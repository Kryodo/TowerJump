extends Node2D
## Lightweight inspection surface for the reusable architecture-module library.

@export var module_recipe: EnvironmentArchitectureRecipe = preload("res://resources/environment/recipes/preview_vertical_grammar.tres")
@export var theme_profiles: Array[EnvironmentThemeProfile] = [
	preload("res://resources/environment/themes/navy_resonance.tres"),
	preload("res://resources/environment/themes/navy_depth_a1.tres"),
	preload("res://resources/environment/themes/amber_diagnostic.tres"),
]
@export var lighting_profile: EnvironmentLightingProfile = preload("res://resources/environment/lighting/restrained_structural_lights.tres")
@export var fixed_seeds: Array[int] = [7319, 24017, 91207]

const VIEW_CENTER: Vector2 = Vector2(360.0, 700.0)
const PREVIEW_BOUNDS_SIZE: Vector2 = Vector2(620.0, 980.0)

var _modules: Array[ArchitectureModuleDefinition] = []

var _camera: Camera2D
var _module_instance: Node2D
var _hud_label: Label
var _module_index: int = 1
var _theme_index: int = 0
var _seed_index: int = 0
var _preview_scale: float = 1.0


func _ready() -> void:
	if module_recipe != null:
		for module in module_recipe.module_pool:
			if module != null:
				_modules.append(module)
	if _modules.is_empty():
		push_error("Architecture Library Viewer: selected recipe contains no modules.")
		return
	_module_index = clampi(_module_index, 0, _modules.size() - 1)
	if theme_profiles.is_empty():
		push_error("Architecture Library Viewer: at least one theme profile is required.")
		return
	if fixed_seeds.is_empty():
		push_error("Architecture Library Viewer: at least one fixed seed is required.")
		return
	for profile in theme_profiles:
		if profile == null:
			push_error("Architecture Library Viewer: theme_profiles must not contain null entries.")
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
	draw_rect(Rect2(-40.0, -40.0, 800.0, 1360.0), Color(0.007843138, 0.023529412, 0.050980393, 1.0), true)
	for x in range(0, 721, 60):
		draw_line(Vector2(float(x), 0.0), Vector2(float(x), 1280.0), Color(0.12, 0.22, 0.31, 0.08), 1.0, true)
	draw_line(Vector2(360.0, 0.0), Vector2(360.0, 1280.0), Color(0.30, 0.47, 0.61, 0.14), 1.0, true)


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
		_module_instance.free()
	_module_instance = null

	var definition := _modules[_module_index]
	if definition.scene == null:
		push_error("Architecture Library Viewer: module %s has no PackedScene." % String(definition.module_id))
		return
	if definition.local_bounds.size.x <= 0.0 or definition.local_bounds.size.y <= 0.0:
		push_error("Architecture Library Viewer: module %s has invalid visual bounds." % String(definition.module_id))
		return

	# Display the actual PackedScene referenced by this module definition. The
	# previous viewer recreated a generic renderer node and ignored definition.scene,
	# making the module selector report resources it did not really instantiate.
	var instance := definition.scene.instantiate() as Node2D
	if instance == null:
		push_error("Architecture Library Viewer: module %s scene root must be Node2D." % String(definition.module_id))
		return
	_module_instance = instance
	_module_instance.name = "SelectedModulePreview"
	_module_instance.set("layer_type", int(definition.depth_layer))
	_module_instance.set("theme_profile", theme_profiles[_theme_index])
	_module_instance.set("environment_seed", fixed_seeds[_seed_index])
	_module_instance.set("architecture_recipe", module_recipe)
	_module_instance.set("world_width", 720.0)
	_module_instance.set("section_top_y", 0.0)
	_module_instance.set("section_bottom_y", 1280.0)
	_module_instance.set("far_detail_treatment", int(module_recipe.far_detail_treatment))
	_module_instance.set("mid_detail_treatment", int(module_recipe.middle_detail_treatment))
	_module_instance.set("module_preview_mode", true)

	# Fit each real module's declared bounds into the same inspection area while
	# preserving its proportions and never enlarging small modules past native scale.
	_preview_scale = minf(
		1.0,
		minf(
			PREVIEW_BOUNDS_SIZE.x / definition.local_bounds.size.x,
			PREVIEW_BOUNDS_SIZE.y / definition.local_bounds.size.y
		)
	)
	_module_instance.scale = Vector2.ONE * _preview_scale
	var bounds_center := definition.local_bounds.position + definition.local_bounds.size * 0.5
	_module_instance.position = VIEW_CENTER - bounds_center * _preview_scale
	_module_instance.z_index = 1
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
	var family_index := clampi(int(definition.family), 0, family_names.size() - 1)
	var depth_index := clampi(int(definition.depth_layer), 0, depth_names.size() - 1)
	var points_text := "—"
	if not definition.connection_points.is_empty():
		var values: Array[String] = []
		for point in definition.connection_points:
			values.append("(%.0f, %.0f)" % [point.x, point.y])
		points_text = ", ".join(values)
	_hud_label.text = (
		"ARCHITECTURE LIBRARY VIEWER   /   LAYER %d OF %d\n" % [_module_index + 1, _modules.size()]
		+ "%s   |   FAMILY: %s   |   DEPTH: %s\n" % [
			String(definition.module_id),
			family_names[family_index],
			depth_names[depth_index],
		]
		+ "VISUAL BOUNDS: %s   |   CLEARANCE: %s   |   CONNECTIONS: %s\n" % [
			str(definition.local_bounds),
			str(definition.clearance_bounds),
			points_text,
		]
		+ "THEME: %s   |   FIXED SEED: %d   |   VIEW SCALE: %.2f\n" % [
			String(theme_profiles[_theme_index].profile_id),
			fixed_seeds[_seed_index],
			_preview_scale,
		]
		+ "1–3 / ← → MODULE   T THEME   R FIXED SEED"
	)
