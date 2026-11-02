class_name EnvironmentArchitectureRecipe
extends Resource
## A named composition recipe referencing library modules rather than duplicating geometry.

@export var recipe_id: StringName
@export var module_pool: Array[ArchitectureModuleDefinition] = []
