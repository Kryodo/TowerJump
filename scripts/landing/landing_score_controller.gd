class_name LandingScoreController
extends Node2D

## Scores only confirmed physical landings. Quality, combo progression and
## floating feedback all derive from the same result dictionary.
signal landing_scored(result: Dictionary)
signal combo_state_changed(state: Dictionary)

@export_category("Landing Quality")
@export_range(0.05, 0.50, 0.01) var perfect_center_threshold: float = 0.18
@export_range(0.10, 0.80, 0.01) var epic_center_threshold: float = 0.48
@export_range(0.0, 600.0, 10.0) var perfect_horizontal_speed_limit: float = 120.0
@export_range(0.0, 900.0, 10.0) var epic_horizontal_speed_limit: float = 360.0
@export_range(0.50, 1.0, 0.01) var clutch_edge_factor_threshold: float = 0.92

@export_category("Base Points")
@export_range(1, 1000, 1) var good_points: int = 10
@export_range(1, 1000, 1) var epic_points: int = 25
@export_range(1, 1000, 1) var perfect_points: int = 50
@export_range(0, 1000, 1) var clutch_bonus_points: int = 25

@export_category("Combo Milestones")
@export_range(2, 10, 1) var combo_activation_landings: int = 3
@export_range(5, 30, 1) var streak_activation_landings: int = 10
@export_range(1, 20, 1) var streak_bonus_base_point_multiple: int = 5

@export_category("Good Combo Curve")
@export var good_combo_start_multiplier: float = 1.15
@export var good_combo_pre_streak_step: float = 0.09
@export var good_combo_streak_step: float = 0.04
@export var good_combo_multiplier_cap: float = 2.0

@export_category("Epic Combo Curve")
@export var epic_combo_start_multiplier: float = 1.35
@export var epic_combo_pre_streak_step: float = 0.18
@export var epic_combo_streak_step: float = 0.08
@export var epic_combo_multiplier_cap: float = 3.25

@export_category("Perfect Combo Curve")
@export var perfect_combo_start_multiplier: float = 1.65
@export var perfect_combo_pre_streak_step: float = 0.25
@export var perfect_combo_streak_step: float = 0.12
@export var perfect_combo_multiplier_cap: float = 4.0

@export_category("Floating Feedback")
@export var floating_feedback_enabled: bool = true

@export var landing_feedback_controller_path: NodePath = NodePath("../LandingFeedbackController")

var _feedback_controller: Node
var _chain_quality: String = ""
var _chain_count: int = 0
var _combo_active: bool = false
var _streak_active: bool = false
var _max_chain_count: int = 0


func _ready() -> void:
	call_deferred("_connect_landing_feedback")
	combo_state_changed.emit(get_combo_state())


func _connect_landing_feedback() -> void:
	_feedback_controller = get_node_or_null(landing_feedback_controller_path)
	if _feedback_controller == null or not _feedback_controller.has_signal("landing_confirmed"):
		push_error("LandingScoreController: LandingFeedbackController was not found.")
		return

	var callback := Callable(self, "_on_landing_confirmed")
	if not _feedback_controller.is_connected("landing_confirmed", callback):
		_feedback_controller.connect("landing_confirmed", callback)


func get_combo_state() -> Dictionary:
	return {
		"quality": _chain_quality,
		"chain_count": _chain_count,
		"combo_active": _combo_active,
		"streak_active": _streak_active,
		"multiplier": _get_combo_multiplier(_chain_quality, _chain_count) if _combo_active else 1.0,
		"combo_activation_landings": combo_activation_landings,
		"streak_activation_landings": streak_activation_landings,
		"best_chain_count": _max_chain_count,
	}


