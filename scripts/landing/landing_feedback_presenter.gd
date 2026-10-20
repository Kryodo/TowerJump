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

const REWARD_SIZE := Vector2(224.0, 86.0)
const STATUS_SIZE := Vector2(270.0, 60.0)
const CLUTCH_SIZE := Vector2(168.0, 34.0)
const EVENT_SIZE := Vector2(212.0, 38.0)
const STATUS_SIDE_GAP := 14.0
const BALL_CLEARANCE := 14.0

const GOOD_COLOR := Color(0.40, 0.86, 1.0, 1.0)
const EPIC_COLOR := Color(0.72, 0.44, 1.0, 1.0)
const PERFECT_COLOR := Color(0.86, 0.98, 1.0, 1.0)
const STREAK_COLOR := Color(1.0, 0.73, 0.30, 1.0)
const SCORE_COLOR := Color(0.58, 0.94, 1.0, 1.0)
const CLUTCH_COLOR := Color(1.0, 0.67, 0.31, 1.0)
const OUTLINE_COLOR := Color(0.012, 0.025, 0.055, 0.98)

var _score_controller: Node
var _ball: Node2D

var _status_root: Control
var _chain_label: Label
var _combo_label: Label
var _streak_label: Label

## Side is locked while there's enough local room: +1 means right of the ball,
## -1 means left. Vertical mode changes only when the current mode hits an edge.
var _status_side: int = 0
var _status_vertical: int = -1
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

	_chain_label = _make_label("ChainStatusLabel", Vector2(STATUS_SIZE.x, 28.0), 16, GOOD_COLOR, 4)
	_chain_label.position = Vector2.ZERO
	_chain_label.visible = false
	_status_root.add_child(_chain_label)

	_combo_label = _make_label("ComboStatusLabel", Vector2(STATUS_SIZE.x, 28.0), 18, EPIC_COLOR, 5)
	_combo_label.position = Vector2.ZERO
	_combo_label.visible = false
	_status_root.add_child(_combo_label)

	_streak_label = _make_label("StreakStatusLabel", Vector2(STATUS_SIZE.x, 26.0), 17, STREAK_COLOR, 5)
	_streak_label.position = Vector2(0.0, 30.0)
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

	if reward_feedback_enabled:
		_spawn_landing_reward(result, platform)

	if bool(result.get("clutch", false)):
		_spawn_clutch_feedback(result, platform)

	# Milestones are separate events, not another line underneath every reward.
	if bool(result.get("streak_activated", false)):
		_spawn_state_transition("▲  STREAK!", STREAK_COLOR)
	elif bool(result.get("combo_activated", false)):
		_spawn_state_transition("✦  COMBO!", _quality_color(str(result.get("quality", "GOOD"))))


