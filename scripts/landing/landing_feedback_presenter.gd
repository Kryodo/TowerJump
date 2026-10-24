extends CanvasLayer

const STATE_INDICATOR_ENERGY_SHADER = preload("res://scenes/state_indicator_energy.gdshader")
const LANDING_GRADE_EMBLEM_SCRIPT = preload("res://scripts/landing/landing_grade_emblem.gd")
const STATE_INDICATOR_ENERGY_FIELD_SCRIPT = preload("res://scripts/landing/state_indicator_energy_field.gd")
## Presents landing rewards and persistent landing states in screen space.
## Scoring remains in LandingScoreController; this node only handles presentation.

@export_category("Reward Presentation")
@export var reward_feedback_enabled: bool = true
@export_range(0.8, 1.5, 0.05) var reward_lifetime: float = 1.05
@export_range(8.0, 36.0, 2.0) var screen_safe_margin: float = 22.0

@export_category("State Indicator")
@export var state_indicator_enabled: bool = true
@export_range(4.0, 24.0, 1.0) var state_follow_speed: float = 12.0

@export var landing_score_controller_path: NodePath = NodePath("../LandingScoreController")
@export var ball_path: NodePath = NodePath("../Ball")
@export var orb_visual_path: NodePath = NodePath("../Ball/Visual")
@export var quality_ring_path: NodePath = NodePath("../Ball/QualityRingIndicator")

const REWARD_SIZE := Vector2(160.0, 66.0)
const STATUS_SIZE := Vector2(184.0, 52.0)
const STATUS_ORB_GAP := 15.0
const STATUS_ROW_CAPTION_WIDTH := 84.0
const STATUS_ROW_GAP := 8.0
const CLUTCH_SIZE := Vector2(144.0, 30.0)

const GOOD_COLOR := Color(0.40, 0.86, 1.0, 1.0)
const EPIC_COLOR := Color(0.92, 0.12, 1.0, 1.0)
const PERFECT_COLOR := Color(0.86, 0.98, 1.0, 1.0)
const STREAK_COLOR := Color(1.0, 0.56, 0.16, 1.0)
const SCORE_COLOR := Color(1.0, 0.82, 0.34, 1.0)
const CLUTCH_COLOR := Color(0.80, 0.96, 1.0, 1.0)
const OUTLINE_COLOR := Color(0.012, 0.025, 0.055, 0.98)

var _score_controller: Node
var _ball: Node2D
var _orb_visual: Sprite2D
var _quality_ring: Node

var _status_root: Control
var _combo_label: Label
var _combo_counter: Label
var _streak_label: Label
var _streak_counter: Label

## Combo/Streak status stays attached to one orb shoulder per activation. It
## never flips sides just because a frame approaches a screen edge.
var _status_position_initialized: bool = false

var _active_rewards: Array[Dictionary] = []
var _active_floats: Array[Dictionary] = []
var _last_state: Dictionary = {}
var _indicator_versions: Dictionary = {}
var _indicator_hiding: Dictionary = {}
var _pulse_clock: float = 0.0
var _state_pop_timer: float = 0.0
var _status_anchor_side: int = 1
var _last_ball_screen_position: Vector2 = Vector2.ZERO
var _status_screen_velocity: Vector2 = Vector2.ZERO
var _orb_core_blend: float = 0.0
var _orb_core_blend_target: float = 0.0
var _orb_core_activation_flash: float = 0.0
var _orb_streak_activation_flash: float = 0.0
var _orb_core_activation_tween: Tween = null
var _orb_streak_activation_tween: Tween = null
var _combo_visual_tier: int = -1
var _streak_visual_tier: int = -1
var _indicator_energy_tweens: Dictionary = {}
var _indicator_energy_targets: Dictionary = {}
var _indicator_energy_field: Control


func _ready() -> void:
	_ball = get_node_or_null(ball_path) as Node2D
	_orb_visual = get_node_or_null(orb_visual_path) as Sprite2D
	_quality_ring = get_node_or_null(quality_ring_path)
	_score_controller = get_node_or_null(landing_score_controller_path)
	_create_state_indicators()

	if _score_controller == null:
		push_warning("LandingFeedbackPresenter: LandingScoreController was not found.")
		return

	var landing_callback := Callable(self, "_on_landing_scored")
	if _score_controller.has_signal("landing_scored"):
		if not _score_controller.is_connected("landing_scored", landing_callback):
			_score_controller.connect("landing_scored", landing_callback)

	var state_callback := Callable(self, "_on_combo_state_changed")
	if _score_controller.has_signal("combo_state_changed"):
		if not _score_controller.is_connected("combo_state_changed", state_callback):
			_score_controller.connect("combo_state_changed", state_callback)

	if _score_controller.has_method("get_combo_state"):
		_on_combo_state_changed(_score_controller.call("get_combo_state"))


func _create_state_indicators() -> void:
	_status_root = Control.new()
	_status_root.name = "LandingStateIndicators"
	_status_root.size = STATUS_SIZE
	_status_root.visible = false
	_status_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_root.z_index = 20
	add_child(_status_root)

	# Captions remain compact and stable; only the numeric values escalate.
	_combo_label = _make_label(
		"ComboStatusLabel", Vector2(84.0, 26.0), 15, EPIC_COLOR, 4
	)
	_combo_label.position = Vector2(0.0, 13.0)
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_combo_label.visible = false
	_status_root.add_child(_combo_label)

	_combo_counter = _make_label(
		"ComboMultiplierCounter", Vector2(100.0, 28.0), 18, EPIC_COLOR, 3
	)
	_combo_counter.position = Vector2(84.0, 11.0)
	_combo_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_combo_counter.visible = false
	_status_root.add_child(_combo_counter)

	_streak_label = _make_label(
		"StreakStatusLabel", Vector2(84.0, 26.0), 15, STREAK_COLOR, 4
	)
	_streak_label.position = Vector2.ZERO
	_streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_streak_label.visible = false
	_status_root.add_child(_streak_label)

	_streak_counter = _make_label(
		"StreakCountCounter", Vector2(100.0, 28.0), 20, STREAK_COLOR, 3
	)
	_streak_counter.position = Vector2(84.0, -2.0)
	_streak_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_streak_counter.visible = false
	_status_root.add_child(_streak_counter)

	# Keep the subtle glyph sheen, then layer animated motes and short filaments
	# directly over the letters so activation reads as moving energy, not just shine.
	_attach_state_energy_material(_combo_label, GOOD_COLOR, 26.0)
	_attach_state_energy_material(_combo_counter, GOOD_COLOR, 26.0)
	_attach_state_energy_material(_streak_label, STREAK_COLOR, 38.0)
	_attach_state_energy_material(_streak_counter, STREAK_COLOR, 38.0)
	_create_shared_state_energy_field()


func _attach_state_energy_material(label: Label, tint: Color, speed: float) -> void:
	var material := ShaderMaterial.new()
	material.shader = STATE_INDICATOR_ENERGY_SHADER
	material.set_shader_parameter("flow_strength", 0.0)
	material.set_shader_parameter("flow_tint", tint)
	material.set_shader_parameter("flow_speed", speed)
	material.set_shader_parameter("flow_period", 92.0)
	label.material = material


func _create_shared_state_energy_field() -> void:
	# One continuous field covers the full indicator instead of decorating each
	# label separately. Filaments can weave around both rows as one energy flow.
	_indicator_energy_field = Control.new()
	_indicator_energy_field.name = "StateIndicatorEnergyField"
	_indicator_energy_field.set_script(STATE_INDICATOR_ENERGY_FIELD_SCRIPT)
	_indicator_energy_field.position = Vector2.ZERO
	_indicator_energy_field.size = STATUS_SIZE
	_indicator_energy_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indicator_energy_field.z_index = 1
	_status_root.add_child(_indicator_energy_field)
	_indicator_energy_field.call("set_energy", 0.0, GOOD_COLOR, 34.0)


