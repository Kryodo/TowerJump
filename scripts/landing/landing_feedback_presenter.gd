extends CanvasLayer
## Presents landing rewards and persistent landing states in screen space.
## Scoring remains in LandingScoreController; this node only handles presentation.

@export_category("Reward Presentation")
@export var reward_feedback_enabled: bool = true
@export_range(0.5, 1.5, 0.05) var reward_lifetime: float = 0.95
@export_range(8.0, 48.0, 2.0) var screen_safe_margin: float = 22.0

@export_category("State Indicator")
@export var state_indicator_enabled: bool = true
@export_range(4.0, 24.0, 1.0) var state_follow_speed: float = 14.0

@export var landing_score_controller_path: NodePath = NodePath("../LandingScoreController")
@export var ball_path: NodePath = NodePath("../Ball")

const REWARD_SIZE := Vector2(264.0, 88.0)
const STATUS_SIZE := Vector2(270.0, 58.0)
const STATUS_SIDE_GAP := 14.0
const BALL_CLEARANCE := 16.0
const HUD_TOP := 42.0

const GOOD_COLOR := Color(0.40, 0.86, 1.0, 1.0)
const EPIC_COLOR := Color(0.72, 0.44, 1.0, 1.0)
const PERFECT_COLOR := Color(0.86, 0.98, 1.0, 1.0)
const STREAK_COLOR := Color(1.0, 0.73, 0.30, 1.0)
const SCORE_COLOR := Color(0.58, 0.94, 1.0, 1.0)
const OUTLINE_COLOR := Color(0.012, 0.025, 0.055, 0.98)

var _score_controller: Node
var _ball: Node2D

var _status_root: Control
var _chain_label: Label
var _combo_label: Label
var _streak_label: Label

var _active_rewards: Array[Dictionary] = []
var _last_state: Dictionary = {}
var _indicator_versions: Dictionary = {}
var _indicator_hiding: Dictionary = {}
var _pulse_clock: float = 0.0
var _state_pop_timer: float = 0.0
var _status_position_initialized: bool = false


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

	_chain_label = _make_label(
		"ChainStatusLabel",
		Vector2(STATUS_SIZE.x, 28.0),
		16,
		GOOD_COLOR,
		4
	)
	_chain_label.position = Vector2.ZERO
	_chain_label.visible = false
	_status_root.add_child(_chain_label)

	_combo_label = _make_label(
		"ComboStatusLabel",
		Vector2(STATUS_SIZE.x, 28.0),
		18,
		EPIC_COLOR,
		5
	)
	_combo_label.position = Vector2.ZERO
	_combo_label.visible = false
	_status_root.add_child(_combo_label)

	_streak_label = _make_label(
		"StreakStatusLabel",
		Vector2(STATUS_SIZE.x, 26.0),
		17,
		STREAK_COLOR,
		5
	)
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
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
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
	if not reward_feedback_enabled:
		return

	var platform := result.get("platform") as Node2D
	if platform == null or not is_instance_valid(platform):
		return

	_spawn_landing_reward(result, platform)


