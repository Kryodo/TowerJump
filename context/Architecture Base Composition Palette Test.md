# Architecture Base-Composition Palette Test

Branch: `experiment-architecture-palette-comparison`

Scene: `scenes/environment_architecture_base_palette_test.tscn`

## Purpose

This is the final bounded palette comparison before moving on to a complete environmental scene. It compares two specific refinements while preserving the original global navy background and the full existing game presentation.

- A1's depth-oriented composition, with two alternative far-silhouette tints.
- A2's integration-oriented composition, with two middle-fill alternatives that no longer resemble the global background so closely.

This test does not replace or remove any of the earlier A–F, transition, or hue-versus-brightness scenes.

## Run it

1. Switch to `experiment-architecture-palette-comparison` in GitHub Desktop.
2. Open the Godot project.
3. Open `scenes/environment_architecture_base_palette_test.tscn`.
4. Run Current Scene (**F6**).
5. Compare **A → B → C** for the A1 family, then **D → E → F** for the A2 family. Switching keys does not rebuild the scene.
6. Use **1** (7319), **2** (24017), or **3** (91207) for fixed seeds. Use **R** for a random seed. Press **Space** or **Enter** after choosing a seed to restart the foreground game scene with that seed.

## Fixed throughout

- Global background: `#02060D`, applied to the game's actual Background ColorRect and the architecture band fill.
- Geometry, deterministic architecture layer seed, parallax factors, seams, contour lines, accents, landmarks and near frames.
- Actual main game scene, camera, ball/trail, platforms, ambient motes, WorldEnvironment and glow/bloom.
- Far fill alpha: `0.98`; middle fill alpha: `0.96`.

Only the named fill palette changes.

## A1 family: preserve A1's brighter blue-purple middle fill

All three use the A1 middle fill `Color(0.015686275, 0.03137255, 0.0627451, 0.96)`.

### A — A1 baseline

- Far mass A: `Color(0.004, 0.012, 0.026, 0.98)`.
- Far mass B: `Color(0.006, 0.016, 0.032, 0.98)`.
- Middle fill: A1's existing brighter dark blue-purple value.

This is the original high-depth reference.

### B — A1 with darker indigo far tint

- Far mass A: `Color(0.012, 0.010, 0.032, 0.98)`.
- Far mass B: `Color(0.016, 0.012, 0.038, 0.98)`.
- Middle fill: unchanged from A1.

The far fills are darker overall than the navy background but introduce a visible indigo/blue-purple relationship instead of using the original near-black control values. The middle fill remains clearly brighter and more blue-weighted.

### C — A1 with brighter blue-purple far tint

- Far mass A: `Color(0.020, 0.026, 0.066, 0.98)`.
- Far mass B: `Color(0.025, 0.027, 0.072, 0.98)`.
- Middle fill: unchanged from A1.

The far fills are slightly brighter than the navy background, with a more purple-leaning channel balance than the original middle fill. Judge whether this softens the transition into the void without merging visually with the A1 middle structures.

## A2 family: keep A2's brighter far fills, change the middle fill

All three use A2's original far fills:

- Far mass A: `Color(0.011764706, 0.03137255, 0.0627451, 0.98)`.
- Far mass B: `Color(0.015686275, 0.039215688, 0.078431375, 0.98)`.

### D — A2 baseline

Uses A2's original middle fill `Color(0.011, 0.024, 0.044, 0.96)`, which previously looked too similar to the global navy background in some compositions.

### E — A2 with dark blue middle fill

- Middle fill: `Color(0.0055, 0.0165, 0.038, 0.96)`.

A cooler dark-blue fill below the background's overall brightness. Evaluate whether it is still visibly structural and avoids distracting cutout-like gaps.

### F — A2 with dark blue-purple middle fill

- Middle fill: `Color(0.014, 0.010, 0.038, 0.96)`.

A darker purple-leaning alternative related to A1's cool palette, but with a much lower green/blue balance than A1's brighter middle fill. Evaluate whether the color reads as intentional architectural tint rather than black or muddy purple.

## Evaluation checklist

1. For A1, does the dark indigo tint in B preserve enough tint to avoid pure-black masses while keeping A1's strong depth?
2. Does C sit more naturally against the navy void without merging into the middle layer?
3. For A2, does E's dark blue middle layer remain readable when gaps occur between far masses?
4. Does F provide a clearer identity from the void while retaining A2's ambiguity and foreground integration?
5. Across every version, do ball, trail and platforms remain the most salient elements?
6. Do the choices remain convincing while climbing and across the fixed seeds?

The existing values are authored candidates. No visual winner is assumed until the scene is run in Godot and reviewed.

## Validation status

Source and branch wiring checks should be followed by a Godot 4.7.x runtime test. No Godot runtime execution was performed as part of this change.
