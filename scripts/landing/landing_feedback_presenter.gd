extends CanvasLayer
## Presents landing rewards and persistent landing states in screen space.
## Scoring remains in LandingScoreController; this node only handles presentation.

@export_category("Reward Presentation")
@export var reward_feedback_enabled: bool = true
@export_range(0.8, 1.5, 0.05) var reward_lifetime: float = 1.15
@export_range(8.0, 36.0, 2.0) var screen_safe_margin: float = 22.0

@export_category("State Indicator")
@export var state_indicator_enabled: bool = true
@export_range(4.0, 24.0, 1.0) var state_follow_speed: float = 12.0

@export var landing_score_controller_path: NodePath = NodePath("../LandingScoreController")
@export var ball_path: NodePath = NodePath("../Ball")

const REWARD_SIZE := Vector2(164.0, 82.0)
const STATUS_SIZE := Vector2(190.0, 52.0)
const CLUTCH_SIZE := Vector2(144.0, 30.0)
const EVENT_SIZE := Vector2(188.0, 34.0)
const STATUS_SIDE_GAP := 7.0

const GOOD_COLOR := Color(0.40, 0.86, 1.0, 1.0)
const EPIC_COLOR := Color(0.72, 0.44, 1.0, 1.0)
const PERFECT_COLOR := Color(0.86, 0.98, 1.0, 1.0)
const STREAK_COLOR := Color(1.0, 0.73, 0.30, 1.0)
const SCORE_COLOR := Color(0.58, 0.94, 1.0, 1.0)
const CLUTCH_COLOR := Color(0.80, 0.96, 1.0, 1.0)
const OUTLINE_COLOR := Color(0.012, 0.025, 0.055, 0.98)

var _score_controller: Node
var _ball: Node2D

var _status_root: Control
var _chain_progress_root: Control
var _chain_segments: Array[ColorRect] = []
var _combo_label: Label
var _streak_label: Label

## The side is selected once and retained until that side no longer fits the
## viewport. The anchor sits beside the ball's trailing edge, not in a screen corner.
var _status_side: int = 0
var _status_position_initialized: bool = false

var _active_rewards: Array[Dictionary] = []
var _active_floats: Array[Dictionary] = []
var _last_state: Dictionary = {}
var _indicator_versions: Dictionary = {}
var _indicator_hiding: Dictionary = {}
var _pulse_clock: float = 0.0
var _state_pop_timer: float = 0.0


