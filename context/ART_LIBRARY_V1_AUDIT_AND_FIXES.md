# Art Library V1 — Audit and Repair Handoff

Last updated: 2026-11-02  
Working branch: \`feature/environment-art-library-v1\`  
Status: **Source audit and repair pass committed; owner-side Godot 4.7.x validation required.**

This note records the audit after the first Art Library handoff was split across two chats. The full data-model/tool implementation is described in [ART_LIBRARY_V1_IMPLEMENTATION.md](ART_LIBRARY_V1_IMPLEMENTATION.md); the strategic scope and exit criteria remain in [ART_PIPELINE_MASTERPLAN.md](ART_PIPELINE_MASTERPLAN.md).

## 1. Split-chat history and the key correction

The first implementation pass created simplified, narrow Far and Middle primitives plus sparse Near lines, with simple seed-based placement. Those primitives did not reproduce the approved architectural system and the initial navy profile did not reproduce the A2 Integrated far/middle palette relationship.

The later repair pass replaced that simplification with the established architecture renderer extracted/adapted from the preserved read-only branch:

- Reference renderer: \`experiment-middle-architecture-details\`
- Current Art Library renderer: \`scripts/environment/environment_architecture_layer.gd\`
- The obsolete simplified helper \`scripts/environment/environment_architecture_module_visual.gd\` and its UID sidecar are absent from the current branch; no current resource or scene references remain.

The following high-value geometry/material methods were compared directly with the preserved renderer and have identical method bodies:

- \`_far_panel_left_x\`
- \`_draw_far_compact_panel_clusters\`
- \`_draw_compact_panel_light\`
- \`_mid_inset_plate_specs\`
- \`_draw_mid_stepped_inset\`
- \`_draw_mid_mechanical_recesses\`

Other shared methods retain the approved architecture geometry, proportions, and repetition logic while accepting theme/recipe resources. The current renderer intentionally omits experiment-only palette/debug overlays.

## 2. Corrections made in this audit

### Regression suite typing

The three reported GDScript inference errors in \`environment_regression_suite.gd\` are already resolved on the current feature branch. These values now have explicit types:

- \`camera_global_y: float\`
- \`resolved_global_offset: float\`
- \`expected_global_offset: float\`

This was a source check; the suite still needs to run in Godot.

### Zone/subzone geometry bleeding across void gaps

A real source issue was found. The diagnostic zone declared a 600 px void gap between 5,400 and 6,000 px, but the extracted renderer's generic drawing loops intentionally overdraw beyond a section window:

- Far silhouettes started 900 px before the section top.
- Middle supports continued more than 1,000 px beyond the section bottom.
- Near rails could also extend past the section end.
- The recipe's 1,000 px bottom padding added more overdraw.

That behavior is needed to reproduce the original isolated full-window reference, but it is not suitable for independent bounded subzones. It could visually bridge the diagnostic void and overlap adjacent subzone compositions.

The fix preserves both modes explicitly:

- \`EnvironmentSubzoneProfile.preserve_reference_overdraw\` defaults to \`false\`.
- Normal subzones now resolve their renderer bottom to the actual authored subzone start-height boundary and use bounded Far/Middle/Near draw paths. Each structure/rail is only drawn when its full vertical extent fits inside that subzone window.
- The one-subzone \`reference_full_composition\` fixture explicitly opts into \`preserve_reference_overdraw = true\`, preserving its original top/bottom window and parity behavior.
- The validator warns if reference overdraw is enabled in a multi-subzone zone.
- The regression suite asserts both the reference opt-in and the bounded diagnostic section coordinates.

Expected bounded diagnostic renderer windows:
- Lower: top \`-4800\`, bottom \`-1200\`.
- Upper: top \`-10800\`, bottom \`-5400\`.

The 600 px authored void interval remains between climb heights 5,400 and 6,000 px. Actual visual appearance still needs owner verification.

### Architecture Library Viewer

The Viewer now instantiates the actual \`PackedScene\` from each \`ArchitectureModuleDefinition\` in the recipe's module pool. It no longer creates a generic renderer and merely changes a displayed module ID.

The middle module's local visual bounds were too large and shifted/scaled the actual support away from the intended inspection center. They are now tightened to:

\`Rect2(-30, 118, 224, 1056)\`

This covers the index-0 support preview with a small stroke margin. Its clearance bounds remain intentionally larger. Far and Near bounds remain distinct: the Far module represents a connected mass/panel unit; Near is intentionally a sparse edge rail, not another filled architecture mass.

### A1 / A2 palette resources

The source resources and renderer resolver are both wired and covered by regression assertions:

- **A2 Integrated — \`navy_resonance\`:** blue far masses, dark-blue middle fill, blue panel/recess frames and blue aperture states.
- **A1 Depth — \`navy_depth_a1\`:** dark indigo/purple far masses, lifted blue-purple middle fill, near-black far panel/dormant aperture fills, purple panel contours and purple lit/neon/halo states.
- **Amber Diagnostic — \`amber_diagnostic\`:** diagnostic-only theme, not a production zone concept.

The Viewer, Zone/Subzone Preview, and Full-Game Jump-In cycle A2 → A1 → Amber with \`T\`. The regression suite checks both the resource values and the palette actually resolved by the renderer.

### Full-Game Jump-In mote hierarchy

The original game mote emitters and the approved parallax factors are retained:

- Far: \`0.18\`
- Middle: \`0.46\`
- Near: \`0.82\`

The original three \`GPUParticles2D\` nodes are still reused; their texture/material/particle settings are not replaced in the full-game harness. The Parallax2D wrappers now attach as **siblings of the compositor under the gameplay root**, matching the hierarchy of the preserved architecture experiment. This removes the extra compositor-parent transform and Z-index compensation that the previous wrapper arrangement required. The emitter's original Z indices (\`-30/-28/-29\`) remain unchanged.

The Jump-In HUD now reports the mote source, adopted layer count, and live factors. Expected full-game display:

\`MOTES: GAME 3/3  0.18/0.46/0.82\`

If it reports fewer than 3/3, an original production mote emitter was not found or adopted.

### Platform spawn investigation

The production \`PlatformSpawner\` and gameplay scripts were not modified.

Source inspection found:
- The Jump-In applies the game-root Y translation before adding the production scene, so the PlatformSpawner's \`_ready()\` reads the translated Ball global position.
- The spawner initializes its spawn cursor from that Ball global position.
- The spawn pool is created once per test root; restarts synchronously free the previous root before creating another.
- New spawn positions are applied through the platform's \`global_position\`.
- The spawner advances its highest generated Y by a positive, physics-clamped vertical gap. No deterministic same-height placement path was found in the current patterns.

This does **not** prove that runtime platforms never overlap. To distinguish a real overlap from a visual impression, the Full-Game Jump-In HUD now reports active platform count and pairwise collision-rectangle AABB overlaps. Expected overlap count is \`0\`.

This is test-harness-only instrumentation. It does not change platform generation, collision, or gameplay behavior. If the HUD reports a positive count in Godot, capture the scene/height/seed and report it before changing production spawner logic.

## 3. Current preview-tool responsibilities

| Tool | Actual source | What it is intended to prove |
|---|---|---|
| Architecture Library Viewer | Actual module \`PackedScene\` from the recipe module pool | Inspect Far, Middle and Near module examples, bounds, theme and seed. |
| Zone/Subzone Preview | Diagnostic two-subzone zone profile + shared planner/compositor | Inspect the lower/upper structures, 600 px void, fixed landmark ownership, height navigation, and theme changes. |
| Full-Game Environment Jump-In | Actual \`scenes/gameplay/main.tscn\` + shared compositor | Inspect environment against real Ball, Camera, platforms, HUD, glow and original game motes at 1,800 / 5,400 / 9,600 px presets. |

The Full-Game Jump-In defaults to the one-subzone reference-parity fixture to compare against the original study. It is not the two-subzone void-gap test; that is the responsibility of Zone/Subzone Preview.

## 4. Deliberately incomplete Phase 2 capabilities

Do not mistake the current module catalogue and previews for a finished procedural placement engine:

- \`ArchitectureModuleDefinition\` scenes are currently catalogue/viewer inputs; the zone compositor still draws the extracted continuous Far/Middle/Near grammar per subzone.
- The planner records landmark clearance reservations, but does not yet suppress individual generated module placements against them. The base continuous architecture remains behind the separately authored landmarks, matching the original study.
- Connection-point metadata exists but is empty and no connector graph/attachment system exists.
- \`EnvironmentLightingProfile\` is validated and can resolve seeded states/colors, but the current architecture renderer does not yet consume it. The established aperture distribution/flicker remains in the extracted renderer and recipe.
- The diagnostic zones/themes are pipeline fixtures, not approved Zone 1 or Zone 2 concepts.
- No Godot runtime, visual golden-image, Android export, or mobile performance validation has been performed by the assistant.

These are intentionally deferred until the first real zone concepts define what is needed.

## 5. Owner-side Godot validation — still required

Fetch the latest \`feature/environment-art-library-v1\` and open it in Godot 4.7.x. Then:

1. Let import/class registration finish and run:
   \`res://scenes/tests/environment/environment_regression_suite.tscn\`.
   Confirm \`ENVIRONMENT REFERENCE REGRESSION PASS\`, with no parser/resource warnings.
2. Run \`architecture_library_viewer.tscn\`; inspect Far/Middle/Near, especially the adjusted middle bounds; cycle A2, A1 and Amber with \`T\`.
3. Run \`zone_subzone_preview.tscn\`; verify the lower and upper sections, open void before/between/after, the Gate/Archive ownership, 600 px gap, height navigation, seeds and theme switching.
4. Run \`full_game_environment_jump_in.tscn\`; test all three presets, repeated restarts, normal movement, camera and platform recycling. Watch the HUD:
   - Platform AABB overlap pairs should remain \`0\`.
   - Motes should report \`GAME 3/3\` and \`0.18/0.46/0.82\`.
5. Compare the three original mote layers and their depth against \`experiment-middle-architecture-details\`.
6. Cycle A2 → A1 → Amber and verify the far mass fills, near-black recess fills, purple aperture lights, and blue A2 treatment visibly switch as expected.
7. Close the test scene and run normal production gameplay to confirm it is unaffected.

If any of these checks fail, report the exact tool, selected height/seed/theme, HUD diagnostic values, and a screenshot. Do not change gameplay code to compensate for an environment preview issue.
