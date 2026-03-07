//! Shared demo scenarios for VolvoxGrid host examples.
//!
//! This module is feature-gated behind `demo` and not included in
//! production builds.  Every host example (GTK, Web/WASM, Android,
//! Flutter) can call these functions instead of duplicating the
//! setup/data logic.
//!
//! Three demos are provided:
//!
//! 1. **Sales Showcase** (`setup_sales_demo`) — ~1000 rows, 10 columns,
//!    subtotals, merged cells, dropdowns, currency/percentage formats,
//!    data bars, alternating row colors, explorer bar, outline bar.
//!
//! 2. **Hierarchy Showcase** (`setup_hierarchy_demo`) — ~200 rows, 5 columns,
//!    simulated directory tree with outline levels, expand/collapse, indented
//!    text, styled folder rows.
//!
//! 3. **Stress Test** (`setup_stress_demo`) — 1M rows, 12 columns, eagerly
//!    materialized for full-dataset sort/scroll benchmarking.  A separate
//!    lazy variant is available via `create_stress_grid`.

use crate::grid::VolvoxGrid;
use crate::indicator::DEFAULT_ROW_INDICATOR_WIDTH;
use crate::outline::{subtotal, subtotal_ex};
use crate::proto::volvoxgrid::v1 as pb;
use crate::style::{CellStyleOverride, HighlightStyle};

// ── Shared helpers ──────────────────────────────────────────────────

/// Scale a logical-pixel value by the grid's DPI scale factor.
fn sp(grid: &VolvoxGrid, px: i32) -> i32 {
    if grid.scale <= 1.001 {
        px
    } else {
        (px as f32 * grid.scale).round() as i32
    }
}

fn apply_demo_column_headers(grid: &mut VolvoxGrid, headers: &[&str], band_row_height_px: i32) {
    for (col, &header) in headers.iter().enumerate() {
        if let Some(cp) = grid.columns.get_mut(col) {
            cp.caption = header.to_string();
        }
    }

    grid.indicator_bands.col_top.visible = true;
    grid.indicator_bands.col_top.band_rows = 1;
    grid.indicator_bands.col_top.default_row_height_px = sp(grid, band_row_height_px);
    grid.indicator_bands.col_top.mode_bits = (pb::ColIndicatorCellMode::ColIndicatorCellHeaderText
        as u32)
        | (pb::ColIndicatorCellMode::ColIndicatorCellSortGlyph as u32);
    grid.indicator_bands.col_top.back_color = Some(0xFF2244AA);
    grid.indicator_bands.col_top.fore_color = Some(0xFFFFFFFF);
    grid.indicator_bands.col_top.allow_resize = true;
    grid.indicator_bands.corner_top_start.visible = false;
    grid.indicator_bands.corner_top_start.mode_bits = 0;
    grid.indicator_bands.corner_top_start.custom_key.clear();
    grid.indicator_bands.corner_top_start.data.clear();
}

fn apply_demo_row_indicator(grid: &mut VolvoxGrid, width_px: i32) {
    grid.indicator_bands.row_start.visible = true;
    grid.indicator_bands.row_start.width_px = sp(grid, width_px.max(DEFAULT_ROW_INDICATOR_WIDTH));
    grid.indicator_bands.row_start.mode_bits = pb::RowIndicatorMode::RowIndicatorNumbers as u32;
    grid.indicator_bands.row_start.back_color = Some(grid.style.back_color_bkg);
    grid.indicator_bands.row_start.fore_color = Some(grid.style.fore_color);
    grid.indicator_bands.row_start.grid_color = Some(grid.style.grid_color);
    grid.indicator_bands.row_start.allow_resize = true;
}

fn apply_sales_subtotal_merges(grid: &mut VolvoxGrid) {
    if grid.cols < 2 {
        return;
    }

    for row in grid.fixed_rows..grid.rows {
        let Some(props) = grid.row_props.get(&row) else {
            continue;
        };
        if props.is_subtotal && props.outline_level <= 0 {
            grid.merged_regions.add_merge(row, 0, row, 1);
        }
    }
}

fn reset_grid(grid: &mut VolvoxGrid) {
    // Clear all data
    grid.cells.clear_all();
    grid.rows = 0;
    grid.cols = 0;
    grid.row_positions.clear();
    grid.col_positions.clear();
    grid.row_heights.clear();
    grid.col_widths.clear();
    grid.row_props.clear();
    grid.columns.clear();
    grid.cell_styles.clear();

    // Reset state
    grid.edit.cancel(); // Ensures active edit is closed
    grid.selection.select(0, 0, 0, 0, 0, 0);
    grid.scroll.scroll_x = 0.0;
    grid.scroll.scroll_y = 0.0;
    grid.span = Default::default();
    grid.outline = Default::default();
    grid.sort_state = Default::default();
    grid.sort_value_generator = None;
    grid.indicator_bands = Default::default();

    // Reset properties to defaults
    grid.fixed_rows = 0;
    grid.fixed_cols = 0;
    grid.frozen_rows = 0;
    grid.frozen_cols = 0;
    grid.style.back_color_alternate = 0;
}

/// splitmix64 hash — deterministic pseudo-random from a seed.
pub fn splitmix64(mut x: u64) -> u64 {
    x = x.wrapping_add(0x9E3779B97F4A7C15);
    let mut z = x;
    z = (z ^ (z >> 30)).wrapping_mul(0xBF58476D1CE4E5B9);
    z = (z ^ (z >> 27)).wrapping_mul(0x94D049BB133111EB);
    z ^ (z >> 31)
}

/// Pick an index in `0..len` deterministically from (row, salt).
pub fn rand_idx(row: i32, salt: u64, len: usize) -> usize {
    if len == 0 {
        return 0;
    }
    (splitmix64((row as u64) ^ salt) as usize) % len
}

// =====================================================================
// Demo 1: Sales Showcase (~1000 rows)
// =====================================================================

