//! VolvoxGrid Smoke Test
//!
//! Loads the plugin via synurang-host PluginHost, exercises basic v1 RPCs:
//! Create, GetConfig, UpdateCells, GetCells, Sort, Configure, Select, Destroy

use prost::Message;
use std::path::Path;
use synurang_host::{Error, FfiError, PluginHost};

use volvoxgrid_engine::proto::volvoxgrid::v1::*;

const SERVICE: &str = "VolvoxGridService";
const DEFAULT_PLUGIN_BASENAME: &str = if cfg!(target_os = "windows") {
    "volvoxgrid_plugin.dll"
} else if cfg!(target_os = "macos") {
    "libvolvoxgrid_plugin.dylib"
} else {
    "libvolvoxgrid_plugin.so"
};

fn resolve_default_plugin_path() -> String {
    let candidates = [
        format!("target/debug/{}", DEFAULT_PLUGIN_BASENAME),
        format!("../target/debug/{}", DEFAULT_PLUGIN_BASENAME),
        format!("../plugin/target/debug/{}", DEFAULT_PLUGIN_BASENAME),
    ];
    for candidate in candidates {
        if Path::new(&candidate).exists() {
            return candidate;
        }
    }
    format!("target/debug/{}", DEFAULT_PLUGIN_BASENAME)
}

fn invoke(plugin: &PluginHost, method: &str, req: &[u8]) -> Vec<u8> {
    match plugin.invoke(SERVICE, method, req) {
        Ok(data) => data,
        Err(e) => panic!("RPC {} failed: {}", method, e),
    }
}

fn expect_plugin_error(plugin: &PluginHost, method: &str, req: &[u8]) -> FfiError {
    match plugin.invoke(SERVICE, method, req) {
        Ok(_) => panic!("RPC {} unexpectedly succeeded", method),
        Err(Error::PluginError(err)) => err,
        Err(e) => panic!("RPC {} failed with unexpected host error: {}", method, e),
    }
}

