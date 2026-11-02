# TowerJump — Environment Art Pipeline Masterplan

Last updated: 2026-11-02  
Status: **Art Pipeline V1 planning and implementation — active on `feature/environment-art-library-v1`.** Repository organization and warning cleanup are merged into `main`; the owner verified the game in Godot with no errors or warnings.

This document is the primary handoff for TowerJump's reusable environment-art pipeline. The immediate scope is deliberately bounded: establish a repeatable pipeline and prove it with two contrasting representative early zones, then freeze environment production while gameplay systems are developed. It records approved visual foundations, minimum viable data relationships and preview tools, architecture module scope, deterministic landmark rules, validation criteria, and the current implementation steps.

This document is the primary handoff for building TowerJump's procedural environmental world and reusable Art Library. It records approved visual foundations, the production phases, data relationships, preview tools, architecture module scope, deterministic landmark rules, and the next implementation steps.

---

# 1. Vision and guiding principles

TowerJump should feel like climbing through an unknown, immense, energized world—not a conventional city and not a sequence of unrelated random shapes. The ball and glowing platforms remain the foreground focus. Environmental architecture creates scale, depth, anticipation, discoveries, and distinct zone identities.

The world should be assembled from geometric masses, atmosphere, controlled procedural variation, and deliberately authored landmarks. Complex external art assets are not required for the base architectural language. Reusable Godot scenes are still appropriate for structures whose silhouette and identity need deliberate authorship.

## Locked visual principles

- The established dark navy void background is the global visual anchor: approximately `#02060D`. It creates the familiar, cozy-space atmosphere.
- Void is intentional negative space. The world should alternate between open void, structural environments, and open void again. Do not fill the entire climb with continuous architecture.
- Void may contain subtle scenery accessories—small arches, bridges, fragments, or distant cues—but it should remain restful.
- Environmental structures use dark silhouettes and restrained tonal separation. Neon foreground gameplay remains dominant.
- The world is mysterious and energized, not necessarily human-built or inhabited. Organized geometric systems are welcome; literal human civilization, residential window grids, and implied human activity are not required.
- Zone identity must not rely on neon color changes alone. Silhouette composition, structural rhythm, landmarks, depth, accents, and atmosphere all contribute.
- Every procedural system must be deterministic from world seed and height/section identity.
- Keep production gameplay logic separate from environment-art generation and preview tooling.

# 2. Approved environmental foundation

Phase 1—giving the existing architecture life—is considered complete as a visual milestone. Its exact implementations are preserved on `experiment-middle-architecture-details`; approved milestone tags are listed in Section 12.

## Far silhouettes

Approved direction:
- Large dark distant masses with controlled A1/A2-style tonal relationships.
- Deliberate rectangular and square aperture clusters, including compact panels, broad openings, and readable slits.
- Recesses vary in height and proportions. Apertures are grouped intentionally rather than scattered randomly.
- Three illumination states: dormant, restrained mid-level light, and stronger neon.
- Some sources switch on/off with staggered deterministic timing; other sources shimmer gently.
- Stronger illuminated sources retain a restrained halo.
- Aperture clusters remain inside the silhouette mass.
- Dark or near-black far recesses work when paired with internal ambient light. Do not copy that treatment indiscriminately into unlit middle structures.

Further generic far-layer decoration is deferred until zone concepts provide a reason for additional detail.

## Middle architecture

Approved direction:
- Monumental supports and masses with broad fills, partial contour reveals, recessed structural seams, sparse joints, and restrained neon accents.
- Four-pattern stepped inset plates and multiple mechanical-recess layouts are available as the current reference treatment.
- Middle recesses use a shared dark-indigo material with brighter purple/indigo contours across blue and purple middle-fill variants. Avoid hollow near-black cutouts.
- Inset plates and smaller mechanical cavities should occupy deliberate separate areas with a clear gap; the reference implementation calculates at least a 15 px separation.
- Bright diagnostic contrast is an inspection mode only. Its accidental bright-neon-tower appearance is a possible future intentional zone direction, not a generic generator default.

Further middle-layer details should be motivated by zone architecture, not added globally by default.

