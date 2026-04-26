#[path = "../ffi.rs"]
mod ffi;

mod proto {
    pub mod volvoxgrid {
        pub mod v1 {
            include!(concat!(env!("OUT_DIR"), "/volvoxgrid.v1.rs"));
        }
    }
}

use std::sync::Arc;
use std::time::Duration;

use cairo::ImageSurface;
use ffi::{resolve_default_plugin_path, PluginLibrary, PluginStream};
use gtk4::gdk;
use gtk4::glib;
use gtk4::prelude::*;
use gtk4::{DrawingArea, Window};
use prost::Message;
use proto::volvoxgrid::v1 as pb;
use serde::{Deserialize, Serialize};

const DEFAULT_WIDTH: i32 = 1280;
const DEFAULT_HEIGHT: i32 = 900;
const DEFAULT_DEMO: &str = "sales";
const DEMO_SALES: &str = "sales";
const DEMO_HIERARCHY: &str = "hierarchy";
const DEMO_STRESS: &str = "stress";
const SALES_DEMO_COLS: i32 = 10;
const HIERARCHY_DEMO_COLS: i32 = 6;
const SALES_STATUS_ITEMS: &str = "Active|Pending|Shipped|Returned|Cancelled";
const GTK_SURFACE_WAIT: Duration = Duration::from_secs(5);
const LAYER_COUNT: usize = 27;
const DEBUG_OVERLAY_BIT: i64 = 26;
const LAYER_LABELS: [&str; LAYER_COUNT] = [
    "Overlay Bands",
    "Indicators",
    "Backgrounds",
    "Progress Bars",
    "Grid Lines",
    "Header Marks",
    "Background Image",
    "Cell Borders",
    "Cell Text",
    "Cell Pictures",
    "Sort Glyphs",
    "Col Drag Marker",
    "Checkboxes",
    "Dropdown Buttons",
    "Selection",
    "Hover Highlight",
    "Edit Highlights",
    "Focus Rect",
    "Fill Handle",
    "Outline",
    "Frozen Borders",
    "Active Editor",
    "Active Dropdown",
    "Scroll Bars",
    "Fast Scroll",
    "Pull To Refresh",
    "Debug Overlay",
];

const NATIVE_SURFACE_DESC_MAGIC: u32 = 0x5658_4753;
const NATIVE_SURFACE_DESC_VERSION: u16 = 1;
const NATIVE_SURFACE_KIND_WAYLAND: u16 = 1;
const NATIVE_SURFACE_KIND_X11: u16 = 2;

fn dropdown_from_labels(items: &str) -> pb::Dropdown {
    pb::Dropdown {
        items: items
            .split('|')
            .filter(|label| !label.is_empty())
            .map(|label| pb::DropdownItem {
                label: Some(label.to_string()),
                ..Default::default()
            })
            .collect(),
        ..Default::default()
    }
}

#[derive(Debug, Deserialize)]
struct HierarchyJsonRow {
    #[serde(rename = "Name")]
    name: String,
    #[serde(rename = "Type")]
    kind: String,
    #[serde(rename = "Size")]
    size: String,
    #[serde(rename = "Modified")]
    modified: String,
    #[serde(rename = "Permissions")]
    permissions: String,
    #[serde(rename = "Action")]
    action: String,
    #[serde(rename = "_level")]
    level: i32,
}

#[derive(Serialize)]
struct HierarchyLoadRow<'a> {
    #[serde(rename = "Name")]
    name: &'a str,
    #[serde(rename = "Type")]
    kind: &'a str,
    #[serde(rename = "Size")]
    size: &'a str,
    #[serde(rename = "Modified")]
    modified: &'a str,
    #[serde(rename = "Permissions")]
    permissions: &'a str,
    #[serde(rename = "Action")]
    action: &'a str,
}

#[repr(C)]
#[derive(Clone, Copy, Debug)]
struct NativeSurfaceDescriptor {
    magic: u32,
    version: u16,
    kind: u16,
    screen: i32,
    reserved: u32,
    display: *mut libc::c_void,
    surface: *mut libc::c_void,
    window: u64,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum RendererChoice {
    Cpu,
    Gpu,
}

impl RendererChoice {
    fn label(self) -> &'static str {
        match self {
            Self::Cpu => "cpu",
            Self::Gpu => "gpu",
        }
    }

