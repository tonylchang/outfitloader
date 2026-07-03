# /spec-check Workflow

Use this workflow to determine whether the project specification is ready to guide development.

## Goal

Review the spec for completeness, internal consistency, and actionability. This workflow is read-only unless the user explicitly asks you to fix issues.

## Process

1. Confirm that all expected files exist in `spec/elements/`:
   - `PURPOSE.md`
   - `FEATURES.md`
   - `STACK.md`
   - `UI.md`
   - `INFRA.md`
   - `CONSTRAINTS.md`
   - `PROJECT.md`
   - `VERSIONING.md`
   - `CONTEXT.md`
2. Read every spec element.
3. Identify files that are empty, skeleton-only, or still contain unresolved placeholder comments.
4. Check for obvious conflicts, such as:
   - Features listed as both core and out of scope
   - Technologies listed as both in scope and out of scope
   - Deployment plans that conflict with budget or compliance constraints
   - Release plans that conflict with project timeline
5. Check whether `spec/original/` contains a baseline snapshot.
6. Report findings without editing files unless the user asks for fixes.

## Output

Return:
- Overall status: ready, needs input, or inconsistent
- Missing or skeletal files
- Conflicts or ambiguities
- Whether an original baseline exists
- Recommended next command, such as `/spec-init`, `/spec-update`, or `/spec-save-original`

## Completion Criteria

- The user knows whether the spec can safely guide development.
- Any missing information is tied to specific files and questions.
