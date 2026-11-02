extends Node2D
## Independent vertical preview for zone/subzone structure, voids and fixed landmarks.

@export var zone_profile: EnvironmentZoneProfile = preload("res://resources/environment/zones/reference_extraction_parity.tres")
@export var theme_profiles: Array[EnvironmentThemeProfile] = [
	preload("res://resources/environment/themes/navy_resonance.tres"),
	preload("res://resources/environment/themes/navy_depth_a1.tres"),
	preload("res://resources/environment/themes/amber_diagnostic.tres"),
]
@export var fixed_seeds: Array[int] = [7319, 24017, 91207]

const COMPOSITOR_SCRIPT: Script = preload("res://scripts/environment/environment_preview_compositor.gd")
const BACKGROUND_COLOR := Color(0.007843138, 0.023529412, 0.050980393, 1.0)
# The production Ball origin is Y=600, while the production Camera2D starts at Y=640.
const CAMERA_RUN_ORIGIN_Y: float = 640.0

var _camera: Camera2D
var _compositor: EnvironmentPreviewCompositor
var _hud_label: Label
var _view_height_px: float = 3600.0
var _seed_index: int = 0
var _theme_index: int = 0


func _ready() -> void:
	if zone_profile == null or theme_profiles.is_empty() or fixed_seeds.is_empty():
		push_error("Zone/Subzone Preview: assign a zone, at least one theme, and at least one fixed seed.")
		return
	for profile in theme_profiles:
		if profile == null:
			push_error("Zone/Subzone Preview: theme_profiles must not contain null entries.")
			return
	_view_height_px = clampf(_view_height_px, zone_profile.start_height_px, zone_profile.end_height_px)
	_create_camera_and_background()
	_create_compositor()
	_create_hud()
	_update_hud()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_UP:
			_set_view_height(_view_height_px + 400.0)
		KEY_DOWN:
			_set_view_height(maxf(_view_height_px - 400.0, 0.0))
		KEY_HOME:
			_set_view_height(clampf(3600.0, zone_profile.start_height_px, zone_profile.end_height_px))
		KEY_1, KEY_2, KEY_3:
			var requested_index := key_event.keycode - KEY_1
			if requested_index < fixed_seeds.size():
				_seed_index = requested_index
				_compositor.call("set_world_seed", fixed_seeds[_seed_index])
				_update_hud()
		KEY_R:
			_seed_index = posmod(_seed_index + 1, fixed_seeds.size())
			_compositor.call("set_world_seed", fixed_seeds[_seed_index])
			_update_hud()
		KEY_T:
			_theme_index = posmod(_theme_index + 1, theme_profiles.size())
			_compositor.call("set_theme_override", theme_profiles[_theme_index])
			_update_hud()
		KEY_J:
			var next_height: float = _compositor.call("get_next_landmark_height", _view_height_px)
			if next_height >= 0.0:
				_set_view_height(next_height)
		KEY_P:
			_capture_regression_image()


func _create_camera_and_background() -> void:
	_camera = Camera2D.new()
	_camera.name = "PreviewCamera"
	_camera.position = Vector2(360.0, CAMERA_RUN_ORIGIN_Y - _view_height_px)
	_camera.enabled = true
	add_child(_camera)
	_camera.make_current()

	var background := ColorRect.new()
	background.name = "PreviewVoid"
	background.position = Vector2(-360.0, -CAMERA_RUN_ORIGIN_Y)
	background.size = Vector2(720.0, 1280.0)
	background.color = BACKGROUND_COLOR
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.z_index = -60
	_camera.add_child(background)


func _create_compositor() -> void:
	_compositor = COMPOSITOR_SCRIPT.new() as EnvironmentPreviewCompositor
	_compositor.name = "EnvironmentPreviewCompositor"
	_compositor.zone_profile = zone_profile
	_compositor.world_seed = fixed_seeds[_seed_index]
	_compositor.theme_override = theme_profiles[_theme_index]
	_compositor.camera_path = NodePath("../PreviewCamera")
	_compositor.camera_run_origin_y = CAMERA_RUN_ORIGIN_Y
	_compositor.z_index = -50
	add_child(_compositor)


func _create_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "ZonePreviewHUD"
	canvas.layer = 5
	add_child(canvas)
	_hud_label = Label.new()
	_hud_label.position = Vector2(20.0, 20.0)
	_hud_label.size = Vector2(680.0, 170.0)
	_hud_label.add_theme_font_size_override("font_size", 16)
	_hud_label.add_theme_color_override("font_color", Color(0.75, 0.87, 0.94, 0.96))
	_hud_label.add_theme_color_override("font_outline_color", Color(0.0, 0.01, 0.025, 1.0))
	_hud_label.add_theme_constant_override("outline_size", 3)
	_hud_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	canvas.add_child(_hud_label)


func _set_view_height(value: float) -> void:
	_view_height_px = clampf(value, zone_profile.start_height_px, zone_profile.end_height_px)
	_camera.position.y = HEIGHT_ORIGIN - _view_height_px
	_update_hud()


func _update_hud() -> void:
	if _hud_label == null:
		return
	var summary: Dictionary = _compositor.call("get_plan_summary") if _compositor != null else {}
	var next_height: float = _compositor.call("get_next_landmark_height", _view_height_px) if _compositor != null else -1.0
	var next_text := "NONE" if next_height < 0.0 else "%dm" % roundi(next_height)
	var errors: Array = summary.get("errors", [])
	var warnings: Array = summary.get("warnings", [])
	var validation_text := "VALID" if errors.is_empty() else "ERRORS %d" % errors.size()
	if errors.is_empty() and not warnings.is_empty():
		validation_text = "WARNINGS %d" % warnings.size()
	_hud_label.text = (
		"ZONE / SUBZONE PREVIEW   |   %s\n" % String(zone_profile.zone_id).to_upper()
		+ "HEIGHT: %dm   |   CURRENT: %s   |   NEXT LANDMARK: %s\n" % [
			roundi(_view_height_px),
			_compositor.call("get_subzone_id_at_height", _view_height_px),
			next_text,
		]
		+ "SEED: %d   |   THEME: %s   |   SECTIONS: %d   |   LANDMARKS: %d   |   PLAN: %s\n" % [
			fixed_seeds[_seed_index],
			String(theme_profiles[_theme_index].profile_id),
			int(summary.get("section_count", 0)),
			int(summary.get("landmark_count", 0)),
			validation_text,
		]
		+ "↑ / ↓ HEIGHT   J NEXT LANDMARK   1–3 / R SEED   T THEME   P CAPTURE PNG   HOME RESET"
	)


func _capture_regression_image() -> void:
	var directory := "user://environment_regression"
	var absolute_directory := ProjectSettings.globalize_path(directory)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK:
		push_warning("Zone Preview: Could not create regression capture directory.")
		return
	var filename := "zone_%s_seed_%d_height_%d.png" % [
		String(zone_profile.zone_id),
		fixed_seeds[_seed_index],
		roundi(_view_height_px),
	]
	var path := directory.path_join(filename)
	var image := get_viewport().get_texture().get_image()
	if image == null:
		push_warning("Zone Preview: Viewport image could not be read.")
		return
	var save_error := image.save_png(path)
	if save_error != OK:
		push_warning("Zone Preview: Could not save capture to %s." % path)
	else:
		print("Environment regression capture saved: %s" % path)
	_update_hud()
