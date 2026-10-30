# Middle Architecture Detail Study

Branch: `experiment-middle-architecture-details`

Scene: `scenes/middle_architecture_detail_test.tscn`

## Purpose

Determine whether the middle architectural supports benefit from additional structural depth beyond their existing broad fills, partial contours, recessed vertical seam, sparse horizontal joints, and short cyan/violet edge accents.

The study deliberately uses a different visual language from the far silhouettes. No additional neon windows, bright aperture clusters, floating geometry, or particle effects are introduced.

## Controls

Run the scene with **F6**.

| Key | Treatment |
|---|---|
| **A** | Original middle architecture (control) |
| **B** | Stepped structural inset plates |
| **C** | Stepped plates + a sparse set of dark mechanical recesses |
| **5** | A1 Depth architecture palette |
| **6** | A2 Integrated architecture palette (default) |
| **1 / 2 / 3** | Fixed seeds 7319 / 24017 / 91207 |
| **R** | Random environment seed |
| **Space / Enter** | Restart |

The approved far-aperture flicker and architecture-matched mote parallax stay enabled and unchanged in every variant:
- Far motes: 0.18
- Middle motes: 0.46
- Near motes: 0.82

Switch A/B/C at the same climb height and use the same seed to judge only the middle-layer treatment.

## Variants

### A — Original

The current middle architecture is shown without additional details. This is the control and must remain visually identical to the reference architecture.

### B — Stepped inset plates

Selected middle support modules receive one recessed vertical plate with a dark pocket, a smaller stepped inner surface, a partial shoulder reveal, interrupted internal divisions, and a short offset lower foot. The treatment is non-emissive and stays embedded in the existing support silhouette.

### C — Plates + mechanical recesses

Adds a small number of compact dark slot recesses to selected modules on top of B. These are structural cavities, not windows: they use no neon or animated light and avoid a repeated residential grid.

## What stays fixed

- Actual `scenes/main.tscn` gameplay and camera reference
- Approved far aperture clusters, three light states, and switch/shimmer flicker
- Approved mote parallax values and existing particle settings
- A1/A2 palettes and #02060D void
- Existing middle support geometry, landmarks, contours, and neon accents
- Player, ball, platforms, HUD, camera behavior, and glow settings

Only the middle detail treatment changes between A/B/C.

## Evaluation

1. Does B make the middle support structures feel more constructed and dimensional?
2. Do the stepped plates read as part of the same monumental structure rather than surface decoration?
3. Does C add useful mechanical character, or does it become too panel-like?
4. Are the new details visible at gameplay scale without competing with the ball and platforms?
5. Do the details remain subdued behind the stronger far-aperture flicker and mote depth?
6. Does the added detail work under both A1 and A2?
7. Is the original A treatment still preferable?

## Validation

Source reviewed; Godot 4.7.x runtime parsing and visual judgment are still required. No treatment is assumed to be the winner before playtesting.
