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

use ffi::{resolve_default_plugin_path, PluginLibrary, PluginStream};
use prost::Message;
use proto::volvoxgrid::v1 as pb;

const DEFAULT_WIDTH: i32 = 1280;
const DEFAULT_HEIGHT: i32 = 900;
const DEFAULT_DEMO: &str = "sales";
const LAYER_COUNT: usize = 26;
const DEBUG_OVERLAY_BIT: i64 = 25;
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
    "Debug Overlay",
];

#[derive(Clone, Debug)]
struct Args {
    demo: String,
    width: i32,
    height: i32,
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
    width: i32,
    height: i32,
    buffer: Box<[u8]>,
}

#[derive(Debug)]
struct FrameResult {
    rendered: bool,
    metrics: Option<pb::FrameMetrics>,
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
        }
    }

    fn record(&mut self, metrics: &pb::FrameMetrics) {
        self.rendered_frames += 1;
        self.frame_ms.push(metrics.frame_time_ms);

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
    }

    fn print(&self) {
        println!("== {} ==", self.name);
        println!("rendered_frames: {}", self.rendered_frames);
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

    fn create_grid(&self, width: i32, height: i32) -> Result<pb::CreateResponse, String> {
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
                        scrollbars: Some(pb::ScrollBarsMode::ScrollbarBoth as i32),
                        fling_enabled: Some(true),
                        fast_scroll: Some(true),
                        ..Default::default()
                    }),
                    rendering: Some(pb::RenderConfig {
                        renderer_mode: Some(pb::RendererMode::RendererCpu as i32),
                        animation_enabled: Some(true),
                        frame_pacing_mode: Some(pb::FramePacingMode::Auto as i32),
                        target_frame_rate_hz: Some(30),
                        ..Default::default()
                    }),
                    ..Default::default()
                }),
            },
        )
    }

    fn configure(&self, grid_id: i64, config: pb::GridConfig) -> Result<(), String> {
        let _: pb::Empty = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/Configure",
            &pb::ConfigureRequest {
                grid_id,
                config: Some(config),
            },
        )?;
        Ok(())
    }

    fn load_demo(&self, grid_id: i64, demo: &str) -> Result<(), String> {
        let _: pb::Empty = self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/LoadDemo",
            &pb::LoadDemoRequest {
                grid_id,
                demo: demo.to_string(),
            },
        )?;
        Ok(())
    }

    fn get_config(&self, grid_id: i64) -> Result<pb::GridConfig, String> {
        self.invoke(
            "/volvoxgrid.v1.VolvoxGridService/GetConfig",
            &pb::GridHandle { id: grid_id },
        )
    }

    fn resize_viewport(&self, grid_id: i64, width: i32, height: i32) -> Result<(), String> {
        let _: pb::Empty = self.invoke(
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

impl BenchSession {
    fn new(args: &Args) -> Result<Self, String> {
        let client = VolvoxServiceClient::load_default()?;
        let create = client.create_grid(args.width, args.height)?;
        let grid_id = create
            .handle
            .as_ref()
            .map(|h| h.id)
            .ok_or_else(|| "create_grid returned no handle".to_string())?;

        apply_initial_config_for_grid(&client, grid_id)?;
        client.resize_viewport(grid_id, args.width, args.height)?;

        let render_stream = client.open_render_session()?;
        let stride = (args.width.max(1) * 4) as usize;
        let size = stride * args.height.max(1) as usize;
        let buffer = vec![0u8; size].into_boxed_slice();

        Ok(Self {
            client,
            grid_id,
            render_stream,
            width: args.width,
            height: args.height,
            buffer,
        })
    }

    fn prepare_demo(
        &mut self,
        demo: &str,
        fling_enabled: bool,
        scroll_track: bool,
    ) -> Result<(), String> {
        self.client.load_demo(self.grid_id, demo)?;
        self.client.configure(
            self.grid_id,
            pb::GridConfig {
                rendering: Some(pb::RenderConfig {
                    renderer_mode: Some(pb::RendererMode::RendererCpu as i32),
                    debug_overlay: Some(true),
                    layer_profiling: Some(true),
                    animation_enabled: Some(true),
                    frame_pacing_mode: Some(pb::FramePacingMode::Unlimited as i32),
                    render_layer_mask: Some(
                        ((1i64 << LAYER_COUNT) - 1) & !(1i64 << DEBUG_OVERLAY_BIT),
                    ),
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
        let input = pb::RenderInput {
            grid_id: self.grid_id,
            input: Some(pb::render_input::Input::Buffer(pb::BufferReady {
                handle: self.buffer.as_mut_ptr() as i64,
                stride: self.width * 4,
                width: self.width,
                height: self.height,
            })),
        };
        self.render_stream.send_raw(&input.encode_to_vec())
    }

    fn wait_for_frame_result(&self) -> Result<FrameResult, String> {
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
                    return Ok(FrameResult {
                        rendered: output.rendered,
                        metrics: frame.metrics,
                    });
                }
                pb::render_output::Event::GpuFrameDone(frame) => {
                    return Ok(FrameResult {
                        rendered: output.rendered,
                        metrics: frame.metrics,
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
                s.record(metrics);
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
                s.record(metrics);
            }
            rendered += 1;
        }
        Ok(rendered)
    }
}

fn apply_initial_config_for_grid(client: &VolvoxServiceClient, grid_id: i64) -> Result<(), String> {
    client.configure(
        grid_id,
        pb::GridConfig {
            rendering: Some(pb::RenderConfig {
                renderer_mode: Some(pb::RendererMode::RendererCpu as i32),
                animation_enabled: Some(true),
                frame_pacing_mode: Some(pb::FramePacingMode::Auto as i32),
                target_frame_rate_hz: Some(30),
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
    frame_interval: Duration,
) -> Result<PhaseStats, String> {
    session.prepare_demo(&args.demo, false, false)?;

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
    frame_interval: Duration,
) -> Result<PhaseStats, String> {
    session.prepare_demo(&args.demo, true, true)?;

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

fn print_usage() {
    println!("volvoxgrid headless benchmark");
    println!("  --demo <sales|hierarchy|stress>");
    println!("  --width <px>");
    println!("  --height <px>");
    println!("  --warmup-steps <count>");
    println!("  --scroll-steps <count>");
    println!("  --scroll-delta-y <delta>");
    println!("  --fling-burst <count>");
    println!("  --fling-max-frames <count>");
    println!("  --frame-interval-ms <ms>");
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
    let frame_interval = if args.frame_interval_ms <= 0.0 {
        Duration::ZERO
    } else {
        Duration::from_secs_f64(args.frame_interval_ms / 1000.0)
    };

    println!(
        "benchmark demo={} viewport={}x{} warmup_steps={} scroll_steps={} fling_burst={} frame_interval_ms={:.2}",
        args.demo,
        args.width,
        args.height,
        args.warmup_steps,
        args.scroll_steps,
        args.fling_burst,
        args.frame_interval_ms,
    );

    let mut session = BenchSession::new(&args)?;
    let steady = run_steady_scroll(&mut session, &args, frame_interval)?;
    let fling = run_fling(&mut session, &args, frame_interval)?;

    let mut combined = PhaseStats::new("combined");
    combined.merge(&steady);
    combined.merge(&fling);

    println!();
    steady.print();
    fling.print();
    combined.print();

    Ok(())
}