func _set_state_indicator_energy(
	combo_active: bool,
	streak_active: bool,
	quality_color: Color,
	combo_just_activated: bool,
	streak_just_activated: bool
) -> void:
	# One status slot is reused for COMBO and STREAK, so its own glyph sheen
	# follows whichever state currently owns the row.
	var status_strength: float = 0.0
	if combo_active:
		status_strength = 0.56
		if streak_active:
			status_strength = 0.68
	elif streak_active:
		status_strength = 0.92

	var status_tint: Color = STREAK_COLOR if streak_active else quality_color
	var status_speed: float = 44.0 if streak_active else 32.0
	var activation: bool = combo_just_activated or streak_just_activated
	_set_state_label_energy(
		_combo_label, status_strength, status_tint, status_speed, activation
	)
	_set_state_label_energy(
		_combo_counter, status_strength * 0.90,
		quality_color.lerp(Color.WHITE, 0.12), status_speed, activation
	)

	# These legacy nodes stay inactive: STREAK takes over the single status row.
	_set_state_label_energy(_streak_label, 0.0, STREAK_COLOR, 44.0, false)
	_set_state_label_energy(_streak_counter, 0.0, STREAK_COLOR, 44.0, false)

	if _indicator_energy_field != null:
		var field_strength: float = 0.0
		var field_tint: Color = quality_color
		var field_speed: float = 34.0
		if combo_active:
			field_strength = 0.92
		if streak_active:
			field_strength = 1.0
			field_tint = STREAK_COLOR
			field_speed = 48.0
		_indicator_energy_field.call(
			"set_energy", field_strength, field_tint, field_speed, activation
		)


func _set_state_label_energy(
	label: Label,
	target_strength: float,
	tint: Color,
	speed: float,
	activation: bool
) -> void:
	if label == null or not is_instance_valid(label):
		return
	var material := label.material as ShaderMaterial
	if material == null:
		return

	material.set_shader_parameter("flow_tint", tint)
	material.set_shader_parameter("flow_speed", speed)

	var target: float = clampf(target_strength, 0.0, 1.0)
	var previous_target: float = float(_indicator_energy_targets.get(label.name, -1.0))
	if is_equal_approx(previous_target, target):
		return
	_indicator_energy_targets[label.name] = target

	var current: float = float(material.get_shader_parameter("flow_strength"))
	var existing_tween := _indicator_energy_tweens.get(label.name) as Tween
	if existing_tween != null and existing_tween.is_valid():
		existing_tween.kill()

	if is_equal_approx(current, target):
		material.set_shader_parameter("flow_strength", target)
		return

	var duration: float = 0.16
	if target > current:
		if activation:
			duration = (
				0.34 if label == _streak_label or label == _streak_counter
				else 0.28
			)
		else:
			duration = 0.20

	var tween := create_tween()
	_indicator_energy_tweens[label.name] = tween
	tween.tween_method(
		Callable(self, "_set_state_label_flow_strength").bind(label),
		current,
		target,
		duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_state_label_flow_strength(value: float, label: Label) -> void:
	if label == null or not is_instance_valid(label):
		return
	var material := label.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter("flow_strength", value)


func _update_state_indicator_motion() -> void:
	# Keep the micro-sway alive between landings. Scale breathing waits until
	# short activation/counter pop tweens finish so it never overrides them.
	var streak_active: bool = bool(_last_state.get("streak_active", false))
	var allow_breathing: bool = _state_pop_timer <= 0.0

	if _combo_label != null and _combo_label.visible and not bool(_indicator_hiding.get(_combo_label.name, false)):
		if allow_breathing:
			var combo_motion: float = 0.012 if not streak_active else 0.016
			_combo_label.scale = Vector2.ONE * (
				1.0 + sin(_pulse_clock * 4.2) * combo_motion
			)
		_combo_label.rotation = sin(_pulse_clock * 3.5 + 0.45) * 0.006
	elif _combo_label != null:
		_combo_label.rotation = 0.0

	if _streak_label != null and _streak_label.visible and not bool(_indicator_hiding.get(_streak_label.name, false)):
		if allow_breathing:
			_streak_label.scale = Vector2.ONE * (
				1.0 + sin(_pulse_clock * 5.1 + 0.9) * 0.022
			)
		_streak_label.rotation = sin(_pulse_clock * 4.3 + 1.2) * 0.013
	elif _streak_label != null:
		_streak_label.rotation = 0.0


func _make_label(
	label_name: String,
	label_size: Vector2,
	font_size: int,
	font_color: Color,
	outline_size: int
) -> Label:
	var label := Label.new()
	label.name = label_name
	label.size = label_size
	label.pivot_offset = label_size * 0.5
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", outline_size)
	label.add_theme_color_override(
		"font_shadow_color",
		Color(font_color.r, font_color.g, font_color.b, 0.38)
	)
	label.add_theme_constant_override("shadow_outline_size", 3)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	return label


func _on_landing_scored(result: Dictionary) -> void:
	if not bool(result.get("scoring_eligible", true)):
		return
	var platform := result.get("platform") as Node2D
	if platform == null or not is_instance_valid(platform):
		return

	var reward_side: int = 0
	if reward_feedback_enabled:
		reward_side = _spawn_landing_reward(result, platform)

	if bool(result.get("clutch", false)):
		_spawn_clutch_feedback(result, platform, reward_side)



func _spawn_landing_reward(result: Dictionary, platform: Node2D) -> int:
	var ball_radius: float = _get_ball_radius()
	var platform_height: float = _get_platform_height(platform)
	var contact_y: float = platform.global_position.y - platform_height * 0.5
	var landing_x: float = float(result.get("landing_world_x", platform.global_position.x))
	var world_anchor := Vector2(landing_x, contact_y - ball_radius)
	var screen_anchor: Vector2 = get_viewport().get_canvas_transform() * world_anchor
	var viewport_size: Vector2 = _get_viewport_size()

	var quality: String = str(result.get("quality", "GOOD"))
	var quality_color: Color = _quality_color(quality)
	var grade_profile: Dictionary = _get_grade_celebration_profile(quality)
	var detail_text: String = _build_reward_detail(result)

	var reward_root := Control.new()
	reward_root.name = "LandingReward"
	reward_root.size = REWARD_SIZE
	reward_root.pivot_offset = REWARD_SIZE * 0.5
	reward_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_root.z_index = 30
	add_child(reward_root)

	# Treat the grade and its geometry as one composition. The composition
	# slides into place; the text gets only a restrained scale impact within it.
	var grade_composition := Control.new()
	grade_composition.name = "LandingGradeComposition"
	grade_composition.size = REWARD_SIZE
	# Scale and rotate the word and its background around the word's visual center.
	grade_composition.pivot_offset = Vector2(REWARD_SIZE.x * 0.5, 11.0)
	grade_composition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_root.add_child(grade_composition)

	var grade_emblem := Control.new()
	grade_emblem.name = "LandingGradeEmblem"
	grade_emblem.set_script(LANDING_GRADE_EMBLEM_SCRIPT)
	grade_emblem.position = Vector2(0.0, -4.0)
	grade_emblem.size = Vector2(REWARD_SIZE.x, 30.0)
	grade_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grade_composition.add_child(grade_emblem)

	var grade_font_size: int = 19
	var grade_label_height: float = 22.0
	match quality:
		"EPIC":
			grade_font_size = 21
			grade_label_height = 25.0
		"PERFECT":
			grade_font_size = 23
			grade_label_height = 28.0

	var grade_label := _make_label(
		"LandingGrade",
		Vector2(REWARD_SIZE.x, grade_label_height),
		grade_font_size,
		quality_color,
		5
	)
	grade_label.text = quality
	# Explicitly center the text on the emblem's drawing center, both axes.
	grade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grade_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grade_label.position = Vector2(
		0.0,
		grade_emblem.position.y + (grade_emblem.size.y - grade_label.size.y) * 0.5
	)
	grade_label.pivot_offset = grade_label.size * 0.5
	grade_composition.add_child(grade_label)
	grade_emblem.call("configure", quality, quality_color)

	var points_label := _make_label(
		"LandingPoints", Vector2(REWARD_SIZE.x, 30.0), 29, SCORE_COLOR, 6
	)
	points_label.position = Vector2(0.0, 19.0)
	points_label.text = "+%d" % int(result.get("total_points", 0))
	reward_root.add_child(points_label)

	var detail_label := _make_label(
		"LandingRewardDetail", Vector2(REWARD_SIZE.x, 18.0), 12, Color(0.84, 0.90, 0.96, 0.92), 0
	)
	detail_label.add_theme_color_override("font_color", Color(0.84, 0.90, 0.96, 0.92))
	detail_label.add_theme_constant_override("outline_size", 0)
	detail_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.0))
	detail_label.add_theme_constant_override("shadow_outline_size", 0)
	detail_label.position = Vector2(0.0, 48.0)
	detail_label.text = detail_text
	reward_root.add_child(detail_label)

	var platform_side := signf(landing_x - platform.global_position.x)
	var preferred_reward_side: int
	if not is_zero_approx(platform_side):
		preferred_reward_side = -int(platform_side)
	else:
		preferred_reward_side = 1 if screen_anchor.x < viewport_size.x * 0.5 else -1

	var start_position: Vector2 = _choose_reward_start(
		screen_anchor,
		viewport_size,
		ball_radius,
		preferred_reward_side
	)
	reward_root.position = start_position
	var reward_side: int = 1 if start_position.x > screen_anchor.x else -1

	var parts: Array[Dictionary] = [
		{
			"label": grade_label,
			"motion_node": grade_composition,
			"base_position": grade_composition.position,
			"delay": 0.0,
			"fade_start": 0.48,
			"fade_duration": 0.22,
			"duration": 0.78,
			"drift_factor": 0.10,
			"drop_factor": 0.18,
			"spring": 0.84,
			"grade_entrance": true,
			"entry_slide_x": float(grade_profile["entry_slide_x"]),
			"entry_slide_direction": -float(reward_side),
			"preload_scale": float(grade_profile["preload_scale"]),
			"anticipation_duration": float(grade_profile["anticipation_duration"]),
			"entry_duration": float(grade_profile["entry_duration"]),
			"impact_scale": float(grade_profile["impact_scale"]),
			"settle_duration": float(grade_profile["settle_duration"]),
			"ambient_breath": float(grade_profile["ambient_breath"]),
			"ambient_rotation": float(grade_profile["ambient_rotation"]),
			"windup_scale": float(grade_profile["windup_scale"]),
			"windup_rotation": float(grade_profile["windup_rotation"]),
			"impact_rotation": float(grade_profile["impact_rotation"]),
			"entry_lift": float(grade_profile["entry_lift"]),
			"entrance_fade_duration": float(grade_profile["entrance_fade_duration"]),
		},
		{
			"label": points_label,
			"base_position": points_label.position,
			"delay": float(grade_profile["points_delay"]),
			"fade_start": 0.73,
			"fade_duration": 0.23,
			"duration": 1.02,
			"drift_factor": 0.20,
			"drop_factor": 0.28,
			"points_entrance": true,
			"points_preload_scale": float(grade_profile["points_preload_scale"]),
			"points_impact_scale": float(grade_profile["points_impact_scale"]),
			"points_entry_duration": float(grade_profile["points_entry_duration"]),
			"points_settle_duration": float(grade_profile["points_settle_duration"]),
			"points_entry_lift": float(grade_profile["points_entry_lift"]),
		},
		{
			"label": detail_label,
			"base_position": detail_label.position,
			"delay": 0.03,
			"fade_start": 0.34,
			"fade_duration": 0.30,
			"duration": 0.70,
			"drift_factor": 0.38,
			"drop_factor": 0.30,
			"spring": 0.90,
		},
	]

	_active_rewards.append({
		"root": reward_root,
		"parts": parts,
		"start_position": start_position,
		"anchor": screen_anchor,
		"age": 0.0,
		"lifetime": maxf(reward_lifetime, 0.8),
		"drift_x": float(reward_side) * randf_range(36.0, 46.0),
		"phase": randf_range(0.0, TAU),
	})
	return reward_side