    fn proto_mode(self) -> i32 {
        match self {
            Self::Cpu => pb::RendererMode::RendererCpu as i32,
            Self::Gpu => pb::RendererMode::RendererGpu as i32,
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum RendererSelection {
    Cpu,
    Gpu,
    Both,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum ToggleSelection {
    Off,
    On,
    Both,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum GpuPath {
    Readback,
    Surface,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum FrameBackend {
    Cpu,
    Gpu,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
struct BenchCase {
    renderer: RendererChoice,
    scroll_blit: bool,
}

impl BenchCase {
    fn label(self) -> String {
        format!(
            "requested_renderer={} scroll_blit={}",
            self.renderer.label(),
            self.scroll_blit
        )
    }
}

struct FrameTarget {
    width: i32,
    height: i32,
    surface: ImageSurface,
    present_buffer: Box<[u8]>,
    render_buffer: Box<[u8]>,
}

impl FrameTarget {
    fn new(width: i32, height: i32) -> Result<Self, String> {
        let width = width.max(1);
        let height = height.max(1);
        let stride = width * 4;
        let size = (stride as usize) * (height as usize);
        let mut present_buffer = vec![0u8; size].into_boxed_slice();
        let render_buffer = vec![0u8; size].into_boxed_slice();
        let surface = create_present_surface(&mut present_buffer, width, height, stride)?;
        Ok(Self {
            width,
            height,
            surface,
            present_buffer,
            render_buffer,
        })
    }

    fn render_handle(&self) -> i64 {
        self.render_buffer.as_ptr() as i64
    }

    fn stride(&self) -> i32 {
        self.width * 4
    }

    fn blit_render_to_surface(&mut self) -> Result<(), String> {
        self.surface.flush();
        rgba_to_bgra_copy(&self.render_buffer, &mut self.present_buffer);
        self.surface.mark_dirty();
        Ok(())
    }
}

fn create_present_surface(
    present_buffer: &mut [u8],
    width: i32,
    height: i32,
    stride: i32,
) -> Result<ImageSurface, String> {
    unsafe {
        ImageSurface::create_for_data_unsafe(
            present_buffer.as_mut_ptr(),
            cairo::Format::ARgb32,
            width,
            height,
            stride,
        )
    }
    .map_err(|err| format!("surface create failed: {err}"))
}

struct VisualBufferHost {
    window: Window,
    area: DrawingArea,
    target: std::rc::Rc<std::cell::RefCell<FrameTarget>>,
}

impl VisualBufferHost {
    fn new(title: &str, width: i32, height: i32) -> Result<Self, String> {
        ensure_gtk_initialized()?;

        let window = Window::builder()
            .title(title)
            .default_width(width.max(1))
            .default_height(height.max(1))
            .resizable(false)
            .build();
        let area = DrawingArea::new();
        area.set_content_width(width.max(1));
        area.set_content_height(height.max(1));
        window.set_child(Some(&area));

        let target = std::rc::Rc::new(std::cell::RefCell::new(FrameTarget::new(width, height)?));
        let draw_target = target.clone();
        area.set_draw_func(move |_area, cr, _w, _h| {
            let target = draw_target.borrow();
            let _ = cr.set_source_surface(&target.surface, 0.0, 0.0);
            let _ = cr.paint();
        });

        window.present();
        let _ = wait_for_mapped_surface(&window)?;

        Ok(Self {
            window,
            area,
            target,
        })
    }

    fn width(&self) -> i32 {
        self.target.borrow().width
    }

    fn height(&self) -> i32 {
        self.target.borrow().height
    }

    fn render_handle(&self) -> i64 {
        self.target.borrow().render_handle()
    }

    fn stride(&self) -> i32 {
        self.target.borrow().stride()
    }

    fn present_frame(&self) -> Result<(), String> {
        self.target.borrow_mut().blit_render_to_surface()?;
        self.area.queue_draw();
        pump_gtk_events();
        Ok(())
    }
}

impl Drop for VisualBufferHost {
    fn drop(&mut self) {
        self.window.close();
        pump_gtk_events();
    }
}

struct SurfaceHost {
    window: Window,
    descriptor: Box<NativeSurfaceDescriptor>,
    width: i32,
    height: i32,
}

impl SurfaceHost {
    fn new(title: &str, width: i32, height: i32) -> Result<Self, String> {
        ensure_gtk_initialized()?;

        let window = Window::builder()
            .title(title)
            .default_width(width.max(1))
            .default_height(height.max(1))
            .resizable(false)
            .build();
        window.present();
        let surface = wait_for_mapped_surface(&window)?;
        let descriptor = Box::new(build_native_surface_descriptor(&surface)?);

        Ok(Self {
            window,
            descriptor,
            width: surface.width().max(1),
            height: surface.height().max(1),
        })
    }

    fn surface_handle(&self) -> i64 {
        self.descriptor.as_ref() as *const NativeSurfaceDescriptor as i64
    }
}

impl Drop for SurfaceHost {
    fn drop(&mut self) {
        self.window.close();
        pump_gtk_events();
    }
}

enum BenchHost {
    HeadlessBuffer {
        width: i32,
        height: i32,
        buffer: Box<[u8]>,
    },
    VisualBuffer(VisualBufferHost),
    GpuSurface(SurfaceHost),
}

impl BenchHost {
    fn new(args: &Args, case: BenchCase) -> Result<Self, String> {
        if !args.visual_host {
            let stride = (args.width.max(1) * 4) as usize;
            let size = stride * args.height.max(1) as usize;
            return Ok(Self::HeadlessBuffer {
                width: args.width.max(1),
                height: args.height.max(1),
                buffer: vec![0u8; size].into_boxed_slice(),
            });
        }

        match (case.renderer, args.gpu_path) {
            (RendererChoice::Gpu, GpuPath::Surface) => Ok(Self::GpuSurface(SurfaceHost::new(
                &format!("VolvoxGrid Bench ({})", case.renderer.label()),
                args.width,
                args.height,
            )?)),
            _ => Ok(Self::VisualBuffer(VisualBufferHost::new(
                &format!("VolvoxGrid Bench ({})", case.renderer.label()),
                args.width,
                args.height,
            )?)),
        }
    }

    fn width(&self) -> i32 {
        match self {
            Self::HeadlessBuffer { width, .. } => *width,
            Self::VisualBuffer(host) => host.width(),
            Self::GpuSurface(host) => host.width,
        }
    }

    fn height(&self) -> i32 {
        match self {
            Self::HeadlessBuffer { height, .. } => *height,
            Self::VisualBuffer(host) => host.height(),
            Self::GpuSurface(host) => host.height,
        }
    }

    fn pump_events(&self) {
        if !matches!(self, Self::HeadlessBuffer { .. }) {
            pump_gtk_events();
        }
    }
}

#[derive(Clone, Debug)]
struct Args {
    demo: String,
    width: i32,
    height: i32,
    renderer: RendererSelection,
    scroll_blit: ToggleSelection,
    visual_host: bool,
    gpu_path: GpuPath,
    warmup_steps: usize,
    scroll_steps: usize,
    scroll_delta_y: f32,
    fling_burst: usize,
    fling_max_frames: usize,
    frame_interval_ms: f64,
}

impl Default for Args {
    fn default() -> Self {
        Self {
            demo: DEFAULT_DEMO.to_string(),
            width: DEFAULT_WIDTH,
            height: DEFAULT_HEIGHT,
            renderer: RendererSelection::Both,
            scroll_blit: ToggleSelection::Both,
            visual_host: false,
            gpu_path: GpuPath::Readback,
            warmup_steps: 8,
            scroll_steps: 48,
            scroll_delta_y: 1.5,
            fling_burst: 10,
            fling_max_frames: 180,
            frame_interval_ms: 16.67,
        }
    }
}

#[derive(Clone)]
struct VolvoxServiceClient {
    plugin: Arc<PluginLibrary>,
}

struct BenchSession {
    client: VolvoxServiceClient,
    grid_id: i64,
    render_stream: Arc<PluginStream>,
    host: BenchHost,
}

#[derive(Debug)]
struct FrameResult {
    rendered: bool,
    metrics: Option<pb::FrameMetrics>,
    backend: FrameBackend,
}

#[derive(Clone, Debug)]
struct PhaseStats {
    name: &'static str,
    rendered_frames: usize,
    truncated: bool,
    frame_ms: Vec<f32>,
    total_layer_us: Vec<f32>,
    layer_sum_us: [f64; LAYER_COUNT],
    layer_max_us: [f32; LAYER_COUNT],
    last_zone_counts: [u32; 4],
    cpu_frames: usize,
    gpu_frames: usize,
}

impl PhaseStats {
    fn new(name: &'static str) -> Self {
        Self {
            name,
            rendered_frames: 0,
            truncated: false,
            frame_ms: Vec::new(),
            total_layer_us: Vec::new(),
            layer_sum_us: [0.0; LAYER_COUNT],
            layer_max_us: [0.0; LAYER_COUNT],
            last_zone_counts: [0; 4],
            cpu_frames: 0,
            gpu_frames: 0,
        }
    }

    fn record(&mut self, metrics: &pb::FrameMetrics, backend: FrameBackend) {
        self.rendered_frames += 1;
        self.frame_ms.push(metrics.frame_time_ms);
        match backend {
            FrameBackend::Cpu => self.cpu_frames += 1,
            FrameBackend::Gpu => self.gpu_frames += 1,
        }

        let mut total = 0.0f32;
        for (idx, us) in metrics
            .layer_times_us
            .iter()
            .copied()
            .enumerate()
            .take(LAYER_COUNT)
        {
            total += us;
            self.layer_sum_us[idx] += us as f64;
            self.layer_max_us[idx] = self.layer_max_us[idx].max(us);
        }
        self.total_layer_us.push(total);

        for (idx, count) in metrics
            .zone_cell_counts
            .iter()
            .copied()
            .enumerate()
            .take(self.last_zone_counts.len())
        {
            self.last_zone_counts[idx] = count;
        }
    }

    fn merge(&mut self, other: &Self) {
        self.rendered_frames += other.rendered_frames;
        self.truncated |= other.truncated;
        self.frame_ms.extend_from_slice(&other.frame_ms);
        self.total_layer_us.extend_from_slice(&other.total_layer_us);
        for idx in 0..LAYER_COUNT {
            self.layer_sum_us[idx] += other.layer_sum_us[idx];
            self.layer_max_us[idx] = self.layer_max_us[idx].max(other.layer_max_us[idx]);
        }
        self.last_zone_counts = other.last_zone_counts;
        self.cpu_frames += other.cpu_frames;
        self.gpu_frames += other.gpu_frames;
    }

    fn actual_backend_label(&self) -> &'static str {
        match (self.cpu_frames > 0, self.gpu_frames > 0) {
            (true, false) => "cpu",
            (false, true) => "gpu",
            (true, true) => "mixed",
            (false, false) => "none",
        }
    }

    fn print(&self) {
        println!("== {} ==", self.name);
        println!("rendered_frames: {}", self.rendered_frames);
        println!(
            "actual_backend: {} (cpu_frames={} gpu_frames={})",
            self.actual_backend_label(),
            self.cpu_frames,
            self.gpu_frames
        );
        if self.truncated {
            println!("truncated: true");
        }
        if self.rendered_frames == 0 {
            println!("no rendered frames collected");
            println!();
            return;
        }

        println!(
            "frame_ms avg {:.3} p50 {:.3} p95 {:.3} max {:.3}",
            mean_f32(&self.frame_ms),
            percentile_f32(&self.frame_ms, 0.50),
            percentile_f32(&self.frame_ms, 0.95),
            max_f32(&self.frame_ms),
        );
        println!(
            "layer_total_us avg {:.1} p50 {:.1} p95 {:.1} max {:.1}",
            mean_f32(&self.total_layer_us),
            percentile_f32(&self.total_layer_us, 0.50),
            percentile_f32(&self.total_layer_us, 0.95),
            max_f32(&self.total_layer_us),
        );
        println!(
            "zone_counts last scroll={} sticky={} pinned={} fixed={}",
            self.last_zone_counts[0],
            self.last_zone_counts[1],
            self.last_zone_counts[2],
            self.last_zone_counts[3],
        );
        println!("top_layers:");

        let total_us_sum: f64 = self.layer_sum_us.iter().sum();
        let mut ranking: Vec<usize> = (0..LAYER_COUNT).collect();
        ranking.sort_by(|&a, &b| self.layer_sum_us[b].total_cmp(&self.layer_sum_us[a]));

        for idx in ranking.into_iter().take(8) {
            let avg_us = self.layer_sum_us[idx] / self.rendered_frames as f64;
            if avg_us <= 0.0 {
                continue;
            }
            let pct = if total_us_sum > 0.0 {
                self.layer_sum_us[idx] * 100.0 / total_us_sum
            } else {
                0.0
            };
            println!(
                "  {:<18} avg {:>8.1}us max {:>8.1}us {:>6.1}%",
                LAYER_LABELS[idx], avg_us, self.layer_max_us[idx], pct,
            );
        }
        println!();
    }
}

impl VolvoxServiceClient {
    fn load_default() -> Result<Self, String> {
        let path = resolve_default_plugin_path();
        let plugin = PluginLibrary::load(&path)?;
        Ok(Self { plugin })
    }

    fn create_grid(
        &self,
        width: i32,
        height: i32,
        renderer: RendererChoice,
        scroll_blit: bool,
    ) -> Result<pb::CreateResponse, String> {
        self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/Create",
            &pb::CreateRequest {
                viewport_width: width,
                viewport_height: height,
                scale: 1.0,
                config: Some(pb::GridConfig {
                    layout: Some(pb::LayoutConfig {
                        rows: Some(200),
                        cols: Some(12),
                        fixed_rows: Some(1),
                        fixed_cols: Some(0),
                        default_row_height: Some(24),
                        default_col_width: Some(110),
                        ..Default::default()
                    }),
                    selection: Some(pb::SelectionConfig {
                        mode: Some(pb::SelectionMode::SelectionFree as i32),
                        visibility: Some(pb::SelectionVisibility::SelectionVisAlways as i32),
                        ..Default::default()
                    }),
                    scrolling: Some(pb::ScrollConfig {
                        scroll_bar: Some(pb::ScrollBarConfig {
                            show_h: Some(pb::ScrollBarMode::ScrollbarModeAuto as i32),
                            show_v: Some(pb::ScrollBarMode::ScrollbarModeAuto as i32),
                            ..Default::default()
                        }),
                        fling_enabled: Some(true),
                        fast_scroll: Some(true),
                        ..Default::default()
                    }),
                    rendering: Some(pb::RenderConfig {
                        renderer_mode: Some(renderer.proto_mode()),
                        animation_enabled: Some(true),
                        frame_pacing_mode: Some(pb::FramePacingMode::Auto as i32),
                        target_frame_rate_hz: Some(30),
                        scroll_blit: Some(scroll_blit),
                        ..Default::default()
                    }),
                    ..Default::default()
                }),
            },
        )
    }

    fn configure(&self, grid_id: i64, config: pb::GridConfig) -> Result<(), String> {
        let _: pb::ConfigureResponse = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/Configure",
            &pb::ConfigureRequest {
                grid_id,
                config: Some(config),
            },
        )?;
        Ok(())
    }

    fn load_demo(&self, grid_id: i64, demo: &str) -> Result<(), String> {
        let _: pb::LoadDemoResponse = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/LoadDemo",
            &pb::LoadDemoRequest {
                grid_id,
                demo: demo.to_string(),
            },
        )?;
        Ok(())
    }

    fn get_demo_data(&self, demo: &str) -> Result<Vec<u8>, String> {
        let response: pb::GetDemoDataResponse = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/GetDemoData",
            &pb::GetDemoDataRequest {
                demo: demo.to_string(),
            },
        )?;
        Ok(response.data)
    }

    fn load_data_with_options(
        &self,
        grid_id: i64,
        data: Vec<u8>,
        options: Option<pb::LoadDataOptions>,
    ) -> Result<pb::LoadDataResult, String> {
        self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/LoadData",
            &pb::LoadDataRequest {
                grid_id,
                data,
                options,
            },
        )
    }

    fn define_columns(&self, grid_id: i64, columns: Vec<pb::ColumnDef>) -> Result<(), String> {
        let _: pb::DefineColumnsResponse = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/DefineColumns",
            &pb::DefineColumnsRequest { grid_id, columns },
        )?;
        Ok(())
    }

