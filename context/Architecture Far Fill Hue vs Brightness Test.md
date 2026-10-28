# Architecture Far-Fill Hue vs Brightness Test

Branch: `experiment-architecture-palette-comparison`

Scene: `scenes/environment_architecture_hue_brightness_test.tscn`

## Purpose

The previous F/A2 test changed far-silhouette fill values in both brightness and color relationship. This controlled test asks which part contributes most to its integration with the TowerJump foreground:

- the subtle A2 color-ratio (hue/chromaticity) change at the original control brightness;
- a brightness lift that retains the original control RGB proportions;
- or the exact combined A2 values.

The previous B was the wrong hue direction and its far fills sat too close to the fixed navy background. B now uses A2's actual channel proportions, scaled down to each original control fill's weighted-RGB luminance proxy. This preserves the hue-only comparison without making the silhouettes disappear.

## Run it

1. Switch to `experiment-architecture-palette-comparison` in GitHub Desktop.
2. Open the Godot project.
3. Open `scenes/environment_architecture_hue_brightness_test.tscn`.
4. Use **Run Current Scene (F6)**.
5. Press **1** to select fixed seed 7319, then compare **A → B → C → D**. The variants can be switched live without rebuilding the scene.
6. Use **2** (24017) and **3** (91207) for the robustness check. Press **Space** or **Enter** to restart after selecting a seed so the foreground game scene also starts from the same global RNG seed.

## Fixed throughout all four variants

- Global background: `#02060D`.
- Middle architectural fill: original `MID_MASS = Color(0.011, 0.024, 0.044, 0.96)`.
- Architecture geometry, deterministic layer seed, parallax factors, seams, contours, accents, landmarks and near frames.
- Actual main game scene, WorldEnvironment, glow/bloom, ball/trail, platforms and mote emitters.
- Far polygon alpha: `0.98`.

Only the far-silhouette fill RGB values vary. The wrapper explicitly sets the live background ColorRect and the architecture-band fill to `#02060D`.

## Variants

### A — Control: original dark far fills

Uses the existing A0 values:

- Far mass A: `Color(0.004, 0.012, 0.026, 0.98)`.
- Far mass B: `Color(0.006, 0.016, 0.032, 0.98)`.

This is the reference for both hue and brightness.

### B — Hue only: A2 color ratios at control brightness

- Far mass A: `Color(0.004514, 0.012040, 0.024080, 0.98)`.
- Far mass B: `Color(0.006366, 0.015911, 0.031821, 0.98)`.

These values use the actual A2 channel proportions for the corresponding far masses, scaled down to match the original A0 fill's weighted-RGB luminance proxy. This changes the subtle color relationship without borrowing A2's brightness lift. B should remain as dark as A, rather than merging into the fixed background. The luminance match is an approximation, so judge the rendered result.

### C — Brightness only: original hue proportions, lifted toward A2's luminance

- Far mass A: `Color(0.01042, 0.03127, 0.06776, 0.98)`.
- Far mass B: `Color(0.01479, 0.03945, 0.07890, 0.98)`.

Each color retains the corresponding original control fill's RGB proportions, scaled upward to approximately match the weighted-RGB luminance of the corresponding A2 far fill. This isolates the brightness contribution as closely as practical in this color space.

### D — Combined: existing A2 far fills

Reuses the existing combined F/A2 values without alteration:

- Far mass A: `Color(0.011764706, 0.03137255, 0.0627451, 0.98)`.
- Far mass B: `Color(0.015686275, 0.039215688, 0.078431375, 0.98)`.

This is the known integration-oriented reference that combines both changes relative to the dark control.

## Controls

- **A** — Original dark-fill control
- **B** — Hue-only, blue-purple-leaning
- **C** — Brightness-only, original RGB proportions
- **D** — Combined existing A2
- **1 / 2 / 3** — Fixed seeds 7319 / 24017 / 91207
- **R** — Random seed
- **Space / Enter** — Restart

The original A–F palette scene and H/I/J D-background transition test remain separate and available.

## Evaluation checklist

1. Comparing A and B, is A2's subtle color-ratio shift visible when silhouette brightness is held at the original dark level?
2. Comparing A and C, does the brightness lift alone explain most of A2's improved foreground integration?
3. Comparing C and D, can you see any additional benefit from A2's small color-ratio shift once the fills are bright?
4. Does the exact A2 palette still relate well to the purple platforms without looking muddy?
5. Does the winner remain convincing while climbing and across the fixed seeds?
6. Do platforms, ball and trail remain the strongest and clearest foreground elements?

## Interpretation note

The values use a weighted-RGB luminance proxy, not a perfect model of perceived brightness under Godot's render and glow. A and B should retain similar darkness; A versus B tests the actual, subtle A2 color-ratio change. C and D may still look nearly identical because the original and A2 channel proportions are quite close. That would be a meaningful result: brightness may contribute much more to A2's integration than its hue shift does.

## Validation status

The new scene, wrapper, palette values and documentation have been added to the same experiment branch. Source checks still need to be followed by a Godot 4.7.x runtime test; no visual winner is assumed in advance.
