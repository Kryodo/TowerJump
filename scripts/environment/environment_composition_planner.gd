class_name EnvironmentCompositionPlanner
extends RefCounted
## Builds a deterministic placement plan without creating scene nodes.
## Previews and regression tests consume the same plan.

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
	var placements: Array[Dictionary] = []
	var landmarks: Array[Dictionary] = []
	var reservations: Array[Rect2] = []

	if not errors.is_empty():
		return _make_result(zone, world_seed, placements, landmarks, reservations, errors, warnings)

	# Landmark reservations are established before any procedural module is considered.
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

	var suppressed_count := 0
	for subzone in zone.subzones:
		var recipe := subzone.architecture_recipe
		var stable_subzone_key: StringName = subzone.seed_key if not String(subzone.seed_key).is_empty() else subzone.subzone_id
		if recipe == null:
			continue
		var theme := _resolve_theme(zone, subzone, theme_override)
		var lighting := _resolve_lighting(zone, subzone)
		var step_px := maxf(recipe.section_step_px, 200.0)
		var section_count := int(ceil((subzone.end_height_px - subzone.start_height_px) / step_px))

		for section_index in range(section_count):
			var section_height := subzone.start_height_px + float(section_index) * step_px
			if section_height >= subzone.end_height_px:
				continue
			for depth in range(3):
				var density := _density_for_depth(recipe, depth)
				var candidates := _modules_for_depth(recipe, depth)
				if candidates.is_empty() or density <= 0.0:
					continue

				var stable_key := StringName("height_%d_depth_%d" % [roundi(section_height), depth])
				var section_seed := EnvironmentSeedResolver.section_seed(
					world_seed,
					zone.zone_id,
					stable_subzone_key,
					stable_key
				)
				var density_roll := float(posmod(section_seed, 10000)) / 10000.0
				if density_roll >= density:
					continue

				var module: ArchitectureModuleDefinition = candidates[posmod(section_seed, candidates.size())]
				var side_count := 1 if depth == ArchitectureModuleDefinition.DepthLayer.NEAR else 2
				for side_index in range(side_count):
					var side_key := StringName("%s_side_%d" % [String(stable_key), side_index])
					var side_seed := EnvironmentSeedResolver.section_seed(
						world_seed,
						zone.zone_id,
						stable_subzone_key,
						side_key
					)
					var mirrored := false
					var root_x := 0.0
					if depth == ArchitectureModuleDefinition.DepthLayer.NEAR:
						mirrored = posmod(side_seed, 2) == 1
						root_x = 720.0 if mirrored else 0.0
					else:
						mirrored = side_index == 1
						root_x = 720.0 if mirrored else 0.0

					var y_jitter := float(posmod(side_seed, 41)) - 20.0
					var root_position := Vector2(root_x, RUN_ORIGIN_WORLD_Y - section_height + y_jitter)
					var clearance := _module_clearance_rect(module, root_position, mirrored)
					var blocked := false
					for reservation in reservations:
						if clearance.intersects(reservation):
							blocked = true
							break
					if blocked:
						suppressed_count += 1
						continue

					placements.append({
						"definition": module,
						"root_position": root_position,
						"mirror_x": mirrored,
						"height_anchor_px": section_height,
						"subzone_id": subzone.subzone_id,
						"section_key": stable_key,
						"seed": side_seed,
						"light_state": lighting.state_for_seed(side_seed) if lighting != null else EnvironmentLightingProfile.LightState.DORMANT,
						"theme_profile": theme,
						"lighting_profile": lighting,
						"clearance_rect": clearance,
					})

	return _make_result(
		zone,
		world_seed,
		placements,
		landmarks,
		reservations,
		errors,
		warnings,
		suppressed_count
	)


static func plan_signature(plan: Dictionary) -> int:
	var lines := PackedStringArray()
	lines.append("zone=%s|seed=%d" % [
		String(plan.get("zone_id", "")),
		int(plan.get("world_seed", 0)),
	])
	for placement in plan.get("placements", []):
		var definition: ArchitectureModuleDefinition = placement.definition
		lines.append("M|%s|%s|%d|%d|%d|%d|%s" % [
			String(definition.module_id),
			String(placement.subzone_id),
			int(placement.height_anchor_px),
			roundi(placement.root_position.x),
			roundi(placement.root_position.y),
			int(placement.seed),
			String(placement.section_key),
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
	placements: Array[Dictionary],
	landmarks: Array[Dictionary],
	reservations: Array[Rect2],
	errors: Array[String],
	warnings: Array[String],
	suppressed_count: int = 0
) -> Dictionary:
	return {
		"zone_id": String(zone.zone_id) if zone != null else "",
		"world_seed": world_seed,
		"placements": placements,
		"landmarks": landmarks,
		"reservations": reservations,
		"errors": errors,
		"warnings": warnings,
		"suppressed_count": suppressed_count,
		"placement_count": placements.size(),
		"landmark_count": landmarks.size(),
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


static func _resolve_lighting(
	zone: EnvironmentZoneProfile,
	subzone: EnvironmentSubzoneProfile
) -> EnvironmentLightingProfile:
	if subzone != null and subzone.lighting_profile != null:
		return subzone.lighting_profile
	return zone.lighting_profile


static func _modules_for_depth(
	recipe: EnvironmentArchitectureRecipe,
	depth: int
) -> Array[ArchitectureModuleDefinition]:
	var result: Array[ArchitectureModuleDefinition] = []
	for module in recipe.module_pool:
		if module != null and module.depth_layer == depth:
			result.append(module)
	return result


static func _density_for_depth(recipe: EnvironmentArchitectureRecipe, depth: int) -> float:
	match depth:
		ArchitectureModuleDefinition.DepthLayer.FAR:
			return recipe.far_density
		ArchitectureModuleDefinition.DepthLayer.NEAR:
			return recipe.near_density
		_:
			return recipe.middle_density


static func _module_clearance_rect(
	module: ArchitectureModuleDefinition,
	root_position: Vector2,
	mirrored: bool
) -> Rect2:
	var local_rect := module.clearance_bounds
	if local_rect.size.x <= 0.0 or local_rect.size.y <= 0.0:
		local_rect = module.local_bounds
	var world_x := root_position.x - local_rect.position.x - local_rect.size.x if mirrored else root_position.x + local_rect.position.x
	return Rect2(
		Vector2(world_x, root_position.y + local_rect.position.y),
		local_rect.size
	)