    fn define_rows(&self, grid_id: i64, rows: Vec<pb::RowDef>) -> Result<(), String> {
        let _: pb::DefineRowsResponse = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/DefineRows",
            &pb::DefineRowsRequest { grid_id, rows },
        )?;
        Ok(())
    }

    fn update_cells(
        &self,
        grid_id: i64,
        cells: Vec<pb::CellUpdate>,
        atomic: bool,
    ) -> Result<(), String> {
        let _: pb::WriteResult = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/UpdateCells",
            &pb::UpdateCellsRequest {
                grid_id,
                cells,
                atomic,
            },
        )?;
        Ok(())
    }

    fn subtotal(
        &self,
        grid_id: i64,
        aggregate: pb::AggregateType,
        group_on_col: i32,
        aggregate_col: i32,
        caption: &str,
        background: u32,
        foreground: u32,
        add_outline: bool,
    ) -> Result<pb::SubtotalResult, String> {
        self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/Subtotal",
            &pb::SubtotalRequest {
                grid_id,
                aggregate: aggregate as i32,
                group_on_col,
                aggregate_col,
                caption: caption.to_string(),
                background,
                foreground,
                add_outline,
                font: None,
            },
        )
    }

    fn get_config(&self, grid_id: i64) -> Result<pb::GridConfig, String> {
        self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/GetConfig",
            &pb::GetConfigRequest { grid_id },
        )
    }

    fn get_node(&self, grid_id: i64, row: i32) -> Result<pb::NodeInfo, String> {
        self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/GetNode",
            &pb::GetNodeRequest {
                grid_id,
                row,
                relation: None,
            },
        )
    }

    fn merge_cells(
        &self,
        grid_id: i64,
        row1: i32,
        col1: i32,
        row2: i32,
        col2: i32,
    ) -> Result<(), String> {
        let _: pb::MergeCellsResponse = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/MergeCells",
            &pb::MergeCellsRequest {
                grid_id,
                range: Some(pb::CellRange {
                    row1,
                    col1,
                    row2,
                    col2,
                }),
            },
        )?;
        Ok(())
    }

    fn resize_viewport(&self, grid_id: i64, width: i32, height: i32) -> Result<(), String> {
        let _: pb::ResizeViewportResponse = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/ResizeViewport",
            &pb::ResizeViewportRequest {
                grid_id,
                width,
                height,
            },
        )?;
        Ok(())
    }

    fn open_render_session(&self) -> Result<Arc<PluginStream>, String> {
        self.plugin
            .open_stream("/volvoxgrid.v1.VolvoxGridService/RenderSession")
    }

    fn invoke<Req, Resp>(&self, method: &str, req: &Req) -> Result<Resp, String>
    where
        Req: Message,
        Resp: Message + Default,
    {
        let data = self.plugin.invoke_raw(method, &req.encode_to_vec())?;
        Resp::decode(data.as_slice()).map_err(|err| format!("decode failed for {method}: {err}"))
    }
}

