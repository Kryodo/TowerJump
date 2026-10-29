# Architecture Life Treatment Test

Branch: `experiment-architecture-life`

Scene: `scenes/environment_architecture_life_test.tscn`

## Purpose

Test whether static detail can make the far architectural silhouettes feel more constructed and less plain without weakening the established distant-depth effect.

This is the first, intentionally bounded architecture-life experiment. It tests:
- baseline far silhouettes,
- subtle interrupted contours and horizontal joints,
- contours plus sparse, dim window openings.

Each treatment is compared with both established palette families:
- **A1 depth:** near-black far structures with a lifted blue-purple middle fill.
- **A2 integrated:** brighter blue-direction far structures with a dark-blue middle fill.

The global background remains `#02060D`. Geometry, world bounds, parallax, gameplay presentation, and middle/near layer construction remain unchanged. The only new rendering is applied to the far silhouettes when a non-baseline life treatment is selected.

## Run it

1. Switch to `experiment-architecture-life` in GitHub Desktop and fetch/pull.
2. Open `scenes/environment_architecture_life_test.tscn` in Godot.
3. Run **Run Current Scene (F6)**.
4. Keep the same seed and compare the A1 trio first, then the A2 trio. Use the same fixed seed for each direct comparison.

## Controls

| Key | Variant |
|---|---|
| **A** | A1 depth — baseline far silhouettes |
| **B** | A1 depth — subtle contours and joints |
| **C** | A1 depth — contours plus sparse windows |
| **D** | A2 integrated — baseline far silhouettes |
| **E** | A2 integrated — subtle contours and joints |
| **F** | A2 integrated — contours plus sparse windows |
| **1 / 2 / 3** | Select seed 7319 / 24017 / 91207 |
| **R** | Select a random seed |
| **Space / Enter** | Restart from the beginning with the selected seed |

Selecting a seed updates the architecture immediately. Restart afterward to also reseed the actual game and regenerate the foreground/platform sequence consistently.

## Treatment definitions

### Baseline

The far silhouettes use the established rendering with no new details. This is the control.

### Subtle contours and joints

Selected far masses receive short, interrupted inset contours and sparse horizontal panel joints. The marks are low-contrast and non-emissive; they do not use HDR values and should not create a continuous neon outline around the architecture.

### Contours plus sparse windows

Uses the same contour treatment, plus small, dim, theme-tinted window slits on selected far masses. The windows are deliberately sparse, non-HDR, and static. A rarer smaller opening provides some variation without creating a regular grid.

### Palette relationship

Contour/window tints follow the selected A1 or A2 profile, so the details are visually related to the architecture rather than introducing a new unrelated color. The treatments do not change the middle structures, near frames, global void, glow settings, or motes.

## What is deliberately not included

- No flickering or animated lights yet.
- No changes to ambient mote placement, movement, or parallax.
- No new prefabs or architectural geometry.
- No changes to `scenes/main.tscn`, player physics, platform generation, or gameplay scripts.

These are separate future experiments. We should first learn whether static far-layer detail improves the environment and how much detail is appropriate.

## Evaluation checklist

1. Does the far layer feel more constructed and less plain?
2. Do the far silhouettes still feel distant and monumental?
3. Do the added contour marks look integrated into the architecture rather than like outlines drawn on top?
4. Are the windows sparse enough, or do they begin to resemble a repeated grid?
5. Do the details remain subordinate to the ball, platforms, and landing feedback?
6. Does the result work equally well with A1 depth and A2 integration, or does one palette family benefit more?
7. Does the preference persist across fixed seeds 7319, 24017, and 91207?
8. Is the baseline still preferable for some structural styles?

The goal is not to maximize detail. It is to find the smallest amount of detail that gives the far layer more life while protecting depth and readability.

## Validation status

The branch and source-level mappings are checked. The scene still needs to be run in Godot 4.7.x to confirm parsing and evaluate the actual visual result; no Godot runtime execution was available during preparation.
