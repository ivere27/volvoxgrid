//! VolvoxGrid Smoke Test
//!
//! Loads the plugin via synurang-host PluginHost, exercises basic v1 RPCs:
//! Create, GetConfig, UpdateCells, GetCells, Sort, Configure, Select, Destroy

use prost::Message;
use synurang_host::PluginHost;
use std::path::Path;

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

fn main() {
    let plugin_path = std::env::args()
        .nth(1)
        .unwrap_or_else(resolve_default_plugin_path);

    println!("Loading plugin: {}", plugin_path);
    let plugin = PluginHost::load(&plugin_path).expect("Failed to load plugin");
    println!("Plugin loaded successfully.");

    // 1. Create — returns GridHandle
    let req = CreateRequest {
        viewport_width: 800,
        viewport_height: 600,
        scale: 0.0,
        config: Some(GridConfig {
            layout: Some(LayoutConfig {
                rows: Some(51),
                cols: Some(5),
                fixed_rows: Some(1),
                fixed_cols: Some(0),
                ..Default::default()
            }),
            ..Default::default()
        }),
    };
    let resp_bytes = invoke(&plugin, "/volvoxgrid.v1.VolvoxGridService/Create", &req.encode_to_vec());
    let handle = GridHandle::decode(resp_bytes.as_slice()).expect("decode GridHandle");
    let grid_id = handle.id;
    println!("Created grid: id={}", grid_id);

    // 2. GetConfig — verify rows/cols
    let handle = GridHandle { id: grid_id };
    let resp_bytes = invoke(&plugin, "/volvoxgrid.v1.VolvoxGridService/GetConfig", &handle.encode_to_vec());
    let config = GridConfig::decode(resp_bytes.as_slice()).unwrap();
    let layout = config.layout.expect("layout should be present");
    assert_eq!(layout.rows.unwrap(), 51, "Expected 51 rows");
    assert_eq!(layout.cols.unwrap(), 5, "Expected 5 cols");
    println!("Grid dimensions: {}x{}", layout.rows.unwrap(), layout.cols.unwrap());

    // 3. UpdateCells — set headers
    let headers = ["Product", "Category", "Sales", "Quarter", "Region"];
    let header_cells: Vec<CellUpdate> = headers.iter().enumerate().map(|(c, h)| {
        CellUpdate {
            row: 0,
            col: c as i32,
            value: Some(CellValue {
                value: Some(cell_value::Value::Text(h.to_string())),
            }),
            ..Default::default()
        }
    }).collect();
    let req = UpdateCellsRequest { grid_id, cells: header_cells };
    invoke(&plugin, "/volvoxgrid.v1.VolvoxGridService/UpdateCells", &req.encode_to_vec());
    println!("Set {} headers.", headers.len());

    // 4. UpdateCells — data rows (batch all 250 cells in one call)
    let products = ["Widget A", "Widget B", "Gadget X", "Gadget Y", "Tool Z"];
    let categories = ["Electronics", "Electronics", "Hardware", "Hardware", "Tools"];
    let regions = ["North", "South", "East", "West"];
    let mut data_cells = Vec::with_capacity(250);
    for r in 1..=50i32 {
        for c in 0..5i32 {
            let text = match c {
                0 => products[((r - 1) % 5) as usize].to_string(),
                1 => categories[((r - 1) % 5) as usize].to_string(),
                2 => format!("{}", r * 123 + 456),
                3 => format!("Q{}", (r % 4) + 1),
                4 => regions[((r - 1) % 4) as usize].to_string(),
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
    let req = UpdateCellsRequest { grid_id, cells: data_cells };
    invoke(&plugin, "/volvoxgrid.v1.VolvoxGridService/UpdateCells", &req.encode_to_vec());
    println!("Populated 50 data rows.");

    // 5. GetCells — verify header and first data row
    let req = GetCellsRequest {
        grid_id, row1: 0, col1: 0, row2: 0, col2: 0,
        include_style: false, include_checked: false,
    };
    let resp_bytes = invoke(&plugin, "/volvoxgrid.v1.VolvoxGridService/GetCells", &req.encode_to_vec());
    let cells_resp = CellsResponse::decode(resp_bytes.as_slice()).unwrap();
    let cell = &cells_resp.cells[0];
    if let Some(CellValue { value: Some(cell_value::Value::Text(ref t)) }) = cell.value {
        assert_eq!(t, "Product", "Header mismatch: got '{}'", t);
    } else {
        panic!("Expected text value for header cell");
    }

    let req = GetCellsRequest {
        grid_id, row1: 1, col1: 0, row2: 1, col2: 0,
        include_style: false, include_checked: false,
    };
    let resp_bytes = invoke(&plugin, "/volvoxgrid.v1.VolvoxGridService/GetCells", &req.encode_to_vec());
    let cells_resp = CellsResponse::decode(resp_bytes.as_slice()).unwrap();
    let cell = &cells_resp.cells[0];
    if let Some(CellValue { value: Some(cell_value::Value::Text(ref t)) }) = cell.value {
        assert_eq!(t, "Widget A", "Cell(1,0) mismatch: got '{}'", t);
    } else {
        panic!("Expected text value for data cell");
    }
    println!("GetCells verified.");

    // 6. Sort
    let req = SortRequest {
        grid_id,
        sort_columns: vec![SortColumn {
            col: 0,
            order: SortOrder::SortGenericAscending as i32,
        }],
    };
    invoke(&plugin, "/volvoxgrid.v1.VolvoxGridService/Sort", &req.encode_to_vec());
    println!("Sort complete.");

    // 7. GetCells after sort
    let req = GetCellsRequest {
        grid_id, row1: 1, col1: 0, row2: 1, col2: 0,
        include_style: false, include_checked: false,
    };
    let resp_bytes = invoke(&plugin, "/volvoxgrid.v1.VolvoxGridService/GetCells", &req.encode_to_vec());
    let cells_resp = CellsResponse::decode(resp_bytes.as_slice()).unwrap();
    let cell = &cells_resp.cells[0];
    if let Some(CellValue { value: Some(cell_value::Value::Text(ref t)) }) = cell.value {
        println!("After sort, row 1 col 0 = \"{}\"", t);
    }

    // 8. Configure selection mode + Select
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
    invoke(&plugin, "/volvoxgrid.v1.VolvoxGridService/Configure", &req.encode_to_vec());

    let req = SelectRequest {
        grid_id,
        row: 2,
        col: 0,
        row_end: Some(5),
        col_end: Some(4),
        show: None,
    };
    invoke(&plugin, "/volvoxgrid.v1.VolvoxGridService/Select", &req.encode_to_vec());
    println!("Selection set: rows 2-5.");

    // 9. Destroy
    let handle = GridHandle { id: grid_id };
    invoke(&plugin, "/volvoxgrid.v1.VolvoxGridService/Destroy", &handle.encode_to_vec());
    println!("Grid destroyed.");

    plugin.close();
    println!("\nAll smoke tests passed!");
}