const SALES_PRODUCTS: [&str; 20] = [
    "Widget A",
    "Widget B",
    "Widget C",
    "Widget D",
    "Gadget X",
    "Gadget Y",
    "Gadget Z",
    "Gadget W",
    "Tool Alpha",
    "Tool Beta",
    "Tool Gamma",
    "Tool Delta",
    "Sensor M1",
    "Sensor M2",
    "Module P1",
    "Module P2",
    "Board Q1",
    "Board Q2",
    "Cable R1",
    "Chip S1",
];

const SALES_CATEGORIES: [&str; 5] = ["Electronics", "Hardware", "Tools", "Sensors", "Components"];

/// Map each product index to a category index.
const SALES_PRODUCT_CATEGORY: [usize; 20] = [
    0, 0, 0, 0, // Electronics
    1, 1, 1, 1, // Hardware
    2, 2, 2, 2, // Tools
    3, 3, 3, 3, // Sensors
    4, 4, 4, 4, // Components
];

const SALES_REGIONS: [&str; 4] = ["North", "South", "East", "West"];
const SALES_QUARTERS: [&str; 4] = ["Q1", "Q2", "Q3", "Q4"];
const SALES_STATUSES: [&str; 5] = ["Active", "Pending", "Shipped", "Returned", "Cancelled"];

const SALES_HEADERS: [&str; 9] = [
    "Q", "Region", "Category", "Product", "Sales", "Cost", "Margin%", "Status", "Notes",
];
const SALES_COL_WIDTHS: [i32; 9] = [40, 80, 100, 120, 90, 90, 70, 80, 140];
const SALES_DATA_ROWS: i32 = 1000;

