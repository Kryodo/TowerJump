# Art Library V1 — Implementation Notes

Last updated: 2026-11-02  
Status: **Source-level audit and correction pass committed. Godot 4.7.x import, parser, and runtime validation still pending.**

The masterplan remains authoritative for strategic scope and Art Pipeline V1 exit criteria. This document records what the current implementation actually does, including the boundaries that earlier split-chat notes overstated. For the latest audit, bug fixes, source-level findings, and owner test checklist, see [ART_LIBRARY_V1_AUDIT_AND_FIXES.md](ART_LIBRARY_V1_AUDIT_AND_FIXES.md).

---

## 1. Branch and repository boundaries

Repository: Kryodo/TowerJump

- Stable production baseline: main at d47ef2206a1326472de3ac1cc1a8a9f7ccda6baa.
- Active implementation branch: feature/environment-art-library-v1.
- Preserved architecture reference: experiment-middle-architecture-details at c8e212a93112bcc6acc990011bfa0974b64dec9a; read-only.
- main, the preserved architecture branch, and existing gameplay scripts/scenes remain unchanged by this audit.
- The implementation remains test-only; scenes/gameplay/main.tscn does not instantiate the environment compositor.

## 2. Reference extraction and initial split-chat correction

The first implementation pass created a simplified drawing helper with narrow far/middle primitives and sparse near lines. That helper, scripts/environment/environment_architecture_module_visual.gd, is now removed from the current feature branch together with its .uid sidecar. There are no remaining scene/resource/script references to it; its historic commits remain in Git history.

The current renderer is scripts/environment/environment_architecture_layer.gd. It is an extraction/adaptation of the established renderer from experiment-middle-architecture-details, not a new three-primitive visual system.

The following method bodies were compared and remain identical to the reference implementation:

- _far_panel_left_x
- _draw_far_compact_panel_clusters
- _draw_compact_panel_light
- _mid_inset_plate_specs
- _draw_mid_stepped_inset
- _draw_mid_mechanical_recesses

Other shared drawing methods were adapted to consume EnvironmentThemeProfile and EnvironmentArchitectureRecipe fields while retaining the approved geometry, section rhythm, dimensions, and deterministic per-layer seed behavior. Experiment-only palette comparisons and diagnostic overlays were not copied into the current renderer.

The signature structures are separate authored scenes:

- scenes/environment/landmarks/resonance_gate.tscn
- scenes/environment/landmarks/archive_fragment.tscn

Their local geometry is based on the original study. The reference parity anchors retain the original world positions: Gate at 4,880 px (root local Y -4,280) and Archive Fragment at 7,280 px (root local Y -6,680), using the 600 px run origin.

## 3. Current Resource model

The current model consists of typed Godot Resources:

| Resource | Current responsibility |
|---|---|
| ArchitectureModuleDefinition | Stable ID, family, depth layer, PackedScene, local visual bounds, clearance bounds, optional connection points. |
| EnvironmentThemeProfile | Far/middle/near colors, far panel/recess and aperture materials, accent colors, and reserved generic light-state colors. Global navy void remains a scene/background responsibility. |
| EnvironmentAmbientProfile | Mote tint, density, speed, highlight share, and far/middle/near parallax factors. |
| EnvironmentLightingProfile | Seeded light-state share and optional flicker settings. These values are validated and can resolve a state/color, but are not yet consumed by the architecture renderer. |
| EnvironmentArchitectureRecipe | Stable recipe ID, module catalogue/pool, far/middle/near repeat spacing, bottom padding, and the approved far/middle detail treatments. |
| EnvironmentSubzoneProfile | Stable ID, positive climb-height range, recipe, optional theme/ambient/lighting profiles, stable seed key, and explicit reference-overdraw compatibility flag. |
| EnvironmentLandmarkAnchor | Landmark ID, owning subzone, PackedScene, absolute climb-height anchor, local position, clearance rectangle, optional theme override, stable neighborhood seed key. |
| EnvironmentZoneProfile | Zone ID/range, default theme/ambient/lighting resources, subzones, and landmark anchors. |

EnvironmentProfileValidator checks IDs, zone/subzone ranges and overlap, recipe values, module pool entries/bounds/scenes, profile ranges, landmark membership, and overlapping landmark reservations.

## 4. What the planner and compositor actually do

EnvironmentCompositionPlanner.build_plan() currently produces:

- One architecture_sections entry per valid subzone.
- Fixed landmark entries with resolved root positions, stable landmark seeds, and owning subzone.
- Landmark reservation rectangles.
- Errors/warnings and section/landmark/reservation counts.