## Ambient motes and depth

Architecture-matched mote parallax is approved:
- Far: `0.18`
- Middle: `0.46`
- Near: `0.82`

This transforms the void into a spatial environment rather than screen-stuck particles. Keep the current particle appearance stable unless testing reveals a specific problem.

## Palette relationships

The library must support multiple valid relationships rather than one universal fixed palette:
- A1-like deeper-depth compositions: darker far masses with lifted blue/purple middle fill.
- A2-like integrated compositions: brighter blue/purple far masses with darker blue/indigo middle architecture.
- Additional variations can place theme hues in either far or middle fills, provided values remain distinct from the global navy void and foreground readability is preserved.
- Middle recess materials should remain indigo/blue-purple rather than switching to black just because a palette is brighter.
- Future zones may use warm or otherwise distinctive theme hues, but every profile must preserve depth separation and the foreground hierarchy.

# 3. Production roadmap — bounded Art Pipeline V1

The current priority is to prove a reusable environment-art production process before scaling content. Art Pipeline V1 is intentionally limited to two contrasting representative early zones.

## Phase 1 — Lock the existing environmental foundation

**Status: COMPLETE.**

Approved far aperture clusters, three illumination states, restrained flicker, middle structural detail treatments, and architecture-matched mote parallax are established. Keep these as reusable references. Do not continue generic detail expansion until the two zone concepts identify a specific need.

## Phase 2 — Establish the minimum viable Art Library foundation

**Status: ACTIVE — NEXT IMPLEMENTATION WORK.**

Audit the existing environment implementation and derive a small, useful technical foundation. Do not build a large generalized framework before the first zone requirements are understood.

Initial deliverables:
- Minimal architecture-module definitions and metadata.
- Theme/palette profiles separated from module geometry.
- Simple architecture recipes/module pools only where the first concepts need them.
- Ambient/lighting profile representation, reusing existing approved behavior where practical.
- Zone/subzone profile definitions sized for two representative zones.
- Deterministic seed/height resolution suitable for repeatable previews.
- Fixed-height landmark reservation/clearance concept.
- A minimal way to preview an individual module and a composed zone.
- A route to verify the same composition in the actual game rendering setup.

The long-term capabilities are an Architecture Library Viewer, Zone/Subzone Preview, Full-Game Environment Jump-In, and fixed-seed regression support. Implement them incrementally as real needs emerge; do not build three oversized independent tools before the first vertical slice works.

## Phase 3 — Concept the first two contrasting zones

**Status: NEXT AFTER THE INITIAL AUDIT / MINIMAL FOUNDATION.**

Develop only two representative early zones:
- **Zone 1 — Reference zone:** establishes the baseline process for identity, far/middle/near composition, architectural rhythm, theme, lighting, ambient treatment, void intervals, transitions, and at least one memorable landmark/discovery.
- **Zone 2 — Variation test:** demonstrates a genuinely different architectural identity, silhouette composition, structural rhythm, palette/atmosphere relationship, and landmark treatment while reusing the same pipeline.

Do not choose zone names or final themes by assumption. Derive them from the approved visual foundation and deliberate concept work. The Resonance Gate and Archive Fragment are promising prior landmark ideas to revisit, not mandatory final choices.

Each concept should establish:
- Environmental identity and role in the climb.
- Palette relationship and theme accent.
- Far, middle, and near structural language.
- Large masses and repeating structural rhythm.
- Landmark/discovery ideas and proposed height anchors.
- Entry/exit transitions and subzone sequence.
- Ambient mote/light behavior.
- Special environmental events or scenery only when they contribute to identity.

The concepts must reveal actual library requirements before a large module inventory is created.

## Phase 4 — Implement and compose the two zones

**Status: NOT STARTED.**

Build only the reusable scenes and procedural modules required by the two concepts. Compose the zones from profiles, recipes, module pools, lighting/ambient treatments, transitions, and fixed landmark anchors. Preserve the void → structure → void rhythm.

Use authored Godot scenes for signature silhouettes and procedural systems for controlled continuity/variation. Do not force every architectural element into a generic module abstraction.

