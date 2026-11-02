extends Node
## Deterministic reference-grammar regression checks.
## Run after project import with:
## godot --headless --path . res://scenes/tests/environment/environment_regression_suite.tscn

const ZONE_PROFILE: EnvironmentZoneProfile = preload("res://resources/environment/zones/reference_extraction_parity.tres")
const BASELINE_PATH: String = "res://resources/environment/regression/preview_diagnostic_fixed_seeds.json"
const REFERENCE_TOP_Y: float = -10400.0
const REFERENCE_BOTTOM_Y: float = 1600.0


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
		get_tree().quit(2)
		return
	var cases: Array = parsed_manifest.get("cases", [])
	if cases.is_empty():
		push_error("Environment regression baseline manifest contains no cases.")
		get_tree().quit(2)
		return

	var validation := EnvironmentProfileValidator.validate_zone(ZONE_PROFILE)
	for message in validation.get("errors", []):
		failures.append("Reference fixture validation: " + str(message))

	if ZONE_PROFILE.subzones.size() != 1:
		failures.append("Reference parity zone must contain exactly one full-height subzone.")
	if ZONE_PROFILE.landmark_anchors.size() != 2:
		failures.append("Reference parity zone must contain the Gate and Archive anchors.")

	# Full-game jump-in shifts the parent game root. The compositor's local
	# offset must still resolve to the same GLOBAL camera-relative parallax as
	# the preserved experiment at every supported depth and jump-in height.
	for jump_height in [0.0, 3600.0, 9600.0]:
		var camera_global_y := 640.0 - jump_height
		for parallax_factor in [0.18, 0.46, 0.82]:
			var local_y := EnvironmentPreviewCompositor.local_parallax_y(
				camera_global_y, parallax_factor, jump_height
			)
			var resolved_global_offset := local_y - jump_height
			var expected_global_offset := camera_global_y * (1.0 - parallax_factor)
			if not is_equal_approx(resolved_global_offset, expected_global_offset):
				failures.append(
					"Jump height %.0f / parallax %.2f: local origin conversion changed global parallax."
					% [jump_height, parallax_factor]
				)

	var theme := ZONE_PROFILE.theme_profile
	if theme != null:
		if (
			not is_equal_approx(theme.far_fill_a.r, 0.011764706)
			or not is_equal_approx(theme.far_fill_a.g, 0.03137255)
			or not is_equal_approx(theme.far_fill_a.b, 0.0627451)
		):
			failures.append("Navy theme far mass A no longer matches the established A2 fill.")
		if (
			not is_equal_approx(theme.middle_fill.r, 0.0055)
			or not is_equal_approx(theme.middle_fill.g, 0.0165)
			or not is_equal_approx(theme.middle_fill.b, 0.038)
		):
			failures.append("Navy theme middle fill no longer matches the established A2 fill.")

	for case_data in cases:
		var seed_value := int(case_data.get("seed", 0))
		var expected_signature := int(case_data.get("signature", -1))
		var expected_sections := int(case_data.get("sections", -1))
		var expected_landmarks := int(case_data.get("landmarks", -1))
		var expected_reservations := int(case_data.get("reservations", -1))

		if seed_value <= 0 or expected_signature < 0:
			failures.append("Baseline contains an invalid seed or signature.")
			continue

		var seed_a := EnvironmentSeedResolver.section_seed(
			seed_value, ZONE_PROFILE.zone_id, &"reference_full_composition", &"architecture_grammar"
		)
		var seed_a_repeat := EnvironmentSeedResolver.section_seed(
			seed_value, ZONE_PROFILE.zone_id, &"reference_full_composition", &"architecture_grammar"
		)
		var seed_b := EnvironmentSeedResolver.section_seed(
			seed_value, ZONE_PROFILE.zone_id, &"reference_full_composition", &"alternate_grammar_key"
		)
		var landmark_seed := EnvironmentSeedResolver.landmark_seed(
			seed_value, ZONE_PROFILE.zone_id, &"resonance_gate", &"gate_neighborhood"
		)
		var alternate_landmark_seed := EnvironmentSeedResolver.landmark_seed(
			seed_value, ZONE_PROFILE.zone_id, &"resonance_gate", &"alternate_neighborhood"
		)

		if seed_a != seed_a_repeat:
			failures.append("Seed %d: identical section requests returned different seeds." % seed_value)
		if seed_a == seed_b:
			failures.append("Seed %d: distinct stable section keys returned the same seed." % seed_value)
		if landmark_seed <= 0 or alternate_landmark_seed == landmark_seed:
			failures.append("Seed %d: landmark neighborhood identity is not affecting its seed." % seed_value)

		var plan_a := EnvironmentCompositionPlanner.build_plan(ZONE_PROFILE, seed_value)
		var plan_b := EnvironmentCompositionPlanner.build_plan(ZONE_PROFILE, seed_value)
		var signature_a := EnvironmentCompositionPlanner.plan_signature(plan_a)
		var signature_b := EnvironmentCompositionPlanner.plan_signature(plan_b)
		if signature_a != signature_b:
			failures.append("Seed %d: identical inputs produced different architecture signatures." % seed_value)
		if signature_a != expected_signature:
			failures.append(
				"Seed %d: signature %d differs from baseline %d." % [
					seed_value, signature_a, expected_signature
				]
			)
		if int(plan_a.get("section_count", 0)) != expected_sections:
			failures.append("Seed %d: architecture section count differs from baseline." % seed_value)
		if int(plan_a.get("landmark_count", 0)) != expected_landmarks:
			failures.append("Seed %d: landmark count differs from baseline." % seed_value)
		if int(plan_a.get("reservation_count", 0)) != expected_reservations:
			failures.append("Seed %d: landmark reservation count differs from baseline." % seed_value)

		var sections: Array = plan_a.get("architecture_sections", [])
		if not sections.is_empty():
			var section: Dictionary = sections[0]
			if int(section.get("architecture_seed", -1)) != seed_value:
				failures.append("Seed %d: the single-section parity recipe must retain the world seed unchanged." % seed_value)
			if not is_equal_approx(float(section.get("section_top_y", 0.0)), REFERENCE_TOP_Y):
				failures.append("Seed %d: extracted architecture top does not match the reference test window." % seed_value)
			if not is_equal_approx(float(section.get("section_bottom_y", 0.0)), REFERENCE_BOTTOM_Y):
				failures.append("Seed %d: extracted architecture bottom does not match the reference test window." % seed_value)
			var recipe: EnvironmentArchitectureRecipe = section.recipe
			if recipe.far_detail_treatment != EnvironmentArchitectureRecipe.FarDetailTreatment.COMPACT_PANEL_FLICKER:
				failures.append("Reference recipe must retain Compact Panel Flicker.")
			if recipe.middle_detail_treatment != EnvironmentArchitectureRecipe.MidDetailTreatment.INSETS_AND_MECHANICAL_RECESSES:
				failures.append("Reference recipe must retain middle treatment C.")

		var gate_found := false
		var archive_found := false
		for landmark in plan_a.get("landmarks", []):
			var anchor: EnvironmentLandmarkAnchor = landmark.anchor
			if anchor.landmark_id == &"resonance_gate":
				gate_found = is_equal_approx(float(landmark.root_position.y), -4280.0)
			elif anchor.landmark_id == &"archive_fragment":
				archive_found = is_equal_approx(float(landmark.root_position.y), -6680.0)
		if not gate_found:
			failures.append("Seed %d: Resonance Gate no longer occupies the established reference anchor." % seed_value)
		if not archive_found:
			failures.append("Seed %d: Archive Fragment no longer occupies the established reference anchor." % seed_value)

	if failures.is_empty():
		print("ENVIRONMENT REFERENCE REGRESSION PASS")
		print("Fixture: %s | Baseline cases: %d" % [
			String(parsed_manifest.get("fixture_id", "unknown")),
			cases.size(),
		])
		get_tree().quit(0)
		return

	for failure in failures:
		push_error(failure)
	print("ENVIRONMENT REFERENCE REGRESSION FAIL (%d issue(s))" % failures.size())
	get_tree().quit(1)
