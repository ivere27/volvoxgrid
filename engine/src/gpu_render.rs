//! GPU renderer for VolvoxGrid using wgpu.
//!
//! Provides zero-copy rendering directly to a GPU surface or readback to a
//! CPU buffer. Uses instanced colored quads (rect pipeline) and instanced
//! textured quads (textured pipeline) to replicate all CPU rendering layers.

use std::collections::HashMap;

use bytemuck::{Pod, Zeroable};
use wgpu::util::DeviceExt;

use crate::canvas::{render_grid, RenderResult};
use crate::canvas_gpu::GpuCanvas;
use crate::glyph_atlas::GlyphAtlas;
use crate::grid::VolvoxGrid;
use crate::text::TextEngine;

/// Minimal block_on for futures that resolve immediately (e.g. wgpu error scopes).
/// Avoids pulling in an async runtime dependency.
/// Only used on native targets; WASM surfaces don't suffer from native window
/// lifecycle issues and pop_error_scope requires the browser event loop.
#[cfg(not(target_arch = "wasm32"))]
fn block_on_immediate<F: std::future::Future>(f: F) -> F::Output {
    let mut f = std::pin::pin!(f);
    let waker = std::task::Waker::noop();
    let mut cx = std::task::Context::from_waker(&waker);
    loop {
        match f.as_mut().poll(&mut cx) {
            std::task::Poll::Ready(v) => return v,
            std::task::Poll::Pending => std::hint::spin_loop(),
        }
    }
}

// ---------------------------------------------------------------------------
// GPU instance data structures
// ---------------------------------------------------------------------------

#[repr(C)]
#[derive(Clone, Copy, Debug, Pod, Zeroable)]
struct Uniforms {
    viewport_size: [f32; 2],
    _pad: [f32; 2],
}

#[repr(C)]
#[derive(Clone, Copy, Debug, Pod, Zeroable)]
pub struct RectInstance {
    pub rect: [f32; 4],    // x, y, w, h
    pub color: [f32; 4],   // r, g, b, a
    pub pattern: [f32; 2], // style (0=solid, 1=dotted, 2=dashed), unused
}

#[repr(C)]
#[derive(Clone, Copy, Debug, Pod, Zeroable)]
pub struct TexturedInstance {
    pub rect: [f32; 4],    // x, y, w, h (dest pixels)
    pub uv_rect: [f32; 4], // u_min, v_min, u_max, v_max
    pub color: [f32; 4],   // tint RGBA
    pub flags: [f32; 2],   // x: mode (0=glyph, 1=image), y: atlas page index
}

// ---------------------------------------------------------------------------
// GpuRenderer
// ---------------------------------------------------------------------------

#[cfg(target_os = "android")]
#[link(name = "android")]
extern "C" {
    fn ANativeWindow_acquire(window: *mut std::ffi::c_void);
    fn ANativeWindow_release(window: *mut std::ffi::c_void);
}

/// GPU renderer for VolvoxGrid.
pub struct GpuRenderer {
    #[allow(dead_code)]
    instance: wgpu::Instance,
    adapter: wgpu::Adapter,
    device: wgpu::Device,
    queue: wgpu::Queue,

    // Pipelines (created lazily or recreated when surface format changes)
    pipeline_format: wgpu::TextureFormat,
    rect_pipeline: wgpu::RenderPipeline,
    textured_pipeline: wgpu::RenderPipeline,

    // Uniform buffer + bind group
    uniform_buf: wgpu::Buffer,
    uniform_bind_group: wgpu::BindGroup,
    uniform_bind_group_layout: wgpu::BindGroupLayout,

    // Textured bind group layout (for atlas textures)
    textured_bind_group_layout: wgpu::BindGroupLayout,

    // Surface for zero-copy rendering
    surface: Option<wgpu::Surface<'static>>,
    surface_config: Option<wgpu::SurfaceConfiguration>,
    #[cfg(target_os = "android")]
    active_native_window: Option<*mut std::ffi::c_void>,

    // Glyph atlas
    glyph_atlas: GlyphAtlas,
    atlas_textures: Vec<wgpu::Texture>,
    atlas_bind_groups: Vec<wgpu::BindGroup>,
    atlas_sampler: wgpu::Sampler,

    // Text shaping engine (shared with CpuCanvas via Canvas trait)
    text_engine: TextEngine,

    // Reusable buffer for glyph layout (avoids per-draw_text allocation)
    glyph_buf: Vec<(crate::glyph_atlas::GlyphEntry, f32, f32)>,

    // Per-text glyph position cache: maps hash of (text, font, size, bold, italic)
    // to the Vec of (GlyphEntry, dx, dy) positions. Skips layout_text_glyphs on hit.
    glyph_pos_cache: hashbrown::HashMap<u64, Vec<(crate::glyph_atlas::GlyphEntry, f32, f32)>>,
    glyph_pos_cache_font_gen: u64,

    // Image texture cache
    _image_textures: HashMap<u64, (wgpu::Texture, wgpu::BindGroup, u32, u32)>,

    // Per-frame instance buffers
    rect_instances: Vec<RectInstance>,
    textured_instances: Vec<TexturedInstance>,

    // Overlay instance buffers (drawn after main pass so they appear on top)
    overlay_rect_instances: Vec<RectInstance>,
    overlay_textured_instances: Vec<TexturedInstance>,

    // Persistent GPU vertex buffers (reused across frames)
    persistent_rect_buf: Option<wgpu::Buffer>,
    persistent_rect_cap: usize,
    persistent_tex_buf: Option<wgpu::Buffer>,
    persistent_tex_cap: usize,
    persistent_overlay_rect_buf: Option<wgpu::Buffer>,
    persistent_overlay_rect_cap: usize,
    persistent_overlay_tex_buf: Option<wgpu::Buffer>,
    persistent_overlay_tex_cap: usize,
}

