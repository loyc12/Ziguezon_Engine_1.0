pub const std = @import( "std" );

pub const timer  = @import( "utils/timer.zig" );
pub const logger = @import( "utils/logger.zig" );

// ================================ SHORTHANDS ================================
// These are shorthand imports for commonly used modules in the project.

pub const alloc = std.heap.smp_allocator;

pub const log  = logger.log;
pub const qlog = logger.qlog;

const engine = @import( "core/engine.zig" ).engine;
var G_NG : engine = .{ .state = .CLOSED }; // Global engine instance

// ================================ INITIALIZATION ================================

pub fn initAll() void
{
  qlog( .INFO, 0, @src(), "Initializing all subsystems" );

  // Initialize the timer
  timer.initTimer();

  // Initialize the logger file if needed
  logger.initFile();
}

pub fn deinitAll() void
{
  qlog( .INFO, 0, @src(), "Deinitializing all subsystems" );

  // Deinitialize the logger file
  logger.deinitFile();
}