fn load_sales_json_demo(client: &VolvoxServiceClient, grid_id: i64) -> Result<(), String> {
    client.configure(
        grid_id,
        pb::GridConfig {
            layout: Some(pb::LayoutConfig {
                cols: Some(SALES_DEMO_COLS),
                ..Default::default()
            }),
            ..Default::default()
        },
    )?;
    client.define_columns(
        grid_id,
        vec![
            pb::ColumnDef {
                index: 0,
                width: Some(40),
                caption: Some("Q".to_string()),
                key: Some("Q".to_string()),
                align: Some(pb::Align::CenterCenter as i32),
                span: Some(true),
                ..Default::default()
            },
            pb::ColumnDef {
                index: 1,
                width: Some(80),
                caption: Some("Region".to_string()),
                key: Some("Region".to_string()),
                span: Some(true),
                ..Default::default()
            },
            pb::ColumnDef {
                index: 2,
                width: Some(100),
                caption: Some("Category".to_string()),
                key: Some("Category".to_string()),
                ..Default::default()
            },
            pb::ColumnDef {
                index: 3,
                width: Some(120),
                caption: Some("Product".to_string()),
                key: Some("Product".to_string()),
                ..Default::default()
            },
            pb::ColumnDef {
                index: 4,
                width: Some(90),
                caption: Some("Sales".to_string()),
                key: Some("Sales".to_string()),
                align: Some(pb::Align::RightCenter as i32),
                data_type: Some(pb::ColumnDataType::ColumnDataCurrency as i32),
                format: Some("$#,##0".to_string()),
                ..Default::default()
            },
            pb::ColumnDef {
                index: 5,
                width: Some(90),
                caption: Some("Cost".to_string()),
                key: Some("Cost".to_string()),
                align: Some(pb::Align::RightCenter as i32),
                data_type: Some(pb::ColumnDataType::ColumnDataCurrency as i32),
                format: Some("$#,##0".to_string()),
                ..Default::default()
            },
            pb::ColumnDef {
                index: 6,
                width: Some(70),
                caption: Some("Margin%".to_string()),
                key: Some("Margin".to_string()),
                align: Some(pb::Align::CenterCenter as i32),
                data_type: Some(pb::ColumnDataType::ColumnDataNumber as i32),
                progress_color: Some(0xFF818CF8),
                ..Default::default()
            },
            pb::ColumnDef {
                index: 7,
                width: Some(56),
                caption: Some("Flag".to_string()),
                key: Some("Flag".to_string()),
                align: Some(pb::Align::CenterCenter as i32),
                data_type: Some(pb::ColumnDataType::ColumnDataBoolean as i32),
                ..Default::default()
            },
            pb::ColumnDef {
                index: 8,
                width: Some(80),
                caption: Some("Status".to_string()),
                key: Some("Status".to_string()),
                dropdown: Some(dropdown_from_labels(SALES_STATUS_ITEMS)),
                ..Default::default()
            },
            pb::ColumnDef {
                index: 9,
                width: Some(140),
                caption: Some("Notes".to_string()),
                key: Some("Notes".to_string()),
                ..Default::default()
            },
        ],
    )?;
    let result = client.load_data_with_options(
        grid_id,
        client.get_demo_data(DEMO_SALES)?,
        Some(pb::LoadDataOptions {
            auto_create_columns: Some(false),
            mode: Some(pb::LoadMode::LoadReplace as i32),
            ..Default::default()
        }),
    )?;
    if result.status == pb::LoadDataStatus::LoadFailed as i32 {
        return Err("LoadData failed for embedded sales demo".to_string());
    }

    client.configure(
        grid_id,
        pb::GridConfig {
            layout: Some(pb::LayoutConfig {
                fixed_rows: Some(0),
                extend_last_col: Some(true),
                ..Default::default()
            }),
            editing: Some(pb::EditConfig {
                trigger: Some(pb::EditTrigger::None as i32),
                tab_behavior: Some(pb::TabBehavior::TabCells as i32),
                dropdown_trigger: Some(pb::DropdownTrigger::DropdownAlways as i32),
                dropdown_search: Some(false),
                ..Default::default()
            }),
            scrolling: Some(pb::ScrollConfig {
                scrollbars: Some(pb::ScrollBarsMode::ScrollbarBoth as i32),
                fling_enabled: Some(true),
                fling_impulse_gain: Some(220.0),
                fling_friction: Some(0.9),
                ..Default::default()
            }),
            interaction: Some(pb::InteractionConfig {
                header_features: Some(pb::HeaderFeatures {
                    sort: Some(true),
                    reorder: Some(true),
                    chooser: Some(false),
                }),
                ..Default::default()
            }),
            indicators: Some(pb::IndicatorsConfig {
                row_start: Some(pb::RowIndicatorConfig {
                    visible: Some(true),
                    width: Some(40),
                    mode_bits: Some(pb::RowIndicatorMode::RowIndicatorNumbers as u32),
                    allow_resize: Some(true),
                    ..Default::default()
                }),
                col_top: Some(pb::ColIndicatorConfig {
                    visible: Some(true),
                    default_row_height: Some(28),
                    band_rows: Some(1),
                    mode_bits: Some(
                        (pb::ColIndicatorCellMode::ColIndicatorCellHeaderText as u32)
                            | (pb::ColIndicatorCellMode::ColIndicatorCellSortGlyph as u32),
                    ),
                    allow_resize: Some(true),
                    ..Default::default()
                }),
                ..Default::default()
            }),
            outline: Some(pb::OutlineConfig {
                tree_indicator: Some(pb::TreeIndicatorStyle::TreeIndicatorNone as i32),
                group_total_position: Some(pb::GroupTotalPosition::GroupTotalBelow as i32),
                multi_totals: Some(true),
                ..Default::default()
            }),
            span: Some(pb::SpanConfig {
                cell_span: Some(pb::CellSpanMode::CellSpanAdjacent as i32),
                cell_span_fixed: Some(pb::CellSpanMode::CellSpanNone as i32),
                cell_span_compare: Some(1),
                ..Default::default()
            }),
            ..Default::default()
        },
    )?;

    client.subtotal(grid_id, pb::AggregateType::AggClear, 0, 0, "", 0, 0, false)?;
    apply_sales_subtotal_decorations(
        client,
        grid_id,
        &client.subtotal(
            grid_id,
            pb::AggregateType::AggSum,
            -1,
            4,
            "Grand Total",
            0xFFEEF2FF,
            0xFF111827,
            true,
        )?,
    )?;
    apply_sales_subtotal_decorations(
        client,
        grid_id,
        &client.subtotal(
            grid_id,
            pb::AggregateType::AggSum,
            0,
            4,
            "",
            0xFFF5F3FF,
            0xFF111827,
            true,
        )?,
    )?;
    apply_sales_subtotal_decorations(
        client,
        grid_id,
        &client.subtotal(
            grid_id,
            pb::AggregateType::AggSum,
            1,
            4,
            "",
            0xFFF8F7FF,
            0xFF111827,
            true,
        )?,
    )?;
    apply_sales_subtotal_decorations(
        client,
        grid_id,
        &client.subtotal(
            grid_id,
            pb::AggregateType::AggSum,
            -1,
            5,
            "Grand Total",
            0xFFEEF2FF,
            0xFF111827,
            true,
        )?,
    )?;
    apply_sales_subtotal_decorations(
        client,
        grid_id,
        &client.subtotal(
            grid_id,
            pb::AggregateType::AggSum,
            0,
            5,
            "",
            0xFFF5F3FF,
            0xFF111827,
            true,
        )?,
    )?;
    apply_sales_subtotal_decorations(
        client,
        grid_id,
        &client.subtotal(
            grid_id,
            pb::AggregateType::AggSum,
            1,
            5,
            "",
            0xFFF8F7FF,
            0xFF111827,
            true,
        )?,
    )?;
    Ok(())
}

