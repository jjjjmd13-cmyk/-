shader_type canvas_item;
render_mode unshaded;
uniform vec4 rim_color : source_color = vec4(0.65, 0.9, 1.0, 0.85);
uniform float rim_width = 2.2;
uniform float exposure = 1.08;
uniform float hit_flash = 0.0;
// Walk cycle: the strips have few frames, so the legs are scissored here.
// frame_w is one frame's width in UV units (frames are equal squares in a row,
// so the frame is found from the UV itself), hip is where the legs start
// (0..1 of the frame height) and stride squeezes the legs towards the body
// centre (1 = untouched, smaller = legs together).
uniform float frame_w = 1.0;
uniform float hip = 0.66;
uniform float stride = 1.0;
varying vec4 vertex_tint;
void vertex() {
	vertex_tint = COLOR;
}
// Where to read the art for this pixel; w = 0 when the warp leaves the frame.
vec3 warp(vec2 uv) {
	if (stride >= 0.999) {
		return vec3(uv, 1.0);
	}
	float frame_x0 = floor(uv.x / frame_w) * frame_w;
	float lx = (uv.x - frame_x0) / frame_w;
	float k = smoothstep(hip, hip + 0.08, uv.y);
	float s = mix(1.0, stride, k);
	lx = 0.5 + (lx - 0.5) / s;
	float inside = step(0.0, lx) * step(lx, 1.0);
	return vec3(frame_x0 + clamp(lx, 0.0, 1.0) * frame_w, uv.y, inside);
}
void fragment() {
	vec3 w0 = warp(UV);
	vec4 body = texture(TEXTURE, w0.xy) * w0.z;
	vec2 step_uv = TEXTURE_PIXEL_SIZE * rim_width;
	vec3 w1 = warp(UV + vec2(step_uv.x, 0.0));
	vec3 w2 = warp(UV - vec2(step_uv.x, 0.0));
	vec3 w3 = warp(UV + vec2(0.0, step_uv.y));
	vec3 w4 = warp(UV - vec2(0.0, step_uv.y));
	float edge = max(max(texture(TEXTURE, w1.xy).a * w1.z, texture(TEXTURE, w2.xy).a * w2.z),
		max(texture(TEXTURE, w3.xy).a * w3.z, texture(TEXTURE, w4.xy).a * w4.z));
	float rim = clamp(edge - body.a, 0.0, 1.0) * rim_color.a;
	float alpha = body.a + rim * (1.0 - body.a);
	vec3 ink = mix(body.rgb * exposure, vec3(1.0), hit_flash * 0.5);
	vec3 rgb = (ink * body.a + rim_color.rgb * rim * (1.0 - body.a)) / max(alpha, 0.0001);
	COLOR = vec4(rgb, alpha) * vertex_tint;
}
