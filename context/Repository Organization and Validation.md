# Repository Organization and Validation

Last updated: 2026-11-02  
Status: **COMPLETED — merged into \`main\` and runtime-verified by the owner.**

Purpose: historical record of the baseline consolidation, repository folder migration, Godot resource-path updates, warning-resolution pass, and final validation.

## Current repository state

- Stable baseline: \`main\`.
- Current baseline commit: \`d47ef2206a1326472de3ac1cc1a8a9f7ccda6baa\`.
- Organization and warning-cleanup PR: [#6 — Organize project structure and resolve Godot warnings](https://github.com/Kryodo/TowerJump/pull/6).
- PR #6 was merged on 2026-11-01. Its merge commit is \`d47ef2206a1326472de3ac1cc1a8a9f7ccda6baa\`.
- Active Art Library development branch: \`feature/environment-art-library-v1\`, created from the same commit as \`main\`.
- The owner subsequently confirmed that the game runs correctly in Godot with no errors or warnings after the warning-cleanup changes.
- The milestone tags \`milestone/gameplay-baseline-v1\` and \`milestone/project-organization-v1\` are present and pushed.
- Retired branches: \`experiment-vertical-resonance-field\`, \`chore/project-organization\`, and \`merge/gameplay-baseline-to-main\`.
- Preserved environment reference: \`experiment-middle-architecture-details\`. Keep it untouched.
- Other preserved branches include \`experiment-forward-assembly-platforms\`, \`experiment-plant-bank-jumping\`, \`experiment-unified-comet-shape\`, and \`feature/combo-system-prototype\`.

## Baseline consolidation

- \`experiment-vertical-resonance-field\` was verified by the owner in Godot and merged into \`main\` through PR #5 on 2026-11-01.
- The verified gameplay-baseline merge commit was \`c3d2cec38bccccbfb852eb8098750513e6d54785\`.
- The merge preserved both source histories and used the exact tree from the verified gameplay baseline.
- The temporary \`merge/gameplay-baseline-to-main\` branch was used to create the proper two-parent integration commit after independent Godot sterilization metadata caused the initial direct merge attempt to conflict.
- The gameplay baseline is preserved by \`milestone/gameplay-baseline-v1\`, which points to the verified \`experiment-vertical-resonance-field\` head.
- PR #5 merged the baseline into \`main\`; the temporary integration branch was later retired.

## Folder organization

The organization work moved resources without deleting any binary image assets.

- Production scenes: \`scenes/gameplay/\`.
- Gameplay test scene: \`scenes/tests/gameplay/\`.
- Scripts grouped under \`scripts/core/\`, \`scripts/player/\`, \`scripts/camera/\`, \`scripts/economy/\`, \`scripts/platform/\`, \`scripts/landing/\`, \`scripts/ui/\`, and \`scripts/tests/\`.
- Shaders grouped under \`shaders/player/\`, \`shaders/platform/\`, and \`shaders/ui/\`; the currently unreferenced platform landing surface shader is retained under \`shaders/platform/legacy/\`.
- Active player and particle resources are in \`assets/player/\` and \`assets/particles/\`.
- Unreferenced historical images are retained in \`assets/references/\` or \`assets/legacy/\`; none were deleted.
- Moved Godot \`.uid\` sidecars remain paired with scripts/shaders. Asset \`.import\` files retain their UIDs and point to the new \`res://\` source paths and matching imported-cache hashes.
- \`project.godot\` starts \`res://scenes/gameplay/main.tscn\` and loads the GameManager autoload from \`res://scripts/core/game_manager.gd\`.
- The user also pushed subsequent Godot import/sterilization updates in commit \`3415ec87d0ced46b1dde6ab9bfaa9b12ee5fdbd3\`; these were included in the validated branch history.

## Warning cleanup pass

The following source changes were included in PR #6 and subsequently retested by the owner.

### \`scripts/player/ball.gd\`

Removed the local \`Input.get_axis()\` declaration that shadowed the class-level \`input_direction\`. The class variable is populated by \`_read_input_direction()\`, which resolves mobile touch or desktop keyboard input. The local shadow had overridden that resolved input. Movement now consistently consumes the existing input resolver result.

Commit: \`b5b8da5bca364282b6a52dd35af79ff1a991c2e5\`.

### \`scripts/player/ball_trail.gd\`

Renamed the local \`material\` variable in \`_initialize_landing_impact_material()\` to \`landing_material\` to avoid shadowing the inherited \`CanvasItem.material\` property.

Commit: \`4a7d43ea9ead2166b103dd284b3f8940428acb97\`.

### \`scripts/platform/platform_resonance_field.gd\`

Renamed exact local/parameter identifier \`seed\` to descriptive \`random_seed\` (with a separate \`strand_seed\` for the edge-filament base seed), avoiding the built-in \`seed()\` global name. Replaced integer midpoint division with explicit float arithmetic and integer conversion:

\`int(float(points.size()) * 0.5)\`

This preserves the intended midpoint selection for the five-point filament paths while avoiding the integer-division warning.

Commits:
- \`8e33ddf58c49a0c081b2f52762314fc6116648d5\`
- \`123f0de2c25cb1f8873879875f8e5db8375e31ab\`

### \`scripts/camera/camera_follow.gd\` and platform test room

The production main scene has \`LandingScoreController\` and \`LandingFeedbackController\` as siblings of \`GameCamera\`, matching the camera's default relative NodePaths. The standalone platform test room intentionally has neither controller and was the source of the warning.

Added exported \`landing_response_enabled\` (default \`true\`). Production behavior remains enabled and the missing-controller warning remains as a diagnostic safeguard. The standalone platform test room explicitly sets \`landing_response_enabled = false\`, because landing camera response is not part of that isolated test.

Commits:
- \`8079686e480b3c6207c00d5e017d3d84182884f7\`
- \`f368c2c428d6640afccf9c2ca37761919acd3675\`

## Owner runtime validation — completed

The owner confirmed after pulling/testing the warning-cleanup branch that:

- The main game runs correctly.
- No errors or warnings remain in the tested Godot project.
- The platform test room runs correctly.
- The input, trail, resonance-field, and landing camera behavior are functioning as expected.

This is an owner-performed runtime validation, not an assistant-performed Godot run.

A separate Android export result is not recorded in this validation note; do not assume export validation solely from the successful editor/runtime test.

## Static source verification

The source audit before the owner retest confirmed:

- No remaining local \`input_direction\` shadow.
- Ball movement uses the value populated by \`_read_input_direction()\`.
- Landing impact material local no longer shadows the base property.
- No bare \`seed\` identifier remains in the resonance script.
- Resonance midpoint uses explicit float division.
- Strand and cycle seeds use distinct variables.
- Camera landing response remains enabled by default.
- Production main scene contains both expected landing controllers.
- Test room explicitly opts out of the absent landing response.
- Resource paths, scene locations, and UID sidecars were checked after the folder migration.

The owner runtime retest closed the remaining validation requirement for the merge.

## Organization milestone and tags

The organization and warning-cleanup milestone is tagged as:

- \`milestone/project-organization-v1\` → \`d47ef2206a1326472de3ac1cc1a8a9f7ccda6baa\`.

The gameplay baseline milestone is tagged as:

- \`milestone/gameplay-baseline-v1\` → annotated tag object resolving to verified commit \`2b57faf68de98ace8221e8b233152214a334388b\`.

The organization merge was completed through PR #6:

- PR: https://github.com/Kryodo/TowerJump/pull/6
- Merge commit: \`d47ef2206a1326472de3ac1cc1a8a9f7ccda6baa\`.

## Result

Repository organization, resource migration, warning cleanup, owner runtime verification, merge into \`main\`, milestone tagging, and obsolete-branch cleanup are complete.

The next implementation work is intentionally separated onto \`feature/environment-art-library-v1\`. See \`context/ART_PIPELINE_MASTERPLAN.md\` for the bounded two-zone Art Pipeline V1 plan.