func _get_grade_celebration_profile(quality: String) -> Dictionary:
	# Cinematic reveal: a deliberate scale rise, restrained lift, then a smooth
	# settle. Grade hierarchy is carried by timing, filament density and color,
	# not a hard squash, rotation whip or elastic overshoot.
	match quality:
		"PERFECT":
			return {
				"preload_scale": 0.92,
				"windup_scale": 0.98,
				"anticipation_duration": 0.035,
				"entry_duration": 0.20,
				"impact_scale": 1.18,
				"settle_duration": 0.15,
				"windup_rotation": -0.018,
				"impact_rotation": 0.006,
				"ambient_breath": 0.0025,
				"ambient_rotation": 0.0015,
				"entry_lift": 5.5,
				"entry_slide_x": 14.0,
				"entrance_fade_duration": 0.18,
				"points_delay": 0.12,
				"points_preload_scale": 0.78,
				"points_impact_scale": 1.32,
				"points_entry_duration": 0.19,
				"points_settle_duration": 0.15,
				"points_entry_lift": 3.0,
			}
		"EPIC":
			return {
				"preload_scale": 0.91,
				"windup_scale": 0.97,
				"anticipation_duration": 0.03,
				"entry_duration": 0.19,
				"impact_scale": 1.14,
				"settle_duration": 0.14,
				"windup_rotation": -0.014,
				"impact_rotation": 0.005,
				"ambient_breath": 0.002,
				"ambient_rotation": 0.001,
				"entry_lift": 4.5,
				"entry_slide_x": 11.0,
				"entrance_fade_duration": 0.15,
				"points_delay": 0.09,
				"points_preload_scale": 0.80,
				"points_impact_scale": 1.27,
				"points_entry_duration": 0.17,
				"points_settle_duration": 0.14,
				"points_entry_lift": 2.5,
			}
		_:
			return {
				"preload_scale": 0.94,
				"windup_scale": 0.98,
				"anticipation_duration": 0.0,
				"entry_duration": 0.12,
				"impact_scale": 1.045,
				"settle_duration": 0.10,
				"windup_rotation": 0.0,
				"impact_rotation": 0.0,
				"ambient_breath": 0.003,
				"ambient_rotation": 0.0,
				"entry_lift": 0.0,
				"entry_slide_x": 8.0,
				"entrance_fade_duration": 0.12,
				"points_delay": 0.04,
				"points_preload_scale": 0.76,
				"points_impact_scale": 1.10,
				"points_entry_duration": 0.13,
				"points_settle_duration": 0.10,
				"points_entry_lift": 1.5,
			}


func _build_reward_detail(result: Dictionary) -> String:
	# Activation copy lives beside the landing reward, where it cannot be lost
	# over the trail. Clutch remains its own edge-anchored event.
	if bool(result.get("streak_activated", false)):
		return "STREAK REACHED"
	if bool(result.get("combo_activated", false)):
		return "COMBO ACTIVATED"

	var quality: String = str(result.get("quality", "GOOD"))
	match quality:
		"PERFECT":
			return "EXCEPTIONAL PRECISION"
		"EPIC":
			return "SHARP PRECISION"
		_:
			return "CLEAN LANDING"

func _choose_reward_start(
	anchor: Vector2,
	viewport_size: Vector2,
	ball_radius: float,
	preferred_side: int
) -> Vector2:
	# Keep the reward beside the landing and slightly lower than before.
	# Placement chooses one local side once; animation never reroutes it.
	var available_right: float = (
		viewport_size.x - screen_safe_margin
		- (anchor.x + ball_radius + 7.0)
	)
	var available_left: float = anchor.x - ball_radius - 7.0 - screen_safe_margin
	var right_fits: bool = available_right >= REWARD_SIZE.x
	var left_fits: bool = available_left >= REWARD_SIZE.x
	var chosen_side: int = 1 if preferred_side >= 0 else -1

	if chosen_side > 0 and not right_fits:
		if left_fits:
			chosen_side = -1
		elif available_left > available_right:
			chosen_side = -1
	elif chosen_side < 0 and not left_fits:
		if right_fits:
			chosen_side = 1
		elif available_right > available_left:
			chosen_side = 1

	var x: float = (
		anchor.x + ball_radius + 7.0
		if chosen_side > 0
		else anchor.x - ball_radius - 7.0 - REWARD_SIZE.x
	)
	# With the compact cluster this places its last row just above the platform.
	var y: float = anchor.y - 36.0
	return _fit_local_position(Vector2(x, y), REWARD_SIZE, viewport_size)