func _ready() -> void:
	_ball = get_node_or_null(ball_path) as Node2D
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

	# Before Combo activates, use a quiet three-segment progress cue instead of
	# another sentence competing with the landing reward.
	_chain_progress_root = Control.new()
	_chain_progress_root.name = "ComboProgressIndicator"
	_chain_progress_root.size = Vector2(82.0, 16.0)
	_chain_progress_root.position = Vector2(1.0, 18.0)
	_chain_progress_root.visible = false
	_chain_progress_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_root.add_child(_chain_progress_root)

	for i in range(3):
		var segment := ColorRect.new()
		segment.name = "ComboProgressSegment%d" % (i + 1)
		segment.position = Vector2(float(i) * 28.0, 5.0)
		segment.size = Vector2(21.0, 5.0)
		segment.color = Color(0.14, 0.23, 0.34, 0.88)
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_chain_progress_root.add_child(segment)
		_chain_segments.append(segment)

	_combo_label = _make_label("ComboStatusLabel", Vector2(STATUS_SIZE.x, 24.0), 16, EPIC_COLOR, 5)
	_combo_label.position = Vector2(0.0, 12.0)
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_combo_label.visible = false
	_status_root.add_child(_combo_label)

	_streak_label = _make_label("StreakStatusLabel", Vector2(STATUS_SIZE.x, 24.0), 16, STREAK_COLOR, 5)
	_streak_label.position = Vector2.ZERO
	_streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_streak_label.visible = false
	_status_root.add_child(_streak_label)


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

	# Milestones remain separate events, positioned relative to the persistent
	# indicator rather than being added to the temporary reward detail line.
	if bool(result.get("streak_activated", false)):
		_spawn_state_transition("▲  STREAK!", STREAK_COLOR)
	elif bool(result.get("combo_activated", false)):
		_spawn_state_transition("✦  COMBO!", _quality_color(str(result.get("quality", "GOOD"))))


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

	# Visual reading order stays grade -> points -> detail. The detail line
	# remains last in the cluster, but its short lifetime lets it leave first.
	var grade_label := _make_label(
		"LandingGrade", Vector2(REWARD_SIZE.x, 25.0), 19, quality_color, 5
	)
	grade_label.position = Vector2.ZERO
	grade_label.text = quality
	reward_root.add_child(grade_label)

	var points_label := _make_label(
		"LandingPoints", Vector2(REWARD_SIZE.x, 35.0), 29, SCORE_COLOR, 6
	)
	points_label.position = Vector2(0.0, 23.0)
	points_label.text = "+%d" % int(result.get("total_points", 0))
	reward_root.add_child(points_label)

	var detail_label := _make_label(
		"LandingRewardDetail", Vector2(REWARD_SIZE.x, 19.0), 12, quality_color.lightened(0.14), 3
	)
	detail_label.position = Vector2(0.0, 61.0)
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
			"fade_start": 0.60,
			"fade_duration": 0.24,
			"duration": 0.92,
			"drift_factor": 0.12,
			"rise_factor": 0.18,
			"spring": 0.84,
		},
		{
			"label": points_label,
			"base_position": points_label.position,
			"delay": 0.055,
			"fade_start": 0.80,
			"fade_duration": 0.25,
			"duration": 1.12,
			"drift_factor": 0.22,
			"rise_factor": 0.25,
			"spring": 0.76,
		},
		{
			"label": detail_label,
			"base_position": detail_label.position,
			"delay": 0.08,
			"fade_start": 0.22,
			"fade_duration": 0.20,
			"duration": 0.46,
			"drift_factor": 0.42,
			"rise_factor": 0.12,
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
	var quality: String = str(result.get("quality", "GOOD"))
	var chain_count: int = int(result.get("chain_count", 0))
	var activation_count: int = int(_last_state.get("combo_activation_landings", 3))

	# Chain progress stays in the reward's small detail line. The separate,
	# locally anchored activation label communicates Combo/Streak transitions.
	if bool(result.get("combo_active", false)) or bool(result.get("streak_active", false)):
		return "%s CHAIN  ·  %d" % [quality, chain_count]
	return "%s CHAIN  ·  %d/%d" % [quality, chain_count, activation_count]


func _choose_reward_start(
	anchor: Vector2,
	viewport_size: Vector2,
	ball_radius: float,
	preferred_side: int
) -> Vector2:
	# Keep the reward beside the landing. This is a two-side local choice only:
	# no screen-wide search and no later repositioning while it animates.
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

	var x: float
	if chosen_side > 0:
		x = anchor.x + ball_radius + 7.0
	else:
		x = anchor.x - ball_radius - 7.0 - REWARD_SIZE.x

	var y: float = anchor.y - 42.0
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
		requested_y = edge_screen.y + 5.0

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
		0.66,
		clutch_drift_direction * 22.0,
		-12.0,
		0.008,
		38,
		0.0
	)
	if clutch_label != null:
		clutch_label.z_index = 36


func _spawn_state_transition(label_text: String, color: Color) -> void:
	if not state_indicator_enabled:
		return

	var viewport_size: Vector2 = _get_viewport_size()
	var ball_screen: Vector2 = _get_ball_screen_position()
	var status_position: Vector2 = (
		_status_root.position
		if _status_position_initialized
		else _get_status_target(ball_screen, viewport_size)
	)
	var requested := Vector2(
		status_position.x,
		status_position.y - EVENT_SIZE.y - 6.0
	)
	var start := _fit_local_position(requested, EVENT_SIZE, viewport_size)
	_spawn_floating_label(
		label_text,
		color,
		23,
		EVENT_SIZE,
		start,
		0.68,
		float(_status_side if _status_side != 0 else 1) * 18.0,
		-24.0,
		0.01,
		40,
		0.0
	)


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


func _get_status_target(ball_screen: Vector2, viewport_size: Vector2) -> Vector2:
	var radius: float = _get_ball_radius()
	var right_x: float = ball_screen.x + radius + STATUS_SIDE_GAP
	var left_x: float = ball_screen.x - radius - STATUS_SIDE_GAP - STATUS_SIZE.x
	var right_fits: bool = right_x + STATUS_SIZE.x <= viewport_size.x - screen_safe_margin
	var left_fits: bool = left_x >= screen_safe_margin

	# Pick a nearby side once. After that, only change side if it actually
	# runs out of viewport space; crossing the screen midpoint does nothing.
	if _status_side == 0:
		if right_fits:
			_status_side = 1
		elif left_fits:
			_status_side = -1
		else:
			var right_room: float = viewport_size.x - screen_safe_margin - right_x
			var left_room: float = left_x - screen_safe_margin
			_status_side = 1 if right_room >= left_room else -1
	elif _status_side > 0 and not right_fits and left_fits:
		_status_side = -1
	elif _status_side < 0 and not left_fits and right_fits:
		_status_side = 1

	var x: float = right_x if _status_side > 0 else left_x
	# This fixed trailing-side offset keeps the status connected to the comet.
	# It only clamps when the ball is genuinely near a viewport boundary.
	var y: float = ball_screen.y + radius * 0.42
	return _fit_local_position(Vector2(x, y), STATUS_SIZE, viewport_size)


