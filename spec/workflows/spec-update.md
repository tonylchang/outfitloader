# /spec-update Workflow

Use this workflow to update the project specification based on new user decisions.

## Goal

Incorporate new information into the appropriate files under `spec/elements/` without rewriting unaffected spec elements or touching `spec/original/`.

## Process

1. Read all current files in `spec/elements/` to understand the existing spec.
2. Parse the user's update. It may be free-form text, bullet points, structured decisions, or a reference to a prior conversation.
3. Map each update to the affected spec element files.
4. Check for conflicts with existing scope, stack, constraints, or exclusions.
5. If an update is ambiguous or conflicts with the current spec, ask for clarification before editing.
6. Update only the affected files in `spec/elements/`.
7. Preserve still-valid context. If something moved out of scope, move it to an out-of-scope or superseded note instead of deleting the history silently.
8. Summarize which files changed and what changed in each.

## Rules

- Never modify `spec/original/`.
- Do not infer beyond what the user stated.
- Keep edits surgical and proportional to the decision.
- If a statement affects multiple files, update each affected file. For example, "switch to Vercel" may affect both `STACK.md` and `INFRA.md`.
- If the active spec has diverged significantly from `spec/original/`, suggest that the user review the baseline.

## Completion Criteria

- Only affected files in `spec/elements/` are modified.
- Any conflict or ambiguity is resolved or explicitly left for follow-up.
- The user receives a brief diff-style summary.
