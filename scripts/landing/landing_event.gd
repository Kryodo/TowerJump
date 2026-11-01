class_name LandingEvent
extends RefCounted
## Immutable-at-emission description of a physical landing.
##
## This object contains outcome/context data only. Prediction and visual
## sequencing live in LandingFeedbackController / LandingApproachState.
## Future ball, particle, score, combo, camera and audio layers can all consume
## the same LandingEvent without knowing how the landing was predicted.

var ball: CharacterBody2D
var platform: Node2D
var landing_world_x: float
var landing_ratio: float
var edge_factor: float
var horizontal_velocity: float
var vertical_velocity: float
var approach_progress: float
var platform_type: int
var platform_generation: int
var late_edge_recovery: bool

func _init(
	landing_ball: CharacterBody2D,
	landing_platform: Node2D,
	world_x: float,
	ratio: float,
	edge: float,
	horizontal_speed: float,
	vertical_speed: float,
	approach: float,
	type: int,
	generation: int,
	had_late_edge_recovery: bool
) -> void:
	ball = landing_ball
	platform = landing_platform
	landing_world_x = world_x
	landing_ratio = ratio
	edge_factor = edge
	horizontal_velocity = horizontal_speed
	vertical_velocity = vertical_speed
	approach_progress = approach
	platform_type = type
	platform_generation = generation
	late_edge_recovery = had_late_edge_recovery