The planner does not currently create individual module placements, calculate a connector graph, or suppress module placements against landmark reservations. There are no module-placement or suppressed-module counts in the current plan.

EnvironmentArchitectureRecipe.module_pool is currently the reusable module catalogue used by the Architecture Library Viewer and validator. The Zone/Subzone and Full-Game compositors render the established continuous Far/Middle/Near grammar through EnvironmentArchitectureLayer for each subzone, then place the authored landmark scenes on the matching middle layer. The ArchitectureModuleDefinition scenes are not yet used as individual zone-composition instances.

This is an intentional current boundary, not a completed modular placement system. Defer per-module placement, connector graphs, and module-clearance suppression until the first zone concept demonstrates what composition primitives are actually needed.

Seed behavior:

- A single-subzone reference parity fixture receives the world seed unchanged so it can reproduce the original study.
- Multi-subzone plans derive independent deterministic seeds from world seed, zone ID, stable subzone identity/key, and the architecture grammar key.
- Landmark neighborhood seeds are derived independently from world seed, zone ID, landmark ID, and stable anchor key.
- EnvironmentSeedResolver uses FNV-1a over stable identities and does not consume global random state.
- plan_signature() captures zone/seed, section identities/ranges/seeds/recipe IDs, and landmark IDs/anchors/seeds. It is a deterministic plan/layout check, not a pixel renderer checksum.

## 5. A1 / A2 palette profiles

The source reference contains two established structured far-detail palettes. Both now have complete theme resources and are consumed by the renderer.

### A2 Integrated — navy_resonance.tres

- Blue far masses and dark-blue middle fill.
- Blue-toned panel fill, edge, rails, frame, dormant fill, lit/neon aperture states, and halo.
- This is the default reference parity palette.

### A1 Depth — navy_depth_a1.tres

- Dark indigo/purple far masses with the brighter lifted blue-purple middle fill.
- Near-black structured panel fill and dormant aperture fill.
- Purple-toned panel edges/rails/frame, lit/neon states, and halo.
- Values are taken from FAR_STRUCTURED_A1 and the A1 dark-far/lifted-middle palette in the preserved renderer.

The extracted renderer's resolve_far_detail_palette() maps all eight far structured material fields from the selected theme. The regression suite checks both the stored resource values and the renderer's resolved palette.

### Amber Diagnostic — amber_diagnostic.tres

This remains a diagnostic profile to exercise theme switching. It is not a Zone 2 concept or an approved production palette.

All three preview tools cycle themes in this order:

1. A2 Integrated (navy_resonance)
2. A1 Depth (navy_depth_a1)
3. Amber Diagnostic (amber_diagnostic)

## 6. Preview tools and their actual inputs

These are runnable test scenes, not editor plugins.

### Architecture Library Viewer

Scene: scenes/tests/environment/architecture_library_viewer.tscn

The Viewer reads the selected ArchitectureModuleDefinition from the recipe's module_pool and now instantiates definition.scene directly. It no longer creates a generic renderer node while merely changing the displayed module ID.

The three current module preview scenes use EnvironmentArchitectureLayer with module_preview_mode = true:

- Far aperture cluster: one connected far mass with the compact aperture/panel treatment.
- Middle support inset: one established support/buttress with stepped inset and mechanical recess treatment.
- Near edge frame: one restrained near-layer edge rail, matching the original near layer's intentionally sparse visual language.

The viewer applies the selected theme, recipe, and fixed seed; it fits the actual scene using the module's declared local bounds. Middle and near bounds were corrected to match their preview extents. The viewer begins on the Far module.

Controls:

- 1 / 2 / 3 or Left / Right: select the module.
- T: cycle A2 / A1 / Amber Diagnostic.
- R: cycle the fixed seed.

Connection-point arrays are currently empty. There is no connector-attachment workflow yet.

### Zone and Subzone Preview

Scene: scenes/tests/environment/zone_subzone_preview.tscn

Its default profile is now resources/environment/zones/preview_diagnostic_zone.tres, which has:

- Lower structural subzone: 1,800–5,400 px.
- A deliberate 600 px gap: 5,400–6,000 px.
- Upper structural subzone: 6,000–11,400 px.
- Gate and Archive anchors owned by their corresponding subzones.

Normal subzones use bounded Far/Middle/Near rendering, so geometry remains inside each authored section window and cannot overdraw through the intended void interval. The isolated one-subzone reference fixture opts into the historical overdraw mode explicitly to preserve its original comparison window.

It uses the shared planner and compositor. The compositor draws the extracted layer grammar separately for each subzone and places the corresponding landmark scenes.