## Phase 5 — Validate, document, and freeze Art Pipeline V1

**Status: NOT STARTED.**

Validate both compositions:
- In independent preview tooling.
- In the actual TowerJump rendering setup.
- At representative gameplay scale.
- Across repeatable fixed seeds.
- For silhouette clarity, depth separation, contrast, landmark readability, transitions, foreground readability, and performance.

When the exit criteria in Section 14 are met, document the production workflow, preserve reference compositions, update the context docs, create a clean checkpoint, and deliberately pause environment production.

## Deferred beyond Art Pipeline V1

**Status: INTENTIONALLY DEFERRED.**

- Concepting and producing every remaining game zone.
- Building a comprehensive catalog of every possible architectural module.
- Platform-specific environmental effects for gameplay types not yet established.
- Trap/hazard-specific environmental art before those mechanics are designed.
- Exhaustive zone transitions, special events, and landmark collections.
- Full content scaling before gameplay pacing and mechanics stabilize.

After Art Pipeline V1 is frozen, the project returns to gameplay foundation and mechanics. The full environment library expands later, once platform types, hazards, FLOW, progression, and visual-feedback requirements are understood.

# 4. Art Library — two complementary systems

The library has two distinct responsibilities: **System A defines what can be built; System B defines the visual theme in which it is built.** Zone profiles combine references to both systems.

## System A — Reusable architectural modules

Organize the library around four families.

### A1. Large masses
- Monumental silhouettes.
- Continuous side walls and large enclosing masses.
- Enormous buildings and towers.
- Broad structural foundations and distant volumes.
- Major forms that establish scale and environmental identity.

### A2. Structural modules
- Buttresses and repeating supports.
- Pillars, ribs, structural spines, and load-bearing frames.
- Alternate buttress arrangements.
- Repeating support sections and controlled offsets.
- Modular wall/support segments that can combine into continuous masses.

### A3. Connectors
- Recesses and architectural passages.
- Arches and major arch compositions.
- Bridges and cross-structures.
- Gates and portals.
- Distinctive framing arrangements.
- Connectors that interrupt, join, or frame large masses.

### A4. Surface details
- Structural seams and joints.
- Recessed plates and mechanical cavities.
- Compact panels and energy apertures.
- Windows/light slits/illuminated openings.
- Restrained neon accents and localized structural lighting.

### Reusable scenes versus procedural generation

Use reusable Godot scenes/prefabs when silhouette and placement need intentional authorship:
- Gates, major arches, bridges, landmark towers, signature portals, distinctive framing arrangements, and other structures with a deliberate visual identity.

Use procedural generation for systems whose value comes from continuity and controlled variation:
- Repeated support sections, continuous side masses, subtle offsets, alternate buttress arrangements, selected aperture placements, recess patterns, and variation in structural rhythm.

A signature landmark must not be reduced to a random arrangement of generic modules. Procedural architecture should compose around it.

## System B — Theme and palette profiles

A theme profile controls how modules are visually presented. It should be independent of the module geometry.

Each profile may define:

1. **Far fill A/B** — main distant masses and their intentional tonal variation.
2. **Middle fill** — supports, walls, and structural masses in the middle depth.
3. **Near-detail colors** — recesses, selected contours, and framing accents.
4. **Structural light** — windows, light slits, and illuminated openings, including dormant/mid/neon state balance and flicker behavior.
5. **Theme accent** — distinctive neon details tied to the zone.
6. **Ambient treatment** — mote colors, density, parallax, and other atmosphere settings where appropriate.

Profiles may also define transition tinting, landmark-specific accent overrides, and special structural lighting. Keep universal value/contrast rules separate from zone-specific color choices.

# 5. Architecture library coverage

The reusable library should eventually cover the full map vocabulary:
- Monumental silhouettes and continuous side walls establishing scale.
- Buttresses, repeating supports, and framing structures that make the tower feel constructed.
- Recesses, arches, bridges, and gates creating distinct compositions.
- Enormous buildings and towers establishing landmarks within the environment.
- Windows, lighted openings, structural seams, and restrained neon accents providing surface detail.
- Signature landmarks/discoveries that can carry height milestones and memorable names.

