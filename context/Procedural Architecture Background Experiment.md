# Architecture Experiments — Palette Comparisons and Life Treatment

Branch: experiment-architecture-life

Parent: experiment-architecture-palette-comparison

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

## Current decisions and related test scenes

The global void background is now the leading shared baseline at **`#02060D`**. The H/I/J transition test supported keeping TowerJump's established navy atmosphere rather than switching the global void to near-black or intermediate blue-black. The architectural fill relationships remain open to further testing.

The controlled experiments are kept in separate scenes on this same branch:

- Original A–F palette comparison: `scenes/environment_architecture_test_room.tscn`.
- Void → structure → void transition, including E/F/G recipes and the D-fill H/I/J background sweep: `scenes/environment_architecture_transition_test.tscn`. Notes: `context/Architecture Void Structure Void Comparison.md`.
- Long-form **void → Structure 1 → void → Structure 2** comparison (A1 depth followed by A2 integrated blue): `scenes/environment_architecture_sequence_test.tscn`. Notes: `context/Architecture Sequence Test.md`.
- **Architecture Life Treatment** static far-detail study (baseline / subtle contours / contours plus sparse windows, across A1/A2): `scenes/environment_architecture_life_test.tscn`. Notes: `context/Architecture Life Treatment Test.md`.
- **Architecture Life Treatment Follow-up** (structured recessed bays, dormant/lit/rare-neon window states, and combined treatments across A1/A2): `scenes/environment_architecture_life_followup_test.tscn`. Notes: `context/Architecture Life Treatment Follow-up.md`.
- Final far-fill hue-versus-brightness study: `scenes/environment_architecture_hue_brightness_test.tscn`. Notes: `context/Architecture Far Fill Hue vs Brightness Test.md`.
- Bounded base-composition palette comparison (A1 far tints and A2 middle-fill alternatives): `scenes/environment_architecture_base_palette_test.tscn`. Notes: `context/Architecture Base Composition Palette Test.md`.
- Final E/A2 palette refinements and purple-placement comparison: `scenes/environment_architecture_followup_palette_test.tscn`. Notes: `context/Architecture Follow-up Palette Test.md`.

The latest hue-versus-brightness test holds the background at `#02060D` and the middle fill constant while comparing the original dark far fills, A2's actual color ratios at the original brightness, a brightness-only lift that preserves the original ratios, and the exact A2 values. The hue-only variant was corrected after the first candidate was too close to the background. The bounded base-composition palette test now adds two A1 far-tint options and two A2 middle-fill alternatives; all earlier comparison scenes remain available. These tests are meant to identify useful options for the future art library, not to force every zone to use the same architecture recipe.

The next long-form pass is now available as a separate sequence scene: it holds the global `#02060D` void fixed, then compares the A1 depth-oriented profile and A2 integrated profile in two separated architecture bands using matching geometry seeds. The earlier transition and palette comparison scenes remain available unchanged.

The isolated **Architecture Life Treatment** branch keeps that work as its starting point and adds a bounded static-detail comparison to the far silhouettes. It tests no extra detail, subtle contours/joints, and contours with sparse dim windows under both A1 and A2. Flicker and mote behavior remain out of scope until the static-detail balance is chosen.
The follow-up pass refines the detail vocabulary into geometry-aligned recessed bays and static window states (mostly dark, some subtly lit, rare low-strength neon), with separate contour-only, window-only, and combined variants. The first life-treatment scene is retained as the baseline reference. Flicker and mote behavior remain out of scope until these static treatments are visually approved.

The earlier irregular **Abstract Energy** aperture trial was rejected because its free-form shapes and small circular energy marks felt arbitrary. Its active renderer modes have been replaced by the organized **Panel Cluster Treatment** below; the old scene entry point now opens the corrected test for compatibility.

The **Panel Cluster Treatment** is the current far-detail direction after the irregular aperture experiment felt too arbitrary. It compares five organized rectangular cluster compositions (squares, broad panels, tall panels, separated pairs, and substantial charged slits), some placed in shallow recesses and others directly on the silhouette. Individual elements have dormant, active, and energized states; the animated variant adds slow charge travel while preserving the previous window treatment's visible neon character. Scene: `scenes/environment_architecture_panel_cluster_test.tscn`; notes: `context/Architecture Panel Cluster Treatment.md`.

The mote depth/parallax idea and restrained architectural accent flicker remain separate future polish investigations. Neither is changed by these palette tests.

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
- current seed when switching A–F
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
