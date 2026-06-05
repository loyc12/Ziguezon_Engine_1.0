# Agent Instructions

Prefer succinct, direct answers with minimal embellishment.

## Code Work

- Match the existing codebase style and conventions.
- Never run formatting passes such as `zig fmt`; the hand-maintained formatting is intentional.
- Preserve the repository's 2-space indentation, spacing inside parentheses, and section organization.
- Align semantically related declarations, arguments, calls, switch cases, and comments across lines using extra spacing.
- When editing an aligned group, realign the whole group.
- Prefer compact, practical implementations and avoid unnecessary abstraction.
- Ask before making large, ambiguous, or risky changes.
- After refactors, remove deprecated or dead code made obsolete by the change.

For broad refactors, new modules, or uncertain formatting decisions, read
[`docs/code_style.md`](docs/code_style.md).
