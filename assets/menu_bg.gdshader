shader_type canvas_item;

uniform vec2 direction = vec2(-1.0, 0.0);
uniform float speed_scale = 0.06;
uniform float crop_bottom = 0.4;

void fragment(){
	vec2 move = direction * TIME * speed_scale;
	vec2 uv = fract(UV + move);
	uv.y = uv.y * (1.0 - crop_bottom);
	COLOR = texture(TEXTURE, uv);
}