The first release does not need every possible variation. Art Library V1 should be driven by the first zone concepts, then expand as later zones reveal new requirements.

# 6. Zone, subzone, and world data relationship

Target conceptual hierarchy:

```text
World Environment
├── Global Void Profile
├── Zone Schedule
│   ├── Zone 1
│   │   ├── Theme / Palette Profile
│   │   ├── Entry Transition
│   │   ├── Subzone Sequence
│   │   │   ├── Architecture Recipe
│   │   │   ├── Module Pool
│   │   │   ├── Lighting / Mote Profile
│   │   │   └── Local Variations + Seed
│   │   ├── Landmark Anchors
│   │   └── Exit Transition
│   ├── Void Interval + Scenery
│   ├── Zone 2
│   │   └── ...
│   └── Further Zones
└── Deterministic Height / Seed Resolver

Architecture Library
├── Large Masses / Silhouettes
├── Repeating Structural Modules
├── Walls / Frames / Recesses
├── Arches / Bridges / Gates
├── Surface Details / Windows / Lights
└── Signature Landmarks

Test Tools
├── Architecture Library Viewer
├── Zone / Subzone Preview
├── Full-Game Height Jump-In
└── Fixed-Seed Regression Tests
```

The Zone Schedule owns height ranges and sequence. A zone references theme/palette profiles, subzone definitions, architecture recipes, module pools, transitions, and landmark anchors. Architecture recipes reference library modules; they do not copy geometry into zone data.

A local subzone seed should be resolved deterministically from world seed + zone ID + subzone ID + stable height/section key. Never let a previous random draw shift the position of a fixed landmark.

# 7. Fixed-height landmarks and discoveries

Landmarks are deliberate authored structures with fixed height anchors.

### A. Give each landmark a deliberate height anchor

A landmark definition should contain at minimum:
- Stable landmark ID and reusable scene/module reference.
- World height anchor or reserved height interval.
- Zone/subzone ownership.
- Vertical footprint and any required horizontal/architectural clearance.
- Landmark-specific palette/light/activation profile.
- Stable seed key for surrounding procedural composition.

### B. Let procedural architecture build around the landmark

The generator must reserve the landmark's occupied height range and spatial footprint. It should not place repeating supports, side masses, or connectors through the landmark. Surrounding architecture should frame it and transition into/out of its signature silhouette.

### C. Keep placement deterministic

The same world seed and height schedule must resolve the same landmark and surrounding composition. Landmark placement must not depend on how many random structures happened to generate earlier.

Landmarks can trigger discovery milestones, text, sound, or a landmark-specific activation effect. Those presentation/gameplay hooks should remain separate from the architecture geometry.

# 8. Three permanent environmental test tools

## Tool 1 — Architecture Library Viewer

Purpose: inspect individual modules without requiring a complete zone or gameplay run.

Required capabilities:
- Load one module or a selected composition.
- Show its silhouette, dimensions, depth layer, connection points, and bounds.
- Switch approved palette/theme profiles.
- Expose controlled parameters and deterministic seeds.
- Compare variants side by side.
- Show any attachment/clearance constraints.

## Tool 2 — Zone and Subzone Preview

Purpose: assemble a zone sequence independently of the full gameplay loop.

Required capabilities:
- Load a zone profile and subzone sequence.
- Display void → entry transition → structure → exit transition → void.
- Compose far/middle/near layers, architecture recipes, module pools, palette profiles, lighting, and motes.
- Place fixed-height landmarks at their scheduled anchors.
- Choose fixed seeds and compare profiles/variants.
- Jump directly to a selected subzone or landmark.

## Tool 3 — Full-Game Environment Jump-In

Purpose: verify the environment in the actual TowerJump gameplay rendering setup.

Required capabilities:
- Use the real player, camera, platforms, glow, and HUD/render settings.
- Jump directly to a specified height or landmark anchor.
- Load the correct zone/subzone profile and deterministic seed for that height.
- Preserve the actual mote depth and camera behavior.
- Allow play through entry/exit transitions and around landmarks.

