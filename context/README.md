# TowerJump Context Index

Last updated: 2026-11-01

This folder is the maintained handoff point for TowerJump design and implementation work.

## Start here

1. **[ART_PIPELINE_MASTERPLAN.md](ART_PIPELINE_MASTERPLAN.md)** — authoritative current plan for the environment art pipeline, architecture library, zones, landmarks, preview tools, and validation.
2. **[design/TowerJump Neon Design V2.md](design/TowerJump%20Neon%20Design%20V2.md)** — broader game and visual-design reference.
3. **[archive/conversation-history/TowerJump Neon Prototype-20261011-1854.md](archive/conversation-history/TowerJump%20Neon%20Prototype-20261011-1854.md)** — historical prototype transcript; useful for recovering decisions, not a current specification.

## Documentation rules

- Keep this index and the masterplan current when a system is implemented, approved, deferred, or rejected.
- Create a focused context document for each substantial new concept or implementation.
- The masterplan records current approved decisions and next steps; focused documents hold implementation-specific detail.
- Move superseded experiment notes and conversation transcripts into `archive/`, rather than deleting useful history.
- Clearly distinguish **approved**, **experimental**, **deferred**, and **rejected** directions.
- Do not treat debug-only visual settings as production design defaults.

## Current repository state

- `main` contains the Godot-verified gameplay baseline from `experiment-vertical-resonance-field` (merged via PR #5 on 2026-11-01).
- `experiment-middle-architecture-details` is the preserved, approved environment-art reference branch. Do not rewrite it during library implementation.
- `experiment-forward-assembly-platforms`, `feature/combo-system-prototype`, `experiment-unified-comet-shape`, and `experiment-plant-bank-jumping` remain preserved future/reference work.
- `chore/project-organization` is the current folder/documentation cleanup branch. It still requires local Godot validation before merging.
- The old gameplay baseline and approved art/comet checkpoints are preserved by tags. See the masterplan for the active tag inventory and branch cleanup notes.

## Current project directories

- `assets/` — active gameplay textures, references, and retained legacy resources.
- `shaders/` — player, platform, UI, and legacy shader resources.
- `scenes/gameplay/` — production gameplay scenes.
- `scenes/tests/gameplay/` — gameplay test scenes.
- `scripts/` — code grouped by system; `scripts/landing/` remains its own subsystem.
- `context/` — current documentation, focused design references, and historical archive.

## Validation status

The owner confirmed the reorganized project and platform test room run correctly in Godot after reloading scenes. Godot's subsequent import/sterilization changes were pushed in commit `3415ec87d0ced46b1dde6ab9bfaa9b12ee5fdbd3`. A warning-cleanup pass is now committed on the organization branch and requires a focused retest before merging; see [Repository Organization and Validation](Repository%20Organization%20and%20Validation.md).
