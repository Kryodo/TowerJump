extends Node2D
## Reusable background manager for the procedural architectural section.
## It creates three independently parallaxing geometry layers and keeps the
## original gameplay scene and gameplay scripts entirely separate.

@export var environment_seed: int = 7319
@export var world_width: float = 720.0
@export var section_top_y: float = -10400.0
@export var section_bottom_y: float = 1600.0
@export var camera_path: NodePath

const ArchitectureLayerScript := preload("res://scripts/procedural_architecture_draw_layer.gd")
const PARALLAX_X_FACTORS: Array[float] = [0.72, 0.90, 1.0]
const PARALLAX_Y_FACTORS: Array[float] = [0.18, 0.46, 0.82]
const LAYER_NAMES: Array[String] = [
	"FarArchitecture",
	"MidArchitecture",
	"NearArchitecture",
]

var _camera: Camera2D
var _layers: Array[Node2D] = []


func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera2D
	_create_layers()
	_update_parallax()


func _draw() -> void:
	# Deep blue-black world base. Soft bands add atmosphere without using a
	# full-screen wallpaper or relying on an imported background image.
	draw_rect(
		Rect2(
			Vector2(-100.0, section_top_y - 200.0),
			Vector2(world_width + 200.0, section_bottom_y - section_top_y + 400.0)
		),
		Color(0.004, 0.009, 0.023, 1.0),
		true
	)

	var band_y: float = section_top_y
	var band_index: int = 0
	while band_y < section_bottom_y:
		var alpha: float = 0.055 if band_index % 3 == 0 else 0.028
		var band_color: Color = Color(0.015, 0.10, 0.17, alpha)
		if band_index % 4 == 2:
			band_color = Color(0.075, 0.025, 0.14, alpha)
		draw_rect(
			Rect2(-80.0, band_y, world_width + 160.0, 160.0),
			band_color,
			true
		)
		band_y += 720.0
		band_index += 1


func set_environment_seed(value: int) -> void:
	environment_seed = value
	for i in range(_layers.size()):
		_layers[i].set("environment_seed", environment_seed)
		_layers[i].queue_redraw()


func _process(_delta: float) -> void:
	_update_parallax()


func _create_layers() -> void:
	for i in range(PARALLAX_Y_FACTORS.size()):
		var layer := Node2D.new()
		layer.name = LAYER_NAMES[i]
		layer.set_script(ArchitectureLayerScript)
		layer.set("layer_type", i)
		layer.set("environment_seed", environment_seed)
		layer.set("world_width", world_width)
		layer.set("section_top_y", section_top_y)
		layer.set("section_bottom_y", section_bottom_y)
		# Parent background sits at z=-100; child-relative indices put each
		# architecture layer behind platforms and the ball, but in depth order.
		layer.z_index = i + 1
		add_child(layer)
		_layers.append(layer)


func _update_parallax() -> void:
	if _camera == null or _layers.is_empty():
		return

	for i in range(_layers.size()):
		var x_factor: float = PARALLAX_X_FACTORS[i]
		var y_factor: float = PARALLAX_Y_FACTORS[i]
		var layer: Node2D = _layers[i]
		# Horizontal scale stays close to 1.0 so even far structures span the
		# environment. Vertical parallax does most of the depth work as the camera
		# climbs; a small horizontal contraction makes the far layer feel recessed.
		layer.scale = Vector2(x_factor, y_factor)
		layer.position = Vector2(
			world_width * 0.5 * (1.0 - x_factor),
			_camera.global_position.y * (1.0 - y_factor)
		)
