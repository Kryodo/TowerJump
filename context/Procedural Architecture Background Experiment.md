# Architecture Palette Comparison — Test 1

Branch: experiment-architecture-palette-comparison

Parent: experiment-coherent-architecture-silhouettes

Baseline: experiment-vertical-resonance-field

## Purpose

Compare how the empty-space background colour relates to the far and middle architectural silhouette fills. This is a palette-only test using the real TowerJump main scene and its glow configuration.

The production main scene and gameplay scripts, geometry, parallax, contour lines, neon accent colours, and glow settings are unchanged.

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
- Middle structures: current subtle blue-black fill.

This preserves the existing palette for a direct control.

### B — Reversed near-black void

- Background: #010204.
- Far silhouettes: deep blue, approximately #07111E / #081524.
- Middle structures: a more visible dark blue, approximately #0B1B2B.

This tests whether the void should be nearly black while the architecture is what introduces blue into the environment.

### C — Intermediate blue-black

- Background: #010409.
- Far silhouettes: almost-black blue, approximately #030812 / #040B16.
- Middle structures: a subtly lighter blue-black, approximately #06101D.

This keeps the environment very dark while giving the silhouette layers a clearer tonal hierarchy than palette A.

## Controlled variables

All three variants keep the same:
- architecture geometry and its deterministic random stream
- current seed when switching A/B/C
- far/middle/near layer placement and parallax
- muted contour and seam colours
- cyan/violet HDR accent colours and line placement
- actual main scene, WorldEnvironment, glow/bloom settings, ball, trail, platforms, and ambient particles

Only the solid background fill and the far/middle silhouette fills change between palettes. Use the same fixed seed while making the A/B/C comparison; changing seeds is a separate check for robustness.

## Evaluation checklist

1. Which palette best preserves the mysterious empty-space feeling?
2. Does the architecture stand out without looking pasted on or becoming a bright neon wall?
3. Does the middle layer read as a structure, an opening, or an ambiguous overlap?
4. Do the contours and neon accents remain readable under real-game glow?
5. Does the palette still leave the ball and platforms as the clearest, most important elements?

## Validation status

The A/B/C controls and source-level palette routing have been implemented and reviewed. The scene still needs to be run in Godot 4.7.x to verify script parsing and compare the actual rendered results. No visual winner is assumed before that playtest.
