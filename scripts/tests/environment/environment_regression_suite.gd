extends Node
## Headless-friendly deterministic data/layout regression checks.
## Run after project import with:
## godot --headless --path . res://scenes/tests/environment/environment_regression_suite.tscn

const ZONE_PROFILE: EnvironmentZoneProfile = preload("res://resources/environment/zones/preview_diagnostic_zone.tres")
const BASELINE_PATH: String = "res://resources/environment/regression/preview_diagnostic_fixed_seeds.json"


func _ready() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	var failures: Array[String] = []
	var manifest_text := FileAccess.get_file_as_string(BASELINE_PATH)
	if manifest_text.is_empty():
		push_error("Environment regression baseline manifest is missing or empty.")
		get_tree().quit(2)
		return

	var parsed_manifest: Variant = JSON.parse_string(manifest_text)
	if not (parsed_manifest is Dictionary):
		push_error("Environment regression baseline manifest is not a JSON object.")
		quit(2)
		return
	var cases: Array = parsed_manifest.get("cases", [])
	if cases.is_empty():
		push_error("Environment regression baseline manifest contains no cases.")
		quit(2)
		return

	var validation := EnvironmentProfileValidator.validate_zone(ZONE_PROFILE)
	for message in validation.get("errors", []):
		failures.append("Fixture validation: " + str(message))

	for case_data in cases:
		var seed_value := int(case_data.get("seed", 0))
		var expected_signature := int(case_data.get("signature", -1))
		var expected_placements := int(case_data.get("placements", -1))
		var expected_landmarks := int(case_data.get("landmarks", -1))
		var expected_suppressed := int(case_data.get("suppressed", -1))

		if seed_value <= 0 or expected_signature < 0:
			failures.append("Baseline contains an invalid seed or signature.")
			continue

		var seed_a := EnvironmentSeedResolver.section_seed(
			seed_value, ZONE_PROFILE.zone_id, &"lower_structure", &"height_1800_depth_0"
		)
		var seed_a_repeat := EnvironmentSeedResolver.section_seed(
			seed_value, ZONE_PROFILE.zone_id, &"lower_structure", &"height_1800_depth_0"
		)
		var seed_b := EnvironmentSeedResolver.section_seed(
			seed_value, ZONE_PROFILE.zone_id, &"lower_structure", &"height_3000_depth_0"
		)
		var landmark_seed := EnvironmentSeedResolver.landmark_seed(
			seed_value, ZONE_PROFILE.zone_id, &"resonance_gate", &"gate_neighborhood"
		)
		if seed_a != seed_a_repeat:
			failures.append("Seed %d: identical section requests returned different seeds." % seed_value)
		if seed_a == seed_b:
			failures.append("Seed %d: distinct stable section keys returned the same seed." % seed_value)
		if landmark_seed <= 0:
			failures.append("Seed %d: landmark seed is not positive." % seed_value)

		var plan_a := EnvironmentCompositionPlanner.build_plan(ZONE_PROFILE, seed_value)
		var plan_b := EnvironmentCompositionPlanner.build_plan(ZONE_PROFILE, seed_value)
		var signature_a := EnvironmentCompositionPlanner.plan_signature(plan_a)
		var signature_b := EnvironmentCompositionPlanner.plan_signature(plan_b)
		if signature_a != signature_b:
			failures.append("Seed %d: identical inputs produced different plan signatures." % seed_value)
		if signature_a != expected_signature:
			failures.append(
				"Seed %d: signature %d differs from baseline %d." % [
					seed_value, signature_a, expected_signature
				]
			)
		if int(plan_a.get("placement_count", 0)) != expected_placements:
			failures.append("Seed %d: module placement count differs from baseline." % seed_value)
		if int(plan_a.get("landmark_count", 0)) != expected_landmarks:
			failures.append("Seed %d: landmark count differs from baseline." % seed_value)
		if int(plan_a.get("suppressed_count", 0)) != expected_suppressed:
			failures.append("Seed %d: landmark reservation suppression count differs from baseline." % seed_value)

		var reservations: Array[Rect2] = []
		for reservation_value in plan_a.get("reservations", []):
			var reservation: Rect2 = reservation_value
			reservations.append(reservation)
		for placement in plan_a.get("placements", []):
			var bounds: Rect2 = placement.clearance_rect
			for reservation in reservations:
				if bounds.intersects(reservation):
					failures.append(
						"Seed %d: module %s overlaps a fixed landmark reservation." % [
							seed_value, String(placement.definition.module_id)
						]
					)
					break

	if failures.is_empty():
		print("ENVIRONMENT REGRESSION PASS")
		print("Fixture: %s | Baseline cases: %d" % [
			String(parsed_manifest.get("fixture_id", "unknown")),
			cases.size(),
		])
		get_tree().quit(0)
		return

	for failure in failures:
		push_error(failure)
	print("ENVIRONMENT REGRESSION FAIL (%d issue(s))" % failures.size())
	get_tree().quit(1)
