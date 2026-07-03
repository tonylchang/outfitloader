# GitHub Copilot Instructions

Use `AGENTS.md` as the canonical agent guidance for this repository.

When the user invokes `/spec-init`, `/spec-save-original`, `/spec-update`, or `/spec-check`, follow the matching workflow in `spec/workflows/`.

Before making code changes, read the relevant files in `spec/elements/` and respect the scope, stack, infrastructure, constraints, and versioning decisions recorded there. Do not modify `spec/original/` except when following `/spec-save-original`.
