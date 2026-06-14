# Agent Instructions

Prefer succinct, direct answers with minimal embellishment.
Avoid textual noise as much as possible : reading your responses should not be tedious.

## Code Work

- Match the existing codebase style and conventions.
- Never run formatting passes such as `zig fmt`; the hand-maintained formatting is intentional.
- Preserve the repository's 2-space indentation, spacing inside parentheses, and section organization.
- Align semantically related declarations, arguments, calls, switch cases, and comments across lines using extra spacing.
- When editing an aligned group, realign the whole group.
- Prefer compact, practical implementations and avoid unnecessary abstraction.
- Add `//` simple or `///` doc comments for potentially ambiguous codeblocks, functions, data
  structures, and types, especially game-facing or public API surfaces.
- Ask before making large, ambiguous, or risky changes.
- After refactors, remove deprecated or dead code made obsolete by the change.
- Do not keep compatibility semantics around unless clearly useful ( ex : getTopSide and getNegXSide )
- When adding or auditing tests, focus on meaningful failure cases; skip trivially
  provable behavior and remove or rework unsuitable tests.

For broad refactors, new modules, large new functions, or uncertain formatting decisions,
read [`docs/code_style.md`](docs/code_style.md).

For creating or substantially editing reference.md or goals.md docs, or questions about
roadmap.md and todo.md read [`docs/doc_guidelines.md`](docs/doc_guidelines.md).