impl GpuRenderer {
    /// Create a new GPU renderer.
    ///
    /// This is async because wgpu adapter/device creation is async.
    /// `preferred_backends` allows overriding the default backend selection.
    pub async fn new(preferred_backends: Option<wgpu::Backends>) -> Result<Self, String> {
        // On wasm, use only the WebGPU browser backend.
        #[cfg(target_arch = "wasm32")]
        let backends = wgpu::Backends::BROWSER_WEBGPU;

        #[cfg(not(target_arch = "wasm32"))]
        let backends = if let Some(b) = preferred_backends {
            b
        } else {
            // On Android, prefer GL over Vulkan to avoid Adreno driver bugs where
            // internal capability probing of high-precision formats (like 56/59)
            // fails during instance/device creation even if they aren't used.
            #[cfg(target_os = "android")]
            {
                wgpu::Backends::GL
            }
            #[cfg(not(target_os = "android"))]
            {
                wgpu::Backends::all()
            }
        };

        let instance = wgpu::Instance::new(&wgpu::InstanceDescriptor {
            backends,
            flags: wgpu::InstanceFlags::default() | wgpu::InstanceFlags::DISCARD_HAL_LABELS,
            ..Default::default()
        });

        let adapter = instance
            .request_adapter(&wgpu::RequestAdapterOptions {
                power_preference: wgpu::PowerPreference::HighPerformance,
                compatible_surface: None,
                force_fallback_adapter: false,
            })
            .await
            .ok_or_else(|| "No suitable GPU adapter found".to_string())?;

        let (device, queue) = adapter
            .request_device(
                &wgpu::DeviceDescriptor {
                    label: Some("VolvoxGrid GPU"),
                    required_features: wgpu::Features::empty(),
                    required_limits: adapter.limits(),
                    memory_hints: wgpu::MemoryHints::Performance,
                },
                None,
            )
            .await
            .map_err(|e| format!("Failed to create GPU device: {}", e))?;

        // Uniform bind group layout
        let uniform_bind_group_layout =
            device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
                label: Some("uniform_bgl"),
                entries: &[wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    visibility: wgpu::ShaderStages::VERTEX_FRAGMENT,
                    ty: wgpu::BindingType::Buffer {
                        ty: wgpu::BufferBindingType::Uniform,
                        has_dynamic_offset: false,
                        min_binding_size: None,
                    },
                    count: None,
                }],
            });

        let uniform_buf = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("uniforms"),
            contents: bytemuck::bytes_of(&Uniforms {
                viewport_size: [1.0, 1.0],
                _pad: [0.0, 0.0],
            }),
            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
        });

        let uniform_bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("uniform_bg"),
            layout: &uniform_bind_group_layout,
            entries: &[wgpu::BindGroupEntry {
                binding: 0,
                resource: uniform_buf.as_entire_binding(),
            }],
        });

        // Textured bind group layout
        let textured_bind_group_layout =
            device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
                label: Some("textured_bgl"),
                entries: &[
                    wgpu::BindGroupLayoutEntry {
                        binding: 0,
                        visibility: wgpu::ShaderStages::FRAGMENT,
                        ty: wgpu::BindingType::Texture {
                            sample_type: wgpu::TextureSampleType::Float { filterable: true },
                            view_dimension: wgpu::TextureViewDimension::D2,
                            multisampled: false,
                        },
                        count: None,
                    },
                    wgpu::BindGroupLayoutEntry {
                        binding: 1,
                        visibility: wgpu::ShaderStages::FRAGMENT,
                        ty: wgpu::BindingType::Sampler(wgpu::SamplerBindingType::Filtering),
                        count: None,
                    },
                ],
            });

        let default_format = wgpu::TextureFormat::Rgba8Unorm;
        let (rect_pipeline, textured_pipeline) = Self::create_pipelines(
            &device,
            &uniform_bind_group_layout,
            &textured_bind_group_layout,
            default_format,
        );

        let atlas_sampler = device.create_sampler(&wgpu::SamplerDescriptor {
            label: Some("atlas_sampler"),
            mag_filter: wgpu::FilterMode::Linear,
            min_filter: wgpu::FilterMode::Linear,
            ..Default::default()
        });

        let text_engine = TextEngine::new();

        Ok(Self {
            instance,
            adapter,
            device,
            queue,
            pipeline_format: default_format,
            rect_pipeline,
            textured_pipeline,
            uniform_buf,
            uniform_bind_group,
            uniform_bind_group_layout,
            textured_bind_group_layout,
            surface: None,
            surface_config: None,
            #[cfg(target_os = "android")]
            active_native_window: None,
            glyph_atlas: GlyphAtlas::new(),
            atlas_textures: Vec::new(),
            atlas_bind_groups: Vec::new(),
            atlas_sampler,
            text_engine,
            glyph_buf: Vec::new(),
            glyph_pos_cache: hashbrown::HashMap::new(),
            glyph_pos_cache_font_gen: 0,
            _image_textures: HashMap::new(),
            rect_instances: Vec::new(),
            textured_instances: Vec::new(),
            overlay_rect_instances: Vec::new(),
            overlay_textured_instances: Vec::new(),
            persistent_rect_buf: None,
            persistent_rect_cap: 0,
            persistent_tex_buf: None,
            persistent_tex_cap: 0,
            persistent_overlay_rect_buf: None,
            persistent_overlay_rect_cap: 0,
            persistent_overlay_tex_buf: None,
            persistent_overlay_tex_cap: 0,
        })
    }

    fn create_pipelines(
        device: &wgpu::Device,
        uniform_bgl: &wgpu::BindGroupLayout,
        textured_bgl: &wgpu::BindGroupLayout,
        format: wgpu::TextureFormat,
    ) -> (wgpu::RenderPipeline, wgpu::RenderPipeline) {
        let rect_shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("rect_shader"),
            source: wgpu::ShaderSource::Wgsl(include_str!("shaders/rect.wgsl").into()),
        });

        let textured_shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("textured_shader"),
            source: wgpu::ShaderSource::Wgsl(include_str!("shaders/textured.wgsl").into()),
        });

        let rect_instance_layout = wgpu::VertexBufferLayout {
            array_stride: std::mem::size_of::<RectInstance>() as u64,
            step_mode: wgpu::VertexStepMode::Instance,
            attributes: &[
                wgpu::VertexAttribute {
                    format: wgpu::VertexFormat::Float32x4,
                    offset: 0,
                    shader_location: 0,
                },
                wgpu::VertexAttribute {
                    format: wgpu::VertexFormat::Float32x4,
                    offset: 16,
                    shader_location: 1,
                },
                wgpu::VertexAttribute {
                    format: wgpu::VertexFormat::Float32x2,
                    offset: 32,
                    shader_location: 2,
                },
            ],
        };

        let textured_instance_layout = wgpu::VertexBufferLayout {
            array_stride: std::mem::size_of::<TexturedInstance>() as u64,
            step_mode: wgpu::VertexStepMode::Instance,
            attributes: &[
                wgpu::VertexAttribute {
                    format: wgpu::VertexFormat::Float32x4,
                    offset: 0,
                    shader_location: 0,
                },
                wgpu::VertexAttribute {
                    format: wgpu::VertexFormat::Float32x4,
                    offset: 16,
                    shader_location: 1,
                },
                wgpu::VertexAttribute {
                    format: wgpu::VertexFormat::Float32x4,
                    offset: 32,
                    shader_location: 2,
                },
                wgpu::VertexAttribute {
                    format: wgpu::VertexFormat::Float32x2,
                    offset: 48,
                    shader_location: 3,
                },
            ],
        };

        let blend_alpha = wgpu::BlendState {
            color: wgpu::BlendComponent {
                src_factor: wgpu::BlendFactor::SrcAlpha,
                dst_factor: wgpu::BlendFactor::OneMinusSrcAlpha,
                operation: wgpu::BlendOperation::Add,
            },
            alpha: wgpu::BlendComponent {
                src_factor: wgpu::BlendFactor::One,
                dst_factor: wgpu::BlendFactor::OneMinusSrcAlpha,
                operation: wgpu::BlendOperation::Add,
            },
        };

        let blend_premul = wgpu::BlendState {
            color: wgpu::BlendComponent {
                src_factor: wgpu::BlendFactor::One,
                dst_factor: wgpu::BlendFactor::OneMinusSrcAlpha,
                operation: wgpu::BlendOperation::Add,
            },
            alpha: wgpu::BlendComponent {
                src_factor: wgpu::BlendFactor::One,
                dst_factor: wgpu::BlendFactor::OneMinusSrcAlpha,
                operation: wgpu::BlendOperation::Add,
            },
        };

        let rect_pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: Some("rect_pl"),
            bind_group_layouts: &[uniform_bgl],
            push_constant_ranges: &[],
        });

        let rect_pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("rect_pipeline"),
            layout: Some(&rect_pipeline_layout),
            vertex: wgpu::VertexState {
                module: &rect_shader,
                entry_point: Some("vs_main"),
                buffers: &[rect_instance_layout],
                compilation_options: Default::default(),
            },
            fragment: Some(wgpu::FragmentState {
                module: &rect_shader,
                entry_point: Some("fs_main"),
                targets: &[Some(wgpu::ColorTargetState {
                    format,
                    blend: Some(blend_alpha),
                    write_mask: wgpu::ColorWrites::ALL,
                })],
                compilation_options: Default::default(),
            }),
            primitive: wgpu::PrimitiveState {
                topology: wgpu::PrimitiveTopology::TriangleList,
                ..Default::default()
            },
            depth_stencil: None,
            multisample: wgpu::MultisampleState::default(),
            multiview: None,
            cache: None,
        });

        let textured_pipeline_layout =
            device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
                label: Some("textured_pl"),
                bind_group_layouts: &[uniform_bgl, textured_bgl],
                push_constant_ranges: &[],
            });

        let textured_pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("textured_pipeline"),
            layout: Some(&textured_pipeline_layout),
            vertex: wgpu::VertexState {
                module: &textured_shader,
                entry_point: Some("vs_main"),
                buffers: &[textured_instance_layout],
                compilation_options: Default::default(),
            },
            fragment: Some(wgpu::FragmentState {
                module: &textured_shader,
                entry_point: Some("fs_main"),
                targets: &[Some(wgpu::ColorTargetState {
                    format,
                    blend: Some(blend_premul),
                    write_mask: wgpu::ColorWrites::ALL,
                })],
                compilation_options: Default::default(),
            }),
            primitive: wgpu::PrimitiveState {
                topology: wgpu::PrimitiveTopology::TriangleList,
                ..Default::default()
            },
            depth_stencil: None,
            multisample: wgpu::MultisampleState::default(),
            multiview: None,
            cache: None,
        });

        (rect_pipeline, textured_pipeline)
    }

    /// Create a surface from a raw native window handle (Android ANativeWindow*, etc.).
    ///
    /// If `native_window_ptr` is null, drops the existing surface.
    /// On Android, builds an `AndroidNdkWindowHandle` + `AndroidDisplayHandle`.
    ///
    /// # Safety
    /// The caller must ensure `native_window_ptr` is a valid ANativeWindow* that
    /// remains valid for the duration of this call, and that `w`/`h` match the
    /// window dimensions.
    #[cfg(not(target_arch = "wasm32"))]
    #[allow(unused_variables)]
    pub async unsafe fn configure_surface_from_raw_handle(
        &mut self,
        native_window_ptr: *mut std::ffi::c_void,
        w: u32,
        h: u32,
        requested_present_mode: i32,
    ) -> Result<(), String> {
        if native_window_ptr.is_null() {
            self.drop_surface();
            return Ok(());
        }

        // Drop existing surface before creating a new one to ensure old handles are released.
        self.drop_surface();

        // Build platform-specific raw handles
        #[cfg(target_os = "android")]
        let (raw_window, raw_display) = {
            // Take an owned native window reference for this configured surface.
            // We release it from drop_surface() when the surface is replaced/dropped.
            ANativeWindow_acquire(native_window_ptr);
            self.active_native_window = Some(native_window_ptr);

            let wh = raw_window_handle::AndroidNdkWindowHandle::new(
                std::ptr::NonNull::new(native_window_ptr)
                    .ok_or_else(|| "null ANativeWindow pointer".to_string())?,
            );
            let dh = raw_window_handle::AndroidDisplayHandle::new();
            (
                raw_window_handle::RawWindowHandle::AndroidNdk(wh),
                raw_window_handle::RawDisplayHandle::Android(dh),
            )
        };

        #[cfg(not(target_os = "android"))]
        return Err("configure_surface_from_raw_handle: unsupported platform".to_string());

        #[cfg(target_os = "android")]
        {
            let target = wgpu::SurfaceTargetUnsafe::RawHandle {
                raw_window_handle: raw_window,
                raw_display_handle: raw_display,
            };

            let surface = self
                .instance
                .create_surface_unsafe(target)
                .map_err(|e| format!("Failed to create surface from raw handle: {}", e))?;

            // Check if the current adapter is compatible with this surface.
            let caps = surface.get_capabilities(&self.adapter);
            if caps.formats.is_empty() {
                // Re-request adapter with compatible_surface
                let new_adapter = self
                    .instance
                    .request_adapter(&wgpu::RequestAdapterOptions {
                        power_preference: wgpu::PowerPreference::HighPerformance,
                        compatible_surface: Some(&surface),
                        force_fallback_adapter: false,
                    })
                    .await
                    .ok_or_else(|| "No GPU adapter compatible with surface".to_string())?;

                let (new_device, new_queue) = new_adapter
                    .request_device(
                        &wgpu::DeviceDescriptor {
                            label: Some("VolvoxGrid GPU"),
                            required_features: wgpu::Features::empty(),
                            required_limits: new_adapter.limits(),
                            memory_hints: wgpu::MemoryHints::Performance,
                        },
                        None,
                    )
                    .await
                    .map_err(|e| format!("Failed to create GPU device: {}", e))?;

                self.adapter = new_adapter;
                self.device = new_device;
                self.queue = new_queue;

                // Rebuild uniform bind group layout and buffer
                self.uniform_bind_group_layout =
                    self.device
                        .create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
                            label: Some("uniform_bgl"),
                            entries: &[wgpu::BindGroupLayoutEntry {
                                binding: 0,
                                visibility: wgpu::ShaderStages::VERTEX_FRAGMENT,
                                ty: wgpu::BindingType::Buffer {
                                    ty: wgpu::BufferBindingType::Uniform,
                                    has_dynamic_offset: false,
                                    min_binding_size: None,
                                },
                                count: None,
                            }],
                        });

                self.uniform_buf =
                    self.device
                        .create_buffer_init(&wgpu::util::BufferInitDescriptor {
                            label: Some("uniforms"),
                            contents: bytemuck::bytes_of(&Uniforms {
                                viewport_size: [1.0, 1.0],
                                _pad: [0.0, 0.0],
                            }),
                            usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
                        });

                self.uniform_bind_group =
                    self.device.create_bind_group(&wgpu::BindGroupDescriptor {
                        label: Some("uniform_bg"),
                        layout: &self.uniform_bind_group_layout,
                        entries: &[wgpu::BindGroupEntry {
                            binding: 0,
                            resource: self.uniform_buf.as_entire_binding(),
                        }],
                    });

                // Rebuild textured bind group layout
                self.textured_bind_group_layout =
                    self.device
                        .create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
                            label: Some("textured_bgl"),
                            entries: &[
                                wgpu::BindGroupLayoutEntry {
                                    binding: 0,
                                    visibility: wgpu::ShaderStages::FRAGMENT,
                                    ty: wgpu::BindingType::Texture {
                                        sample_type: wgpu::TextureSampleType::Float {
                                            filterable: true,
                                        },
                                        view_dimension: wgpu::TextureViewDimension::D2,
                                        multisampled: false,
                                    },
                                    count: None,
                                },
                                wgpu::BindGroupLayoutEntry {
                                    binding: 1,
                                    visibility: wgpu::ShaderStages::FRAGMENT,
                                    ty: wgpu::BindingType::Sampler(
                                        wgpu::SamplerBindingType::Filtering,
                                    ),
                                    count: None,
                                },
                            ],
                        });

                self.atlas_sampler = self.device.create_sampler(&wgpu::SamplerDescriptor {
                    label: Some("atlas_sampler"),
                    mag_filter: wgpu::FilterMode::Linear,
                    min_filter: wgpu::FilterMode::Linear,
                    ..Default::default()
                });

                // Clear cached GPU resources that belong to the old device
                self.atlas_textures.clear();
                self.atlas_bind_groups.clear();
                self.glyph_atlas.clear();
                self.persistent_rect_buf = None;
                self.persistent_rect_cap = 0;
                self.persistent_tex_buf = None;
                self.persistent_tex_cap = 0;
                self.persistent_overlay_rect_buf = None;
                self.persistent_overlay_rect_cap = 0;
                self.persistent_overlay_tex_buf = None;
                self.persistent_overlay_tex_cap = 0;

                // Reset pipeline format to force recreation of pipelines with the new device
                self.pipeline_format = wgpu::TextureFormat::Rgba8Uint;
            }

            if !self.configure_surface(surface, w, h, requested_present_mode) {
                return Err("Surface configuration failed (incompatible surface)".to_string());
            }
            Ok(())
        }
    }

    /// Drop the current surface (e.g. when the native window is destroyed).
    pub fn drop_surface(&mut self) {
        self.surface = None;
        self.surface_config = None;
        #[cfg(target_os = "android")]
        if let Some(window) = self.active_native_window.take() {
            unsafe {
                ANativeWindow_release(window);
            }
        }
    }

    /// Returns true if a surface is currently configured for zero-copy rendering.
    pub fn has_surface(&self) -> bool {
        self.surface.is_some()
    }

    /// Returns the name of the underlying graphics API backend.
    pub fn backend_name(&self) -> String {
        match self.adapter.get_info().backend {
            wgpu::Backend::Vulkan => "Vulkan".to_string(),
            wgpu::Backend::Metal => "Metal".to_string(),
            wgpu::Backend::Dx12 => "DX12".to_string(),
            wgpu::Backend::Gl => "OpenGL".to_string(),
            wgpu::Backend::BrowserWebGpu => "WebGPU".to_string(),
            _ => format!("{:?}", self.adapter.get_info().backend),
        }
    }

    /// Returns the underlying graphics API backend type.
    pub fn backend_type(&self) -> wgpu::Backend {
        self.adapter.get_info().backend
    }

    /// Returns the name of the active presentation mode.
    pub fn present_mode_name(&self) -> String {
        match self.surface_config.as_ref().map(|c| c.present_mode) {
            Some(wgpu::PresentMode::Fifo) => "Fifo".to_string(),
            Some(wgpu::PresentMode::Mailbox) => "Mailbox".to_string(),
            Some(wgpu::PresentMode::Immediate) => "Immediate".to_string(),
            Some(wgpu::PresentMode::FifoRelaxed) => "FifoRelaxed".to_string(),
            _ => "Unknown".to_string(),
        }
    }

    /// Returns the total number of instances (rects + text) produced in the last render pass.
    pub fn instance_count(&self) -> usize {
        self.rect_instances.len()
            + self.textured_instances.len()
            + self.overlay_rect_instances.len()
            + self.overlay_textured_instances.len()
    }

    /// Returns the number of entries currently in the text layout cache.
    pub fn text_cache_len(&self) -> usize {
        self.text_engine.layout_cache.len()
    }
}

