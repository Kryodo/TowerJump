class_name EnvironmentPreviewCompositor
extends Node2D
## Shared renderer for Architecture Library, Zone/Subzone Preview and Full-Game Jump-In.
## All three contexts use the same extracted EnvironmentArchitectureLayer grammar.

const WORLD_WIDTH: float = 720.0
const RUN_ORIGIN_WORLD_Y: float = 600.0
const AMBIENT_TEXTURE: Texture2D = preload("res://assets/particles/ambient_mote.svg")
const ARCHITECTURE_LAYER_SCRIPT: Script = preload("res://scripts/environment/environment_architecture_layer.gd")
const BASE_AMBIENT_AMOUNTS: Array[int] = [60, 16, 4]
const ARCHITECTURE_PARALLAX_X: Array[float] = [0.88, 0.96, 1.0]
const AMBIENT_PARALLAX_Y: Array[float] = [0.18, 0.46, 0.82]
const AMBIENT_EMITTER_Z_INDEX: Array[int] = [-30, -28, -29]
const AMBIENT_VELOCITY_MIN: Array[float] = [2.0, 3.0, 2.5]
const AMBIENT_VELOCITY_MAX: Array[float] = [8.0, 9.0, 7.0]
const AMBIENT_SCALE_MIN: Array[float] = [0.18, 0.34, 0.32]
const AMBIENT_SCALE_MAX: Array[float] = [0.62, 0.72, 0.66]
const GAME_MOTE_NODE_NAMES: Array[String] = [
	"AmbientMotes",
	"AmbientMotesNear",
	"AmbientMoteHighlights",
]
const AMBIENT_REPEAT_HEIGHT: float = 1520.0

@export var zone_profile: EnvironmentZoneProfile
@export var world_seed: int = 7319
## Adds the selected jump-in height to all zone-local renderer and landmark coordinates.
@export var world_origin_height_px: float = 0.0
## Baseline global camera Y at climb height zero: 600 in standalone preview, 640 in the production scene.
@export var camera_run_origin_y: float = 600.0
@export var camera_path: NodePath
@export var theme_override: EnvironmentThemeProfile
## When hosted inside the real game, reuse its existing three mote emitters and
## wrap them with the same Parallax2D setup as the preserved architecture study.
@export var reuse_game_ambient_emitters: bool = false
@export var ambient_particles_enabled: bool = true

var validation_errors: Array[String] = []
var validation_warnings: Array[String] = []

var _camera: Camera2D
var _architecture_layers: Array[Node2D] = []
var _architecture_x_factors: Array[float] = []
var _architecture_y_factors: Array[float] = []
var _middle_layers_by_subzone: Dictionary = {}
var _ambient_layers: Array[Node2D] = []
var _ambient_emitters: Array[GPUParticles2D] = []
var _original_mote_layers: Array[Parallax2D] = []
var _using_original_game_motes: bool = false
var _active_ambient_profile: EnvironmentAmbientProfile
var _last_plan: Dictionary = {}


static func local_parallax_y(
	camera_global_y: float,
	parallax_factor: float,
	world_origin_height: float
) -> float:
	# The compositor is parented below a game root translated by -world_origin_height.
	# Architecture draw coordinates are also translated by +world_origin_height and
	# then scaled by the parallax factor. Compensate for BOTH transforms so the final
	# global offset remains camera_global_y * (1 - parallax_factor).
	return (camera_global_y + world_origin_height) * (1.0 - parallax_factor)


func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera2D if not camera_path.is_empty() else null
	if _camera == null:
		push_warning("EnvironmentPreviewCompositor: No Camera2D was resolved; parallax will remain at its origin.")
	if reuse_game_ambient_emitters:
		_adopt_existing_game_motes()
	rebuild()
	_update_parallax()


func _process(_delta: float) -> void:
	_update_parallax()
	_update_ambient_for_view_height()


func set_world_seed(value: int) -> void:
	world_seed = value
	rebuild()


func set_theme_override(profile: EnvironmentThemeProfile) -> void:
	theme_override = profile
	rebuild()


