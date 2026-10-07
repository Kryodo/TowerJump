class_name LandingPlatformReaction
extends Node
## Dedicated platform-side reaction layer.
##
## Receives the centralized LandingEvent and tells the landed platform to play
## its completion response. Future Good/Epic/Perfect logic can choose a flash
## strength here without touching prediction or platform gameplay.

@export var landing_feedback_controller_path: NodePath = NodePath("../LandingFeedbackController")

func _ready() -> void:
	call_deferred("_connect_controller")

func _connect_controller() -> void:
	var controller := get_node_or_null(
		landing_feedback_controller_path
	) as LandingFeedbackController

	if controller == null:
		return

	var callback := Callable(self, "_on_landing_confirmed")
	if not controller.landing_confirmed.is_connected(callback):
		controller.landing_confirmed.connect(callback)

func _on_landing_confirmed(event: LandingEvent) -> void:
	if event == null or event.platform == null:
		return

	if not is_instance_valid(event.platform):
		return

	if event.platform.has_method("play_landing_confirmation"):
		event.platform.play_landing_confirmation()
