extends CanvasLayer
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

const REWARD_SIZE := Vector2(160.0, 66.0)
const STATUS_SIZE := Vector2(184.0, 52.0)
const CLUTCH_SIZE := Vector2(144.0, 30.0)

const STREAK_COLOR := Color(1.0, 0.73, 0.30, 1.0)
const SCORE_COLOR := Color(0.58, 0.94, 1.0, 1.0)
const CLUTCH_COLOR := Color(0.80, 0.96, 1.0, 1.0)
const OUTLINE_COLOR := Color(0.012, 0.025, 0.055, 0.98)

var _score_controller: Node
var _zone_palette: ZoneFeedbackPalette
var _ball: Node2D
var _orb_visual: Sprite2D

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
var _combo_visual_tier: int = -1
var _streak_visual_tier: int = -1


func _ready() -> void:
	_zone_palette = ZonePaletteManager.current_palette
	_ball = get_node_or_null(ball_path) as Node2D
	_orb_visual = get_node_or_null(orb_visual_path) as Sprite2D
	_score_controller = get_node_or_null(landing_score_controller_path)
	_apply_zone_palette_to_orb()
	_create_state_indicators()
	if not ZonePaletteManager.palette_changed.is_connected(_on_zone_palette_changed):
		ZonePaletteManager.palette_changed.connect(_on_zone_palette_changed)

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
		"ComboStatusLabel", Vector2(84.0, 26.0), 15, _zone_palette.epic_color, 4
	)
	_combo_label.position = Vector2(0.0, 13.0)
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_combo_label.visible = false
	_status_root.add_child(_combo_label)

	_combo_counter = _make_label(
		"ComboMultiplierCounter", Vector2(100.0, 28.0), 20, _zone_palette.epic_color, 3
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
	var detail_text: String = _build_reward_detail(result)

	var reward_root := Control.new()
	reward_root.name = "LandingReward"
	reward_root.size = REWARD_SIZE
	reward_root.pivot_offset = REWARD_SIZE * 0.5
	reward_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_root.z_index = 30
	add_child(reward_root)

	# The detail remains the last visual row, but the quality-chain progress is
	# communicated by the orb's segmented core ring.
	var grade_label := _make_label(
		"LandingGrade", Vector2(REWARD_SIZE.x, 22.0), 19, quality_color, 5
	)
	grade_label.position = Vector2.ZERO
	grade_label.text = quality
	reward_root.add_child(grade_label)

	var points_label := _make_label(
		"LandingPoints", Vector2(REWARD_SIZE.x, 30.0), 29, SCORE_COLOR, 6
	)
	points_label.position = Vector2(0.0, 19.0)
	points_label.text = "+%d" % int(result.get("total_points", 0))
	reward_root.add_child(points_label)

	var detail_label := _make_label(
		"LandingRewardDetail", Vector2(REWARD_SIZE.x, 18.0), 12, _zone_palette.reward_detail_color, 0
	)
	detail_label.add_theme_color_override("font_color", _zone_palette.reward_detail_color)
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
			"base_position": grade_label.position,
			"delay": 0.0,
			"fade_start": 0.48,
			"fade_duration": 0.22,
			"duration": 0.78,
			"drift_factor": 0.10,
			"drop_factor": 0.18,
			"spring": 0.84,
		},
		{
			"label": points_label,
			"base_position": points_label.position,
			"delay": 0.05,
			"fade_start": 0.73,
			"fade_duration": 0.23,
			"duration": 1.02,
			"drift_factor": 0.20,
			"drop_factor": 0.28,
			"spring": 0.76,
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


func _choose_status_anchor_side(ball_screen: Vector2, viewport_size: Vector2) -> int:
	var radius: float = _get_ball_radius()
	var gap: float = 8.0
	var left_space: float = ball_screen.x - radius - gap - screen_safe_margin
	var right_space: float = viewport_size.x - screen_safe_margin - (ball_screen.x + radius + gap)
	if right_space >= STATUS_SIZE.x and left_space < STATUS_SIZE.x:
		return 1
	if left_space >= STATUS_SIZE.x and right_space < STATUS_SIZE.x:
		return -1
	# When both sides fit, place the tag on the inboard shoulder.
	return 1 if ball_screen.x < viewport_size.x * 0.5 else -1


func _get_status_target(ball_screen: Vector2, viewport_size: Vector2) -> Vector2:
	var radius: float = _get_ball_radius()
	var gap: float = 8.0
	var x: float = (
		ball_screen.x + radius + gap
		if _status_anchor_side > 0
		else ball_screen.x - radius - gap - STATUS_SIZE.x
	)
	# The tag sits beside the upper shoulder, never directly above the core.
	var y: float = ball_screen.y - radius * 0.62 - STATUS_SIZE.y * 0.50
	# Keep the horizontal shoulder anchor honest: clipping/fading is better than
	# clamping the tag over the orb when the selected side has limited room.
	var max_y: float = maxf(screen_safe_margin, viewport_size.y - screen_safe_margin - STATUS_SIZE.y)
	return Vector2(x, clampf(y, screen_safe_margin, max_y))


func _get_status_edge_visibility(ball_screen: Vector2, viewport_size: Vector2) -> float:
	var radius: float = _get_ball_radius()
	var gap: float = 8.0
	var available: float
	if _status_anchor_side > 0:
		available = viewport_size.x - screen_safe_margin - (ball_screen.x + radius + gap)
	else:
		available = ball_screen.x - radius - gap - screen_safe_margin
	return clampf(available / STATUS_SIZE.x, 0.0, 1.0)


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
			_layout_status_row(_combo_label, _combo_counter, 25.0 if bool(_last_state.get("streak_active", false)) else 13.0, 24.0 if bool(_last_state.get("streak_active", false)) else 11.0)
			_layout_status_row(_streak_label, _streak_counter, 0.0, -2.0)
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
	# Mirror the text arrangement too: the numeric value remains closest to the
	# orb, at the same gap, whether the status is attached to the left or right.
	if _status_anchor_side > 0:
		caption.position = Vector2(0.0, caption_y)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		counter.position = Vector2(84.0, counter_y)
		counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		counter.position = Vector2(0.0, counter_y)
		counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		caption.position = Vector2(100.0, caption_y)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _apply_zone_palette_to_orb() -> void:
	if _zone_palette == null or _orb_visual == null or not is_instance_valid(_orb_visual):
		return
	var material := _orb_visual.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("active_quality_color", _zone_palette.good_color)
	material.set_shader_parameter("zone_confirmation_color", _zone_palette.confirmation_color)


func _on_zone_palette_changed(palette: ZoneFeedbackPalette) -> void:
	if palette == null:
		return
	_zone_palette = palette
	_apply_zone_palette_to_orb()
	if not _last_state.is_empty():
		_on_combo_state_changed(_last_state)


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
	if combo_just_activated:
		_orb_core_activation_flash = 1.0
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
	var quality_color: Color = _quality_color(quality)
	if not _status_root.visible:
		_status_anchor_side = _choose_status_anchor_side(
			_get_ball_screen_position(),
			_get_viewport_size()
		)
		_status_position_initialized = false
		_last_ball_screen_position = _get_ball_screen_position()
	_status_root.visible = true

	# Streak occupies the first row; Combo shifts down when both states are active.
	_layout_status_row(_combo_label, _combo_counter, 25.0 if streak_active else 13.0, 24.0 if streak_active else 11.0)
	_layout_status_row(_streak_label, _streak_counter, 0.0, -2.0)

	var combo_tier_up: bool = false
	var streak_tier_up: bool = false
	var combo_tier: int = -1
	var streak_tier: int = -1
	var streak_activation_count: int = int(state.get("streak_activation_landings", 10))

	if combo_active:
		var combo_intensity: float = _get_combo_visual_intensity(multiplier, quality)
		combo_tier = _get_visual_tier(combo_intensity)
		combo_tier_up = previous_combo_active and combo_tier > previous_combo_tier
		_apply_counter_intensity(_combo_counter, combo_intensity, 20, 9)
		_set_indicator(_combo_label, "✦  COMBO", quality_color, combo_just_activated)
		var combo_counter_color: Color = quality_color.lerp(Color.WHITE, 0.08)
		_set_counter_indicator(
			_combo_counter, "×%.2f" % multiplier, combo_counter_color, combo_just_activated
		)
		if previous_combo_active and multiplier > previous_multiplier + 0.001:
			_animate_counter_change(_combo_counter, combo_intensity, combo_tier_up, combo_counter_color)
	else:
		_hide_indicator(_combo_label)
		_hide_indicator(_combo_counter)
		_combo_visual_tier = -1

	if streak_active:
		var streak_intensity: float = _get_streak_visual_intensity(
			chain_count, streak_activation_count
		)
		streak_tier = _get_visual_tier(streak_intensity)
		streak_tier_up = previous_streak_active and streak_tier > previous_streak_tier
		_apply_counter_intensity(_streak_counter, streak_intensity, 20, 9)
		_set_indicator(_streak_label, "▲  STREAK", STREAK_COLOR, streak_just_activated)
		var streak_counter_color: Color = STREAK_COLOR.lerp(Color.WHITE, 0.08)
		_set_counter_indicator(
			_streak_counter, "%02d" % chain_count, streak_counter_color, streak_just_activated
		)
		if previous_streak_active and chain_count > previous_chain_count:
			_animate_counter_change(_streak_counter, streak_intensity, streak_tier_up, streak_counter_color)
	else:
		_hide_indicator(_streak_label)
		_hide_indicator(_streak_counter)
		_streak_visual_tier = -1

	if combo_active:
		_combo_visual_tier = combo_tier
	if streak_active:
		_streak_visual_tier = streak_tier

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

	material.set_shader_parameter(
		"quality_chain_progress",
		clampf(float(chain_count), 0.0, 3.0)
	)
	material.set_shader_parameter("quality_chain", quality_id)
	if _zone_palette != null:
		# One active palette color now drives both the segmented ring and the
		# combo core, preventing their quality hues from drifting apart.
		material.set_shader_parameter("active_quality_color", _zone_palette.quality_color(quality))
		material.set_shader_parameter("zone_confirmation_color", _zone_palette.confirmation_color)
	if combo_active:
		# Preserve the last active grade while its core tint eases back out on a break.
		material.set_shader_parameter("combo_core_quality", quality_id)
		_orb_core_blend_target = 1.0
	else:
		_orb_core_blend_target = 0.0

func _update_orb_core_blend(delta: float) -> void:
	if _orb_visual == null or not is_instance_valid(_orb_visual):
		return
	var material := _orb_visual.material as ShaderMaterial
	if material == null:
		return
	var weight: float = 1.0 - exp(-8.0 * delta)
	_orb_core_blend = lerpf(_orb_core_blend, _orb_core_blend_target, weight)
	_orb_core_activation_flash *= exp(-4.2 * delta)
	material.set_shader_parameter("combo_core_blend", _orb_core_blend)
	material.set_shader_parameter("combo_activation_flash", _orb_core_activation_flash)

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

	var target_font_size: int = int(label.get_meta("counter_target_font_size", 20))
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
	)


