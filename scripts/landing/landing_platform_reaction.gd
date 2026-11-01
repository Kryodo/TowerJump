class_name LandingPlatformReaction
extends Node
## Applies the platform's existing confirmation animation using the quality
## produced by LandingScoreController, keeping scoring authoritative.

@export var landing_score_controller_path: NodePath = NodePath("../LandingScoreController")


func _ready() -> void:
	call_deferred("_connect_score_controller")


func _connect_score_controller() -> void:
	var controller: Node = get_node_or_null(landing_score_controller_path)
	if controller == null or not controller.has_signal("landing_scored"):
		push_error("LandingPlatformReaction: LandingScoreController was not found.")
		return

	var callback := Callable(self, "_on_landing_scored")
	if not controller.is_connected("landing_scored", callback):
		controller.connect("landing_scored", callback)


func _on_landing_scored(result: Dictionary) -> void:
	var platform := result.get("platform") as Node2D
	if platform == null or not is_instance_valid(platform):
		return

	var quality: String = str(result.get("quality", "GOOD"))
	var strength: float
	match quality:
		"PERFECT":
			strength = 1.22
		"EPIC":
			strength = 1.0
		_:
			strength = 0.82

	if bool(result.get("combo_activated", false)):
		strength += 0.08
	if bool(result.get("streak_activated", false)):
		strength += 0.18

	if platform.has_method("play_landing_confirmation"):
		platform.call("play_landing_confirmation", strength)
