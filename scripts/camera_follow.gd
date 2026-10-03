extends Camera2D
## Folgt dem Ziel (Ball) ausschließlich nach oben. Fällt der Ball wieder
## nach unten, bleibt die Kamera stehen (typisch für Doodle-Jump-artige Spiele).

@export var target_path: NodePath
@export var follow_lerp_weight: float = 6.0 ## Höher = die Kamera "klebt" enger am Ball

@onready var _target: Node2D = get_node(target_path)

func _process(delta: float) -> void:
	if _target.global_position.y < global_position.y:
		global_position.y = lerp(global_position.y, _target.global_position.y, clampf(follow_lerp_weight * delta, 0.0, 1.0))
