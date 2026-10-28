# Architecture Palette Comparison — Test 1

Branch: experiment-architecture-palette-comparison

Parent: experiment-coherent-architecture-silhouettes

Baseline: experiment-vertical-resonance-field

## Purpose

Compare how the empty-space background colour relates to the architectural silhouette fills. This is a palette-only test using the actual TowerJump main scene and its production glow setup.

The earlier B/C palette values were too bright and exposed the geometry. This revision corrects that mistake: it keeps the original low-contrast art direction and reverses only the dark colour roles.

The production main scene, gameplay scripts, geometry, parallax, contour lines, neon accents, and glow settings remain unchanged.

## Run it

1. Switch to experiment-architecture-palette-comparison in GitHub Desktop.
2. Open the project in Godot.
3. Open scenes/environment_architecture_test_room.tscn.
4. Use **Run Current Scene (F6)**.
5. Press **A**, **B**, or **C** to switch palette while keeping the current seed. Use **1**, **2**, or **3** to set a fixed seed, **R** for a new seed, and **Space** to restart.

## Palette variants

### A — Current navy (control)

- Background: current TowerJump navy, #02060D.
- Far silhouettes: current near-black blue fills.
- Middle filled structures: current subtle blue-black fill.

This preserves the existing palette for direct comparison.

### B — Reversed dark colour roles

- Background: near-black #010307.
- Far silhouettes: original game navy #02060D, with only a tiny variation for adjacent masses.
- Middle filled structures: near-black #03070D.

This swaps the current near-black far-mass shade and the game navy without introducing brighter blue. The nearest filled architecture remains only fractionally lighter than near-black.

### C — Intermediate background

- Background: #01050A, between A's navy and B's near-black.
- Far silhouettes: the same subdued original-game navy values as B.
- Middle filled structures: the same near-black #03070D as B.

This tests whether a slightly lifted near-black background keeps enough atmosphere while preserving the restrained silhouette hierarchy.

## Controlled variables

All three variants keep the same:
- architecture geometry and deterministic random stream
- current seed when switching A/B/C
- far/middle/near layer placement and parallax
- muted contour and seam colours
- cyan/violet HDR accent colours and line placement
- actual main scene, WorldEnvironment, glow/bloom settings, ball, trail, platforms, and ambient particles

Only the solid background fill and far/middle silhouette fills change between palettes. No new brighter-blue fills, extra outlines, or additional details are introduced. Use the same fixed seed while comparing A/B/C; changing seeds is a separate robustness check.

## Evaluation checklist

1. Does B preserve the original subtle contrast while making the empty space feel more like a void?
2. Do the silhouettes remain largely hidden, with only enough definition to suggest architecture?
3. Does C feel like a useful middle ground between A and B?
4. Do the existing contours and neon accents remain restrained under real-game glow?
5. Does the palette keep the ball and platforms as the clearest elements?

## Validation status

The corrected A/B/C fills and controls have been implemented and source-reviewed. The scene still needs to be run in Godot 4.7.x to confirm script parsing and compare the actual rendered results. No visual winner is assumed before that playtest.
