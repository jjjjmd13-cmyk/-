extends RefCounted
## Cached production atlases shared by HUD and visual-only combat effects.
const THEMES := ["knight", "ranger", "mage", "rogue"]
static var _textures: Dictionary = {}
static var _cells: Dictionary = {}
static var _additive: CanvasItemMaterial

static func texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path]

static func cell(path: String, column: int, row: int, columns := 4, rows := 4) -> AtlasTexture:
	var key := "%s:%d:%d" % [path, column, row]
	if not _cells.has(key):
		var source := texture(path)
		var tile := source.get_size() / Vector2(columns, rows)
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		atlas.region = Rect2(Vector2(column, row) * tile, tile)
		atlas.filter_clip = true
		_cells[key] = atlas
	return _cells[key]

static func icon(hero: String, slot: int) -> AtlasTexture:
	return cell("res://assets/ui/ability-icons.png", slot, maxi(0, THEMES.find(hero)))

static func prop(index: int) -> AtlasTexture:
	return cell("res://assets/environment/courtyard-props.png", index % 2, index / 2, 2, 2)

static func vfx(hero: String, kind: int) -> AtlasTexture:
	return cell("res://assets/vfx/ability-effects.png", kind, maxi(0, THEMES.find(hero)))

static func color_theme(color: Color) -> String:
	if color.b > color.r * 1.1:
		return "mage"
	if color.g > color.r * 1.15:
		return "ranger"
	if color.r > color.g * 1.8:
		return "rogue"
	return "knight"

static func additive() -> CanvasItemMaterial:
	if _additive == null:
		_additive = CanvasItemMaterial.new()
		_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _additive

static func stamp(parent: Node2D, hero: String, kind: int, diameter: float) -> Sprite2D:
	additive()
	var sprite := Sprite2D.new()
	sprite.texture = vfx(hero, kind)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.material = _additive
	# Painted spell layers yield to actors and enemy warning boundaries.
	sprite.self_modulate.a = 0.72
	sprite.scale = Vector2.ONE * diameter / sprite.texture.get_width()
	parent.add_child(sprite)
	return sprite

static func actor_material(player: bool, elite := false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/actor_readability.gdshader")
	mat.set_shader_parameter("rim_color", Color(0.62, 0.94, 1, 0.95) if player else (Color(1, 0.52, 0.24, 0.8) if elite else Color(0.9, 0.5, 0.34, 0.48)))
	mat.set_shader_parameter("rim_width", 2.8 if player else 2.0)
	mat.set_shader_parameter("exposure", 1.12 if player else 1.08)
	return mat

static func release_cache() -> void:
	_cells.clear()
	_textures.clear()
	_additive = null