func _update_status_follow(delta: float) -> void:
	if _status_root == null or not _status_root.visible or not state_indicator_enabled:
		return

	var viewport_size: Vector2 = _get_viewport_size()
	var ball_screen: Vector2 = _get_ball_screen_position()
	var target_position: Vector2 = _get_status_target(ball_screen, viewport_size)
	if not _status_position_initialized:
		_status_root.position = target_position
		_status_position_initialized = true
	else:
		var follow_weight: float = 1.0 - exp(-state_follow_speed * delta)
		_status_root.position = _status_root.position.lerp(target_position, follow_weight)


func _on_combo_state_changed(state: Dictionary) -> void:
	if not state_indicator_enabled or _status_root == null:
		return

	var previous_chain_count: int = int(_last_state.get("chain_count", 0))
	var previous_combo_active: bool = bool(_last_state.get("combo_active", false))
	var previous_streak_active: bool = bool(_last_state.get("streak_active", false))
	_last_state = state.duplicate(true)

	var chain_count: int = int(state.get("chain_count", 0))
	if chain_count <= 0:
		_chain_progress_root.visible = false
		_hide_indicator(_combo_label)
		_hide_indicator(_streak_label)
		_status_root.visible = false
		_status_position_initialized = false
		return

	var quality: String = str(state.get("quality", "GOOD"))
	var combo_active: bool = bool(state.get("combo_active", false))
	var streak_active: bool = bool(state.get("streak_active", false))
	var multiplier: float = float(state.get("multiplier", 1.0))
	var quality_color: Color = _quality_color(quality)

	_status_root.visible = true
	_chain_progress_root.visible = not combo_active
	var filled_segments: int = mini(chain_count, _chain_segments.size())
	for i in range(_chain_segments.size()):
		var segment := _chain_segments[i]
		segment.color = quality_color if i < filled_segments else Color(0.14, 0.23, 0.34, 0.88)

	if combo_active:
		_set_indicator(
			_combo_label,
			"✦  %s COMBO  ×%.2f" % [quality, multiplier],
			quality_color,
			not previous_combo_active
		)
	else:
		_hide_indicator(_combo_label)

	if streak_active:
		# STREAK owns the primary line once it activates; Combo and its
		# multiplier remain available below it as the secondary state.
		_streak_label.position = Vector2(0.0, 0.0)
		_combo_label.position = Vector2(0.0, 25.0)
		_set_indicator(
			_streak_label,
			"▲  STREAK  %02d" % chain_count,
			STREAK_COLOR,
			not previous_streak_active
		)
	else:
		_combo_label.position = Vector2(0.0, 12.0)
		_streak_label.position = Vector2.ZERO
		_hide_indicator(_streak_label)

	if (combo_active and not previous_combo_active) or (streak_active and not previous_streak_active):
		_state_pop_timer = 0.30
	elif previous_chain_count != chain_count:
		_state_pop_timer = 0.24


func _set_indicator(label: Label, text_value: String, color: Color, animate: bool) -> void:
	if label == null:
		return

	var was_visible: bool = label.visible
	var was_hiding: bool = bool(_indicator_hiding.get(label.name, false))
	var text_changed: bool = label.text != text_value
	label.text = text_value
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override(
		"font_shadow_color",
		Color(color.r, color.g, color.b, 0.38)
	)
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

	label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	label.scale = Vector2.ONE * 0.82

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, 0.12)
	tween.tween_property(label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
			-20.0 * eased + sin(age * 5.0 + phase) * 1.0
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
			var part_rise: float = 11.0 * float(part.get("rise_factor", 0.5))
			var part_flutter: float = sin(local_age * 9.0 + phase) * 1.0 * (1.0 - part_progress)
			label.position = base_position + Vector2(
				part_drift * part_eased + part_flutter,
				-part_rise * part_eased
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

	if _status_root == null or not _status_root.visible or not state_indicator_enabled:
		return

	_pulse_clock += delta
	_state_pop_timer = maxf(_state_pop_timer - delta, 0.0)
	if _state_pop_timer <= 0.0:
		var pulse: float = sin(_pulse_clock * 3.0)
		for label in [_combo_label, _streak_label]:
			if label.visible and not bool(_indicator_hiding.get(label.name, false)):
				label.scale = Vector2.ONE * (1.0 + pulse * 0.008)
				label.modulate.a = 0.94 + pulse * 0.045
