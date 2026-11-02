class_name EnvironmentPreviewCompositor
extends Node2D
## Shared data-driven renderer used by the library viewer, zone preview and full-game jump-in.

const WORLD_WIDTH: float = 720.0
const RUN_ORIGIN_WORLD_Y: float = 600.0
const AMBIENT_TEXTURE: Texture2D = preload("res://assets/particles/ambient_mote.svg")
const LAYER_NAMES: Array[String] = ["FarArchitecture", "MiddleArchitecture", "NearArchitecture"]
const BASE_AMBIENT_AMOUNTS: Array[int] = [54, 18, 5]

@export var zone_profile: EnvironmentZoneProfile
@export var world_seed: int = 7319
## Adds the previewed climb height to local plan coordinates in the full-game wrapper.
@export var world_origin_height_px: float = 0.0
@export var camera_path: NodePath
@export var theme_override: EnvironmentThemeProfile
@export var replace_game_ambient_emitters: bool = false
@export var ambient_particles_enabled: bool = true

var validation_errors: Array[String] = []
var validation_warnings: Array[String] = []
var _camera: Camera2D
var _architecture_layers: Array[Node2D] = []
var _ambient_layers: Array[Node2D] = []
var _ambient_emitters: Array[GPUParticles2D] = []
var _active_ambient_profile: EnvironmentAmbientProfile
var _last_plan: Dictionary = {}


func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera2D if not camera_path.is_empty() else null
	_create_architecture_layers()
	if replace_game_ambient_emitters:
		_disable_existing_game_emitters()
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
	if _architecture_layers.is_empty():
		_create_architecture_layers()

	for layer in _architecture_layers:
		for child in layer.get_children():
			child.free()

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

	for placement in _last_plan.placements:
		var definition: ArchitectureModuleDefinition = placement.definition
		if definition.scene == null:
			continue
		var instance := definition.scene.instantiate() as Node2D
		if instance == null:
			push_warning("EnvironmentPreviewCompositor: Module %s did not instantiate as Node2D." % String(definition.module_id))
			continue
		instance.position = placement.root_position + Vector2(0.0, world_origin_height_px)
		instance.scale.x = -1.0 if placement.mirror_x else 1.0
		if instance.has_method("configure"):
			instance.call(
				"configure",
				placement.theme_profile,
				placement.lighting_profile,
				int(placement.seed),
				int(placement.light_state)
			)
		_architecture_layers[int(definition.depth_layer)].add_child(instance)

	for landmark in _last_plan.landmarks:
		var anchor: EnvironmentLandmarkAnchor = landmark.anchor
		if anchor.scene == null:
			continue
		var instance := anchor.scene.instantiate() as Node2D
		if instance == null:
			push_warning("EnvironmentPreviewCompositor: Landmark %s did not instantiate as Node2D." % String(anchor.landmark_id))
			continue
		instance.position = landmark.root_position + Vector2(0.0, world_origin_height_px)
		if instance.has_method("configure"):
			instance.call(
				"configure",
				landmark.theme_profile,
				landmark.lighting_profile,
				int(landmark.seed)
			)
		# Landmarks sit in the middle architectural depth, above far masses.
		_architecture_layers[1].add_child(instance)

	_update_ambient_for_view_height(true)