fn apply_sales_subtotal_decorations(
    client: &VolvoxServiceClient,
    grid_id: i64,
    result: &pb::SubtotalResult,
) -> Result<(), String> {
    let mut unique_rows = result.rows.clone();
    unique_rows.sort_unstable();
    unique_rows.dedup();
    for row in unique_rows {
        if client.get_node(grid_id, row)?.level <= 0 {
            client.merge_cells(grid_id, row, 0, row, 1)?;
        }
    }
    Ok(())
}

fn load_hierarchy_json_demo(client: &VolvoxServiceClient, grid_id: i64) -> Result<(), String> {
    client.configure(
        grid_id,
        pb::GridConfig {
            layout: Some(pb::LayoutConfig {
                cols: Some(HIERARCHY_DEMO_COLS),
                ..Default::default()
            }),
            ..Default::default()
        },
    )?;
    let raw_json = client.get_demo_data(DEMO_HIERARCHY)?;
    let rows: Vec<HierarchyJsonRow> = serde_json::from_slice(&raw_json)
        .map_err(|err| format!("embedded hierarchy demo parse failed: {err}"))?;
    let load_rows: Vec<HierarchyLoadRow<'_>> = rows
        .iter()
        .map(|row| HierarchyLoadRow {
            name: &row.name,
            kind: &row.kind,
            size: &row.size,
            modified: &row.modified,
            permissions: &row.permissions,
            action: &row.action,
        })
        .collect();
    let load_data = serde_json::to_vec(&load_rows)
        .map_err(|err| format!("embedded hierarchy demo encode failed: {err}"))?;
    client.define_columns(
        grid_id,
        vec![
            pb::ColumnDef {
                index: 0,
                width: Some(260),
                caption: Some("Name".to_string()),
                key: Some("Name".to_string()),
                ..Default::default()
            },
            pb::ColumnDef {
                index: 1,
                width: Some(80),
                caption: Some("Type".to_string()),
                key: Some("Type".to_string()),
                ..Default::default()
            },
            pb::ColumnDef {
                index: 2,
                width: Some(80),
                caption: Some("Size".to_string()),
                key: Some("Size".to_string()),
                align: Some(pb::Align::RightCenter as i32),
                ..Default::default()
            },
            pb::ColumnDef {
                index: 3,
                width: Some(120),
                caption: Some("Modified".to_string()),
                key: Some("Modified".to_string()),
                data_type: Some(pb::ColumnDataType::ColumnDataDate as i32),
                format: Some("short date".to_string()),
                ..Default::default()
            },
            pb::ColumnDef {
                index: 4,
                width: Some(100),
                caption: Some("Permissions".to_string()),
                key: Some("Permissions".to_string()),
                align: Some(pb::Align::CenterCenter as i32),
                ..Default::default()
            },
            pb::ColumnDef {
                index: 5,
                width: Some(92),
                caption: Some("Action".to_string()),
                key: Some("Action".to_string()),
                align: Some(pb::Align::CenterCenter as i32),
                interaction: Some(pb::CellInteraction::TextLink as i32),
                ..Default::default()
            },
        ],
    )?;
    let result = client.load_data_with_options(
        grid_id,
        load_data,
        Some(pb::LoadDataOptions {
            auto_create_columns: Some(false),
            mode: Some(pb::LoadMode::LoadReplace as i32),
            ..Default::default()
        }),
    )?;
    if result.status == pb::LoadDataStatus::LoadFailed as i32 {
        return Err("LoadData failed for embedded hierarchy demo".to_string());
    }

    client.configure(
        grid_id,
        pb::GridConfig {
            layout: Some(pb::LayoutConfig {
                fixed_rows: Some(0),
                ..Default::default()
            }),
            selection: Some(pb::SelectionConfig {
                mode: Some(pb::SelectionMode::SelectionFree as i32),
                ..Default::default()
            }),
            editing: Some(pb::EditConfig {
                trigger: Some(pb::EditTrigger::None as i32),
                tab_behavior: Some(pb::TabBehavior::TabCells as i32),
                dropdown_trigger: Some(pb::DropdownTrigger::DropdownNever as i32),
                ..Default::default()
            }),
            scrolling: Some(pb::ScrollConfig {
                scrollbars: Some(pb::ScrollBarsMode::ScrollbarBoth as i32),
                fling_enabled: Some(true),
                fling_impulse_gain: Some(220.0),
                fling_friction: Some(0.9),
                ..Default::default()
            }),
            interaction: Some(pb::InteractionConfig {
                header_features: Some(pb::HeaderFeatures {
                    sort: Some(false),
                    reorder: Some(false),
                    chooser: Some(false),
                }),
                ..Default::default()
            }),
            indicators: Some(pb::IndicatorsConfig {
                row_start: Some(pb::RowIndicatorConfig {
                    visible: Some(false),
                    ..Default::default()
                }),
                col_top: Some(pb::ColIndicatorConfig {
                    visible: Some(true),
                    default_row_height: Some(28),
                    band_rows: Some(1),
                    mode_bits: Some(pb::ColIndicatorCellMode::ColIndicatorCellHeaderText as u32),
                    allow_resize: Some(true),
                    ..Default::default()
                }),
                ..Default::default()
            }),
            outline: Some(pb::OutlineConfig {
                tree_indicator: Some(pb::TreeIndicatorStyle::TreeIndicatorArrowsLeaf as i32),
                tree_column: Some(0),
                ..Default::default()
            }),
            ..Default::default()
        },
    )?;

    client.define_rows(
        grid_id,
        rows.iter()
            .enumerate()
            .map(|(index, row)| pb::RowDef {
                index: index as i32,
                outline_level: Some(row.level),
                is_subtotal: Some(row.kind == "Folder"),
                ..Default::default()
            })
            .collect(),
    )?;

    let action_style = pb::CellStyle {
        foreground: Some(0xFF2563EB),
        ..Default::default()
    };
    let folder_style = pb::CellStyle {
        foreground: Some(0xFF92400E),
        font: Some(pb::Font {
            bold: Some(true),
            ..Default::default()
        }),
        ..Default::default()
    };
    let mut cells = Vec::with_capacity(rows.len() * 2);
    for (index, row) in rows.iter().enumerate() {
        cells.push(pb::CellUpdate {
            row: index as i32,
            col: 5,
            style: Some(action_style.clone()),
            ..Default::default()
        });
        if row.kind == "Folder" {
            cells.push(pb::CellUpdate {
                row: index as i32,
                col: 0,
                style: Some(folder_style.clone()),
                ..Default::default()
            });
        }
    }
    client.update_cells(grid_id, cells, true)?;
    Ok(())
}

impl BenchSession {
    fn new(args: &Args, case: BenchCase) -> Result<Self, String> {
        let host = BenchHost::new(args, case)?;
        let width = host.width();
        let height = host.height();
        let client = VolvoxServiceClient::load_default()?;
        let create = client.create_grid(width, height, case.renderer, case.scroll_blit)?;
        let grid_id = create.grid_id;
        if grid_id <= 0 {
            return Err("create_grid returned no grid id".to_string());
        }

        apply_initial_config_for_grid(&client, grid_id, case.renderer, case.scroll_blit)?;
        client.resize_viewport(grid_id, width, height)?;

        let render_stream = client.open_render_session()?;

        Ok(Self {
            client,
            grid_id,
            render_stream,
            host,
        })
    }