func _spawn_landing_reward(result: Dictionary, platform: Node2D) -> void:
	var radius: float = _get_ball_radius()
	var platform_height_value: Variant = platform.get("height")
	var platform_height: float = (
		float(platform_height_value)
		if platform_height_value != null
		else 20.0
	)
	var contact_y: float = platform.global_position.y - platform_height * 0.5
	var landing_x: float = float(result.get("landing_world_x", platform.global_position.x))
	var world_anchor := Vector2(landing_x, contact_y - radius)
	var screen_anchor: Vector2 = get_viewport().get_canvas_transform() * world_anchor

	var quality: String = str(result.get("quality", "GOOD"))
	var quality_color: Color = _quality_color(quality)
	var detail_text: String = _build_reward_detail(result)

	var reward_root := Control.new()
	reward_root.name = "LandingReward"
	reward_root.size = REWARD_SIZE
	reward_root.pivot_offset = REWARD_SIZE * 0.5
	reward_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_root.z_index = 30
	reward_root.modulate = Color.WHITE
	add_child(reward_root)

	var grade_label := _make_label(
		"LandingGrade",
		Vector2(REWARD_SIZE.x, 26.0),
		21,
		quality_color,
		5
	)
	grade_label.position = Vector2.ZERO
	grade_label.text = quality
	reward_root.add_child(grade_label)

	var points_label := _make_label(
		"LandingPoints",
		Vector2(REWARD_SIZE.x, 38.0),
		32,
		SCORE_COLOR,
		6
	)
	points_label.position = Vector2(0.0, 25.0)
	points_label.text = "+%d" % int(result.get("total_points", 0))
	reward_root.add_child(points_label)

	var detail_label := _make_label(
		"LandingRewardDetail",
		Vector2(REWARD_SIZE.x, 22.0),
		13,
		quality_color.lightened(0.14),
		3
	)
	detail_label.position = Vector2(0.0, 64.0)
	detail_label.text = detail_text
	detail_label.visible = not detail_text.is_empty()
	detail_label.modulate.a = 1.0
	reward_root.add_child(detail_label)

	var start_position: Vector2 = _choose_reward_position(
		screen_anchor,
		REWARD_SIZE,
		radius
	)
	reward_root.position = start_position

	var drift_direction: float = 1.0 if start_position.x >= screen_anchor.x else -1.0
	if absf(start_position.x + REWARD_SIZE.x * 0.5 - screen_anchor.x) < REWARD_SIZE.x * 0.36:
		drift_direction = 1.0 if screen_anchor.x < _get_viewport_size().x * 0.5 else -1.0

	_active_rewards.append({
		"root": reward_root,
		"grade_label": grade_label,
		"points_label": points_label,
		"detail_label": detail_label,
		"points_start": points_label.position,
		"start_position": start_position,
		"age": 0.0,
		"lifetime": maxf(reward_lifetime, 0.5),
		"drift_x": drift_direction * randf_range(10.0, 18.0),
		"phase": randf_range(0.0, TAU),
		"rotation": randf_range(-0.018, 0.018),
	})


