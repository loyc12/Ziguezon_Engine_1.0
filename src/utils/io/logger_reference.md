# Logging System Reference

This reference records the current design contract for `src/utils/io/logger.zig`
and the logger-specific expansion paths that still look relevant.

## 1. Purpose

Provide a compact logging helper that keeps gated-out calls as cheap as
possible while still producing precise, source-stamped debug output when a level
is active. The logger is a personal debug tool first, but its public shape should
stay clean enough to remain reusable across engine and game code.

The current public call shape is id-free:

```zig
utl.qlog( .INFO, @src(), "Camera reset" );
utl.log(  .WARN, @src(), "Missing Entity {d}", .{ entityId });
```

The logger should remain practical in hot engine/game paths:

* inactive levels should return before formatting;
* active logs should build each emitted message once;
* terminal output should be readable and optionally coloured;
* file output should be plain text and deterministic;
* logging internals should not leak file handles or sink details into the public
  API.

## 2. Level Gating

`G_LOG_LVL` is the primary logging gate. It is currently backed by the
compile-time `logger_config.log_level` build option.

The level argument should stay `comptime` so inactive calls can return before
formatting, argument formatting, timestamp work, location formatting, or file
I/O. This is the main reason the logger remains custom instead of being replaced
by direct `std.log` calls.

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
continuation only logs if the previous log call emitted successfully.

## 3. Public API

The active convenience API is intentionally small:

* `qlog`: message with no formatting args;
* `log`: message with formatting args;
* `logRayFrameTime`: raylib frame-time helper;
* `logDeltaTime`: duration helper.

The old `id` argument was removed because it added noise to every call site
without proving useful.

Temporary timer helpers such as `resetTmpTimer` / `logTmpTimer` are not part of
the active public API. Restore them only if a concrete caller needs scoped timing
logs again.

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

Each active log call formats into a temporary message stream, then flushes that
stream once per sink.

The logger supports these sinks:

* terminal sink;
* aggregate log file sink;
* per-level log file sink.

Terminal and file records may be built separately if that keeps color handling
simple. The important contract is that each sink receives one complete record
rather than several interleaved `std.debug.print` fragments.

The reusable output primitives live in `src/utils/io/outputer.zig`:

* `GetFixedStream`: fixed-size buffer with an explicit truncation marker;
* `GetNamedFileSink`: create/truncate/write/close wrapper for a single file;
* `formatTaggedFileName`: helper for `debug_INFO.log`-style paths.

For file logging:

* files are created or truncated during logger initialization;
* every active level gets a file, even if no later messages use it;
* one aggregate file receives all emitted messages;
* each per-level file receives messages for that exact level;
* `.CONT` messages go to the most recent successfully emitted non-`.CONT`
  level file;
* every file starts with an initialization record so an empty file is visibly
  valid;
* shutdown writes deinitialization records before files close;
* files are readable as plain text and never contain terminal colour escapes.

## 6. File Names

`LOG_FILE_NAME` is backed by the compile-time `logger_config.file_name` build
option.

The aggregate log file uses `LOG_FILE_NAME` directly. Per-level files derive
their names from the configured base name plus the level name:

```text
debug.log
debug_ERROR.log
debug_WARN.log
debug_INFO.log
debug_DEBUG.log
```

If `TRACE` is active, create `debug_TRACE.log`. `CONT` does not get its own
file; it routes to the latest successful non-`CONT` level file.

## 7. Initialization And Shutdown

`initFile()` and `deinitFile()` are the lifecycle hooks exposed through
`utl.initAllUtils()` and `utl.deinitAllUtils()`.

The logger lifecycle:

* reject `G_LOG_LVL == .CONT`;
* reset continuation state during initialization;
* create/truncate every required file when file logging is enabled;
* write initialization records to every file;
* tolerate file initialization failure by falling back to terminal logging;
* close every opened file during deinit.

## 8. Configuration Boundary

Logger configuration is compile-time build configuration injected as the
`logger_config` module. This keeps inactive call sites comptime-gated while
allowing validation and local runs to change logger behavior without editing
`logger.zig`.

Current build options:

* `-Dlogger_log_level=DEBUG`;
* `-Dlogger_use_file=false`;
* `-Dlogger_file_name=debug.log`;
* `-Dlogger_show_timestamp=true`;
* `-Dlogger_show_source=true`;
* `-Dlogger_show_colour=true`.

`logger_log_level` accepts `NONE`, `ERROR`, `WARN`, `INFO`, `DEBUG`, or `TRACE`.
`CONT` is intentionally rejected because it is a continuation policy, not a
global gate.

The default configuration is terminal-only debug logging with timestamps, source
locations, and terminal colours enabled.

## 9. Concurrency And Limits

The current logger is single-process and effectively single-thread oriented.
That is acceptable for the current engine.

`CONT` state may remain local global state. The worst expected failure mode is
missing a continuation header or interrupting a grouped message. Do not overbuild
thread-safe logging until the engine actually introduces concurrent logging.

Buffers should be fixed-size or otherwise allocator-light. If a message exceeds
the temporary stream capacity, the logger should emit a visible truncation or
logging-failed note rather than silently corrupting output.

## 10. Validation

General validation:

```sh
zig build
zig build test
```

File logging validation:

```sh
zig build test_logger_files
```

This validates aggregate file output, exact-level file output, `.CONT` routing,
and absence of ANSI escape sequences in file logs.

Setup-failure validation:

```sh
zig build test_logger_file_failure
```

This validates that file setup failure leaves the logger in terminal-only state
and still allows log calls to return normally.

`zig build check_games` is useful after build-option plumbing changes because
every game target receives a generated `logger_config` module.

## 11. Future Expansion

These are logger-specific future avenues, not current implementation work:

* runtime log-level switching if compile-time gating becomes too rigid;
* log categories or subsystem tags if level-only filtering becomes too blunt;
* structured records if plain text stops being enough for inspection tools;
* log rotation or log directory configuration if file output becomes common;
* async or thread-safe logging if concurrent engine logging appears;
* per-test log capture or quiet defaults if test output becomes too noisy;
* scoped temporary timing helpers if a concrete caller needs them again;
* closer `std.log` integration if it can preserve this logger's gating and
  message-shape guarantees.

## 12. Non-Goals

Do not add complexity without a concrete logging use case. In particular, avoid
turning logger work into a broad application configuration, general file I/O, or
unrelated serialization project.
