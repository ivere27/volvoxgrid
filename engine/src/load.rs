use crate::column::ColumnProps;
use crate::grid::VolvoxGrid;
use crate::proto::volvoxgrid::v1 as pb;
use serde_json::Value as JsonValue;
use std::collections::{BTreeMap, HashMap, HashSet};

#[derive(Clone, Debug)]
enum LoadFormat {
    Csv {
        delimiter: String,
        quote_char: char,
        trim_whitespace: bool,
    },
    Json {
        data_path: Option<String>,
    },
}

#[derive(Clone, Debug)]
struct EffectiveLoadOptions {
    format: LoadFormat,
    header_policy: i32,
    type_policy: i32,
    coercion: i32,
    error_mode: i32,
    date_format: Option<String>,
    decimal_char: char,
    auto_create_columns: bool,
    mode: i32,
    atomic: bool,
    skip_rows: usize,
    max_rows: Option<usize>,
}

impl EffectiveLoadOptions {
    fn from_proto(data: &[u8], options: Option<&pb::LoadDataOptions>) -> Self {
        let format = match options.and_then(|o| o.format.as_ref()) {
            Some(pb::load_data_options::Format::Csv(csv)) => LoadFormat::Csv {
                delimiter: csv
                    .delimiter
                    .clone()
                    .filter(|value| !value.is_empty())
                    .unwrap_or_else(|| ",".to_string()),
                quote_char: csv
                    .quote_char
                    .as_deref()
                    .and_then(|value| value.chars().next())
                    .unwrap_or('"'),
                trim_whitespace: csv.trim_whitespace.unwrap_or(false),
            },
            Some(pb::load_data_options::Format::Json(json)) => LoadFormat::Json {
                data_path: json.data_path.clone().filter(|value| !value.is_empty()),
            },
            None => match data
                .iter()
                .copied()
                .find(|byte| !byte.is_ascii_whitespace())
            {
                Some(b'[') | Some(b'{') => LoadFormat::Json { data_path: None },
                _ => LoadFormat::Csv {
                    delimiter: ",".to_string(),
                    quote_char: '"',
                    trim_whitespace: false,
                },
            },
        };

        Self {
            format,
            header_policy: options
                .and_then(|o| o.header_policy)
                .unwrap_or(pb::HeaderPolicy::HeaderAuto as i32),
            type_policy: options
                .and_then(|o| o.type_policy)
                .unwrap_or(pb::TypePolicy::TypeAutoDetect as i32),
            coercion: options
                .and_then(|o| o.coercion)
                .unwrap_or(pb::CoercionMode::CoercionFlexible as i32),
            error_mode: options
                .and_then(|o| o.error_mode)
                .unwrap_or(pb::WriteErrorMode::WriteErrorSkip as i32),
            date_format: options
                .and_then(|o| o.date_format.clone())
                .filter(|value| !value.is_empty()),
            decimal_char: options
                .and_then(|o| {
                    o.decimal_char
                        .as_deref()
                        .and_then(|value| value.chars().next())
                })
                .unwrap_or('.'),
            auto_create_columns: options.and_then(|o| o.auto_create_columns).unwrap_or(true),
            mode: options
                .and_then(|o| o.mode)
                .unwrap_or(pb::LoadMode::LoadReplace as i32),
            atomic: options.and_then(|o| o.atomic).unwrap_or(false),
            skip_rows: options.and_then(|o| o.skip_rows).unwrap_or(0).max(0) as usize,
            max_rows: options
                .and_then(|o| o.max_rows)
                .filter(|value| *value >= 0)
                .map(|value| value as usize),
        }
    }
}

#[derive(Clone, Debug)]
enum SourceValue {
    Null,
    Text(String),
    Number(f64),
    Bool(bool),
}

#[derive(Clone, Debug, Default)]
struct RawTable {
    headers: Vec<String>,
    has_headers: bool,
    rows: Vec<Vec<SourceValue>>,
    warnings: Vec<String>,
}

#[derive(Clone, Debug)]
struct ColumnMapping {
    source_index: usize,
    target_col: i32,
    expected_type: i32,
}