    fn prepare_demo(
        &mut self,
        demo: &str,
        fling_enabled: bool,
        scroll_track: bool,
        renderer: RendererChoice,
        scroll_blit: bool,
    ) -> Result<(), String> {
        match demo {
            DEMO_SALES => load_sales_json_demo(&self.client, self.grid_id)?,
            DEMO_HIERARCHY => load_hierarchy_json_demo(&self.client, self.grid_id)?,
            DEMO_STRESS => self.client.load_demo(self.grid_id, demo)?,
            other => return Err(format!("unknown demo: {other}")),
        }
        self.client.configure(
            self.grid_id,
            pb::GridConfig {
                rendering: Some(pb::RenderConfig {
                    renderer_mode: Some(renderer.proto_mode()),
                    debug_overlay: Some(true),
                    layer_profiling: Some(true),
                    animation_enabled: Some(true),
                    frame_pacing_mode: Some(pb::FramePacingMode::Unlimited as i32),
                    render_layer_mask: Some(
                        ((1i64 << LAYER_COUNT) - 1) & !(1i64 << DEBUG_OVERLAY_BIT),
                    ),
                    scroll_blit: Some(scroll_blit),
                    ..Default::default()
                }),
                scrolling: Some(pb::ScrollConfig {
                    fling_enabled: Some(fling_enabled),
                    scroll_track: Some(scroll_track),
                    fast_scroll: Some(false),
                    ..Default::default()
                }),
                ..Default::default()
            },
        )?;
        let cfg = self.client.get_config(self.grid_id)?;
        let rc = cfg
            .rendering
            .as_ref()
            .ok_or_else(|| "missing rendering config after prepare_demo".to_string())?;
        if rc.layer_profiling != Some(true) && rc.debug_overlay != Some(true) {
            return Err(format!(
                "profiling flags did not stick after configure: layer_profiling={:?} debug_overlay={:?}",
                rc.layer_profiling,
                rc.debug_overlay,
            ));
        }
        self.render_until_clean(None, 256)?;
        Ok(())
    }

    fn current_backend(&self) -> Result<FrameBackend, String> {
        let cfg = self.client.get_config(self.grid_id)?;
        let mode = cfg
            .rendering
            .as_ref()
            .and_then(|rc| rc.renderer_mode)
            .unwrap_or(pb::RendererMode::RendererCpu as i32);
        Ok(if mode >= pb::RendererMode::RendererGpu as i32 {
            FrameBackend::Gpu
        } else {
            FrameBackend::Cpu
        })
    }

    fn send_scroll(&self, dx: f32, dy: f32) -> Result<(), String> {
        let input = pb::RenderInput {
            grid_id: self.grid_id,
            input: Some(pb::render_input::Input::Scroll(pb::ScrollEvent {
                delta_x: dx,
                delta_y: dy,
            })),
        };
        self.render_stream.send_raw(&input.encode_to_vec())
    }

    fn request_frame(&mut self) -> Result<(), String> {
        self.host.pump_events();
        let input = match &mut self.host {
            BenchHost::HeadlessBuffer {
                width,
                height,
                buffer,
            } => pb::RenderInput {
                grid_id: self.grid_id,
                input: Some(pb::render_input::Input::Buffer(pb::BufferReady {
                    handle: buffer.as_mut_ptr() as i64,
                    capacity: buffer.len() as i32,
                    stride: *width * 4,
                    width: *width,
                    height: *height,
                })),
            },
            BenchHost::VisualBuffer(host) => pb::RenderInput {
                grid_id: self.grid_id,
                input: Some(pb::render_input::Input::Buffer(pb::BufferReady {
                    handle: host.render_handle(),
                    capacity: host.stride() * host.height(),
                    stride: host.stride(),
                    width: host.width(),
                    height: host.height(),
                })),
            },
            BenchHost::GpuSurface(host) => pb::RenderInput {
                grid_id: self.grid_id,
                input: Some(pb::render_input::Input::GpuSurface(pb::GpuSurfaceReady {
                    surface_handle: host.surface_handle(),
                    width: host.width,
                    height: host.height,
                })),
            },
        };
        self.render_stream.send_raw(&input.encode_to_vec())
    }

    fn wait_for_frame_result(&mut self) -> Result<FrameResult, String> {
        loop {
            let Some(data) = self.render_stream.recv_raw()? else {
                return Err("render stream closed".to_string());
            };
            let output = pb::RenderOutput::decode(data.as_slice())
                .map_err(|err| format!("decode RenderOutput failed: {err}"))?;
            let Some(event) = output.event else {
                continue;
            };
            match event {
                pb::render_output::Event::FrameDone(frame) => {
                    if output.rendered {
                        if let BenchHost::VisualBuffer(host) = &self.host {
                            host.present_frame()?;
                        }
                    }
                    self.host.pump_events();
                    return Ok(FrameResult {
                        rendered: output.rendered,
                        metrics: frame.metrics,
                        backend: self.current_backend()?,
                    });
                }
                pb::render_output::Event::GpuFrameDone(frame) => {
                    self.host.pump_events();
                    return Ok(FrameResult {
                        rendered: output.rendered,
                        metrics: frame.metrics,
                        backend: FrameBackend::Gpu,
                    });
                }
                _ => {}
            }
        }
    }

    fn render_until_clean(
        &mut self,
        mut stats: Option<&mut PhaseStats>,
        max_frames: usize,
    ) -> Result<usize, String> {
        let mut rendered = 0usize;
        for _ in 0..max_frames {
            self.request_frame()?;
            let frame = self.wait_for_frame_result()?;
            if !frame.rendered {
                return Ok(rendered);
            }
            if let Some(s) = stats.as_deref_mut() {
                let metrics = frame
                    .metrics
                    .as_ref()
                    .ok_or_else(|| "rendered frame missing metrics".to_string())?;
                s.record(metrics, frame.backend);
            }
            rendered += 1;
        }
        Ok(rendered)
    }

    fn paced_render_until_clean(
        &mut self,
        stats: Option<&mut PhaseStats>,
        max_frames: usize,
        frame_interval: Duration,
    ) -> Result<usize, String> {
        if frame_interval.is_zero() {
            return self.render_until_clean(stats, max_frames);
        }

        let mut rendered = 0usize;
        let mut stats = stats;
        for frame_idx in 0..max_frames {
            if frame_idx > 0 {
                std::thread::sleep(frame_interval);
            }
            self.request_frame()?;
            let frame = self.wait_for_frame_result()?;
            if !frame.rendered {
                return Ok(rendered);
            }
            if let Some(s) = stats.as_deref_mut() {
                let metrics = frame
                    .metrics
                    .as_ref()
                    .ok_or_else(|| "rendered frame missing metrics".to_string())?;
                s.record(metrics, frame.backend);
            }
            rendered += 1;
        }
        Ok(rendered)
    }
}

impl Drop for BenchSession {
    fn drop(&mut self) {
        self.render_stream.close();
    }
}

fn ensure_gtk_initialized() -> Result<(), String> {
    if gtk4::is_initialized_main_thread() {
        return Ok(());
    }
    gtk4::init().map_err(|err| format!("gtk init failed: {err}"))
}

fn pump_gtk_events() {
    if !gtk4::is_initialized_main_thread() {
        return;
    }
    let ctx = glib::MainContext::default();
    while ctx.pending() {
        ctx.iteration(false);
    }
}

fn wait_for_mapped_surface(window: &Window) -> Result<gdk::Surface, String> {
    let start = std::time::Instant::now();
    loop {
        pump_gtk_events();
        if let Some(surface) = window.surface() {
            if surface.is_mapped() && surface.width() > 0 && surface.height() > 0 {
                return Ok(surface);
            }
        }
        if start.elapsed() >= GTK_SURFACE_WAIT {
            return Err("timed out waiting for GTK surface to map".to_string());
        }
        std::thread::sleep(Duration::from_millis(10));
    }
}