Fixed-seed regression tests should capture known-good module and zone compositions. A change to a library module must be reviewable against previous outputs.

# 9. Complete workflow: idea to validated Art Pipeline V1

1. Lock the global visual principles — **complete**.
2. Preserve the approved far/middle architecture, lighting, and mote references — **complete**.
3. Audit existing environment scenes, scripts, shaders, assets, and comparison harnesses.
4. Define only the minimum viable data model and preview workflow.
5. Concept two contrasting representative early zones.
6. Derive the actual module/profile requirements from those concepts.
7. Build the initial reusable scenes and procedural modules.
8. Compose both zone sequences, including transitions, void intervals, and fixed-height landmark spaces.
9. Review modules and compositions in lightweight preview tools.
10. Validate both zones in the actual TowerJump rendering setup and across deterministic seeds.
11. Document the repeatable workflow, save fixed-seed reference compositions, and freeze Art Pipeline V1.
12. Return to gameplay foundation and mechanics; expand the full Art Library only later.

Do not build a large generic asset catalog before the first two zone concepts. The working sequence is: audit → minimum foundation → two zone concepts → requirements → modules → two compositions → game-scale validation → documentation/freeze.

# 10. Dedicated repository and project structure

The repository organization is **implemented, merged, and owner-verified**. Current relevant directories include:

```text
TowerJump/
├── assets/
│   ├── player/
│   ├── particles/
│   ├── references/
│   └── legacy/
├── shaders/
│   ├── player/
│   ├── platform/
│   └── ui/
├── scenes/
│   ├── gameplay/
│   └── tests/
│       └── gameplay/
├── scripts/
│   ├── core/
│   ├── player/
│   ├── camera/
│   ├── economy/
│   ├── platform/
│   ├── landing/
│   ├── ui/
│   └── tests/
├── context/
│   ├── README.md
│   ├── ART_PIPELINE_MASTERPLAN.md
│   ├── design/
│   └── archive/
└── project.godot
```

This is the existing organized structure, not a requirement to create every possible environment folder immediately. Add environment-specific directories such as `assets/environment/`, `scenes/environment/`, `scripts/environment/`, and `scenes/tests/environment/` only when the first implementation slice demonstrates that they are useful.

The migration preserved all image binaries. Runtime-used textures are grouped under `assets/player/` and `assets/particles/`; unreferenced concept images and experimental particles remain under `assets/references/` or `assets/legacy/`. `scripts/landing/` remains a dedicated subsystem. Shader resources are separated from scenes. Keep Godot `.uid` sidecars and paired `.import` metadata with their resources.

# 11. Validation and implementation discipline

- Keep `main` as the stable production baseline; all Art Library work belongs on `feature/environment-art-library-v1`.
- Never modify the preserved `experiment-middle-architecture-details` reference branch. Inspect it read-only.
- Do not copy architecture comparison harnesses wholesale into the production or Art Library branch.
- Keep environment generation and preview tooling separate from player movement, physics, platform gameplay, scoring, difficulty, and other gameplay systems.
- Do not modify existing gameplay logic for visual/environment experiments unless a specific, necessary integration change is first justified and kept narrowly scoped.
- Change one concern at a time and maintain a known-good control.
- Preserve UIDs and update all paths when moving scripts, scenes, shaders, and imported assets.
- Do not delete assets solely because they have no current runtime reference; classify them as references/legacy first.
- Run Godot 4.7.x project import and relevant scene/runtime checks after resource or scene changes.
- The owner has already verified the organized project and warning-cleanup changes in Godot with no errors or warnings. Do not claim assistant-side runtime verification.
- Verify the actual game rendering setup as well as isolated preview scenes. Do not accept a beautiful preview if it compromises foreground gameplay readability or runtime performance.
- Use deterministic local seeds and stable IDs/height keys; never let unrelated random draws shift fixed landmark positions.
- Keep changes small, documented, and committed at clear checkpoints.

# 12. Branches, tags, and current handoff state

## Current branch strategy — verified 2026-11-02