pub fn load_data(
    grid: &mut VolvoxGrid,
    data: &[u8],
    options: Option<&pb::LoadDataOptions>,
) -> pb::LoadDataResult {
    let opts = EffectiveLoadOptions::from_proto(data, options);
    let mut table = match parse_input(data, &opts) {
        Ok(table) => table,
        Err(message) => return failed_result(message),
    };
    apply_row_limits(&mut table, &opts);

    let original_cols = grid.cols.max(0) as usize;
    let source_col_count = source_column_count(&table);
    let source_names = source_column_names(&table, source_col_count);
    let preserve_existing_cols =
        opts.mode == pb::LoadMode::LoadAppend as i32 || has_meaningful_schema(grid);
    let mut target_width = if preserve_existing_cols {
        original_cols
    } else {
        0usize
    };

    let explicit_map = build_explicit_field_map(options);
    let mut warnings = table.warnings.clone();
    let mut created_defs = BTreeMap::new();
    let mut key_lookup = HashMap::new();
    let mut caption_lookup = HashMap::new();
    for (index, column) in grid.columns.iter().enumerate().take(original_cols) {
        if !column.key.is_empty() {
            key_lookup.insert(column.key.clone(), index as i32);
        }
        if !column.caption.is_empty() {
            caption_lookup.insert(normalize_caption(&column.caption), index as i32);
        }
    }

    let mut mappings = Vec::new();
    let mut inferred_by_target = HashMap::<i32, i32>::new();
    let mut inferred_names = HashMap::<i32, String>::new();

    for source_index in 0..source_col_count {
        let source_name = source_names
            .get(source_index)
            .cloned()
            .unwrap_or_else(|| generic_column_key(source_index));
        let inferred_type =
            infer_source_type(&collect_source_values(&table.rows, source_index), &opts);

        let Some(target_col) = resolve_target_column(
            grid,
            &opts,
            &source_name,
            source_index,
            table.has_headers,
            &explicit_map,
            &mut target_width,
            &mut created_defs,
            &mut key_lookup,
            &mut caption_lookup,
            &mut warnings,
        ) else {
            continue;
        };

        let expected_type = if opts.type_policy == pb::TypePolicy::TypeFromSchema as i32 {
            target_schema_type(grid, &created_defs, target_col)
        } else {
            inferred_type
        };

        mappings.push(ColumnMapping {
            source_index,
            target_col,
            expected_type,
        });

        let merged = inferred_by_target
            .get(&target_col)
            .copied()
            .map(|current| merge_inferred_types(current, expected_type))
            .unwrap_or(expected_type);
        inferred_by_target.insert(target_col, merged);
        inferred_names
            .entry(target_col)
            .or_insert(source_name.clone());
        if let Some(def) = created_defs.get_mut(&target_col) {
            def.data_type = Some(merged);
        }
    }

    let loaded_rows = table.rows.len() as i32;
    let loaded_cols = target_width as i32;
    if mappings.is_empty() && source_col_count > 0 {
        warnings.push("No source columns could be mapped into the grid.".to_string());
    }

    let row_offset = if opts.mode == pb::LoadMode::LoadAppend as i32 {
        grid.rows.max(0)
    } else {
        0
    };
    let mut updates = Vec::new();
    for (row_index, row) in table.rows.iter().enumerate() {
        for mapping in &mappings {
            let source = row
                .get(mapping.source_index)
                .cloned()
                .unwrap_or(SourceValue::Null);
            updates.push(pb::CellUpdate {
                row: row_offset + row_index as i32,
                col: mapping.target_col,
                value: Some(source_value_to_cell_value(
                    &source,
                    mapping.expected_type,
                    &opts,
                )),
                style: None,
                checked: None,
                picture: None,
                picture_align: None,
                button_picture: None,
                dropdown_items: None,
                sticky_row: None,
                sticky_col: None,
            });
        }
    }

    let final_cols = if preserve_existing_cols {
        target_width.max(original_cols).max(1) as i32
    } else {
        target_width.max(1) as i32
    };
    let final_rows = if opts.mode == pb::LoadMode::LoadAppend as i32 {
        (grid.rows.max(0) + loaded_rows).max(1)
    } else {
        loaded_rows.max(1)
    };

    let mut preview = build_preview_grid(grid, final_rows, final_cols);
    apply_created_columns(&mut preview, &created_defs);
    apply_request_modes(&mut preview, final_cols, opts.coercion, opts.error_mode);
    let preview_result = preview.write_cells(&updates, false);
    if opts.atomic && preview_result.rejected_count > 0 {
        return pb::LoadDataResult {
            status: pb::LoadDataStatus::LoadFailed as i32,
            rows: loaded_rows,
            cols: loaded_cols,
            rejected: preview_result.rejected_count,
            violations: preview_result.violations,
            warnings,
            inferred_columns: build_inferred_columns(
                grid,
                &created_defs,
                &inferred_by_target,
                &inferred_names,
            ),
        };
    }

    let restore_modes = snapshot_request_modes(grid, original_cols.min(final_cols as usize));
    if opts.mode == pb::LoadMode::LoadReplace as i32 {
        grid.set_rows(final_rows);
        grid.set_cols(final_cols);
        grid.cells.clear_all();
    } else {
        grid.set_cols(final_cols);
        grid.set_rows(final_rows);
    }
    apply_created_columns(grid, &created_defs);
    apply_request_modes(grid, final_cols, opts.coercion, opts.error_mode);
    let write_result = grid.write_cells(&updates, false);
    restore_request_modes(grid, &restore_modes);

    pb::LoadDataResult {
        status: if write_result.rejected_count > 0 {
            pb::LoadDataStatus::LoadPartial as i32
        } else {
            pb::LoadDataStatus::LoadOk as i32
        },
        rows: loaded_rows,
        cols: loaded_cols,
        rejected: write_result.rejected_count,
        violations: write_result.violations,
        warnings,
        inferred_columns: build_inferred_columns(
            grid,
            &created_defs,
            &inferred_by_target,
            &inferred_names,
        ),
    }
}

fn failed_result(message: String) -> pb::LoadDataResult {
    pb::LoadDataResult {
        status: pb::LoadDataStatus::LoadFailed as i32,
        rows: 0,
        cols: 0,
        rejected: 0,
        violations: Vec::new(),
        warnings: vec![message],
        inferred_columns: Vec::new(),
    }
}

fn parse_input(data: &[u8], opts: &EffectiveLoadOptions) -> Result<RawTable, String> {
    if data.iter().all(|byte| byte.is_ascii_whitespace()) {
        return Err("LoadData input is empty".to_string());
    }
    match &opts.format {
        LoadFormat::Csv {
            delimiter,
            quote_char,
            trim_whitespace,
        } => parse_csv_input(
            data,
            delimiter,
            *quote_char,
            *trim_whitespace,
            opts.header_policy,
        ),
        LoadFormat::Json { data_path } => {
            parse_json_input(data, data_path.as_deref(), opts.header_policy)
        }
    }
}

fn parse_csv_input(
    data: &[u8],
    delimiter: &str,
    quote_char: char,
    trim_whitespace: bool,
    header_policy: i32,
) -> Result<RawTable, String> {
    let text = std::str::from_utf8(data).map_err(|_| "CSV input is not valid UTF-8".to_string())?;
    let mut rows = parse_delimited_text(text, delimiter, quote_char, trim_whitespace);
    let wants_headers = header_policy != pb::HeaderPolicy::HeaderNone as i32;
    let headers = if wants_headers && !rows.is_empty() {
        rows.remove(0)
    } else {
        Vec::new()
    };

    Ok(RawTable {
        has_headers: wants_headers && !headers.is_empty(),
        headers,
        rows: rows
            .into_iter()
            .map(|row| row.into_iter().map(SourceValue::Text).collect())
            .collect(),
        warnings: Vec::new(),
    })
}

fn parse_json_input(
    data: &[u8],
    data_path: Option<&str>,
    header_policy: i32,
) -> Result<RawTable, String> {
    let root: JsonValue =
        serde_json::from_slice(data).map_err(|err| format!("JSON parse error: {err}"))?;
    let value = if let Some(path) = data_path {
        navigate_json_path(&root, path)
            .ok_or_else(|| format!("JSON data_path '{}' was not found", path))?
    } else {
        &root
    };
    parse_json_value(value, header_policy)
}

