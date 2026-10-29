# Architecture Follow-up Palette Test

Branch: `experiment-architecture-palette-comparison`

Scene: `scenes/environment_architecture_followup_palette_test.tscn`

## Purpose

This bounded follow-up does two things:

1. Refines the successful A2/E combination with a balanced and a brighter atmospheric option.
2. Compares whether the purple tint works better in the far silhouettes or the middle structures.

The global background stays `#02060D`. Earlier comparison scenes remain unchanged.

## Run it

1. Switch to `experiment-architecture-palette-comparison` in GitHub Desktop and fetch/pull the branch.
2. Open `scenes/environment_architecture_followup_palette_test.tscn` in Godot.
3. Run Current Scene (**F6**).
4. Compare **A → B → C** for the E/A2 refinements, then **D ↔ E** for the purple-placement comparison.
5. Use **1** (7319), **2** (24017), or **3** (91207) for fixed seeds; **R** randomizes the seed. Press **Space** or **Enter** to restart the foreground after changing seeds.

## Fixed across all variants

- Actual game scene, background color and matching architecture-band color.
- Architecture geometry, world bounds, layer parallax, contours, seams, accents, landmarks and near frames.
- Game camera, ball/trail, platforms, ambient motes, WorldEnvironment and glow/bloom.

## How far-silhouette overlaps work

The far layer intentionally contains multiple tall polygons whose vertical spans overlap. This is part of its structural rhythm and has not been removed. Each polygon is assigned one of the two authored far-fill colors based on its deterministic module index (`index % 3`), not a new third layer or an uncontrolled random color. At overlaps, the two intended fills can visually blend; they remain part of the far layer. Both far-fill shades in every candidate are kept chromatically distinct from the fixed navy background, and their overlap should not be interpreted as another architectural depth layer.

## Variants

### A — E baseline

- Far A: `Color(0.011764706, 0.03137255, 0.0627451, 0.98)`.
- Far B: `Color(0.015686275, 0.039215688, 0.078431375, 0.98)`.
- Middle: `Color(0.0055, 0.0165, 0.038, 0.96)`.

The current preferred integration/depth balance reference from the previous test.

### B — Balanced E

- Far A: `Color(0.010, 0.026, 0.060, 0.98)`.
- Far B: `Color(0.014, 0.032, 0.070, 0.98)`.
- Middle: `Color(0.004, 0.016, 0.065, 0.96)`.

Far silhouettes are slightly darker and a little more purple-leaning than A2. The middle fill is modestly brighter than E by weighted-RGB luminance. It is a deliberate dark-blue tint: red/green remain below the navy backdrop, while blue is clearly above it. This creates a stronger color distinction than a small uniform lift toward the background.

### C — Brighter E

- Far A: `Color(0.016, 0.033, 0.075, 0.98)`.
- Far B: `Color(0.022, 0.041, 0.092, 0.98)`.
- Middle: `Color(0.004, 0.018, 0.075, 0.96)`.

Far silhouettes are a little brighter and more purple-leaning than A2. The middle fill is brighter than B, with a more pronounced blue channel than the fixed navy background. Its weighted-RGB luminance remains below the background, but the blue-tint difference is intentionally clear rather than a near-match. This tests a more atmospheric combination without allowing the middle fill to reuse the background's navy color relationship.

### D — Purple far, blue middle

- Far A: `Color(0.056, 0.014, 0.100, 0.98)`.
- Far B: `Color(0.071, 0.018, 0.126, 0.98)`.
- Middle: the same dark-blue fill as A, `Color(0.0055, 0.0165, 0.038, 0.96)`.

This places a pronounced purple hue in the far layer and blue in the middle layer. The far values are approximated to the A2 far-fill weighted-RGB luminance, so the far layer does not become purple merely by becoming brighter.

### E — Blue far, purple middle

- Far A/B: the exact original A2 far fills from A.
- Middle: `Color(0.030, 0.0075, 0.054, 0.96)`.

This places the purple hue in the middle layer. Its weighted-RGB luminance proxy is approximately matched to A's dark-blue middle fill, so D versus E primarily probes where the purple hue belongs rather than introducing a deliberate large brightness difference.

Weighted RGB luminance is only an approximate comparison aid; judge the actual Godot render, display, and glow.

## Evaluation checklist

1. Does B keep E's pleasing integration while making the fill relationships feel more balanced?
2. Does C feel more atmospheric, or do the brighter layers begin to compete with platforms and ball?
3. Does D (purple far / blue middle) integrate better with the purple idle platforms while preserving a blue structural body?
4. Does E (blue far / purple middle) connect the nearer structure to the platforms more effectively, or does it feel muddy?
5. Are all three structural values—navy void, far silhouettes, and middle structures—still distinguishable when gaps appear?
6. Does the preference persist while climbing and across fixed seeds?

These are authored comparison candidates, not asserted winners.

## Validation status

Source-level checks should be followed by a Godot 4.7.x runtime test. No Godot runtime execution was performed for this change.
