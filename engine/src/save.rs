use crate::grid::VolvoxGrid;
use crate::proto::volvoxgrid::v1 as pb;
use std::time::{SystemTime, UNIX_EPOCH};

/// Save grid data to a byte vector in the specified format.
///
/// `format`:
/// - 1 = binary (FXGD)
/// - 2 = tab-separated text
/// - 3 = comma-separated (CSV)
/// - 4 = custom separator (uses `grid.clip_col_separator`)
/// - 5 = Excel SpreadsheetML XML
///
/// `scope`:
/// - 1 = data + format
/// - 2 = data only
/// - 3 = format only
pub fn save_grid(grid: &VolvoxGrid, format: i32, scope: i32) -> Vec<u8> {
    if !export_scope_is_valid(scope) {
        return Vec::new();
    }

    match format {
        f if f == pb::ExportFormat::ExportBinary as i32 => save_binary(grid, scope),
        f if f == pb::ExportFormat::ExportTsv as i32 => save_text(grid, "\t", scope),
        f if f == pb::ExportFormat::ExportCsv as i32 => save_text(grid, ",", scope),
        f if f == pb::ExportFormat::ExportDelimited as i32 => {
            save_text(grid, &grid.clip_col_separator, scope)
        }
        f if f == pb::ExportFormat::ExportXlsx as i32 => save_excel(grid, scope),
        _ => Vec::new(),
    }
}

/// Load grid data from a byte slice in the specified format.
///
/// `format`:
/// - 1 = binary (FXGD)
/// - 2 = tab-separated text
/// - 3 = comma-separated (CSV)
/// - 4 = custom separator (uses `grid.clip_col_separator`)
///
/// `scope`: same as `save_grid`.
pub fn load_grid(grid: &mut VolvoxGrid, data: &[u8], format: i32, scope: i32) {
    if !export_scope_is_valid(scope) {
        return;
    }

    match format {
        f if f == pb::ExportFormat::ExportBinary as i32 => load_binary(grid, data, scope),
        f if f == pb::ExportFormat::ExportTsv as i32 => load_text(grid, data, "\t", scope),
        f if f == pb::ExportFormat::ExportCsv as i32 => load_text(grid, data, ",", scope),
        f if f == pb::ExportFormat::ExportDelimited as i32 => {
            let sep = grid.clip_col_separator.clone();
            load_text(grid, data, &sep, scope);
        }
        _ => {}
    }

    // Auto-resize columns/rows if the property is enabled
    if grid.auto_resize {
        let mode = grid.auto_size_mode;
        if mode == 0 || mode == 1 {
            // Resize columns (mode 0 = both, mode 1 = cols only)
            for c in 0..grid.cols {
                grid.auto_resize_col(c);
            }
        }
        if mode == 0 || mode == 2 {
            // Resize rows (mode 0 = both, mode 2 = rows only)
            for r in 0..grid.rows {
                grid.auto_resize_row(r);
            }
        }
    }
}

fn export_includes_data(scope: i32) -> bool {
    scope == pb::ExportScope::ExportAll as i32 || scope == pb::ExportScope::ExportDataOnly as i32
}

fn export_includes_format(scope: i32) -> bool {
    scope == pb::ExportScope::ExportAll as i32 || scope == pb::ExportScope::ExportFormatOnly as i32
}

fn export_scope_is_valid(scope: i32) -> bool {
    export_includes_data(scope) || export_includes_format(scope)
}

