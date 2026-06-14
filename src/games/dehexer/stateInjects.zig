const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

const tlmp = utl.legacy_tilemap;

const Tilemap  = tlmp.Tilemap;
const TileType = tlmp.TileType;

pub var GRID : Tilemap = .{};

pub var GRID_WIDTH  : i32 = 50;
pub var GRID_HEIGHT : i32 = 25;

pub var GRID_SCALE  : f64 = 50; // NOTE : Will be overwritten

pub const TILE_MINE_1 : TileType = .T1;
pub const TILE_MINE_2 : TileType = .T2;
pub const TILE_MINE_3 : TileType = .T3;
pub const TILE_HIDDEN : TileType = .T4;
pub const TILE_SHOWN  : TileType = .T5;

/// Returns the game-owned grid after `OnGameOpen` initializes it.
pub fn getGrid() ?*Tilemap
{
  if( GRID.isInit() ){ return &GRID; }

  utl.qlog( .WARN, @src(), "Dehexer grid is not initialized" );
  return null;
}

// ================================ STATE INJECTION FUNCTIONS ================================

pub fn OnGameStart( ng : *eng.Engine ) void
{
  _ = ng; // Prevent unused variable warning
}

pub fn OnGameOpen( ng : *eng.Engine ) void
{
  _ = ng;

  // Adjusting grid scalling to fit the screen
  const scaleFactor : f64 = @floatFromInt( 1 + @max( GRID_WIDTH, GRID_HEIGHT * 2 ));

  const scale2 = utl.getScreenSize().addVal( 128 ).mulVal( 1.0 / scaleFactor );

  GRID_SCALE = @max( scale2.x, scale2.y );


  // Setting up the grid
  GRID = Tilemap.createTilemapFromParams(
  .{
    .mapPos    = .{ .x = 0,          .y = GRID_SCALE  },
    .mapSize   = .{ .x = GRID_WIDTH, .y = GRID_HEIGHT },
    .tileScale = .{ .x = GRID_SCALE, .y = GRID_SCALE  },
    .tileShape = .HEX1,
  }, TILE_HIDDEN, utl.getDefaultAlloc() ) orelse
  {
    utl.qlog( .ERROR, @src(), "Failed to create tilemap" );
    return;
  };

  var grid = &GRID;

  for( 0 .. grid.getTileCount() )| index |
  {
    var tile : *tlmp.Tile = &grid.tileArray[ index ];

    tile.colour = .mGray;
  }
}

pub fn OnGameClose( ng : *eng.Engine ) void
{
  _ = ng;

  GRID.deinit( utl.getDefaultAlloc() );
}