func _on_landing_confirmed(event: LandingEvent) -> void:
	if event == null or event.platform == null or not is_instance_valid(event.platform):
		return

	var quality: String = _classify_landing(event)
	var previous_quality: String = _chain_quality
	var previous_count: int = _chain_count
	var previous_combo_active: bool = _combo_active
	var chain_broken: bool = previous_combo_active and quality != previous_quality

	if quality == _chain_quality:
		_chain_count += 1
	else:
		_chain_quality = quality
		_chain_count = 1

	_max_chain_count = maxi(_max_chain_count, _chain_count)
	_combo_active = _chain_count >= combo_activation_landings
	_streak_active = _chain_count >= streak_activation_landings
	var combo_activated: bool = _chain_count == combo_activation_landings
	var streak_activated: bool = _chain_count == streak_activation_landings

	var base_points: int = _base_points_for_quality(quality)
	var multiplier: float = _get_combo_multiplier(quality, _chain_count) if _combo_active else 1.0
	var multiplied_points: int = roundi(float(base_points) * multiplier)
	var clutch_bonus: int = (
		clutch_bonus_points
		if quality == "GOOD" and event.edge_factor >= clutch_edge_factor_threshold
		else 0
	)
	var streak_bonus: int = (
		base_points * streak_bonus_base_point_multiple
		if streak_activated
		else 0
	)
	var total_points: int = multiplied_points + clutch_bonus + streak_bonus

	var result := {
		"quality": quality,
		"base_points": base_points,
		"multiplier": multiplier,
		"multiplied_points": multiplied_points,
		"clutch": clutch_bonus > 0,
		"clutch_bonus": clutch_bonus,
		"combo_active": _combo_active,
		"combo_activated": combo_activated,
		"chain_broken": chain_broken,
		"chain_count": _chain_count,
		"streak_active": _streak_active,
		"streak_activated": streak_activated,
		"streak_bonus": streak_bonus,
		"total_points": total_points,
		"best_chain_count": _max_chain_count,
		"landing_world_x": event.landing_world_x,
		"platform": event.platform,
		"edge_factor": event.edge_factor,
		"horizontal_velocity": event.horizontal_velocity,
		"platform_type": event.platform_type,
	}

	# GameManager remains the authority for the run total and run statistics.
	GameManager.record_landing_result(result)
	landing_scored.emit(result)
	combo_state_changed.emit(get_combo_state())

	if floating_feedback_enabled:
		_spawn_landing_feedback(result, event)


func _classify_landing(event: LandingEvent) -> String:
	var platform_half_width: float = 1.0
	if event.platform.has_method("half_width"):
		platform_half_width = maxf(float(event.platform.call("half_width")), 1.0)
	var center_offset: float = absf(
		event.landing_world_x - event.platform.global_position.x
	)
	# Width-relative thresholds keep the grade zones proportional on narrow
	# and wide platforms rather than relying on fixed pixel distances.
	var normalized_offset: float = center_offset / platform_half_width
	var horizontal_speed: float = absf(event.horizontal_velocity)

	if (
		normalized_offset <= perfect_center_threshold
		and horizontal_speed <= perfect_horizontal_speed_limit
	):
		return "PERFECT"
	if (
		normalized_offset <= epic_center_threshold
		and horizontal_speed <= epic_horizontal_speed_limit
	):
		return "EPIC"
	return "GOOD"


func _base_points_for_quality(quality: String) -> int:
	match quality:
		"PERFECT":
			return perfect_points
		"EPIC":
			return epic_points
		_:
			return good_points


func _get_combo_multiplier(quality: String, chain_count: int) -> float:
	if chain_count < combo_activation_landings:
		return 1.0

	var count_before_streak: int = mini(chain_count, streak_activation_landings)
	var pre_streak_steps: int = maxi(count_before_streak - combo_activation_landings, 0)
	var post_streak_steps: int = maxi(chain_count - streak_activation_landings, 0)
	var multiplier: float = 1.0
	var multiplier_cap: float = 1.0

	match quality:
		"PERFECT":
			multiplier = (
				perfect_combo_start_multiplier
				+ float(pre_streak_steps) * perfect_combo_pre_streak_step
				+ float(post_streak_steps) * perfect_combo_streak_step
			)
			multiplier_cap = perfect_combo_multiplier_cap
		"EPIC":
			multiplier = (
				epic_combo_start_multiplier
				+ float(pre_streak_steps) * epic_combo_pre_streak_step
				+ float(post_streak_steps) * epic_combo_streak_step
			)
			multiplier_cap = epic_combo_multiplier_cap
		_:
			multiplier = (
				good_combo_start_multiplier
				+ float(pre_streak_steps) * good_combo_pre_streak_step
				+ float(post_streak_steps) * good_combo_streak_step
			)
			multiplier_cap = good_combo_multiplier_cap

	return clampf(multiplier, 1.0, maxf(multiplier_cap, 1.0))


