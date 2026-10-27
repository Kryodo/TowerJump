# Procedural Architecture Background — Experiment

Branch: `experiment-procedural-architecture-background`

Base: `experiment-vertical-resonance-field`

## Purpose

Prove that one TowerJump vertical section can feel like a coherent, enormous architectural environment using procedural composition from a small set of geometry motifs. This is an isolated visual experiment; the production main scene and gameplay scripts are not modified.

## Run it

1. Switch to `experiment-procedural-architecture-background` in GitHub Desktop and open the project in Godot.
2. Open `scenes/environment_architecture_test_room.tscn`.
3. Use **Run Current Scene (F6)**. The normal main scene remains unchanged.
4. Steer with the left/right arrow keys. The test room reuses the existing ball, platform scene and platform spawner.
5. Press `R` to generate a new composition, or `1`, `2`, or `3` to compare fixed seeds.

## What the experiment contains

- A dark atmospheric foundation with restrained vertical color bands.
- Three separate architectural layers: far silhouettes, mid-distance structures, and nearer framing geometry.
- Vertical parallax tied to camera movement, so layers travel at different rates.
- Reusable motifs made from simple polygons, line work, arcs, ribs and angular frames.
- A composed focal landmark, **The Resonance Gate**, with depth echoes across the layers.
- An isolated **Archive Fragment** visual signature to test how a discovery could sit within the environment.
- Deterministic seeds that vary surrounding architecture while retaining the core landmark composition.
- The existing neon ball and pattern-based platform generation in front of the background, to evaluate contrast and gameplay readability in motion.

## Evaluation goals

1. Does the architecture make the world feel large and vertically continuous?
2. Are far/mid/near layers distinguishable while ascending?
3. Does the background frame the playable route rather than fight it?
4. Does the Resonance Gate read as a memorable landmark rather than decoration?
5. Do fixed seeds feel like different compositions without losing the zone's identity?
6. Is the geometry-driven approach flexible enough to support a future environment kit per zone?

## Deliberate prototype limits

- This is one visual section, not the final tower atlas or a complete zone-transition system.
- The Archive Fragment is currently environmental decoration, not a collectible with gameplay or profile integration.
- Geometry is generated procedurally from code; there are no imported art assets.
- Difficulty, movement values, platform patterns and gameplay mechanics are unchanged.

## Validation status

The branch and source files have been created from the baseline, but the scene still needs to be opened and run in Godot 4.7.x to verify rendering, parallax, glow behavior and visual readability on the target device. Do not treat the prototype as engine-validated until that playtest is complete.