func _spawn_landing_reward(result: Dictionary, platform: Node2D) -> void:
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

	var detail_label := _make_label(
		"LandingRewardDetail", Vector2(REWARD_SIZE.x, 20.0), 13, quality_color.lightened(0.14), 3
	)
	detail_label.position = Vector2.ZERO
	detail_label.text = detail_text
	reward_root.add_child(detail_label)

	var grade_label := _make_label(
		"LandingGrade", Vector2(REWARD_SIZE.x, 28.0), 21, quality_color, 5
	)
	grade_label.position = Vector2(0.0, 19.0)
	grade_label.text = quality
	reward_root.add_child(grade_label)

	var points_label := _make_label(
		"LandingPoints", Vector2(REWARD_SIZE.x, 38.0), 32, SCORE_COLOR, 6
	)
	points_label.position = Vector2(0.0, 46.0)
	points_label.text = "+%d" % int(result.get("total_points", 0))
	reward_root.add_child(points_label)

	var start_position: Vector2 = _choose_reward_start(screen_anchor, viewport_size, ball_radius)
	reward_root.position = start_position

	var center_x: float = start_position.x + REWARD_SIZE.x * 0.5
	var drift_direction: float = signf(center_x - screen_anchor.x)
	if is_zero_approx(drift_direction):
		drift_direction = 1.0 if screen_anchor.x < viewport_size.x * 0.5 else -1.0
	if center_x < screen_safe_margin + REWARD_SIZE.x * 0.5 + 42.0:
		drift_direction = 1.0
	elif center_x > viewport_size.x - screen_safe_margin - REWARD_SIZE.x * 0.5 - 42.0:
		drift_direction = -1.0

	var parts: Array[Dictionary] = [
		{
			"label": detail_label,
			"base_position": detail_label.position,
			"delay": 0.0,
			"fade_start": 0.20,
			"fade_duration": 0.18,
			"duration": 0.42,
			"drift_factor": 0.65,
			"rise_factor": 0.70,
			"spring": 0.90,
		},
		{
			"label": grade_label,
			"base_position": grade_label.position,
			"delay": 0.045,
			"fade_start": 0.56,
			"fade_duration": 0.22,
			"duration": 0.82,
			"drift_factor": 0.28,
			"rise_factor": 0.30,
			"spring": 0.82,
		},
		{
			"label": points_label,
			"base_position": points_label.position,
			"delay": 0.105,
			"fade_start": 0.76,
			"fade_duration": 0.24,
			"duration": 1.10,
			"drift_factor": 0.58,
			"rise_factor": 0.52,
			"spring": 0.72,
		},
	]

	_active_rewards.append({
		"root": reward_root,
		"parts": parts,
		"start_position": start_position,
		"anchor": screen_anchor,
		"age": 0.0,
		"lifetime": maxf(reward_lifetime, 0.8),
		"drift_x": drift_direction * randf_range(16.0, 24.0),
		"phase": randf_range(0.0, TAU),
	})


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
	ball_radius: float
) -> Vector2:
	var safe_y: float = screen_safe_margin
	var desired_y: float = anchor.y - REWARD_SIZE.y - 8.0
	if desired_y < safe_y:
		# At the top edge, keep the reward beside the contact point rather than
		# pinning it to the top of the screen.
		desired_y = anchor.y + ball_radius + 6.0
	desired_y = clampf(desired_y, safe_y, viewport_size.y - safe_y - REWARD_SIZE.y)

	var preferred_offset: float = -float(_status_side) * 64.0 if _status_side != 0 else (
		56.0 if anchor.x < viewport_size.x * 0.5 else -56.0
	)
	var candidates: Array[Vector2] = [
		Vector2(anchor.x - REWARD_SIZE.x * 0.5 + preferred_offset, desired_y),
		Vector2(anchor.x - REWARD_SIZE.x * 0.5 - preferred_offset, desired_y),
	]
	var ball_rect := Rect2(
		anchor - Vector2(ball_radius + BALL_CLEARANCE, ball_radius + BALL_CLEARANCE),
		Vector2((ball_radius + BALL_CLEARANCE) * 2.0, (ball_radius + BALL_CLEARANCE) * 2.0)
	)
	var obstacles: Array[Rect2] = [ball_rect]
	if _status_root != null and _status_root.visible and _status_position_initialized:
		obstacles.append(Rect2(_status_root.position, STATUS_SIZE))
	obstacles.append_array(_get_visible_hud_rects())

	var best_position: Vector2 = _fit_local_position(candidates[0], REWARD_SIZE, viewport_size)
	var best_cost: float = INF
	for requested in candidates:
		var fitted: Vector2 = _fit_local_position(requested, REWARD_SIZE, viewport_size)
		var reward_rect := Rect2(fitted, REWARD_SIZE)
		var cost: float = requested.distance_to(fitted) * 3.0
		cost += _rect_overlap_area(reward_rect, ball_rect) * 0.55
		for obstacle in obstacles:
			cost += _rect_overlap_area(reward_rect, obstacle) * 0.40
		if cost < best_cost:
			best_cost = cost
			best_position = fitted

	return best_position