fn parse_json_value(value: &JsonValue, header_policy: i32) -> Result<RawTable, String> {
    match value {
        JsonValue::Array(items) => {
            if items.iter().all(JsonValue::is_object) {
                parse_json_records(items)
            } else {
                parse_json_arrays(items, header_policy)
            }
        }
        JsonValue::Object(map) => {
            if let (Some(columns), Some(data)) = (map.get("columns"), map.get("data")) {
                parse_json_split(columns, data)
            } else if map.values().all(JsonValue::is_array) {
                parse_json_columns(map)
            } else {
                parse_json_records(&[value.clone()])
            }
        }
        _ => Err("JSON input must be an array or object".to_string()),
    }
}

fn parse_json_records(items: &[JsonValue]) -> Result<RawTable, String> {
    let mut headers = Vec::new();
    let mut seen = HashSet::new();
    for item in items {
        let object = item
            .as_object()
            .ok_or_else(|| "JSON records input must contain objects".to_string())?;
        for key in object.keys() {
            if seen.insert(key.clone()) {
                headers.push(key.clone());
            }
        }
    }

    let mut rows = Vec::with_capacity(items.len());
    for item in items {
        let object = item
            .as_object()
            .ok_or_else(|| "JSON records input must contain objects".to_string())?;
        let mut row = Vec::with_capacity(headers.len());
        for header in &headers {
            row.push(
                object
                    .get(header)
                    .map(json_to_source)
                    .unwrap_or(SourceValue::Null),
            );
        }
        rows.push(row);
    }

    Ok(RawTable {
        has_headers: true,
        headers,
        rows,
        warnings: Vec::new(),
    })
}

fn parse_json_arrays(items: &[JsonValue], header_policy: i32) -> Result<RawTable, String> {
    let mut rows = Vec::with_capacity(items.len());
    for item in items {
        match item {
            JsonValue::Array(values) => rows.push(values.iter().map(json_to_source).collect()),
            _ => rows.push(vec![json_to_source(item)]),
        }
    }

    let wants_headers = header_policy == pb::HeaderPolicy::HeaderFirstRow as i32;
    let headers = if wants_headers && !rows.is_empty() {
        rows.remove(0)
            .into_iter()
            .map(source_to_text)
            .collect::<Vec<_>>()
    } else {
        Vec::new()
    };

    Ok(RawTable {
        has_headers: wants_headers && !headers.is_empty(),
        headers,
        rows,
        warnings: Vec::new(),
    })
}

fn parse_json_split(columns: &JsonValue, data: &JsonValue) -> Result<RawTable, String> {
    let headers = parse_json_headers(columns)?;
    let rows = match data {
        JsonValue::Array(items) => items
            .iter()
            .map(|item| match item {
                JsonValue::Array(values) => Ok(values.iter().map(json_to_source).collect()),
                JsonValue::Object(object) => Ok(headers
                    .iter()
                    .map(|header| {
                        object
                            .get(header)
                            .map(json_to_source)
                            .unwrap_or(SourceValue::Null)
                    })
                    .collect()),
                _ => Err("JSON split data rows must be arrays or objects".to_string()),
            })
            .collect::<Result<Vec<Vec<SourceValue>>, String>>()?,
        _ => return Err("JSON split input requires an array in 'data'".to_string()),
    };

    Ok(RawTable {
        has_headers: true,
        headers,
        rows,
        warnings: Vec::new(),
    })
}

fn parse_json_columns(map: &serde_json::Map<String, JsonValue>) -> Result<RawTable, String> {
    let headers = map.keys().cloned().collect::<Vec<_>>();
    let mut columns = Vec::with_capacity(headers.len());
    let mut row_count = 0usize;
    for header in &headers {
        let values = map
            .get(header)
            .and_then(JsonValue::as_array)
            .ok_or_else(|| "JSON columns input requires arrays for every field".to_string())?;
        row_count = row_count.max(values.len());
        columns.push(values.iter().map(json_to_source).collect::<Vec<_>>());
    }

    let mut rows = Vec::with_capacity(row_count);
    for row_index in 0..row_count {
        let mut row = Vec::with_capacity(columns.len());
        for column in &columns {
            row.push(column.get(row_index).cloned().unwrap_or(SourceValue::Null));
        }
        rows.push(row);
    }

    Ok(RawTable {
        has_headers: true,
        headers,
        rows,
        warnings: Vec::new(),
    })
}

fn parse_json_headers(value: &JsonValue) -> Result<Vec<String>, String> {
    let items = value
        .as_array()
        .ok_or_else(|| "JSON split 'columns' must be an array".to_string())?;
    Ok(items
        .iter()
        .enumerate()
        .map(|(index, item)| match item {
            JsonValue::String(text) if !text.is_empty() => text.clone(),
            JsonValue::Object(object) => object
                .get("key")
                .or_else(|| object.get("caption"))
                .or_else(|| object.get("name"))
                .or_else(|| object.get("field"))
                .and_then(JsonValue::as_str)
                .filter(|value| !value.is_empty())
                .map(str::to_string)
                .unwrap_or_else(|| generic_column_caption(index)),
            _ => generic_column_caption(index),
        })
        .collect())
}

fn navigate_json_path<'a>(value: &'a JsonValue, path: &str) -> Option<&'a JsonValue> {
    let mut current = value;
    for part in path.split('.') {
        if part.is_empty() {
            continue;
        }
        if let Ok(index) = part.parse::<usize>() {
            current = current.as_array()?.get(index)?;
        } else {
            current = current.as_object()?.get(part)?;
        }
    }
    Some(current)
}

fn json_to_source(value: &JsonValue) -> SourceValue {
    match value {
        JsonValue::Null => SourceValue::Null,
        JsonValue::Bool(flag) => SourceValue::Bool(*flag),
        JsonValue::Number(number) => number
            .as_f64()
            .filter(|value| value.is_finite())
            .map(SourceValue::Number)
            .unwrap_or_else(|| SourceValue::Text(number.to_string())),
        JsonValue::String(text) => SourceValue::Text(text.clone()),
        JsonValue::Array(_) | JsonValue::Object(_) => SourceValue::Text(value.to_string()),
    }
}