func _quality_color(quality: String) -> Color:
	if _zone_palette != null:
		return _zone_palette.quality_color(quality)
	return ZonePaletteManager.current_palette.quality_color(quality)


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

			var local_age: float = age - float(part.get("delay", 0.0))
			if local_age < 0.0:
				label.modulate.a = 0.0
				continue

			var duration: float = maxf(float(part.get("duration", lifetime)), 0.1)
			var part_progress: float = clampf(local_age / duration, 0.0, 1.0)
			var part_eased: float = 1.0 - pow(1.0 - part_progress, 2.0)
			var base_position: Vector2 = part.get("base_position", label.position)
			var part_drift: float = drift_x * float(part.get("drift_factor", 1.0))
			var part_drop: float = 7.0 * float(part.get("drop_factor", 0.5))
			var part_flutter: float = sin(local_age * 9.0 + phase) * 1.0 * (1.0 - part_progress)
			label.position = base_position + Vector2(
				part_drift * part_eased + part_flutter,
				part_drop * part_eased
			)

			var alpha: float = 1.0
			if local_age < 0.07:
				alpha = local_age / 0.07
			var fade_start: float = float(part.get("fade_start", 0.7))
			var fade_duration: float = maxf(float(part.get("fade_duration", 0.2)), 0.05)
			if local_age > fade_start:
				alpha *= 1.0 - clampf((local_age - fade_start) / fade_duration, 0.0, 1.0)
			label.modulate.a = clampf(alpha, 0.0, 1.0)

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