- `main` — stable production baseline at `d47ef2206a1326472de3ac1cc1a8a9f7ccda6baa`.
- `feature/environment-art-library-v1` — active Art Library V1 working branch, created from the exact same commit as `main`. All implementation work in this phase belongs here.
- `experiment-middle-architecture-details` — preserved approved environment-art reference; inspect read-only and keep untouched.
- `experiment-forward-assembly-platforms` — important future gameplay/environment design reference.
- `feature/combo-system-prototype` — preserved early combo/resonance prototype.
- `experiment-unified-comet-shape` — preserved comet contour/shape and future cosmetic-skin direction.
- `experiment-plant-bank-jumping` — preserved small gameplay experiment.

Retired branches:
- `experiment-vertical-resonance-field` — merged into `main`; exact baseline is preserved by `milestone/gameplay-baseline-v1`.
- `chore/project-organization` — merged through PR #6; the integrated result is preserved by `milestone/project-organization-v1`.
- `merge/gameplay-baseline-to-main` — temporary two-parent integration branch; its history is already part of `main` and it has been deleted.

PR #6 — [Organize project structure and resolve Godot warnings](https://github.com/Kryodo/TowerJump/pull/6) — is merged. Its merge commit is `d47ef2206a1326472de3ac1cc1a8a9f7ccda6baa`. The owner confirmed the project runs in Godot with no errors or warnings after the final retest.

## Preserved tag inventory

The following checkpoint/reference tags are present on the remote:
- `foundation/pre-comet-redesign-v1`
- `milestone/gameplay-baseline-v1`
- `milestone/project-organization-v1`
- `milestone/far-apertures-v1`
- `milestone/ambient-mote-depth-v1`
- `milestone/middle-architecture-v1`
- `reference/comet-design-v3-new`
- `reference/comet-landing-shedding-v2-new`
- `reference/comet-shedding-v1`
- `reference/comet-continuous-shedding-v1`
- `idea/comet-dissolution-v1`
- `idea/comet-layered-undulation-v1`
- `reference/early-comet-redesign-v1`
- `reference/first-background-concept`

The `milestone/project-organization-v1` tag points to the integrated PR #6 merge commit `d47ef2206a1326472de3ac1cc1a8a9f7ccda6baa`. The `milestone/gameplay-baseline-v1` tag preserves the verified gameplay-baseline branch head `2b57faf68de98ace8221e8b233152214a334388b`.

Tags preserve exact historical commits without requiring every completed experiment branch to remain active.

# 13. Phase 2 — Art Library data model and preview tooling

## Status — 2026-11-02

**Implementation status: core resources, source renderer, shared previews, and regression checks exist on feature/environment-art-library-v1. A source audit/correction pass has been completed. Godot 4.7.x import, parser, visual, and runtime validation is still pending.**

Phase 2 is the reusable data foundation and the minimum tools needed to inspect it. It is deliberately separate from Zone 1/Zone 2 production concepts. The implementation reuses the established renderer from experiment-middle-architecture-details rather than replacing it with a new simplified primitive system.

The production branch main and preserved architecture reference branch remain untouched.

## Required Phase 2 deliverables and actual implementation boundary

