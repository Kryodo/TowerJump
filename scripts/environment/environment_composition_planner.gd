class_name EnvironmentCompositionPlanner
extends RefCounted
## Resolves a zone into deterministic architectural sections and authored landmarks.
## The geometry itself is rendered by EnvironmentArchitectureLayer, which contains
## the extracted far/middle/near grammar from the preserved experiment.

const RUN_ORIGIN_WORLD_Y: float = 600.0


static func build_plan(
	zone: EnvironmentZoneProfile,
	world_seed: int,
	theme_override: EnvironmentThemeProfile = null
) -> Dictionary:
	var validation := EnvironmentProfileValidator.validate_zone(zone)
	var errors: Array[String] = []
	var warnings: Array[String] = []
	for message in validation.get("errors", []):
		errors.append(str(message))
	for message in validation.get("warnings", []):
		warnings.append(str(message))

	var architecture_sections: Array[Dictionary] = []
	var landmarks: Array[Dictionary] = []
	var reservations: Array[Rect2] = []

	if not errors.is_empty():
		return _make_result(zone, world_seed, architecture_sections, landmarks, reservations, errors, warnings)

	for subzone in zone.subzones:
		if subzone == null or subzone.architecture_recipe == null:
			continue
		var stable_subzone_key: StringName = (
			subzone.seed_key
			if not String(subzone.seed_key).is_empty()
			else subzone.subzone_id
		)

		# A one-subzone reference composition receives the world seed unchanged.
		# This is required to reproduce the established seed-7319 comparison exactly.
		# Multi-subzone compositions derive independent stable section seeds.
		var architecture_seed := world_seed
		if zone.subzones.size() > 1:
			architecture_seed = EnvironmentSeedResolver.section_seed(
				world_seed,
				zone.zone_id,
				stable_subzone_key,
				&"architecture_grammar"
			)

		var theme := _resolve_theme(zone, subzone, theme_override)
		var ambient := _resolve_ambient(zone, subzone)
		var lighting := _resolve_lighting(zone, subzone)
		var recipe: EnvironmentArchitectureRecipe = subzone.architecture_recipe
		var section_top_y := RUN_ORIGIN_WORLD_Y - subzone.end_height_px
		var section_bottom_y := (
			RUN_ORIGIN_WORLD_Y
			- subzone.start_height_px
			+ recipe.section_bottom_padding_px
		)
		architecture_sections.append({
			"subzone_id": subzone.subzone_id,
			"stable_seed_key": stable_subzone_key,
			"start_height_px": subzone.start_height_px,
			"end_height_px": subzone.end_height_px,
			"section_top_y": section_top_y,
			"section_bottom_y": section_bottom_y,
			"architecture_seed": architecture_seed,
			"recipe": recipe,
			"theme_profile": theme,
			"ambient_profile": ambient,
			"lighting_profile": lighting,
		})

	# Register all fixed landmark reservations before returning the plan.
	# The base architecture is allowed to remain behind a landmark, as in the
	# original study; additional authored modules must respect these clearances.
	for anchor in zone.landmark_anchors:
		var subzone := _find_subzone(zone, anchor.subzone_id)
		var theme := _resolve_theme(zone, subzone, theme_override, anchor.theme_override)
		var lighting := _resolve_lighting(zone, subzone)
		var seed_value := EnvironmentSeedResolver.landmark_seed(
			world_seed,
			zone.zone_id,
			anchor.landmark_id,
			anchor.seed_key if not String(anchor.seed_key).is_empty() else anchor.landmark_id
		)
		var root_position := Vector2(
			anchor.local_position.x,
			RUN_ORIGIN_WORLD_Y - anchor.height_anchor_px + anchor.local_position.y
		)
		var clearance := Rect2(
			root_position + anchor.clearance_bounds.position,
			anchor.clearance_bounds.size
		)
		reservations.append(clearance)
		landmarks.append({
			"anchor": anchor,
			"root_position": root_position,
			"seed": seed_value,
			"theme_profile": theme,
			"lighting_profile": lighting,
			"clearance_rect": clearance,
		})

	return _make_result(
		zone,
		world_seed,
		architecture_sections,
		landmarks,
		reservations,
		errors,
		warnings
	)


static func plan_signature(plan: Dictionary) -> int:
	var lines := PackedStringArray()
	lines.append("zone=%s|seed=%d" % [
		String(plan.get("zone_id", "")),
		int(plan.get("world_seed", 0)),
	])
	for section in plan.get("architecture_sections", []):
		var recipe: EnvironmentArchitectureRecipe = section.recipe
		lines.append("S|%s|%s|%d|%d|%d|%s" % [
			String(section.subzone_id),
			String(section.stable_seed_key),
			int(section.start_height_px),
			int(section.end_height_px),
			int(section.architecture_seed),
			String(recipe.recipe_id),
		])
	for landmark in plan.get("landmarks", []):
		var anchor: EnvironmentLandmarkAnchor = landmark.anchor
		lines.append("L|%s|%d|%d|%d|%d" % [
			String(anchor.landmark_id),
			int(anchor.height_anchor_px),
			roundi(landmark.root_position.x),
			roundi(landmark.root_position.y),
			int(landmark.seed),
		])
	return EnvironmentSeedResolver.fingerprint("\n".join(lines))


static func _make_result(
	zone: EnvironmentZoneProfile,
	world_seed: int,
	architecture_sections: Array[Dictionary],
	landmarks: Array[Dictionary],
	reservations: Array[Rect2],
	errors: Array[String],
	warnings: Array[String]
) -> Dictionary:
	return {
		"zone_id": String(zone.zone_id) if zone != null else "",
		"world_seed": world_seed,
		"architecture_sections": architecture_sections,
		"landmarks": landmarks,
		"reservations": reservations,
		"errors": errors,
		"warnings": warnings,
		"section_count": architecture_sections.size(),
		"landmark_count": landmarks.size(),
		"reservation_count": reservations.size(),
	}


static func _find_subzone(zone: EnvironmentZoneProfile, subzone_id: StringName) -> EnvironmentSubzoneProfile:
	for subzone in zone.subzones:
		if subzone != null and subzone.subzone_id == subzone_id:
			return subzone
	return null


static func _resolve_theme(
	zone: EnvironmentZoneProfile,
	subzone: EnvironmentSubzoneProfile,
	global_override: EnvironmentThemeProfile,
	anchor_override: EnvironmentThemeProfile = null
) -> EnvironmentThemeProfile:
	if global_override != null:
		return global_override
	if anchor_override != null:
		return anchor_override
	if subzone != null and subzone.theme_profile != null:
		return subzone.theme_profile
	return zone.theme_profile


static func _resolve_ambient(
	zone: EnvironmentZoneProfile,
	subzone: EnvironmentSubzoneProfile
) -> EnvironmentAmbientProfile:
	if subzone != null and subzone.ambient_profile != null:
		return subzone.ambient_profile
	return zone.ambient_profile


static func _resolve_lighting(
	zone: EnvironmentZoneProfile,
	subzone: EnvironmentSubzoneProfile
) -> EnvironmentLightingProfile:
	if subzone != null and subzone.lighting_profile != null:
		return subzone.lighting_profile
	return zone.lighting_profile