func rebuild() -> void:
	if zone_profile == null:
		validation_errors.clear()
		validation_errors.append("No EnvironmentZoneProfile is assigned.")
		return

	_clear_architecture_layers()
	_last_plan = EnvironmentCompositionPlanner.build_plan(zone_profile, world_seed, theme_override)
	validation_errors.clear()
	for message in _last_plan.get("errors", []):
		validation_errors.append(str(message))
	validation_warnings.clear()
	for message in _last_plan.get("warnings", []):
		validation_warnings.append(str(message))

	if not validation_errors.is_empty():
		for message in validation_errors:
			push_error("EnvironmentPreviewCompositor: " + message)
		return

	for section in _last_plan.get("architecture_sections", []):
		_create_subzone_architecture(section)

	for landmark in _last_plan.get("landmarks", []):
		_add_landmark(landmark)

	_update_ambient_for_view_height(true)
	_update_parallax()


func get_plan_summary() -> Dictionary:
	return {
		"zone_id": String(zone_profile.zone_id) if zone_profile != null else "",
		"world_seed": world_seed,
		"section_count": int(_last_plan.get("section_count", 0)),
		"landmark_count": int(_last_plan.get("landmark_count", 0)),
		"reservation_count": int(_last_plan.get("reservation_count", 0)),
		"signature": EnvironmentCompositionPlanner.plan_signature(_last_plan) if not _last_plan.is_empty() else 0,
		"errors": validation_errors.duplicate(),
		"warnings": validation_warnings.duplicate(),
	}


func get_ambient_summary() -> Dictionary:
	var valid_layers := 0
	if _using_original_game_motes:
		for layer in _original_mote_layers:
			if is_instance_valid(layer):
				valid_layers += 1
	elif ambient_particles_enabled:
		for layer in _ambient_layers:
			if is_instance_valid(layer):
				valid_layers += 1
	var factors: Array[float] = _get_parallax_factors(_active_ambient_profile)
	return {
		"source": "GAME" if _using_original_game_motes else ("PREVIEW" if ambient_particles_enabled else "DISABLED"),
		"layer_count": valid_layers,
		"expected_layer_count": GAME_MOTE_NODE_NAMES.size(),
		"parallax_factors": factors,
	}


func get_subzone_id_at_height(height_px: float) -> String:
	if zone_profile == null:
		return "NO ZONE"
	for subzone in zone_profile.subzones:
		if subzone != null and height_px >= subzone.start_height_px and height_px < subzone.end_height_px:
			return String(subzone.subzone_id)
	return "VOID"


func get_next_landmark_height(height_px: float) -> float:
	if zone_profile == null:
		return -1.0
	var next_height := INF
	for anchor in zone_profile.landmark_anchors:
		if anchor != null and anchor.height_anchor_px > height_px:
			next_height = minf(next_height, anchor.height_anchor_px)
	return -1.0 if is_inf(next_height) else next_height


func _create_subzone_architecture(section: Dictionary) -> void:
	var recipe: EnvironmentArchitectureRecipe = section.recipe
	var ambient: EnvironmentAmbientProfile = section.ambient_profile
	var factors := _get_parallax_factors(ambient)

	for depth in range(3):
		var layer := Node2D.new()
		layer.name = "%s_%s" % [
			String(section.subzone_id),
			["FarArchitecture", "MiddleArchitecture", "NearArchitecture"][depth],
		]
		layer.set_script(ARCHITECTURE_LAYER_SCRIPT)
		layer.set("layer_type", depth)
		layer.set("theme_profile", section.theme_profile)
		layer.set("environment_seed", int(section.architecture_seed))
		layer.set("architecture_recipe", recipe)
		layer.set("world_width", WORLD_WIDTH)
		layer.set("section_top_y", float(section.section_top_y) + world_origin_height_px)
		layer.set("section_bottom_y", float(section.section_bottom_y) + world_origin_height_px)
		layer.set("preserve_reference_overdraw", bool(section.get("preserve_reference_overdraw", false)))
		layer.set("far_detail_treatment", int(recipe.far_detail_treatment))
		layer.set("mid_detail_treatment", int(recipe.middle_detail_treatment))
		layer.z_index = depth + 1
		add_child(layer)
		_architecture_layers.append(layer)
		_architecture_x_factors.append(ARCHITECTURE_PARALLAX_X[depth])
		_architecture_y_factors.append(factors[depth])

		if depth == 1:
			_middle_layers_by_subzone[String(section.subzone_id)] = layer


