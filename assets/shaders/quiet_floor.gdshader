shader_type canvas_item;
render_mode unshaded;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() {
	vec2 d = TEXTURE_PIXEL_SIZE * 5.0;
	vec4 stone = texture(TEXTURE, UV) * 0.28;
	stone += texture(TEXTURE, UV + vec2(d.x, d.y)) * 0.18;
	stone += texture(TEXTURE, UV + vec2(-d.x, d.y)) * 0.18;
	stone += texture(TEXTURE, UV + vec2(d.x, -d.y)) * 0.18;
	stone += texture(TEXTURE, UV - d) * 0.18;
	float luma = dot(stone.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 muted = mix(vec3(luma), stone.rgb, 0.35);
	// Compress texture contrast around a dark neutral slate, not pure black.
	COLOR = vec4(mix(vec3(0.23, 0.245, 0.26), muted, 0.43), stone.a) * vertex_tint;
}
