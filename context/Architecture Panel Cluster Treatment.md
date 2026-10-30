# Compact Panel and Flicker Refinement

Branch: `experiment-abstract-energy-apertures`

Scene: `scenes/environment_architecture_panel_cluster_test.tscn`

This is the next refinement of the organized panel-cluster direction. The previous larger cluster treatment remains available as a direct comparison in the test scene.

## Purpose

Refine the far-silhouette details so they feel like intentional components of an unknown technological structure, while preserving the successful geometric organization and the cozy, restrained quality of the earlier small illuminated windows.

This refinement adds four things:

1. Recesses vary more in height and width instead of repeating one tall-bay proportion.
2. Recesses and isolated aperture groups are anchored fully inside the far silhouette, with a consistent inset from its inner edge.
3. Panel and aperture dimensions, spacing, and vertical placement vary deterministically while retaining the same organized rectangular language.
4. The three light states are more distinct. A subset of sources now switches between visibly on and nearly off; the remaining sources retain a gentler irregular shimmer. Strong neon sources receive a clearer layered glow.

The actual `scenes/main.tscn` is used as the gameplay reference. The architecture silhouette grammar, A1/A2 palette recipes, #02060D void, parallax, camera, player, platforms, and environment setup remain fixed.

## Comparison variants

| Key | Palette | Treatment |
|---|---|---|
| **A** | A1 | Baseline far silhouettes |
| **B** | A1 | Previous structured bays + window states |
| **C** | A1 | Previous larger panel clusters, static |
| **D** | A1 | Taller recesses + compact panel states, static |
| **E** | A1 | Same compact panels with restrained flicker |
| **F** | A2 | Baseline far silhouettes |
| **G** | A2 | Previous structured bays + window states |
| **H** | A2 | Previous larger panel clusters, static |
| **I** | A2 | Taller recesses + compact panel states, static |
| **J** | A2 | Same compact panels with restrained flicker |

A1 is the near-black far layer paired with the lifted blue-purple middle layer. A2 uses the brighter blue-direction far silhouettes with dark-blue middle structures.

## Run it

1. Switch to `experiment-abstract-energy-apertures` in GitHub Desktop and fetch/pull.
2. Open `scenes/environment_architecture_panel_cluster_test.tscn` in Godot.
3. Run **Run Current Scene (F6)**.
4. Compare A–E with seed 7319, then F–J. Use the same seed for each direct comparison.
5. Repeat with seeds 24017 and 91207. `R` selects a random seed; Space/Enter restarts the game scene.

## Recess and cluster layout

The recessed bays are taller than the earlier panel housings, but their height and width now vary by module. This creates a more natural range of structural proportions while preserving the same visual grammar. Both recessed bays and isolated aperture groups are positioned inside the solid far silhouette rather than hanging beyond its inward edge. The group is anchored from the silhouette boundary, with a consistent safety inset.

The pattern library remains intentional and rectangular:
- Mixed compact square, short horizontal aperture, and taller slit.
- Two separated elements with contrasting proportions.
- Compact four-part group with an offset lower pair.
- Several substantial slits arranged around a smaller horizontal aperture.
- Sparse asymmetric trio with a broader upper panel and two compact elements below.

Element sizes and positions vary per module, including modest width/height changes and small deterministic offsets. Their proportions account for the far layer's X scale of 0.88 and Y scale of 0.18, so square-like apertures remain legible at game scale rather than collapsing into horizontal bars.

## Light and flicker behavior

Every aperture retains a deterministic dormant, active, or energized state.

- **Dormant:** dark inset with a readable edge.
- **Active:** compact, subdued internal light.
- **Energized:** stronger neon-colored source with a more noticeable layered halo, closer to the successful window treatment.

Most energy sources inhabit compact squares, shorter rectangles, and slits. Larger horizontal panels are more likely to remain dormant or carry only subdued activity. This keeps illumination logically contained in smaller components rather than turning broad structural surfaces into glowing signs.

The **D / I** modes show the new panel and light arrangement statically. The **E / J** modes use the same layouts and states with deterministic flicker. A subset of active and energized sources now has a clear on / nearly-off cycle, with different periods and phases so they do not switch together. Other sources keep a gentler irregular shimmer. Light remains stationary inside each aperture; there are no traveling energy pulses.

A2's recessed fill and dark aperture treatment are lifted and softened so they sit closer to the brighter blue far mass. The recess should still read as an inset, but no longer as a black cutout competing with the middle architecture.

## Evaluation checklist

1. Do the taller recesses feel like intentional vertical structural bays?
2. Do compact illuminated panels retain the cozy, restrained quality of the earlier small windows?
3. Are the light sources noticeable at normal game zoom without becoming broad glowing rectangles?
4. Do compact squares and slits carry most of the activity, while broader elements provide structure?
5. Do the panel clusters remain ordered and varied without becoming residential window grids?
6. Do the three states read clearly as dormant, mid-level light, and strong neon?
7. Does the stronger glow remain close to the successful window treatment without competing with gameplay?
8. Does the switch-like flicker add life without reading as rapid blinking or visual noise?
9. Does the softer A2 recess treatment integrate with the brighter far fill and remain distinct from the middle layer?
10. Is static D / I preferable to flickering E / J, or does the motion improve the far layer?
11. Do A1 and A2 both work across the fixed seeds?
12. Do the orb and platforms remain the dominant visual focus?

## Scope and validation

The previous window treatment and larger panel cluster treatment remain available as comparison variants. Earlier palette and architecture scenes are retained.

Production gameplay, `scenes/main.tscn`, `scripts/ball.gd`, platform generation, camera behavior, middle architecture, near frames, and mote behavior are not modified.

Source-level validation is performed after implementation. Godot 4.7.x runtime parsing and actual visual evaluation are still required; no runtime result is assumed.