/// Configure and populate a grid as the Sales Showcase demo.
///
/// Creates ~1000 data rows with multi-level subtotals:
/// - Product subtotals within each category
/// - Category subtotals
/// - Grand total
///
/// Subtotals are placed above each group for proper outline tree collapse.
/// Outline levels: 0=grand, 1=category, 2=product, 3=data.
pub fn setup_sales_demo(grid: &mut VolvoxGrid) {
    reset_grid(grid);

    // ── Generate data in memory ──────────────────────────────────────
    struct Entry {
        product: &'static str,
        category: &'static str,
        region: &'static str,
        quarter: &'static str,
        sales: i32,
        cost: i32,
        margin_pct: f32,
        status: &'static str,
        note: String,
    }

    let note_tags = [
        "review",
        "priority",
        "follow-up",
        "audit",
        "bulk",
        "check",
        "normal",
        "expedite",
    ];
    let mut entries = Vec::with_capacity(SALES_DATA_ROWS as usize);
    for r in 1..=SALES_DATA_ROWS {
        let pi = rand_idx(r, 0xA1, SALES_PRODUCTS.len());
        let ci = SALES_PRODUCT_CATEGORY[pi];
        let ri = rand_idx(r, 0xC3, SALES_REGIONS.len());
        let qi = rand_idx(r, 0xD4, SALES_QUARTERS.len());
        let si = rand_idx(r, 0xE5, SALES_STATUSES.len());
        let ni = rand_idx(r, 0xF6, note_tags.len());
        let sales = 500 + (splitmix64((r as u64) ^ 0x51F0_0DAD) % 49_501) as i32;
        let cost_pct = 40 + (splitmix64((r as u64) ^ 0x22AA_BB) % 46) as i32;
        let cost = sales * cost_pct / 100;
        let margin = if sales > 0 {
            (sales - cost) as f32 / sales as f32 * 100.0
        } else {
            0.0
        };
        let nc = 1000 + (splitmix64((r as u64) ^ 0x4455) % 9000) as i32;
        entries.push(Entry {
            product: SALES_PRODUCTS[pi],
            category: SALES_CATEGORIES[ci],
            region: SALES_REGIONS[ri],
            quarter: SALES_QUARTERS[qi],
            sales,
            cost,
            margin_pct: margin,
            status: SALES_STATUSES[si],
            note: format!("{} note {}", note_tags[ni], nc),
        });
    }

    // ── Sort by Q, then Region ─────────────────────────────────────
    entries.sort_by(|a, b| a.quarter.cmp(b.quarter).then(a.region.cmp(b.region)));

    // ── Configure grid ───────────────────────────────────────────────
    grid.set_rows(entries.len() as i32);
    grid.set_cols(9);

    for (c, &w) in SALES_COL_WIDTHS.iter().enumerate() {
        grid.set_col_width(c as i32, sp(grid, w));
    }
    grid.default_row_height = sp(grid, crate::grid::DEFAULT_ROW_HEIGHT);
    apply_demo_column_headers(grid, &SALES_HEADERS, 28);
    apply_demo_row_indicator(grid, 40);

    grid.columns[0].alignment = pb::Align::CenterCenter as i32;
    grid.columns[4].alignment = pb::Align::RightCenter as i32;
    grid.columns[5].alignment = pb::Align::RightCenter as i32;
    grid.columns[6].alignment = pb::Align::CenterCenter as i32;
    grid.columns[4].format = "$#,##0".to_string();
    grid.columns[5].format = "$#,##0".to_string();
    grid.columns[7].dropdown_items = "Active|Pending|Shipped|Returned|Cancelled".to_string();
    grid.columns[6].progress_color = 0xFF4488CC;
    grid.style.back_color_alternate = 0xFFF0F5FF;

    grid.allow_user_resizing = 3;
    grid.tab_behavior = 1;
    grid.edit_trigger_mode = 2;
    grid.dropdown_trigger = 1;
    grid.dropdown_search = true;
    grid.fling_enabled = true;
    grid.fling_impulse_gain = 220.0;
    grid.fling_friction = 0.9;
    grid.header_features = 3;
    grid.auto_size_mouse = true;
    grid.allow_user_freezing = 3;
    grid.selection.hover_mode = (pb::HoverMode::HoverRow as u32)
        | (pb::HoverMode::HoverColumn as u32)
        | (pb::HoverMode::HoverCell as u32);
    grid.selection.hover_row_style = HighlightStyle {
        back_color: Some(0x0A1A73E8),
        ..HighlightStyle::default()
    };
    grid.selection.hover_column_style = HighlightStyle {
        back_color: Some(0x0A1A73E8),
        ..HighlightStyle::default()
    };
    grid.selection.hover_cell_style = HighlightStyle {
        back_color: Some(0x241A73E8),
        border: Some(pb::BorderStyle::BorderThin as i32),
        border_color: Some(0xFF1A73E8),
        ..HighlightStyle::default()
    };

    // ── Write flat data rows ─────────────────────────────────────────
    for (idx, e) in entries.iter().enumerate() {
        let r = idx as i32;
        grid.cells.set_text(r, 0, e.quarter.to_string());
        grid.cells.set_text(r, 1, e.region.to_string());
        grid.cells.set_text(r, 2, e.category.to_string());
        grid.cells.set_text(r, 3, e.product.to_string());
        grid.cells.set_text(r, 4, format!("{}", e.sales));
        grid.cells.set_text(r, 5, format!("{}", e.cost));
        grid.cells.set_text(r, 6, format!("{:.0}", e.margin_pct));
        grid.cells.set_text(r, 7, e.status.to_string());
        grid.cells.set_text(r, 8, e.note.clone());
        if e.margin_pct < 0.0 {
            grid.cell_styles.insert(
                (r, 6),
                CellStyleOverride {
                    fore_color: Some(0xFFCC0000),
                    font_bold: Some(true),
                    ..Default::default()
                },
            );
        }
    }

    // ── Subtotals: Q → Region → Grand Total (below) ────────────────
    grid.outline.group_total_position = 1; // below
    subtotal(grid, 1, 0, 0, "", 0, 0, false); // clear existing
    subtotal(grid, 2, -1, 4, "Grand Total", 0xFFC0C0C0, 0xFF000000, true);
    // Group by Q (col 0), match_from=1
    subtotal_ex(
        grid, 2, 0, 4, "", 0xFFD0D0D0, 0xFF000000, true, "", false, 1, false,
    );
    // Group by Region (col 1), match_from=1 so Q+Region both participate
    subtotal_ex(
        grid, 2, 1, 4, "", 0xFFE8E8E8, 0xFF000000, true, "", false, 1, false,
    );

    // Fill cost and margin for subtotal rows from their data rows above.
    let margin_f = |s: i64, c: i64| -> f64 {
        if s > 0 {
            (s - c) as f64 / s as f64 * 100.0
        } else {
            0.0
        }
    };
    let parse_i64 = |s: &str| -> i64 { s.parse::<i64>().unwrap_or(0) };
    let row_count = grid.rows;
    for row in grid.fixed_rows..row_count {
        let Some(props) = grid.row_props.get(&row) else {
            continue;
        };
        if !props.is_subtotal {
            continue;
        }
        let level = props.outline_level;
        let mut sales_sum = 0_i64;
        let mut cost_sum = 0_i64;
        // Walk backwards — subtotals are below their data rows
        let mut r = row - 1;
        while r >= grid.fixed_rows {
            let (is_sub, row_level) = grid
                .row_props
                .get(&r)
                .map(|p| (p.is_subtotal, p.outline_level))
                .unwrap_or((false, 0));
            if is_sub && row_level <= level {
                break;
            }
            if !is_sub {
                sales_sum += parse_i64(grid.cells.get_text(r, 4));
                cost_sum += parse_i64(grid.cells.get_text(r, 5));
            }
            r -= 1;
        }
        grid.cells.set_text(row, 5, format!("{}", cost_sum));
        grid.cells
            .set_text(row, 6, format!("{:.1}", margin_f(sales_sum, cost_sum)));
    }

    // Span on Q and Region columns
    grid.span.mode = 4;
    grid.span.mode_fixed = 0;
    grid.span.span_cols.clear();
    grid.span.span_cols.insert(0, true);
    grid.span.span_cols.insert(1, true);
    grid.span.span_compare = 1;
    apply_sales_subtotal_merges(grid);

    // Outline bar
    grid.outline.tree_indicator = 0;
    grid.outline.group_total_position = 1; // below

    grid.layout.invalidate();
    grid.mark_dirty();
}

// =====================================================================
// Demo 2: Hierarchy Showcase (~200 rows)
// =====================================================================

const HIERARCHY_HEADERS: [&str; 5] = ["Name", "Type", "Size", "Modified", "Permissions"];
const HIERARCHY_COL_WIDTHS: [i32; 5] = [260, 80, 80, 120, 100];

struct DirEntry {
    name: &'static str,
    kind: &'static str, // "Folder", "File"
    size_kb: i32,       // 0 for folders
    modified: &'static str,
    perms: &'static str,
    level: i32,
}