fn save_binary(grid: &VolvoxGrid, scope: i32) -> Vec<u8> {
    let mut out = Vec::new();
    // Header: magic + version
    out.extend_from_slice(b"FXGD");
    out.extend_from_slice(&2u32.to_le_bytes()); // version 2 (enhanced)

    // Dimensions
    out.extend_from_slice(&grid.rows.to_le_bytes());
    out.extend_from_slice(&grid.cols.to_le_bytes());
    out.extend_from_slice(&grid.fixed_rows.to_le_bytes());
    out.extend_from_slice(&grid.fixed_cols.to_le_bytes());

    if export_includes_data(scope) {
        // Data: write each cell text
        for r in 0..grid.rows {
            for c in 0..grid.cols {
                let text = grid.cells.get_text(r, c);
                let len = text.len() as u32;
                out.extend_from_slice(&len.to_le_bytes());
                out.extend_from_slice(text.as_bytes());
            }
        }
    }

    if export_includes_format(scope) {
        // Format section

        // Row heights
        let custom_heights: Vec<_> = (0..grid.rows)
            .filter(|r| grid.row_heights.contains_key(r))
            .collect();
        out.extend_from_slice(&(custom_heights.len() as u32).to_le_bytes());
        for r in custom_heights {
            out.extend_from_slice(&r.to_le_bytes());
            out.extend_from_slice(&grid.get_row_height(r).to_le_bytes());
        }

        // Col widths
        let custom_widths: Vec<_> = (0..grid.cols)
            .filter(|c| grid.col_widths.contains_key(c))
            .collect();
        out.extend_from_slice(&(custom_widths.len() as u32).to_le_bytes());
        for c in custom_widths {
            out.extend_from_slice(&c.to_le_bytes());
            out.extend_from_slice(&grid.get_col_width(c).to_le_bytes());
        }

        // Cell styles (v2)
        let styles: Vec<_> = grid.cell_styles.iter().collect();
        out.extend_from_slice(&(styles.len() as u32).to_le_bytes());
        for (&(r, c), style) in &styles {
            out.extend_from_slice(&r.to_le_bytes());
            out.extend_from_slice(&c.to_le_bytes());
            out.extend_from_slice(&style.back_color.unwrap_or(0).to_le_bytes());
            out.extend_from_slice(&style.fore_color.unwrap_or(0).to_le_bytes());
            out.extend_from_slice(&style.alignment.unwrap_or(-1).to_le_bytes());
            let flags: u8 = (if style.back_color.is_some() { 1 } else { 0 })
                | (if style.fore_color.is_some() { 2 } else { 0 })
                | (if style.alignment.is_some() { 4 } else { 0 })
                | (if style.font_bold.unwrap_or(false) {
                    8
                } else {
                    0
                })
                | (if style.font_italic.unwrap_or(false) {
                    16
                } else {
                    0
                })
                | (if style.font_underline.unwrap_or(false) {
                    32
                } else {
                    0
                })
                | (if style.font_strikethrough.unwrap_or(false) {
                    64
                } else {
                    0
                });
            out.push(flags);
            let font_size_bits = style.font_size.unwrap_or(0.0).to_le_bytes();
            out.extend_from_slice(&font_size_bits);
        }

        // Column properties (v2)
        out.extend_from_slice(&(grid.cols as u32).to_le_bytes());
        for c in 0..grid.cols {
            let cp = &grid.columns[c as usize];
            out.extend_from_slice(&cp.alignment.to_le_bytes());
            out.extend_from_slice(&cp.data_type.to_le_bytes());
            let fmt_bytes = cp.format.as_bytes();
            out.extend_from_slice(&(fmt_bytes.len() as u32).to_le_bytes());
            out.extend_from_slice(fmt_bytes);
        }

        // Row properties (v2)
        let rprops: Vec<_> = grid.row_props.iter().collect();
        out.extend_from_slice(&(rprops.len() as u32).to_le_bytes());
        for (&r, rp) in &rprops {
            out.extend_from_slice(&r.to_le_bytes());
            out.extend_from_slice(&rp.outline_level.to_le_bytes());
            out.push(if rp.is_subtotal { 1 } else { 0 });
            out.push(if rp.is_collapsed { 1 } else { 0 });
        }

        // Span state (v2) - span rows/cols flags
        let span_entries: Vec<_> = grid.span.span_rows.iter().collect();
        out.extend_from_slice(&(span_entries.len() as u32).to_le_bytes());
        for (&r, &v) in &span_entries {
            out.extend_from_slice(&r.to_le_bytes());
            out.push(if v { 1 } else { 0 });
        }
    }

    out
}

