extends Node2D
## Lightweight inspection surface for the reusable architecture-module library.

@export var module_recipe: EnvironmentArchitectureRecipe = preload("res://resources/environment/recipes/preview_vertical_grammar.tres")
@export var theme_profiles: Array[EnvironmentThemeProfile] = [
	preload("res://resources/environment/themes/navy_resonance.tres"),
	preload("res://resources/environment/themes/amber_diagnostic.tres"),
]
@export var lighting_profile: EnvironmentLightingProfile = preload("res://resources/environment/lighting/restrained_structural_lights.tres")
@export var fixed_seeds: Array[int] = [7319, 24017, 91207]

const PREVIEW_SCALE: float = 0.72

var _modules: Array[ArchitectureModuleDefinition] = []

var _camera: Camera2D
var _module_instance: Node2D
var _hud_label: Label
var _module_index: int = 0
var _theme_index: int = 0
var _seed_index: int = 0


func _ready() -> void:
	if module_recipe != null:
		for module in module_recipe.module_pool:
			if module != null:
				_modules.append(module)
	if _modules.is_empty():
		push_error("Architecture Library Viewer: selected recipe contains no modules.")
		return
	if theme_profiles.is_empty():
		push_error("Architecture Library Viewer: at least one theme profile is required.")
		return
	if fixed_seeds.is_empty():
		push_error("Architecture Library Viewer: at least one fixed seed is required.")
		return

	_camera = Camera2D.new()
	_camera.name = "LibraryViewerCamera"
	_camera.position = Vector2(360.0, 640.0)
	_camera.enabled = true
	add_child(_camera)
	_camera.make_current()
	_create_hud()
	_show_module()


func _draw() -> void:
	draw_rect(Rect2(-40.0, -40.0, 800.0, 1360.0), Color(0.0078, 0.0235, 0.051, 1.0), true)
	for x in range(0, 721, 60):
		draw_line(Vector2(float(x), 0.0), Vector2(float(x), 1280.0), Color(0.12, 0.22, 0.31, 0.12), 1.0, true)
	draw_line(Vector2(360.0, 0.0), Vector2(360.0, 1280.0), Color(0.30, 0.47, 0.61, 0.22), 1.0, true)
	draw_rect(Rect2(30.0, 112.0, 660.0, 1050.0), Color(0.24, 0.40, 0.55, 0.15), false, 1.0)
	if _module_instance != null:
		var definition := _modules[_module_index]
		var box := definition.local_bounds
		var origin := Vector2(360.0 - definition.local_bounds.size.x * PREVIEW_SCALE * 0.5, 180.0)
		var preview_rect := Rect2(
			origin + box.position * PREVIEW_SCALE,
			box.size * PREVIEW_SCALE
		)
		draw_rect(preview_rect, Color(0.37, 0.70, 0.84, 0.62), false, 1.4)
		var clearance := definition.clearance_bounds
		if clearance.size.x > 0.0 and clearance.size.y > 0.0:
			draw_rect(
				Rect2(origin + clearance.position * PREVIEW_SCALE, clearance.size * PREVIEW_SCALE),
				Color(0.77, 0.49, 0.20, 0.42),
				false,
				1.0
			)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_1, KEY_2, KEY_3:
			var requested_index := key_event.keycode - KEY_1
			if requested_index < _modules.size():
				_module_index = requested_index
				_show_module()
		KEY_LEFT, KEY_RIGHT:
			_module_index = posmod(_module_index + (-1 if key_event.keycode == KEY_LEFT else 1), _modules.size())
			_show_module()
		KEY_T:
			_theme_index = posmod(_theme_index + 1, theme_profiles.size())
			_show_module()
		KEY_R:
			_seed_index = posmod(_seed_index + 1, fixed_seeds.size())
			_show_module()


func _show_module() -> void:
	if _module_instance != null and is_instance_valid(_module_instance):
		_module_instance.queue_free()
	var definition := _modules[_module_index]
	_module_instance = definition.scene.instantiate() as Node2D
	if _module_instance == null:
		push_error("Architecture Library Viewer: module scene failed to instantiate.")
		return
	_module_instance.position = Vector2(
		360.0 - definition.local_bounds.size.x * PREVIEW_SCALE * 0.5,
		180.0
	)
	_module_instance.scale = Vector2(PREVIEW_SCALE, PREVIEW_SCALE)
	_module_instance.call(
		"configure",
		theme_profiles[_theme_index],
		lighting_profile,
		fixed_seeds[_seed_index]
	)
	add_child(_module_instance)
	queue_redraw()
	_update_hud()


func _create_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "LibraryViewerHUD"
	canvas.layer = 5
	add_child(canvas)
	_hud_label = Label.new()
	_hud_label.position = Vector2(20.0, 20.0)
	_hud_label.size = Vector2(680.0, 142.0)
	_hud_label.add_theme_font_size_override("font_size", 16)
	_hud_label.add_theme_color_override("font_color", Color(0.72, 0.86, 0.94, 0.96))
	_hud_label.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	_hud_label.add_theme_constant_override("outline_size", 3)
	_hud_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	canvas.add_child(_hud_label)
	_update_hud()


func _update_hud() -> void:
	if _hud_label == null:
		return
	var definition := _modules[_module_index]
	var family_names := ["LARGE MASS", "STRUCTURAL", "CONNECTOR", "SURFACE DETAIL"]
	var depth_names := ["FAR", "MIDDLE", "NEAR"]
	var points_text := "—"
	if not definition.connection_points.is_empty():
		var values: Array[String] = []
		for point in definition.connection_points:
			values.append("(%.0f, %.0f)" % [point.x, point.y])
		points_text = ", ".join(values)
	_hud_label.text = (
		"ART LIBRARY VIEWER   /   MODULE %d OF %d\n" % [_module_index + 1, _modules.size()]
		+ "%s   |   FAMILY: %s   |   DEPTH: %s\n" % [
			String(definition.module_id),
			family_names[definition.family],
			depth_names[definition.depth_layer],
		]
		+ "VISUAL BOUNDS: %s   |   CLEARANCE: %s   |   CONNECTIONS: %s\n" % [
			str(definition.local_bounds),
			str(definition.clearance_bounds),
			points_text,
		]
		+ "THEME: %s   |   FIXED SEED: %d\n" % [String(theme_profiles[_theme_index].profile_id), fixed_seeds[_seed_index]]
		+ "1–3 / ← → MODULE   T THEME   R FIXED SEED"
	)
