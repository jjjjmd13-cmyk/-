shader_type canvas_item;
render_mode unshaded;
uniform vec4 rim_color : source_color = vec4(0.65, 0.9, 1.0, 0.85);
uniform float rim_width = 2.2;
uniform float exposure = 1.08;
uniform float hit_flash = 0.0;
varying vec4 vertex_tint;
void vertex() {
	vertex_tint = COLOR;
}
void fragment() {
	vec4 body = texture(TEXTURE, UV);
	vec2 step_uv = TEXTURE_PIXEL_SIZE * rim_width;
	float edge = max(max(texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).a,
		texture(TEXTURE, UV - vec2(step_uv.x, 0.0)).a),
		max(texture(TEXTURE, UV + vec2(0.0, step_uv.y)).a,
		texture(TEXTURE, UV - vec2(0.0, step_uv.y)).a));
	float rim = clamp(edge - body.a, 0.0, 1.0) * rim_color.a;
	float alpha = body.a + rim * (1.0 - body.a);
	vec3 ink = mix(body.rgb * exposure, vec3(1.0), hit_flash * 0.5);
	vec3 rgb = (ink * body.a + rim_color.rgb * rim * (1.0 - body.a)) / max(alpha, 0.0001);
	COLOR = vec4(rgb, alpha) * vertex_tint;
}