impl Drop for GpuRenderer {
    fn drop(&mut self) {
        self.drop_surface();
    }
}

impl GpuRenderer {
    /// Create a surface from an HTML canvas element (wasm32 only) and configure it.
    #[cfg(target_arch = "wasm32")]
    pub fn configure_surface_from_canvas(
        &mut self,
        canvas: web_sys::HtmlCanvasElement,
        w: u32,
        h: u32,
        requested_present_mode: i32,
    ) -> Result<(), String> {
        let surface = self
            .instance
            .create_surface(wgpu::SurfaceTarget::Canvas(canvas))
            .map_err(|e| format!("Failed to create surface from canvas: {}", e))?;
        if !self.configure_surface(surface, w, h, requested_present_mode) {
            return Err("Surface configuration failed (incompatible surface)".to_string());
        }
        Ok(())
    }

    /// Configure a surface for zero-copy rendering.
    ///
    /// Queries the surface capabilities to determine the preferred texture
    /// format and recreates pipelines if it differs from the current one.
    /// Returns `false` if configuration failed (surface dropped).
    pub fn configure_surface(
        &mut self,
        surface: wgpu::Surface<'static>,
        w: u32,
        h: u32,
        requested_present_mode: i32,
    ) -> bool {
        let caps = surface.get_capabilities(&self.adapter);
        if caps.formats.is_empty() {
            // Surface is invalid or incompatible. Drop it to avoid crash in configure.
            self.drop_surface();
            return false;
        }

        // Prioritize standard 8-bit formats to match CPU blit and ensure wide compatibility.
        // This naturally avoids problematic high-precision formats (like Rgba16Float or Rgb10a2Unorm)
        // that cause Adreno driver failures, as they are not in our priority list.
        let format = [
            wgpu::TextureFormat::Rgba8Unorm,
            wgpu::TextureFormat::Bgra8Unorm,
            wgpu::TextureFormat::Rgba8UnormSrgb,
            wgpu::TextureFormat::Bgra8UnormSrgb,
        ]
        .into_iter()
        .find(|f| caps.formats.contains(f))
        .unwrap_or_else(|| {
            caps.formats
                .iter()
                .find(|f| !f.is_srgb())
                .copied()
                .unwrap_or_else(|| {
                    caps.formats
                        .first()
                        .copied()
                        .unwrap_or(wgpu::TextureFormat::Rgba8Unorm)
                })
        });

        // Recreate pipelines if the surface prefers a different format.
        if format != self.pipeline_format {
            let (rect, textured) = Self::create_pipelines(
                &self.device,
                &self.uniform_bind_group_layout,
                &self.textured_bind_group_layout,
                format,
            );
            self.rect_pipeline = rect;
            self.textured_pipeline = textured;
            self.pipeline_format = format;
        }

        let present_mode = match requested_present_mode {
            1 => wgpu::PresentMode::Fifo,
            2 if caps.present_modes.contains(&wgpu::PresentMode::Mailbox) => {
                wgpu::PresentMode::Mailbox
            }
            3 if caps.present_modes.contains(&wgpu::PresentMode::Immediate) => {
                wgpu::PresentMode::Immediate
            }
            _ => wgpu::PresentMode::Fifo, // Auto defaults to Fifo (vsync)
        };

        let config = wgpu::SurfaceConfiguration {
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
            format,
            width: w.max(1),
            height: h.max(1),
            present_mode,
            alpha_mode: wgpu::CompositeAlphaMode::Auto,
            view_formats: vec![],
            desired_maximum_frame_latency: if present_mode == wgpu::PresentMode::Mailbox {
                2
            } else {
                1
            },
        };

        // On native targets, use error scopes to catch validation errors
        // (e.g. "Invalid surface", "queue family incompatible") instead of
        // letting wgpu abort the process. On WASM, pop_error_scope is truly
        // async and requires the browser event loop, but WASM surfaces don't
        // suffer from native window lifecycle issues.
        #[cfg(not(target_arch = "wasm32"))]
        {
            self.device.push_error_scope(wgpu::ErrorFilter::Validation);
            surface.configure(&self.device, &config);
            let error = block_on_immediate(self.device.pop_error_scope());
            if error.is_some() {
                self.drop_surface();
                return false;
            }
        }
        #[cfg(target_arch = "wasm32")]
        {
            surface.configure(&self.device, &config);
        }

        self.surface_config = Some(config);
        self.surface = Some(surface);
        true
    }