fn parse_delimited_text(
    input: &str,
    separator: &str,
    quote_char: char,
    trim_whitespace: bool,
) -> Vec<Vec<String>> {
    let separator = if separator.is_empty() {
        b",".to_vec()
    } else {
        separator.as_bytes().to_vec()
    };
    let quote_char = quote_char as u8;

    let mut rows = Vec::new();
    let mut row = Vec::new();
    let mut field = Vec::new();
    let bytes = input.as_bytes();
    let mut index = 0usize;
    let mut in_quotes = false;

    let push_field = |row: &mut Vec<String>, field: &mut Vec<u8>| {
        let mut text = String::from_utf8_lossy(field).to_string();
        if trim_whitespace {
            text = text.trim().to_string();
        }
        row.push(text);
        field.clear();
    };

    while index < bytes.len() {
        if in_quotes {
            if bytes[index] == quote_char {
                if index + 1 < bytes.len() && bytes[index + 1] == quote_char {
                    field.push(quote_char);
                    index += 2;
                } else {
                    in_quotes = false;
                    index += 1;
                }
            } else {
                field.push(bytes[index]);
                index += 1;
            }
            continue;
        }

        if bytes[index] == quote_char {
            in_quotes = true;
            index += 1;
            continue;
        }

        if !separator.is_empty()
            && index + separator.len() <= bytes.len()
            && bytes[index..].starts_with(&separator)
        {
            push_field(&mut row, &mut field);
            index += separator.len();
            continue;
        }

        if bytes[index] == b'\n' {
            push_field(&mut row, &mut field);
            rows.push(std::mem::take(&mut row));
            index += 1;
            continue;
        }

        if bytes[index] == b'\r' {
            push_field(&mut row, &mut field);
            rows.push(std::mem::take(&mut row));
            index += 1;
            if index < bytes.len() && bytes[index] == b'\n' {
                index += 1;
            }
            continue;
        }

        field.push(bytes[index]);
        index += 1;
    }

    let ends_with_break = input.ends_with('\n') || input.ends_with('\r');
    if !field.is_empty() || !row.is_empty() || (!ends_with_break && !input.is_empty()) {
        push_field(&mut row, &mut field);
        rows.push(row);
    }

    rows
}

fn apply_row_limits(table: &mut RawTable, opts: &EffectiveLoadOptions) {
    if opts.skip_rows > 0 {
        let skipped = opts.skip_rows.min(table.rows.len());
        if skipped > 0 {
            table.rows.drain(0..skipped);
            table
                .warnings
                .push(format!("Skipped {} leading data rows.", skipped));
        }
    }
    if let Some(max_rows) = opts.max_rows {
        if table.rows.len() > max_rows {
            table.rows.truncate(max_rows);
            table
                .warnings
                .push(format!("Truncated input to {} data rows.", max_rows));
        }
    }
}

fn source_column_count(table: &RawTable) -> usize {
    if table.has_headers {
        table.headers.len()
    } else {
        table.rows.iter().map(|row| row.len()).max().unwrap_or(0)
    }
}

fn source_column_names(table: &RawTable, count: usize) -> Vec<String> {
    if table.has_headers {
        (0..count)
            .map(|index| {
                table
                    .headers
                    .get(index)
                    .cloned()
                    .filter(|value| !value.trim().is_empty())
                    .unwrap_or_else(|| generic_column_key(index))
            })
            .collect()
    } else {
        (0..count).map(generic_column_key).collect()
    }
}

fn collect_source_values(rows: &[Vec<SourceValue>], index: usize) -> Vec<SourceValue> {
    rows.iter()
        .map(|row| row.get(index).cloned().unwrap_or(SourceValue::Null))
        .collect()
}

fn has_meaningful_schema(grid: &VolvoxGrid) -> bool {
    grid.columns.iter().any(column_has_meaningful_schema)
}

fn column_has_meaningful_schema(column: &ColumnProps) -> bool {
    !column.key.is_empty()
        || !column.caption.is_empty()
        || !column.format.is_empty()
        || normalize_data_type(column.data_type) != pb::ColumnDataType::ColumnDataString as i32
        || !column.nullable
        || column.coercion_mode != 0
        || column.error_mode != 0
}

fn build_explicit_field_map(
    options: Option<&pb::LoadDataOptions>,
) -> HashMap<String, pb::FieldMapping> {
    let mut mappings = HashMap::new();
    if let Some(options) = options {
        for mapping in &options.field_map {
            if !mapping.field.is_empty() {
                mappings.insert(mapping.field.clone(), mapping.clone());
            }
        }
    }
    mappings
}

#[allow(clippy::too_many_arguments)]
fn resolve_target_column(
    grid: &VolvoxGrid,
    opts: &EffectiveLoadOptions,
    source_name: &str,
    source_index: usize,
    has_headers: bool,
    explicit_map: &HashMap<String, pb::FieldMapping>,
    target_width: &mut usize,
    created_defs: &mut BTreeMap<i32, pb::ColumnDef>,
    key_lookup: &mut HashMap<String, i32>,
    caption_lookup: &mut HashMap<String, i32>,
    warnings: &mut Vec<String>,
) -> Option<i32> {
    if let Some(mapping) = explicit_map.get(source_name) {
        return resolve_explicit_target(
            grid,
            opts,
            source_name,
            source_index,
            has_headers,
            mapping,
            target_width,
            created_defs,
            key_lookup,
            caption_lookup,
            warnings,
        );
    }

    if has_headers {
        if let Some(target) = key_lookup.get(source_name) {
            *target_width = (*target_width).max((*target as usize) + 1);
            return Some(*target);
        }
        if let Some(target) = caption_lookup.get(&normalize_caption(source_name)) {
            *target_width = (*target_width).max((*target as usize) + 1);
            return Some(*target);
        }
    }

    if !has_headers {
        let target = source_index as i32;
        let target_index = target as usize;
        let existing_cols = grid.cols.max(0) as usize;
        if target_index < existing_cols || opts.auto_create_columns {
            *target_width = (*target_width).max(target_index + 1);
            if opts.auto_create_columns
                && (target_index >= existing_cols
                    || !column_index_has_definition(grid, target_index))
            {
                let (key, caption) = positional_column_identity(target_index);
                ensure_created_definition(
                    target,
                    key,
                    caption,
                    created_defs,
                    key_lookup,
                    caption_lookup,
                    opts,
                );
            }
            return Some(target);
        }

        warnings.push(format!(
            "Skipped source column {} because no target column exists.",
            source_index + 1
        ));
        return None;
    }

    if opts.auto_create_columns {
        let target = *target_width as i32;
        *target_width += 1;
        let (key, caption) = named_column_identity(source_name, target as usize);
        ensure_created_definition(
            target,
            key,
            caption,
            created_defs,
            key_lookup,
            caption_lookup,
            opts,
        );
        return Some(target);
    }

    warnings.push(format!("Skipped unmapped source field '{}'.", source_name));
    None
}

