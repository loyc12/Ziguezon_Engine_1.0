# Logging System Reference

This reference defines the target contract for `src/utils/io/logger.zig`.
The logger is a personal debug tool first, but its public shape should be clean
enough to grow into a reusable utils-level debug logging API.

The roadmap records phase order. The TODO tracks the next practical edits.

## 1. Target

Provide a compact logging helper that keeps gated-out calls as cheap as
possible while still producing precise, source-stamped debug output when a level
is active.

Example target call shape:

```zig
utl.qlog( .INFO, @src(), "Camera reset" );
utl.log(  .WARN, @src(), "Missing Entity {d}", .{ entityId });
```

The logger should remain practical in hot engine/game paths:

* inactive levels should return before formatting;
* active logs should build each emitted message once;
* terminal output should be readable and optionally colored;
* file output should be plain text and deterministic;
* file logging should not require broad save-system primitives up front.

## 2. Level Gating

`G_LOG_LVL` remains the primary logging gate.

The level argument should stay `comptime` so inactive calls can return before
formatting, argument formatting, timestamp work, location formatting, or file
I/O. This is the main reason to keep a custom logger instead of replacing the
surface with plain `std.log` immediately.

Ordering remains:

```text
NONE
CONT
ERROR
WARN
INFO
DEBUG
TRACE
```

Higher configured levels allow every lower-severity level to log. `TRACE` is
expected to be noisy. Normal development runs are expected to use `DEBUG` or a
stricter level.

`CONT` is a continuation policy, not a normal independent severity. A
continuation should only log if the previous log call emitted successfully.

## 3. Public API

Keep the active convenience API small:

* `qlog`: message with no formatting args;
* `log`: message with formatting args;
* `logFrameTime`: frame-time helper;
* `logDeltaTime`: duration helper;
* `resetTmpTimer` / `logTmpTimer` if timing helpers remain part of the logger.

Remove the old `id` argument from the public API. It has not proven useful and
adds noise to every call site.

The public logger API should not expose file handles, stream internals, or sink
selection details unless a concrete caller needs them.

## 4. Message Shape

A normal message should contain:

```text
[LEVEL] timestamp : file:line | function() :
 > message
```

A continuation should omit the header and preserve the current grouped-output
style:

```text
   continued message
```

Terminal output may apply colors to the level, timestamp, source location, and
message body. File output must stay plain text.

Message-prefix colors such as `!`, `@`, `#`, `$`, `%`, and `&` can remain a
terminal-only convenience. They should not leak ANSI escapes into log files.

## 5. Output Model

Each active log call should format into a temporary message stream, then flush
that stream once per sink.

The logger should support these sinks:

* terminal sink;
* aggregate log file sink;
* per-level log file sink.

Terminal and file records may be built separately if that keeps color handling
simple. The important contract is that each sink receives one complete message
record rather than several interleaved `std.debug.print` fragments.

For file logging:

* files are created or truncated during logger initialization;
* every active level gets a file, even if no later messages use it;
* one aggregate file receives all emitted messages;
* each per-level file receives messages for that exact level;
* `.CONT` messages go to the most recent successfully emitted non-`.CONT`
  level file;
* every file starts with an initialization record so an empty file is visibly
  valid;
* files are readable as plain text.

## 6. File Names

`LOG_FILE_NAME` remains file-local config for now.

The aggregate log file should use `LOG_FILE_NAME` directly. Per-level files
should derive their names from the configured base name plus the level name:

```text
debug.log
debug_ERROR.log
debug_WARN.log
debug_INFO.log
debug_DEBUG.log
```

If `TRACE` is active, create `debug_TRACE.log`. `CONT` should not need its own
file unless a later use case proves otherwise.

## 7. Initialization And Shutdown

`initFile()` and `deinitFile()` are currently the lifecycle hooks exposed
through `utl.initAllUtils()` and `utl.deinitAllUtils()`.

The eventual logger lifecycle should:

* assert or reject `G_LOG_LVL == .CONT`;
* initialize terminal/file sinks once;
* create/truncate every required file when file logging is enabled;
* write initialization records to every file;
* tolerate file initialization failure by falling back to terminal logging;
* close every opened file during deinit.

The logger should avoid depending on the future save system. If a small file
primitive naturally falls out of the implementation, promote it later.

## 8. Configuration Boundary

Current file-local globals stay in `logger.zig` for now:

* `G_LOG_LVL`;
* timestamp/source toggles;
* terminal/file toggles;
* file base name.

Later, these may move into a utils configuration layer. That config layer could
reuse or replace the current engine-interface configuration pattern, but that is
deferred until there is a broader utils config pass.

Tests may later override logging level through the same config path. Until that
exists, test-output quieting is a deferred polish task.

## 9. Concurrency And Limits

The current logger is single-process and effectively single-thread oriented.
That is acceptable for the current engine.

`CONT` state may remain local global state. The worst expected failure mode is
missing a continuation header or interrupting a grouped message. Do not overbuild
thread-safe logging until the engine actually introduces concurrent logging.

Buffers should be fixed-size or otherwise allocator-light. If a message exceeds
the temporary stream capacity, the logger should emit a visible truncation or
logging-failed note rather than silently corrupting output.

## 10. Non-Goals

Do not pull these into the first logger rework:

* general save-system design;
* complete file I/O abstraction for all utils;
* async logging;
* thread-safe logging;
* log rotation;
* structured JSON logs;
* domain-specific log categories;
* replacing all call sites with `std.log`;
* runtime-configurable log levels before a utils config layer exists.