| Deliverable | Current implementation | Accurate current capability |
|---|---|---|
| Architecture module definitions | ArchitectureModuleDefinition Resource | Stable ID, family, depth layer, PackedScene, visual/clearance bounds, optional connection points. |
| Theme/palette profiles | EnvironmentThemeProfile Resource | Far/middle/near fills, complete A1/A2 far panel/recess/aperture material sets, accents and generic light-state colors. |
| Architecture recipes and module pools | EnvironmentArchitectureRecipe Resource | Reusable module catalogue, repeat spacing, bottom padding, far/middle detail treatments. Module pools currently feed the Viewer and validation; they are not yet a per-module placement solver. |
| Ambient/lighting profiles | EnvironmentAmbientProfile and EnvironmentLightingProfile Resources | Ambient tint/density/speed/highlight share/parallax; lighting state distribution and optional flicker data. Ambient profile drives mote preview behavior. Lighting profile is validated but is not yet consumed by the extracted architecture renderer. |
| Zone/subzone profiles | EnvironmentZoneProfile and EnvironmentSubzoneProfile Resources | Bounded climb-height ranges, inherited/override profiles, recipes, stable IDs/seed keys, and intentional void gaps. |
| Fixed-height landmarks and deterministic seeds | EnvironmentLandmarkAnchor and EnvironmentSeedResolver | Authored scenes, stable height anchors, ownership, clearance rectangles, neighborhood seeds. Landmark reservations are planned and validated. |
| Shared composition planning | EnvironmentCompositionPlanner | Deterministic architecture-section descriptors and landmark/reservation records. It does not currently generate individual module placements or suppress module placements against reservations. |
| Shared environment rendering | EnvironmentPreviewCompositor + EnvironmentArchitectureLayer | Renders the established continuous Far/Middle/Near architectural grammar per subzone, then places authored landmark scenes. It does not yet compose zones from individual PackedScene modules. |
| Architecture Library Viewer | architecture_library_viewer.tscn | Instantiates the selected module definition's actual PackedScene and applies theme, seed, recipe, preview bounds. |
| Zone/Subzone Preview | zone_subzone_preview.tscn | Uses the two-subzone diagnostic fixture to show structure/void/structure/void, landmark ownership, theme and seed changes, and profile-driven ambient parallax. |
| Full-Game Environment Jump-In | full_game_environment_jump_in.tscn | Instantiates the actual production gameplay scene in a test-only wrapper and overlays the reference-parity environment at selected absolute heights. |
| Fixed-seed regression | environment_regression_suite.tscn + JSON manifest | Checks reference plan signatures/anchors, A1/A2 resource and renderer palette mapping, diagnostic subzone composition/seeds, and jump-in parallax coordinate conversion. It is not a pixel-golden or gameplay platform-overlap test. |

## Shared composition behavior

- The planner builds an inspectable data plan without instantiating scene nodes.
- One architecture section is produced per valid subzone. Single-subzone parity fixtures preserve the world seed unchanged; multi-subzone plans derive stable independent seeds from the world seed, zone ID, and subzone identity/key.
- Landmark seeds derive independently from the world seed, zone ID, landmark ID, and stable neighborhood key.
- Landmark clearance rectangles are validated and included in the plan. Since individual module placements are not currently generated, the planner does not yet suppress module instances against these reservations.
- Positive climb-height zero maps to production ball local Y=600 px. A positive height h maps to local world Y=600-h.
- Far/Middle/Near parallax defaults remain 0.18 / 0.46 / 0.82.
- Architecture X parallax remains distinct from mote parallax. Motes use horizontal factor 1.0 and profile-driven vertical factors.
- The full-game wrapper reuses the original three production mote emitters; the standalone Zone Preview creates lightweight profile-driven Parallax2D emitters from the existing mote texture.
- The production gameplay scene, player movement, physics, platform generator/spawner, scoring, and camera script are not modified by this environment preview implementation.

## Two independent preview fixtures

Do not confuse the reference parity fixture with the diagnostic zone fixture.

- reference_extraction_parity: one full-height subzone, exact reference study window, A2 default palette, Compact Panel Flicker, middle detail treatment C, Gate/Archive anchors at established original heights. Used by the Full-Game Jump-In and the reference regression suite.
- preview_diagnostic_zone: two structure subzones with an intentional 600 px gap, open void before and after, Gate owned by lower structure and Archive owned by upper structure. Used by Zone/Subzone Preview.

These fixtures exercise the pipeline only. They do not define Zone 1 or Zone 2, finalize zone palettes, or approve the landmarks for production.

## Palette profiles

The three preview tools cycle the following profiles:

1. A2 Integrated — navy_resonance.
2. A1 Depth — navy_depth_a1.
3. Amber Diagnostic — amber_diagnostic.

A1 and A2 both provide the complete far structured panel/window palette. The extracted renderer resolves all eight material values from the selected theme profile. A1's far panels/dormant apertures remain near-black and its aperture states/halo are purple-tinted; A2 remains blue-toned. Amber is solely a diagnostic theme-switching resource and is not a Zone 2 concept.

## Preview controls