fn load_binary(grid: &mut VolvoxGrid, data: &[u8], scope: i32) {
    if data.len() < 24 {
        return;
    }
    if &data[0..4] != b"FXGD" {
        return;
    }

    let version = u32::from_le_bytes(data[4..8].try_into().unwrap_or([0; 4]));
    let mut pos = 8; // skip magic + version
    let rows = read_i32(data, &mut pos);
    let cols = read_i32(data, &mut pos);
    let fixed_rows = read_i32(data, &mut pos);
    let fixed_cols = read_i32(data, &mut pos);

    grid.set_rows(rows);
    grid.set_cols(cols);
    grid.fixed_rows = fixed_rows;
    grid.fixed_cols = fixed_cols;

    if export_includes_data(scope) {
        for r in 0..rows {
            for c in 0..cols {
                if pos + 4 > data.len() {
                    return;
                }
                let len = read_u32(data, &mut pos) as usize;
                if pos + len > data.len() {
                    return;
                }
                let text = String::from_utf8_lossy(&data[pos..pos + len]).to_string();
                pos += len;
                grid.cells.set_text(r, c, text);
            }
        }
    }

    if export_includes_format(scope) {
        // Row heights
        if pos + 4 > data.len() {
            grid.layout.invalidate();
            grid.mark_dirty();
            return;
        }
        let n_heights = read_u32(data, &mut pos) as usize;
        for _ in 0..n_heights {
            if pos + 8 > data.len() {
                break;
            }
            let r = read_i32(data, &mut pos);
            let h = read_i32(data, &mut pos);
            grid.set_row_height(r, h);
        }

        // Col widths
        if pos + 4 > data.len() {
            grid.layout.invalidate();
            grid.mark_dirty();
            return;
        }
        let n_widths = read_u32(data, &mut pos) as usize;
        for _ in 0..n_widths {
            if pos + 8 > data.len() {
                break;
            }
            let c = read_i32(data, &mut pos);
            let w = read_i32(data, &mut pos);
            grid.set_col_width(c, w);
        }

        // V2 extended format sections
        if version >= 2 {
            // Cell styles
            if pos + 4 <= data.len() {
                let n_styles = read_u32(data, &mut pos) as usize;
                for _ in 0..n_styles {
                    if pos + 21 > data.len() {
                        break;
                    } // 4+4+4+4+4+1+4 = 25 min
                    let r = read_i32(data, &mut pos);
                    let c = read_i32(data, &mut pos);
                    let back = read_u32(data, &mut pos);
                    let fore = read_u32(data, &mut pos);
                    let align = read_i32(data, &mut pos);
                    let flags = if pos < data.len() {
                        let v = data[pos];
                        pos += 1;
                        v
                    } else {
                        0
                    };
                    let font_size = if pos + 4 <= data.len() {
                        read_f32(data, &mut pos)
                    } else {
                        0.0
                    };

                    let style = crate::style::CellStylePatch {
                        back_color: if flags & 1 != 0 { Some(back) } else { None },
                        fore_color: if flags & 2 != 0 { Some(fore) } else { None },
                        alignment: if flags & 4 != 0 { Some(align) } else { None },
                        font_bold: if flags & 8 != 0 { Some(true) } else { None },
                        font_italic: if flags & 16 != 0 { Some(true) } else { None },
                        font_underline: if flags & 32 != 0 { Some(true) } else { None },
                        font_strikethrough: if flags & 64 != 0 { Some(true) } else { None },
                        font_size: if font_size > 0.0 {
                            Some(font_size)
                        } else {
                            None
                        },
                        ..Default::default()
                    };
                    grid.cell_styles.insert((r, c), style);
                }
            }

            // Column properties
            if pos + 4 <= data.len() {
                let n_cols = read_u32(data, &mut pos) as i32;
                for c in 0..n_cols.min(grid.cols) {
                    if pos + 8 > data.len() {
                        break;
                    }
                    let alignment = read_i32(data, &mut pos);
                    let data_type = read_i32(data, &mut pos);
                    if pos + 4 > data.len() {
                        break;
                    }
                    let fmt_len = read_u32(data, &mut pos) as usize;
                    let format = if pos + fmt_len <= data.len() {
                        let s = String::from_utf8_lossy(&data[pos..pos + fmt_len]).to_string();
                        pos += fmt_len;
                        s
                    } else {
                        pos = data.len();
                        String::new()
                    };
                    if (c as usize) < grid.columns.len() {
                        grid.columns[c as usize].alignment = alignment;
                        grid.columns[c as usize].data_type = data_type;
                        grid.columns[c as usize].format = format;
                    }
                }
            }

            // Row properties
            if pos + 4 <= data.len() {
                let n_rprops = read_u32(data, &mut pos) as usize;
                for _ in 0..n_rprops {
                    if pos + 6 > data.len() {
                        break;
                    } // 4+4+1+1
                    let r = read_i32(data, &mut pos);
                    let outline_level = read_i32(data, &mut pos);
                    let is_subtotal = if pos < data.len() {
                        let v = data[pos];
                        pos += 1;
                        v != 0
                    } else {
                        false
                    };
                    let is_collapsed = if pos < data.len() {
                        let v = data[pos];
                        pos += 1;
                        v != 0
                    } else {
                        false
                    };
                    let rp = grid.row_props.entry(r).or_default();
                    rp.outline_level = outline_level;
                    rp.is_subtotal = is_subtotal;
                    rp.is_collapsed = is_collapsed;
                }
            }

            // Span state
            if pos + 4 <= data.len() {
                let n_span = read_u32(data, &mut pos) as usize;
                for _ in 0..n_span {
                    if pos + 5 > data.len() {
                        break;
                    }
                    let r = read_i32(data, &mut pos);
                    let span_val = if pos < data.len() {
                        let v = data[pos];
                        pos += 1;
                        v != 0
                    } else {
                        false
                    };
                    grid.span.span_rows.insert(r, span_val);
                }
            }
        }
    }

    grid.layout.invalidate();
    grid.mark_dirty();
}