/// Configure and populate a grid as the Hierarchy Showcase demo.
///
/// Creates ~200 rows showing a directory tree with outline levels,
/// expand/collapse, indented names, and styled folder rows.
pub fn setup_hierarchy_demo(grid: &mut VolvoxGrid) {
    reset_grid(grid);
    let entries = build_hierarchy_entries();
    let data_rows = entries.len() as i32;

    grid.set_rows(data_rows);
    grid.set_cols(5);

    // Column widths
    for (c, &w) in HIERARCHY_COL_WIDTHS.iter().enumerate() {
        grid.set_col_width(c as i32, sp(grid, w));
    }

    grid.default_row_height = sp(grid, crate::grid::DEFAULT_ROW_HEIGHT);
    apply_demo_column_headers(grid, &HIERARCHY_HEADERS, 28);

    // Column alignments
    grid.columns[2].alignment = pb::Align::RightCenter as i32;
    grid.columns[4].alignment = pb::Align::CenterCenter as i32;

    // Alternating row color
    grid.style.back_color_alternate = 0xFFF5F5F5;

    // Interaction defaults
    grid.allow_user_resizing = 3;
    grid.tab_behavior = 1;
    grid.edit_trigger_mode = 0; // read-only for hierarchy
    grid.fling_enabled = true;
    grid.fling_impulse_gain = 220.0;
    grid.fling_friction = 0.9;
    grid.header_features = 0; // disabled — flat sort is incompatible with tree hierarchy
    grid.auto_size_mouse = true;
    grid.selection.hover_mode = pb::HoverMode::HoverCell as u32;
    grid.selection.hover_row_style = HighlightStyle::default();
    grid.selection.hover_column_style = HighlightStyle::default();
    grid.selection.hover_cell_style = HighlightStyle {
        back_color: Some(0x1A2E7D32),
        border: Some(pb::BorderStyle::BorderThin as i32),
        border_color: Some(0xFF2E7D32),
        ..HighlightStyle::default()
    };

    // Populate data rows
    for (i, entry) in entries.iter().enumerate() {
        let r = i as i32;

        // Plain name — visual indent is handled by the outline tree renderer
        grid.cells.set_text(r, 0, entry.name.to_string());
        grid.cells.set_text(r, 1, entry.kind.to_string());
        if entry.size_kb > 0 {
            grid.cells.set_text(r, 2, format_size(entry.size_kb));
        }
        grid.cells.set_text(r, 3, entry.modified.to_string());
        grid.cells.set_text(r, 4, entry.perms.to_string());

        // Set outline level (shift +1 so root-level folders at level 0
        // become level 1 and get +/- buttons from the renderer)
        let props = grid.row_props.entry(r).or_default();
        props.outline_level = entry.level + 1;
        if entry.kind == "Folder" {
            props.is_subtotal = true;
        }

        // Style folders bold
        if entry.kind == "Folder" {
            grid.cell_styles.insert(
                (r, 0),
                CellStyleOverride {
                    font_bold: Some(true),
                    fore_color: Some(0xFF1A5276),
                    ..Default::default()
                },
            );
        }
    }

    // Outline bar in complete mode
    grid.outline.tree_indicator = 2;
    grid.outline.tree_column = 0;

    grid.layout.invalidate();
    grid.mark_dirty();
}

fn format_size(kb: i32) -> String {
    if kb >= 1024 * 1024 {
        format!("{:.1} GB", kb as f64 / (1024.0 * 1024.0))
    } else if kb >= 1024 {
        format!("{:.1} MB", kb as f64 / 1024.0)
    } else {
        format!("{} KB", kb)
    }
}

