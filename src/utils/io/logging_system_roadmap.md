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

## 1. Phase 1 - Remove Legacy Id Plumbing

Goal: simplify every call site and remove a feature that has not earned its
cost.

Tasks:

* remove the `id` argument from `qlog`, `log`, `_log`, and helper calls;
* remove `SHOW_ID_MSGS`;
* remove `logId()`;
* update logger comments and examples;
* update every `utl.log` and `utl.qlog` call site;
* keep `G_LOG_LVL` gating exactly at the public wrapper boundary;
* run `zig build test`.

Expected API after this phase:

```zig
utl.qlog( .INFO, @src(), "Camera reset" );
utl.log(  .WARN, @src(), "Missing Entity {d}", .{ entityId });
```

## 2. Phase 2 - Single-Record Terminal Formatting

Goal: replace many direct `std.debug.print` fragments with one formatted record
per emitted log call.

Tasks:

* introduce a small logger-local stream/buffer;
* format header, body, and reset code into the stream;
* flush terminal output once at the end of the log call;
* preserve terminal colors;
* preserve `CONT` behavior;
* keep inactive log levels no-op-like;
* remove obsolete commented-out stream code while replacing it.

This phase should not add file logging yet. It proves the formatter and stream
shape first.

## 3. Phase 3 - Logger-Local File Sinks

Goal: implement file logging without broadening into a save-system project.

Tasks:

* create/truncate the aggregate file at startup;
* create/truncate one file for every active non-`.CONT` level;
* write initialization records to every file;
* format file records as plain text;
* route normal messages to aggregate + exact level file;
* route `.CONT` messages to aggregate + latest successful non-`.CONT` level
  file;
* close all files during deinit;
* fallback visibly to terminal-only logging if file setup fails.

This phase can keep the file implementation inside `logger.zig`.

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
