# Plant / Bank Jumping Experiment

Branch: `experiment-plant-bank-jumping`  
Base: `experiment-vertical-resonance-field`

This is an isolated experiment. It does not modify the production `scripts/ball.gd`, `scenes/main.tscn`, existing landing scoring, or the source branch.

## Open the experiment

1. Check out `experiment-plant-bank-jumping` in GitHub Desktop and open the project in Godot.
2. Open `scenes/plant_bank_test_room.tscn`.
3. Use **Run Current Scene (F6)** so the main game scene remains unchanged.

## Controls

- **Left / Right arrows** steer on desktop. On a mobile export, touch the left or right side of the play area below the HUD.
- **1 / 2 / 3 / 4** switch between Normal, Plant, Bank, and Auto.
- **R** or **RESET TEST RUN** restarts the same platform sequence.
- The HUD reports live horizontal/vertical velocity and the last landing's incoming/outgoing horizontal velocity, contact offset, and vertical rebound scale.

## What is being compared

- **Normal** — existing platform bounce behavior, with no experimental rebound adjustment.
- **Plant** — after landing, lateral velocity is reduced to 10% of its incoming value. Intended to test a more controlled starting trajectory for reversals and narrower paths.
- **Bank** — retains most lateral velocity and adds a horizontal impulse based on which side of the platform the ball contacts. The vertical rebound is reduced to 90%, and steering authority is briefly raised. Intended to test carrying/redirecting movement to cross larger gaps.
- **Auto** — uses Plant only for a slow, centered landing; otherwise uses Bank. This is a diagnostic comparison, not a final gameplay rule.

The mode can be switched at any time, but it only affects the next landing. The same repeatable platform pattern alternates long horizontal crossings, reversals, and wide reset platforms; it repeats as the player climbs.

## Experiment caveats

The values are intentionally strong enough to make differences observable and are not tuned for release. This test is meant to answer whether changing the rebound state creates enjoyable, legible choices with the current steering controls. It does not include FLOW, the rising threat, or production scoring logic changes.

The scene and scripts were committed to the experiment branch only. Godot runtime validation is still required before treating the scene as working; inspect the debugger if Godot reports parser or runtime errors.
