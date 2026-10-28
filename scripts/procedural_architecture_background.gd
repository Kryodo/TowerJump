extends Node2D
## Background manager for a controlled palette comparison.
## Palette A preserves the current game backdrop; B reverses the relationship
## toward a near-black void with blue architecture; C is the in-between option.

enum PaletteVariant {
	CURRENT_NAVY,
	REVERSED_VOID,
	INTERMEDIATE_BLUE_BLACK,
}

@export var environment_seed: int = 7319
@export var palette_variant: PaletteVariant = PaletteVariant.CURRENT_NAVY
@export var world_width: float = 720.0
@export var section_top_y: float = -10400.0
@export var section_bottom_y: float = 1600.0
@export var camera_path: NodePath

const ArchitectureLayerScript := preload("res://scripts/procedural_architecture_draw_layer.gd")
const PARALLAX_X_FACTORS: Array[float] = [0.88, 0.96, 1.0]
const PARALLAX_Y_FACTORS: Array[float] = [0.18, 0.46, 0.82]
const LAYER_NAMES: Array[String] = [
	"FarArchitecture",
	"MidArchitecture",
	"NearArchitecture",
]

const BACKGROUND_CURRENT_NAVY := Color(0.007843138, 0.023529412, 0.050980393, 1.0) # #02060D
const BACKGROUND_REVERSED_VOID := Color(0.003921569, 0.007843138, 0.015686275, 1.0) # #010204
const BACKGROUND_INTERMEDIATE := Color(0.003921569, 0.015686275, 0.035294118, 1.0) # #010409

var _camera: Camera2D
var _layers: Array[Node2D] = []


func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera2D
	_create_layers()
	_update_parallax()


func _draw() -> void:
	# Only the solid background fill changes between palette trials.
	draw_rect(
		Rect2(
			Vector2(-100.0, section_top_y - 200.0),
			Vector2(world_width + 200.0, section_bottom_y - section_top_y + 400.0)
		),
		_background_color(),
		true
	)


func _background_color() -> Color:
	match palette_variant:
		PaletteVariant.REVERSED_VOID:
			return BACKGROUND_REVERSED_VOID
		PaletteVariant.INTERMEDIATE_BLUE_BLACK:
			return BACKGROUND_INTERMEDIATE
		_:
			return BACKGROUND_CURRENT_NAVY


func set_environment_seed(value: int) -> void:
	environment_seed = value
	for layer in _layers:
		layer.set("environment_seed", environment_seed)
		layer.queue_redraw()


func set_palette_variant(value: int) -> void:
	palette_variant = clampi(value, PaletteVariant.CURRENT_NAVY, PaletteVariant.INTERMEDIATE_BLUE_BLACK)
	for layer in _layers:
		layer.set("palette_variant", palette_variant)
		layer.queue_redraw()
	queue_redraw()


func _process(_delta: float) -> void:
	_update_parallax()


func _create_layers() -> void:
	for i in range(PARALLAX_Y_FACTORS.size()):
		var layer := Node2D.new()
		layer.name = LAYER_NAMES[i]
		layer.set_script(ArchitectureLayerScript)
		layer.set("layer_type", i)
		layer.set("environment_seed", environment_seed)
		layer.set("palette_variant", palette_variant)
		layer.set("world_width", world_width)
		layer.set("section_top_y", section_top_y)
		layer.set("section_bottom_y", section_bottom_y)
		# All layers stay behind gameplay. The near layer is just faint framing.
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
		layer.scale = Vector2(x_factor, y_factor)
		layer.position = Vector2(
			world_width * 0.5 * (1.0 - x_factor),
			_camera.global_position.y * (1.0 - y_factor)
		)