func _add_landmark(landmark: Dictionary) -> void:
	var anchor: EnvironmentLandmarkAnchor = landmark.anchor
	if anchor.scene == null:
		return
	var instance := anchor.scene.instantiate() as Node2D
	if instance == null:
		push_warning("EnvironmentPreviewCompositor: Landmark %s scene root must be Node2D." % String(anchor.landmark_id))
		return

	instance.position = landmark.root_position + Vector2(0.0, world_origin_height_px)
	if instance.has_method("configure"):
		instance.call(
			"configure",
			landmark.theme_profile,
			landmark.lighting_profile,
			int(landmark.seed)
		)

	var target_layer: Node2D = _middle_layers_by_subzone.get(String(anchor.subzone_id)) as Node2D
	if target_layer == null and not _architecture_layers.is_empty():
		target_layer = _architecture_layers[min(1, _architecture_layers.size() - 1)]
	if target_layer == null:
		add_child(instance)
	else:
		# The authored landmark draws after the procedural support layer, matching
		# the original study's deliberate foreground ordering inside the middle layer.
		target_layer.add_child(instance)


func _clear_architecture_layers() -> void:
	for layer in _architecture_layers:
		if is_instance_valid(layer):
			layer.free()
	_architecture_layers.clear()
	_architecture_x_factors.clear()
	_architecture_y_factors.clear()
	_middle_layers_by_subzone.clear()


func _get_parallax_factors(ambient: EnvironmentAmbientProfile = null) -> Array[float]:
	if ambient == null:
		ambient = zone_profile.ambient_profile if zone_profile != null else null
	if ambient == null:
		return [0.18, 0.46, 0.82]
	return [ambient.far_parallax, ambient.middle_parallax, ambient.near_parallax]


func _update_parallax() -> void:
	if _camera == null:
		return

	for index in range(_architecture_layers.size()):
		var x_factor: float = _architecture_x_factors[index]
		var y_factor: float = _architecture_y_factors[index]
		_architecture_layers[index].scale = Vector2(x_factor, y_factor)
		# The full-game preview shifts its game root upward by the jump-in
		# height and offsets section coordinates by the same amount. Add that
		# origin back here so the layer's GLOBAL parallax offset remains exactly
		# camera.global_position.y * (1 - factor), as in the preserved study.
		_architecture_layers[index].position = Vector2(
			WORLD_WIDTH * 0.5 * (1.0 - x_factor),
			local_parallax_y(_camera.global_position.y, y_factor, world_origin_height_px)
		)

	# Ambient layers are Parallax2D nodes and use scroll_scale directly. Unlike
	# architecture layers, motes must not be vertically scaled: the reference
	# experiment changes their camera-relative motion, not particle size.


func _adopt_existing_game_motes() -> void:
	if _camera == null:
		return

	var adopted_count := 0
	var active_ambient := _resolve_ambient_profile_for_current_height()
	var factors: Array[float] = _get_parallax_factors(active_ambient)
	for index in range(GAME_MOTE_NODE_NAMES.size()):
		var emitter := _camera.get_node_or_null(GAME_MOTE_NODE_NAMES[index]) as GPUParticles2D
		if emitter == null:
			push_warning(
				"EnvironmentPreviewCompositor: The production camera has no %s mote emitter."
				% GAME_MOTE_NODE_NAMES[index]
			)
			continue

		var layer := Parallax2D.new()
		layer.name = "AmbientMotesParallax%d" % index
		layer.scroll_scale = Vector2(1.0, factors[index])
		layer.repeat_size = Vector2(0.0, AMBIENT_REPEAT_HEIGHT)
		layer.repeat_times = 2
		# The compositor itself is z=-50. Cancel that parent offset so each
		# original emitter retains its reference z-index (-30/-28/-29).
		layer.z_index = 50
		add_child(layer)
		layer.global_position = _camera.global_position

		# This is the same reparent/local-coordinate operation used by the
		# preserved middle-architecture detail study.
		emitter.reparent(layer, true)
		emitter.local_coords = true
		emitter.restart()
		_original_mote_layers.append(layer)
		adopted_count += 1

	_using_original_game_motes = adopted_count > 0
	_active_ambient_profile = active_ambient
	if adopted_count != GAME_MOTE_NODE_NAMES.size():
		push_warning(
			"EnvironmentPreviewCompositor: Adopted %d of %d original game mote emitters."
			% [adopted_count, GAME_MOTE_NODE_NAMES.size()]
		)


