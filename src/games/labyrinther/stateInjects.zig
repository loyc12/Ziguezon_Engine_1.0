const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

const tlmp = utl.legacy_tilemap;

const Tilemap = tlmp.Tilemap;

pub var MAZE : Tilemap = .{};

/// Returns the game-owned maze after `OnGameOpen` initializes it.
pub fn getMaze() ?*Tilemap
{
  if( MAZE.isInit() ){ return &MAZE; }

  utl.qlog( .WARN, @src(), "Labyrinther maze is not initialized" );
  return null;
}

// ================================ STATE INJECTION FUNCTIONS ================================
// These functions are called by the engine whenever it changes state ( see changeState() in engine.zig )

pub fn OnGameStart( ng : *eng.Engine ) void
{
  _ = ng; // Prevent unused variable warning
}

pub fn OnGameOpen( ng : *eng.Engine ) void
{
  _ = ng;

  MAZE = Tilemap.createTilemapFromParams(
  .{
    .mapPos    = .{ .x = 0, .y = 0 },
    .mapSize   = .{ .x = 256, .y = 256  },
    .tileScale = .{ .x = 64, .y = 64 },
    .tileShape = .RECT,
  }, .T1, utl.getDefaultAlloc() ) orelse
  {
    utl.qlog( .ERROR, @src(), "Failed to create tilemap" );
    return;
  };

  var grid = &MAZE;
  grid.fillWithColour( .lGray );
}

pub fn OnGameClose( ng : *eng.Engine ) void
{
  _ = ng;

  if( MAZE.isInit() ){ MAZE.deinit( utl.getDefaultAlloc() ); }
}