func _spawn_clutch_feedback(
	result: Dictionary,
	platform: Node2D,
	reward_side: int
) -> void:
	var half_width: float = 110.0
	if platform.has_method("half_width"):
		half_width = maxf(float(platform.call("half_width")), 1.0)
	else:
		var width_value: Variant = platform.get("width")
		if width_value != null:
			half_width = maxf(float(width_value) * 0.5, 1.0)

	var landing_x: float = float(result.get("landing_world_x", platform.global_position.x))
	var landing_side: float = signf(landing_x - platform.global_position.x)
	var viewport_size: Vector2 = _get_viewport_size()
	if is_zero_approx(landing_side):
		var platform_screen := get_viewport().get_canvas_transform() * platform.global_position
		landing_side = 1.0 if platform_screen.x < viewport_size.x * 0.5 else -1.0

	var world_edge := Vector2(
		platform.global_position.x + landing_side * half_width,
		platform.global_position.y - _get_platform_height(platform) * 0.5
	)
	var edge_screen: Vector2 = get_viewport().get_canvas_transform() * world_edge

	# Clutch belongs outside the risky edge when space permits. If the reward
	# had to use that same side, place Clutch just below the edge to separate
	# the two events vertically instead of forcing the reward to relocate.
	var outside_x: float = (
		edge_screen.x + 7.0
		if landing_side > 0.0
		else edge_screen.x - CLUTCH_SIZE.x - 7.0
	)
	var outside_fits: bool = (
		outside_x >= screen_safe_margin
		and outside_x + CLUTCH_SIZE.x <= viewport_size.x - screen_safe_margin
	)
	var inside_x: float = (
		edge_screen.x - CLUTCH_SIZE.x - 7.0
		if landing_side > 0.0
		else edge_screen.x + 7.0
	)
	var requested_x: float = outside_x if outside_fits else inside_x
	var requested_y: float = edge_screen.y - _get_ball_radius() - CLUTCH_SIZE.y + 8.0
	if reward_side != 0 and reward_side == int(landing_side):
		requested_y = edge_screen.y + 12.0

	var start := _fit_local_position(
		Vector2(requested_x, requested_y),
		CLUTCH_SIZE,
		viewport_size
	)
	var clutch_drift_direction: float = landing_side if outside_fits else -landing_side
	var clutch_label := _spawn_floating_label(
		"◆  CLUTCH +%d" % int(result.get("clutch_bonus", 0)),
		CLUTCH_COLOR,
		17,
		CLUTCH_SIZE,
		start,
		0.74,
		clutch_drift_direction * 22.0,
		28.0,
		0.008,
		38,
		0.0
	)
	if clutch_label != null:
		clutch_label.z_index = 36




func _spawn_floating_label(
	label_text: String,
	color: Color,
	font_size: int,
	label_size: Vector2,
	start_position: Vector2,
	lifetime: float,
	drift_x: float,
	drift_y: float,
	max_rotation: float,
	z_index: int,
	start_delay: float
) -> Label:
	var label := _make_label(
		"FloatingEvent",
		label_size,
		font_size,
		color,
		5
	)
	label.text = label_text
	label.position = start_position
	label.z_index = z_index
	label.modulate.a = 0.0
	label.scale = Vector2.ONE * 0.78
	add_child(label)

	_active_floats.append({
		"label": label,
		"start_position": start_position,
		"age": 0.0,
		"delay": start_delay,
		"lifetime": lifetime,
		"drift_x": drift_x,
		"drift_y": drift_y,
		"rotation": max_rotation,
		"phase": randf_range(0.0, TAU),
	})
	return label


func _get_indicator_text_width(label: Label) -> float:
	if label == null or not is_instance_valid(label):
		return 0.0
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	if label == _combo_counter or label == _streak_counter:
		font_size = int(label.get_meta("counter_target_font_size", font_size))

	# When the side is first selected, the live label text may not have been
	# assigned yet. Measure the current state values in that brief window.
	var text_value: String = label.text
	if text_value.is_empty():
		if label == _combo_label:
			if bool(_last_state.get("streak_active", false)):
				text_value = "STREAK %02d" % int(_last_state.get("chain_count", 0))
			else:
				text_value = "✦  COMBO"
		elif label == _streak_label:
			text_value = "▲  STREAK"
		elif label == _combo_counter:
			text_value = "×%.2f" % float(_last_state.get("multiplier", 1.0))
		elif label == _streak_counter:
			text_value = "%02d" % int(_last_state.get("chain_count", 0))

	return font.get_string_size(
		text_value,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size
	).x


func _get_status_content_width(side: int) -> float:
	# There is exactly one status row now, whether it reads COMBO or STREAK.
	if not bool(_last_state.get("combo_active", false)) and not bool(_last_state.get("streak_active", false)):
		return STATUS_SIZE.x

	var caption_text_width: float = _get_indicator_text_width(_combo_label)
	var counter_width: float = _get_indicator_text_width(_combo_counter)
	var streak_row: bool = (
		bool(_last_state.get("streak_active", false))
		or _combo_label.text.begins_with("STREAK")
	)
	if streak_row:
		# Measure the target text too: on activation, this can run before the
		# caption has been changed from COMBO to STREAK nn.
		var caption_font: Font = _combo_label.get_theme_font("font")
		var target_caption: String = "STREAK %02d" % int(_last_state.get("chain_count", 0))
		caption_text_width = caption_font.get_string_size(
			target_caption, HORIZONTAL_ALIGNMENT_LEFT, -1,
			_combo_label.get_theme_font_size("font_size")
		).x
		return maxf(STATUS_ROW_CAPTION_WIDTH, caption_text_width + 2.0) + STATUS_ROW_GAP + counter_width

	var caption_width: float = minf(caption_text_width, _combo_label.size.x)
	if side > 0:
		return maxf(caption_width, _combo_label.size.x + counter_width)

	var mirrored_counter_gap: float = maxf(0.0, _combo_label.size.x - caption_width)
	return _combo_label.size.x + mirrored_counter_gap + counter_width


func _choose_status_anchor_side(ball_screen: Vector2, viewport_size: Vector2) -> int:
	var radius: float = _get_ball_radius()
	var left_space: float = ball_screen.x - radius - STATUS_ORB_GAP - screen_safe_margin
	var right_space: float = viewport_size.x - screen_safe_margin - (ball_screen.x + radius + STATUS_ORB_GAP)
	var left_width: float = _get_status_content_width(-1)
	var right_width: float = _get_status_content_width(1)
	if right_space >= right_width and left_space < left_width:
		return 1
	if left_space >= left_width and right_space < right_width:
		return -1
	# When both sides fit, place the tag on the inboard shoulder.
	return 1 if ball_screen.x < viewport_size.x * 0.5 else -1


func _get_status_target(ball_screen: Vector2, viewport_size: Vector2) -> Vector2:
	var radius: float = _get_ball_radius()
	var x: float = (
		ball_screen.x + radius + STATUS_ORB_GAP
		if _status_anchor_side > 0
		else ball_screen.x - radius - STATUS_ORB_GAP - _get_status_content_width(-1)
	)
	# The tag sits beside the upper shoulder, never directly above the core.
	var y: float = ball_screen.y - radius * 0.62 - STATUS_SIZE.y * 0.50
	# Keep the horizontal shoulder anchor honest: clipping/fading is better than
	# clamping the tag over the orb when the selected side has limited room.
	var max_y: float = maxf(screen_safe_margin, viewport_size.y - screen_safe_margin - STATUS_SIZE.y)
	return Vector2(x, clampf(y, screen_safe_margin, max_y))


func _get_status_edge_visibility(ball_screen: Vector2, viewport_size: Vector2) -> float:
	var radius: float = _get_ball_radius()
	var available: float
	var content_width: float = _get_status_content_width(_status_anchor_side)
	if _status_anchor_side > 0:
		available = viewport_size.x - screen_safe_margin - (ball_screen.x + radius + STATUS_ORB_GAP)
	else:
		available = ball_screen.x - radius - STATUS_ORB_GAP - screen_safe_margin
	return clampf(available / maxf(content_width, 1.0), 0.0, 1.0)


