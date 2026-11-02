class_name EnvironmentArchitectureRecipe
extends Resource
## Deterministic composition settings and a pool of reusable architecture modules.

@export var recipe_id: StringName
@export var module_pool: Array[ArchitectureModuleDefinition] = []

## Each section key is derived from its absolute positive climb height.
@export_range(200.0, 5000.0, 50.0) var section_step_px: float = 1200.0
@export_range(0.0, 1.0, 0.05) var far_density: float = 0.95
@export_range(0.0, 1.0, 0.05) var middle_density: float = 0.85
@export_range(0.0, 1.0, 0.05) var near_density: float = 0.42
