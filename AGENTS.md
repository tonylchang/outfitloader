# AGENTS.md - Spec-Driven Development

This project uses harness-neutral spec-driven development. The project specification lives in `spec/elements/`; workflow definitions live in `spec/workflows/`.

## Standard Entrypoints

The following names are the public entrypoints for this pattern:

| Entrypoint | Workflow |
| --- | --- |
| `/spec-init` | Populate all spec elements through an interview |
| `/spec-save-original` | Snapshot the current spec into `spec/original/` |
| `/spec-update` | Apply targeted updates to affected spec elements |
| `/spec-check` | Check whether the spec is complete and usable |

When a user invokes one of these commands, read and follow the matching workflow file in `spec/workflows/`. If your harness does not support native custom slash commands, still treat the literal command text as a request to run the matching workflow.

Native adapters should be thin wrappers only. Do not duplicate workflow logic in harness-specific command or skill files.

Codex note: Codex reads `AGENTS.md`, but current public Codex docs describe built-in slash commands rather than repo-defined custom slash commands. For Codex, treat `/spec-*` text as prompt entrypoints, or expose equivalent repo skills as `$spec-init`, `$spec-save-original`, `$spec-update`, and `$spec-check` when `.agents/skills/` is available.

## Spec Elements

All spec elements live in `spec/elements/`. Each file covers one concern:

| File | Purpose |
| --- | --- |
| `PURPOSE.md` | Why this project exists, who it serves, and what it improves on |
| `FEATURES.md` | Core features, planned features, and explicit exclusions |
| `STACK.md` | Approved and excluded technologies |
| `UI.md` | Interface type, platform targets, and UX preferences |
| `INFRA.md` | Deployment, hosting, CI/CD, and observability |
| `CONSTRAINTS.md` | Budget, timeline, team, licensing, and compliance limits |
| `PROJECT.md` | Development lifecycle, milestones, and release plan |
| `VERSIONING.md` | Version scheme, release cadence, tags, and changelog policy |
| `CONTEXT.md` | Additional project context that does not fit elsewhere |

The `spec/original/` directory preserves the initial spec baseline. Do not modify files there except through `/spec-save-original`, and ask before overwriting existing snapshots.

## Operating Rules

- Before making code changes, read the spec elements relevant to the task. For broad feature work, onboarding, architecture, stack, or deployment changes, read all files in `spec/elements/`.
- If a required spec file is empty or only contains skeleton headings/comments, ask the user for the missing information or run `/spec-init`.
- Do not add features not listed in `FEATURES.md` unless the user explicitly updates the spec or confirms the scope change.
- Respect stack boundaries in `STACK.md`; if a technology is listed as out of scope, do not use it without confirmation.
- Respect constraints in `CONSTRAINTS.md`, especially budget, timeline, licensing, and compliance requirements.
- Follow `VERSIONING.md` for releases, tags, pre-release labels, and changelog updates.
- When a user request conflicts with the current spec, flag the conflict and ask whether to update the spec before implementing.
- Keep spec updates targeted. `/spec-update` should only modify affected files in `spec/elements/`.

## Harness Notes

- Claude Code reads `CLAUDE.md`; this repository keeps `CLAUDE.md` as a shim that imports `AGENTS.md`.
- Codex and OpenCode read `AGENTS.md` directly.
- GitHub Copilot can read `AGENTS.md` for agent instructions and `.github/copilot-instructions.md` for repository-wide Copilot guidance.
- Claude Code native slash commands live in `.claude/commands/`.
- OpenCode native slash commands live in `.opencode/commands/`.
- Codex native reusable workflows are skills invoked with `$skill-name`; if added, keep them as thin wrappers around `spec/workflows/`.
