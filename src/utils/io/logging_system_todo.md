# Logging System TODO

Next practical steps for polishing the active logger.

`logging_system_reference.md` is the contract authority. The roadmap is the
phase-order authority. This TODO stays narrower than both: it tracks the next
implementation slices that are useful without turning the logger into a broad
utils I/O or save-system project.

## 0. Current Baseline

The active logger is `src/utils/io/logger.zig`.

Current behavior:

* `utl.log` and `utl.qlog` are exported through `src/utils/utilsDef.zig`;
* call sites pass `( level, @src(), message, args )` or
  `( level, @src(), message )`;
* `G_LOG_LVL` is a file-local comptime gate;
* inactive levels return before `_log()` is called;
* active terminal output is built into a fixed-size logger-local buffer and
  flushed with one `std.debug.print` call;
* terminal output uses ANSI colors and prefix-driven message colors;
* file logging state exists behind `USE_LOG_FILE`;
* file logging creates an aggregate file and one active non-`.CONT` file per
  level;
* file logs are plain text and truncate files during `initFile()`;
* `.CONT` relies on `LoggedLastMsg` and routes file continuations through
  `LastLogLevel`;
* if file setup fails, the logger closes any opened files and continues
  terminal-only.

## 1. Next Slice - Output Primitive Extraction Review

Goal: decide whether the logger-local stream and file-sink code should stay in
`logger.zig` or become reusable utils I/O.

Tasks:

* compare `LogStream` in `src/utils/io/logger.zig` against
  `src/utils/drafts/outputer.zig`;
* decide whether fixed-buffer writing is logger-specific or useful enough to
  move into `src/utils/io/outputer.zig`;
* if extracting, keep the first extracted API small:
  * fixed stream wrapper;
  * optional create/truncate helper;
  * plain write/close helpers if they reduce logger duplication;
* preserve logger behavior exactly during any extraction;
* do not pull in `src/utils/drafts/inputer.zig` or save/load semantics during
  this slice;
* run `zig build` and `zig build test` if code moves.

Exit criteria:

* either `LogStream` and file helpers are deliberately kept logger-local, or a
  minimal `src/utils/io/outputer.zig` exists and `logger.zig` uses it without
  behavior drift;
* stale draft comments are either updated to point at the new direction or left
  deferred with an explicit reason.

## 2. Next Slice - Logger Configuration Boundary

Goal: choose the smallest useful configuration path for logger globals.

Tasks:

* decide whether `G_LOG_LVL` should become a build option, a utils config value,
  or remain file-local for now;
* decide how `USE_LOG_FILE`, `LOG_FILE_NAME`, colors, timestamps, and source
  locations should be configured;
* decide whether tests need a quiet log level override;
* check whether the engine-interface config pattern is appropriate for utils or
  too heavy for this layer;
* update `logging_system_reference.md` and `logging_system_roadmap.md` if the
  chosen boundary changes the contract.

Guardrails:

* keep inactive log calls comptime-gated;
* do not add runtime log-level switching yet;
* do not design a general app config system in this pass.

Validation:

* docs-only decisions need no build;
* build-option or config code changes need `zig build` and `zig build test`;
* if game interfaces are touched, also run `zig build check_games`.

## 3. Next Slice - File Logging Validation Polish

Goal: make file logging easier to verify without changing the public logger API.

Tasks:

* add a focused validation path for `USE_LOG_FILE = true` that avoids manually
  editing constants when practical;
* verify aggregate file output, per-level file output, and `.CONT` routing;
* verify file logs do not contain ANSI escape sequences;
* verify setup failure still prints a clear terminal warning and continues
  terminal-only;
* document the validation command or workflow in this TODO if it cannot be
  automated cleanly yet.

Guardrails:

* keep log files plain text;
* do not add log rotation, async logging, or structured records;
* do not introduce allocator-heavy formatting for normal log calls.

## 4. Next Slice - Public API And Docs Sync

Goal: keep the reference docs aligned with the active API.

Tasks:

* inspect whether `resetTmpTimer` / `logTmpTimer` should remain part of the
  target public API; they are referenced in `logging_system_reference.md`, but
  are not active exports after the id-removal pass;
* update the reference if temporary timer helpers are intentionally dropped;
* if the helpers are still wanted, add a small scoped TODO for restoring them
  instead of silently reintroducing dead exports;
* keep examples in `logging_system_reference.md` and
  `logging_system_roadmap.md` using the id-free call shape.

Validation:

* docs-only sync needs no build;
* restored helper code needs `zig build test`.

## 5. TODO Comment Triage

Validated handling for currently implicated TODO comments:

* `src/utils/drafts/outputer.zig`
  * current TODO: `// TODO : figure me out better`;
  * handling: defer until the output primitive extraction review;
  * reason: it may become the real home for logger-local stream/file helpers,
    but that decision has not been made.
* `src/utils/drafts/inputer.zig`
  * current TODO: `// TODO : figure me out better`;
  * handling: defer;
  * reason: input primitives and save/load-adjacent file semantics are outside
    the next logger slice.

Do not address, delete, or rewrite these draft TODO comments before confirming
the specific implementation slice.

## 6. Deferred Features

These remain intentionally out of scope unless the reference changes:

* general save-system design;
* complete file I/O abstraction for all utils;
* async logging;
* thread-safe logging;
* runtime log-level switching;
* log categories/subsystems;
* structured log records;
* log rotation;
* replacing the logger API with `std.log`;
* per-test log capture beyond a simple log-level override.
