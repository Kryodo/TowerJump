# Architecture Palette Comparison — Tests 1–2

Branch: experiment-architecture-palette-comparison

Parent: experiment-coherent-architecture-silhouettes

Baseline: experiment-vertical-resonance-field

## Purpose

Compare how the empty-space background colour relates to the architectural silhouette fills, then isolate middle-fill and far-silhouette changes under the original navy background. This uses the actual TowerJump main scene and its production glow setup.

The earlier B/C palette values were too bright and exposed the geometry. This revision corrects that mistake: it keeps the original low-contrast art direction and reverses only the dark colour roles.

The production main scene, gameplay scripts, geometry, parallax, contour lines, neon accents, and glow settings remain unchanged.

## Run it

1. Switch to experiment-architecture-palette-comparison in GitHub Desktop.
2. Open the project in Godot.
3. Open scenes/environment_architecture_test_room.tscn.
4. Use **Run Current Scene (F6)**.
5. Press **A–F** to switch variants while keeping the current seed. A is A0, E is A1, and F is A2; B/C/D are retained from the previous pass. Use **1**, **2**, or **3** to set a fixed seed, **R** for a new seed, and **Space** to restart.

## Palette variants

### A / A0 — Current navy (control)

- Background: current TowerJump navy, #02060D.
- Far silhouettes: current near-black blue fills.
- Middle filled structures: current subtle blue-black fill.

This preserves the existing palette for direct comparison and serves as the A0 control for the original-navy pass.

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

### D — C with slightly brighter middle architecture

- Background: identical to C, #01050A.
- Far silhouettes: identical to C, using the same subdued navy fills.
- Middle filled support structures: a small fill-only lift from approximately #03070D to #040810.
- Geometry, parallax, seams, contour colors, HDR accents, landmarks, and near frames remain unchanged.

D exists solely to test whether a little extra separation makes the middle supports legible without undermining the unified, monumental impression that made C attractive. Compare C and D with the same fixed seed; do not judge D against a different architectural arrangement.

### E / A1 — Original navy + brighter middle fill

- Background: identical to A0, #02060D.
- Far silhouettes: unchanged from A0 (the original near-black blue fills).
- Middle filled support structures: the same approximately #040810 fill used by D.
- Geometry, parallax, seams, contour colors, HDR accents, landmarks, and near frames remain unchanged.

E isolates the middle-fill lift on the original navy background. Compare A and E with the same seed.

### F / A2 — Original navy + brighter blue far silhouettes

- Background: identical to A0, #02060D.
- Far silhouettes: slightly brighter, more blue-direction fills, approximately #030810 and #040A14 instead of the original near-black fills.
- Middle filled support structures: unchanged from A0.
- Geometry, parallax, seams, contour colors, HDR accents, landmarks, and near frames remain unchanged.

F isolates the far-mass fill change. Compare A and F with the same seed. The goal is subtle structural definition, not bright or outlined architecture.

## Controlled variables

All six variants keep the same:
- architecture geometry and deterministic random stream
- current seed when switching A/B/C
- far/middle/near layer placement and parallax
- muted contour and seam colours
- cyan/violet HDR accent colours and line placement
- actual main scene, WorldEnvironment, glow/bloom settings, ball, trail, platforms, and ambient particles

Across A–F, the geometry, parallax, seams, contour colors, neon accents and seed remain fixed while selecting variants. D changes only C's middle fill. E changes only A0's middle fill. F changes only A0's far fills. A/B/C remain the previous palette tests. Use the same fixed seed for direct comparisons; changing seeds is a separate robustness check.

## Evaluation checklist

1. Does B preserve the original subtle contrast while making the empty space feel more like a void?
2. Do the silhouettes remain largely hidden, with only enough definition to suggest architecture?
3. Does C feel like a useful middle ground between A and B?
4. Compared with C, does D make the middle supports read more clearly without making them feel pasted on or too prominent?
5. Do the existing contours and neon accents remain restrained under real-game glow?
6. Does the palette keep the ball and platforms as the clearest elements?
7. In the original navy comparison, does E's middle-fill lift improve integration without becoming too visible?
8. Does F's brighter blue-direction far fill solve the cutout-like effect while preserving the navy void?

## Validation status

A/B/C remain available as before; D retains the C middle-fill contrast test. E and F add the A1/A2 original-navy comparisons. The source changes are reviewed, but the scene still needs to be run in Godot 4.7.x to confirm script parsing and judge actual rendering. No visual winner is assumed before that playtest.
