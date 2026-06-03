const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

pub var GRID_ID     : u32 = 0;

pub var GRID_WIDTH  : i32 = 50;
pub var GRID_HEIGHT : i32 = 25;

pub var GRID_SCALE  : f64 = 50; // NOTE : Will be overwritten

pub const TILE_MINE_1 = eng.e_tile_type.T1;
pub const TILE_MINE_2 = eng.e_tile_type.T2;
pub const TILE_MINE_3 = eng.e_tile_type.T3;
pub const TILE_HIDDEN = eng.e_tile_type.T4;
pub const TILE_SHOWN  = eng.e_tile_type.T5;

// ================================ STATE INJECTION FUNCTIONS ================================

pub fn OnGameStart( ng : *eng.Engine ) void
{
  _ = ng; // Prevent unused variable warning
}

pub fn OnGameOpen( ng : *eng.Engine ) void
{
  // Adjusting grid scalling to fit the screen
  const scaleFactor : f64 = @floatFromInt( 1 + @max( GRID_WIDTH, GRID_HEIGHT * 2 ));

  const scale2 = utl.getScreenSize().addVal( 128 ).mulVal( 1.0 / scaleFactor );

  GRID_SCALE = @max( scale2.x, scale2.y );


  // Setting up the grid
  const tlm = ng.tilemapManager.loadTilemapFromParams(
  .{
    .mapPos    = .{ .x = 0,          .y = GRID_SCALE  },
    .mapSize   = .{ .x = GRID_WIDTH, .y = GRID_HEIGHT },
    .tileScale = .{ .x = GRID_SCALE, .y = GRID_SCALE  },
    .tileShape = .HEX1,
  }, TILE_HIDDEN );


  if( tlm == null ){ utl.qlog( .ERROR, 0, @src(), "Failed to create tilemap" ); }

  var grid : *eng.Tilemap = tlm.?;

  GRID_ID = grid.id;

  for( 0 .. grid.getTileCount() )| index |
  {
    var tile : *eng.Tile = &grid.tileArray.items.ptr[ index ];

    tile.colour = .mGray;
  }
}



