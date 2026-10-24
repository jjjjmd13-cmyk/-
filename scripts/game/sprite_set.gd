extends RefCounted
## Optional sprite-sheet art. When PNG strips exist under
##   res://assets/sprites/<group>/<id>/<animation>.png
## (group = heroes / enemies / bosses) they replace the procedural drawing.
## Each file is one horizontal row of square frames, character facing right,
## feet at the bottom centre. See docs/ART_GUIDE.md for the full spec.

const ROOT := "res://assets/sprites"
const ANIMS := ["idle", "run", "attack", "skill", "dash", "cast", "death"]
const FPS := {"idle": 8.0, "run": 12.0, "attack": 14.0, "skill": 12.0, "dash": 14.0, "cast": 10.0, "death": 10.0}
const LOOPING := ["idle", "run", "cast"]
## Fallbacks used when an animation file is missing.
const FALLBACK := {
	"idle": ["run"], "run": ["idle"], "attack": ["idle", "run"], "skill": ["attack", "idle", "run"],
	"dash": ["run", "idle"], "cast": ["attack", "idle", "run"], "death": [],
}
## Frames are drawn at half size, so a 256 px frame is 128 px on screen.
const DISPLAY_SCALE := 0.5
## Feet sit this fraction of the frame height above the bottom edge.
const FOOT_MARGIN := 1.0 / 16.0

static var _cache := {}


static func frames_for(group: String, id: String) -> SpriteFrames:
	## Returns the animations for this character, or null if no art exists.
	var key := group + "/" + id
	if _cache.has(key):
		return _cache[key]
	var sf: SpriteFrames = null
	for anim in ANIMS:
		var path := "%s/%s/%s/%s.png" % [ROOT, group, id, anim]
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		if tex == null or tex.get_height() <= 0:
			continue
		if sf == null:
			sf = SpriteFrames.new()
			sf.remove_animation("default")
		var size := tex.get_height()
		var count := maxi(1, tex.get_width() / size)
		sf.add_animation(anim)
		sf.set_animation_speed(anim, minf(FPS[anim], 4.0 if anim == "idle" else 8.0) if count == 4 else FPS[anim])
		if anim == "run" and count >= 8:
			var cycle := 0.85 if group == "bosses" else (0.5 if id == "bat" else 0.65)
			sf.set_animation_speed(anim, float(count) / cycle)
		elif anim == "idle" and count == 5:
			sf.set_animation_speed(anim, float(count) / 1.2)
		sf.set_animation_loop(anim, LOOPING.has(anim))
		if anim == "cast" and count >= 8:
			sf.set_animation_loop(anim, false)
		for i in count:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * size, 0, size, size)
			sf.add_frame(anim, at)
	# At least something to show while standing or moving.
	if sf != null and not (sf.has_animation("idle") or sf.has_animation("run")):
		push_warning("Sprites for %s need idle.png or run.png; ignoring them." % key)
		sf = null
	_cache[key] = sf
	return sf


static func make_sprite(group: String, id: String) -> AnimatedSprite2D:
	var sf := frames_for(group, id)
	if sf == null:
		return null
	var s := AnimatedSprite2D.new()
	s.sprite_frames = sf
	s.scale = Vector2(DISPLAY_SCALE, DISPLAY_SCALE)
	# Hit-flash materials on the parent apply to the sprite too.
	s.use_parent_material = true
	var first: String = "idle" if sf.has_animation("idle") else "run"
	var h := float(sf.get_frame_texture(first, 0).get_height())
	s.offset = Vector2(0, -h / 2.0 + h * FOOT_MARGIN)
	play(s, first)
	return s


static func resolve(s: AnimatedSprite2D, anim: String) -> String:
	## The animation that will actually play for `anim`, after fallbacks.
	var sf := s.sprite_frames
	if sf.has_animation(anim):
		return anim
	for alt in FALLBACK.get(anim, []):
		if sf.has_animation(alt):
			return alt
	return ""


static func play(s: AnimatedSprite2D, anim: String, duration: float = 0.0) -> void:
	## Plays `anim` (or its fallback). With `duration`, one-shot animations are
	## sped up or slowed down to last exactly that long.
	var real := resolve(s, anim)
	if real == "":
		return
	var speed := 1.0
	if duration > 0.0 and not s.sprite_frames.get_animation_loop(real):
		var frames := s.sprite_frames.get_frame_count(real)
		speed = (frames / s.sprite_frames.get_animation_speed(real)) / duration
	if s.animation != real or not s.is_playing():
		s.play(real)
	s.speed_scale = speed


static var _hips := {}


static func hip_line(s: AnimatedSprite2D, anim: String) -> float:
	## Where the legs begin in this animation's frames (0..1 of the frame height),
	## measured once from the art: a little over half way down the body.
	var tex := s.sprite_frames.get_frame_texture(anim, 0) as AtlasTexture
	if tex == null:
		return 0.66
	var key := tex.atlas.resource_path
	if not _hips.has(key):
		var img := tex.atlas.get_image()
		if img.is_compressed():
			img = img.duplicate()
			img.decompress()
		var size := int(tex.region.size.y)
		var top := size
		var bottom := 0
		for y in range(0, size, 2):
			for x in range(0, size, 3):
				if img.get_pixel(int(tex.region.position.x) + x, y).a > 0.4:
					top = mini(top, y)
					bottom = maxi(bottom, y)
					break
		_hips[key] = (top + (bottom - top) * 0.56) / float(size) if bottom > top else 0.66
	return _hips[key]


static func set_stride(s: AnimatedSprite2D, stride: float) -> void:
	## Scissors the legs of the current frame (1 = as drawn, smaller = legs together).
	var mat := s.material as ShaderMaterial
	if mat == null:
		return
	if stride >= 0.999:
		mat.set_shader_parameter("stride", 1.0)
		return
	var tex := s.sprite_frames.get_frame_texture(s.animation, s.frame) as AtlasTexture
	if tex == null:
		return
	mat.set_shader_parameter("frame_w", tex.region.size.x / float(tex.atlas.get_width()))
	mat.set_shader_parameter("hip", hip_line(s, s.animation))
	mat.set_shader_parameter("stride", stride)


static func has_authored_motion(s: AnimatedSprite2D) -> bool:
	return s.sprite_frames.has_animation("run") and s.sprite_frames.get_frame_count("run") >= 8
