shader_type canvas_item;

uniform sampler2D source_texture : filter_linear_mipmap, repeat_disable;
// Row-major 3x3 Inverse Homography matrix packed as Projection/mat4
uniform mat4 inv_homography;

void fragment() {
    vec4 screen_coord = vec4(UV.x, UV.y, 1.0, 0.0);

    // Matrix multiplication: H_inv * [u, v, 1]^T
    float mapped_x = inv_homography[0][0] * screen_coord.x + inv_homography[0][1] * screen_coord.y + inv_homography[0][2];
    float mapped_y = inv_homography[1][0] * screen_coord.x + inv_homography[1][1] * screen_coord.y + inv_homography[1][2];
    float mapped_w = inv_homography[2][0] * screen_coord.x + inv_homography[2][1] * screen_coord.y + inv_homography[2][2];

    if (abs(mapped_w) < 0.00001 || mapped_w <= 0.0) {
        COLOR = vec4(0.0, 0.0, 0.0, 1.0);
    } else {
        vec2 game_uv = vec2(mapped_x, mapped_y) / mapped_w;

        // Discard fragments outside the active game viewport boundaries
        if (game_uv.x < 0.0 || game_uv.x > 1.0 || game_uv.y < 0.0 || game_uv.y > 1.0) {
            COLOR = vec4(0.0, 0.0, 0.0, 1.0);
        } else {
            COLOR = texture(source_texture, game_uv);
        }
    }
}
