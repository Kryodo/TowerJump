# Architecture Panel Cluster Treatment

Branch: \`experiment-abstract-energy-apertures\`

Scene: \`scenes/environment_architecture_panel_cluster_test.tscn\`

The previous abstract-aperture trial is retained as a historical experiment. This pass replaces its irregular free-form geometry with an organized rectangular panel language.

## Purpose

Test how far-silhouette details can feel part of an unknown energized world while preserving clear geometric organization and the visibility that made the previous static window treatment successful.

The pass uses the actual \`scenes/main.tscn\` as the gameplay reference. It changes only the optional far-silhouette detail treatment. The existing architecture silhouette grammar, A1/A2 palette recipes, #02060D void, parallax, camera, player, platforms, and environment setup remain fixed.

## Comparison variants

| Key | Palette | Treatment |
|---|---|---|
| **A / E** | A1 / A2 | Baseline far silhouettes |
| **B / F** | A1 / A2 | Previous structured bays + static window states |
| **C / G** | A1 / A2 | Organized rectangular panel clusters with static states |
| **D / H** | A1 / A2 | Same clusters with slow animated energy states |

A1 is the near-black far layer paired with the lifted blue-purple middle layer. A2 uses the brighter blue-direction far silhouettes with dark-blue middle structures.

## Run it

1. Switch to \`experiment-abstract-energy-apertures\` in GitHub Desktop and fetch/pull.
2. Open \`scenes/environment_architecture_panel_cluster_test.tscn\` in Godot.
3. Run **Run Current Scene (F6)**.
4. Compare A–D with seed 7319, then E–H. Keep the seed fixed for each direct comparison.
5. Use seeds 24017 and 91207 to check pattern robustness. \`R\` selects a random seed; Space/Enter restarts the game scene.

## Panel cluster language

The new treatment deliberately avoids free-floating circles, irregular polygon cutouts, and arbitrary decorative marks. Rectangles and squares are the primary elements.

Each selected far module receives one deterministic composition from a small pattern library:

- **Mixed cluster:** a substantial square-like element, a wider horizontal element, and a taller vertical element below.
- **Separated pair:** two larger apertures with contrasting proportions and clear negative space.
- **Compact four-part group:** a taller element and horizontal element above, with an offset pair below.
- **Charged-slit group:** two substantial vertical slits arranged around a broad rectangular element.
- **Sparse asymmetric trio:** one broad upper panel with two separated square-like elements.

Not every module receives a cluster. Some clusters sit inside a shallow rectangular recess with subdued depth rails; others sit directly in the silhouette without a large backing bay. The openings vary in length, height, width, and spacing, but each group remains composed and legible.

## Energy states

Every individual aperture has a deterministic state:

- **Dormant:** dark inner surface and a visible but restrained edge.
- **Active:** clearly visible subdued internal illumination.
- **Energized:** a stronger neon-colored fill and halo, preserving the visibility and character of the previous successful window treatment.

The **C / G** modes show these states statically so the panel geometry and state distribution can be judged without motion.

The **D / H** modes add slow, continuous intensity breathing and a rectangular charge pulse traveling along the long axis of energized apertures. This is not random blinking; each panel keeps its assigned state and movement phase.

The A1 and A2 panel colors reuse the established structured-detail palettes. Recess fills remain tinted per palette instead of turning into uniform black cutouts.

## Evaluation checklist

1. Do the clusters feel intentionally organized without resembling residential window grids?
2. Does the mix of squares, broad rectangles, tall panels, and charged slits feel coherent?
3. Are the clusters varied enough in count, spacing, and alignment without looking randomly scattered?
4. Do shallow recesses add useful depth, and do direct-surface clusters also feel integrated?
5. Are dormant apertures still identifiable?
6. Are active and energized panels clearly visible at normal far-layer zoom?
7. Does the energized glow preserve the satisfying previous window treatment without competing with the ball or middle-layer accents?
8. Do animated pulses read as energy traveling through a structure rather than blinking lights?
9. Do A1 and A2 both work across the fixed seeds?

## Scope and validation

The previous abstract irregular-aperture code and comparison files are retained for reference, but this is the new intended direction for evaluation. Existing life-treatment enum values remain stable; the panel-cluster modes are appended after them.

Production gameplay, \`scenes/main.tscn\`, \`scripts/ball.gd\`, platform generation, camera behavior, middle architecture, near frames, and mote behavior are not modified.

Source-level validation is required after implementation. Godot 4.7.x runtime parsing and visual evaluation remain necessary; no runtime result is assumed.