func _resolve_ambient_profile_for_current_height() -> EnvironmentAmbientProfile:
	var ambient := zone_profile.ambient_profile if zone_profile != null else null
	if zone_profile == null or _camera == null:
		return ambient

	var view_height := camera_run_origin_y - _camera.global_position.y
	for subzone in zone_profile.subzones:
		if (
			subzone != null
			and view_height >= subzone.start_height_px
			and view_height < subzone.end_height_px
			and subzone.ambient_profile != null
		):
			return subzone.ambient_profile
	return ambient


func _update_ambient_for_view_height(force_rebuild: bool = false) -> void:
	var ambient := _resolve_ambient_profile_for_current_height()
	if _using_original_game_motes:
		if ambient == _active_ambient_profile and not force_rebuild:
			return
		_active_ambient_profile = ambient
		_update_original_mote_parallax(ambient)
		return

	if not ambient_particles_enabled:
		_clear_ambient_layers()
		return
	if ambient == _active_ambient_profile and not force_rebuild:
		return
	_active_ambient_profile = ambient
	_rebuild_ambient_layers(ambient)


func _update_original_mote_parallax(profile: EnvironmentAmbientProfile) -> void:
	if profile == null:
		return
	var factors: Array[float] = [
		profile.far_parallax,
		profile.middle_parallax,
		profile.near_parallax,
	]
	for index in range(_original_mote_layers.size()):
		var layer := _original_mote_layers[index]
		if is_instance_valid(layer):
			layer.scroll_scale = Vector2(1.0, factors[index % factors.size()])


func _rebuild_ambient_layers(profile: EnvironmentAmbientProfile) -> void:
	_clear_ambient_layers()
	if profile == null:
		return

	var factors: Array[float] = [
		profile.far_parallax,
		profile.middle_parallax,
		profile.near_parallax,
	]
	for index in range(3):
		var layer := Parallax2D.new()
		layer.name = "AmbientParallax%d" % index
		layer.scroll_scale = Vector2(1.0, factors[index])
		layer.repeat_size = Vector2(0.0, AMBIENT_REPEAT_HEIGHT)
		layer.repeat_times = 2
		# The compositor is z=-50. Match the original emitters' own z positions
		# (-30/-28/-29) after the Parallax2D wrapper is added beneath it.
		layer.z_index = 50
		add_child(layer)
		if _camera != null:
			layer.global_position = _camera.global_position
		_ambient_layers.append(layer)

		var emitter := GPUParticles2D.new()
		emitter.name = GAME_MOTE_NODE_NAMES[index]
		emitter.texture = AMBIENT_TEXTURE
		if index == 2:
			emitter.amount = maxi(
				1,
				roundi(float(BASE_AMBIENT_AMOUNTS[0] + BASE_AMBIENT_AMOUNTS[1])
					* profile.highlight_share * profile.density_scale)
			)
		else:
			emitter.amount = maxi(
				1,
				roundi(float(BASE_AMBIENT_AMOUNTS[index]) * profile.density_scale)
			)
		emitter.z_index = AMBIENT_EMITTER_Z_INDEX[index]
		emitter.lifetime = 8.0
		emitter.preprocess = 8.0
		emitter.visibility_rect = Rect2(-520.0, -900.0, 1040.0, 1800.0)
		emitter.local_coords = true

		var material := ParticleProcessMaterial.new()
		material.emission_shape = 3
		material.emission_box_extents = (
			Vector3(440.0, 380.0, 1.0) if index == 2 else Vector3(440.0, 760.0, 1.0)
		)
		if index == 2:
			material.emission_shape_offset = Vector3(0.0, -340.0, 0.0)
		material.direction = Vector3(0.0, -1.0, 0.0)
		material.spread = 180.0
		material.initial_velocity_min = AMBIENT_VELOCITY_MIN[index] * profile.speed_scale
		material.initial_velocity_max = AMBIENT_VELOCITY_MAX[index] * profile.speed_scale
		material.gravity = Vector3.ZERO
		material.linear_accel_min = -0.25
		material.linear_accel_max = 0.25
		material.scale_min = AMBIENT_SCALE_MIN[index]
		material.scale_max = AMBIENT_SCALE_MAX[index]
		material.color = (
			profile.mote_tint.lightened(0.12) if index == 2 else profile.mote_tint
		)
		emitter.process_material = material
		layer.add_child(emitter)
		_ambient_emitters.append(emitter)
		emitter.restart()
		emitter.emitting = true

	_update_parallax()


func _clear_ambient_layers() -> void:
	for layer in _ambient_layers:
		if is_instance_valid(layer):
			layer.free()
	_ambient_layers.clear()
	_ambient_emitters.clear()