func _update_status_follow(delta: float) -> void:
	if _status_root == null or not _status_root.visible or not state_indicator_enabled:
		return

	var viewport_size: Vector2 = _get_viewport_size()
	var ball_screen: Vector2 = _get_ball_screen_position()
	var wrap_distance: float = minf(120.0, viewport_size.x * 0.22)
	var did_wrap: bool = (
		_status_position_initialized
		and ball_screen.distance_to(_last_ball_screen_position) > wrap_distance
	)
	if did_wrap:
		_status_screen_velocity = Vector2.ZERO
		# A screen wrap is a teleport, not ordinary motion: reselect only if the
		# locked side no longer fits at the destination.
		if _get_status_edge_visibility(ball_screen, viewport_size) < 1.0:
			_status_anchor_side = _choose_status_anchor_side(ball_screen, viewport_size)
			_layout_status_row(_combo_label, _combo_counter, 13.0, 11.0)
		_last_ball_screen_position = ball_screen
	elif not _status_position_initialized:
		_last_ball_screen_position = ball_screen
		_status_screen_velocity = Vector2.ZERO
	else:
		if delta > 0.0:
			var raw_velocity: Vector2 = (ball_screen - _last_ball_screen_position) / delta
			_status_screen_velocity = _status_screen_velocity.lerp(raw_velocity, 0.18)
		_last_ball_screen_position = ball_screen

	# A small, filtered lead keeps the tag beside the orb instead of trailing
	# into the comet ribbon. The cap prevents sudden motion from moving the tag.
	var predictive_offset := Vector2(
		clampf(_status_screen_velocity.x * 0.035, -7.0, 7.0),
		clampf(_status_screen_velocity.y * 0.025, -4.0, 4.0)
	)
	var target_position: Vector2 = _get_status_target(ball_screen + predictive_offset, viewport_size)
	var target_jump_distance: float = _status_root.position.distance_to(target_position)

	if (
		not _status_position_initialized
		or target_jump_distance > minf(120.0, viewport_size.x * 0.22)
	):
		_status_root.position = target_position
		_status_position_initialized = true
	else:
		var follow_weight: float = 1.0 - exp(-state_follow_speed * delta)
		_status_root.position = _status_root.position.lerp(target_position, follow_weight)

	# Do not flip the label at an edge. If its locked side no longer has room,
	# it fades away; the orb's chain ring/core remains the backup state cue.
	_status_root.modulate.a = _get_status_edge_visibility(ball_screen, viewport_size)

func _layout_status_row(caption: Label, counter: Label, caption_y: float, counter_y: float) -> void:
	# STREAK nn is longer than COMBO, so give it a measured slot and an explicit
	# gap before the multiplier. Keep the existing COMBO layout unchanged.
	var streak_row: bool = caption.text.begins_with("STREAK")
	var caption_text_width: float = _get_indicator_text_width(caption)
	var caption_slot_width: float = STATUS_ROW_CAPTION_WIDTH
	if streak_row:
		caption_slot_width = maxf(STATUS_ROW_CAPTION_WIDTH, caption_text_width + 2.0)
	caption.size.x = caption_slot_width
	caption.pivot_offset = Vector2(caption_slot_width * 0.5, caption.size.y * 0.5)
	caption.position = Vector2(0.0, caption_y)

	if _status_anchor_side > 0:
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var multiplier_x: float = caption_slot_width
		if streak_row:
			multiplier_x += STATUS_ROW_GAP
		counter.position = Vector2(multiplier_x, counter_y)
	else:
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if streak_row:
			var streak_counter_text_width: float = _get_indicator_text_width(counter)
			var streak_counter_x: float = (
				caption_slot_width + STATUS_ROW_GAP
				+ streak_counter_text_width - counter.size.x
			)
			counter.position = Vector2(streak_counter_x, counter_y)
		else:
			var old_row_gap: float = maxf(
				0.0, STATUS_ROW_CAPTION_WIDTH - caption_text_width
			)
			var combo_counter_text_width: float = _get_indicator_text_width(counter)
			var counter_text_start: float = STATUS_ROW_CAPTION_WIDTH + old_row_gap
			var combo_counter_x: float = counter_text_start + combo_counter_text_width - counter.size.x
			counter.position = Vector2(combo_counter_x, counter_y)


func _on_combo_state_changed(state: Dictionary) -> void:
	if not state_indicator_enabled or _status_root == null:
		return

	var previous_chain_count: int = int(_last_state.get("chain_count", 0))
	var previous_multiplier: float = float(_last_state.get("multiplier", 1.0))
	var previous_combo_active: bool = bool(_last_state.get("combo_active", false))
	var previous_streak_active: bool = bool(_last_state.get("streak_active", false))
	var previous_combo_tier: int = _combo_visual_tier
	var previous_streak_tier: int = _streak_visual_tier
	_last_state = state.duplicate(true)

	var chain_count: int = int(state.get("chain_count", 0))
	var quality: String = str(state.get("quality", "GOOD"))
	var combo_active: bool = bool(state.get("combo_active", false))
	var streak_active: bool = bool(state.get("streak_active", false))
	var combo_just_activated: bool = combo_active and not previous_combo_active
	var streak_just_activated: bool = streak_active and not previous_streak_active
	var quality_color: Color = _quality_color(quality)
	_set_state_indicator_energy(
		combo_active, streak_active, quality_color,
		combo_just_activated, streak_just_activated
	)
	if combo_just_activated:
		_play_orb_combo_activation()
	if streak_just_activated:
		_play_orb_streak_activation()
	_update_orb_chain_feedback(chain_count, quality, combo_active)

	if chain_count <= 0 or (not combo_active and not streak_active):
		_hide_indicator(_combo_label)
		_hide_indicator(_combo_counter)
		_hide_indicator(_streak_label)
		_hide_indicator(_streak_counter)
		_status_root.visible = false
		_status_root.modulate.a = 1.0
		_status_position_initialized = false
		_status_screen_velocity = Vector2.ZERO
		_combo_visual_tier = -1
		_streak_visual_tier = -1
		return

	var multiplier: float = float(state.get("multiplier", 1.0))
	if not _status_root.visible:
		_status_anchor_side = _choose_status_anchor_side(
			_get_ball_screen_position(),
			_get_viewport_size()
		)
		_status_position_initialized = false
		_last_ball_screen_position = _get_ball_screen_position()
	_status_root.visible = true

	# COMBO and STREAK share one fixed row. The multiplier is slightly smaller;
	# STREAK's live chain count gets a little more size to balance its importance.
	_combo_label.add_theme_font_size_override("font_size", 17 if streak_active else 15)
	_layout_status_row(_combo_label, _combo_counter, 13.0, 11.0)
	_streak_label.visible = false
	_streak_label.modulate = Color.WHITE
	_streak_label.scale = Vector2.ONE
	_streak_label.rotation = 0.0
	_streak_counter.visible = false
	_streak_counter.modulate = Color.WHITE
	_streak_counter.scale = Vector2.ONE
	_streak_counter.rotation = 0.0

	var combo_intensity: float = 0.0
	var combo_tier: int = -1
	var combo_tier_up: bool = false
	if combo_active:
		combo_intensity = _get_combo_visual_intensity(multiplier, quality)
		combo_tier = _get_visual_tier(combo_intensity)
		combo_tier_up = previous_combo_active and combo_tier > previous_combo_tier

	var streak_intensity: float = 0.0
	var streak_tier: int = -1
	var streak_tier_up: bool = false
	var streak_activation_count: int = int(state.get("streak_activation_landings", 10))
	if streak_active:
		streak_intensity = _get_streak_visual_intensity(
			chain_count, streak_activation_count
		)
		streak_tier = _get_visual_tier(streak_intensity)
		streak_tier_up = previous_streak_active and streak_tier > previous_streak_tier

	var combo_counter_color: Color = quality_color.lerp(Color.WHITE, 0.08)
	if streak_active:
		# Take over the existing caption instead of creating a second important
		# indicator. No separate STREAK row or count counter is shown.
		var multiplier_intensity: float = combo_intensity if combo_active else streak_intensity
		_apply_counter_intensity(_combo_counter, multiplier_intensity, 18, 7)
		_set_indicator(
			_combo_label, "STREAK %02d" % chain_count,
			STREAK_COLOR, streak_just_activated
		)
		_set_counter_indicator(
			_combo_counter, "×%.2f" % multiplier,
			combo_counter_color, combo_just_activated or streak_just_activated
		)

		if previous_streak_active and chain_count > previous_chain_count:
			# Let the count update give the shared status slot a compact impact.
			_animate_counter_change(
				_combo_label, streak_intensity, streak_tier_up, STREAK_COLOR
			)
		if (previous_combo_active or previous_streak_active) and multiplier > previous_multiplier + 0.001:
			_animate_counter_change(
				_combo_counter, multiplier_intensity, combo_tier_up, combo_counter_color
			)
	else:
		if combo_active:
			_apply_counter_intensity(_combo_counter, combo_intensity, 18, 7)
			_set_indicator(_combo_label, "✦  COMBO", quality_color, combo_just_activated)
			_set_counter_indicator(
				_combo_counter, "×%.2f" % multiplier,
				combo_counter_color, combo_just_activated
			)
			if previous_combo_active and multiplier > previous_multiplier + 0.001:
				_animate_counter_change(
					_combo_counter, combo_intensity, combo_tier_up, combo_counter_color
				)
		else:
			_hide_indicator(_combo_label)
			_hide_indicator(_combo_counter)

	# Recalculate after the caption switches between COMBO and STREAK nn.
	_layout_status_row(_combo_label, _combo_counter, 13.0, 11.0)
	_combo_visual_tier = combo_tier if combo_active else -1
	_streak_visual_tier = streak_tier if streak_active else -1

	if combo_just_activated or streak_just_activated:
		_state_pop_timer = 0.62
	elif combo_tier_up or streak_tier_up:
		_state_pop_timer = 0.34
	elif previous_chain_count != chain_count:
		_state_pop_timer = 0.24


