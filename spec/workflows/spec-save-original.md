# /spec-save-original Workflow

Use this workflow to preserve the current project specification as the original baseline.

## Goal

Copy the current files from `spec/elements/` into `spec/original/` and record snapshot metadata. The original baseline is used for comparison as the active spec evolves.

## Process

1. Ensure `spec/original/` exists.
2. Inspect `spec/original/` for existing files other than `.gitkeep`.
3. If snapshot files already exist, ask the user before overwriting anything.
4. Copy every file from `spec/elements/` into `spec/original/`, preserving filenames.
5. Add or update `spec/original/_SNAPSHOT.md` with:
   - Date
   - Method used to generate the spec, such as `/spec-init` interview or manual authoring
   - List of files preserved

## Snapshot Format

```markdown
# Spec Snapshot

- **Date**: YYYY-MM-DD
- **Method**: [how the spec was generated]
- **Files preserved**: [list of files]
```

## Rules

- Only this workflow may modify `spec/original/`.
- Do not overwrite existing baseline files without explicit user confirmation.
- Do not change active files in `spec/elements/`.

## Completion Criteria

- `spec/original/` contains copies of all current spec element files.
- `_SNAPSHOT.md` records when and how the baseline was preserved.
- The user receives a short summary of what was copied.