func _spawn_landing_feedback(result: Dictionary, event: LandingEvent) -> void:
	var platform_height_value: Variant = event.platform.get("height")
	var platform_height: float = float(platform_height_value) if platform_height_value != null else 20.0
	var ball_radius: float = 30.0
	if event.ball != null and is_instance_valid(event.ball):
		ball_radius = float(event.ball.get("radius")) if event.ball.get("radius") != null else 30.0
	var contact_y: float = event.platform.global_position.y - platform_height * 0.5
	var center_x: float = event.landing_world_x
	var quality: String = str(result["quality"])
	var grade_text: String = quality + "!"
	if bool(result["streak_activated"]):
		grade_text = "STREAK!"
	elif bool(result["combo_activated"]):
		grade_text = quality + " COMBO!"

	var grade_color: Color = _quality_color(quality)
	if bool(result["streak_activated"]):
		grade_color = Color(1.0, 0.73, 0.30, 1.0)

	_spawn_float_label(
		grade_text,
		grade_color,
		29 if bool(result["combo_activated"]) or bool(result["streak_activated"]) else 25,
		Vector2(center_x, contact_y - ball_radius - 57.0),
		46.0,
		0.05,
		0.70
	)
	_spawn_float_label(
		"+%d" % int(result["total_points"]),
		Color(0.55, 0.92, 1.0, 1.0),
		36,
		Vector2(center_x, contact_y - ball_radius - 24.0),
		38.0,
		0.03,
		0.64
	)

	var detail_parts: Array[String] = []
	if bool(result["streak_activated"]):
		detail_parts.append("STREAK BONUS +%d" % int(result["streak_bonus"]))
	elif bool(result["combo_activated"]):
		detail_parts.append("%s COMBO  x%.2f" % [quality, float(result["multiplier"])])
	elif bool(result["streak_active"]):
		detail_parts.append("%s STREAK  x%.2f" % [quality, float(result["multiplier"])])
	elif bool(result["combo_active"]):
		detail_parts.append("%s COMBO  x%.2f" % [quality, float(result["multiplier"])])
	elif bool(result["chain_broken"]):
		detail_parts.append("CHAIN BROKEN  ·  %s 1/%d" % [quality, combo_activation_landings])
	else:
		detail_parts.append("%s CHAIN  %d/%d" % [
			quality,
			int(result["chain_count"]),
			combo_activation_landings
		])
	if bool(result["clutch"]):
		detail_parts.append("CLUTCH +%d" % int(result["clutch_bonus"]))

	_spawn_float_label(
		"  ·  ".join(detail_parts),
		grade_color.lightened(0.12),
		16,
		Vector2(center_x, contact_y - ball_radius + 6.0),
		24.0,
		0.0,
		0.48
	)


func _spawn_float_label(
	label_text: String,
	label_color: Color,
	font_size: int,
	world_position: Vector2,
	rise_distance: float,
	fade_delay: float,
	start_scale: float
) -> void:
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(460.0, float(font_size) * 1.8)
	label.pivot_offset = label.size * 0.5
	label.position = world_position - label.size * 0.5
	label.scale = Vector2.ONE * start_scale
	label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	label.z_index = 100
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", label_color)
	label.add_theme_color_override("font_outline_color", Color(0.015, 0.025, 0.05, 0.98))
	label.add_theme_constant_override("outline_size", 5)
	add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, 0.07)
	tween.tween_property(label, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y - rise_distance, 0.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(fade_delay)
	tween.chain().tween_property(label, "modulate:a", 0.0, 0.22)
	tween.chain().tween_callback(func() -> void:
		if is_instance_valid(label):
			label.queue_free()
	)


func _quality_color(quality: String) -> Color:
	match quality:
		"PERFECT":
			return Color(0.86, 0.98, 1.0, 1.0)
		"EPIC":
			return Color(0.72, 0.44, 1.0, 1.0)
		_:
			return Color(0.40, 0.86, 1.0, 1.0)