The standalone preview camera is centered on the production Camera2D run origin (Y=640), while positive climb-height zero still maps to the ball/world run origin (Y=600). The navy backdrop is aligned to the same camera center. This removes the previous 40 px camera/backdrop mismatch.

Controls:

- Up / Down: move through height in 400 px increments.
- Home: return to the initial 3,600 px view, clamped to the zone range.
- J: jump to the next landmark.
- 1 / 2 / 3 or R: select/cycle fixed seeds.
- T: cycle A2 / A1 / Amber Diagnostic.
- P: save a PNG under user://environment_regression/.

The HUD reports current zone/subzone/height, next landmark, theme, seed, section/landmark counts, and plan validation state.

### Full-Game Environment Jump-In

Scene: scenes/tests/environment/full_game_environment_jump_in.tscn

The default zone is reference_extraction_parity.tres, intentionally a single full-height subzone matching the original architecture study. It is separate from the two-subzone diagnostic fixture used by Zone/Subzone Preview.

The wrapper instantiates the actual scenes/gameplay/main.tscn as a test-only child and overlays the same environment compositor. It keeps the real player, camera, platforms, HUD, WorldEnvironment/glow, and movement controls.

**Important platform-spawn correction:** the wrapper now sets _game_root.position.y = -jump_in_height_px before calling add_child(_game_root). The production PlatformSpawner initializes its spawn cursor from the ball's global position in _ready(). Applying the transform before the scene enters the tree ensures the initial platform pool and the spawner's cached global spawn height use the same translated coordinate system. The production spawner and gameplay scripts were not changed.

On restart, the previous test root is freed before the next root is created, avoiding a frame where two platform pools could coexist.

Controls:

- 1 / 2 / 3: jump to 1,800 / 5,400 / 9,600 px using the corresponding fixed seeds.
- R: restart the current height/seed.
- N: choose a new seed and restart.
- T: cycle A2 / A1 / Amber Diagnostic.
- Normal game movement controls remain available.

The wrapper is a preview harness only. It does not modify production main.tscn or integrate the compositor into normal gameplay.

## 7. Ambient mote and parallax behavior

The approved ambient depth relationship remains:

- Far: 0.18
- Middle: 0.46
- Near: 0.82

Architecture horizontal parallax remains separate from mote parallax. The original mote layers use horizontal scroll factor 1.0; do not apply the architecture layers' 0.88 / 0.96 / 1.0 X factors to motes.

### Full-Game Jump-In

It adopts the three original production mote emitters and reparents them under Parallax2D wrappers, matching the preserved ambient_mote_parallax_test.gd approach.

The original emitter Z indices are retained (-30, -28, -29). The Parallax2D wrappers are siblings of the compositor under the gameplay root, matching the preserved reference hierarchy directly; they do not inherit the compositor's architecture Z-index or transform.

The active ambient profile updates the three wrappers' vertical scroll_scale factors when the camera enters a different subzone. It does not replace the production emitter material/texture in the full-game preview. The Jump-In HUD reports the mote source, number of adopted layers, and current factors; the expected production state is GAME 3/3 at 0.18 / 0.46 / 0.82.

### Standalone Zone Preview

There is no production game scene in this preview, so the compositor builds three lightweight Parallax2D emitter layers from the existing ambient mote texture and selected EnvironmentAmbientProfile. They use horizontal factor 1.0, the approved vertical factors, repeated vertical space, and controlled density/speed/scale/tint. This is a profile-driven preview approximation; the Full-Game Jump-In is the exact production-emitter comparison.

### Jump-in coordinate conversion

In Full-Game Jump-In the game root is translated by -J before children initialize. The architecture layer also adds +J to its world draw coordinates, and those coordinates are scaled by the layer's parallax factor p.

The compositor therefore resolves the required local layer offset as:

local_y = (camera_global_y + J) * (1 - p)

The regression suite checks the combined global result:

local_y - J + J * p = camera_global_y * (1 - p)

for jump heights 0, 3,600, and 9,600 px at parallax factors 0.18, 0.46, and 0.82.

## 8. Regression suite and baseline manifest

Runner: scenes/tests/environment/environment_regression_suite.tscn  
Script: scripts/tests/environment/environment_regression_suite.gd  
Manifest: resources/environment/regression/preview_diagnostic_fixed_seeds.json

The reference-parity manifest contains three cases:

| World seed | Plan signature | Sections | Landmarks | Reservations |
|---:|---:|---:|---:|---:|
| 7,319 | 443631857 | 1 | 2 | 2 |
| 24,017 | 1174694490 | 1 | 2 | 2 |
| 91,207 | 2059592232 | 1 | 2 | 2 |