    /// Resize an already-configured surface.
    pub fn resize_surface(&mut self, w: u32, h: u32) {
        let (new_w, new_h) = (w.max(1), h.max(1));

        // Fast-path: check if the surface is still backed by a live native window.
        if let Some(ref surface) = self.surface {
            let caps = surface.get_capabilities(&self.adapter);
            if caps.formats.is_empty() {
                self.drop_surface();
                return;
            }
        }

        if let Some(ref mut config) = self.surface_config {
            config.width = new_w;
            config.height = new_h;
            if let Some(ref surface) = self.surface {
                #[cfg(not(target_arch = "wasm32"))]
                {
                    self.device.push_error_scope(wgpu::ErrorFilter::Validation);
                    surface.configure(&self.device, config);
                    let error = block_on_immediate(self.device.pop_error_scope());
                    if error.is_some() {
                        self.surface = None;
                        #[cfg(target_os = "android")]
                        if let Some(window) = self.active_native_window.take() {
                            unsafe {
                                ANativeWindow_release(window);
                            }
                        }
                    }
                }
                #[cfg(target_arch = "wasm32")]
                {
                    surface.configure(&self.device, config);
                }
            }
        }
        if self.surface.is_none() {
            self.surface_config = None;
        }
    }

    /// Load font data (TTF/OTF/TTC) into the GPU renderer's text engine.
    pub fn load_font_data(&mut self, data: Vec<u8>) {
        self.text_engine.load_font_data(data);
        self.glyph_atlas.clear();
    }