func _spawn_clutch_feedback(result: Dictionary, platform: Node2D) -> void:
	var half_width: float = 110.0
	if platform.has_method("half_width"):
		half_width = maxf(float(platform.call("half_width")), 1.0)
	else:
		var width_value: Variant = platform.get("width")
		if width_value != null:
			half_width = maxf(float(width_value) * 0.5, 1.0)

	var landing_x: float = float(result.get("landing_world_x", platform.global_position.x))
	var landing_side: float = signf(landing_x - platform.global_position.x)
	if is_zero_approx(landing_side):
		landing_side = 1.0 if landing_x < _get_viewport_size().x * 0.5 else -1.0

	var world_edge := Vector2(
		platform.global_position.x + landing_side * half_width,
		platform.global_position.y - _get_platform_height(platform) * 0.5
	)
	var edge_screen: Vector2 = get_viewport().get_canvas_transform() * world_edge
	var viewport_size: Vector2 = _get_viewport_size()
	var place_left: bool = edge_screen.x > viewport_size.x * 0.5
	var requested_x: float = edge_screen.x - CLUTCH_SIZE.x + 8.0 if place_left else edge_screen.x - 8.0
	var requested_y: float = edge_screen.y - _get_ball_radius() - CLUTCH_SIZE.y
	var start := _fit_local_position(
		Vector2(requested_x, requested_y),
		CLUTCH_SIZE,
		viewport_size
	)
	var text := _spawn_floating_label(
		"✦  CLUTCH +%d" % int(result.get("clutch_bonus", 0)),
		CLUTCH_COLOR,
		19,
		CLUTCH_SIZE,
		start,
		0.66,
		-landing_side * 26.0,
		-22.0,
		0.015,
		38,
		0.0
	)
	if text != null:
		text.z_index = 36


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
	if _status_side == 0:
		_status_side = 1 if ball_screen.x < viewport_size.x * 0.5 else -1

	var radius: float = _get_ball_radius()
	var left_x: float = ball_screen.x - radius - STATUS_SIDE_GAP - STATUS_SIZE.x
	var right_x: float = ball_screen.x + radius + STATUS_SIDE_GAP

	# Switch sides only when the selected local position actually runs out of
	# room. The gap between these thresholds prevents side-flipping jitter.
	if _status_side > 0 and right_x + STATUS_SIZE.x > viewport_size.x - screen_safe_margin:
		_status_side = -1
	elif _status_side < 0 and left_x < screen_safe_margin:
		_status_side = 1

	var x: float = right_x if _status_side > 0 else left_x
	var above_y: float = ball_screen.y - radius - STATUS_SIZE.y - 12.0
	var below_y: float = ball_screen.y + radius + 12.0

	if _status_vertical < 0 and above_y < screen_safe_margin:
		_status_vertical = 1
	elif _status_vertical > 0 and below_y + STATUS_SIZE.y > viewport_size.y - screen_safe_margin:
		_status_vertical = -1

	var y: float = above_y if _status_vertical < 0 else below_y
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
		_hide_indicator(_chain_label)
		_hide_indicator(_combo_label)
		_hide_indicator(_streak_label)
		_status_root.visible = false
		_status_position_initialized = false
		return

	var quality: String = str(state.get("quality", "GOOD"))
	var combo_active: bool = bool(state.get("combo_active", false))
	var streak_active: bool = bool(state.get("streak_active", false))
	var multiplier: float = float(state.get("multiplier", 1.0))
	var activation_count: int = int(state.get("combo_activation_landings", 3))

	_status_root.visible = true
	if combo_active:
		_hide_indicator(_chain_label)
	else:
		_set_indicator(
			_chain_label,
			"%s CHAIN  ·  %d/%d" % [quality, chain_count, activation_count],
			_quality_color(quality),
			previous_chain_count != chain_count or previous_combo_active
		)

	if combo_active:
		_set_indicator(
			_combo_label,
			"✦  %s COMBO  ×%.2f" % [quality, multiplier],
			_quality_color(quality),
			not previous_combo_active
		)
	else:
		_hide_indicator(_combo_label)

	if streak_active:
		_set_indicator(
			_streak_label,
			"▲  STREAK  %02d" % chain_count,
			STREAK_COLOR,
			not previous_streak_active
		)
	else:
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


func _get_visible_hud_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var hud_paths: Array[NodePath] = [
		NodePath("../HUD/ScoreLabel"),
		NodePath("../HUD/CoinLabel"),
		NodePath("../HUD/DebugSectionLabel"),
	]
	for hud_path in hud_paths:
		var hud_control := get_node_or_null(hud_path) as Control
		if hud_control == null or not hud_control.is_visible_in_tree():
			continue
		if hud_control.modulate.a <= 0.08:
			continue
		rects.append(hud_control.get_global_rect())
	return rects


func _fit_local_position(position: Vector2, element_size: Vector2, viewport_size: Vector2) -> Vector2:
	var max_x: float = maxf(screen_safe_margin, viewport_size.x - screen_safe_margin - element_size.x)
	var max_y: float = maxf(screen_safe_margin, viewport_size.y - screen_safe_margin - element_size.y)
	return Vector2(
		clampf(position.x, screen_safe_margin, max_x),
		clampf(position.y, screen_safe_margin, max_y)
	)


func _rect_overlap_area(first: Rect2, second: Rect2) -> float:
	if not first.intersects(second):
		return 0.0
	var overlap: Rect2 = first.intersection(second)
	return maxf(overlap.size.x, 0.0) * maxf(overlap.size.y, 0.0)


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
		for label in [_chain_label, _combo_label, _streak_label]:
			if label.visible and not bool(_indicator_hiding.get(label.name, false)):
				label.scale = Vector2.ONE * (1.0 + pulse * 0.008)
				label.modulate.a = 0.94 + pulse * 0.045
