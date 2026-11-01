# Repository Organization and Validation

Last updated: 2026-11-01  
Branch: `chore/project-organization`  
Purpose: handoff record for the repository cleanup, folder moves, Godot resource migration, and warning-resolution pass.

## Baseline consolidation

- `experiment-vertical-resonance-field` was verified by the owner in Godot and merged into `main` through PR #5 on 2026-11-01.
- Merge commit: `c3d2cec38bccccbfb852eb8098750513e6d54785`.
- The merge preserved both source histories and uses the exact tree from the verified gameplay baseline.
- The old-main foundation and milestone/reference commits are preserved by user-created tags.
- Preserved environment-art reference branch: `experiment-middle-architecture-details` (do not rewrite it).

## Folder organization

The organization branch moved resources without deleting any binary image assets.

- Production scenes: `scenes/gameplay/`.
- Gameplay test scene: `scenes/tests/gameplay/`.
- Scripts grouped under `scripts/core/`, `player/`, `camera/`, `economy/`, `platform/`, `landing/`, `ui/`, and `tests/`.
- Shaders grouped under `shaders/player/`, `shaders/platform/`, and `shaders/ui/`; the currently unreferenced platform landing surface shader is retained under `shaders/platform/legacy/`.
- Active player and particle resources are in `assets/player/` and `assets/particles/`.
- Unreferenced historical images are retained in `assets/references/` or `assets/legacy/`; none were deleted.
- Moved Godot `.uid` sidecars remain paired with scripts/shaders. Asset `.import` files retain their UIDs and now point to the new `res://` source paths and matching imported-cache hashes.
- `project.godot` now starts `res://scenes/gameplay/main.tscn` and loads the GameManager autoload from `res://scripts/core/game_manager.gd`.

## Owner's initial validation

The owner confirmed:
- The reorganized project opens/runs in Godot after reloading scenes.
- The platform test room runs correctly.
- Godot performed additional resource sterilization/import updates, pushed in commit `3415ec87d0ced46b1dde6ab9bfaa9b12ee5fdbd3`.

This was the initial folder migration validation. The warning-cleanup source changes below still need a focused runtime retest.

## Warning cleanup pass

### `scripts/player/ball.gd`

Removed the local `Input.get_axis()` declaration that shadowed the class-level `input_direction`. The class variable is already populated by `_read_input_direction()`, which selects mobile touch or desktop keyboard input. The local shadow also overrode that resolved input. Movement now consistently consumes the existing input resolver result.

Commit: `b5b8da5bca364282b6a52dd35af79ff1a991c2e5`.

### `scripts/player/ball_trail.gd`

Renamed the local `material` variable in `_initialize_landing_impact_material()` to `landing_material` to avoid shadowing the inherited `CanvasItem.material` property.

Commit: `4a7d43ea9ead2166b103dd284b3f8940428acb97`.

### `scripts/platform/platform_resonance_field.gd`

Renamed exact local/parameter identifier `seed` to descriptive `random_seed` (with a separate `strand_seed` for the edge-filament base seed), avoiding the built-in `seed()` global name. Replaced integer midpoint division with explicit float arithmetic and integer conversion:
`int(float(points.size()) * 0.5)`.
This keeps the same midpoint selection for the five-point filament paths while silencing the integer-division warning.

Commits:
- `8e33ddf58c49a0c081b2f52762314fc6116648d5`
- `123f0de2c25cb1f8873879875f8e5db8375e31ab`

### `scripts/camera/camera_follow.gd` and platform test room

The production main scene has `LandingScoreController` and `LandingFeedbackController` as siblings of `GameCamera`, matching the camera's default relative NodePaths. The standalone platform test room intentionally has neither controller and was the source of the warning.

Added exported `landing_response_enabled` (default `true`). Production behavior remains enabled and the missing-controller warning remains as a diagnostic safeguard. The standalone platform test room explicitly sets `landing_response_enabled = false`, because landing camera response is not part of that isolated test.

Commits:
- `8079686e480b3c6207c00d5e017d3d84182884f7`
- `f368c2c428d6640afccf9c2ca37761919acd3675`

## Static verification

The final source audit confirms:
- No remaining local `input_direction` shadow.
- Ball movement uses the value populated by `_read_input_direction()`.
- Landing impact material local no longer shadows the base property.
- No bare `seed` identifier remains in the resonance script.
- Resonance midpoint uses explicit float division.
- Strand and cycle seeds use distinct variables.
- Camera landing response remains enabled by default.
- Production main scene contains both expected landing controllers.
- Test room explicitly opts out of the absent landing response.

Static checks passed. Godot parser/runtime verification has not been performed by the assistant.

## Next owner validation checklist

1. Fetch/pull `chore/project-organization` in GitHub Desktop.
2. Open `project.godot` in Godot 4.7.x and allow import/scan to finish.
3. Confirm the `CONFUSABLE_LOCAL_USAGE` and `SHADOWED_VARIABLE` warnings in ball.gd are gone.
4. Confirm the base-class `material` shadow warning in ball_trail.gd is gone.
5. Confirm all `SHADOWED_GLOBAL_IDENTIFIER` and `INTEGER_DIVISION` warnings in platform_resonance_field.gd are gone.
6. Run the main gameplay scene and verify desktop keyboard movement, mobile touch input assumptions, trail appearance, resonance field animation, and landing camera response.
7. Run `scenes/tests/gameplay/platform_test_room.tscn` and confirm the camera warning is absent and the test scene still functions.
8. Verify the Android export preset and inspect any new generated `.import` changes before committing them.

Only after this retest and export check should `chore/project-organization` be merged into `main`, followed by creation of `feature/environment-art-library-v1`.
