// Instanced textured-quad shader for VolvoxGrid GPU renderer.
//
// Each instance is an axis-aligned rectangle sampling from a texture atlas.
// Used for: glyph atlas text rendering and cell picture images.

struct Uniforms {
    viewport_size: vec2<f32>,
    _pad: vec2<f32>,
}

@group(0) @binding(0) var<uniform> uniforms: Uniforms;
@group(1) @binding(0) var t_atlas: texture_2d<f32>;
@group(1) @binding(1) var s_atlas: sampler;

struct TexturedInstance {
    // Pixel-space destination rectangle: (x, y, width, height).
    @location(0) rect: vec4<f32>,
    // UV rectangle in the atlas: (u_min, v_min, u_max, v_max).
    @location(1) uv_rect: vec4<f32>,
    // Tint color (premultiplied alpha for text; white for images).
    @location(2) color: vec4<f32>,
    // Flags: x = mode (0=alpha-only/glyph, 1=full RGBA/image).
    @location(3) flags: vec2<f32>,
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
    @location(1) color: vec4<f32>,
    @location(2) flags: vec2<f32>,
}

var<private> QUAD_POS: array<vec2<f32>, 6> = array<vec2<f32>, 6>(
    vec2<f32>(0.0, 0.0),
    vec2<f32>(1.0, 0.0),
    vec2<f32>(0.0, 1.0),
    vec2<f32>(1.0, 0.0),
    vec2<f32>(1.0, 1.0),
    vec2<f32>(0.0, 1.0),
);

@vertex
fn vs_main(
    @builtin(vertex_index) vertex_index: u32,
    instance: TexturedInstance,
) -> VertexOutput {
    let quad = QUAD_POS[vertex_index];

    let pixel_pos = instance.rect.xy + quad * instance.rect.zw;
    let ndc = vec2<f32>(
        (pixel_pos.x / uniforms.viewport_size.x) * 2.0 - 1.0,
        1.0 - (pixel_pos.y / uniforms.viewport_size.y) * 2.0,
    );

    // Interpolate UVs across the quad.
    let uv = mix(instance.uv_rect.xy, instance.uv_rect.zw, quad);

    var out: VertexOutput;
    out.position = vec4<f32>(ndc, 0.0, 1.0);
    out.uv = uv;
    out.color = instance.color;
    out.flags = instance.flags;
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let tex = textureSample(t_atlas, s_atlas, in.uv);
    let mode = i32(in.flags.x);

    if mode == 0 {
        // Alpha-only glyph mode: use red channel as coverage alpha.
        let alpha = tex.r * in.color.a;
        return vec4<f32>(in.color.rgb * alpha, alpha);
    } else {
        // Full RGBA image mode: multiply by tint.
        return tex * in.color;
    }
}
