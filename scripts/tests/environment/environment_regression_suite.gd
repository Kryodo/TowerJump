extends SceneTree
## Headless-friendly deterministic data/layout regression checks.
## Run with: godot --headless --path . --script res://scripts/tests/environment/environment_regression_suite.gd

const ZONE_PROFILE: EnvironmentZoneProfile = preload("res://resources/environment/zones/preview_diagnostic_zone.tres")
const EXPECTED_SEED: int = 7319
const EXPECTED_SIGNATURE: int = 0 # Updated after the first reviewed fixture manifest is generated.


func _initialize() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	var failures: Array[String] = []
	var seed_a := EnvironmentSeedResolver.section_seed(
		EXPECTED_SEED, ZONE_PROFILE.zone_id, &"lower_structure", &"height_1800_depth_0"
	)
	var seed_a_repeat := EnvironmentSeedResolver.section_seed(
		EXPECTED_SEED, ZONE_PROFILE.zone_id, &"lower_structure", &"height_1800_depth_0"
	)
	var seed_b := EnvironmentSeedResolver.section_seed(
		EXPECTED_SEED, ZONE_PROFILE.zone_id, &"lower_structure", &"height_3000_depth_0"
	)
	var landmark_seed := EnvironmentSeedResolver.landmark_seed(
		EXPECTED_SEED, ZONE_PROFILE.zone_id, &"resonance_gate", &"gate_neighborhood"
	)
	if seed_a != seed_a_repeat:
		failures.append("Stable section seed changed between identical requests.")
	if seed_a == seed_b:
		failures.append("Distinct stable section keys returned the same seed.")
	if landmark_seed <= 0:
		failures.append("Landmark seed must be positive.")

	var validation := EnvironmentProfileValidator.validate_zone(ZONE_PROFILE)
	for message in validation.errors:
		failures.append("Fixture validation: " + message)

	var plan_a := EnvironmentCompositionPlanner.build_plan(ZONE_PROFILE, EXPECTED_SEED)
	var plan_b := EnvironmentCompositionPlanner.build_plan(ZONE_PROFILE, EXPECTED_SEED)
	var signature_a := EnvironmentCompositionPlanner.plan_signature(plan_a)
	var signature_b := EnvironmentCompositionPlanner.plan_signature(plan_b)
	if signature_a != signature_b:
		failures.append("Identical seed/profile requests produced different composition signatures.")
	if EXPECTED_SIGNATURE != 0 and signature_a != EXPECTED_SIGNATURE:
		failures.append("Composition signature differs from the reviewed fixed-seed baseline.")
	if int(plan_a.get("landmark_count", 0)) != ZONE_PROFILE.landmark_anchors.size():
		failures.append("One or more fixed landmark anchors were not planned.")

	var reservations: Array[Rect2] = plan_a.get("reservations", [])
	for placement in plan_a.get("placements", []):
		var bounds: Rect2 = placement.clearance_rect
		for reservation in reservations:
			if bounds.intersects(reservation):
				failures.append("Module %s overlaps a fixed landmark reservation." % String(placement.definition.module_id))
				break

	if failures.is_empty():
		print("ENVIRONMENT REGRESSION PASS")
		print("Seed: %d | Plan signature: %d | Modules: %d | Landmarks: %d | Suppressed: %d" % [
			EXPECTED_SEED,
			signature_a,
			int(plan_a.get("placement_count", 0)),
			int(plan_a.get("landmark_count", 0)),
			int(plan_a.get("suppressed_count", 0)),
		])
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	print("ENVIRONMENT REGRESSION FAIL (%d issue(s))" % failures.size())
	quit(1)