fn build_hierarchy_entries() -> Vec<DirEntry> {
    let mut entries = Vec::with_capacity(200);

    // Helper macro for folder/file entries
    macro_rules! folder {
        ($name:expr, $level:expr, $date:expr) => {
            entries.push(DirEntry {
                name: $name,
                kind: "Folder",
                size_kb: 0,
                modified: $date,
                perms: "rwxr-xr-x",
                level: $level,
            });
        };
    }
    macro_rules! file {
        ($name:expr, $level:expr, $size:expr, $date:expr, $perms:expr) => {
            entries.push(DirEntry {
                name: $name,
                kind: "File",
                size_kb: $size,
                modified: $date,
                perms: $perms,
                level: $level,
            });
        };
    }

    // Root-level directories
    // Documents/
    folder!("Documents", 0, "2025-12-01");
    folder!("Reports", 1, "2025-11-15");
    file!("Q1_Report.xlsx", 2, 245, "2025-03-31", "rw-r--r--");
    file!("Q2_Report.xlsx", 2, 312, "2025-06-30", "rw-r--r--");
    file!("Q3_Report.pdf", 2, 1840, "2025-09-30", "rw-r--r--");
    file!("Q4_Report.docx", 2, 178, "2025-12-15", "rw-r--r--");
    file!("Annual_Summary.pdf", 2, 4200, "2025-12-20", "rw-r--r--");
    folder!("Invoices", 1, "2025-12-10");
    file!("INV-001.pdf", 2, 89, "2025-01-15", "rw-r--r--");
    file!("INV-002.pdf", 2, 92, "2025-02-18", "rw-r--r--");
    file!("INV-003.pdf", 2, 76, "2025-03-22", "rw-r--r--");
    file!("INV-004.pdf", 2, 134, "2025-04-10", "rw-r--r--");
    file!("INV-005.pdf", 2, 98, "2025-05-05", "rw-r--r--");
    file!("INV-006.pdf", 2, 112, "2025-06-08", "rw-r--r--");
    file!("INV-007.pdf", 2, 87, "2025-07-14", "rw-r--r--");
    file!("INV-008.pdf", 2, 145, "2025-08-19", "rw-r--r--");
    file!("INV-009.pdf", 2, 93, "2025-09-23", "rw-r--r--");
    file!("INV-010.pdf", 2, 101, "2025-10-30", "rw-r--r--");
    file!("INV-011.pdf", 2, 88, "2025-11-12", "rw-r--r--");
    file!("INV-012.pdf", 2, 156, "2025-12-05", "rw-r--r--");
    folder!("Contracts", 1, "2025-10-01");
    file!("Contract_Alpha.pdf", 2, 2100, "2025-01-20", "rw-------");
    file!("Contract_Beta.pdf", 2, 1850, "2025-04-15", "rw-------");
    file!("Contract_Gamma.docx", 2, 980, "2025-07-01", "rw-------");
    file!("NDA_Template.docx", 2, 45, "2025-02-10", "rw-r--r--");
    folder!("Presentations", 1, "2025-11-20");
    file!("Roadmap_2025.pptx", 2, 8500, "2025-01-10", "rw-r--r--");
    file!("Team_Kickoff.pptx", 2, 5200, "2025-03-01", "rw-r--r--");
    file!("Client_Demo.pptx", 2, 12400, "2025-06-15", "rw-r--r--");
    file!("Year_Review.pptx", 2, 9800, "2025-12-18", "rw-r--r--");

    // Photos/
    folder!("Photos", 0, "2025-11-30");
    folder!("Vacation", 1, "2025-08-20");
    file!("IMG_001.jpg", 2, 3200, "2025-08-01", "rw-r--r--");
    file!("IMG_002.jpg", 2, 2800, "2025-08-01", "rw-r--r--");
    file!("IMG_003.jpg", 2, 4100, "2025-08-02", "rw-r--r--");
    file!("IMG_004.jpg", 2, 3600, "2025-08-03", "rw-r--r--");
    file!("IMG_005.jpg", 2, 2950, "2025-08-04", "rw-r--r--");
    file!("IMG_006.jpg", 2, 5100, "2025-08-05", "rw-r--r--");
    file!("IMG_007.jpg", 2, 3800, "2025-08-06", "rw-r--r--");
    file!("IMG_008.jpg", 2, 4200, "2025-08-07", "rw-r--r--");
    folder!("Panoramas", 2, "2025-08-10");
    file!("PANO_001.jpg", 3, 12500, "2025-08-02", "rw-r--r--");
    file!("PANO_002.jpg", 3, 15200, "2025-08-04", "rw-r--r--");
    file!("PANO_003.jpg", 3, 11800, "2025-08-06", "rw-r--r--");
    folder!("Events", 1, "2025-11-10");
    file!("Conference_01.jpg", 2, 2400, "2025-05-15", "rw-r--r--");
    file!("Conference_02.jpg", 2, 3100, "2025-05-15", "rw-r--r--");
    file!("Conference_03.jpg", 2, 2700, "2025-05-16", "rw-r--r--");
    file!("TeamDinner.jpg", 2, 4500, "2025-09-20", "rw-r--r--");
    file!("Award_Ceremony.jpg", 2, 3800, "2025-11-05", "rw-r--r--");
    folder!("Screenshots", 1, "2025-12-15");
    file!("Screen_001.png", 2, 890, "2025-10-01", "rw-r--r--");
    file!("Screen_002.png", 2, 1200, "2025-10-15", "rw-r--r--");
    file!("Screen_003.png", 2, 780, "2025-11-01", "rw-r--r--");
    file!("Screen_004.png", 2, 950, "2025-11-20", "rw-r--r--");
    file!("Screen_005.png", 2, 1100, "2025-12-10", "rw-r--r--");

    // Projects/
    folder!("Projects", 0, "2025-12-18");
    folder!("VolvoxGrid", 1, "2025-12-18");
    folder!("src", 2, "2025-12-18");
    file!("main.rs", 3, 12, "2025-12-18", "rw-r--r--");
    file!("lib.rs", 3, 45, "2025-12-17", "rw-r--r--");
    file!("grid.rs", 3, 128, "2025-12-16", "rw-r--r--");
    file!("render.rs", 3, 89, "2025-12-15", "rw-r--r--");
    file!("cell.rs", 3, 34, "2025-12-14", "rw-r--r--");
    file!("style.rs", 3, 22, "2025-12-13", "rw-r--r--");
    folder!("tests", 2, "2025-12-10");
    file!("test_grid.rs", 3, 56, "2025-12-10", "rw-r--r--");
    file!("test_render.rs", 3, 78, "2025-12-09", "rw-r--r--");
    file!("test_edit.rs", 3, 34, "2025-12-08", "rw-r--r--");
    file!("Cargo.toml", 2, 2, "2025-12-15", "rw-r--r--");
    file!("README.md", 2, 8, "2025-12-01", "rw-r--r--");
    folder!("WebApp", 1, "2025-11-25");
    folder!("src", 2, "2025-11-25");
    file!("index.ts", 3, 15, "2025-11-25", "rw-r--r--");
    file!("app.ts", 3, 42, "2025-11-24", "rw-r--r--");
    file!("style.css", 3, 18, "2025-11-23", "rw-r--r--");
    folder!("public", 2, "2025-11-20");
    file!("index.html", 3, 3, "2025-11-20", "rw-r--r--");
    file!("favicon.ico", 3, 4, "2025-11-01", "rw-r--r--");
    file!("package.json", 2, 2, "2025-11-15", "rw-r--r--");
    file!("tsconfig.json", 2, 1, "2025-11-10", "rw-r--r--");
    folder!("MobileApp", 1, "2025-10-30");
    folder!("android", 2, "2025-10-30");
    file!("MainActivity.kt", 3, 28, "2025-10-30", "rw-r--r--");
    file!("build.gradle.kts", 3, 5, "2025-10-25", "rw-r--r--");
    folder!("ios", 2, "2025-10-28");
    file!("AppDelegate.swift", 3, 15, "2025-10-28", "rw-r--r--");
    file!("ContentView.swift", 3, 22, "2025-10-27", "rw-r--r--");

    // Music/
    folder!("Music", 0, "2025-09-15");
    folder!("Classical", 1, "2025-06-01");
    file!("Bach_BWV1007.flac", 2, 45000, "2025-01-10", "rw-r--r--");
    file!("Mozart_K545.flac", 2, 38000, "2025-02-15", "rw-r--r--");
    file!("Beethoven_Op27.flac", 2, 52000, "2025-03-20", "rw-r--r--");
    folder!("Jazz", 1, "2025-09-15");
    file!("Blue_Train.flac", 2, 61000, "2025-05-01", "rw-r--r--");
    file!("Kind_of_Blue.flac", 2, 58000, "2025-06-10", "rw-r--r--");
    file!("Mingus_Ah_Um.flac", 2, 49000, "2025-07-05", "rw-r--r--");
    folder!("Playlists", 1, "2025-09-01");
    file!("WorkFocus.m3u", 2, 2, "2025-08-01", "rw-r--r--");
    file!("Relaxation.m3u", 2, 3, "2025-08-15", "rw-r--r--");
    file!("Running.m3u", 2, 2, "2025-09-01", "rw-r--r--");

    // Downloads/
    folder!("Downloads", 0, "2025-12-20");
    file!("setup_v3.2.exe", 1, 85000, "2025-12-01", "rw-r--r--");
    file!("manual.pdf", 1, 12400, "2025-11-15", "rw-r--r--");
    file!("data_export.csv", 1, 34000, "2025-12-10", "rw-r--r--");
    file!("wallpaper.jpg", 1, 8900, "2025-10-20", "rw-r--r--");
    file!("archive_2024.tar.gz", 1, 256000, "2025-01-05", "rw-r--r--");
    file!("notes.txt", 1, 12, "2025-12-20", "rw-r--r--");
    file!(
        "presentation_draft.pptx",
        1,
        15600,
        "2025-12-18",
        "rw-r--r--"
    );
    file!("database_backup.sql", 1, 128000, "2025-12-15", "rw-------");

    // Recycle Bin/
    folder!("Recycle Bin", 0, "2025-12-19");
    file!("old_report.docx", 1, 340, "2025-06-01", "rw-------");
    file!("temp_data.xlsx", 1, 890, "2025-08-10", "rw-------");
    file!("draft_v1.txt", 1, 15, "2025-09-22", "rw-------");

    entries
}

