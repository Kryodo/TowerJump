# Architecture Life Treatment — Follow-up Pass

Branch: `experiment-architecture-life`

Scene: `scenes/environment_architecture_life_followup_test.tscn`

Reference scene retained from the first pass: `scenes/environment_architecture_life_test.tscn`

## Purpose

The first life-treatment test showed that static details help the far silhouettes, especially windows, but its short contour strokes felt arbitrarily placed. This follow-up gives the details a clearer architectural role and introduces multiple window states.

It compares four treatments under both established palette families:

- **Baseline:** no new far-layer detail.
- **Structured contours:** repeated recessed facade bays with aligned rails, panel edges, and an occasional internal joint.
- **Window states:** dark openings, subdued internal illumination, and rare low-strength neon windows.
- **Combined:** structured facade bays and window states together.

A1 is the depth-oriented family (near-black far structures with a lifted blue-purple middle layer). A2 is the integrated family (brighter blue-direction far structures with dark-blue middle structures).

## Run it

1. Switch to `experiment-architecture-life` in GitHub Desktop and fetch/pull.
2. Open `scenes/environment_architecture_life_followup_test.tscn` in Godot.
3. Run **Run Current Scene (F6)**.
4. With seed 7319, compare A–D first, then E–H. Use the same seed for every direct comparison.
5. Try seeds 24017 and 91207 after the first pass. Use **Space / Enter** to restart with the selected seed.

## Controls

| Key | Variant |
|---|---|
| **A** | A1 depth — baseline |
| **B** | A1 depth — structured contours |
| **C** | A1 depth — window states |
| **D** | A1 depth — contours + window states |
| **E** | A2 integrated — baseline |
| **F** | A2 integrated — structured contours |
| **G** | A2 integrated — window states |
| **H** | A2 integrated — contours + window states |
| **1 / 2 / 3** | Fixed seeds 7319 / 24017 / 91207 |
| **R** | Random seed |
| **Space / Enter** | Restart the run |

Selecting a seed immediately updates the architecture. Restart after selecting a seed to reseed the foreground game's platform generation as well.

## Treatment notes

### Structured contours

The far layer uses a repeated recessed facade bay rather than disconnected decorative strokes. A subdued inset fill, panel rails, and occasional internal joint suggest a constructed surface. The motif repeats selectively and is deliberately interrupted, so not every silhouette becomes a fully outlined grid.

A1 uses a slightly lifted violet-indigo edge treatment to help the details remain legible against its darker masses. A2 uses cooler blue contours. These colors are separate from the middle layer's more prominent neon accents.

### Window states

Window groups are placed in a consistent facade bay. The exact state is deterministic from the environment module index and window position, so a fixed seed reproduces the same pattern.

- **Dormant:** a nearly black aperture with a quiet frame.
- **Subdued illumination:** a low-intensity blue or violet interior suggesting activity inside.
- **Rare neon:** a thin, restrained colored interior and a low-alpha halo. Its color intensity remains below the middle architecture's principal HDR accents.

Most windows remain dark, fewer are subtly lit, and emitting windows are rare. The windows are static; no flicker or time-based state changes are introduced in this pass.

### Combined treatment

This combines the recessed bay construction with the window-state groups. It tests whether the details reinforce one another or whether the far layer becomes too busy.

## Fixed variables / out of scope

- The global background remains `#02060D`.
- The same architecture geometry rules, bounds, parallax, foreground gameplay, camera, glow/bloom, middle structures, near frames, and ambient motes are used.
- No changes to `scenes/main.tscn`, player physics, platform generation, or production gameplay logic.
- No flickering lights, animated windows, mote movement changes, or new architecture geometry.
- The original first-pass life scene and all palette/transition comparison scenes remain available.

## Evaluation checklist

1. Do the recessed bays feel built into the architecture rather than lines drawn over it?
2. Are the contours visible enough on A1 without flattening the far depth?
3. Does A2 gain useful detail without becoming too busy?
4. Do dark windows create convincing negative space within the facade?
5. Do the subdued lit windows suggest activity without turning into a grid of glowing dots?
6. Are the rare neon windows noticeable on inspection but clearly weaker than the middle-layer neon accents?
7. Does the combined treatment feel more immersive than either treatment alone, or does it add too much?
8. Which treatment works best for A1 versus A2?
9. Does the result remain coherent across the three fixed seeds?

The goal is not to maximize lit windows or draw borders around every panel. It is to establish a reusable static-detail vocabulary that adds scale and architectural logic while leaving the far layer distant.

## Validation status

The follow-up scene and treatment mappings are source-authored and checked against the renderer/manager enum values. Godot 4.7.x runtime parsing and visual evaluation are still required; no runtime execution was available during preparation.
