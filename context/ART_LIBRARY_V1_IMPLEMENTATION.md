# Art Library V1 — Implementation Notes

Last updated: 2026-11-02  
Status: **Reference extraction and preview parity corrections implemented at source level; Godot 4.7.x import/runtime and visual comparison pending.**

This document records implementation details. The masterplan remains the authoritative strategic scope and exit-criteria document.

---

## 1. Branch and repository boundaries

Repository: Kryodo/TowerJump

- Stable production baseline: main at d47ef2206a1326472de3ac1cc1a8a9f7ccda6baa.
- Active implementation branch: feature/environment-art-library-v1.
- Preserved architecture reference: experiment-middle-architecture-details at c8e212a93112bcc6acc990011bfa0974b64dec9a; read-only.
- All Art Library implementation changes are isolated to feature/environment-art-library-v1.
- No production gameplay files or scenes/gameplay/main.tscn have been changed for this work.

The branch was created from the same production baseline as main. The initial audit found that the organized production project had no environment-specific renderer or module library yet. The main production scene remains the actual entry point.

## 2. Production rendering integration

The production scene is scenes/gameplay/main.tscn, loaded by project.godot.

The existing scene owns the real ball, camera, platform/coin systems, WorldEnvironment/glow, dark navy background, and camera-attached ambient mote emitters. The Art Library compositor is not inserted into the production scene.

Full-Game Environment Jump-In uses a separate wrapper scene:

1. Instantiate the actual production main scene as a child of the wrapper.
2. Let the production scene finish its normal initialization, including recording the initial ball Y.
3. Offset the instantiated game root to the selected test height.
4. Add the environment compositor only to that instantiated game root.
5. Disable the existing ambient emitters only on that test instance, so the profile-driven motes do not double up.
6. Keep the production background below the architecture and the new ambient motes above the architecture.

The production game scene, player movement, physics, platform generation, scoring, camera script, and gameplay logic remain unchanged.

### Coordinate convention

Positive climb height zero is the production ball's initial local Y coordinate, 600 px. A positive climb height h therefore maps to local world Y 600 - h.

The composition planner uses this coordinate convention for modules and landmark anchors. The standalone preview camera is aligned to that ball-origin convention. The full-game wrapper applies its jump-in height as a local overlay offset, while the parent game root is shifted by the negative of the same amount; the environment geometry therefore lands at the intended absolute game-world height.

The approved ambient vertical parallax relationship remains:

| Layer | Parallax |
|---|---:|
| Far | 0.18 |
| Middle | 0.46 |
| Near | 0.82 |

## 3. Reused visual reference

The preserved experiment branch is a read-only visual/technical reference. Its comparison harness, palette controls, debug overlays, and test orchestration are not copied into the Art Library.

The reusable EnvironmentArchitectureLayer extracts the approved Far/Middle/Near drawing grammar, fixed A2 Integrated palette values, Compact Panel Flicker treatment, middle treatment C, section cadence, and deterministic per-layer seed behavior. The renderer retains the established proportions and geometry while taking theme and recipe resources as inputs. Resonance Gate and Archive Fragment are separate authored scenes positioned by fixed-height anchors; their local geometry and placement match the original study.

The reference parity fixture uses the exact original study window (-10400 to 1600 px), world width 720 px, A2 Integrated fills, Compact Panel Flicker, Insets + Mechanical Recesses, and fixed seeds. The comparison harness itself remains on the experiment branch and is not copied.

The diagnostic module scenes represent the approved visual vocabulary:

- Far aperture cluster: connected dark silhouette with deliberately grouped apertures/panels and a few dormant/subtle/neon states.
- Middle support inset: monumental fill, stepped inset, partial contour reveal, and a mechanical recess separated from the plate by at least 15 px.
- Near edge frame: sparse broken rails, intentionally low visual weight.
- Resonance Gate and Archive Fragment: independently authored landmark scene examples, kept separate from repeating modules.

The sample theme profiles are diagnostics. Navy Resonance reflects the established navy atmosphere; Amber Diagnostic exists to prove profile switching and is not a Zone 2 concept. No production zone or landmark selection is implied.

## 4. Data model

All model objects are typed Godot Resources.

| Resource | Main fields and responsibility |
|---|---|
| ArchitectureModuleDefinition | Stable module ID, family, depth layer, PackedScene, local visual bounds, clearance bounds, optional connection points. |
| EnvironmentThemeProfile | Far/middle fills, near detail, accent colors, dormant/subtle/neon structural-light colors. The global void color is not owned by the theme. |
| EnvironmentAmbientProfile | Mote tint, density, speed, highlight share, and Far/Middle/Near parallax factors. |
| EnvironmentLightingProfile | Seeded light-state distribution, intensity scaling, and optional restrained flicker. Flicker is disabled by default. |
| EnvironmentArchitectureRecipe | Stable recipe ID, ordered module pool, section step, and per-depth density values. |
| EnvironmentSubzoneProfile | Stable subzone ID, positive height range, recipe, optional theme/ambient/lighting overrides, and stable seed key. |
| EnvironmentLandmarkAnchor | Landmark ID, owning subzone, PackedScene, positive height anchor, local scene position, clearance rectangle, optional theme override, and stable neighborhood key. |
| EnvironmentZoneProfile | Zone ID, positive height range, default theme/ambient/lighting profiles, subzones, and landmark anchors. |

