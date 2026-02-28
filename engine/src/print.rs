use crate::event::GridEventData;
use crate::grid::VolvoxGrid;
use crate::canvas::render_grid;
use crate::canvas_cpu::CpuCanvas;
use crate::text::TextEngine;

/// A single rendered page produced by `print_grid`.
pub struct PrintPage {
    /// 1-based page number.
    pub page_number: i32,
    /// PNG-encoded image data for this page.
    pub image_data: Vec<u8>,
    /// Page width in pixels.
    pub width: i32,
    /// Page height in pixels.
    pub height: i32,
}

/// Render the grid to a sequence of printable page images (PNG).
///
/// Each page is rendered as a full RGBA bitmap and then encoded to PNG.
/// Fixed rows are repeated on every page. The grid's scroll state is
/// temporarily adjusted per page and restored afterward.
///
/// `orientation`: 0 = portrait (8.5x11 in), 1 = landscape (11x8.5 in).
/// Margins and header/footer are specified in pixels at 96 DPI.
///
/// Returns a `Vec<PrintPage>` with one entry per page.
#[allow(clippy::too_many_arguments)]
pub fn print_grid(
    grid: &mut VolvoxGrid,
    orientation: i32,
    margin_left: i32,
    margin_top: i32,
    margin_right: i32,
    margin_bottom: i32,
    header: &str,
    footer: &str,
    show_page_numbers: bool,
) -> Vec<PrintPage> {
    // Standard page sizes at 96 DPI
    let (page_w, page_h) = if orientation == 1 {
        (1056, 816) // landscape (11x8.5 inches)
    } else {
        (816, 1056) // portrait (8.5x11 inches)
    };

    // Reserve space for header/footer text within margins
    let header_h = if !header.is_empty() { 20 } else { 0 };
    let footer_h = if !footer.is_empty() || show_page_numbers {
        20
    } else {
        0
    };

    let content_w = page_w - margin_left - margin_right;
    let content_h = page_h - margin_top - margin_bottom - header_h - footer_h;

    // Determine page breaks
    if !grid.layout.valid {
        return Vec::new();
    }

    // First pass: count total pages
    let mut total_pages = 0;
    {
        let mut row = grid.fixed_rows;
        while row < grid.rows {
            let mut ph = 0;
            let mut end = row;
            while end < grid.rows {
                let rh = grid.get_row_height(end);
                if ph + rh > content_h && end > row {
                    break;
                }
                ph += rh;
                end += 1;
            }
            total_pages += 1;
            row = end;
        }
    }

    let mut pages = Vec::new();
    let mut current_row = grid.fixed_rows;
    let mut page_num = 1;

    // Use the grid-owned text engine so host-loaded fonts participate in print.
    let mut text_engine = grid.text_engine.take().unwrap_or_else(TextEngine::new);
    if text_engine.layout_cache_cap != grid.text_layout_cache_cap {
        text_engine.set_layout_cache_cap(grid.text_layout_cache_cap);
    }
    text_engine.set_render_options(
        grid.style.text_render_mode,
        grid.style.text_hinting_mode,
        grid.style.text_pixel_snap,
    );
    let font_name = if grid.style.font_name.is_empty() {
        ""
    } else {
        &grid.style.font_name
    };
    let font_size = if grid.style.font_size > 0.0 {
        grid.style.font_size
    } else {
        10.0
    };

    while current_row < grid.rows {
        if page_num > 1 {
            grid.events
                .push(GridEventData::BeforePageBreak { row: current_row });
        }
        grid.events
            .push(GridEventData::StartPage { page: page_num });
        if page_num > 1 {
            grid.events
                .push(GridEventData::GetHeaderRow { page: page_num });
        }

        // Find how many rows fit on this page
        let mut page_height = 0;
        let mut end_row = current_row;
        while end_row < grid.rows {
            let rh = grid.get_row_height(end_row);
            if page_height + rh > content_h && end_row > current_row {
                break;
            }
            page_height += rh;
            end_row += 1;
        }

        // Render this page
        let mut buffer = vec![0u8; (page_w * page_h * 4) as usize];

        // Fill white background
        for i in (0..buffer.len()).step_by(4) {
            buffer[i] = 255;
            buffer[i + 1] = 255;
            buffer[i + 2] = 255;
            buffer[i + 3] = 255;
        }

        // Save and restore scroll state
        let saved_scroll = grid.scroll.clone();
        let saved_viewport_w = grid.viewport_width;
        let saved_viewport_h = grid.viewport_height;

        grid.viewport_width = content_w;
        grid.viewport_height = content_h;

        // Set scroll to show the correct row range
        if current_row > grid.fixed_rows {
            let fixed_h = grid.layout.row_pos(grid.fixed_rows);
            grid.scroll.scroll_y = (grid.layout.row_pos(current_row) - fixed_h) as f32;
        }

        let mut canvas = CpuCanvas::new(&mut buffer, page_w, page_h, page_w * 4, &mut text_engine);
        render_grid(grid, &mut canvas);

        // Restore
        grid.scroll = saved_scroll;
        grid.viewport_width = saved_viewport_w;
        grid.viewport_height = saved_viewport_h;

        // Render header text
        if !header.is_empty() {
            let header_text = expand_print_placeholders(header, page_num, total_pages);
            let header_y = margin_top.max(2);
            text_engine.render_text_styled(
                &mut buffer,
                page_w,
                page_h,
                page_w * 4,
                margin_left,
                header_y,
                0,
                content_w,
                header_h,
                &header_text,
                font_name,
                font_size,
                false,
                false,
                0xFF000000,
                0,
                None,
            );
        }

        // Render footer text
        let footer_text = if show_page_numbers && footer.is_empty() {
            format!("Page {}", page_num)
        } else if !footer.is_empty() {
            expand_print_placeholders(footer, page_num, total_pages)
        } else {
            String::new()
        };

        if !footer_text.is_empty() {
            let footer_y = page_h - margin_bottom - footer_h;
            text_engine.render_text_styled(
                &mut buffer,
                page_w,
                page_h,
                page_w * 4,
                margin_left,
                footer_y.max(0),
                0,
                content_w,
                footer_h,
                &footer_text,
                font_name,
                font_size,
                false,
                false,
                0xFF000000,
                0,
                None,
            );
        }

        // Encode as PNG
        let png_data = encode_rgba_png(&buffer, page_w as u32, page_h as u32);

        pages.push(PrintPage {
            page_number: page_num,
            image_data: png_data,
            width: page_w,
            height: page_h,
        });

        page_num += 1;
        current_row = end_row;
    }

    grid.text_engine = Some(text_engine);
    pages
}

/// Expand print header/footer placeholders:
/// - `&P` or `&p` = current page number
/// - `&N` or `&n` = total page count
fn expand_print_placeholders(template: &str, page: i32, total: i32) -> String {
    template
        .replace("&P", &page.to_string())
        .replace("&p", &page.to_string())
        .replace("&N", &total.to_string())
        .replace("&n", &total.to_string())
}

/// Encode raw RGBA pixel data as a PNG using tiny-skia's Pixmap.
pub fn encode_rgba_png(data: &[u8], width: u32, height: u32) -> Vec<u8> {
    if let Some(size) = tiny_skia::IntSize::from_wh(width, height) {
        if let Some(pixmap) = tiny_skia::Pixmap::from_vec(data.to_vec(), size) {
            return pixmap.encode_png().unwrap_or_default();
        }
    }
    Vec::new()
}
