# Logging System Roadmap

Roadmap for polishing `src/utils/io/logger.zig` into a compact utils-level debug
logging API.

`logging_system_reference.md` is the contract authority. This roadmap is the
phase-order authority: it records what should happen first, what depends on
earlier slices, and what stays deferred.

## 0. Direction

Keep the current custom logger surface, but remove legacy noise and make the
internals easier to extend.

Target paths:

```text
src/utils/io/logger.zig
  comptime level gating
  id-free API
  one-record formatting
  terminal sink
  plain-text file sinks
  aggregate + per-level files
  continuation tracking
```

```text
src/utils/io/outputer.zig
  optional future home for small output primitives
  only if logger-local stream code proves reusable
```

The logger should not wait for a full save system. The first useful file output
can be logger-local.

## 1. Completed - Remove Legacy Id Plumbing

The active API no longer takes the old `id` argument.

Done:

* removed the `id` argument from `qlog`, `log`, `_log`, and helper calls;
* removed `SHOW_ID_MSGS` and `logId()`;
* updated logger comments and every `utl.log` / `utl.qlog` call site;
* kept `G_LOG_LVL` gating at the public wrapper boundary.

Expected API after this phase:

```zig
utl.qlog( .INFO, @src(), "Camera reset" );
utl.log(  .WARN, @src(), "Missing Entity {d}", .{ entityId });
```

## 2. Completed - Single-Record Terminal Formatting

Active terminal logs now build one complete record before output.

Done:

* introduced a small logger-local stream/buffer;
* formats header, body, newline, and reset code into the stream;
* flushes terminal output once at the end of the log call;
* preserves terminal colors, prefix message colors, and `CONT` behavior;
* keeps inactive log levels no-op-like;
* removed obsolete commented-out stream code.

## 3. Completed - Logger-Local File Sinks

File logging is implemented inside `logger.zig` behind `USE_LOG_FILE`.

Done:

* create/truncate the aggregate file at startup;
* create/truncate one file for every active non-`.CONT` level;
* write initialization records to every file;
* format file records as plain text;
* route normal messages to aggregate + exact level file;
* route `.CONT` messages to aggregate + latest successful non-`.CONT` level
  file;
* close all files during deinit;
* fallback visibly to terminal-only logging if file setup fails.

## 4. Phase 4 - Output Primitive Extraction Review

Goal: decide whether the logger-local stream/file code should become reusable
utils I/O.

Extract only if the implementation is clearly useful outside logging.

Candidate extraction:

* fixed stream wrapper;
* buffered file writer wrapper;
* create/truncate helper;
* plain flush/close lifecycle helper.

Keep this separate from save-system design. Save/load will likely need stronger
semantics than the logger does.

## 5. Phase 5 - Config Integration

Goal: move hardcoded logger globals only after a utils config direction exists.

Deferred candidates:

* build-option or utils-config `G_LOG_LVL`;
* test-specific log level;
* terminal/file toggles;
* log directory;
* log file base name;
* color enable/disable.

This may reuse the engine-interface config pattern, move that pattern into
utils, or use a simpler build-option-only approach. Do not choose this during
the first logger cleanup.

## 6. Deferred Features

Do not include these in the near-term logger polish unless the reference
changes:

* async logging;
* thread-safe logging;
* runtime log-level switching;
* log categories/subsystems;
* structured log records;
* log rotation;
* persistent save-system primitives;
* replacing the logger API with `std.log`;
* per-test log capture;
* automatic suppression of known test warnings.