fn read_i32(data: &[u8], pos: &mut usize) -> i32 {
    let v = i32::from_le_bytes(data[*pos..*pos + 4].try_into().unwrap_or([0; 4]));
    *pos += 4;
    v
}

fn read_u32(data: &[u8], pos: &mut usize) -> u32 {
    let v = u32::from_le_bytes(data[*pos..*pos + 4].try_into().unwrap_or([0; 4]));
    *pos += 4;
    v
}

fn read_f32(data: &[u8], pos: &mut usize) -> f32 {
    let v = f32::from_le_bytes(data[*pos..*pos + 4].try_into().unwrap_or([0; 4]));
    *pos += 4;
    v
}

fn save_text(grid: &VolvoxGrid, separator: &str, scope: i32) -> Vec<u8> {
    if !export_includes_data(scope) {
        return Vec::new();
    }

    let mut out = String::new();
    for r in 0..grid.rows {
        if r > 0 {
            out.push('\n');
        }
        for c in 0..grid.cols {
            if c > 0 {
                out.push_str(separator);
            }
            let text = grid.cells.get_text(r, c);
            // Quote if contains separator or newline
            if text.contains(separator)
                || text.contains('\n')
                || text.contains('\r')
                || text.contains('"')
            {
                out.push('"');
                out.push_str(&text.replace('"', "\"\""));
                out.push('"');
            } else {
                out.push_str(text);
            }
        }
    }
    out.into_bytes()
}

fn load_text(grid: &mut VolvoxGrid, data: &[u8], separator: &str, scope: i32) {
    if !export_includes_data(scope) {
        return;
    }

    let text = String::from_utf8_lossy(data);
    let rows = parse_delimited_text(&text, separator);
    if rows.is_empty() {
        return;
    }

    let cols = rows
        .iter()
        .map(|r| r.len() as i32)
        .max()
        .unwrap_or(0)
        .max(1);
    grid.set_rows(rows.len() as i32);
    grid.set_cols(cols.max(grid.cols));

    for (r, row) in rows.iter().enumerate() {
        for (c, cell) in row.iter().enumerate() {
            grid.cells.set_text(r as i32, c as i32, cell.clone());
        }
    }

    grid.layout.invalidate();
    grid.mark_dirty();
}

