# Architecture Far-Fill Hue vs Brightness Test

Branch: `experiment-architecture-palette-comparison`

Scene: `scenes/environment_architecture_hue_brightness_test.tscn`

## Purpose

The previous F/A2 test changed far-silhouette fill values in both brightness and color relationship. This controlled test asks which part contributes most to its integration with the TowerJump foreground:

- a blue-purple-leaning hue shift at approximately the original luminance;
- a brightness lift that retains the original RGB proportions;
- or the combined A2 values.

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

### B — Hue only: blue-purple lean at approximately matched luminance

- Far mass A: `Color(0.0075, 0.0090, 0.0450, 0.98)`.
- Far mass B: `Color(0.0110, 0.0125, 0.0530, 0.98)`.

These values shift the far masses toward a blue-purple relationship while keeping a simple weighted-RGB luminance proxy close to the control values. They are an authored test candidate, not a mathematically perfect perceptual match. Display rendering and glow may affect the perceived comparison.

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

1. Does B improve foreground integration while retaining A's deeper silhouette separation?
2. Does C integrate better primarily because the far masses move closer to the background's value?
3. Does D still look better than either isolated adjustment?
4. Does the purple-platform relationship improve in B or D, and does it feel intentional rather than muddy?
5. Does the winner remain convincing while climbing and across the fixed seeds?
6. Do platforms, ball and trail remain the strongest and clearest foreground elements?

## Interpretation note

The RGB-channel values and approximate luminance matching are starting points for a controlled visual test, not a claim of perfect perceptual equivalence. Judge the actual Godot render under the real game's environment and glow. If B and C appear too similar, too strong, or too weak, record that feedback before changing any values.

## Validation status

The new scene, wrapper, palette values and documentation have been added to the same experiment branch. Source checks still need to be followed by a Godot 4.7.x runtime test; no visual winner is assumed in advance.
