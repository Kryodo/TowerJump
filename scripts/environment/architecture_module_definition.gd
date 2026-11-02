class_name ArchitectureModuleDefinition
extends Resource
## Reusable authored or procedural architecture unit plus its composition metadata.

enum Family {
	LARGE_MASS,
	STRUCTURAL,
	CONNECTOR,
	SURFACE_DETAIL,
}

enum DepthLayer {
	FAR,
	MIDDLE,
	NEAR,
}

@export var module_id: StringName
@export var family: Family = Family.STRUCTURAL
@export var depth_layer: DepthLayer = DepthLayer.MIDDLE
@export var scene: PackedScene
## Module-local visual bounds, relative to the scene root.
@export var local_bounds: Rect2 = Rect2()
## Module-local area that neighboring modules must keep clear.
@export var clearance_bounds: Rect2 = Rect2()
## Optional local attachment points for deliberate module composition.
@export var connection_points: Array[Vector2] = []