// =====================================================================
// Demo 3: Stress Test (~1M rows)
// =====================================================================

/// Default data rows for the stress test (1 million).
pub const STRESS_DATA_ROWS: i32 = 1_000_000;
/// Default number of rows to preload at startup.
pub const STRESS_PRELOAD_ROWS: i32 = 2_000;
/// Padding rows to materialize around the visible window.
pub const STRESS_MATERIALIZE_PADDING: i32 = 48;

const STRESS_HEADERS: [&str; 11] = [
    "Text",
    "Number",
    "Currency",
    "Pct",
    "Date",
    "Bool",
    "Combo",
    "Long Text",
    "Formatted",
    "Rating",
    "Code",
];
const STRESS_COL_WIDTHS: [i32; 11] = [110, 80, 90, 60, 100, 50, 90, 160, 90, 60, 100];

const STRESS_TEXT_POOL: [&str; 10] = [
    "Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf", "Hotel", "India", "Juliet",
];

const STRESS_COMBO_OPTIONS: [&str; 5] =
    ["Option A", "Option B", "Option C", "Option D", "Option E"];

const STRESS_LONG_TEXT: [&str; 8] = [
    "Short note",
    "A medium-length description for testing",
    "This is a longer text entry that spans multiple words and exercises the text layout engine",
    "Review pending",
    "Approved by management team after thorough evaluation of all criteria",
    "TODO: follow up next quarter",
    "Flagged for audit - requires additional documentation and verification steps",
    "Completed",
];

/// Configure a grid as the Stress Test demo (1M rows, 12 columns).
///
/// Sets up column widths, headers, alignment, dropdown lists, formats,
/// progress colors, and interaction settings.  All 1M data rows are
/// materialized in memory at startup so sort and scroll work on the
/// complete dataset.
pub fn setup_stress_demo(grid: &mut VolvoxGrid) {
    setup_stress_grid(
        grid,
        STRESS_DATA_ROWS,
        stress_cell_capacity_for_rows(STRESS_DATA_ROWS),
    );

    // Generate all cell texts in parallel across CPU cores if rayon is enabled,
    // then insert into CellStore sequentially (HashMap insert is fast
    // with pre-allocated capacity).
    #[cfg(feature = "rayon")]
    let all_texts: Vec<(i32, Vec<String>)> = {
        use rayon::prelude::*;
        (0..STRESS_DATA_ROWS)
            .into_par_iter()
            .map(|r| {
                let texts: Vec<String> = (0..12).map(|c| stress_cell_text(r, c as i32)).collect();
                (r, texts)
            })
            .collect()
    };

    #[cfg(not(feature = "rayon"))]
    let all_texts: Vec<(i32, Vec<String>)> = (0..STRESS_DATA_ROWS)
        .map(|r| {
            let texts: Vec<String> = (0..12).map(|c| stress_cell_text(r, c as i32)).collect();
            (r, texts)
        })
        .collect();

    for (r, texts) in all_texts {
        for (c, text) in texts.into_iter().enumerate() {
            grid.cells.set_text(r, c as i32, text);
        }
    }
}

/// Create a fully configured stress demo grid with lazy row materialization.
///
/// Only `preload_rows` are generated at startup; remaining
/// rows are materialized on demand by `stress_materialize_visible_rows`.
pub fn create_stress_grid(
    id: i64,
    width: i32,
    height: i32,
    data_rows: i32,
    preload_rows: i32,
) -> VolvoxGrid {
    let data_rows = data_rows.max(0);
    let preload_rows = preload_rows.clamp(0, data_rows);
    let reserve_rows = (preload_rows + STRESS_MATERIALIZE_PADDING * 4).clamp(0, data_rows);

    let mut grid = VolvoxGrid::new(id, width, height, data_rows, 12, 0, 1);
    setup_stress_grid(
        &mut grid,
        data_rows,
        stress_cell_capacity_for_rows(reserve_rows),
    );

    // Enable virtual sort for unmaterialized rows.
    if preload_rows < data_rows {
        grid.sort_value_generator = Some(stress_cell_text);
    }

    // Materialize only a small startup window.
    for r in 0..preload_rows {
        stress_materialize_row(&mut grid, r);
    }

    // If viewport is known, also fill the first visible window.
    if width > 0 && height > 0 {
        stress_materialize_visible_rows(&mut grid, STRESS_MATERIALIZE_PADDING);
    }
    grid
}

fn stress_cell_capacity_for_rows(data_rows: i32) -> usize {
    (data_rows.max(0) as usize).saturating_mul(12)
}