func _get_combo_visual_intensity(multiplier: float, quality: String) -> float:
	var start_multiplier: float = 1.15
	var cap_multiplier: float = 2.0
	match quality:
		"EPIC":
			start_multiplier = 1.35
			cap_multiplier = 3.25
		"PERFECT":
			start_multiplier = 1.65
			cap_multiplier = 4.0
	return clampf(
		(multiplier - start_multiplier) / maxf(cap_multiplier - start_multiplier, 0.01),
		0.0,
		1.0
	)


func _get_streak_visual_intensity(chain_count: int, activation_count: int) -> float:
	var growth_span: float = maxf(float(activation_count) * 1.2, 4.0)
	return clampf(float(chain_count - activation_count) / growth_span, 0.0, 1.0)


func _get_visual_tier(intensity: float) -> int:
	return clampi(int(floor(clampf(intensity, 0.0, 1.0) * 4.0)), 0, 3)


func _apply_counter_intensity(
	label: Label,
	_intensity: float,
	base_font_size: int = 20,
	_growth_font_size: int = 9
) -> void:
	if label == null or not is_instance_valid(label):
		return
	# Keep the counter visually stable between increases. Intensity is used for
	# milestone detection only, not for permanent size/glow escalation.
	label.set_meta("feedback_intensity", 0.0)
	label.set_meta("counter_target_font_size", base_font_size)
	label.add_theme_font_size_override("font_size", base_font_size)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_constant_override("shadow_outline_size", 3)

func _set_indicator_font_size(value: float, label: Label) -> void:
	if not is_instance_valid(label):
		return
	label.add_theme_font_size_override("font_size", maxi(roundi(value), 15))


func _set_counter_font_size(value: float, label: Label) -> void:
	if not is_instance_valid(label):
		return
	label.add_theme_font_size_override("font_size", maxi(roundi(value), 18))


func _set_counter_flash(value: float, label: Label, base_color: Color) -> void:
	if not is_instance_valid(label):
		return
	var flash: float = clampf(value, 0.0, 1.0)
	label.add_theme_color_override("font_color", base_color.lerp(Color.WHITE, flash * 0.62))
	label.add_theme_color_override(
		"font_shadow_color",
		Color(base_color.r, base_color.g, base_color.b, lerpf(0.42, 0.90, flash))
	)


