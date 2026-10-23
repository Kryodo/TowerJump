class_name LandingScoreController
extends Node2D

## Scores only confirmed physical landings. Quality and combo progression
## are calculated here, then emitted as one authoritative result dictionary.
signal landing_scored(result: Dictionary)
signal combo_state_changed(state: Dictionary)

@export_category("Landing Quality")
@export_range(0.05, 0.50, 0.01) var perfect_center_threshold: float = 0.18
@export_range(0.10, 0.80, 0.01) var epic_center_threshold: float = 0.48
@export_range(0.50, 1.0, 0.01) var clutch_edge_factor_threshold: float = 0.92

@export_category("Base Points")
@export_range(1, 1000, 1) var good_points: int = 10
@export_range(1, 1000, 1) var epic_points: int = 25
@export_range(1, 1000, 1) var perfect_points: int = 50
@export_range(0, 1000, 1) var clutch_bonus_points: int = 25
@export_range(0, 10, 1) var clutch_cooldown_landings: int = 2

const MIN_VERTICAL_PROGRESS_PX: float = 12.0

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

@export var landing_feedback_controller_path: NodePath = NodePath("../LandingFeedbackController")

var _feedback_controller: Node
var _chain_quality: String = ""
var _chain_count: int = 0
var _combo_active: bool = false
var _streak_active: bool = false
var _max_chain_count: int = 0
var _last_seen_generation_by_platform: Dictionary = {}
var _has_scored_platform_progress: bool = false
var _highest_scored_platform_y: float = 0.0
var _clutch_cooldown_remaining: int = 0


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

	var platform_instance_id: int = event.platform.get_instance_id()
	var platform_generation: int = event.platform_generation
	var previous_generation: int = int(
		_last_seen_generation_by_platform.get(platform_instance_id, -1)
	)
	var repeated_platform_landing: bool = previous_generation == platform_generation
	_last_seen_generation_by_platform[platform_instance_id] = platform_generation

	# Landing points require real upward progress. This also prevents alternating
	# between separate branch platforms at the same height to farm score.
	var platform_y: float = event.platform.global_position.y
	var advances_height: bool = (
		not _has_scored_platform_progress
		or platform_y < _highest_scored_platform_y - MIN_VERTICAL_PROGRESS_PX
	)
	if repeated_platform_landing or not advances_height:
		var chain_was_active: bool = _chain_count > 0
		_reset_combo_chain()
		var rejected_result := {
			"quality": "GOOD",
			"base_points": 0,
			"multiplier": 1.0,
			"multiplied_points": 0,
			"clutch": false,
			"clutch_bonus": 0,
			"clutch_recovery": event.late_edge_recovery,
			"combo_active": false,
			"combo_activated": false,
			"chain_broken": chain_was_active,
			"chain_count": 0,
			"streak_active": false,
			"streak_activated": false,
			"streak_bonus": 0,
			"total_points": 0,
			"best_chain_count": _max_chain_count,
			"landing_world_x": event.landing_world_x,
			"platform": event.platform,
			"platform_generation": platform_generation,
			"edge_factor": event.edge_factor,
			"horizontal_velocity": event.horizontal_velocity,
			"platform_type": event.platform_type,
			"scoring_eligible": false,
			"repeat_platform_landing": repeated_platform_landing,
			"progression_blocked": not advances_height,
		}
		# Keep physical platform confirmation, but don't grant score, stats,
		# Combo/Streak progress, reward text, or Clutch for rejected contacts.
		landing_scored.emit(rejected_result)
		combo_state_changed.emit(get_combo_state())
		return

	_has_scored_platform_progress = true
	_highest_scored_platform_y = platform_y

	var quality: String = _classify_landing(event)
	var previous_quality: String = _chain_quality
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

	var platform_half_width: float = maxf(float(event.platform.call("half_width")), 1.0)
	var actual_local_x: float = absf(
		event.landing_world_x - event.platform.global_position.x
	)
	var clutch_candidate: bool = (
		quality == "GOOD"
		and event.edge_factor >= clutch_edge_factor_threshold
		and event.late_edge_recovery
		and actual_local_x <= platform_half_width
	)
	var clutch_bonus: int = 0
	if _clutch_cooldown_remaining > 0:
		_clutch_cooldown_remaining -= 1
	elif clutch_candidate:
		clutch_bonus = clutch_bonus_points
		_clutch_cooldown_remaining = clutch_cooldown_landings

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
		"clutch_recovery": event.late_edge_recovery,
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
		"platform_generation": platform_generation,
		"edge_factor": event.edge_factor,
		"horizontal_velocity": event.horizontal_velocity,
		"platform_type": event.platform_type,
		"scoring_eligible": true,
		"repeat_platform_landing": false,
		"progression_blocked": false,
	}

	# GameManager remains the authority for the run total and run statistics.
	GameManager.record_landing_result(result)
	landing_scored.emit(result)
	combo_state_changed.emit(get_combo_state())


func _reset_combo_chain() -> void:
	_chain_quality = ""
	_chain_count = 0
	_combo_active = false
	_streak_active = false


func _classify_landing(event: LandingEvent) -> String:
	var platform_half_width: float = 1.0
	if event.platform.has_method("half_width"):
		platform_half_width = maxf(float(event.platform.call("half_width")), 1.0)
	var center_offset: float = absf(
		event.landing_world_x - event.platform.global_position.x
	)
	# For now, COMBO grades measure landing precision only. Horizontal speed
	# remains available on LandingEvent for possible future systems, but it
	# must not automatically downgrade a precise landing.
	var normalized_offset: float = center_offset / platform_half_width

	if normalized_offset <= perfect_center_threshold:
		return "PERFECT"
	if normalized_offset <= epic_center_threshold:
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