The suite checks:

- Reference fixture validation and one-subzone structure.
- Reference section top/bottom coordinates, detail treatments, and preserved single-subzone seed behavior.
- Gate and Archive anchor positions and subzone ownership.
- Stable seed resolution and repeated plan signatures across the three manifest seeds.
- A1/A2 theme fill values and all eight structured far material fields.
- The renderer's actual A1/A2 far-palette resolution.
- The two-subzone diagnostic zone, its intentional 600 px gap, bounded renderer window coordinates, deterministic repeated planning, and independent stable subzone seeds.
- The reference-only overdraw flag is enabled only for the one-subzone parity fixture and disabled for both diagnostic subzones.
- Full jump-in parent/draw-coordinate parallax conversion for the three jump heights and three depth factors.

This remains a plan/resource/coordinate regression. It does not prove rendering pixels, platform collision/spawn spacing at runtime, particle appearance, or Android export.

Run after the project import/class registration pass:

1. Open the project once in Godot 4.7.x, or run godot --headless --editor --path . --quit.
2. Run godot --headless --path . res://scenes/tests/environment/environment_regression_suite.tscn.

The owner-side engine run is still required; these source changes have not been executed in Godot by the assistant.

## 9. Deliberately incomplete capabilities

The following are not complete and should not be claimed as implemented:

1. **Individual module composition:** module definitions and pools exist, and the Viewer instantiates the module scenes, but the zone planner/compositor currently uses the continuous extracted architecture grammar per subzone. It does not place individual PackedScene modules into zone compositions.
2. **Module reservation suppression:** landmark clearance rectangles are validated and included in the plan, but there are no individual module placements to test against them yet. The original continuous architecture is still drawn behind the separately authored landmarks, matching the reference experiment.
3. **Connector graph/attachments:** connection-point metadata exists but is empty and unused.
4. **Lighting profile integration:** EnvironmentLightingProfile is a data model with validation and deterministic state/color methods, but the extracted architecture renderer does not yet call those methods. Its established aperture state distribution and Compact Panel Flicker remain controlled by the extracted renderer and recipe. Keep this behavior until a deliberate zone concept/test justifies replacing it.
5. **Production-zone content:** preview_diagnostic_zone and reference_extraction_parity are fixtures, not Zone 1 or Zone 2.
6. **Automated visual golden tests, mobile performance profiling, and Android export:** not yet performed.

Do not fill these gaps by adding a generic architecture framework before Zone 1 has established concrete requirements. Preserve the current reference-parity path and derive the next abstraction from a real zone concept.

## 10. Owner-side Godot validation checklist

The source audit is complete, but the runtime/visual pass remains with the project owner.

1. Fetch the latest feature/environment-art-library-v1 in GitHub Desktop and open it in Godot 4.7.x. Let the import and global class registration pass finish.
2. Run the regression scene. Confirm there are no parser/type/resource errors and it prints ENVIRONMENT REFERENCE REGRESSION PASS.
3. Run Architecture Library Viewer:
   - Verify Far, Middle, and Near are actual different module scenes, not the old narrow generic primitives.
   - Check centering/bounds, especially the tall Far mass, support/recess Middle structure, and intentionally sparse Near rail.
   - Cycle A2 → A1 → Amber and fixed seeds.
4. Run Zone/Subzone Preview:
   - Confirm lower and upper structures, void before/between/after, Gate ownership in the lower subzone, Archive ownership in the upper subzone.
   - Check no 40 px camera/backdrop offset.
   - Cycle A2 → A1 → Amber. A1 should show darker near-black far recess/panel fills and purple-tinted aperture states; A2 should remain blue.
   - Check mote parallax and profile changes across subzones; check the plan validation HUD and PNG capture.
5. Run Full-Game Jump-In:
   - Test all three height presets and repeated restarts.
   - Verify initial platforms are placed relative to the translated ball/spawn cursor and normal platform recycling continues. The HUD's platform AABB overlap-pair count should remain 0; report the height/seed if it is positive.
   - Verify ball, platforms, camera, HUD, and architecture share the intended world position.
   - Compare the three original mote emitters against the preserved experiment: GAME 3/3 adopted, far/middle/near factors 0.18/0.46/0.82, and original depth ordering above architecture.
   - Cycle A2/A1/Amber and verify the far fill, recesses, and aperture lighting actually change.
   - Confirm no doubled mote emitters.
6. Run normal gameplay after closing the test scene to confirm the production scene remains unaffected.
7. Android export validation remains a separate future check.

Only after this owner-side pass should the next phase proceed to Zone 1 concept and its requirements.