#[allow(clippy::too_many_arguments)]
fn resolve_explicit_target(
    grid: &VolvoxGrid,
    opts: &EffectiveLoadOptions,
    source_name: &str,
    source_index: usize,
    has_headers: bool,
    mapping: &pb::FieldMapping,
    target_width: &mut usize,
    created_defs: &mut BTreeMap<i32, pb::ColumnDef>,
    key_lookup: &mut HashMap<String, i32>,
    caption_lookup: &mut HashMap<String, i32>,
    warnings: &mut Vec<String>,
) -> Option<i32> {
    let target = match mapping.target.as_ref() {
        Some(pb::field_mapping::Target::ColIndex(index)) => *index,
        Some(pb::field_mapping::Target::ColKey(key)) => {
            if let Some(existing) = key_lookup.get(key) {
                *target_width = (*target_width).max((*existing as usize) + 1);
                return Some(*existing);
            }
            if !opts.auto_create_columns {
                warnings.push(format!(
                    "Field '{}' references missing target column key '{}'.",
                    source_name, key
                ));
                return None;
            }
            let target = *target_width as i32;
            *target_width += 1;
            let caption = if source_name.trim().is_empty() {
                key.clone()
            } else {
                source_name.to_string()
            };
            ensure_created_definition(
                target,
                key.clone(),
                caption,
                created_defs,
                key_lookup,
                caption_lookup,
                opts,
            );
            return Some(target);
        }
        None => {
            warnings.push(format!(
                "Field '{}' has an explicit mapping without a target.",
                source_name
            ));
            return None;
        }
    };

    if target < 0 {
        warnings.push(format!(
            "Field '{}' references negative target column index {}.",
            source_name, target
        ));
        return None;
    }

    let target_index = target as usize;
    let existing_cols = grid.cols.max(0) as usize;
    if target_index >= existing_cols && !opts.auto_create_columns {
        warnings.push(format!(
            "Field '{}' references missing target column index {}.",
            source_name, target
        ));
        return None;
    }

    *target_width = (*target_width).max(target_index + 1);
    if opts.auto_create_columns
        && (target_index >= existing_cols || !column_index_has_definition(grid, target_index))
    {
        let (key, caption) = if has_headers {
            named_column_identity(source_name, target_index)
        } else {
            positional_column_identity(source_index)
        };
        ensure_created_definition(
            target,
            key,
            caption,
            created_defs,
            key_lookup,
            caption_lookup,
            opts,
        );
    }
    Some(target)
}

fn column_index_has_definition(grid: &VolvoxGrid, index: usize) -> bool {
    grid.columns
        .get(index)
        .map(column_has_meaningful_schema)
        .unwrap_or(false)
}

fn ensure_created_definition(
    target: i32,
    key: String,
    caption: String,
    created_defs: &mut BTreeMap<i32, pb::ColumnDef>,
    key_lookup: &mut HashMap<String, i32>,
    caption_lookup: &mut HashMap<String, i32>,
    opts: &EffectiveLoadOptions,
) {
    let def = created_defs.entry(target).or_insert_with(|| pb::ColumnDef {
        index: target,
        key: if key.is_empty() {
            None
        } else {
            Some(key.clone())
        },
        caption: if caption.is_empty() {
            None
        } else {
            Some(caption.clone())
        },
        nullable: Some(true),
        coercion_mode: Some(opts.coercion),
        error_mode: Some(opts.error_mode),
        ..Default::default()
    });
    if def.key.as_deref().unwrap_or_default().is_empty() && !key.is_empty() {
        def.key = Some(key.clone());
    }
    if def.caption.as_deref().unwrap_or_default().is_empty() && !caption.is_empty() {
        def.caption = Some(caption.clone());
    }
    if !key.is_empty() {
        key_lookup.entry(key).or_insert(target);
    }
    if !caption.is_empty() {
        caption_lookup
            .entry(normalize_caption(&caption))
            .or_insert(target);
    }
}

fn target_schema_type(
    grid: &VolvoxGrid,
    created_defs: &BTreeMap<i32, pb::ColumnDef>,
    target_col: i32,
) -> i32 {
    if let Some(data_type) = created_defs.get(&target_col).and_then(|def| def.data_type) {
        return normalize_data_type(data_type);
    }
    grid.columns
        .get(target_col as usize)
        .map(|column| normalize_data_type(column.data_type))
        .unwrap_or(pb::ColumnDataType::ColumnDataString as i32)
}

fn normalize_data_type(data_type: i32) -> i32 {
    match data_type {
        v if v == pb::ColumnDataType::ColumnDataString as i32 => v,
        v if v == pb::ColumnDataType::ColumnDataNumber as i32 => v,
        v if v == pb::ColumnDataType::ColumnDataDate as i32 => v,
        v if v == pb::ColumnDataType::ColumnDataBoolean as i32 => v,
        v if v == pb::ColumnDataType::ColumnDataCurrency as i32 => v,
        _ => pb::ColumnDataType::ColumnDataString as i32,
    }
}

fn infer_source_type(values: &[SourceValue], opts: &EffectiveLoadOptions) -> i32 {
    if opts.type_policy == pb::TypePolicy::TypeAllString as i32
        || opts.type_policy == pb::TypePolicy::TypeFromSchema as i32
    {
        return pb::ColumnDataType::ColumnDataString as i32;
    }

    let mut inferred = None;
    for value in values {
        let Some(value_type) = candidate_type(value, opts) else {
            continue;
        };
        match inferred {
            None => inferred = Some(value_type),
            Some(current) if current == value_type => {}
            Some(_) => return pb::ColumnDataType::ColumnDataString as i32,
        }
    }
    inferred.unwrap_or(pb::ColumnDataType::ColumnDataString as i32)
}