    /// Register an external glyph rasterizer for fallback when SwashCache
    /// cannot produce a glyph (e.g. missing fonts on WASM).
    pub fn set_external_glyph_rasterizer(
        &mut self,
        r: Box<dyn crate::glyph_atlas::ExternalGlyphRasterizer>,
    ) {
        self.glyph_atlas.set_external_rasterizer(r);
    }

    /// Render directly to the configured GPU surface (zero-copy).
    ///
    /// Returns `RenderResult`: dirty rect, per-layer times (us), zone cell counts.
    pub fn render_to_surface(
        &mut self,
        grid: &VolvoxGrid,
        w: i32,
        h: i32,
    ) -> Result<RenderResult, wgpu::SurfaceError> {
        let surface = match self.surface.as_ref() {
            Some(s) => s,
            None => return Err(wgpu::SurfaceError::Lost),
        };

        let frame = match surface.get_current_texture() {
            Ok(f) => f,
            Err(e) => return Err(e),
        };

        let view = frame
            .texture
            .create_view(&wgpu::TextureViewDescriptor::default());

        let result = self.render_to_view(grid, &view, w, h);

        frame.present();
        Ok(result)
    }

    /// Render to a CPU buffer (readback mode / fallback).
    ///
    /// Renders to an offscreen texture, then copies pixels back to `buf`.
    /// `buf` must be at least `stride * height` bytes.
    pub fn render_to_buffer(
        &mut self,
        grid: &VolvoxGrid,
        buf: &mut [u8],
        w: i32,
        h: i32,
        stride: i32,
    ) -> RenderResult {
        if w <= 0 || h <= 0 {
            return ((0, 0, 0, 0), [0.0; crate::canvas::layer::COUNT], [0; 4]);
        }

        let uw = w as u32;
        let uh = h as u32;

        // Create offscreen render target
        let texture = self.device.create_texture(&wgpu::TextureDescriptor {
            label: Some("readback_target"),
            size: wgpu::Extent3d {
                width: uw,
                height: uh,
                depth_or_array_layers: 1,
            },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format: self.pipeline_format,
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT | wgpu::TextureUsages::COPY_SRC,
            view_formats: &[],
        });

        let view = texture.create_view(&wgpu::TextureViewDescriptor::default());
        let render_result = self.render_to_view(grid, &view, w, h);

        // Copy texture to buffer for readback
        let bytes_per_row = uw * 4;
        let padded_bytes_per_row = (bytes_per_row + 255) & !255; // wgpu alignment
        let readback_buf = self.device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("readback_buf"),
            size: (padded_bytes_per_row * uh) as u64,
            usage: wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::MAP_READ,
            mapped_at_creation: false,
        });

        let mut encoder = self
            .device
            .create_command_encoder(&wgpu::CommandEncoderDescriptor {
                label: Some("readback_encoder"),
            });

        encoder.copy_texture_to_buffer(
            wgpu::TexelCopyTextureInfo {
                texture: &texture,
                mip_level: 0,
                origin: wgpu::Origin3d::ZERO,
                aspect: wgpu::TextureAspect::All,
            },
            wgpu::TexelCopyBufferInfo {
                buffer: &readback_buf,
                layout: wgpu::TexelCopyBufferLayout {
                    offset: 0,
                    bytes_per_row: Some(padded_bytes_per_row),
                    rows_per_image: Some(uh),
                },
            },
            wgpu::Extent3d {
                width: uw,
                height: uh,
                depth_or_array_layers: 1,
            },
        );

        self.queue.submit(std::iter::once(encoder.finish()));

        let is_bgra = matches!(
            self.pipeline_format,
            wgpu::TextureFormat::Bgra8Unorm | wgpu::TextureFormat::Bgra8UnormSrgb
        );

        // Map and copy
        let buffer_slice = readback_buf.slice(..);
        let (tx, rx) = std::sync::mpsc::channel();
        buffer_slice.map_async(wgpu::MapMode::Read, move |result| {
            let _ = tx.send(result);
        });
        self.device.poll(wgpu::Maintain::Wait);
        if rx.recv().map(|r| r.is_ok()).unwrap_or(false) {
            let data = buffer_slice.get_mapped_range();
            let row_bytes = (w * 4) as usize;
            for y in 0..h as usize {
                let src_off = y * padded_bytes_per_row as usize;
                let dst_off = y * stride as usize;
                if src_off + row_bytes <= data.len() && dst_off + row_bytes <= buf.len() {
                    buf[dst_off..dst_off + row_bytes]
                        .copy_from_slice(&data[src_off..src_off + row_bytes]);

                    if is_bgra {
                        let mut i = dst_off;
                        let end = dst_off + row_bytes;
                        while i + 3 < end {
                            buf.swap(i, i + 2);
                            i += 4;
                        }
                    }
                }
            }
        }

        render_result
    }

    // -----------------------------------------------------------------------
    // Internal: render to a wgpu TextureView
    // -----------------------------------------------------------------------

    fn render_to_view(
        &mut self,
        grid: &VolvoxGrid,
        view: &wgpu::TextureView,
        w: i32,
        h: i32,
    ) -> RenderResult {
        // Keep renderer-owned text cache policy in sync with runtime grid config.
        if self.text_engine.layout_cache_cap != grid.text_layout_cache_cap {
            self.text_engine
                .set_layout_cache_cap(grid.text_layout_cache_cap);
        }

        // Update uniforms
        self.queue.write_buffer(
            &self.uniform_buf,
            0,
            bytemuck::bytes_of(&Uniforms {
                viewport_size: [w as f32, h as f32],
                _pad: [0.0, 0.0],
            }),
        );

        // Invalidate glyph position cache when fonts change.
        let font_gen = self.text_engine.font_generation;
        if font_gen != self.glyph_pos_cache_font_gen {
            self.glyph_pos_cache.clear();
            self.glyph_pos_cache_font_gen = font_gen;
        }

        // Build all instance data
        self.rect_instances.clear();
        self.textured_instances.clear();
        self.overlay_rect_instances.clear();
        self.overlay_textured_instances.clear();
        let render_result = {
            let mut gpu_canvas = GpuCanvas::new(
                &mut self.rect_instances,
                &mut self.textured_instances,
                &mut self.overlay_rect_instances,
                &mut self.overlay_textured_instances,
                &mut self.glyph_atlas,
                &mut self.text_engine,
                &mut self.glyph_buf,
                &mut self.glyph_pos_cache,
                w,
                h,
            );
            render_grid(grid, &mut gpu_canvas)
        };

        // Ensure atlas textures are up to date
        self.sync_atlas_textures();

        // Update persistent vertex buffers (realloc with 2x headroom when needed)
        let has_rects = ensure_buffer(
            &self.device,
            &self.queue,
            &mut self.persistent_rect_buf,
            &mut self.persistent_rect_cap,
            "rect_instances",
            bytemuck::cast_slice(&self.rect_instances),
        );
        let has_tex = ensure_buffer(
            &self.device,
            &self.queue,
            &mut self.persistent_tex_buf,
            &mut self.persistent_tex_cap,
            "textured_instances",
            bytemuck::cast_slice(&self.textured_instances),
        );
        let has_overlay_rects = ensure_buffer(
            &self.device,
            &self.queue,
            &mut self.persistent_overlay_rect_buf,
            &mut self.persistent_overlay_rect_cap,
            "overlay_rect_instances",
            bytemuck::cast_slice(&self.overlay_rect_instances),
        );
        let has_overlay_tex = ensure_buffer(
            &self.device,
            &self.queue,
            &mut self.persistent_overlay_tex_buf,
            &mut self.persistent_overlay_tex_cap,
            "overlay_textured_instances",
            bytemuck::cast_slice(&self.overlay_textured_instances),
        );

        // Encode render pass
        let bkg = color_to_f32(grid.style.back_color_bkg);
        let mut encoder = self
            .device
            .create_command_encoder(&wgpu::CommandEncoderDescriptor {
                label: Some("frame_encoder"),
            });

        {
            let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("main_pass"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view,
                    resolve_target: None,
                    ops: wgpu::Operations {
                        load: wgpu::LoadOp::Clear(wgpu::Color {
                            r: bkg[0] as f64,
                            g: bkg[1] as f64,
                            b: bkg[2] as f64,
                            a: bkg[3] as f64,
                        }),
                        store: wgpu::StoreOp::Store,
                    },
                })],
                depth_stencil_attachment: None,
                timestamp_writes: None,
                occlusion_query_set: None,
            });

            // --- Main layer: rects then textured ---
            if has_rects {
                let buf = self.persistent_rect_buf.as_ref().unwrap();
                let count = self.rect_instances.len() as u32;
                pass.set_pipeline(&self.rect_pipeline);
                pass.set_bind_group(0, &self.uniform_bind_group, &[]);
                pass.set_vertex_buffer(0, buf.slice(..));
                pass.draw(0..6, 0..count);
            }

            if has_tex {
                let buf = self.persistent_tex_buf.as_ref().unwrap();
                pass.set_pipeline(&self.textured_pipeline);
                pass.set_bind_group(0, &self.uniform_bind_group, &[]);
                pass.set_vertex_buffer(0, buf.slice(..));
                draw_textured_batches(&mut pass, &self.textured_instances, &self.atlas_bind_groups);
            }

            // --- Overlay layer (editor + dropdown): rects then textured ---
            // Drawn after all main content so popups float on top.
            if has_overlay_rects {
                let buf = self.persistent_overlay_rect_buf.as_ref().unwrap();
                let count = self.overlay_rect_instances.len() as u32;
                pass.set_pipeline(&self.rect_pipeline);
                pass.set_bind_group(0, &self.uniform_bind_group, &[]);
                pass.set_vertex_buffer(0, buf.slice(..));
                pass.draw(0..6, 0..count);
            }

            if has_overlay_tex {
                let buf = self.persistent_overlay_tex_buf.as_ref().unwrap();
                pass.set_pipeline(&self.textured_pipeline);
                pass.set_bind_group(0, &self.uniform_bind_group, &[]);
                pass.set_vertex_buffer(0, buf.slice(..));
                draw_textured_batches(
                    &mut pass,
                    &self.overlay_textured_instances,
                    &self.atlas_bind_groups,
                );
            }
        }

        self.queue.submit(std::iter::once(encoder.finish()));

        render_result
    }

    // -----------------------------------------------------------------------
    // Atlas texture sync
    // -----------------------------------------------------------------------

    fn sync_atlas_textures(&mut self) {
        let atlas_size = self.glyph_atlas.atlas_size();
        while self.atlas_textures.len() < self.glyph_atlas.page_count() {
            let tex = self.device.create_texture(&wgpu::TextureDescriptor {
                label: Some("atlas_page"),
                size: wgpu::Extent3d {
                    width: atlas_size,
                    height: atlas_size,
                    depth_or_array_layers: 1,
                },
                mip_level_count: 1,
                sample_count: 1,
                dimension: wgpu::TextureDimension::D2,
                format: wgpu::TextureFormat::R8Unorm,
                usage: wgpu::TextureUsages::TEXTURE_BINDING | wgpu::TextureUsages::COPY_DST,
                view_formats: &[],
            });
            let view = tex.create_view(&wgpu::TextureViewDescriptor::default());
            let bind_group = self.device.create_bind_group(&wgpu::BindGroupDescriptor {
                label: Some("atlas_bg"),
                layout: &self.textured_bind_group_layout,
                entries: &[
                    wgpu::BindGroupEntry {
                        binding: 0,
                        resource: wgpu::BindingResource::TextureView(&view),
                    },
                    wgpu::BindGroupEntry {
                        binding: 1,
                        resource: wgpu::BindingResource::Sampler(&self.atlas_sampler),
                    },
                ],
            });
            self.atlas_textures.push(tex);
            self.atlas_bind_groups.push(bind_group);
        }

        // Upload dirty pages
        let atlas_size = self.glyph_atlas.atlas_size();
        for i in 0..self.glyph_atlas.page_count() {
            let page = self.glyph_atlas.page_mut(i);
            if page.dirty {
                self.queue.write_texture(
                    wgpu::TexelCopyTextureInfo {
                        texture: &self.atlas_textures[i],
                        mip_level: 0,
                        origin: wgpu::Origin3d::ZERO,
                        aspect: wgpu::TextureAspect::All,
                    },
                    &page.pixels,
                    wgpu::TexelCopyBufferLayout {
                        offset: 0,
                        bytes_per_row: Some(atlas_size),
                        rows_per_image: Some(atlas_size),
                    },
                    wgpu::Extent3d {
                        width: atlas_size,
                        height: atlas_size,
                        depth_or_array_layers: 1,
                    },
                );
                page.dirty = false;
            }
        }
    }
}

