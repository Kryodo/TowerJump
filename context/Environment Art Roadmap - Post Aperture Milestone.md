# Environment Art Roadmap — After the Aperture Milestone

Current reference branch: `experiment-abstract-energy-apertures`

Current next experiment: `experiment-ambient-mote-parallax`

## Locked baseline

The organized far-silhouette aperture treatment is now a successful generic environment baseline:
- compact, deliberate rectangular clusters
- recesses and isolated aperture groups fully contained inside the far silhouette
- three readable light states: dormant, mid-level, and strong neon
- a mixture of gentle shimmer and switch-like on/off activity

Do not add more generic far-layer details at this stage. Preserve the current treatment as a reusable option. Future far-detail variants should be justified by a zone identity, landmark, or environmental function rather than added as decoration.

## Work sequence

### 1. Integrate ambient motes with environmental depth

Use the isolated `Ambient Mote Parallax Test` to compare:
- current camera-attached behavior
- parallax values matched to the architecture layers
- a subtler depth spread
- a more pronounced depth spread

Keep all current mote aesthetics fixed during this comparison: particle counts, textures, gradients, colors, lifetimes, emission areas, velocities, and size ranges. Choose the depth behavior first; tune appearance only if the selected parallax exposes a specific problem.

### 2. Explore a distinct middle-layer detail language

The middle layer can support some additional detail, but should not copy the far-layer apertures. Its larger forms already use broad fills, partial contour reveals, recessed vertical seams, sparse joints, and occasional cyan/violet edge accents. It also contains the Resonance Gate and Archive Recess landmarks.

Run a dedicated, reversible A/B/C study:
- A: current middle layer as the unchanged control
- B: sparse structural depth cues, such as stepped inset plates, interrupted buttress joints, or small mechanical recesses
- C: a restrained combination only if B proves useful

Do not begin with extra neon windows, repeated bright accents, floating geometry, or dense panel grids. The test should answer whether these additions make the middle structures feel more constructed and monumental without competing with the player, platforms, or far-layer light sources.

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
- Ambient mote parallax: test harness added; awaiting runtime visual evaluation.
- Middle-layer detail: scoped, not yet implemented.
- Zone concepts: next design milestone after depth integration and the middle-layer detail study.
- Art Library V1: schema and preview tooling follow those decisions, rather than preceding them.