fn setup_stress_grid(grid: &mut VolvoxGrid, data_rows: i32, cell_capacity: usize) {
    reset_grid(grid);
    // Capacity is caller-defined: eager path uses full dataset; lazy path
    // keeps startup memory/time low and grows on demand.
    grid.cells = crate::cell::CellStore::with_capacity(cell_capacity.max(12));
    grid.set_rows(data_rows.max(0));
    grid.set_cols(11);

    // Column widths
    for (c, &w) in STRESS_COL_WIDTHS.iter().enumerate() {
        grid.set_col_width(c as i32, sp(grid, w));
    }

    grid.default_row_height = sp(grid, crate::grid::DEFAULT_ROW_HEIGHT);
    apply_demo_column_headers(grid, &STRESS_HEADERS, 28);
    apply_demo_row_indicator(grid, 40);

    // Column alignments
    grid.columns[1].alignment = pb::Align::RightCenter as i32;
    grid.columns[2].alignment = pb::Align::RightCenter as i32;
    grid.columns[3].alignment = pb::Align::CenterCenter as i32;
    grid.columns[5].alignment = pb::Align::CenterCenter as i32;
    grid.columns[9].alignment = pb::Align::CenterCenter as i32;

    // Column display formats
    grid.columns[2].format = "$#,##0".to_string(); // Currency

    // Dropdown list
    grid.columns[6].dropdown_items = "Option A|Option B|Option C|Option D|Option E".to_string();

    // Rating progress (data-bar)
    grid.columns[9].progress_color = 0xFF44AA88;

    // Alternating row color
    grid.style.back_color_alternate = 0xFFF0F5FF;

    // Interaction defaults
    grid.allow_user_resizing = 3;
    grid.tab_behavior = 1;
    grid.edit_trigger_mode = 2;
    grid.dropdown_trigger = 1;
    grid.dropdown_search = true;
    grid.fling_enabled = true;
    grid.fling_impulse_gain = 220.0;
    grid.fling_friction = 0.9;
    grid.header_features = 3;
    grid.auto_size_mouse = true;
    grid.allow_user_freezing = 3;
    grid.selection.hover_mode = pb::HoverMode::HoverRow as u32;
    grid.selection.hover_row_style = HighlightStyle {
        back_color: Some(0x12000000),
        ..HighlightStyle::default()
    };
    grid.selection.hover_column_style = HighlightStyle::default();
    grid.selection.hover_cell_style = HighlightStyle::default();
}

/// Compute the cell text for a given source row and column (stress test).
///
/// This is a pure function — given the same (source_row, col) it always
/// returns the same string.  Used by `stress_materialize_row` and by the
/// sort system (via `sort_value_generator`) to compare unmaterialized rows.
pub fn stress_cell_text(source_row: i32, col: i32) -> String {
    let logical_row = source_row.max(0) + 1;
    match col {
        0 => STRESS_TEXT_POOL[rand_idx(logical_row, 0xA1, STRESS_TEXT_POOL.len())].to_string(),
        1 => {
            let number = (splitmix64((logical_row as u64) ^ 0x1234) % 100_000) as i32 - 50_000;
            format!("{}", number)
        }
        2 => {
            let currency = 100 + (splitmix64((logical_row as u64) ^ 0x5678) % 999_900) as i32;
            format!("{}", currency)
        }
        3 => {
            let pct = (splitmix64((logical_row as u64) ^ 0x9ABC) % 101) as f32;
            format!("{:.0}", pct)
        }
        4 => {
            let day_offset = (splitmix64((logical_row as u64) ^ 0xAABB) % 2190) as i32;
            let year = 2020 + day_offset / 365;
            let day_in_year = day_offset % 365;
            let month = (day_in_year / 30).min(11) + 1;
            let day = (day_in_year % 30) + 1;
            format!("{:04}-{:02}-{:02}", year, month, day)
        }
        5 => {
            let bool_val = (splitmix64((logical_row as u64) ^ 0xDEF0) % 2) != 0;
            if bool_val { "Yes" } else { "No" }.to_string()
        }
        6 => STRESS_COMBO_OPTIONS[rand_idx(logical_row, 0xB2, STRESS_COMBO_OPTIONS.len())]
            .to_string(),
        7 => STRESS_LONG_TEXT[rand_idx(logical_row, 0xC3, STRESS_LONG_TEXT.len())].to_string(),
        8 => {
            let formatted =
                (splitmix64((logical_row as u64) ^ 0xEEFF) % 10_000_000) as f64 / 1000.0;
            format!("{:.3}", formatted)
        }
        9 => {
            let rating = (splitmix64((logical_row as u64) ^ 0x3355) % 100) as f32;
            format!("{:.0}", rating)
        }
        10 => {
            let code_val = splitmix64((logical_row as u64) ^ 0xCCDD);
            format!("{:016X}", code_val)
        }
        _ => String::new(),
    }
}

/// Populate a single data row with deterministic random values (stress test).
///
/// Uses `row_positions[row]` as the source seed so that sorted order is
/// preserved across trim/re-materialize cycles.
/// Does nothing if `row` is out of range or already has data in col 0.
pub fn stress_materialize_row(grid: &mut VolvoxGrid, row: i32) {
    if row < 0 || row >= grid.rows {
        return;
    }
    if grid.cells.contains(row, 0) {
        return;
    }

    let source_row = grid.row_positions.get(row as usize).copied().unwrap_or(row);

    for col in 0..11 {
        grid.cells
            .set_text(row, col, stress_cell_text(source_row, col));
    }
}