unsafe fn lookup_gtk_symbol<T>(name: &str) -> Result<T, String> {
    let c_name =
        std::ffi::CString::new(name).map_err(|_| format!("invalid symbol name: {name}"))?;
    let symbol = libc::dlsym(libc::RTLD_DEFAULT, c_name.as_ptr());
    if symbol.is_null() {
        return Err(format!("missing GTK symbol: {name}"));
    }
    Ok(std::mem::transmute_copy(&symbol))
}

fn build_native_surface_descriptor(
    surface: &gdk::Surface,
) -> Result<NativeSurfaceDescriptor, String> {
    type GetWaylandDisplay = unsafe extern "C" fn(*mut libc::c_void) -> *mut libc::c_void;
    type GetWaylandSurface = unsafe extern "C" fn(*mut libc::c_void) -> *mut libc::c_void;
    type GetX11Display = unsafe extern "C" fn(*mut libc::c_void) -> *mut libc::c_void;
    type GetX11Xid = unsafe extern "C" fn(*mut libc::c_void) -> libc::c_ulong;

    let display = surface.display();
    let raw_display = display.as_ptr() as *mut libc::c_void;
    let raw_surface = surface.as_ptr() as *mut libc::c_void;

    match display.backend() {
        gdk::Backend::Wayland => {
            let get_display: GetWaylandDisplay =
                unsafe { lookup_gtk_symbol("gdk_wayland_display_get_wl_display")? };
            let get_surface: GetWaylandSurface =
                unsafe { lookup_gtk_symbol("gdk_wayland_surface_get_wl_surface")? };

            let wl_display = unsafe { get_display(raw_display) };
            let wl_surface = unsafe { get_surface(raw_surface) };
            if wl_display.is_null() || wl_surface.is_null() {
                return Err("failed to resolve Wayland wl_display/wl_surface".to_string());
            }

            Ok(NativeSurfaceDescriptor {
                magic: NATIVE_SURFACE_DESC_MAGIC,
                version: NATIVE_SURFACE_DESC_VERSION,
                kind: NATIVE_SURFACE_KIND_WAYLAND,
                screen: 0,
                reserved: 0,
                display: wl_display,
                surface: wl_surface,
                window: 0,
            })
        }
        gdk::Backend::X11 => {
            let get_display: GetX11Display =
                unsafe { lookup_gtk_symbol("gdk_x11_display_get_xdisplay")? };
            let get_xid: GetX11Xid = unsafe { lookup_gtk_symbol("gdk_x11_surface_get_xid")? };

            let xdisplay = unsafe { get_display(raw_display) };
            let xid = unsafe { get_xid(raw_surface) };
            if xdisplay.is_null() || xid == 0 {
                return Err("failed to resolve X11 Display/XID".to_string());
            }

            Ok(NativeSurfaceDescriptor {
                magic: NATIVE_SURFACE_DESC_MAGIC,
                version: NATIVE_SURFACE_DESC_VERSION,
                kind: NATIVE_SURFACE_KIND_X11,
                screen: 0,
                reserved: 0,
                display: xdisplay,
                surface: std::ptr::null_mut(),
                window: xid as u64,
            })
        }
        other => Err(format!(
            "unsupported GTK backend for GPU surface benchmark: {:?}",
            other
        )),
    }
}

fn rgba_to_bgra_copy(src: &[u8], dst: &mut [u8]) {
    for (src_px, dst_px) in src.chunks_exact(4).zip(dst.chunks_exact_mut(4)) {
        dst_px[0] = src_px[2];
        dst_px[1] = src_px[1];
        dst_px[2] = src_px[0];
        dst_px[3] = src_px[3];
    }
}

fn apply_initial_config_for_grid(
    client: &VolvoxServiceClient,
    grid_id: i64,
    renderer: RendererChoice,
    scroll_blit: bool,
) -> Result<(), String> {
    client.configure(
        grid_id,
        pb::GridConfig {
            rendering: Some(pb::RenderConfig {
                renderer_mode: Some(renderer.proto_mode()),
                animation_enabled: Some(true),
                frame_pacing_mode: Some(pb::FramePacingMode::Auto as i32),
                target_frame_rate_hz: Some(30),
                scroll_blit: Some(scroll_blit),
                ..Default::default()
            }),
            editing: Some(pb::EditConfig {
                host_key_dispatch: Some(false),
                host_pointer_dispatch: Some(false),
                ..Default::default()
            }),
            interaction: Some(pb::InteractionConfig {
                header_features: Some(pb::HeaderFeatures {
                    sort: Some(true),
                    reorder: Some(true),
                    chooser: Some(false),
                }),
                ..Default::default()
            }),
            ..Default::default()
        },
    )
}

fn run_steady_scroll(
    session: &mut BenchSession,
    args: &Args,
    case: BenchCase,
    frame_interval: Duration,
) -> Result<PhaseStats, String> {
    session.prepare_demo(&args.demo, false, false, case.renderer, case.scroll_blit)?;

    for _ in 0..args.warmup_steps {
        session.send_scroll(0.0, args.scroll_delta_y)?;
        let _ = session.paced_render_until_clean(None, 32, frame_interval)?;
    }

    let mut stats = PhaseStats::new("steady_scroll");
    for _ in 0..args.scroll_steps {
        session.send_scroll(0.0, args.scroll_delta_y)?;
        let rendered = session.paced_render_until_clean(Some(&mut stats), 32, frame_interval)?;
        if rendered >= 32 {
            stats.truncated = true;
        }
    }
    Ok(stats)
}

fn run_fling(
    session: &mut BenchSession,
    args: &Args,
    case: BenchCase,
    frame_interval: Duration,
) -> Result<PhaseStats, String> {
    session.prepare_demo(&args.demo, true, true, case.renderer, case.scroll_blit)?;

    for _ in 0..args.fling_burst {
        session.send_scroll(0.0, args.scroll_delta_y)?;
    }

    let mut stats = PhaseStats::new("fling");
    let rendered = session.paced_render_until_clean(
        Some(&mut stats),
        args.fling_max_frames,
        frame_interval,
    )?;
    if rendered >= args.fling_max_frames {
        stats.truncated = true;
    }
    Ok(stats)
}

fn parse_args() -> Result<Args, String> {
    let mut args = Args::default();
    let mut it = std::env::args().skip(1);

    while let Some(arg) = it.next() {
        match arg.as_str() {
            "--demo" => args.demo = next_value(&mut it, "--demo")?,
            "--width" => args.width = parse_i32(&next_value(&mut it, "--width")?, "--width")?,
            "--height" => args.height = parse_i32(&next_value(&mut it, "--height")?, "--height")?,
            "--renderer" => {
                args.renderer =
                    parse_renderer_selection(&next_value(&mut it, "--renderer")?, "--renderer")?
            }
            "--scroll-blit" => args.scroll_blit = ToggleSelection::On,
            "--scroll-blit-mode" => {
                args.scroll_blit = parse_toggle_selection(
                    &next_value(&mut it, "--scroll-blit-mode")?,
                    "--scroll-blit-mode",
                )?
            }
            "--visual-host" => args.visual_host = true,
            "--gpu-path" => {
                args.gpu_path = parse_gpu_path(&next_value(&mut it, "--gpu-path")?, "--gpu-path")?
            }
            "--matrix" => {
                args.renderer = RendererSelection::Both;
                args.scroll_blit = ToggleSelection::Both;
            }
            "--warmup-steps" => {
                args.warmup_steps =
                    parse_usize(&next_value(&mut it, "--warmup-steps")?, "--warmup-steps")?
            }
            "--scroll-steps" => {
                args.scroll_steps =
                    parse_usize(&next_value(&mut it, "--scroll-steps")?, "--scroll-steps")?
            }
            "--scroll-delta-y" => {
                args.scroll_delta_y = parse_f32(
                    &next_value(&mut it, "--scroll-delta-y")?,
                    "--scroll-delta-y",
                )?
            }
            "--fling-burst" => {
                args.fling_burst =
                    parse_usize(&next_value(&mut it, "--fling-burst")?, "--fling-burst")?
            }
            "--fling-max-frames" => {
                args.fling_max_frames = parse_usize(
                    &next_value(&mut it, "--fling-max-frames")?,
                    "--fling-max-frames",
                )?
            }
            "--frame-interval-ms" => {
                args.frame_interval_ms = parse_f64(
                    &next_value(&mut it, "--frame-interval-ms")?,
                    "--frame-interval-ms",
                )?
            }
            "--help" | "-h" => {
                print_usage();
                std::process::exit(0);
            }
            other => return Err(format!("unknown argument: {other}")),
        }
    }

    if args.width <= 0 || args.height <= 0 {
        return Err("width and height must be positive".to_string());
    }
    if args.frame_interval_ms < 0.0 {
        return Err("frame interval must be non-negative".to_string());
    }
    if args.gpu_path == GpuPath::Surface {
        args.visual_host = true;
    }

    Ok(args)
}

