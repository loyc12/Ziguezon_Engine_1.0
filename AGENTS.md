# Agent Instructions

Prefer succinct, direct answers and short progress updates; avoid textual noise or embelishment.

## Work Boundaries

- Treat the user's request and active todo slice as the scope boundary.
- If a slice exposes a broader issue, report it with exact files, errors, and
  the smallest known blocker instead of expanding the architecture ad hoc.
- Ask before broad module reshaping, type erasure, generic factories,
  dependency-injection layers, compatibility surfaces, or ownership rewrites.
- Prefer direct concrete code until duplication, the compiler, or a clear
  ownership problem proves a boundary must change.

## Code Work

- Match the existing codebase style and conventions.
- Never run formatting passes such as `zig fmt`; the hand-maintained formatting
  is intentional.
- Preserve 2-space indentation, spacing inside parentheses, section
  organization, and semantically aligned groups.
- Prefer compact, practical implementations and avoid unnecessary abstraction.
- Add `//` or `///` comments for ambiguous codeblocks, functions, data
  structures, and types, especially game-facing or public API surfaces.
- After refactors, remove deprecated or dead code made obsolete by the change.
- Do not add or keep compatibility semantics around unless the user requests a
  transitional caller migration; remove them in the same slice or report why they remain.
- When adding or auditing tests, focus on meaningful failure cases.

For formatting, module layout, large functions, or code organization, read
[`docs/code_style.md`](docs/code_style.md).

For broad refactors, ownership changes, validation, or slice-boundary questions,
read [`docs/workflow_guidelines.md`](docs/workflow_guidelines.md).

For creating or substantially editing reference.md, goals.md, roadmap.md, or
todo.md, read [`docs/doc_guidelines.md`](docs/doc_guidelines.md).
