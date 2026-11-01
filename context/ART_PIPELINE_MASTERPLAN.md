# TowerJump — Environment Art Pipeline Masterplan

Last updated: 2026-11-01  
Status: Production pipeline definition; repository organization branch is awaiting local Godot validation.

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

# 3. Production roadmap — six phases

## Phase 1 — Give the existing architecture more life

**Status: COMPLETE.**

Approved far aperture clusters, three illumination states, restrained flicker, middle structural detail treatments, and architecture-matched mote parallax are established. Keep these as reusable references. Do not continue generic detail expansion until zone concepts identify a need.

## Phase 2 — Build the Art Library foundation and preview tools

**Status: NEXT IMPLEMENTATION PHASE.**

Define the data model and the three permanent preview tools before producing a large module inventory.

Deliverables:
- Architecture module definitions and metadata.
- Theme/palette profiles.
- Architecture recipes and module pools.
- Ambient/lighting profiles.
- Zone/subzone profile definitions.
- Fixed-height landmark anchors and deterministic height/seed resolver.
- Fixed-seed regression support.
- Architecture Library Viewer.
- Zone and Subzone Preview.
- Full-Game Environment Jump-In.

Build only the fields and tools required by the first zone concepts. Avoid premature generic frameworks.

## Phase 3 — Concept the early zones

**Status: NOT STARTED.**

Concept the first few contrasting zones before filling the library. Each zone concept must establish:
- Environmental identity and role in the climb.
- Palette relationship and theme accent.
- Far, middle, and near structural language.
- Large masses and repeating structural rhythm.
- Landmark/discovery ideas and their height anchors.
- Entry/exit transitions and subzone sequence.
- Ambient mote/light behavior.
- Special environmental events or scenery, if appropriate.

The first zone concepts should reveal the actual library requirements.

## Phase 4 — Build the reusable architectural library

**Status: NOT STARTED.**

Build the first useful reusable module pool from the approved zone requirements. Use both reusable scenes and procedural systems; do not force every structure into one approach.

## Phase 5 — Assemble zones and subzones

**Status: NOT STARTED.**

Compose complete environmental sequences using zone profiles, architecture recipes, module pools, palette profiles, ambient profiles, transitions, and landmark anchors. Preserve the void → structure → void rhythm.

## Phase 6 — Validate, refine, and expand

**Status: NOT STARTED.**

Validate compositions at actual gameplay scale and across deterministic seeds. Review silhouette clarity, depth, contrast, performance, transitions, landmark readability, and interaction with ball/platform glow. Refine the library from real zone results, then expand.

---

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

# 9. Complete workflow: idea to finished zone

1. Lock the visual principles — **complete**.
2. Finish bounded generic detail experiments — **complete**.
3. Define the data model and preview tools.
4. Concept the first few zones.
5. Derive library requirements from those concepts.
6. Build initial reusable scenes and procedural modules.
7. Compose playable zone/subzone sequences.
8. Review them in the Architecture Library Viewer and Zone Preview.
9. Refine the reusable library based on composition results.
10. Validate at actual gameplay scale in the Full-Game Environment Jump-In.
11. Expand the zone schedule and library only when a new zone needs it.

Do not build a large generic asset catalog before the first zone concepts. Zone concepts → library requirements → initial modules → playable zone composition → visual review → library refinement.

# 10. Dedicated repository and project structure

The organization branch is establishing this target structure:

```text
TowerJump/
├── assets/
│   ├── player/
│   ├── particles/
│   ├── environment/
│   ├── references/
│   └── legacy/
├── shaders/
│   ├── player/
│   ├── platform/
│   ├── ui/
│   └── ...
├── scenes/
│   ├── gameplay/
│   ├── ui/
│   ├── environment/
│   └── tests/
│       ├── gameplay/
│       └── environment/
├── scripts/
│   ├── core/
│   ├── player/
│   ├── camera/
│   ├── economy/
│   ├── platform/
│   ├── landing/
│   ├── ui/
│   ├── environment/
│   └── tests/
├── context/
│   ├── README.md
│   ├── ART_PIPELINE_MASTERPLAN.md
│   ├── design/
│   └── archive/
└── project.godot
```

Current organization moves preserve all image binaries. Runtime-used textures are grouped under `assets/player` and `assets/particles`; unreferenced old concept images and experimental particles are retained in `assets/references` or `assets/legacy`, not deleted. `scripts/landing/` remains a dedicated subsystem. Shader resources are separated from scenes. Keep Godot `.uid` sidecars and paired `.import` metadata with moved files.

# 11. Validation and implementation discipline

- Use a separate working branch for repository structure changes and for library features.
- Keep `main` as the production baseline.
- Never modify the preserved `experiment-middle-architecture-details` reference branch.
- Do not copy architecture comparison harnesses wholesale into the production or Art Library branch.
- Change one concern at a time and maintain a known-good control.
- Preserve UIDs and update all paths when moving scripts, scenes, shaders, and imported assets.
- Do not delete assets solely because they have no current runtime reference; classify them as references/legacy first.
- Run Godot 4.7.x project import and scene-load validation after file moves.
- Verify the main gameplay scene, ball/trail shaders, platform scene, landing feedback, test room, and Android export.
- Any runtime parse/import error discovered by the project owner must be fixed before merging the organization branch.
- Only after project loading and export are verified should the Art Library feature branch be created.

# 12. Branches, tags, and current handoff state

## Current branch strategy

- `main` — stable production baseline. On 2026-11-01 it received the verified gameplay baseline through PR #5.
- `chore/project-organization` — current folder and context cleanup branch; awaiting local Godot validation.
- `experiment-middle-architecture-details` — preserved approved environment-art reference; keep untouched.
- `experiment-forward-assembly-platforms` — important future gameplay/environment design reference.
- `feature/combo-system-prototype` — preserved early combo/resonance prototype.
- `experiment-unified-comet-shape` — preserved comet contour/shape and future cosmetic-skin direction.
- `experiment-plant-bank-jumping` — preserved small gameplay experiment.

`experiment-vertical-resonance-field` has been merged into main and is preserved by tag; its remote/local branch can be retired after the owner updates their local repository. `merge/gameplay-baseline-to-main` was a temporary integration branch used to resolve independent Godot sterilization metadata; it can be retired after the merge. The old conflicted PR #4 was closed; PR #5 was merged.

## Preserved tag inventory

The user created and pushed these checkpoint/reference tags:
- `foundation/pre-comet-redesign-v1`
- `milestone/gameplay-baseline-v1`
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

Tags preserve exact historical commits without keeping every experiment as an active branch.

# 13. Immediate next steps

1. Finish and audit `chore/project-organization` (folder and context changes).
2. Owner fetches the branch in GitHub Desktop and opens the project in Godot 4.7.x.
3. Wait for Godot's import/UID scan to complete; verify the main scene, player/trail, platform, landing feedback, and test room.
4. Run an Android export and resolve any path/import issues.
5. Merge the organization branch into main only after local validation.
6. Delete the merged `experiment-vertical-resonance-field` and temporary merge branch locally/remotely; preserve their tags.
7. Create `feature/environment-art-library-v1` from the validated main.
8. Start Phase 2: data model and Architecture Library Viewer, then Zone/Subzone Preview and Full-Game Environment Jump-In.
9. Concept the first contrasting zones before expanding the reusable module library.

The environment is ready to move from isolated experiments to a reusable world-building pipeline once repository validation is complete.