/// Ensure layout is up to date and materialize visible stress rows.
///
/// Materializes the current scroll window plus `padding` rows above/below.
/// Rows outside this range are kept as-is (no trimming).
pub fn stress_materialize_visible_rows(grid: &mut VolvoxGrid, padding: i32) {
    grid.ensure_layout();
    if grid.viewport_height <= 0 {
        return;
    }
    let fixed_row_end = (grid.fixed_rows + grid.frozen_rows).clamp(0, grid.rows);
    if fixed_row_end >= grid.rows {
        return;
    }

    let (first, last) =
        grid.layout
            .visible_rows(grid.scroll.scroll_y, grid.viewport_height, fixed_row_end);
    let start = (first - padding.max(0)).max(fixed_row_end);
    let end = (last + padding.max(0)).min(grid.rows - 1);

    if start > end {
        return;
    }
    for row in start..=end {
        stress_materialize_row(grid, row);
    }
}

// ── Compatibility aliases ───────────────────────────────────────────
// These allow existing code to continue working during migration.

/// Alias for `STRESS_DATA_ROWS`.
pub const DEFAULT_DATA_ROWS: i32 = STRESS_DATA_ROWS;
/// Alias for `STRESS_PRELOAD_ROWS`.
pub const DEFAULT_PRELOAD_ROWS: i32 = STRESS_PRELOAD_ROWS;
/// Alias for `STRESS_MATERIALIZE_PADDING`.
pub const DEFAULT_MATERIALIZE_PADDING: i32 = STRESS_MATERIALIZE_PADDING;

/// Alias: configure grid as stress test.
pub fn setup_sales_grid(grid: &mut VolvoxGrid) {
    setup_stress_grid(
        grid,
        STRESS_DATA_ROWS,
        stress_cell_capacity_for_rows(STRESS_DATA_ROWS),
    );
}

/// Alias: create a stress test grid.
pub fn create_sales_grid(
    id: i64,
    width: i32,
    height: i32,
    data_rows: i32,
    preload_rows: i32,
) -> VolvoxGrid {
    create_stress_grid(id, width, height, data_rows, preload_rows)
}

/// Alias: materialize a stress test row.
pub fn materialize_row(grid: &mut VolvoxGrid, row: i32) {
    stress_materialize_row(grid, row);
}

/// Alias: materialize visible rows for stress test.
pub fn materialize_visible_rows(grid: &mut VolvoxGrid, padding: i32) {
    stress_materialize_visible_rows(grid, padding);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sales_demo_uses_indicator_headers() {
        let mut grid = VolvoxGrid::new(1, 960, 540, 1, 1, 0, 0);
        setup_sales_demo(&mut grid);

        assert_eq!(grid.fixed_rows, 0);
        assert_eq!(grid.fixed_cols, 0);
        assert_eq!(grid.columns[0].caption, "Q");
        assert_eq!(grid.columns[4].caption, "Sales");
        assert!(grid.indicator_bands.col_top.visible);
        assert!(grid.indicator_bands.row_start.visible);
        assert_eq!(grid.indicator_bands.col_top.row_count(), 1);
        assert_eq!(
            grid.indicator_bands.row_start.mode_bits,
            pb::RowIndicatorMode::RowIndicatorNumbers as u32
        );
        assert_ne!(grid.cells.get_text(0, 0), "Q");
        assert_ne!(grid.cells.get_text(0, 4), "Sales");
    }

    #[test]
    fn sales_demo_merges_q_and_region_for_q_subtotals_and_grand_total() {
        let mut grid = VolvoxGrid::new(1, 960, 540, 1, 1, 0, 0);
        setup_sales_demo(&mut grid);

        let mut merged_subtotal_rows = 0;
        let mut region_subtotal_rows = 0;
        for row in grid.fixed_rows..grid.rows {
            let Some(props) = grid.row_props.get(&row) else {
                continue;
            };
            if !props.is_subtotal {
                continue;
            }

            if props.outline_level <= 0 {
                merged_subtotal_rows += 1;
                assert_eq!(grid.get_merged_range(row, 0), Some((row, 0, row, 1)));
                assert_eq!(grid.get_merged_range(row, 1), Some((row, 0, row, 1)));
            } else {
                region_subtotal_rows += 1;
                assert_eq!(grid.get_merged_range(row, 0), None);
                assert_eq!(grid.get_merged_range(row, 1), None);
            }
        }

        assert!(merged_subtotal_rows > 0, "expected Q subtotal and grand-total merges");
        assert!(region_subtotal_rows > 0, "expected region subtotal rows to remain unmerged");
    }

    #[test]
    fn hierarchy_demo_hides_row_indicator() {
        let mut grid = VolvoxGrid::new(1, 960, 540, 1, 1, 0, 0);
        setup_hierarchy_demo(&mut grid);

        assert_eq!(grid.fixed_rows, 0);
        assert_eq!(grid.columns[0].caption, "Name");
        assert_eq!(grid.columns[4].caption, "Permissions");
        assert!(grid.indicator_bands.col_top.visible);
        assert!(!grid.indicator_bands.row_start.visible);
        assert_eq!(grid.indicator_bands.col_top.row_count(), 1);
        assert_eq!(grid.cells.get_text(0, 0), "Documents");
        assert_ne!(grid.cells.get_text(0, 0), "Name");
    }

    #[test]
    fn create_stress_grid_uses_zero_based_rows_with_indicator_headers() {
        let mut grid = create_stress_grid(1, 0, 0, 8, 3);

        assert_eq!(grid.fixed_rows, 0);
        assert_eq!(grid.fixed_cols, 0);
        assert_eq!(grid.columns[0].caption, "Text");
        assert_eq!(grid.columns[10].caption, "Code");
        assert!(grid.indicator_bands.col_top.visible);
        assert!(grid.indicator_bands.row_start.visible);
        assert_eq!(grid.cells.get_text(0, 0), stress_cell_text(0, 0));
        assert_eq!(grid.cells.get_text(2, 0), stress_cell_text(2, 0));
        assert_eq!(grid.cells.get_text(3, 0), "");

        stress_materialize_row(&mut grid, 3);
        assert_eq!(grid.cells.get_text(3, 0), stress_cell_text(3, 0));
    }
}
