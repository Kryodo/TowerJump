# Compact Panel and Flicker Refinement

Branch: \`experiment-abstract-energy-apertures\`

Scene: \`scenes/environment_architecture_panel_cluster_test.tscn\`

This is the next refinement of the organized panel-cluster direction. The previous larger cluster treatment remains available as a direct comparison in the test scene.

## Purpose

Refine the far-silhouette details so they feel like intentional components of an unknown technological structure, while preserving the successful geometric organization and the cozy, restrained quality of the earlier small illuminated windows.

This pass changes three things:

1. Recesses become taller vertical bays, with more breathing room around their contents.
2. Most illuminated elements become compact squares, short rectangles, and readable slits. Broader panels remain part of the cluster language but are more likely to stay dormant.
3. Moving charge pulses are replaced by subtle flicker in stationary light sources. No illuminated element has a traveling light segment.

The actual \`scenes/main.tscn\` is used as the gameplay reference. The architecture silhouette grammar, A1/A2 palette recipes, #02060D void, parallax, camera, player, platforms, and environment setup remain fixed.

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

1. Switch to \`experiment-abstract-energy-apertures\` in GitHub Desktop and fetch/pull.
2. Open \`scenes/environment_architecture_panel_cluster_test.tscn\` in Godot.
3. Run **Run Current Scene (F6)**.
4. Compare A–E with seed 7319, then F–J. Use the same seed for each direct comparison.
5. Repeat with seeds 24017 and 91207. \`R\` selects a random seed; Space/Enter restarts the game scene.

## Recess and cluster layout

The recessed bays are taller than the earlier panel housings. They create a vertical structural zone and give the contained elements more negative space. Some clusters remain directly integrated into the far silhouette without a large backing recess.

The pattern library remains intentional and rectangular:
- Mixed compact square, short horizontal aperture, and taller slit.
- Two separated elements with contrasting proportions.
- Compact four-part group with an offset lower pair.
- Several substantial slits arranged around a smaller horizontal aperture.
- Sparse asymmetric trio with a broader upper panel and two compact elements below.

Elements are sized to account for the far layer's X scale of 0.88 and Y scale of 0.18, so square-like apertures should remain visually square at game scale rather than collapsing into horizontal bars.

## Light and flicker behavior

Every aperture retains a deterministic dormant, active, or energized state.

- **Dormant:** dark inset with a readable edge.
- **Active:** compact, subdued internal light.
- **Energized:** visible neon-colored source and a restrained halo, retaining the satisfying glow character of the successful window treatment.

Most energy sources inhabit compact squares, shorter rectangles, and slits. Larger horizontal panels are more likely to remain dormant or carry only subdued activity. This keeps illumination logically contained in smaller components rather than turning broad structural surfaces into glowing signs.

The **D / I** modes show the new panel and light arrangement statically. The **E / J** modes use the same layouts and states but add controlled, deterministic flicker to active and energized sources. Flicker is subtle and continuous, with no complete blackouts, random per-frame state changes, or traveling energy pulses. The source stays in place; only its intensity varies.

The A1 and A2 detail colors reuse the established structured-detail palettes. Recess fills remain tinted per palette rather than becoming uniform black cutouts.

## Evaluation checklist

1. Do the taller recesses feel like intentional vertical structural bays?
2. Do compact illuminated panels retain the cozy, restrained quality of the earlier small windows?
3. Are the light sources noticeable at normal game zoom without becoming broad glowing rectangles?
4. Do compact squares and slits carry most of the activity, while broader elements provide structure?
5. Do the panel clusters remain ordered and varied without becoming residential window grids?
6. Does flicker add life without looking like electrical failure, rapid blinking, or visual noise?
7. Is static D / I preferable to flickering E / J, or does the motion improve the far layer?
8. Do A1 and A2 both work across the fixed seeds?
9. Do the orb and platforms remain the dominant visual focus?

## Scope and validation

The previous window treatment and larger panel cluster treatment remain available as comparison variants. Earlier palette and architecture scenes are retained.

Production gameplay, \`scenes/main.tscn\`, \`scripts/ball.gd\`, platform generation, camera behavior, middle architecture, near frames, and mote behavior are not modified.

Source-level validation is performed after implementation. Godot 4.7.x runtime parsing and actual visual evaluation are still required; no runtime result is assumed.
