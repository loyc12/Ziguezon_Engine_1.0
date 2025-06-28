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
pub var G_NG : engine = .{ .state = .CLOSED }; // Global engine instance

// ================================ INJECTORS ================================
pub const OnEntityRender  = @import( "injectors/entityInjects.zig" ).OnEntityRender;
pub const OnEntityCollide = @import( "injectors/entityInjects.zig" ).OnEntityCollide;

pub const OnLoopStart = @import( "injectors/stepInjects.zig" ).OnLoopStart;
pub const OnLoopIter  = @import( "injectors/stepInjects.zig" ).OnLoopIter;
pub const OnLoopEnd   = @import( "injectors/stepInjects.zig" ).OnLoopEnd;

pub const OnUpdate = @import( "injectors/stepInjects.zig" ).OnUpdate;
pub const OnTick   = @import( "injectors/stepInjects.zig" ).OnTick;

pub const OnRenderWorld   = @import( "injectors/stepInjects.zig" ).OnRenderWorld;
pub const OnRenderOverlay = @import( "injectors/stepInjects.zig" ).OnRenderOverlay;

pub const OnStart  = @import( "injectors/stateInjects.zig" ).OnStart;
pub const OnLaunch = @import( "injectors/stateInjects.zig" ).OnLaunch;
pub const OnPlay   = @import( "injectors/stateInjects.zig" ).OnPlay;

pub const OnPause = @import( "injectors/stateInjects.zig" ).OnPause;
pub const OnStop  = @import( "injectors/stateInjects.zig" ).OnStop;
pub const OnClose = @import( "injectors/stateInjects.zig" ).OnClose;

// ================================ RAYLIB ================================
// These are shorthand imports for raylib's types and functions to make the code cleaner.

pub const vec2 = rl.Vector2; // Shorthand for raylib's Vector2 type

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