Null subzone overrides inherit the owning zone profile. The data model intentionally does not include a global world schedule, a generic transition framework, or an editor plugin.

## 5. Deterministic composition and reservations

EnvironmentCompositionPlanner builds an inspectable plan without creating scene nodes. The shared compositor, previews, and regression suite use that same plan.

For repeating sections, the planner derives seeds from:

- World seed.
- Stable zone ID.
- Explicit subzone seed key (falling back to the subzone ID when blank).
- Absolute height/depth section key.
- A stable side key for left/right placement.

Landmark neighborhoods derive seeds independently from the world seed, zone ID, landmark ID, and anchor neighborhood key. The resolver uses FNV-1a hashing over stable identities and does not consume or mutate the global random draw sequence.

The planner creates all landmark reservation rectangles before considering procedural module placements. A module whose clearance rectangle intersects a reserved landmark rectangle is suppressed. The plan exposes its placement list, landmark list, reservations, warnings/errors, placement count, and suppressed count.

EnvironmentProfileValidator checks zone and subzone ranges, duplicate IDs, subzone overlaps, recipes/module pools, module bounds/scenes, lighting state distributions, landmark scene/reservation data, and landmark membership/height within the assigned subzone.

The current layout algorithm is intentionally a small deterministic fixture composer: it selects from a recipe's pool per depth/section, places repeating modules toward the two sides (with one sparse near-layer placement), mirrors the right-hand module, and suppresses overlaps with fixed landmark reservations. This is a proof of the data flow and reservations, not a final general-purpose architecture grammar or connector-graph solver.

## 6. Shared compositor and ambient treatment

EnvironmentPreviewCompositor is the single renderer used by all three preview tools.

It:

- Builds the plan from the selected zone, world seed, and optional theme override.
- Instantiates the module scenes into Far/Middle/Near layers.
- Instantiates landmark scenes at fixed anchors.
- Applies the resolved structural-light state and module seed to each instance.
- Applies the active ambient profile's parallax factors.
- Creates three profile-driven ambient mote layers from the existing ambient mote texture.
- Uses ambient density, speed, tint, and highlight share. Highlight particles are a small separate fraction; they are not a new high-density effect system.
- Can disable the original game mote emitters on the full-game test instance only.

Optional structural flicker is a very restrained profile property, off by default. The reference parity recipe defaults to Compact Panel Flicker and middle treatment C, matching the approved reference. The current default reference fixture is not a new zone concept.

## 7. Preview tools

These are runnable test scenes, not editor plugins. They are deliberately lightweight and share the same resources/composition logic.

### Architecture Library Viewer

Scene: scenes/tests/environment/architecture_library_viewer.tscn

It browses the module/depth definitions and displays the selected depth using the actual extracted architecture grammar in a short vertical slice. It reports module ID, family, depth, visual bounds, clearance bounds, connection points, current theme, and fixed seed. It does not substitute the old narrow generic drawing fixtures for the established layer composition.

Controls:
- 1 / 2 / 3 or Left / Right: select module.
- T: cycle theme.
- R: cycle fixed seed.

### Zone and Subzone Preview

Scene: scenes/tests/environment/zone_subzone_preview.tscn

It previews the diagnostic zone vertically with Far/Middle/Near architecture and profile-driven ambient layers. The two structural subzones have intentional empty height intervals before/between/after them. The HUD identifies the current subzone/void, current height, next landmark, theme, seed, and plan counts.

Controls:
- Up / Down: move 400 px through the height sequence.
- Home: return to the initial 3600 px view.
- J: jump to the next landmark anchor.
- 1 / 2 / 3 or R: select/cycle the fixed seed.
- T: cycle the diagnostic theme.
- P: save a PNG capture to user://environment_regression/.

The screenshot capture is a manual visual comparison aid, not an automated pixel-golden regression.

### Full-Game Environment Jump-In

Scene: scenes/tests/environment/full_game_environment_jump_in.tscn

This wrapper instantiates the real scenes/gameplay/main.tscn and overlays the shared compositor inside the test instance. It retains the actual player, platform scene, camera, HUD/game rendering, and gameplay controls. The environment profile is tested at selected absolute climb heights.

Controls:
- 1 / 2 / 3: jump into 1800 / 5400 / 9600 px with the corresponding fixed seed.
- R: restart the current height and seed.
- N: choose a new seed and restart at the current height.
- T: cycle diagnostic theme.
- The real game’s existing movement controls remain available.