func get_plan_summary() -> Dictionary:
	return {
		"zone_id": String(zone_profile.zone_id) if zone_profile != null else "",
		"world_seed": world_seed,
		"placement_count": int(_last_plan.get("placement_count", 0)),
		"landmark_count": int(_last_plan.get("landmark_count", 0)),
		"suppressed_count": int(_last_plan.get("suppressed_count", 0)),
		"signature": EnvironmentCompositionPlanner.plan_signature(_last_plan) if not _last_plan.is_empty() else 0,
		"errors": validation_errors.duplicate(),
		"warnings": validation_warnings.duplicate(),
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


func _create_architecture_layers() -> void:
	if not _architecture_layers.is_empty():
		return
	var factors := _get_parallax_factors()
	var x_factors: Array[float] = [0.88, 0.96, 1.0]
	for index in range(3):
		var layer := Node2D.new()
		layer.name = LAYER_NAMES[index]
		layer.scale = Vector2(x_factors[index], factors[index])
		layer.z_index = index + 1
		add_child(layer)
		_architecture_layers.append(layer)


func _get_parallax_factors(ambient: EnvironmentAmbientProfile = null) -> Array[float]:
	if ambient == null:
		ambient = _resolve_ambient_profile_for_current_height()
	if ambient == null:
		return [0.18, 0.46, 0.82]
	return [ambient.far_parallax, ambient.middle_parallax, ambient.near_parallax]


func _update_parallax() -> void:
	if _camera == null:
		return
	var active_profile := _resolve_ambient_profile_for_current_height()
	var factors := _get_parallax_factors(active_profile)
	var x_factors: Array[float] = [0.88, 0.96, 1.0]
	for index in range(_architecture_layers.size()):
		var factor: float = factors[index]
		_architecture_layers[index].scale.y = factor
		_architecture_layers[index].position = Vector2(
			WORLD_WIDTH * 0.5 * (1.0 - x_factors[index]),
			_camera.position.y * (1.0 - factor)
		)
	for index in range(_ambient_layers.size()):
		var factor: float = factors[index]
		_ambient_layers[index].scale.y = factor
		_ambient_layers[index].position = Vector2(
			WORLD_WIDTH * 0.5 * (1.0 - x_factors[index]),
			_camera.position.y * (1.0 - factor)
		)


func _disable_existing_game_emitters() -> void:
	if _camera == null:
		return
	for node_name in ["AmbientMotes", "AmbientMotesNear", "AmbientMoteHighlights"]:
		var emitter := _camera.get_node_or_null(node_name) as GPUParticles2D
		if emitter != null:
			emitter.emitting = false


func _resolve_ambient_profile_for_current_height() -> EnvironmentAmbientProfile:
	var ambient := zone_profile.ambient_profile if zone_profile != null else null
	if zone_profile == null or _camera == null:
		return ambient

	var view_height := world_origin_height_px + RUN_ORIGIN_WORLD_Y - _camera.position.y
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
	if not ambient_particles_enabled:
		_clear_ambient_layers()
		_active_ambient_profile = null
		return

	var ambient := _resolve_ambient_profile_for_current_height()
	if ambient == _active_ambient_profile and not force_rebuild:
		return
	_active_ambient_profile = ambient
	_rebuild_ambient_layers(ambient)


func _rebuild_ambient_layers(profile: EnvironmentAmbientProfile) -> void:
	_clear_ambient_layers()
	if profile == null:
		return
	var factors: Array[float] = [
		profile.far_parallax,
		profile.middle_parallax,
		profile.near_parallax,
	]
	var x_factors: Array[float] = [0.88, 0.96, 1.0]
	for index in range(3):
		var factor := maxf(factors[index], 0.08)
		var layer := Node2D.new()
		layer.name = "AmbientParallax%d" % index
		layer.scale = Vector2(x_factors[index], factor)
		layer.z_index = 20 + index
		add_child(layer)
		_ambient_layers.append(layer)

		var emitter := GPUParticles2D.new()
		emitter.name = "AmbientMoteEmitter"
		emitter.texture = AMBIENT_TEXTURE
		emitter.amount = maxi(1, roundi(float(BASE_AMBIENT_AMOUNTS[index]) * profile.density_scale))
		emitter.lifetime = 8.0
		emitter.preprocess = 8.0
		emitter.visibility_rect = Rect2(-540.0, -2500.0, 1080.0, 5000.0)

		var material := ParticleProcessMaterial.new()
		material.emission_shape = 3
		material.emission_box_extents = Vector3(440.0, 760.0 / factor, 1.0)
		material.direction = Vector3(0.0, -1.0, 0.0)
		material.spread = 180.0
		material.initial_velocity_min = 2.0 * profile.speed_scale
		material.initial_velocity_max = 8.0 * profile.speed_scale
		material.gravity = Vector3.ZERO
		material.linear_accel_min = -0.25
		material.linear_accel_max = 0.25
		material.scale_min = 0.18 if index == 0 else (0.25 if index == 1 else 0.34)
		material.scale_max = 0.48 if index == 0 else (0.58 if index == 1 else 0.72)
		material.color = profile.mote_tint
		emitter.process_material = material
		layer.add_child(emitter)
		_ambient_emitters.append(emitter)
		emitter.emitting = true

		var highlight_count := roundi(float(emitter.amount) * profile.highlight_share)
		if highlight_count > 0:
			var highlight_emitter := GPUParticles2D.new()
			highlight_emitter.name = "AmbientMoteHighlights"
			highlight_emitter.texture = AMBIENT_TEXTURE
			highlight_emitter.amount = highlight_count
			highlight_emitter.lifetime = emitter.lifetime
			highlight_emitter.preprocess = emitter.preprocess
			highlight_emitter.visibility_rect = emitter.visibility_rect
			var highlight_material := material.duplicate() as ParticleProcessMaterial
			highlight_material.scale_min *= 0.62
			highlight_material.scale_max *= 0.78
			highlight_material.color = profile.mote_tint.lightened(0.12)
			highlight_emitter.process_material = highlight_material
			layer.add_child(highlight_emitter)
			_ambient_emitters.append(highlight_emitter)
			highlight_emitter.emitting = true
	_update_parallax()


func _clear_ambient_layers() -> void:
	for layer in _ambient_layers:
		if is_instance_valid(layer):
			layer.free()
	_ambient_layers.clear()
	_ambient_emitters.clear()