fn parse_delimited_text(input: &str, separator: &str) -> Vec<Vec<String>> {
    let sep = if separator.is_empty() {
        b"\t".to_vec()
    } else {
        separator.as_bytes().to_vec()
    };

    let mut rows: Vec<Vec<String>> = Vec::new();
    let mut row: Vec<String> = Vec::new();
    let mut field: Vec<u8> = Vec::new();
    let bytes = input.as_bytes();
    let mut i = 0usize;
    let mut in_quotes = false;

    while i < bytes.len() {
        if in_quotes {
            if bytes[i] == b'"' {
                if i + 1 < bytes.len() && bytes[i + 1] == b'"' {
                    field.push(b'"');
                    i += 2;
                } else {
                    in_quotes = false;
                    i += 1;
                }
            } else {
                field.push(bytes[i]);
                i += 1;
            }
            continue;
        }

        if bytes[i] == b'"' {
            in_quotes = true;
            i += 1;
            continue;
        }

        if !sep.is_empty() && i + sep.len() <= bytes.len() && bytes[i..].starts_with(&sep) {
            row.push(String::from_utf8_lossy(&field).to_string());
            field.clear();
            i += sep.len();
            continue;
        }

        if bytes[i] == b'\n' {
            row.push(String::from_utf8_lossy(&field).to_string());
            field.clear();
            rows.push(std::mem::take(&mut row));
            i += 1;
            continue;
        }

        if bytes[i] == b'\r' {
            row.push(String::from_utf8_lossy(&field).to_string());
            field.clear();
            rows.push(std::mem::take(&mut row));
            i += 1;
            if i < bytes.len() && bytes[i] == b'\n' {
                i += 1;
            }
            continue;
        }

        field.push(bytes[i]);
        i += 1;
    }

    let ends_with_row_break = input.ends_with('\n') || input.ends_with('\r');
    if !field.is_empty() || !row.is_empty() || (!ends_with_row_break && !input.is_empty()) {
        row.push(String::from_utf8_lossy(&field).to_string());
        rows.push(row);
    }

    rows
}

