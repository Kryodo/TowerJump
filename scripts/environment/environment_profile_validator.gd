class_name EnvironmentProfileValidator
extends RefCounted
## Source-data validation shared by all previews and regression checks.

static func validate_zone(zone: EnvironmentZoneProfile) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []

	if zone == null:
		errors.append("Zone profile is null.")
		return {"errors": errors, "warnings": warnings}

	if String(zone.zone_id).is_empty():
		errors.append("Zone ID must not be empty.")
	if zone.start_height_px < 0.0 or zone.end_height_px <= zone.start_height_px:
		errors.append("Zone height range must be positive and end after start.")
	if zone.theme_profile == null:
		warnings.append("Zone has no default theme profile.")
	if zone.ambient_profile == null:
		warnings.append("Zone has no default ambient profile.")
	else:
		_validate_ambient_profile(zone.ambient_profile, "Zone", errors)
	if zone.lighting_profile == null:
		warnings.append("Zone has no default lighting profile.")
	else:
		_validate_lighting_profile(zone.lighting_profile, "Zone", errors)

	var subzone_ids: Dictionary = {}
	var sorted_ranges: Array[Vector2] = []
	for subzone in zone.subzones:
		if subzone == null:
			errors.append("Zone contains a null subzone entry.")
			continue
		var subzone_id := String(subzone.subzone_id)
		if subzone_id.is_empty():
			errors.append("A subzone has an empty ID.")
		elif subzone_ids.has(subzone_id):
			errors.append("Duplicate subzone ID: %s." % subzone_id)
		else:
			subzone_ids[subzone_id] = true

		if (
			subzone.start_height_px < zone.start_height_px
			or subzone.end_height_px > zone.end_height_px
			or subzone.end_height_px <= subzone.start_height_px
		):
			errors.append("Subzone %s has an invalid or out-of-zone height range." % subzone_id)
		sorted_ranges.append(Vector2(subzone.start_height_px, subzone.end_height_px))

		if subzone.architecture_recipe == null:
			errors.append("Subzone %s has no architecture recipe." % subzone_id)
			continue
		var recipe := subzone.architecture_recipe
		if String(recipe.recipe_id).is_empty():
			errors.append("Subzone %s uses a recipe with an empty ID." % subzone_id)
		if recipe.section_step_px < 200.0 or recipe.section_step_px > 5000.0:
			errors.append("Recipe %s section step must remain in the supported 200–5000 px range." % String(recipe.recipe_id))
		if (
			recipe.far_density < 0.0 or recipe.far_density > 1.0
			or recipe.middle_density < 0.0 or recipe.middle_density > 1.0
			or recipe.near_density < 0.0 or recipe.near_density > 1.0
		):
			errors.append("Recipe %s has a depth density outside the 0–1 range." % String(recipe.recipe_id))
		if recipe.module_pool.is_empty():
			errors.append("Recipe %s has an empty module pool." % String(recipe.recipe_id))

		var module_ids: Dictionary = {}
		for module in recipe.module_pool:
			if module == null:
				errors.append("Recipe %s contains a null module." % String(recipe.recipe_id))
				continue
			var module_id := String(module.module_id)
			if module_id.is_empty():
				errors.append("Recipe %s contains a module with an empty ID." % String(recipe.recipe_id))
			elif module_ids.has(module_id):
				errors.append("Recipe %s contains duplicate module ID %s." % [String(recipe.recipe_id), module_id])
			else:
				module_ids[module_id] = true
			if module.family < ArchitectureModuleDefinition.Family.LARGE_MASS or module.family > ArchitectureModuleDefinition.Family.SURFACE_DETAIL:
				errors.append("Module %s has an invalid family value." % module_id)
			if module.depth_layer < ArchitectureModuleDefinition.DepthLayer.FAR or module.depth_layer > ArchitectureModuleDefinition.DepthLayer.NEAR:
				errors.append("Module %s has an invalid depth layer." % module_id)
			if module.scene == null:
				errors.append("Module %s has no PackedScene." % module_id)
			if module.local_bounds.size.x <= 0.0 or module.local_bounds.size.y <= 0.0:
				errors.append("Module %s must have positive visual bounds." % module_id)
			if module.clearance_bounds.size.x < 0.0 or module.clearance_bounds.size.y < 0.0:
				errors.append("Module %s has negative clearance bounds." % module_id)

		if subzone.theme_profile == null and zone.theme_profile == null:
			warnings.append("Subzone %s has no resolved theme." % subzone_id)
		if subzone.ambient_profile == null and zone.ambient_profile == null:
			warnings.append("Subzone %s has no resolved ambient profile." % subzone_id)
		elif subzone.ambient_profile != null:
			_validate_ambient_profile(subzone.ambient_profile, "Subzone %s" % subzone_id, errors)
		if subzone.lighting_profile == null and zone.lighting_profile == null:
			warnings.append("Subzone %s has no resolved lighting profile." % subzone_id)
		elif subzone.lighting_profile != null:
			_validate_lighting_profile(subzone.lighting_profile, "Subzone %s" % subzone_id, errors)

	sorted_ranges.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	for index in range(1, sorted_ranges.size()):
		if sorted_ranges[index].x < sorted_ranges[index - 1].y:
			errors.append("Subzone height ranges overlap; use a gap for an intentional void interval.")

	var landmark_ids: Dictionary = {}
	var landmark_reservations: Array[Rect2] = []
	for anchor in zone.landmark_anchors:
		if anchor == null:
			errors.append("Zone contains a null landmark anchor.")
			continue
		var landmark_id := String(anchor.landmark_id)
		if landmark_id.is_empty():
			errors.append("A landmark anchor has an empty ID.")
		elif landmark_ids.has(landmark_id):
			errors.append("Duplicate landmark ID: %s." % landmark_id)
		else:
			landmark_ids[landmark_id] = true
		if anchor.scene == null:
			errors.append("Landmark %s has no PackedScene." % landmark_id)
		if anchor.height_anchor_px < zone.start_height_px or anchor.height_anchor_px >= zone.end_height_px:
			errors.append("Landmark %s is outside the zone height range." % landmark_id)
		if anchor.clearance_bounds.size.x <= 0.0 or anchor.clearance_bounds.size.y <= 0.0:
			errors.append("Landmark %s must reserve a positive clearance rectangle." % landmark_id)
		else:
			var anchor_root := Vector2(
				anchor.local_position.x,
				600.0 - anchor.height_anchor_px + anchor.local_position.y
			)
			var reservation := Rect2(
				anchor_root + anchor.clearance_bounds.position,
				anchor.clearance_bounds.size
			)
			for existing_reservation in landmark_reservations:
				if reservation.intersects(existing_reservation):
					errors.append("Landmark %s overlaps another landmark reservation." % landmark_id)
					break
			landmark_reservations.append(reservation)
		if not String(anchor.subzone_id).is_empty():
			var owning_subzone := _find_subzone(zone, anchor.subzone_id)
			if owning_subzone == null:
				errors.append("Landmark %s references unknown subzone %s." % [landmark_id, String(anchor.subzone_id)])
			elif (
				anchor.height_anchor_px < owning_subzone.start_height_px
				or anchor.height_anchor_px >= owning_subzone.end_height_px
			):
				errors.append("Landmark %s is outside its assigned subzone %s." % [landmark_id, String(anchor.subzone_id)])

	return {"errors": errors, "warnings": warnings}