fn candidate_type(value: &SourceValue, opts: &EffectiveLoadOptions) -> Option<i32> {
    match value {
        SourceValue::Null => None,
        SourceValue::Number(_) => Some(pb::ColumnDataType::ColumnDataNumber as i32),
        SourceValue::Bool(_) => Some(pb::ColumnDataType::ColumnDataBoolean as i32),
        SourceValue::Text(text) => {
            if text.trim().is_empty() {
                return None;
            }
            if detect_date_text(text, opts).is_some() {
                Some(pb::ColumnDataType::ColumnDataDate as i32)
            } else if parse_number_text(text, opts.decimal_char).is_some() {
                Some(pb::ColumnDataType::ColumnDataNumber as i32)
            } else if parse_bool_text(text).is_some() {
                Some(pb::ColumnDataType::ColumnDataBoolean as i32)
            } else {
                Some(pb::ColumnDataType::ColumnDataString as i32)
            }
        }
    }
}

fn merge_inferred_types(left: i32, right: i32) -> i32 {
    if left == right {
        left
    } else {
        pb::ColumnDataType::ColumnDataString as i32
    }
}

fn source_value_to_cell_value(
    value: &SourceValue,
    expected_type: i32,
    opts: &EffectiveLoadOptions,
) -> pb::CellValue {
    use pb::cell_value::Value;

    let value = match value {
        SourceValue::Null => None,
        SourceValue::Text(text)
            if text.trim().is_empty()
                && expected_type != pb::ColumnDataType::ColumnDataString as i32 =>
        {
            None
        }
        SourceValue::Text(text) => match expected_type {
            v if v == pb::ColumnDataType::ColumnDataString as i32 => {
                Some(Value::Text(text.clone()))
            }
            v if v == pb::ColumnDataType::ColumnDataNumber as i32
                || v == pb::ColumnDataType::ColumnDataCurrency as i32 =>
            {
                parse_number_text(text, opts.decimal_char)
                    .map(Value::Number)
                    .or_else(|| Some(Value::Text(text.clone())))
            }
            v if v == pb::ColumnDataType::ColumnDataBoolean as i32 => parse_bool_text(text)
                .map(Value::Flag)
                .or_else(|| Some(Value::Text(text.clone()))),
            v if v == pb::ColumnDataType::ColumnDataDate as i32 => {
                parse_date_for_expected(text, opts)
                    .map(Value::Timestamp)
                    .or_else(|| Some(Value::Text(text.clone())))
            }
            _ => Some(Value::Text(text.clone())),
        },
        SourceValue::Number(number) => match expected_type {
            v if v == pb::ColumnDataType::ColumnDataString as i32 => {
                Some(Value::Text(number.to_string()))
            }
            v if v == pb::ColumnDataType::ColumnDataBoolean as i32 => {
                Some(Value::Flag(*number != 0.0))
            }
            v if v == pb::ColumnDataType::ColumnDataDate as i32 => {
                Some(Value::Timestamp(*number as i64))
            }
            _ => Some(Value::Number(*number)),
        },
        SourceValue::Bool(flag) => match expected_type {
            v if v == pb::ColumnDataType::ColumnDataString as i32 => Some(Value::Text(
                if *flag { "true" } else { "false" }.to_string(),
            )),
            v if v == pb::ColumnDataType::ColumnDataNumber as i32
                || v == pb::ColumnDataType::ColumnDataCurrency as i32 =>
            {
                Some(Value::Number(if *flag { 1.0 } else { 0.0 }))
            }
            v if v == pb::ColumnDataType::ColumnDataBoolean as i32 => Some(Value::Flag(*flag)),
            _ => Some(Value::Text(
                if *flag { "true" } else { "false" }.to_string(),
            )),
        },
    };

    pb::CellValue { value }
}

fn build_preview_grid(grid: &VolvoxGrid, rows: i32, cols: i32) -> VolvoxGrid {
    let rows = rows.max(1);
    let cols = cols.max(1);
    let mut preview = VolvoxGrid::new(
        -1,
        grid.viewport_width,
        grid.viewport_height,
        rows,
        cols,
        grid.fixed_rows.min(rows),
        grid.fixed_cols.min(cols),
    );
    let copy_len = preview
        .columns
        .len()
        .min(grid.columns.len())
        .min(cols as usize);
    for index in 0..copy_len {
        preview.columns[index] = grid.columns[index].clone();
    }
    preview
}

fn apply_created_columns(grid: &mut VolvoxGrid, created_defs: &BTreeMap<i32, pb::ColumnDef>) {
    if created_defs.is_empty() {
        return;
    }
    let defs = created_defs.values().cloned().collect::<Vec<_>>();
    grid.define_columns(&defs);
}

fn apply_request_modes(grid: &mut VolvoxGrid, cols: i32, coercion: i32, error_mode: i32) {
    let limit = cols.max(0).min(grid.columns.len() as i32) as usize;
    for column in grid.columns.iter_mut().take(limit) {
        column.coercion_mode = coercion;
        column.error_mode = error_mode;
    }
}

fn snapshot_request_modes(grid: &VolvoxGrid, cols: usize) -> Vec<(usize, i32, i32)> {
    grid.columns
        .iter()
        .enumerate()
        .take(cols)
        .map(|(index, column)| (index, column.coercion_mode, column.error_mode))
        .collect()
}

fn restore_request_modes(grid: &mut VolvoxGrid, snapshot: &[(usize, i32, i32)]) {
    for &(index, coercion_mode, error_mode) in snapshot {
        if let Some(column) = grid.columns.get_mut(index) {
            column.coercion_mode = coercion_mode;
            column.error_mode = error_mode;
        }
    }
}

fn build_inferred_columns(
    grid: &VolvoxGrid,
    created_defs: &BTreeMap<i32, pb::ColumnDef>,
    inferred_by_target: &HashMap<i32, i32>,
    inferred_names: &HashMap<i32, String>,
) -> Vec<pb::ColumnDef> {
    let mut targets = inferred_by_target.keys().copied().collect::<Vec<_>>();
    targets.sort_unstable();
    targets
        .into_iter()
        .map(|target| {
            let data_type = inferred_by_target
                .get(&target)
                .copied()
                .unwrap_or(pb::ColumnDataType::ColumnDataString as i32);
            let mut def = created_defs.get(&target).cloned().unwrap_or_default();
            let fallback_name = inferred_names
                .get(&target)
                .cloned()
                .unwrap_or_else(|| generic_column_caption(target as usize));
            def.index = target;
            def.data_type = Some(data_type);
            if def.key.as_deref().unwrap_or_default().is_empty() {
                def.key = Some(
                    grid.columns
                        .get(target as usize)
                        .filter(|column| !column.key.is_empty())
                        .map(|column| column.key.clone())
                        .unwrap_or_else(|| {
                            named_column_identity(&fallback_name, target as usize).0
                        }),
                );
            }
            if def.caption.as_deref().unwrap_or_default().is_empty() {
                def.caption = Some(
                    grid.columns
                        .get(target as usize)
                        .filter(|column| !column.caption.is_empty())
                        .map(|column| column.caption.clone())
                        .unwrap_or_else(|| {
                            if fallback_name.starts_with("column_") {
                                generic_column_caption(target as usize)
                            } else {
                                fallback_name.clone()
                            }
                        }),
                );
            }
            def.coercion_mode = None;
            def.error_mode = None;
            def
        })
        .collect()
}

