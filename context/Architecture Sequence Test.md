# Architecture Sequence Test — Void → Structure 1 → Void → Structure 2

Branch: `experiment-architecture-palette-comparison`

Scene: `scenes/environment_architecture_sequence_test.tscn`

## Purpose

Judge the architectural palettes as part of a longer climb, with the same global navy void returning between two structures.

The sequence is:

1. **Opening void** — the TowerJump navy background, `#02060D`.
2. **Structure 1 — A1 structural depth** — near-black/indigo far masses with a lifted blue-purple middle layer.
3. **Return to void** — Structure 1 leaves the view before Structure 2 begins.
4. **Structure 2 — A2 integrated blue** — slightly brighter blue-direction far silhouettes paired with a dark-blue middle fill.

Both structures use the same architecture seed and procedural geometry grammar. Their bands are separated vertically and use different palette variants, so the comparison focuses on atmosphere rather than intentionally changing the underlying architectural design.

## Run it

1. Switch to `experiment-architecture-palette-comparison` in GitHub Desktop, then fetch/pull.
2. Open `scenes/environment_architecture_sequence_test.tscn` in Godot.
3. Run **Run Current Scene (F6)**.
4. Start with seed **1 (7319)** and climb through both structures. Observe Structure 1 emerging from the void, how it disappears, the duration of the empty interval, and Structure 2 emerging.
5. Use **2 (24017)** and **3 (91207)** to check whether the impression holds across other fixed seeds. After selecting a seed, press **Space** or **Enter** to restart the entire run with that seed. **R** selects a random seed.

## Fixed variables

- The global background remains `#02060D throughout the climb.
- The real `scenes/main.tscn` provides the ball, trail, platforms, camera follow, landing feedback, ambient motes, WorldEnvironment, and glow/bloom.
- Both architecture bands use the same seed and the same geometry-generation rules.
- Layer parallax, seams, accents, recesses, the resonance gate, archive recess, and near frames come from the existing architecture script.
- No production scene or gameplay script is edited.

## Structure profiles

### Structure 1 — A1 structural depth

Uses palette variant 4 from `procedural_architecture_draw_layer.gd`:

- Far layer: original near-black blue fills.
- Middle structures: lifted blue-purple fills (approximately `Color(0.015686275, 0.03137255, 0.0627451, 0.96)`).
- Near frames, seams, accents, and landmarks: unchanged.

### Structure 2 — A2 integrated blue

Uses palette variant 11, the A2/E baseline from the follow-up palette test:

- Far layer: the brighter blue-direction A2 fills (`Color(0.011764706, 0.03137255, 0.0627451, 0.98)` and `Color(0.015686275, 0.039215688, 0.078431375, 0.98)`).
- Middle structures: dark blue (`Color(0.0055, 0.0165, 0.038, 0.96)`).
- Near frames, seams, accents, and landmarks: unchanged.

Both bands' local background fills are matched to the global `#02060D` void, preventing a rectangular color seam.

## Bounded regions and transitions

- Structure 1: `section_top_y = -9000`, `section_bottom_y = -6000`, matching the earlier transition study.
- Structure 2: `section_top_y = -26000`, `section_bottom_y = -23000`.
- The second band is shifted upward along the tower to leave a distinct return to empty void. Different layer parallax and geometry extending beyond the nominal bounds mean layers emerge and disappear at different times.
- Transition heights are estimates from the geometry and parallax, not runtime measurements. Use the live climb-height readout and the actual Godot playtest to judge the pacing.

## Controls

- **1** — fixed seed 7319.
- **2** — fixed seed 24017.
- **3** — fixed seed 91207.
- **R** — random seed.
- **Space / Enter** — restart from the beginning, retaining the selected seed.

Selecting a seed changes the architecture immediately; restart to also reset the foreground's generated platform sequence to that seed. Both structure bands share the selected architecture seed.

## Evaluation checklist

1. Does the opening void establish the right atmosphere?
2. Does Structure 1 feel deeper and more monumental?
3. Does it leave the screen cleanly, returning to a satisfying empty navy void?
4. Is the void interval long enough to feel distinct rather than like one continuous structure?
5. Does Structure 2 feel more integrated with the foreground?
6. Do the two structures feel like different environments despite sharing the same architecture grammar?
7. Do the ball, platforms, trail, and landing feedback remain the main focus?
8. Does the sequence remain convincing across all three fixed seeds?

## Out of scope

- No changes to `scenes/main.tscn`, gameplay scripts, physics, platform generation, glow settings, motes, or architecture geometry.
- No new architectural prefabs, flickering lights, or world-space mote integration in this pass.
- These are test profiles, not a final commitment to permanent zone palettes.

## Validation status

The new scene and wrapper are source-authored for Godot 4.7.x. Run the scene in Godot to confirm parser/runtime behavior and evaluate the rendered transitions; no Godot runtime execution was available during preparation.