/// Reuse or grow a persistent GPU vertex buffer and upload `data` into it.
///
/// Returns `true` if `data` is non-empty (i.e. the buffer is ready for drawing).
/// Allocates with 2× headroom to reduce future reallocations.
fn ensure_buffer(
    device: &wgpu::Device,
    queue: &wgpu::Queue,
    existing: &mut Option<wgpu::Buffer>,
    capacity: &mut usize,
    label: &str,
    data: &[u8],
) -> bool {
    if data.is_empty() {
        return false;
    }
    if *capacity < data.len() || existing.is_none() {
        let new_cap = data.len() * 2;
        *existing = Some(device.create_buffer(&wgpu::BufferDescriptor {
            label: Some(label),
            size: new_cap as u64,
            usage: wgpu::BufferUsages::VERTEX | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        }));
        *capacity = new_cap;
    }
    queue.write_buffer(existing.as_ref().unwrap(), 0, data);
    true
}

/// Draw textured instances in stable order while switching atlas pages as needed.
fn draw_textured_batches(
    pass: &mut wgpu::RenderPass<'_>,
    instances: &[TexturedInstance],
    atlas_bind_groups: &[wgpu::BindGroup],
) {
    if instances.is_empty() {
        return;
    }

    // Fallback: draw everything with whatever texture is currently bound.
    if atlas_bind_groups.is_empty() {
        pass.draw(0..6, 0..instances.len() as u32);
        return;
    }

    let page_of = |inst: &TexturedInstance| -> usize {
        let raw = inst.flags[1];
        if raw.is_finite() && raw >= 0.0 {
            raw as usize
        } else {
            0
        }
    };

    // Keep original draw order by batching only contiguous page runs.
    let mut run_start = 0usize;
    let mut run_page = page_of(&instances[0]);
    let len = instances.len();

    for idx in 1..=len {
        let boundary = idx == len || page_of(&instances[idx]) != run_page;
        if !boundary {
            continue;
        }

        let page_index = run_page.min(atlas_bind_groups.len().saturating_sub(1));
        pass.set_bind_group(1, &atlas_bind_groups[page_index], &[]);
        pass.draw(0..6, run_start as u32..idx as u32);

        if idx < len {
            run_start = idx;
            run_page = page_of(&instances[idx]);
        }
    }
}

/// Convert a packed 0xAARRGGBB color to normalized `[r, g, b, a]`.
fn color_to_f32(c: u32) -> [f32; 4] {
    let a = ((c >> 24) & 0xFF) as f32 / 255.0;
    let r = ((c >> 16) & 0xFF) as f32 / 255.0;
    let g = ((c >> 8) & 0xFF) as f32 / 255.0;
    let b = (c & 0xFF) as f32 / 255.0;
    [r, g, b, a]
}