This is a preview-only test harness. It does not add environment integration to the production scene.

## 8. Fixed-seed regression support

The runner is scenes/tests/environment/environment_regression_suite.tscn, backed by scripts/tests/environment/environment_regression_suite.gd.

The baseline manifest is resources/environment/regression/preview_diagnostic_fixed_seeds.json. It contains three reviewed fixture cases:

| World seed | Plan signature | Modules | Landmarks | Suppressed by landmark reservations |
|---:|---:|---:|---:|---:|
| 7319 | 864963443 | 22 | 2 | 6 |
| 24017 | 3501769721 | 21 | 2 | 6 |
| 91207 | 81216545 | 21 | 2 | 6 |

The regression scene checks stable seed repeatability, distinct stable section keys, that changing an authored subzone seed key changes the composition, that changing a landmark neighborhood key changes its derived seed, profile validity, repeated plan-signature equality, manifest signature/count equality, and absence of module-clearance overlap with any landmark reservation.

Run after project import:

1. Open/import the project in Godot 4.7.x, or run godot --headless --editor --path . --quit.
2. Run godot --headless --path . res://scenes/tests/environment/environment_regression_suite.tscn.

The signatures were recalculated against the current stable-subzone-key and 600 px climb-origin planning contract. They have not yet been confirmed by running the GDScript regression scene in the Godot engine, so the first owner-side test run is the authoritative verification.

## 9. Diagnostic resource fixture inventory

- Themes: resources/environment/themes/navy_resonance.tres, resources/environment/themes/amber_diagnostic.tres.
- Ambient: resources/environment/ambient/default_motes.tres.
- Lighting: resources/environment/lighting/restrained_structural_lights.tres.
- Modules: resources/environment/modules/far_aperture_cluster.tres, middle_support_inset.tres, near_edge_frame.tres.
- Recipe: resources/environment/recipes/preview_vertical_grammar.tres.
- Subzones: resources/environment/subzones/preview_lower_structure.tres, preview_upper_structure.tres.
- Landmark anchors: resources/environment/landmarks/resonance_gate_anchor.tres, archive_fragment_anchor.tres.
- Zone fixture: resources/environment/zones/preview_diagnostic_zone.tres.

These files are scaffolding for exercising the pipeline. They are not the first production module inventory.

## 10. Validation status and handoff

### Completed by this implementation

- Repository audit and read-only classification of the preserved experiment.
- Typed Resource model and profile validation.
- Deterministic section/landmark seed resolver.
- Shared composition planner with fixed-height landmark clearance reservations.
- Three architecture module definitions and two landmark scenes, with the landmark local geometry restored to the original study.
- Diagnostic theme, ambient, lighting, recipe, subzone, landmark, and zone resources.
- Shared environment compositor.
- Architecture Library Viewer.
- Zone/Subzone Preview.
- Full-Game Environment Jump-In using the real production scene in a test-only wrapper.
- Three-case fixed-seed regression manifest and runnable regression scene, including parity-zone validity, exact reference section bounds, A2 fill values, landmark anchor positions, and treatment checks.
- Full-game parallax origin correction: when the test wrapper offsets the instantiated game root, local layer positions compensate for that offset so global parallax matches the original camera-relative behavior.
- Parity fixture uses dedicated Gate/Archive anchor resources bound to its single reference subzone; the original diagnostic anchor resources retain their lower/upper subzone ownership.
- Documentation of the model, controls, and validation workflow.

### Still required from the owner

Godot is not installed in the assistant execution environment, so no Godot 4.7.x import, script parser run, renderer run, or actual scene execution has been performed here. Source-level review and independent baseline calculations are not a substitute for engine validation.

After pulling the feature branch:

1. Open the project in Godot 4.7.x and allow the editor import/class registration pass to finish. Keep any generated .uid sidecars.
2. Run Architecture Library Viewer and check module display, bounds, theme/seed controls, and output warnings.
3. Run Zone/Subzone Preview and inspect the structure/void sequence, landmark clearance, theme/seed controls, motes, and PNG capture.
4. Run Full-Game Environment Jump-In and check alignment with the production ball/platform/camera/glow, no doubled ambient motes, and no gameplay regressions in the wrapper.
5. Run the headless regression scene and confirm all three manifest signatures/counts pass.
6. Fix any import/parser/runtime issues on this feature branch only.

### Work intentionally deferred

- Zone 1 and Zone 2 concepts, names, palettes, landmark choices, and full content.
- Production-scale module catalog and final recipes.
- A generic connector graph or complex architecture grammar.
- Integration into production main.tscn.
- Renderer golden-image automation, profiling at mobile scale, and Android export validation.
- Additional zones or full-game environment production.

Once the owner-side Phase 2 validation passes, the next design step is Zone 1 concept definition using the approved references. Then derive only the modules that concept needs. Zone 2 should follow as a genuinely different architecture/atmosphere, not as a recolor of the diagnostic amber theme.

