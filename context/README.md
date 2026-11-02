# TowerJump Context Index

Last updated: 2026-11-02

This folder is the maintained handoff point for TowerJump design and implementation work. It records current approved decisions, implementation status, and links to focused references.

## Start here

1. **[ART_PIPELINE_MASTERPLAN.md](ART_PIPELINE_MASTERPLAN.md)** — authoritative current plan for the environment-art pipeline, the bounded Art Library V1 scope, architecture and theme systems, the first two representative zones, preview tooling, and the next implementation steps.
2. **[ART_LIBRARY_V1_IMPLEMENTATION.md](ART_LIBRARY_V1_IMPLEMENTATION.md)** — source audit, initial data contracts, reuse decisions, and implementation checkpoints.
3. **[design/TowerJump Neon Design V2.md](design/TowerJump%20Neon%20Design%20V2.md)** — broader game and visual-design reference. Treat it as historical design context; prefer newer explicitly approved decisions in the masterplan.
4. **[Repository Organization and Validation.md](Repository%20Organization%20and%20Validation.md)** — record of the repository restructure, warning cleanup, successful owner runtime validation, and current branch/tag state.
5. **[archive/conversation-history/TowerJump Neon Prototype-20261011-1854.md](archive/conversation-history/TowerJump%20Neon%20Prototype-20261011-1854.md)** — historical prototype transcript; useful for recovering decisions, not a current specification.

## Documentation rules

- Keep this index and the masterplan current when a system is implemented, approved, deferred, or rejected.
- Create a focused context document for each substantial new concept or implementation when it adds useful detail beyond the masterplan.
- The masterplan records current approved decisions and next steps; focused documents hold implementation-specific detail.
- Move superseded experiment notes and conversation transcripts into \`archive/\`, rather than deleting useful history.
- Clearly distinguish **approved**, **experimental**, **deferred**, and **rejected** directions.
- Do not treat debug-only visual settings as production design defaults.
- Preserve historical validation records while updating their current status; do not erase how or when a milestone was verified.

## Current repository and branch state

- \`main\` is the stable production baseline at merge commit \`d47ef2206a1326472de3ac1cc1a8a9f7ccda6baa\`.
- PR [#6 — Organize project structure and resolve Godot warnings](https://github.com/Kryodo/TowerJump/pull/6) is merged into \`main\`.
- The owner confirmed that the reorganized project and warning-cleanup changes run in Godot with **no errors or warnings**.
- The current environment-art working branch is \`feature/environment-art-library-v1\`, created directly from the same commit as \`main\`. All Art Library V1 implementation work belongs on this branch; do not commit directly to \`main\`.
- \`experiment-middle-architecture-details\` is the preserved, approved environment-art reference branch. Inspect it read-only; do not rewrite or modify it.
- \`experiment-forward-assembly-platforms\`, \`experiment-plant-bank-jumping\`, \`experiment-unified-comet-shape\`, and \`feature/combo-system-prototype\` remain preserved future/reference work.
- The old \`experiment-vertical-resonance-field\`, \`chore/project-organization\`, and temporary \`merge/gameplay-baseline-to-main\` branches have been retired after their work was integrated or preserved by tags.
- The preserved milestones include \`milestone/gameplay-baseline-v1\` and \`milestone/project-organization-v1\`. The masterplan and validation record contain the full tag inventory.

## Current project directories

- \`assets/\` — active gameplay textures, references, and retained legacy resources.
- \`shaders/\` — player, platform, UI, and legacy shader resources.
- \`scenes/gameplay/\` — production gameplay scenes.
- \`scenes/tests/gameplay/\` — gameplay test scenes.
- \`scripts/\` — code grouped by system; \`scripts/landing/\` remains its own subsystem.
- \`context/\` — current documentation, focused design references, and historical archive.

Environment-art folders and data structures should be introduced deliberately as the Art Library implementation requires them; do not create an oversized directory/framework structure prematurely.

## Current Art Library V1 status

**Approved strategic scope:** establish a reusable, deterministic environment-art pipeline and prove it with two contrasting representative early zones. Once both zones work in independent preview and the actual game rendering setup, document and freeze Art Pipeline V1. Do not produce the complete game's zone catalog yet.

**Foundation checkpoint (2026-11-02):** repository/reference audit completed; typed resource contracts and stable local seed derivation added on `feature/environment-art-library-v1`. Godot 4.7.x import/parser and runtime validation of these new scripts is still pending. Next: concept Zone 1, derive its actual module needs, and build the first preview vertical slice.

The immediate implementation phase is a source/repository audit, reconciliation of the remaining context documents, and design of a minimal data model plus preview workflow. See the masterplan for the complete scope and exit criteria.

## Validation status

The owner completed the Godot runtime retest after the warning cleanup and confirmed the game runs correctly with no errors or warnings. The folder migration, resource-path updates, warning fixes, and standalone platform test-room behavior are therefore considered validated by the owner. See [Repository Organization and Validation](Repository%20Organization%20and%20Validation.md) for the detailed record.
