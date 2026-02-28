// Instanced colored-quad shader for VolvoxGrid GPU renderer.
//
// Each instance is an axis-aligned rectangle with a solid RGBA color.
// Used for: cell backgrounds, grid lines, flood fills, borders,
// selection highlight, focus rect, scrollbars.

struct Uniforms {
    // Orthographic projection: maps pixel coords to NDC.
    // viewport_size.xy = (width, height) in pixels.
    viewport_size: vec2<f32>,
    _pad: vec2<f32>,
}

@group(0) @binding(0) var<uniform> uniforms: Uniforms;

struct RectInstance {
    // Pixel-space rectangle: (x, y, width, height).
    @location(0) rect: vec4<f32>,
    // RGBA color (each component 0..1).
    @location(1) color: vec4<f32>,
    // Border pattern: x = style (0=solid, 1=dotted, 2=dashed), y = unused.
    @location(2) pattern: vec2<f32>,
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) color: vec4<f32>,
    @location(1) frag_pos: vec2<f32>,
    @location(2) rect_size: vec2<f32>,
    @location(3) pattern: vec2<f32>,
}

// Fullscreen quad vertices: 2 triangles forming a unit quad [0,1]x[0,1].
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
    instance: RectInstance,
) -> VertexOutput {
    let quad = QUAD_POS[vertex_index];

    // Scale and translate the unit quad to pixel coordinates.
    let pixel_pos = instance.rect.xy + quad * instance.rect.zw;

    // Convert pixel coordinates to NDC: x in [-1,1], y in [-1,1].
    // Pixel (0,0) is top-left, NDC (-1,1) is top-left in our projection.
    let ndc = vec2<f32>(
        (pixel_pos.x / uniforms.viewport_size.x) * 2.0 - 1.0,
        1.0 - (pixel_pos.y / uniforms.viewport_size.y) * 2.0,
    );

    var out: VertexOutput;
    out.position = vec4<f32>(ndc, 0.0, 1.0);
    out.color = instance.color;
    out.frag_pos = quad * instance.rect.zw;
    out.rect_size = instance.rect.zw;
    out.pattern = instance.pattern;
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let style = i32(in.pattern.x);

    // Dotted pattern: discard every other 2px block.
    if style == 1 {
        let coord = in.frag_pos.x + in.frag_pos.y;
        if (i32(coord) / 2) % 2 == 1 {
            discard;
        }
    }

    // Dashed pattern: discard in a 4-on/4-off pattern.
    if style == 2 {
        let coord = in.frag_pos.x + in.frag_pos.y;
        if (i32(coord) / 4) % 2 == 1 {
            discard;
        }
    }

    return in.color;
}
