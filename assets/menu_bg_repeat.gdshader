shader_type canvas_item;

uniform float repeat_x = 1.0;

void fragment() {
	vec2 uv = vec2(fract(UV.x * repeat_x), UV.y);
	COLOR = texture(TEXTURE, uv);
}
