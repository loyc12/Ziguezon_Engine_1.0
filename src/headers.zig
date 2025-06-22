pub const std = @import( "std" );
pub const rl  = @import( "raylib" );

pub const col    = @import( "utils/colour.zig" );
pub const logger = @import( "utils/logger.zig" );
pub const timer  = @import( "utils/timer.zig" );

// ================================ SHORTHANDS ================================
// These are shorthand imports for commonly used modules in the project.

pub const alloc = std.heap.smp_allocator;

pub const log  = logger.log;  // for argument-formatting logging
pub const qlog = logger.qlog; // for quick logging ( no args )

const engine = @import( "core/engine.zig" ).engine;
var G_NG : engine = .{ .state = .CLOSED }; // Global engine instance

// ================================ INITIALIZATION ================================

pub fn initAll() void
{
  // Initialize the timer
  timer.initTimer();

  // Initialize the log file if needed
  logger.initFile();

  qlog( .INFO, 0, @src(), "Initialized all subsystems" );
}

pub fn deinitAll() void
{
  qlog( .INFO, 0, @src(), "Deinitializing all subsystems" );

  // Deinitialize the log file if present
  logger.deinitFile();
}