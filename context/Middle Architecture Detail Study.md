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
| **C** | Stepped plates + varied mechanical recess patterns |
| **D** | Toggle high-contrast diagnostic colors for the currently selected B/C treatment |
| **5** | A1 Depth architecture palette |
| **6** | A2 Integrated architecture palette (default) |
| **1 / 2 / 3** | Fixed seeds 7319 / 24017 / 91207 |
| **R** | Random environment seed |
| **Space / Enter** | Restart |

The approved far-aperture flicker and architecture-matched mote parallax stay enabled and unchanged in every variant:
- Far motes: 0.18
- Middle motes: 0.46
- Near motes: 0.82

Switch A/B/C at the same climb height and use the same seed to judge only the middle-layer treatment. Press D at any time to toggle diagnostic contrast without changing the selected geometry.

## Variants

### A — Original

The current middle architecture is shown without additional details. This is the control and must remain visually identical to the reference architecture.

### B — Stepped inset plates

Selected middle support modules receive one of four deterministic inset compositions: a tall single bay, two offset stacked recesses, a broad horizontal housing with a compact companion, or a paired vertical arrangement. Each uses a dark pocket, smaller stepped interior, partial shoulder reveal, and pattern-specific internal divisions. Some include a short offset foot. The normal treatment is non-emissive and stays embedded in the existing support silhouette.

### C — Plates + mechanical recesses

Adds a small number of mechanical cavity groups to selected modules on top of B. Their deterministic arrangements vary between paired vertical cavities, broad-and-compact companions, staggered mixed orientations, and short uneven service cuts. These are structural cavities, not windows: they use no neon or animated light and avoid a repeated residential grid.

## Value treatment and diagnostic mode

Normal recess colors respond to the resolved middle fill value, but all middle-layer recesses now stay within a dark blue/indigo family rather than using near-black. Very dark blue/purple fills receive dark-indigo cavities with more visible indigo edges and separation lines. Slightly brighter fills use deeper indigo shadows. This keeps the middle structures from reading as hollow black cutouts; the far layer remains the place where black apertures pair with their internal ambient lights.

Press **D** to toggle diagnostic contrast. The same B/C geometry is recolored with much brighter slate-blue surfaces and pale edges so the plate silhouettes, inner steps, divisions, and mechanical cavity layouts can be inspected clearly. The normal-value separation lines have also been lifted and slightly thickened so they remain detectable without diagnostic colors.

The diagnostic treatment unexpectedly creates a striking bright-neon-tower atmosphere. Preserve that as a future intentional zone-art direction to explore, not as a generic generator setting or a default middle-layer treatment. Press **D** again to return to the intended dark-indigo colors.

## What stays fixed

- Actual `scenes/main.tscn` gameplay and camera reference
- Approved far aperture clusters, three light states, and switch/shimmer flicker
- Approved mote parallax values and existing particle settings
- A1/A2 palettes and #02060D void
- Existing middle support geometry, landmarks, contours, and neon accents
- Player, ball, platforms, HUD, camera behavior, and glow settings

Only the middle detail treatment changes between A/B/C.

## Evaluation

1. Do the four B patterns provide enough variety while remaining part of one structural language?
2. Do the stepped plates read as integrated monumental construction rather than surface decoration?
3. Does C add useful mechanical character, or does it become too panel-like?
4. Are the normal graphite recesses visible enough on the very dark middle fill?
5. Does diagnostic D make all plate and cavity geometry easy to inspect?
6. After returning D off, do the normal recess colors remain convincing under both A1 and A2?
7. Are the new details visible at gameplay scale without competing with the ball, platforms, far apertures, or mote depth?
8. Is the original A treatment still preferable?

## Validation

Source reviewed; Godot 4.7.x runtime parsing and visual judgment are still required. No treatment is assumed to be the winner before playtesting.