/// Save grid as SpreadsheetML XML (Excel 2003 XML format).
///
/// This produces a simple XML Spreadsheet that Excel, LibreOffice, and
/// Google Sheets can open directly. No external dependencies required.
fn save_excel(grid: &VolvoxGrid, scope: i32) -> Vec<u8> {
    let mut xml = String::new();
    xml.push_str("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
    xml.push_str("<?mso-application progid=\"Excel.Sheet\"?>\n");
    xml.push_str("<Workbook xmlns=\"urn:schemas-microsoft-com:office:spreadsheet\"\n");
    xml.push_str(" xmlns:ss=\"urn:schemas-microsoft-com:office:spreadsheet\">\n");

    // Styles
    xml.push_str(" <Styles>\n");
    xml.push_str("  <Style ss:ID=\"Default\" ss:Name=\"Normal\">\n");
    xml.push_str("   <Alignment ss:Vertical=\"Center\"/>\n");
    xml.push_str("  </Style>\n");
    xml.push_str("  <Style ss:ID=\"Header\">\n");
    xml.push_str("   <Font ss:Bold=\"1\"/>\n");
    xml.push_str("   <Interior ss:Color=\"#C0C0C0\" ss:Pattern=\"Solid\"/>\n");
    xml.push_str("  </Style>\n");
    xml.push_str("  <Style ss:ID=\"Bold\">\n");
    xml.push_str("   <Font ss:Bold=\"1\"/>\n");
    xml.push_str("  </Style>\n");
    xml.push_str("  <Style ss:ID=\"Number\">\n");
    xml.push_str("   <NumberFormat ss:Format=\"#,##0.00\"/>\n");
    xml.push_str("  </Style>\n");
    xml.push_str(" </Styles>\n");

    xml.push_str(" <Worksheet ss:Name=\"Sheet1\">\n");
    xml.push_str("  <Table");
    xml.push_str(&format!(
        " ss:DefaultRowHeight=\"{}\"",
        grid.default_row_height
    ));
    xml.push_str(&format!(
        " ss:DefaultColumnWidth=\"{}\"",
        grid.default_col_width
    ));
    xml.push_str(">\n");

    if export_includes_data(scope) {
        // Write column widths
        for c in 0..grid.cols {
            let w = grid.get_col_width(c);
            xml.push_str(&format!("   <Column ss:Width=\"{}\"/>\n", w));
        }

        // Write rows
        for r in 0..grid.rows {
            let h = grid.get_row_height(r);
            let is_fixed = r < grid.fixed_rows;

            xml.push_str(&format!("   <Row ss:Height=\"{}\"", h));
            xml.push_str(">\n");

            for c in 0..grid.cols {
                let text = grid.cells.get_text(r, c);

                // Determine data type
                let cleaned = text.replace([',', '$', ' '], "");
                let is_number = !cleaned.is_empty() && cleaned.parse::<f64>().is_ok();

                let style_id = if is_fixed {
                    " ss:StyleID=\"Header\""
                } else if grid
                    .cell_styles
                    .get(&(r, c))
                    .map_or(false, |s| s.font_bold == Some(true))
                {
                    " ss:StyleID=\"Bold\""
                } else if is_number {
                    " ss:StyleID=\"Number\""
                } else {
                    ""
                };

                if text.is_empty() {
                    xml.push_str(&format!(
                        "    <Cell{}><Data ss:Type=\"String\"></Data></Cell>\n",
                        style_id
                    ));
                } else if is_number {
                    let val = cleaned.parse::<f64>().unwrap_or(0.0);
                    xml.push_str(&format!(
                        "    <Cell{}><Data ss:Type=\"Number\">{}</Data></Cell>\n",
                        style_id, val
                    ));
                } else {
                    let escaped = xml_escape(text);
                    xml.push_str(&format!(
                        "    <Cell{}><Data ss:Type=\"String\">{}</Data></Cell>\n",
                        style_id, escaped
                    ));
                }
            }

            xml.push_str("   </Row>\n");
        }
    }

    xml.push_str("  </Table>\n");
    xml.push_str(" </Worksheet>\n");
    xml.push_str("</Workbook>\n");

    xml.into_bytes()
}

/// Escape special XML characters in text.
fn xml_escape(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for ch in s.chars() {
        match ch {
            '&' => out.push_str("&amp;"),
            '<' => out.push_str("&lt;"),
            '>' => out.push_str("&gt;"),
            '"' => out.push_str("&quot;"),
            '\'' => out.push_str("&apos;"),
            _ => out.push(ch),
        }
    }
    out
}

/// Determine the grid format from a URL file extension.
///
/// Returns a format code compatible with `load_grid()`:
/// - 1 = binary (FXGD)
/// - 2 = tab-separated text (.txt, .tab)
/// - 3 = comma-separated (.csv)
/// - 5 = Excel (.xls, .xlsx)
/// - -1 = unknown
pub fn format_from_url(url: &str) -> i32 {
    let lower = url.to_lowercase();
    if lower.ends_with(".fxgd") || lower.ends_with(".fxg") {
        pb::ExportFormat::ExportBinary as i32
    } else if lower.ends_with(".txt") || lower.ends_with(".tab") || lower.ends_with(".tsv") {
        pb::ExportFormat::ExportTsv as i32
    } else if lower.ends_with(".csv") {
        pb::ExportFormat::ExportCsv as i32
    } else if lower.ends_with(".xls") || lower.ends_with(".xlsx") {
        pb::ExportFormat::ExportXlsx as i32
    } else {
        -1
    }
}

/// Load grid data from bytes fetched from a URL.
///
/// This is the engine-side implementation of `LoadGridURL`.
/// The actual URL fetching is platform-specific and must be done by the
/// host/plugin layer. The host fetches the bytes, then calls this function.
///
/// `url` is used to auto-detect the format if `format` is -1.
/// Returns `true` on success.
pub fn load_grid_url(
    grid: &mut VolvoxGrid,
    url: &str,
    data: &[u8],
    format: i32,
    scope: i32,
) -> bool {
    let fmt = if format < 0 {
        format_from_url(url)
    } else {
        format
    };
    if fmt < 0 {
        return false;
    }
    load_grid(grid, data, fmt, scope);
    true
}

/// Archive operations for saving/loading named grid snapshots.
///
/// `action`:
/// - 1 = SAVE: upsert the named entry and return the updated archive blob
/// - 2 = LOAD: deserialize the named entry from the provided archive blob
/// - 3 = DELETE: remove the named entry and return the updated archive blob
/// - 4 = LIST: return the entry names in the provided archive blob
///
/// Returns `(data_bytes, name_list)`.
pub fn archive(
    grid: &mut VolvoxGrid,
    name: &str,
    action: i32,
    data: &[u8],
) -> (Vec<u8>, Vec<String>) {
    let mut entries = parse_archive_blob(data).unwrap_or_default();
    let requested_name = name;
    let norm_name = if name.is_empty() { "grid" } else { name };

    match action {
        a if a == pb::archive_request::Action::Save as i32 => {
            let grid_data = save_grid(
                grid,
                pb::ExportFormat::ExportBinary as i32,
                pb::ExportScope::ExportAll as i32,
            );
            let now = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .map(|d| d.as_secs() as i64)
                .unwrap_or(0);
            let original = grid_data.len() as u32;
            let compressed = original;

            if let Some(existing) = entries.iter_mut().find(|e| e.name == norm_name) {
                existing.data = grid_data;
                existing.modified_unix = now;
                existing.original_size = original;
                existing.compressed_size = compressed;
            } else {
                entries.push(ArchiveEntry {
                    name: norm_name.to_string(),
                    data: grid_data,
                    modified_unix: now,
                    original_size: original,
                    compressed_size: compressed,
                });
            }

            let names = entries.iter().map(|e| e.name.clone()).collect();
            (serialize_archive_blob(&entries), names)
        }
        a if a == pb::archive_request::Action::Load as i32 => {
            let maybe_entry = if requested_name.is_empty() {
                entries.first()
            } else {
                entries.iter().find(|e| e.name == norm_name)
            };
            if let Some(entry) = maybe_entry {
                load_grid(
                    grid,
                    &entry.data,
                    pb::ExportFormat::ExportBinary as i32,
                    pb::ExportScope::ExportAll as i32,
                );
            } else if entries.is_empty() && !data.is_empty() {
                // Backward compatibility: treat payload as raw SaveGrid binary.
                load_grid(
                    grid,
                    data,
                    pb::ExportFormat::ExportBinary as i32,
                    pb::ExportScope::ExportAll as i32,
                );
            }
            let names = entries.iter().map(|e| e.name.clone()).collect();
            (Vec::new(), names)
        }
        a if a == pb::archive_request::Action::Delete as i32 => {
            entries.retain(|e| e.name != norm_name);
            let names = entries.iter().map(|e| e.name.clone()).collect();
            (serialize_archive_blob(&entries), names)
        }
        a if a == pb::archive_request::Action::List as i32 => {
            let names = entries.iter().map(|e| e.name.clone()).collect();
            (Vec::new(), names)
        }
        _ => (Vec::new(), Vec::new()),
    }
}

pub fn archive_info(data: &[u8]) -> (Vec<String>, Vec<i32>) {
    let entries = parse_archive_blob(data).unwrap_or_default();
    let names = entries.iter().map(|e| e.name.clone()).collect();
    let sizes = entries
        .iter()
        .map(|e| e.original_size.min(i32::MAX as u32) as i32)
        .collect();
    (names, sizes)
}

#[derive(Clone, Debug, Default)]
struct ArchiveEntry {
    name: String,
    data: Vec<u8>,
    modified_unix: i64,
    original_size: u32,
    compressed_size: u32,
}

const ARCHIVE_MAGIC: &[u8] = b"FXAR1\0";

fn parse_archive_blob(data: &[u8]) -> Option<Vec<ArchiveEntry>> {
    if data.is_empty() {
        return Some(Vec::new());
    }
    if data.len() < ARCHIVE_MAGIC.len() + 4 || &data[..ARCHIVE_MAGIC.len()] != ARCHIVE_MAGIC {
        return None;
    }

    let mut pos = ARCHIVE_MAGIC.len();
    let count = read_u32_checked(data, &mut pos)? as usize;
    let mut entries = Vec::with_capacity(count);

    for _ in 0..count {
        let name_len = read_u16_checked(data, &mut pos)? as usize;
        let original_size = read_u32_checked(data, &mut pos)?;
        let compressed_size = read_u32_checked(data, &mut pos)?;
        let modified_unix = read_i64_checked(data, &mut pos)?;
        let data_len = read_u32_checked(data, &mut pos)? as usize;

        if pos + name_len > data.len() {
            return None;
        }
        let name = String::from_utf8_lossy(&data[pos..pos + name_len]).to_string();
        pos += name_len;

        if pos + data_len > data.len() {
            return None;
        }
        let payload = data[pos..pos + data_len].to_vec();
        pos += data_len;

        entries.push(ArchiveEntry {
            name,
            data: payload,
            modified_unix,
            original_size,
            compressed_size,
        });
    }

    Some(entries)
}

fn serialize_archive_blob(entries: &[ArchiveEntry]) -> Vec<u8> {
    let mut out = Vec::new();
    out.extend_from_slice(ARCHIVE_MAGIC);
    out.extend_from_slice(&(entries.len() as u32).to_le_bytes());
    for entry in entries {
        let name_bytes = entry.name.as_bytes();
        let name_len = name_bytes.len().min(u16::MAX as usize) as u16;
        let payload_len = entry.data.len().min(u32::MAX as usize) as u32;
        out.extend_from_slice(&name_len.to_le_bytes());
        out.extend_from_slice(&entry.original_size.to_le_bytes());
        out.extend_from_slice(&entry.compressed_size.to_le_bytes());
        out.extend_from_slice(&entry.modified_unix.to_le_bytes());
        out.extend_from_slice(&payload_len.to_le_bytes());
        out.extend_from_slice(&name_bytes[..name_len as usize]);
        out.extend_from_slice(&entry.data[..payload_len as usize]);
    }
    out
}

fn read_u16_checked(data: &[u8], pos: &mut usize) -> Option<u16> {
    if *pos + 2 > data.len() {
        return None;
    }
    let v = u16::from_le_bytes([data[*pos], data[*pos + 1]]);
    *pos += 2;
    Some(v)
}

fn read_u32_checked(data: &[u8], pos: &mut usize) -> Option<u32> {
    if *pos + 4 > data.len() {
        return None;
    }
    let v = u32::from_le_bytes(data[*pos..*pos + 4].try_into().ok()?);
    *pos += 4;
    Some(v)
}

fn read_i64_checked(data: &[u8], pos: &mut usize) -> Option<i64> {
    if *pos + 8 > data.len() {
        return None;
    }
    let v = i64::from_le_bytes(data[*pos..*pos + 8].try_into().ok()?);
    *pos += 8;
    Some(v)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn grid_with_cell() -> VolvoxGrid {
        let mut grid = VolvoxGrid::new(1, 640, 480, 1, 1, 0, 0);
        grid.cells.set_text(0, 0, "value".to_string());
        grid
    }

    #[test]
    fn save_grid_rejects_unspecified_format_or_scope() {
        let grid = grid_with_cell();

        assert!(save_grid(
            &grid,
            pb::ExportFormat::Unspecified as i32,
            pb::ExportScope::ExportAll as i32,
        )
        .is_empty());
        assert!(save_grid(
            &grid,
            pb::ExportFormat::ExportBinary as i32,
            pb::ExportScope::Unspecified as i32,
        )
        .is_empty());
    }

    #[test]
    fn archive_unspecified_action_does_not_save() {
        let mut grid = grid_with_cell();

        let (data, names) = archive(
            &mut grid,
            "snapshot",
            pb::archive_request::Action::Unspecified as i32,
            &[],
        );

        assert!(data.is_empty());
        assert!(names.is_empty());
    }
}