static func _find_subzone(zone: EnvironmentZoneProfile, subzone_id: StringName) -> EnvironmentSubzoneProfile:
	for subzone in zone.subzones:
		if subzone != null and subzone.subzone_id == subzone_id:
			return subzone
	return null



static func _validate_lighting_profile(
	profile: EnvironmentLightingProfile,
	scope_label: String,
	errors: Array[String]
) -> void:
	var shares_total := profile.dormant_share + profile.subtle_share + profile.neon_share
	if (
		profile.dormant_share < 0.0 or profile.dormant_share > 1.0
		or profile.subtle_share < 0.0 or profile.subtle_share > 1.0
		or profile.neon_share < 0.0 or profile.neon_share > 1.0
	):
		errors.append("%s lighting profile shares must each be between 0 and 1." % scope_label)
	if shares_total <= 0.0:
		errors.append("%s lighting profile must enable at least one light state." % scope_label)
	if profile.intensity_scale < 0.0 or profile.intensity_scale > 2.0:
		errors.append("%s lighting intensity scale must be between 0 and 2." % scope_label)
	if profile.flicker_rate_hz < 0.1 or profile.flicker_rate_hz > 8.0:
		errors.append("%s lighting flicker rate is outside the supported range." % scope_label)
	if profile.flicker_minimum_alpha < 0.75 or profile.flicker_minimum_alpha > 1.0:
		errors.append("%s lighting flicker minimum alpha is outside the supported range." % scope_label)


static func _validate_ambient_profile(
	profile: EnvironmentAmbientProfile,
	scope_label: String,
	errors: Array[String]
) -> void:
	if profile.density_scale < 0.0 or profile.density_scale > 3.0:
		errors.append("%s ambient density scale must be between 0 and 3." % scope_label)
	if profile.speed_scale < 0.0 or profile.speed_scale > 2.0:
		errors.append("%s ambient speed scale must be between 0 and 2." % scope_label)
	if profile.highlight_share < 0.0 or profile.highlight_share > 1.0:
		errors.append("%s ambient highlight share must be between 0 and 1." % scope_label)
	if (
		profile.far_parallax < 0.0 or profile.far_parallax > 1.0
		or profile.middle_parallax < 0.0 or profile.middle_parallax > 1.0
		or profile.near_parallax < 0.0 or profile.near_parallax > 1.0
	):
		errors.append("%s ambient parallax factors must be between 0 and 1." % scope_label)
