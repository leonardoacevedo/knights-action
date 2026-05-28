// res://assets/shaders/white_to_alpha.gdshader
shader_type canvas_item;

uniform float threshold : hint_range(0.0, 1.0) = 0.95;
uniform float softness : hint_range(0.0, 0.2) = 0.05;

void fragment() {
    vec4 c = texture(TEXTURE, UV);
    float white = min(c.r, min(c.g, c.b));
    float a = 1.0 - smoothstep(threshold - softness, threshold, white);
    COLOR = vec4(c.rgb, c.a * a);
}