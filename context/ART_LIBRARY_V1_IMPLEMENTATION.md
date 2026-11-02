# Art Library V1 — Implementation Notes

Last updated: 2026-11-02  
Status: **Foundation checkpoint 1 — repository audit and initial resource contracts complete; Godot validation pending.**

This document records implementation-specific decisions without turning the masterplan into a code diary. The masterplan remains the authoritative scope and exit-criteria document.

---

## 1. Repository and branch audit

Repository: \`Kryodo/TowerJump\`

- Production baseline: \`main\` at \`d47ef2206a1326472de3ac1cc1a8a9f7ccda6baa\`.
- Art Library branch: \`feature/environment-art-library-v1\`.
- Audited feature HEAD before this checkpoint: \`379f4910e3b108c4bbce8f0aff9482c40227e556\`.
- Preserved read-only architecture reference: \`experiment-middle-architecture-details\` at \`c8e212a93112bcc6acc990011bfa0974b64dec9a\`.

The feature branch was created from the same baseline commit as \`main\`, as documented. At audit time it was three documentation commits ahead of \`main\` and zero commits behind. Those commits modified only:

- \`context/ART_PIPELINE_MASTERPLAN.md\`
- \`context/README.md\`
- \`context/Repository Organization and Validation.md\`

There were no new gameplay, environment implementation, or asset changes in those commits. All new Art Library work belongs on the feature branch. Do not modify \`main\` or the preserved experiment branch.

## 2. Production rendering integration

The current production scene is \`scenes/gameplay/main.tscn\`, loaded by \`project.godot\`.

It contains the real player, camera, platform/coin systems, WorldEnvironment/glow, navy background, and camera-attached ambient mote emitters. The production scene does not yet contain an architectural background renderer.

The preserved experiment demonstrated a useful isolated integration pattern:

1. Instantiate the actual game scene inside a test wrapper.
2. Add an environment root to the instantiated game scene at \`z_index = -50\`.
3. Keep the base background at \`z_index = -60\` and ambient motes above the architecture around \`z_index = -30\`.
4. Resolve the camera from the instantiated game scene and update the environment layers relative to it.

The V1 preview should adapt this pattern to the current production path, \`res://scenes/gameplay/main.tscn\`. It should not copy the old \`scenes/main.tscn\` path or require changes to player movement, physics, platforms, scoring, difficulty, or landing logic.

The approved ambient mote parallax values are:

| Layer | Vertical parallax |
|---|---:|
| Far | 0.18 |
| Middle | 0.46 |
| Near | 0.82 |

The experiment applies these through runtime \`Parallax2D\` wrappers around the existing emitters. Any such reparenting should remain local to the preview/game instance until deliberately integrated.

## 3. Preserved architecture reference — reuse classification

The reference branch contains one substantial drawing implementation and multiple diagnostic wrappers. Treat it as a visual/technical reference, not a production library.

| Existing reference | Classification | V1 decision |
|---|---|---|
| \`scripts/procedural_architecture_background.gd\` | Palette/layer comparison manager | Rebuild only the useful layer/parallax behavior around data-driven profiles. Do not copy the palette-test manager. |
| \`scripts/procedural_architecture_draw_layer.gd\` | Large monolithic procedural drawing script | Reuse approved geometry and drawing treatments selectively; split actual zone requirements into focused reusable scenes/scripts. |
| Far silhouette and aperture functions | Approved visual vocabulary | Reuse large connected side masses, deliberate aperture clusters, compact panels, broad openings, and three lighting states. |
| Middle support and inset functions | Approved visual vocabulary | Reuse monumental supports, partial contour reveals, sparse seams, four stepped inset patterns, and mechanical cavities with deliberate spacing. |
| \`_draw_resonance_gate()\` | Landmark concept embedded in a layer draw method | Revisit as a candidate, then author as an independent scene if selected. |
| \`_draw_archive_recess()\` | Landmark/discovery concept embedded in a layer draw method | Revisit as a candidate, then author as an independent scene if selected. |
| \`scripts/ambient_mote_parallax_test.gd\` | Approved parallax experiment | Preserve the 0.18/0.46/0.82 relationship; adapt the wrapper logic rather than importing the test harness. |
| Palette, life-treatment, hue/brightness, transition, and sequence test scenes | Comparison/debug-only | Keep on the preserved branch. Do not port them wholesale. |

The reference implementation contains many hard-coded comparison enums, palette variants, test labels, fixed section bounds, and geometry methods in a single script. Those are useful records of how the visual direction was reached, but they are not the desired module/theme/zone API.

### Approved reusable visual decisions

- Global void anchor: approximately \`#02060D\`.
- Three depth layers: Far, Middle, Near.
- Large dark distant silhouettes with deliberately grouped apertures.
- Dormant, restrained mid-level, and stronger neon illumination states.
- Monumental middle supports with broad fills, partial contours, recessed seams, sparse joints, and restrained accents.
- Four deterministic stepped-inset arrangements.
- Shared dark-indigo middle recess materials across blue/purple fill variants.
- Mechanical recesses remain structural cavities, not illuminated residential-style windows; the reference layout preserves a 15 px minimum separation from inset plates.
- Near framing remains sparse and quiet.

The Resonance Gate and Archive Fragment remain possible landmark candidates, not committed Zone 1 or Zone 2 content. Diagnostic bright-neon middle treatments are not generic production defaults.

## 4. Initial V1 data contract

The first code checkpoint adds typed Resource definitions only. It does not yet create a module catalog, zone assets, a renderer, or a gameplay integration.

| Resource | Responsibility |
|---|---|
| \`ArchitectureModuleDefinition\` | Stable module ID, one of four module families, depth layer, PackedScene reference, local bounds, clearance bounds, and optional connection points. |
| \`EnvironmentThemeProfile\` | Far/middle/near fills, accent colors, and structural-light state colors, independent of geometry. It does not own the global void color. |
| \`EnvironmentAmbientProfile\` | Mote tint/density and the approved far/middle/near parallax defaults. |
| \`EnvironmentArchitectureRecipe\` | Named references to a module pool; actual generation parameters should be added only when a zone needs them. |
| \`EnvironmentSubzoneProfile\` | Stable subzone ID, start/end climb height, recipe, optional theme/ambient overrides, and a stable seed key. |
| \`EnvironmentZoneProfile\` | Zone ID, bounded height range, default theme/ambient profiles, subzone sequence, and landmark anchors. |
| \`EnvironmentLandmarkAnchor\` | Stable landmark ID, authored scene, height anchor, local clearance rectangle, optional theme override, and stable neighborhood seed key. |

Heights in the new profile resources are expressed as positive climb-distance pixels measured upward from the run origin. The preview/composition layer will convert this to the game's world-space Y coordinate. This keeps data ordering intuitive while leaving the existing gameplay coordinate system untouched.

The landmark clearance rectangle is local to the landmark scene root. Its transformed bounds reserve the landmark's occupied vertical and horizontal space before procedural architecture is placed. The selected landmark scene itself remains authored and deterministic; procedural modules compose around its reserved region.

The model intentionally does not include a full world schedule, global content registry, generic transition framework, or editor plugin. Two zone resources are enough for V1; add a higher-level schedule only when the preview/composition slice demonstrates a real need.

## 5. Deterministic seed policy

\`EnvironmentSeedResolver\` derives a local seed from:

- World seed.
- Stable zone ID.
- Stable subzone ID.
- Stable section key, or stable landmark/neighborhood key.

It uses a small explicit FNV-1a hash over the input identity and returns a positive 31-bit seed. It does not read or mutate global random state.

Each independent section and landmark neighborhood receives its own derived seed. Adding another module earlier in the vertical sequence therefore cannot shift an already anchored landmark or change unrelated sections.

Use \`section_seed()\` for repeating/local architecture sections and \`landmark_seed()\` for the neighborhood surrounding an authored landmark. Do not pass an incrementing draw counter as the stable key.

## 6. Preview strategy

Build one small preview vertical slice rather than three independent editor systems.

The intended first preview should:

- Inspect one authored/procedural module with its bounds and depth layer.
- Load one zone profile and a short subzone sequence.
- Show an intentional void → structure → void composition.
- Expose a fixed world seed and stable section keys.
- Place one selected landmark at its fixed height while reserving its clearance.
- Use an instance of the actual production game scene for the final rendering/readability check.

The module viewer, zone/subzone preview, and full-game jump-in remain long-term capabilities. Their interfaces should emerge from this first working slice, not be built as separate frameworks in advance.

## 7. Checkpoint 1 status and next actions

**Added on \`feature/environment-art-library-v1\`:**

- \`scripts/environment/architecture_module_definition.gd\`
- \`scripts/environment/environment_theme_profile.gd\`
- \`scripts/environment/environment_ambient_profile.gd\`
- \`scripts/environment/environment_architecture_recipe.gd\`
- \`scripts/environment/environment_subzone_profile.gd\`
- \`scripts/environment/environment_landmark_anchor.gd\`
- \`scripts/environment/environment_zone_profile.gd\`
- \`scripts/environment/environment_seed_resolver.gd\`

**Not yet implemented:**

- Actual reusable architecture scenes or procedural modules.
- Zone 1 or Zone 2 content and final themes.
- The preview host/compositor.
- Landmark reservations in a running composition.
- Fixed-seed visual regression captures.

**Validation:** source-level structure reviewed. Godot 4.7.x project import, parser, resource registration, and runtime checks have not been run by the assistant. The owner should run the project in Godot and check the new scripts before relying on them.

**Next concrete checkpoint:** concept Zone 1, derive its first module requirements, create one representative reusable module and one small zone sequence, then build the preview wrapper around \`scenes/gameplay/main.tscn\`. Revisit this data contract only when that real composition exposes a missing field.