func _build_reward_detail(result: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var quality: String = str(result.get("quality", "GOOD"))

	if bool(result.get("streak_activated", false)):
		parts.append("STREAK BONUS +%d" % int(result.get("streak_bonus", 0)))
	elif bool(result.get("combo_activated", false)):
		parts.append("COMBO ACTIVATED")
	elif bool(result.get("streak_active", false)):
		parts.append("STREAK  ·  %d" % int(result.get("chain_count", 0)))
	elif bool(result.get("combo_active", false)):
		parts.append("%s COMBO  ×%.2f" % [
			quality,
			float(result.get("multiplier", 1.0))
		])
	else:
		parts.append("%s CHAIN  %d/%d" % [
			quality,
			int(result.get("chain_count", 0)),
			int(_last_state.get("combo_activation_landings", 3))
		])

	if bool(result.get("clutch", false)):
		parts.append("CLUTCH +%d" % int(result.get("clutch_bonus", 0)))

	return "  ·  ".join(parts)


func _choose_reward_position(
	anchor: Vector2,
	element_size: Vector2,
	ball_radius: float
) -> Vector2:
	var viewport_size: Vector2 = _get_viewport_size()
	var side_gap: float = ball_radius + BALL_CLEARANCE
	var candidates: Array[Vector2] = [
		Vector2(anchor.x + side_gap, anchor.y - element_size.y - 16.0),
		Vector2(anchor.x - element_size.x - side_gap, anchor.y - element_size.y - 16.0),
		Vector2(anchor.x + side_gap, anchor.y - element_size.y * 0.56),
		Vector2(anchor.x - element_size.x - side_gap, anchor.y - element_size.y * 0.56),
		Vector2(anchor.x - element_size.x * 0.5, anchor.y - element_size.y - ball_radius - 12.0),
	]

	var action_rect := Rect2(
		anchor - Vector2(ball_radius + 18.0, ball_radius + 18.0),
		Vector2((ball_radius + 18.0) * 2.0, (ball_radius + 18.0) * 2.0 + 18.0)
	)
	var obstacles: Array[Rect2] = _get_hud_obstacles(viewport_size)
	obstacles.append(action_rect)
	obstacles.append_array(_get_active_reward_obstacles())
	if _status_root != null and _status_root.visible:
		obstacles.append(Rect2(_status_root.position, _status_root.size))

	return _choose_lowest_cost_position(
		candidates,
		element_size,
		anchor,
		viewport_size,
		obstacles,
		anchor.x < viewport_size.x * 0.55
	)


func _choose_status_position(ball_screen: Vector2, viewport_size: Vector2) -> Vector2:
	var radius: float = _get_ball_radius()
	var side_gap: float = radius + STATUS_SIDE_GAP
	var candidates: Array[Vector2] = [
		Vector2(ball_screen.x + side_gap, ball_screen.y - STATUS_SIZE.y - 18.0),
		Vector2(ball_screen.x - STATUS_SIZE.x - side_gap, ball_screen.y - STATUS_SIZE.y - 18.0),
		Vector2(ball_screen.x + side_gap, ball_screen.y + radius + 12.0),
		Vector2(ball_screen.x - STATUS_SIZE.x - side_gap, ball_screen.y + radius + 12.0),
	]

	var action_rect := Rect2(
		ball_screen - Vector2(radius + 12.0, radius + 12.0),
		Vector2((radius + 12.0) * 2.0, (radius + 12.0) * 2.0)
	)
	var obstacles: Array[Rect2] = _get_hud_obstacles(viewport_size)
	obstacles.append(action_rect)
	obstacles.append_array(_get_active_reward_obstacles())

	var best_position: Vector2 = _choose_lowest_cost_position(
		candidates,
		STATUS_SIZE,
		ball_screen,
		viewport_size,
		obstacles,
		ball_screen.x < viewport_size.x * 0.55
	)

	# Hysteresis discourages rapid side-to-side switching as popups drift past.
	if _status_position_initialized:
		var current_position: Vector2 = _status_root.position
		var current_rect := Rect2(current_position, STATUS_SIZE)
		var current_cost: float = _position_cost(
			current_position,
			STATUS_SIZE,
			ball_screen,
			viewport_size,
			obstacles,
			ball_screen.x < viewport_size.x * 0.55,
			0
		)
		var best_cost: float = _position_cost(
			best_position,
			STATUS_SIZE,
			ball_screen,
			viewport_size,
			obstacles,
			ball_screen.x < viewport_size.x * 0.55,
			0
		)
		if current_cost <= best_cost + 24.0 and _rect_overlaps_area(current_rect, action_rect) < 8.0:
			return _fit_position(current_position, STATUS_SIZE, viewport_size)

	return best_position


func _choose_lowest_cost_position(
	candidates: Array[Vector2],
	element_size: Vector2,
	anchor: Vector2,
	viewport_size: Vector2,
	obstacles: Array[Rect2],
	prefer_right: bool
) -> Vector2:
	var best_position: Vector2 = _fit_position(candidates[0], element_size, viewport_size)
	var best_cost: float = INF

	for i in range(candidates.size()):
		var candidate: Vector2 = _fit_position(candidates[i], element_size, viewport_size)
		var cost: float = _position_cost(
			candidates[i],
			element_size,
			anchor,
			viewport_size,
			obstacles,
			prefer_right,
			i
		)
		if cost < best_cost:
			best_cost = cost
			best_position = candidate

	return best_position


func _position_cost(
	requested_position: Vector2,
	element_size: Vector2,
	anchor: Vector2,
	viewport_size: Vector2,
	obstacles: Array[Rect2],
	prefer_right: bool,
	candidate_index: int
) -> float:
	var fitted_position: Vector2 = _fit_position(requested_position, element_size, viewport_size)
	var fitted_rect := Rect2(fitted_position, element_size)
	var cost: float = requested_position.distance_to(fitted_position) * 5.0
	cost += float(candidate_index) * 2.0
	cost += fitted_position.distance_to(anchor) * 0.012

	for obstacle in obstacles:
		cost += _rect_overlaps_area(fitted_rect, obstacle) * 0.65

	var is_right_of_anchor: bool = fitted_rect.get_center().x >= anchor.x
	if is_right_of_anchor != prefer_right:
		cost += 18.0

	return cost


func _fit_position(position: Vector2, element_size: Vector2, viewport_size: Vector2) -> Vector2:
	var max_x: float = maxf(screen_safe_margin, viewport_size.x - screen_safe_margin - element_size.x)
	var max_y: float = maxf(screen_safe_margin, viewport_size.y - screen_safe_margin - element_size.y)
	return Vector2(
		clampf(position.x, screen_safe_margin, max_x),
		clampf(position.y, screen_safe_margin, max_y)
	)


func _get_hud_obstacles(viewport_size: Vector2) -> Array[Rect2]:
	return [
		Rect2(Vector2(12.0, HUD_TOP), Vector2(390.0, 66.0)),
		Rect2(Vector2(viewport_size.x - 232.0, HUD_TOP), Vector2(220.0, 66.0)),
	]


func _get_active_reward_obstacles() -> Array[Rect2]:
	var obstacles: Array[Rect2] = []
	for reward in _active_rewards:
		var root := reward.get("root") as Control
		if root == null or not is_instance_valid(root):
			continue
		if float(reward.get("age", 0.0)) < float(reward.get("lifetime", 1.0)) * 0.78:
			if root.modulate.a > 0.18:
				obstacles.append(Rect2(root.position, root.size))
	return obstacles


func _rect_overlaps_area(first: Rect2, second: Rect2) -> float:
	if not first.intersects(second):
		return 0.0
	var overlap: Rect2 = first.intersection(second)
	return maxf(overlap.size.x, 0.0) * maxf(overlap.size.y, 0.0)


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
			"%s CHAIN  %d/%d" % [quality, chain_count, activation_count],
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


func _process(delta: float) -> void:
	_update_reward_animations(delta)

	if _status_root == null or not _status_root.visible or not state_indicator_enabled:
		return

	var viewport_size: Vector2 = _get_viewport_size()
	var ball_screen: Vector2 = _get_ball_screen_position()
	var target_position: Vector2 = _choose_status_position(ball_screen, viewport_size)
	if not _status_position_initialized:
		_status_root.position = target_position
		_status_position_initialized = true
	else:
		var follow_weight: float = 1.0 - exp(-state_follow_speed * delta)
		_status_root.position = _status_root.position.lerp(target_position, follow_weight)

	_pulse_clock += delta
	_state_pop_timer = maxf(_state_pop_timer - delta, 0.0)
	if _state_pop_timer <= 0.0:
		var pulse: float = sin(_pulse_clock * 3.2)
		var scale_factor: float = 1.0 + pulse * 0.012
		for label in [_chain_label, _combo_label, _streak_label]:
			if label.visible:
				label.scale = Vector2.ONE * scale_factor
				label.modulate.a = 0.91 + pulse * 0.07


func _update_reward_animations(delta: float) -> void:
	for i in range(_active_rewards.size() - 1, -1, -1):
		var reward: Dictionary = _active_rewards[i]
		var root := reward.get("root") as Control
		if root == null or not is_instance_valid(root):
			_active_rewards.remove_at(i)
			continue

		var age: float = float(reward.get("age", 0.0)) + delta
		var lifetime: float = maxf(float(reward.get("lifetime", reward_lifetime)), 0.5)
		reward["age"] = age
		var progress: float = clampf(age / lifetime, 0.0, 1.0)
		var eased_progress: float = 1.0 - pow(1.0 - progress, 2.4)
		var phase: float = float(reward.get("phase", 0.0))
		var drift_x: float = float(reward.get("drift_x", 12.0))
		var start_position: Vector2 = reward.get("start_position", root.position)
		var flutter: float = sin(age * 10.0 + phase) * 1.6 * (1.0 - progress * 0.45)

		root.position = start_position + Vector2(
			drift_x * progress + flutter,
			-68.0 * eased_progress + sin(age * 7.2 + phase) * 1.2 * (1.0 - progress)
		)
		root.rotation = float(reward.get("rotation", 0.0)) + sin(age * 8.0 + phase) * 0.022

		if age < 0.12:
			root.scale = Vector2.ONE * lerpf(0.78, 1.06, age / 0.12)
		elif age < 0.20:
			root.scale = Vector2.ONE * lerpf(1.06, 1.0, (age - 0.12) / 0.08)
		else:
			root.scale = Vector2.ONE * (1.0 + sin(age * 9.0 + phase) * 0.008 * (1.0 - progress))

		var alpha: float = 1.0
		if age < 0.10:
			alpha = age / 0.10
		elif age > lifetime * 0.56:
			alpha = 1.0 - clampf(
				(age - lifetime * 0.56) / maxf(lifetime * 0.44, 0.01),
				0.0,
				1.0
			)
		root.modulate.a = alpha

		var points_label := reward.get("points_label") as Label
		if points_label != null and is_instance_valid(points_label):
			var points_start: Vector2 = reward.get("points_start", points_label.position)
			points_label.position = points_start + Vector2(
				drift_x * 0.24 * eased_progress,
				-7.0 * progress + sin(age * 11.0 + phase) * 1.2
			)

		var detail_label := reward.get("detail_label") as Label
		if detail_label != null and is_instance_valid(detail_label):
			detail_label.modulate.a = 1.0 - clampf((age - 0.28) / 0.24, 0.0, 1.0)

		if age >= lifetime:
			root.queue_free()
			_active_rewards.remove_at(i)
		else:
			_active_rewards[i] = reward