fn generic_column_key(index: usize) -> String {
    format!("column_{}", index + 1)
}

fn generic_column_caption(index: usize) -> String {
    format!("Column {}", index + 1)
}

fn positional_column_identity(index: usize) -> (String, String) {
    (generic_column_key(index), generic_column_caption(index))
}

fn named_column_identity(source_name: &str, index: usize) -> (String, String) {
    let trimmed = source_name.trim();
    if trimmed.is_empty() {
        positional_column_identity(index)
    } else {
        (trimmed.to_string(), trimmed.to_string())
    }
}

fn normalize_caption(value: &str) -> String {
    value.trim().to_ascii_lowercase()
}

fn source_to_text(value: SourceValue) -> String {
    match value {
        SourceValue::Null => String::new(),
        SourceValue::Text(text) => text,
        SourceValue::Number(number) => number.to_string(),
        SourceValue::Bool(flag) => {
            if flag {
                "true".to_string()
            } else {
                "false".to_string()
            }
        }
    }
}

fn parse_number_text(raw: &str, decimal_char: char) -> Option<f64> {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return None;
    }
    let mut normalized = trimmed.replace(' ', "");
    if decimal_char == ',' {
        if normalized.contains('.') && normalized.contains(',') {
            normalized = normalized.replace('.', "");
        }
        normalized = normalized.replace(',', ".");
    } else if normalized.contains(',') {
        return None;
    }
    normalized
        .parse::<f64>()
        .ok()
        .filter(|value| value.is_finite())
}

fn parse_bool_text(raw: &str) -> Option<bool> {
    match raw.trim().to_ascii_lowercase().as_str() {
        "true" | "1" | "yes" | "y" | "on" => Some(true),
        "false" | "0" | "no" | "n" | "off" => Some(false),
        _ => None,
    }
}

fn detect_date_text(raw: &str, opts: &EffectiveLoadOptions) -> Option<i64> {
    if let Some(format) = &opts.date_format {
        if let Some(value) = parse_custom_date_format(raw, format) {
            return Some(value);
        }
    }
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return None;
    }
    if !(trimmed.contains('-')
        || trimmed.contains('/')
        || trimmed.contains('T')
        || trimmed.contains(':'))
    {
        return None;
    }
    parse_loose_date(trimmed)
}

fn parse_date_for_expected(raw: &str, opts: &EffectiveLoadOptions) -> Option<i64> {
    detect_date_text(raw, opts).or_else(|| raw.trim().parse::<i64>().ok())
}

fn parse_custom_date_format(raw: &str, format: &str) -> Option<i64> {
    let input = raw.trim();
    if input.is_empty() || format.is_empty() {
        return None;
    }
    let fmt = format.as_bytes();
    let bytes = input.as_bytes();
    let mut fi = 0usize;
    let mut ii = 0usize;
    let mut year = None;
    let mut month = None;
    let mut day = None;
    let mut hour = Some(0i32);
    let mut minute = Some(0i32);
    let mut second = Some(0i32);

    while fi < fmt.len() {
        if fmt[fi..].starts_with(b"yyyy") {
            year = Some(parse_digits(bytes, &mut ii, 4)?);
            fi += 4;
        } else if fmt[fi..].starts_with(b"MM") {
            month = Some(parse_digits(bytes, &mut ii, 2)?);
            fi += 2;
        } else if fmt[fi..].starts_with(b"dd") {
            day = Some(parse_digits(bytes, &mut ii, 2)?);
            fi += 2;
        } else if fmt[fi..].starts_with(b"HH") {
            hour = Some(parse_digits(bytes, &mut ii, 2)?);
            fi += 2;
        } else if fmt[fi..].starts_with(b"mm") {
            minute = Some(parse_digits(bytes, &mut ii, 2)?);
            fi += 2;
        } else if fmt[fi..].starts_with(b"ss") {
            second = Some(parse_digits(bytes, &mut ii, 2)?);
            fi += 2;
        } else {
            if ii >= bytes.len() || fmt[fi] != bytes[ii] {
                return None;
            }
            fi += 1;
            ii += 1;
        }
    }
    if ii != bytes.len() {
        return None;
    }

    build_timestamp(
        year?,
        month?,
        day?,
        hour.unwrap_or(0),
        minute.unwrap_or(0),
        second.unwrap_or(0),
    )
}

fn parse_digits(input: &[u8], index: &mut usize, len: usize) -> Option<i32> {
    if *index + len > input.len() {
        return None;
    }
    let slice = &input[*index..*index + len];
    if !slice.iter().all(u8::is_ascii_digit) {
        return None;
    }
    *index += len;
    std::str::from_utf8(slice).ok()?.parse::<i32>().ok()
}

fn parse_loose_date(raw: &str) -> Option<i64> {
    let parts = raw
        .split(|ch: char| !ch.is_ascii_digit())
        .filter(|part| !part.is_empty())
        .collect::<Vec<_>>();
    if parts.len() < 3 {
        return None;
    }

    let p0 = parts[0].parse::<i32>().ok()?;
    let p1 = parts[1].parse::<i32>().ok()?;
    let p2 = parts[2].parse::<i32>().ok()?;
    let (year, month, day) = if parts[0].len() == 4 {
        (p0, p1, p2)
    } else if parts[2].len() == 4 {
        (p2, p0, p1)
    } else {
        return None;
    };
    let hour = parts
        .get(3)
        .and_then(|value| value.parse::<i32>().ok())
        .unwrap_or(0);
    let minute = parts
        .get(4)
        .and_then(|value| value.parse::<i32>().ok())
        .unwrap_or(0);
    let second = parts
        .get(5)
        .and_then(|value| value.parse::<i32>().ok())
        .unwrap_or(0);
    build_timestamp(year, month, day, hour, minute, second)
}

