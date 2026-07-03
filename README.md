# AI Project Spec Pattern

A harness-agnostic template for **spec-driven development** with AI coding agents.

## The Idea

Project specs are often monolithic documents that are hard to maintain and hard for coding agents to reference precisely. This pattern breaks project specifications into **atomic, modular elements**, each covering one discrete concern.

The result is a lightweight source of truth that works across Claude Code, Codex, GitHub Copilot, OpenCode, and other coding agents that can read repository instructions.

## How It Works

1. Clone or fork this template into a new project.
2. Invoke `spec-init` to interview the user and populate all spec elements.
3. Invoke `spec-save-original` to snapshot the initial baseline.
4. Develop with guardrails from `AGENTS.md` and `spec/elements/`.
5. Invoke `spec-update` when scope, stack, infrastructure, constraints, or release plans change.
6. Invoke `spec-check` when you want to validate that the spec is complete and consistent.

## Standard Entrypoints

These names are the standard entrypoints for the workflow:

| Entrypoint | What It Does |
| --- | --- |
| `/spec-init` | Interactive interview that generates all spec elements |
| `/spec-save-original` | Snapshots current spec elements into `spec/original/` |
| `/spec-update` | Applies targeted updates to affected spec elements |
| `/spec-check` | Checks whether the spec is complete, consistent, and ready to guide development |

The canonical process for each entrypoint lives in `spec/workflows/`. Harness-specific adapters should only route to those workflow docs.

Claude Code and OpenCode support the `/spec-*` commands through checked-in command adapters. Codex does not currently document repo-defined custom slash commands; Codex users should either type the `/spec-*` text as a prompt, which `AGENTS.md` maps to the workflow files, or define repo skills that invoke the same workflows as `$spec-*`.

## Harness Support

| Harness | How This Repo Supports It |
| --- | --- |
| Codex | Reads `AGENTS.md`; use literal `/spec-*` prompts or optional `$spec-*` repo skills |
| Claude Code | Uses `CLAUDE.md` as a shim that imports `AGENTS.md`, plus `.claude/commands/spec-*.md` command adapters |
| GitHub Copilot | Uses `AGENTS.md` plus `.github/copilot-instructions.md` |
| OpenCode | Uses `AGENTS.md` plus `.opencode/commands/spec-*.md` command adapters |
| Other agents | Can follow `AGENTS.md` and the workflow docs in `spec/workflows/` |

If a harness does not support native custom slash commands, type the command text anyway. `AGENTS.md` maps `/spec-init`, `/spec-save-original`, `/spec-update`, and `/spec-check` to the corresponding workflow files.

## Spec Elements

All elements live in `spec/elements/`. Each is a standalone Markdown file covering one concern:

| File | What It Defines |
| --- | --- |
| `PURPOSE.md` | Why this project exists and who it is for |
| `FEATURES.md` | Core features, planned features, and explicit exclusions |
| `STACK.md` | Approved and excluded technologies |
| `UI.md` | Interface type, platform targets, and UX preferences |
| `INFRA.md` | Deployment, hosting, CI/CD, and monitoring |
| `CONSTRAINTS.md` | Budget, timeline, team size, licensing, and compliance |
| `PROJECT.md` | Development lifecycle, milestones, and release plan |
| `VERSIONING.md` | Version scheme, release cadence, tags, and changelog policy |
| `CONTEXT.md` | Freeform context that informs development |

The `spec/original/` directory preserves the initial spec as an immutable baseline for comparison as the project evolves.

## Workflows

Workflow definitions live in `spec/workflows/`:

| File | Purpose |
| --- | --- |
| `spec-init.md` | Interview flow for generating all spec elements |
| `spec-save-original.md` | Baseline snapshot process |
| `spec-update.md` | Targeted spec update process |
| `spec-check.md` | Readiness and consistency check |

## Why This Pattern

- **Harness-agnostic**: the spec and workflows are plain Markdown, with thin adapters for specific agents.
- **Atomic and modular**: each spec element is independent, so updates are targeted.
- **Reduces drift**: agents check specific spec elements before adding features, dependencies, or deployment assumptions.
- **Explicit scope**: out-of-scope sections help prevent feature creep.
- **Reproducible onboarding**: `/spec-init` creates the same spec structure across projects.
- **Spec evolution tracking**: `spec/original/` preserves the baseline.
- **Human-readable**: the files remain useful without any AI tooling.

## Setup

### Prerequisites

Use any AI coding harness that can read repository instructions. Native slash-command adapters are included for Claude Code and OpenCode.

### Getting Started

```bash
# Option 1: GitHub template
gh repo create my-project --template danielrosehill/AI-Project-Spec-Pattern

# Option 2: Clone and reinitialize
git clone https://github.com/danielrosehill/AI-Project-Spec-Pattern.git my-project
cd my-project
rm -rf .git && git init
```

Then open the project in your preferred coding agent and invoke the init workflow:

```text
/spec-init
```

After the spec is populated, invoke the baseline workflow:

```text
/spec-save-original
```

In Codex, these are prompt entrypoints rather than repo-defined slash commands. Type `/spec-init` as the task request, or create a Codex repo skill named `spec-init` that follows `spec/workflows/spec-init.md` and invoke it as `$spec-init`.

## Customizing

- **Add spec elements**: Add new files under `spec/elements/` and update `AGENTS.md` plus `spec/workflows/spec-init.md`.
- **Modify workflow behavior**: Edit the relevant file under `spec/workflows/`.
- **Add harness adapters**: Create thin command or skill wrappers that point to the appropriate workflow file.
- **Layer on existing preferences**: Capture durable project preferences in `AGENTS.md` or the relevant spec element.

## License

MIT
