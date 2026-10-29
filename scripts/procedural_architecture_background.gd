extends Node2D
## Background manager for isolated architecture palette comparisons.
## It supports the original A-F palette study, D-background transition study,
## and far-fill hue/brightness study while keeping the production scene unchanged.

enum PaletteVariant {
	CURRENT_NAVY,
	REVERSED_VOID,
	INTERMEDIATE_BLUE_BLACK,
	INTERMEDIATE_BLUE_BLACK_MID_CONTRAST,
	CURRENT_NAVY_MID_CONTRAST,
	CURRENT_NAVY_BRIGHTER_FAR,
	CURRENT_NAVY_HYBRID,
	CURRENT_NAVY_HUE_ONLY,
	CURRENT_NAVY_BRIGHTNESS_ONLY,
	CURRENT_NAVY_A1_DARK_TINT_FAR,
	CURRENT_NAVY_A1_BRIGHT_TINT_FAR,
	CURRENT_NAVY_A2_DARK_BLUE_MID,
	CURRENT_NAVY_A2_DARK_PURPLE_MID,
	CURRENT_NAVY_E_BALANCED,
	CURRENT_NAVY_E_BRIGHTER,
	CURRENT_NAVY_PURPLE_FAR_BLUE_MID,
	CURRENT_NAVY_BLUE_FAR_PURPLE_MID,
}

enum LifeTreatment {
	BASELINE,
	SUBTLE_CONTOURS,
	CONTOURS_AND_WINDOWS,
}

@export var environment_seed: int = 7319
@export var palette_variant: PaletteVariant = PaletteVariant.CURRENT_NAVY
@export var life_treatment: LifeTreatment = LifeTreatment.BASELINE
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
const BACKGROUND_REVERSED_VOID := Color(0.003921569, 0.011764706, 0.02745098, 1.0) # #010307 (near-black, matching the former darkest far mass)
const BACKGROUND_INTERMEDIATE := Color(0.003921569, 0.019607844, 0.039215688, 1.0) # #01050A

var _camera: Camera2D
var _layers: Array[Node2D] = []
var _use_background_fill_override: bool = false
var _background_fill_override: Color = BACKGROUND_CURRENT_NAVY


func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera2D
	_create_layers()
	_update_parallax()


func _draw() -> void:
	# Only the solid background fill and matching far/mid silhouette fills change between palette trials.
	draw_rect(
		Rect2(
			Vector2(-100.0, section_top_y - 200.0),
			Vector2(world_width + 200.0, section_bottom_y - section_top_y + 400.0)
		),
		_background_color(),
		true
	)


func _background_color() -> Color:
	if _use_background_fill_override:
		return _background_fill_override
	match palette_variant:
		PaletteVariant.REVERSED_VOID:
			return BACKGROUND_REVERSED_VOID
		PaletteVariant.INTERMEDIATE_BLUE_BLACK, PaletteVariant.INTERMEDIATE_BLUE_BLACK_MID_CONTRAST:
			return BACKGROUND_INTERMEDIATE
		_:
			return BACKGROUND_CURRENT_NAVY


func set_environment_seed(value: int) -> void:
	environment_seed = value
	for layer in _layers:
		layer.set("environment_seed", environment_seed)
		layer.queue_redraw()


func set_palette_variant(value: int) -> void:
	palette_variant = clampi(value, PaletteVariant.CURRENT_NAVY, PaletteVariant.CURRENT_NAVY_BLUE_FAR_PURPLE_MID)
	for layer in _layers:
		layer.set("palette_variant", palette_variant)
		layer.queue_redraw()
	queue_redraw()


func set_life_treatment(value: int) -> void:
	life_treatment = clampi(value, LifeTreatment.BASELINE, LifeTreatment.CONTOURS_AND_WINDOWS)
	for layer in _layers:
		layer.set("life_treatment", life_treatment)
		layer.queue_redraw()


func set_background_fill_override(value: Color) -> void:
	# Transition-test wrapper can force the same backdrop throughout the world.
	# With this disabled by default, the original A-F palette scene is unchanged.
	_background_fill_override = value
	_use_background_fill_override = true
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
		layer.set("life_treatment", life_treatment)
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
