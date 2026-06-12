# Logging System TODO

Next steps for polishing the active logger.

`logging_system_reference.md` is the contract authority. The roadmap is the
phase-order authority. This TODO stays narrower than both: it tracks the next
practical implementation slices.

## 0. Current Baseline

The active logger is `src/utils/io/logger.zig`.

Current behavior:

* `utl.log` and `utl.qlog` are exported through `src/utils/utilsDef.zig`;
* call sites pass `( level, id, @src(), message, args )`;
* `G_LOG_LVL` is a file-local comptime gate;
* inactive levels return before `_log()` is called;
* output is written through several direct `std.debug.print` calls;
* terminal output uses ANSI colors;
* file logging globals exist, but file initialization and shutdown are
  commented out;
* `CONT` relies on `LoggedLastMsg`;
* no dedicated latest-level state exists for routing continuations to per-level
  files.

## 1. Guardrails

* Preserve comptime `G_LOG_LVL` gating.
* Keep gated-out calls as close to no-op functions as practical.
* Do not evaluate timestamps, source formatting, message formatting, or file
  writes for inactive levels.
* Remove the old `id` argument rather than keeping compatibility shims.
* Keep file-local logger globals for now.
* Keep log files plain text.
* Keep terminal color behavior.
* Keep `TRACE` potentially noisy.
* Keep `CONT` simple and global-state based.
* Do not design the full save system in this pass.
* Do not run formatting passes such as `zig fmt`.

Validation rules:

* Docs-only changes need no build.
* Logger signature or call-site changes: run `zig build test`.
* Wider utils I/O changes: run `zig build` and `zig build test`.
* If game call sites are touched broadly, consider `zig build check_games` if
  available and relevant.

## 2. Next Slice - Remove Id Arguments

Goal: simplify the active API and remove unused id-gating behavior.

Tasks:

* Change `_log` from:

```zig
fn _log( level : LogLevel, id : u64, logLoc : ?std.builtin.SourceLocation, comptime message : [] const u8, args : anytype ) !void
```

to:

```zig
fn _log( level : LogLevel, logLoc : ?std.builtin.SourceLocation, comptime message : [] const u8, args : anytype ) !void
```

* Change `qlog` from:

```zig
pub fn qlog( comptime level : LogLevel, id : u64, logLoc : ?std.builtin.SourceLocation, comptime message : []const u8 ) void
```

to:

```zig
pub fn qlog( comptime level : LogLevel, logLoc : ?std.builtin.SourceLocation, comptime message : []const u8 ) void
```

* Change `log` from:

```zig
pub fn log( comptime level : LogLevel, id : u64, logLoc : ?std.builtin.SourceLocation, comptime message : []const u8, args : anytype ) void
```

to:

```zig
pub fn log( comptime level : LogLevel, logLoc : ?std.builtin.SourceLocation, comptime message : []const u8, args : anytype ) void
```

* Remove `SHOW_ID_MSGS`.
* Remove `logId()`.
* Remove the id section from comments and examples.
* Update `logFrameTime()` and `logDeltaTime()` helper calls.
* Update every `utl.qlog( level, 0, @src(), ... )` call.
* Update every `utl.log( level, 0, @src(), ... )` call.
* Search for non-zero id call sites before editing. If any exist, inspect them
  manually before removing the argument.
* Run `zig build test`.

## 3. Next Slice - Remove Dead Logger Draft Code

Goal: clear obsolete implementation noise before adding the new stream path.

Tasks:

* Remove the old commented-out `LogStream` draft block once replacement stream
  work begins.
* Replace self-deprecating file comments with precise module docs.
* Fix spelling in logger-local comments while touching nearby lines.
* Keep section organization and alignment consistent with the surrounding file.

This can be done with the id-removal slice if the diff stays easy to review.

## 4. Next Slice - Single Terminal Flush

Goal: build a complete terminal record before output.

Tasks:

* Add a fixed-size logger-local buffer/stream.
* Format level, timestamp, source, body, newline, and reset color into the
  stream.
* Flush once at the end of each active call.
* Preserve prefix-driven message colors.
* Preserve `ADD_PREC_NL` behavior unless renamed during cleanup.
* Make overflow visible.
* Keep inactive log behavior unchanged.
* Run `zig build test`.

## 5. Next Slice - File Logging Prototype

Goal: make `USE_LOG_FILE` actually work.

Tasks:

* Add aggregate file state.
* Add per-level file state for every active non-`.CONT` level.
* Add `LastLogLevel : ?LogLevel` or equivalent.
* Create/truncate files in `initFile()`.
* Write initialization records to every opened file.
* Close files in `deinitFile()`.
* Build file records without ANSI colors.
* Route normal records to aggregate + exact level file.
* Route `.CONT` records to aggregate + `LastLogLevel` file.
* If file setup fails, print a clear terminal warning and continue terminal-only.
* Run `zig build test`.

## 6. Open Design Decisions For Later

These are intentionally deferred:

* whether logger-local stream code should move to `src/utils/io/outputer.zig`;
* whether `src/utils/drafts/inputer.zig` should become a real input primitive;
* whether logging and save/load share lower-level file helpers;
* whether `G_LOG_LVL` becomes a build option;
* whether tests override the log level;
* whether the engine-interface config pattern should move into utils.

Ask before starting any of these as implementation work.