func _animate_counter_change(
	label: Label,
	_intensity: float,
	milestone: bool,
	base_color: Color
) -> void:
	if label == null or not is_instance_valid(label):
		return
	var peak_scale: float = 1.19 if milestone else 1.125
	var flash_method := Callable(self, "_set_counter_flash").bind(label, base_color)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		label, "scale", Vector2.ONE * peak_scale, 0.075
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_method(flash_method, 0.0, 1.0, 0.045)
	tween.set_parallel(false)
	tween.tween_property(
		label, "scale", Vector2.ONE * 0.985, 0.075
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_method(flash_method, 1.0, 0.0, 0.14)
	tween.tween_property(
		label, "scale", Vector2.ONE, 0.10
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _update_orb_chain_feedback(chain_count: int, quality: String, combo_active: bool) -> void:
	if _quality_ring != null and is_instance_valid(_quality_ring) and _quality_ring.has_method("set_quality_state"):
		_quality_ring.call("set_quality_state", chain_count, quality)

	if _orb_visual == null or not is_instance_valid(_orb_visual):
		return
	var material := _orb_visual.material as ShaderMaterial
	if material == null:
		return

	var quality_id: int = 0
	match quality:
		"EPIC":
			quality_id = 1
		"PERFECT":
			quality_id = 2

	material.set_shader_parameter("combo_core_active", 1.0 if combo_active else 0.0)
	if combo_active:
		# Keep the core's quality tint while Combo is active. The separate ring
		# renderer no longer depends on this material or the cosmetic skin hue.
		material.set_shader_parameter("combo_core_quality", quality_id)
		_orb_core_blend_target = 1.0
	else:
		_orb_core_blend_target = 0.0

func _play_orb_combo_activation() -> void:
	if _orb_core_activation_tween != null and _orb_core_activation_tween.is_valid():
		_orb_core_activation_tween.kill()
	_orb_core_activation_flash = 0.0
	_orb_core_activation_tween = create_tween()
	var flash_setter := Callable(self, "_set_orb_core_activation_flash")
	_orb_core_activation_tween.tween_method(flash_setter, 0.0, 1.0, 0.09).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_orb_core_activation_tween.tween_method(flash_setter, 1.0, 0.0, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_orb_core_activation_flash(value: float) -> void:
	_orb_core_activation_flash = clampf(value, 0.0, 1.0)


func _play_orb_streak_activation() -> void:
	if _orb_streak_activation_tween != null and _orb_streak_activation_tween.is_valid():
		_orb_streak_activation_tween.kill()
	_orb_streak_activation_flash = 0.0
	if _quality_ring != null and is_instance_valid(_quality_ring) and _quality_ring.has_method("play_streak_activation"):
		_quality_ring.call("play_streak_activation")
	_orb_streak_activation_tween = create_tween()
	var flash_setter := Callable(self, "_set_orb_streak_activation_flash")
	_orb_streak_activation_tween.tween_method(flash_setter, 0.0, 1.0, 0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_orb_streak_activation_tween.tween_method(flash_setter, 1.0, 0.0, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_orb_streak_activation_flash(value: float) -> void:
	_orb_streak_activation_flash = clampf(value, 0.0, 1.0)


func _update_orb_core_blend(delta: float) -> void:
	if _orb_visual == null or not is_instance_valid(_orb_visual):
		return
	var material := _orb_visual.material as ShaderMaterial
	if material == null:
		return
	var weight: float = 1.0 - exp(-14.0 * delta)
	_orb_core_blend = lerpf(_orb_core_blend, _orb_core_blend_target, weight)
	material.set_shader_parameter("combo_core_blend", _orb_core_blend)
	material.set_shader_parameter("combo_activation_flash", _orb_core_activation_flash)
	material.set_shader_parameter("streak_activation_flash", _orb_streak_activation_flash)

func _set_indicator(label: Label, text_value: String, color: Color, animate: bool) -> void:
	if label == null:
		return

	var was_visible: bool = label.visible
	var was_hiding: bool = bool(_indicator_hiding.get(label.name, false))
	var text_changed: bool = label.text != text_value
	label.text = text_value
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(color.r, color.g, color.b, 0.48))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_constant_override("shadow_outline_size", 3)
	if not was_visible:
		animate = true

	label.visible = true
	_indicator_versions[label.name] = int(_indicator_versions.get(label.name, 0)) + 1
	_indicator_hiding[label.name] = false

	if not animate and not text_changed:
		if was_hiding:
			label.modulate = Color.WHITE
			label.scale = Vector2.ONE
		return
	if not animate:
		label.modulate = Color.WHITE
		label.scale = Vector2.ONE
		return

	var target_font_size: int = maxi(label.get_theme_font_size("font_size"), 15)
	label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	label.scale = Vector2.ONE * 0.78
	label.rotation = 0.0

	var peak_scale: float = 1.16 if label == _combo_label else 1.12
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, 0.08)
	tween.tween_property(label, "scale", Vector2.ONE * peak_scale, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_property(label, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _set_counter_indicator(label: Label, text_value: String, color: Color, animate: bool) -> void:
	if label == null:
		return

	var was_visible: bool = label.visible
	var was_hiding: bool = bool(_indicator_hiding.get(label.name, false))
	var text_changed: bool = label.text != text_value
	label.text = text_value
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(color.r, color.g, color.b, 0.46))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_constant_override("shadow_outline_size", 3)
	if not was_visible:
		animate = true

	label.visible = true
	_indicator_versions[label.name] = int(_indicator_versions.get(label.name, 0)) + 1
	_indicator_hiding[label.name] = false

	if not animate:
		if was_hiding:
			label.modulate = Color.WHITE
			label.scale = Vector2.ONE
			label.rotation = 0.0
		return
	if not text_changed and was_visible and not was_hiding:
		return

	var target_font_size: int = int(label.get_meta("counter_target_font_size", 18))
	label.add_theme_font_size_override("font_size", target_font_size + 3)
	label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	label.scale = Vector2.ONE * 0.70
	label.rotation = 0.0
	var peak_scale: float = 1.24 if label == _combo_counter else 1.18
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, 0.075)
	tween.tween_property(
		label, "scale", Vector2.ONE * peak_scale, 0.18
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var font_tweener = tween.tween_method(
		Callable(self, "_set_counter_font_size").bind(label),
		float(target_font_size + 3),
		float(target_font_size),
		0.22
	)
	font_tweener.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_property(label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _hide_indicator(label: Label) -> void:
	if label == null or not label.visible:
		return
	if bool(_indicator_hiding.get(label.name, false)):
		return

	var version: int = int(_indicator_versions.get(label.name, 0)) + 1
	_indicator_versions[label.name] = version
	_indicator_hiding[label.name] = true

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 0.0, 0.14)
	tween.tween_property(label, "scale", Vector2.ONE * 0.90, 0.14)
	tween.chain().tween_callback(func() -> void:
		if not is_instance_valid(label):
			return
		if int(_indicator_versions.get(label.name, 0)) != version:
			return
		_indicator_hiding[label.name] = false
		label.visible = false
		label.modulate = Color.WHITE
		label.scale = Vector2.ONE
		label.rotation = 0.0
	)


func _quality_color(quality: String) -> Color:
	match quality:
		"PERFECT":
			return PERFECT_COLOR
		"EPIC":
			return EPIC_COLOR
		_:
			return GOOD_COLOR


func _get_platform_height(platform: Node2D) -> float:
	var height_value: Variant = platform.get("height")
	if height_value != null:
		return maxf(float(height_value), 1.0)
	return 20.0


func _get_ball_radius() -> float:
	if _ball != null and is_instance_valid(_ball):
		var radius_value: Variant = _ball.get("radius")
		if radius_value != null:
			return maxf(float(radius_value), 1.0)
	return 30.0


func _get_viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _get_ball_screen_position() -> Vector2:
	if _ball == null or not is_instance_valid(_ball):
		return _get_viewport_size() * 0.5
	return get_viewport().get_canvas_transform() * _ball.global_position


func _fit_local_position(position: Vector2, element_size: Vector2, viewport_size: Vector2) -> Vector2:
	var max_x: float = maxf(screen_safe_margin, viewport_size.x - screen_safe_margin - element_size.x)
	var max_y: float = maxf(screen_safe_margin, viewport_size.y - screen_safe_margin - element_size.y)
	return Vector2(
		clampf(position.x, screen_safe_margin, max_x),
		clampf(position.y, screen_safe_margin, max_y)
	)


func _update_reward_animations(delta: float) -> void:
	for i in range(_active_rewards.size() - 1, -1, -1):
		var reward: Dictionary = _active_rewards[i]
		var root := reward.get("root") as Control
		if root == null or not is_instance_valid(root):
			_active_rewards.remove_at(i)
			continue

		var age: float = float(reward.get("age", 0.0)) + delta
		var lifetime: float = maxf(float(reward.get("lifetime", reward_lifetime)), 0.8)
		reward["age"] = age
		var progress: float = clampf(age / lifetime, 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - progress, 2.0)
		var phase: float = float(reward.get("phase", 0.0))
		var start_position: Vector2 = reward.get("start_position", root.position)
		var drift_x: float = float(reward.get("drift_x", 34.0))
		var flutter: float = sin(age * 7.5 + phase) * 1.0 * (1.0 - progress)
		root.position = start_position + Vector2(
			drift_x * eased + flutter,
			17.0 * eased + sin(age * 5.0 + phase) * 1.0
		)

		var parts: Array = reward.get("parts", [])
		for part_value in parts:
			var part: Dictionary = part_value
			var label := part.get("label") as Label
			if label == null or not is_instance_valid(label):
				continue

			var motion_node := part.get("motion_node") as Control
			var position_node: Control = (
				motion_node
				if motion_node != null and is_instance_valid(motion_node)
				else label
			)

			var local_age: float = age - float(part.get("delay", 0.0))
			if local_age < 0.0:
				label.modulate.a = 0.0
				if motion_node != null and is_instance_valid(motion_node):
					motion_node.modulate.a = 0.0
				continue

			var duration: float = maxf(float(part.get("duration", lifetime)), 0.1)
			var part_progress: float = clampf(local_age / duration, 0.0, 1.0)
			var part_eased: float = 1.0 - pow(1.0 - part_progress, 2.0)
			var base_position: Vector2 = part.get("base_position", position_node.position)
			var part_drift: float = drift_x * float(part.get("drift_factor", 1.0))
			var part_drop: float = 7.0 * float(part.get("drop_factor", 0.5))
			var part_flutter: float = sin(local_age * 9.0 + phase) * 1.0 * (1.0 - part_progress)
			var part_motion_position: Vector2 = base_position + Vector2(
				part_drift * part_eased + part_flutter,
				part_drop * part_eased
			)
			position_node.position = part_motion_position

			var alpha: float = 1.0
			if local_age < 0.07:
				alpha = local_age / 0.07
			var fade_start: float = float(part.get("fade_start", 0.7))
			var fade_duration: float = maxf(float(part.get("fade_duration", 0.2)), 0.05)
			if local_age > fade_start:
				alpha *= 1.0 - clampf((local_age - fade_start) / fade_duration, 0.0, 1.0)
			if motion_node != null and is_instance_valid(motion_node):
				# Fade the whole grade composition once, keeping both layers joined.
				label.modulate.a = 1.0
				motion_node.modulate.a = clampf(alpha, 0.0, 1.0)
			else:
				label.modulate.a = clampf(alpha, 0.0, 1.0)

			if bool(part.get("grade_entrance", false)):
				var preload_scale: float = float(part.get("preload_scale", 0.82))
				var windup_scale: float = float(part.get("windup_scale", preload_scale))
				var anticipation: float = float(part.get("anticipation_duration", 0.0))
				var entry_duration: float = maxf(float(part.get("entry_duration", 0.105)), 0.01)
				var impact_scale: float = float(part.get("impact_scale", 1.055))
				var settle_duration: float = maxf(float(part.get("settle_duration", 0.105)), 0.01)
				var windup_rotation: float = float(part.get("windup_rotation", 0.0))
				var impact_rotation: float = float(part.get("impact_rotation", 0.0))
				var ambient_rotation: float = float(part.get("ambient_rotation", 0.0))
				var entry_lift: float = float(part.get("entry_lift", 0.0))
				var entrance_fade_duration: float = maxf(
					float(part.get("entrance_fade_duration", 0.14)), 0.01
				)
				var fade_progress: float = clampf(local_age / entrance_fade_duration, 0.0, 1.0)
				var fade_eased: float = 1.0 - pow(1.0 - fade_progress, 3.0)
				if motion_node != null and is_instance_valid(motion_node):
					motion_node.modulate.a = minf(motion_node.modulate.a, fade_eased)
				else:
					label.modulate.a = minf(label.modulate.a, fade_eased)
				var entry_slide_x: float = float(part.get("entry_slide_x", 0.0))
				var entry_slide_direction: float = float(part.get("entry_slide_direction", -1.0))
				var entrance_offset_x: float = 0.0
				var entrance_offset_y: float = 0.0

				if anticipation > 0.0 and local_age < anticipation:
					var anticipation_progress: float = clampf(local_age / anticipation, 0.0, 1.0)
					var anticipation_eased: float = 1.0 - pow(1.0 - anticipation_progress, 2.0)
					position_node.scale = Vector2.ONE * lerpf(
						preload_scale, windup_scale, anticipation_eased
					)
					position_node.rotation = lerpf(0.0, windup_rotation, anticipation_eased)
					entrance_offset_x = entry_slide_x * entry_slide_direction * (1.0 - anticipation_progress * 0.10)
					entrance_offset_y = entry_lift * (1.0 - anticipation_progress * 0.10)
				elif local_age < anticipation + entry_duration:
					var entry_progress: float = clampf(
						(local_age - anticipation) / entry_duration, 0.0, 1.0
					)
					# A controlled, non-elastic reveal: quick acceleration with no
					# back-ease overshoot or visible rotational whip.
					var entry_eased: float = 1.0 - pow(1.0 - entry_progress, 3.0)
					position_node.scale = Vector2.ONE * lerpf(
						windup_scale, impact_scale, entry_eased
					)
					position_node.rotation = lerpf(windup_rotation, impact_rotation, entry_eased)
					entrance_offset_x = entry_slide_x * entry_slide_direction * (1.0 - entry_eased)
					entrance_offset_y = entry_lift * (1.0 - entry_eased)
				elif local_age < anticipation + entry_duration + settle_duration:
					var settle_progress: float = clampf(
						(local_age - anticipation - entry_duration) / settle_duration,
						0.0, 1.0
					)
					var settle_eased: float = 1.0 - pow(1.0 - settle_progress, 3.0)
					position_node.scale = Vector2.ONE * lerpf(impact_scale, 1.0, settle_eased)
					position_node.rotation = lerpf(impact_rotation, 0.0, settle_eased)
				else:
					var ambient_breath: float = float(part.get("ambient_breath", 0.003))
					position_node.scale = Vector2.ONE * (
						1.0 + sin(local_age * 7.0 + phase) * ambient_breath
					)
					position_node.rotation = sin(local_age * 7.0 + phase) * ambient_rotation
				position_node.position += Vector2(entrance_offset_x, entrance_offset_y)
			elif bool(part.get("points_entrance", false)):
				var points_preload_scale: float = float(part.get("points_preload_scale", 0.76))
				var points_impact_scale: float = float(part.get("points_impact_scale", 1.10))
				var points_entry_duration: float = maxf(
					float(part.get("points_entry_duration", 0.13)), 0.01
				)
				var points_settle_duration: float = maxf(
					float(part.get("points_settle_duration", 0.10)), 0.01
				)
				var points_entry_lift: float = float(part.get("points_entry_lift", 0.0))
				if local_age < points_entry_duration:
					var points_progress: float = clampf(local_age / points_entry_duration, 0.0, 1.0)
					var points_eased: float = 1.0 - pow(1.0 - points_progress, 3.0)
					label.scale = Vector2.ONE * lerpf(
						points_preload_scale, points_impact_scale, points_eased
					)
					label.position += Vector2(0.0, points_entry_lift * (1.0 - points_eased))
				elif local_age < points_entry_duration + points_settle_duration:
					var points_settle_progress: float = clampf(
						(local_age - points_entry_duration) / points_settle_duration,
						0.0, 1.0
					)
					var points_settle_eased: float = 1.0 - pow(1.0 - points_settle_progress, 3.0)
					label.scale = Vector2.ONE * lerpf(
						points_impact_scale, 1.0, points_settle_eased
					)
				else:
					label.scale = Vector2.ONE * (1.0 + sin(local_age * 8.0 + phase) * 0.004)
			else:
				var spring: float = float(part.get("spring", 0.85))
				if local_age < 0.13:
					label.scale = Vector2.ONE * lerpf(spring, 1.035, local_age / 0.13)
				elif local_age < 0.21:
					label.scale = Vector2.ONE * lerpf(1.035, 1.0, (local_age - 0.13) / 0.08)
				else:
					label.scale = Vector2.ONE * (1.0 + sin(local_age * 7.0 + phase) * 0.004)


		if age >= lifetime:
			root.queue_free()
			_active_rewards.remove_at(i)
		else:
			_active_rewards[i] = reward


func _update_floating_labels(delta: float) -> void:
	for i in range(_active_floats.size() - 1, -1, -1):
		var item: Dictionary = _active_floats[i]
		var label := item.get("label") as Label
		if label == null or not is_instance_valid(label):
			_active_floats.remove_at(i)
			continue

		var age: float = float(item.get("age", 0.0)) + delta
		item["age"] = age
		var delay: float = float(item.get("delay", 0.0))
		var lifetime: float = maxf(float(item.get("lifetime", 0.65)), 0.1)
		var local_age: float = age - delay
		if local_age < 0.0:
			label.modulate.a = 0.0
			_active_floats[i] = item
			continue

		var progress: float = clampf(local_age / lifetime, 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - progress, 2.0)
		var start_position: Vector2 = item.get("start_position", label.position)
		var phase: float = float(item.get("phase", 0.0))
		label.position = start_position + Vector2(
			float(item.get("drift_x", 20.0)) * eased + sin(local_age * 9.0 + phase) * 0.8,
			float(item.get("drift_y", -22.0)) * eased
		)
		label.rotation = float(item.get("rotation", 0.0)) * sin(local_age * 5.0 + phase)

		var alpha: float = 1.0
		if local_age < 0.08:
			alpha = local_age / 0.08
		elif local_age > lifetime * 0.45:
			alpha = 1.0 - clampf(
				(local_age - lifetime * 0.45) / maxf(lifetime * 0.55, 0.01),
				0.0,
				1.0
			)
		label.modulate.a = alpha

		if local_age < 0.12:
			label.scale = Vector2.ONE * lerpf(0.78, 1.06, local_age / 0.12)
		elif local_age < 0.20:
			label.scale = Vector2.ONE * lerpf(1.06, 1.0, (local_age - 0.12) / 0.08)
		else:
			label.scale = Vector2.ONE * (1.0 + sin(local_age * 8.0 + phase) * 0.006)

		if age >= delay + lifetime:
			label.queue_free()
			_active_floats.remove_at(i)
		else:
			_active_floats[i] = item


func _process(delta: float) -> void:
	_update_reward_animations(delta)
	_update_floating_labels(delta)
	_update_status_follow(delta)
	_update_orb_core_blend(delta)

	if _status_root == null or not _status_root.visible or not state_indicator_enabled:
		return

	_pulse_clock += delta
	_state_pop_timer = maxf(_state_pop_timer - delta, 0.0)
	if _state_pop_timer <= 0.0:
		var pulse: float = sin(_pulse_clock * 3.0)
		for label in [_combo_label, _combo_counter, _streak_label, _streak_counter]:
			if label.visible and not bool(_indicator_hiding.get(label.name, false)):
				label.modulate.a = 0.94 + pulse * 0.045
	_update_state_indicator_motion()
