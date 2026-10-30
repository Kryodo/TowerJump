# Combined Ambient Mote + Architecture Parallax Test

Branch: `experiment-ambient-mote-parallax`

Scene: `scenes/ambient_mote_parallax_test.tscn`

## Purpose

The current three mote emitters live under `GameCamera`, but their existing particle setup uses global coordinates: already-emitted particles stay in world space after they spawn. That means the current three sets effectively share one world-space scroll speed instead of receiving distinct far, middle, and near depth behavior. This test compares that exact baseline with three actual parallax depth distributions.

The test instantiates the real `scenes/main.tscn` as its gameplay reference and now adds the approved procedural architecture stack on top of it: compact far-silhouette apertures with the approved flicker treatment, existing middle architecture and landmarks, and near framing. The architecture is rendered behind the mote layers so the combined depth relationship can be judged in the actual gameplay camera. No production scenes, particle settings, camera behavior, architecture source, or gameplay scripts are modified.

## Controls

Run the scene with **F6**.

| Key | Mode |
|---|---|
| **A** | Current single-depth/global-space particle behavior |
| **B** | Architecture-matched parallax: far 0.18 / mid 0.46 / near 0.82 |
| **C** | Subtle depth separation: far 0.10 / mid 0.30 / near 0.55 |
| **D** | Pronounced depth separation: far 0.28 / mid 0.62 / near 0.92 |
| **5** | A1 Depth architecture palette |
| **6** | A2 Integrated architecture palette (default) |
| **1 / 2 / 3** | Fixed run seeds 7319 / 24017 / 91207 |
| **R** | Random run seed |
| **Space / Enter** | Restart |

Switch A–D during the same run to compare the depth behavior at the same climb height. Particle systems restart when switching, so allow their fields to repopulate before judging density.

## What stays fixed

All variants preserve the three existing emitters' particle counts, textures, gradients, emission extents, lifetimes, velocities, scale ranges, and z-order. Mode A preserves their current global-coordinate behavior. The parallax modes set particle local coordinates so existing particles move with their own parallax layer; only coordinate behavior and scroll scales change.

The approved architecture is always present. Keys 5 and 6 switch between the A1 and A2 palette treatments without changing the mote depth variant. The default is A2 with compact far-aperture states and switch/shimmer flicker enabled.

The parallax variants set particle local coordinates so existing particles move with their parallax layer. Each layer repeats vertically to keep the ambient field present as the camera climbs.

## Evaluation

1. Does B integrate motes into the established far / middle / near architecture depth?
3. Does C feel more atmospheric and distant, or too static?
4. Does D create convincing foreground movement, or distract from the ball and platforms?
5. Do the motes move at a useful speed relative to the architecture while the camera climbs?
6. Does the particle field remain continuous across longer runs without obvious repetition?
7. Do the current mote sizes, brightness, and density still feel balanced once depth is introduced?
8. Does A1 or A2 provide the better combined architecture-and-void relationship?
9. Does the far aperture flicker remain readable through the mote field without losing its impact?
10. Does the effect remain subtle during camera landing response and streak zoom?

## Validation

The code is source-reviewed, but Godot 4.7.x runtime parsing and visual testing are required. No visual winner is assumed. The experiment is isolated from the successful `experiment-abstract-energy-apertures` milestone and all production files.
