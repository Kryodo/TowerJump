# Architecture Transition Comparison — Void → Structure → Void

Branch: `experiment-architecture-palette-comparison`

Scene: `scenes/environment_architecture_transition_test.tscn`

## Purpose

Evaluate the architecture as part of a continuous climb rather than as a static screenshot: begin in the normal empty void, enter a bounded architectural region, and then climb back into the empty void.

The global background is held at the existing TowerJump navy, `#02060D`, for the entire test. The production `scenes/main.tscn` remains unchanged. The transition wrapper instantiates the real main scene and adds the existing procedural architecture behind gameplay and in front of the base background.

## Run it

1. Switch to `experiment-architecture-palette-comparison` in GitHub Desktop.
2. Open the project in Godot.
3. Open `scenes/environment_architecture_transition_test.tscn`.
4. Run **Run Current Scene (F6)**.
5. Start with fixed seed **1** (7319). Compare E, F and G with that same seed. Use **2** (24017) and **3** (91207) only after the first comparison.
6. For a full-sequence comparison, select E, F or G and then press **Space** to restart from the initial void. The selected recipe and seed are retained; the wrapper reseeds the global RNG before the game scene initializes.
7. Climb continuously: the architecture is a finite band, so the scene begins with empty void, gradually gains architecture at different parallax depths, and eventually returns to empty void. Use **Space** to restart the run.

## Recipes

All variants use the same #02060D background, geometry, seed, parallax factors, seams, accents, architecture landmarks, gameplay scene, glow settings, platforms and mote emitters. Only the far/middle architectural fill combination changes.

### E / A1 — Structural depth

- Far silhouettes: original near-black blue fills (`#010307` and `#020408`, approximately).
- Middle supports: lifted blue-black (`#040810`, approximately).
- Background: `#02060D`.

This is the current leading recipe for readable structural depth.

### F / A2 — Integrated far silhouettes

- Far silhouettes: brighter, bluer fills (approximately `#030810` and `#040A14`).
- Middle supports: original subdued blue-black (`#03060B`, approximately).
- Background: `#02060D`.

This is the integration-oriented recipe where the far structures approach the background in value and color.

### G — Hybrid

- Far silhouettes: same as F / A2.
- Middle supports: same as E / A1.
- Background: `#02060D`.

This untested hybrid asks whether the integrated far masses can be combined with enough middle-layer separation to recover a little more depth.

## Transition band and parallax

The architecture manager uses a bounded section from `section_top_y = -9000` to `section_bottom_y = -6000`. Existing module geometry deliberately extends beyond those bounds, allowing the architectural masses to emerge and leave gradually rather than appearing as a hard rectangular mask.

The three existing parallax Y factors remain unchanged:

- Far architecture: `0.18`
- Middle architecture: `0.46`
- Near frames: `0.82`

Because each depth moves at a different rate, the layers will not enter or leave simultaneously. Expect the far silhouettes to linger longest; this is part of the test, not a fixed promise about zone length. With the current bounds, the far silhouettes should begin entering at roughly 1.8–2.0k climb height, with middle structure becoming more apparent around 3.3k and near frames around 5.9k. On the way out, near frames should leave first (roughly 10k), then middle structure (roughly 11k), with the far silhouettes returning fully to void at roughly 14k. These are geometry/parallax estimates, not Godot-runtime measurements; camera-follow lag and seed variation can shift them.

The background manager may draw a background-color rectangle within the band, but for E/F/G that fill is exactly the same navy as the production background. The intended visible change is architecture only.

## Controls

- **E** — E / A1 structural-depth recipe
- **F** — F / A2 integrated-far recipe
- **G** — hybrid (A2 far + A1 middle)
- **1 / 2 / 3** — fixed seeds 7319 / 24017 / 91207
- **R** — random seed
- **Space / Enter** — restart

The original A–F palette comparison remains available in `scenes/environment_architecture_test_room.tscn`; this is a separate test scene, not a replacement. The wrapper seeds Godot's global RNG before instantiating the real main scene so platform-pattern choices that use the global RNG are repeatable with a fixed seed; any separate RNGs that explicitly randomize themselves may still vary.

## Evaluation checklist

1. Does the original navy void still feel satisfying before the architecture appears?
2. Does E/A1's deeper structure feel natural when it emerges from that void?
3. Does F/A2 make the foreground and background feel more cohesive during the actual transition, not just in a static view?
4. Does G preserve the integrated far masses while making the middle supports more readable?
5. Does the return to empty void feel natural and spacious?
6. Do the platforms, ball, trail and ambient motes remain visually integrated throughout?
7. Do the transitions remain convincing across other fixed seeds?

## Out of scope for this pass

- No production gameplay, `scenes/main.tscn`, or ball script modifications.
- No mote depth/parallax modifications; record any screen-glued mote impression separately.
- No accent flicker, hue-versus-brightness experiment, or zone-system implementation yet.

## Validation status

The test scene, wrapper and hybrid recipe have been added to the existing experiment branch. Source checks should confirm the new keys and fill mappings; the scene still needs to be run in Godot 4.7.x to verify parsing and assess the rendered transitions. No visual winner is assumed before the playtest.