fn build_timestamp(
    year: i32,
    month: i32,
    day: i32,
    hour: i32,
    minute: i32,
    second: i32,
) -> Option<i64> {
    if !(1..=12).contains(&month)
        || !(1..=31).contains(&day)
        || !(0..=23).contains(&hour)
        || !(0..=59).contains(&minute)
        || !(0..=59).contains(&second)
    {
        return None;
    }
    let days = days_from_civil(year, month, day);
    let seconds = hour as i64 * 3600 + minute as i64 * 60 + second as i64;
    Some(days * 86_400_000 + seconds * 1000)
}

fn days_from_civil(year: i32, month: i32, day: i32) -> i64 {
    let year = year as i64 - if month <= 2 { 1 } else { 0 };
    let era = if year >= 0 { year } else { year - 399 } / 400;
    let yoe = year - era * 400;
    let month_param = month as i64 + if month > 2 { -3 } else { 9 };
    let day_of_year = (153 * month_param + 2) / 5 + day as i64 - 1;
    let day_of_era = yoe * 365 + yoe / 4 - yoe / 100 + day_of_year;
    era * 146_097 + day_of_era - 719_468
}

#[cfg(test)]
mod tests {
    use super::load_data;
    use crate::grid::VolvoxGrid;
    use crate::proto::volvoxgrid::v1 as pb;

    fn new_grid() -> VolvoxGrid {
        VolvoxGrid::new(1, 800, 600, 1, 1, 0, 0)
    }

    fn json_options() -> pb::LoadDataOptions {
        pb::LoadDataOptions {
            format: Some(pb::load_data_options::Format::Json(pb::JsonOptions {
                data_path: None,
            })),
            ..Default::default()
        }
    }

    fn csv_options(delimiter: &str) -> pb::LoadDataOptions {
        pb::LoadDataOptions {
            format: Some(pb::load_data_options::Format::Csv(pb::CsvOptions {
                delimiter: Some(delimiter.to_string()),
                quote_char: None,
                trim_whitespace: None,
            })),
            ..Default::default()
        }
    }

    #[test]
    fn load_data_json_records_auto_creates_columns_and_infers_number() {
        let mut grid = new_grid();
        let result = load_data(
            &mut grid,
            br#"[{"date":"2024-01-01","amount":"12.5","ok":true}]"#,
            Some(&json_options()),
        );

        assert_eq!(result.status, pb::LoadDataStatus::LoadOk as i32);
        assert_eq!(result.rows, 1);
        let amount_col = grid
            .columns
            .iter()
            .position(|column| column.key == "amount")
            .expect("amount column should exist") as i32;
        let cells = grid.get_cells(0, amount_col, 0, amount_col, false, false, true);
        let value = cells[0].value.as_ref().and_then(|cell| cell.value.as_ref());
        assert!(matches!(value, Some(pb::cell_value::Value::Number(_))));
    }

    #[test]
    fn load_data_json_split_shape_is_supported() {
        let mut grid = new_grid();
        let result = load_data(
            &mut grid,
            br#"{"columns":["name","active"],"data":[["A",true],["B",false]]}"#,
            Some(&json_options()),
        );

        assert_eq!(result.status, pb::LoadDataStatus::LoadOk as i32);
        assert_eq!(result.rows, 2);
        assert!(grid.columns.iter().any(|column| column.key == "name"));
        assert!(grid.columns.iter().any(|column| column.key == "active"));
    }

    #[test]
    fn load_data_csv_supports_append_and_decimal_char() {
        let mut grid = new_grid();
        grid.set_rows(1);
        grid.set_cols(2);
        grid.define_columns(&[
            pb::ColumnDef {
                index: 0,
                key: Some("date".to_string()),
                ..Default::default()
            },
            pb::ColumnDef {
                index: 1,
                key: Some("amount".to_string()),
                data_type: Some(pb::ColumnDataType::ColumnDataNumber as i32),
                ..Default::default()
            },
        ]);

        let mut options = csv_options(";");
        options.decimal_char = Some(",".to_string());
        options.mode = Some(pb::LoadMode::LoadAppend as i32);

        let result = load_data(&mut grid, b"date;amount\n2024-01-02;1,25", Some(&options));

        assert_eq!(result.status, pb::LoadDataStatus::LoadOk as i32);
        assert_eq!(grid.rows, 2);
        let cells = grid.get_cells(1, 1, 1, 1, false, false, true);
        let value = cells[0].value.as_ref().and_then(|cell| cell.value.as_ref());
        assert!(matches!(value, Some(pb::cell_value::Value::Number(_))));
    }

    #[test]
    fn load_data_atomic_failure_rolls_back() {
        let mut grid = new_grid();
        grid.set_cols(1);
        grid.define_columns(&[pb::ColumnDef {
            index: 0,
            key: Some("amount".to_string()),
            data_type: Some(pb::ColumnDataType::ColumnDataNumber as i32),
            ..Default::default()
        }]);
        let _ = grid.write_cells(
            &[pb::CellUpdate {
                row: 0,
                col: 0,
                value: Some(pb::CellValue {
                    value: Some(pb::cell_value::Value::Number(42.0)),
                }),
                style: None,
                checked: None,
                picture: None,
                picture_align: None,
                button_picture: None,
                dropdown_items: None,
                sticky_row: None,
                sticky_col: None,
            }],
            false,
        );

        let mut options = json_options();
        options.type_policy = Some(pb::TypePolicy::TypeFromSchema as i32);
        options.error_mode = Some(pb::WriteErrorMode::WriteErrorReject as i32);
        options.atomic = Some(true);

        let result = load_data(&mut grid, br#"[{"amount":"bad"}]"#, Some(&options));

        assert_eq!(result.status, pb::LoadDataStatus::LoadFailed as i32);
        assert_eq!(result.rejected, 1);
        let cells = grid.get_cells(0, 0, 0, 0, false, false, true);
        let value = cells[0].value.as_ref().and_then(|cell| cell.value.as_ref());
        match value {
            Some(pb::cell_value::Value::Number(number)) => assert_eq!(*number, 42.0),
            _ => panic!("existing value should remain after atomic failure"),
        }
    }
}