fn next_value(it: &mut impl Iterator<Item = String>, flag: &str) -> Result<String, String> {
    it.next().ok_or_else(|| format!("missing value for {flag}"))
}

fn parse_i32(value: &str, flag: &str) -> Result<i32, String> {
    value
        .parse::<i32>()
        .map_err(|err| format!("invalid {flag}: {err}"))
}

fn parse_usize(value: &str, flag: &str) -> Result<usize, String> {
    value
        .parse::<usize>()
        .map_err(|err| format!("invalid {flag}: {err}"))
}

fn parse_f32(value: &str, flag: &str) -> Result<f32, String> {
    value
        .parse::<f32>()
        .map_err(|err| format!("invalid {flag}: {err}"))
}

fn parse_f64(value: &str, flag: &str) -> Result<f64, String> {
    value
        .parse::<f64>()
        .map_err(|err| format!("invalid {flag}: {err}"))
}

fn parse_renderer_selection(value: &str, flag: &str) -> Result<RendererSelection, String> {
    match value {
        "cpu" => Ok(RendererSelection::Cpu),
        "gpu" => Ok(RendererSelection::Gpu),
        "both" | "all" => Ok(RendererSelection::Both),
        _ => Err(format!(
            "invalid {flag}: expected cpu, gpu, or both, got {value}"
        )),
    }
}

fn parse_toggle_selection(value: &str, flag: &str) -> Result<ToggleSelection, String> {
    match value {
        "off" => Ok(ToggleSelection::Off),
        "on" => Ok(ToggleSelection::On),
        "both" | "all" => Ok(ToggleSelection::Both),
        _ => Err(format!(
            "invalid {flag}: expected off, on, or both, got {value}"
        )),
    }
}

fn parse_gpu_path(value: &str, flag: &str) -> Result<GpuPath, String> {
    match value {
        "readback" => Ok(GpuPath::Readback),
        "surface" => Ok(GpuPath::Surface),
        _ => Err(format!(
            "invalid {flag}: expected readback or surface, got {value}"
        )),
    }
}

fn bench_cases(args: &Args) -> Vec<BenchCase> {
    let renderers: &[RendererChoice] = match args.renderer {
        RendererSelection::Cpu => &[RendererChoice::Cpu],
        RendererSelection::Gpu => &[RendererChoice::Gpu],
        RendererSelection::Both => &[RendererChoice::Cpu, RendererChoice::Gpu],
    };
    let scroll_blit_values: &[bool] = match args.scroll_blit {
        ToggleSelection::Off => &[false],
        ToggleSelection::On => &[true],
        ToggleSelection::Both => &[false, true],
    };

    let mut cases = Vec::with_capacity(renderers.len() * scroll_blit_values.len());
    for &renderer in renderers {
        for &scroll_blit in scroll_blit_values {
            cases.push(BenchCase {
                renderer,
                scroll_blit,
            });
        }
    }
    cases
}

fn print_usage() {
    println!("volvoxgrid headless benchmark");
    println!("  --demo <sales|hierarchy|stress>");
    println!("  --width <px>");
    println!("  --height <px>");
    println!("  --renderer <cpu|gpu|both>");
    println!("  --scroll-blit");
    println!("  --scroll-blit-mode <off|on|both>");
    println!("  --visual-host");
    println!("  --gpu-path <readback|surface>");
    println!("  --matrix");
    println!("Defaults: renderer=both, scroll_blit=both, gpu_path=readback");
    println!("  --warmup-steps <count>");
    println!("  --scroll-steps <count>");
    println!("  --scroll-delta-y <delta>");
    println!("  --fling-burst <count>");
    println!("  --fling-max-frames <count>");
    println!("  --frame-interval-ms <ms>");
}

#[derive(Clone, Debug)]
struct BenchOutcome {
    case: BenchCase,
    steady: PhaseStats,
    fling: PhaseStats,
    combined: PhaseStats,
}

fn print_summary(outcomes: &[BenchOutcome]) {
    if outcomes.is_empty() {
        return;
    }

    println!("== summary ==");
    for outcome in outcomes {
        let avg = mean_f32(&outcome.combined.frame_ms);
        let p95 = percentile_f32(&outcome.combined.frame_ms, 0.95);
        let max = max_f32(&outcome.combined.frame_ms);
        println!(
            "renderer={} scroll_blit={} actual={} steady_avg={:.3}ms fling_avg={:.3}ms combined_avg={:.3}ms combined_p95={:.3}ms combined_max={:.3}ms",
            outcome.case.renderer.label(),
            outcome.case.scroll_blit,
            outcome.combined.actual_backend_label(),
            mean_f32(&outcome.steady.frame_ms),
            mean_f32(&outcome.fling.frame_ms),
            avg,
            p95,
            max,
        );
    }
    println!();
}

fn mean_f32(values: &[f32]) -> f32 {
    if values.is_empty() {
        return 0.0;
    }
    values.iter().sum::<f32>() / values.len() as f32
}

fn max_f32(values: &[f32]) -> f32 {
    values.iter().copied().fold(0.0, f32::max)
}

fn percentile_f32(values: &[f32], percentile: f32) -> f32 {
    if values.is_empty() {
        return 0.0;
    }
    let mut sorted = values.to_vec();
    sorted.sort_by(|a, b| a.total_cmp(b));
    let rank = ((sorted.len() - 1) as f32 * percentile.clamp(0.0, 1.0)).round() as usize;
    sorted[rank]
}

fn main() -> Result<(), String> {
    let args = parse_args()?;
    let cases = bench_cases(&args);
    let frame_interval = if args.frame_interval_ms <= 0.0 {
        Duration::ZERO
    } else {
        Duration::from_secs_f64(args.frame_interval_ms / 1000.0)
    };

    println!(
        "benchmark demo={} viewport={}x{} renderer={:?} scroll_blit={:?} visual_host={} gpu_path={:?} cases={} warmup_steps={} scroll_steps={} fling_burst={} frame_interval_ms={:.2}",
        args.demo,
        args.width,
        args.height,
        args.renderer,
        args.scroll_blit,
        args.visual_host,
        args.gpu_path,
        cases.len(),
        args.warmup_steps,
        args.scroll_steps,
        args.fling_burst,
        args.frame_interval_ms,
    );

    let mut outcomes = Vec::with_capacity(cases.len());
    for case in cases {
        println!();
        println!("## {}", case.label());

        let mut session = BenchSession::new(&args, case)?;
        let steady = run_steady_scroll(&mut session, &args, case, frame_interval)?;
        let fling = run_fling(&mut session, &args, case, frame_interval)?;

        let mut combined = PhaseStats::new("combined");
        combined.merge(&steady);
        combined.merge(&fling);

        steady.print();
        fling.print();
        combined.print();

        outcomes.push(BenchOutcome {
            case,
            steady,
            fling,
            combined,
        });
    }

    print_summary(&outcomes);

    Ok(())
}
