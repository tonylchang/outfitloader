# /spec-init Workflow

Use this workflow to initialize a project specification in `spec/elements/`.

## Goal

Interview the user and generate a complete, internally consistent set of spec elements. Work through each element one at a time. Ask focused questions, use earlier answers to avoid repetition, and write each file before moving to the next section.

## Process

1. Ensure `spec/elements/` exists and contains the expected nine spec files.
2. For each spec element below, ask the listed questions unless the answer is already clear from prior context.
3. Replace skeleton content with concise Markdown that captures the user's decisions.
4. Do not write to `spec/original/`.
5. After all files are written, summarize each file in one line and suggest `/spec-save-original` if the user wants to preserve the baseline.

## Interview Flow

### 1. `PURPOSE.md`

Ask:
- What does this project do? What problem does it solve?
- Who is it for?
- Is there an existing solution this replaces or improves on?

Use sections for problem statement, target users, and prior art.

### 2. `FEATURES.md`

Ask:
- What are the core features for the first usable release?
- What are nice-to-have or future features?
- What is explicitly out of scope?

Use sections for core features, planned features, and out of scope.

### 3. `STACK.md`

Ask:
- What languages, frameworks, databases, and tools are required or preferred?
- Is this starting fresh or building on an existing codebase?
- What technologies should be avoided?
- Are there preferences for package managers, testing frameworks, or build tools?

Use sections for in-scope technologies, out-of-scope technologies, and rationale.

### 4. `UI.md`

Ask:
- What type of interface is this: CLI, desktop GUI, web app, mobile, API-only, library, or something else?
- What platforms or runtimes are targeted?
- Are there UI framework preferences?
- Are there accessibility requirements?
- Are there design references or style preferences?

### 5. `INFRA.md`

Ask:
- Where will this run or be deployed?
- Are there CI/CD preferences?
- Where will data services be hosted, if any?
- Are there domain, DNS, or environment plans?
- What monitoring, logging, or observability is needed?

### 6. `CONSTRAINTS.md`

Ask:
- What budget limits apply to hosting, APIs, services, or tooling?
- Is there a deadline or timeline?
- What is the team size and collaboration model?
- What licensing requirements apply?
- Are there regulatory, legal, or compliance requirements?

### 7. `PROJECT.md`

Ask:
- What is the development approach: POC first, iterative, milestone-based, waterfall, or other?
- What does done mean for the first milestone?
- What later milestones are planned?
- Is this a one-off project or ongoing product?

Use sections for current phase, milestones, and long-term plan.

### 8. `VERSIONING.md`

Ask:
- What versioning scheme should be used?
- When are releases cut?
- What tagging strategy should be used?
- Should there be a changelog?
- Are pre-release labels such as alpha, beta, or rc needed?

### 9. `CONTEXT.md`

Ask:
- Is there anything else relevant: related projects, team conventions, domain knowledge, prior art, political considerations, or personal preferences?

Capture anything relevant that did not fit cleanly elsewhere.

## Completion Criteria

- All nine files in `spec/elements/` contain project-specific content.
- Ambiguities are either resolved with the user or marked clearly as needing input.
- The user receives a concise summary of the generated spec.
