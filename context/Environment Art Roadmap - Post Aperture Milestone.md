# Environment Art Roadmap — After the Aperture Milestone

Current reference branch: `experiment-abstract-energy-apertures`

Current active workstream: `experiment-middle-architecture-details` (mote depth approved; middle-layer A/B/C study prepared)

## Locked baseline

The organized far-silhouette aperture treatment is now a successful generic environment baseline:
- compact, deliberate rectangular clusters
- recesses and isolated aperture groups fully contained inside the far silhouette
- three readable light states: dormant, mid-level, and strong neon
- a mixture of gentle shimmer and switch-like on/off activity

Do not add more generic far-layer details at this stage. Preserve the current treatment as a reusable option. Future far-detail variants should be justified by a zone identity, landmark, or environmental function rather than added as decoration.

## Work sequence

### 1. Ambient mote depth — APPROVED

Architecture-matched parallax is visually approved and locked as the common environment baseline:
- Far motes: `0.18`
- Middle motes: `0.46`
- Near motes: `0.82`

This gives the void a convincing sense of scale while integrating the particles into the same spatial model as the far, middle, and near architecture. The A/C/D alternatives remain in the comparison scene for reference, but B is now its startup/default mode.

Keep the current mote appearance unchanged for now. Particle counts, textures, gradients, colors, lifetimes, emission areas, velocities, and size ranges were deliberately held fixed during the depth study.

### 2. Middle-layer structural detail — READY FOR VISUAL TESTING

A dedicated A/B/C experiment is prepared on `experiment-middle-architecture-details` in `scenes/middle_architecture_detail_test.tscn`:
- A: original middle architecture, unchanged control
- B: sparse stepped inset plates with dark pockets and partial structural reveals
- C: B plus a small number of dark mechanical recesses

The far aperture treatment and approved mote parallax remain fixed. No extra neon windows, repeated bright accents, floating geometry, or dense panel grids are introduced. Only the middle support details change. The goal is to make the supports feel more constructed and monumental without competing with the player, platforms, or far-layer lighting.

### 3. Define the first zone concepts

Before creating several art variants, define at least two contrasting zone identities. Each concept should establish a recognizable environmental role, palette relationship, structural silhouette/landmark language, and atmosphere. Avoid treating zones as palette swaps alone.

### 4. Build Art Library V1 around proven variation points

After the first two zone concepts and the mote/middle-layer decisions, formalize only the settings that actually need to vary. A likely V1 composition is:

- **Zone art profile:** combines palette, architecture, landmarks, and atmosphere.
- **Palette profile:** void/background, far fills, middle fills, seams, edge reveals, and emissive accents.
- **Architecture profile:** far detail treatment, middle structural treatment, near-frame treatment, and landmark selection.
- **Atmosphere profile:** mote layer count, parallax scales, emission, size, velocity, palette, and density.

The preview tool should load a zone profile into a dedicated environment test room, show the actual TowerJump camera/player/platform reference, expose deterministic seeds, and allow side-by-side profile comparisons. Keep gameplay systems and production gameplay code out of this art-preview pipeline.

## Efficiency rules

1. One experiment branch per visual question.
2. Change one family of variables at a time.
3. Keep a known-good baseline in every comparison.
4. Prefer deterministic seeds and the actual game camera/rendering setup.
5. Promote a treatment into the art library only after it works at gameplay scale.
6. Do not refactor the procedural architecture into a generic data model before we know which profile fields genuinely vary between zones.

## Current status

- Far aperture treatment: visually approved reference; further generic detail deferred.
- Ambient mote parallax: architecture-matched depths 0.18 / 0.46 / 0.82 visually approved and locked; combined test defaults to B.
- Middle-layer detail: four inset patterns, varied cavity layouts, value-aware recess colors, and D-key diagnostic contrast added; awaiting runtime visual evaluation.
- Zone concepts: next design milestone after depth integration and the middle-layer detail study.
- Art Library V1: schema and preview tooling follow those decisions, rather than preceding them.