| Test scene | Controls |
|---|---|
| scenes/tests/environment/architecture_library_viewer.tscn | 1 / 2 / 3 or Left / Right: module. T: theme. R: fixed seed. |
| scenes/tests/environment/zone_subzone_preview.tscn | Up / Down: move through height. Home: initial height. J: next landmark. 1 / 2 / 3 or R: fixed seed. T: theme. P: capture PNG under user://environment_regression/. |
| scenes/tests/environment/full_game_environment_jump_in.tscn | Normal game movement. 1 / 2 / 3: jump to 1,800 / 5,400 / 9,600 px with fixed seeds. R: restart. N: next seed. T: theme. |
| scenes/tests/environment/environment_regression_suite.tscn | Runs deterministic source/layout checks and exits with a status code. |

After Godot has imported the project, run the regression suite with:

1. godot --headless --editor --path . --quit
2. godot --headless --path . res://scenes/tests/environment/environment_regression_suite.tscn

The expected reference-parity signatures are in resources/environment/regression/preview_diagnostic_fixed_seeds.json. This is a deterministic plan/resource/coordinate regression, not a pixel-perfect renderer test or a runtime platform-collision test.

## Phase 2 completion boundary

All planned resource types and three preview capabilities exist at source level. The Viewer now instantiates the actual selected module PackedScene. Zone/Subzone Preview uses the two-subzone diagnostic fixture. Full-Game Jump-In uses the real production scene in a test-only wrapper. The reference renderer/palette parity and regression checks have been strengthened.

This closes the current source implementation sequence for the basic Phase 2 foundation, but **does not close owner-side Godot validation**. It also does not mean that a generic modular architecture placement engine, connector graph, fully integrated lighting profile, or either representative production zone is complete.

The next action is an owner-side Godot 4.7.x import and run-through of the regression scene and all three preview scenes. Resolve parser, resource, rendering, platform-spawn, parallax, and palette issues on this same feature branch. Preserve any .uid sidecars Godot generates.

Only after validation should work proceed to Zone 1 concept definition, deriving actual architectural requirements, and later proving reuse with a genuinely contrasting Zone 2. Do not expand the module catalogue or implement speculative module-placement abstractions before the concepts reveal a concrete need.

# 14. Art Pipeline V1 exit criteria and intentional handoff back to gameplay

Art Pipeline V1 is complete when all of the following are true:

- Two representative early zones have distinct and recognizable environmental identities.
- Both zones use the same documented underlying pipeline for architecture, theme treatment, composition, and preview.
- The shared system supports authored signature structures alongside procedural repeating architecture.
- Far/middle/near depth, the global navy void, and foreground gameplay readability remain coherent.
- Each zone has a composed environmental sequence with deliberate void intervals and appropriate transitions.
- At least one memorable landmark/discovery is integrated into the representative zone set, with reserved space and a deterministic height anchor.
- Fixed world seed + zone/subzone identifiers + stable height/section keys reproduce the same intended compositions and landmark placement.
- Both zones can be inspected in independent preview tooling and verified in the actual TowerJump rendering setup.
- Runtime/performance and visual readability have been checked at representative gameplay scale.
- The workflow, data relationships, approved decisions, deferred work, and reference seeds are documented.

Once these conditions are met, stop adding zones or expanding the generic module catalog. Preserve a clean Art Pipeline V1 checkpoint and return primary development focus to gameplay.

## Broader development sequence after Art Pipeline V1

1. **Gameplay foundation:** establish movement, gravity, jump velocity, climbing speed, platform spacing, generation patterns, and difficulty progression.
2. **Gameplay mechanics:** define platform types, traps, route challenges, dodging, recovery, FLOW, the rising bottom threat, safe capsules, and progression.
3. **Core visual feedback:** finish landing impact, Streak visuals, platform environmental responses, and the visual communication required by the established mechanics.
4. **Full environment production:** expand the Art Library and produce remaining zones based on the now-established gameplay and visual requirements.
5. **Integration and polish:** balance pacing, transitions, visual consistency, progression, performance, and mobile presentation.

This ordering is deliberate. Art Pipeline V1 should prove that future environment content can be produced reliably; it should not pre-emptively design content for gameplay systems that do not yet exist.
