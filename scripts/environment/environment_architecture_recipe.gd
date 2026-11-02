class_name EnvironmentArchitectureRecipe
extends Resource
## Reusable composition recipe for the extracted architectural grammar.
## Module pools describe inspectable reusable library entries; the procedural
## layer generators preserve the established connected-mass/support grammar.

enum FarDetailTreatment {
	NONE,
	COMPACT_PANEL_STATES,
	COMPACT_PANEL_FLICKER,
}

enum MidDetailTreatment {
	BASELINE,
	STEPPED_INSETS,
	INSETS_AND_MECHANICAL_RECESSES,
}

@export var recipe_id: StringName
@export var module_pool: Array[ArchitectureModuleDefinition] = []

## Approved reference rhythm. These defaults reproduce the original composition.
@export_range(800.0, 2600.0, 20.0) var far_repeat_spacing_px: float = 1580.0
@export_range(800.0, 2200.0, 20.0) var middle_repeat_spacing_px: float = 1260.0
@export_range(1200.0, 3200.0, 20.0) var near_repeat_spacing_px: float = 2140.0
## Extends the renderer slightly below the zone start, matching the reference window.
@export_range(0.0, 2000.0, 20.0) var section_bottom_padding_px: float = 1000.0

@export var far_detail_treatment: FarDetailTreatment = FarDetailTreatment.COMPACT_PANEL_FLICKER
@export var middle_detail_treatment: MidDetailTreatment = MidDetailTreatment.INSETS_AND_MECHANICAL_RECESSES