fn main() {
    let plugin_path = std::env::args()
        .nth(1)
        .unwrap_or_else(resolve_default_plugin_path);

    println!("Loading plugin: {}", plugin_path);
    let plugin = PluginHost::load(&plugin_path).expect("Failed to load plugin");
    println!("Plugin loaded successfully.");

    // 1. Create — returns CreateResponse with GridHandle
    let req = CreateRequest {
        viewport_width: 800,
        viewport_height: 600,
        scale: 0.0,
        config: Some(GridConfig {
            layout: Some(LayoutConfig {
                rows: Some(50),
                cols: Some(5),
                fixed_rows: Some(0),
                fixed_cols: Some(0),
                ..Default::default()
            }),
            indicators: Some(IndicatorsConfig {
                col_top: Some(ColIndicatorConfig {
                    visible: Some(true),
                    band_rows: Some(1),
                    mode_bits: Some(
                        (ColIndicatorCellMode::ColIndicatorCellHeaderText as u32)
                            | (ColIndicatorCellMode::ColIndicatorCellSortGlyph as u32),
                    ),
                    ..Default::default()
                }),
                row_start: Some(RowIndicatorConfig {
                    visible: Some(false),
                    width: Some(35),
                    mode_bits: Some(
                        (RowIndicatorMode::RowIndicatorCurrent as u32)
                            | (RowIndicatorMode::RowIndicatorSelection as u32),
                    ),
                    ..Default::default()
                }),
                ..Default::default()
            }),
            ..Default::default()
        }),
    };
    let resp_bytes = invoke(
        &plugin,
        "/volvoxgrid.v1.VolvoxGridService/Create",
        &req.encode_to_vec(),
    );
    let create = CreateResponse::decode(resp_bytes.as_slice()).expect("decode CreateResponse");
    let grid_id = create.handle.expect("create handle should be present").id;
    println!("Created grid: id={}", grid_id);

    // 2. GetConfig — verify rows/cols
    let handle = GridHandle { id: grid_id };
    let resp_bytes = invoke(
        &plugin,
        "/volvoxgrid.v1.VolvoxGridService/GetConfig",
        &handle.encode_to_vec(),
    );
    let config = GridConfig::decode(resp_bytes.as_slice()).unwrap();
    let layout = config.layout.expect("layout should be present");
    assert_eq!(layout.rows.unwrap(), 50, "Expected 50 rows");
    assert_eq!(layout.cols.unwrap(), 5, "Expected 5 cols");
    println!(
        "Grid dimensions: {}x{}",
        layout.rows.unwrap(),
        layout.cols.unwrap()
    );

    // 3. Structured FFI error — empty font payload should round-trip as FfiError
    let ffi_error = expect_plugin_error(
        &plugin,
        "/volvoxgrid.v1.VolvoxGridService/LoadFontData",
        &LoadFontDataRequest {
            data: Vec::new(),
            font_name: String::new(),
            font_names: Vec::new(),
        }
        .encode_to_vec(),
    );
    assert_eq!(
        ffi_error.code,
        ErrorCode::ErrorInvalidArgument as i32,
        "Expected VolvoxGrid invalid-argument error code"
    );
    assert_eq!(ffi_error.grpc_code, 3, "Expected gRPC INVALID_ARGUMENT");
    assert_eq!(ffi_error.message, "font data is empty");
    assert!(
        !ffi_error.payload.is_empty(),
        "Expected serialized core.v1.Error payload"
    );
    println!(
        "Structured FFI error verified: code={}, grpc_code={}, message={}",
        ffi_error.code, ffi_error.grpc_code, ffi_error.message
    );

    // 4. DefineColumns — set captions for the top column-indicator band
    let headers = ["Product", "Category", "Sales", "Quarter", "Region"];
    let columns: Vec<ColumnDef> = headers
        .iter()
        .enumerate()
        .map(|(c, h)| ColumnDef {
            index: c as i32,
            key: Some(h.to_lowercase()),
            caption: Some(h.to_string()),
            ..Default::default()
        })
        .collect();
    let req = DefineColumnsRequest { grid_id, columns };
    invoke(
        &plugin,
        "/volvoxgrid.v1.VolvoxGridService/DefineColumns",
        &req.encode_to_vec(),
    );
    println!("Defined {} column captions.", headers.len());

    // 5. UpdateCells — data rows (batch all 250 cells in one call)
    let products = ["Widget A", "Widget B", "Gadget X", "Gadget Y", "Tool Z"];
    let categories = [
        "Electronics",
        "Electronics",
        "Hardware",
        "Hardware",
        "Tools",
    ];
    let regions = ["North", "South", "East", "West"];
    let mut data_cells = Vec::with_capacity(250);
    for r in 0..50i32 {
        for c in 0..5i32 {
            let text = match c {
                0 => products[(r % 5) as usize].to_string(),
                1 => categories[(r % 5) as usize].to_string(),
                2 => format!("{}", (r + 1) * 123 + 456),
                3 => format!("Q{}", ((r + 1) % 4) + 1),
                4 => regions[(r % 4) as usize].to_string(),
                _ => unreachable!(),
            };
            data_cells.push(CellUpdate {
                row: r,
                col: c,
                value: Some(CellValue {
                    value: Some(cell_value::Value::Text(text)),
                }),
                ..Default::default()
            });
        }
    }
    let req = UpdateCellsRequest {
        grid_id,
        cells: data_cells,
        atomic: false,
    };
    invoke(
        &plugin,
        "/volvoxgrid.v1.VolvoxGridService/UpdateCells",
        &req.encode_to_vec(),
    );
    println!("Populated 50 data rows.");

    // 6. GetCells — verify the first data row
    let req = GetCellsRequest {
        grid_id,
        row1: 0,
        col1: 0,
        row2: 0,
        col2: 0,
        include_style: false,
        include_checked: false,
        include_typed: false,
    };
    let resp_bytes = invoke(
        &plugin,
        "/volvoxgrid.v1.VolvoxGridService/GetCells",
        &req.encode_to_vec(),
    );
    let cells_resp = CellsResponse::decode(resp_bytes.as_slice()).unwrap();
    let cell = &cells_resp.cells[0];
    if let Some(CellValue {
        value: Some(cell_value::Value::Text(ref t)),
    }) = cell.value
    {
        assert_eq!(t, "Widget A", "Cell(0,0) mismatch: got '{}'", t);
    } else {
        panic!("Expected text value for data cell");
    }
    println!("GetCells verified.");

    // 7. Sort
    let req = SortRequest {
        grid_id,
        sort_columns: vec![SortColumn {
            col: 0,
            order: Some(SortOrder::SortAscending as i32),
            r#type: Some(SortType::Auto as i32),
        }],
    };
    invoke(
        &plugin,
        "/volvoxgrid.v1.VolvoxGridService/Sort",
        &req.encode_to_vec(),
    );
    println!("Sort complete.");

    // 8. GetCells after sort
    let req = GetCellsRequest {
        grid_id,
        row1: 0,
        col1: 0,
        row2: 0,
        col2: 0,
        include_style: false,
        include_checked: false,
        include_typed: false,
    };
    let resp_bytes = invoke(
        &plugin,
        "/volvoxgrid.v1.VolvoxGridService/GetCells",
        &req.encode_to_vec(),
    );
    let cells_resp = CellsResponse::decode(resp_bytes.as_slice()).unwrap();
    let cell = &cells_resp.cells[0];
    if let Some(CellValue {
        value: Some(cell_value::Value::Text(ref t)),
    }) = cell.value
    {
        println!("After sort, row 1 col 0 = \"{}\"", t);
    }

    // 9. Configure selection mode + Select
    let req = ConfigureRequest {
        grid_id,
        config: Some(GridConfig {
            selection: Some(SelectionConfig {
                mode: Some(SelectionMode::SelectionByRow as i32),
                ..Default::default()
            }),
            ..Default::default()
        }),
    };
    invoke(
        &plugin,
        "/volvoxgrid.v1.VolvoxGridService/Configure",
        &req.encode_to_vec(),
    );

    let req = SelectRequest {
        grid_id,
        active_row: 2,
        active_col: 0,
        ranges: vec![CellRange {
            row1: 2,
            col1: 0,
            row2: 5,
            col2: 4,
        }],
        show: None,
    };
    invoke(
        &plugin,
        "/volvoxgrid.v1.VolvoxGridService/Select",
        &req.encode_to_vec(),
    );
    println!("Selection set: rows 2-5.");

    // 10. Destroy
    let handle = GridHandle { id: grid_id };
    invoke(
        &plugin,
        "/volvoxgrid.v1.VolvoxGridService/Destroy",
        &handle.encode_to_vec(),
    );
    println!("Grid destroyed.");

    plugin.close();
    println!("\nAll smoke tests passed!");
}
