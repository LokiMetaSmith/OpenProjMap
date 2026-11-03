shader_type canvas_item;

// Source warped texture
uniform sampler2D source_texture : filter_linear_mipmap, repeat_disable;

// Overlap blend margins normalized (0.0 to 0.5): (left, top, right, bottom)
uniform vec4 blend_margins = vec4(0.0, 0.0, 0.0, 0.0);
// Gamma exponent for linear photometric falloff
uniform float blend_gamma = 2.0;

void fragment() {
    vec4 base_color = texture(source_texture, UV);

    float factor_x = 1.0;
    float factor_y = 1.0;

    // Left edge
    if (blend_margins.x > 0.001 && UV.x < blend_margins.x) {
        factor_x = min(factor_x, clamp(UV.x / blend_margins.x, 0.0, 1.0));
    }
    // Right edge
    if (blend_margins.z > 0.001 && UV.x > (1.0 - blend_margins.z)) {
        factor_x = min(factor_x, clamp((1.0 - UV.x) / blend_margins.z, 0.0, 1.0));
    }
    // Top edge
    if (blend_margins.y > 0.001 && UV.y < blend_margins.y) {
        factor_y = min(factor_y, clamp(UV.y / blend_margins.y, 0.0, 1.0));
    }
    // Bottom edge
    if (blend_margins.w > 0.001 && UV.y > (1.0 - blend_margins.w)) {
        factor_y = min(factor_y, clamp((1.0 - UV.y) / blend_margins.w, 0.0, 1.0));
    }

    float blend_mult = pow(factor_x * factor_y, blend_gamma);
    COLOR = vec4(base_color.rgb * blend_mult, base_color.a);
}
