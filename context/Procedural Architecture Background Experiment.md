# Coherent Architecture Silhouettes — Experiment

Branch: `experiment-coherent-architecture-silhouettes`

Parent prototype: `experiment-procedural-architecture-background`

Baseline: `experiment-vertical-resonance-field`

## Purpose

Replace the first prototype's scattered polygon/arc composition with a consistent visual grammar: large connected side masses, repeated buttress/support modules, carefully interrupted seams, and an open central play lane. The goal is to make the tower feel like one enormous constructed place while keeping the background dark but clearly legible and subordinate to foreground gameplay.

This is an isolated visual experiment. The production main scene and gameplay scripts are not modified. The test wrapper instantiates the actual main scene at runtime so the experiment is evaluated with the real rendering and gameplay setup.

## Run it

1. Switch to `experiment-coherent-architecture-silhouettes` in GitHub Desktop.
2. Open the project in Godot.
3. Open `scenes/environment_architecture_test_room.tscn`.
4. Use **Run Current Scene (F6)**.
5. Steer with the left/right arrow keys. Press `R` for a new bounded composition, `1`, `2`, or `3` for fixed seeds, or `Space` to restart the run.

## Visual grammar

- **Far layer:** overlapping, dark architectural masses with a repeated stepped inner edge. These are broad silhouettes, not collections of independent fragments.
- **Mid layer:** repeated upright/support/buttress modules, occasional missing modules, rare recessed seams, and a consistent structural cadence.
- **Near layer:** sparse, interrupted side rails only. It does not form a third pile of shapes over the play area.
- **Palette:** the base fill matches the real game's blue-black background. Broad silhouettes use clearly separated dark values, with low-contrast edge reveals and only occasional cyan/violet HDR accents. Those accents should respond to the actual glow pass without turning the environment into a bright neon outline.
- **Play lane:** the middle remains mostly open. The architecture frames play from the sides rather than filling the center.
- **Resonance Gate:** retained as one composed landmark in the mid layer, built from a thick dark mass and a clear aperture. It has only a few restrained seams, with no duplicated arcs or shards in other depth layers.
- **Archive Fragment:** retained as a small recessed object embedded into the side structure, rather than a floating ring/diamond glyph.

## What changed from the first prototype

The original experiment's drawing script and background manager are revised only on this branch. Geometry now varies within authored module proportions and vertical rhythm rather than choosing unrelated shape primitives. The background's broad tinted horizontal bands were removed. Parallax remains, but is used to separate depth layers, not to duplicate landmark fragments.

The test wrapper instantiates `scenes/main.tscn` itself, then inserts the architecture between the main scene's background color and ambient motes. This reuses the exact production `WorldEnvironment` resource and settings (`BG_CANVAS`, glow enabled, intensity 0.8, bloom 0.3, HDR threshold 0.5), as well as the real ball/trail, platforms, motes, HUD, camera, and landing feedback. This prevents the test from proving the concept under a different glow setup.

## Evaluation checklist

1. Does the architecture read as a connected megastructure instead of abstract geometry?
2. Are the silhouettes clearly visible while the real ball/platform bloom remains dominant?
3. Does the center remain open enough for platforms, ball, and later hazards?
4. Do different seeds retain the same visual identity while giving modest compositional variation?
5. Does the Gate still feel special, without becoming a bright screen-filling effect?
6. Does the Archive look embedded in the environment and worth investigating?

## Deliberate limits / validation

This remains one art-direction prototype, not a finished zone kit, landmark system, or procedural tower atlas. The Archive is visual only and is not a collectible. The experiment must still be opened and run in Godot 4.7.x to verify script parsing, layer order, parallax, glow response, and target-device readability. The test now uses the real main scene and environment rather than reproducing those settings manually; engine/runtime validation is still pending. Do not treat it as engine-validated until that test is complete.
