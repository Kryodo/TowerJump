# Architecture Abstract Energy Treatment

Branch: \`experiment-abstract-energy-apertures\`

Scene: \`scenes/environment_architecture_abstract_energy_test.tscn\`

Reference scene retained from the previous pass: \`scenes/environment_architecture_life_followup_test.tscn\`

## Purpose

This pass tests whether far-silhouette detail can make TowerJump's mysterious world feel active without implying human occupancy or conventional buildings.

It preserves the successful palette relationships, environment bounds, parallax, overall silhouette grammar, player, platforms, camera and bloom. Only the optional far-silhouette detail treatment changes.

## Compare these treatments

| Keys | Palette | Treatment |
|---|---|---|
| **A / E** | A1 / A2 | Baseline far silhouettes |
| **B / F** | A1 / A2 | Previous successful structured bays + window states |
| **C / G** | A1 / A2 | Abstract geometric apertures, static energy marks |
| **D / H** | A1 / A2 | Same abstract forms with slow traveling energy pulses |

A1 is the near-black far layer paired with the lifted blue-purple middle layer. A2 uses the brighter blue-direction far silhouettes with dark-blue middle structures.

## Run it

1. Switch to \`experiment-abstract-energy-apertures\` in GitHub Desktop and fetch/pull.
2. Open \`scenes/environment_architecture_abstract_energy_test.tscn\` in Godot.
3. Run **Run Current Scene (F6)**.
4. Compare A–D with seed 7319, then E–H. Use the same seed for every direct comparison.
5. Try seeds 24017 and 91207 for pattern robustness. \`R\` selects a random seed; Space/Enter restarts the run.

## Abstract aperture language

The old treatment uses rectangular recessed bays and aligned window groups. The new treatment removes that framing and gives each selected far module a deterministic mix of:
- narrow, slanted fissures
- broad, skewed voids
- irregular multi-plane cavities
- elongated diamond-like apertures

Patterns differ in number, position, width, height and shape. They are sparse and intentionally asymmetrical rather than repeated as rows or grids. Some modules receive no aperture details at all.

A1 recesses are tinted slightly toward indigo so they do not simply become featureless black cutouts. A2 recesses remain blue-tinted and darker than the far mass without becoming pure black. The edges are subdued and remain below the stronger middle-layer accents.

## Energy states

Most apertures stay dormant. A rare subset carries a low-strength internal energy trace.

- **C / G:** the selected energy marks are static, giving a direct control for shape and placement.
- **D / H:** the same geometric patterns are used, but selected energy traces move slowly through their apertures and breathe in intensity. The movement is continuous and deliberate, not rapid flicker. The shapes and their selected/dormant identities remain stable.

This is intentionally not a row of animated lights. The goal is to test whether motion reads as energy or a state change inside an unknown structure, not as visible human activity.

The energy uses restrained blue or violet colors and does not use HDR-strength emissive values. No motes, environmental geometry, game logic, player physics, platform generation or production main scene files are changed.

## Evaluation checklist

1. Do the irregular apertures feel less like façade windows than the previous treatment?
2. Do the different shapes and asymmetric patterns feel intentional rather than randomly scattered?
3. Are cavities readable against A1 without becoming black holes?
4. Do A2 cavities remain blue-tinted and secondary to the silhouettes?
5. Does the slow traveling pulse suggest an energized state, or does it read as a moving light inside a building?
6. Is the pulse restrained enough to avoid flicker and visual clutter?
7. Does D/H feel more alive than C/G without changing the identity of the structures?
8. Does the new treatment work equally well on A1 and A2?
9. Does the effect remain readable at normal game zoom, with the orb and platforms still dominant?

## Scope and validation

The follow-up static test and all previous palette/transition scenes remain intact on their prior branches. This branch adds a new comparison scene and appends new life-treatment enum values after the existing IDs, preserving prior mappings.

Source-level wiring checks are still required after implementation. Godot 4.7.x runtime parsing and actual visual evaluation are needed before judging the result; no runtime result is assumed here.
