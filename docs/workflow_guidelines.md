# Workflow Guidelines

This guide covers repo-specific workflow behavior that is too detailed for
`AGENTS.md`. Keep it durable and compact: do not duplicate general Codex
defaults, long failure histories, or context already held by the active todo,
handoff notes, or the harness.

## Scope Boundaries

- Treat the user's request and the active todo slice as the work boundary.
- Do not make large ad-hoc architecture fixes when a slice exposes a broader
  issue.
- Report out-of-scope issues, contradictions, dependency loops, unrelated build
  failures, and unclear ownership boundaries with exact files and compiler
  errors when available.
- If a validation gate exposes unrelated failures, report them instead of
  expanding the slice to repair everything nearby.
- Ask before large, ambiguous, risky, or ownership-changing work.

## Architecture Choices

- Prefer direct concrete code until duplication, the compiler, or a clear
  ownership problem proves a boundary must change.
- Ask before broad module reshaping, type erasure, generic factories,
  dependency-injection layers, compatibility surfaces, or ownership rewrites.
- Avoid one-use factories, wrappers around a single concrete type, needless heap
  allocations, type erasure, and abstraction layers whose main purpose is hiding
  direct ownership.
- Add modules, move code, or split files when it clarifies ownership or prevents
  obscure mega-files; validate the result.
- Do not add or keep compatibility semantics around unless requested or transitional.
  Transitional compatibility surfaces should be removed during the same work slice,
  or reported to the user directly.

## Validation

- Follow validation gates in active todo or roadmap files when they exist.
- For code refactors, run the relevant `zig build` and/or `zig build test`
  command unless the user explicitly asks for docs-only work or investigation.
- For docs-only edits, a build is usually unnecessary.
- Never run `zig fmt`.

## Instruction Hygiene

- Keep `AGENTS.md` as a short entrypoint and router to focused docs.
- Put detailed task context in the active todo, roadmap, goals, reference, or
  handoff note instead of expanding global agent instructions.
- Preserve durable project constraints, but trim generic assistant behavior and
  repeated context when editing instruction docs.
- Prefer one focused rule in the right file over the same rule restated across
  several docs.
