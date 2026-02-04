const std = @import( "std" );
const def = @import( "defs" );

pub var GRID_ID     : u32 = 0;

pub var GRID_WIDTH  : i32 = 50;
pub var GRID_HEIGHT : i32 = 25;

pub var GRID_SCALE  : f32 = 50; // NOTE : Will be overwritten

pub const TILE_MINE_1 = def.e_tile_type.T1;
pub const TILE_MINE_2 = def.e_tile_type.T2;
pub const TILE_MINE_3 = def.e_tile_type.T3;
pub const TILE_HIDDEN = def.e_tile_type.T4;
pub const TILE_SHOWN  = def.e_tile_type.T5;

// ================================ STATE INJECTION FUNCTIONS ================================

pub fn OnStart( ng : *def.Engine ) void
{
  _ = ng; // Prevent unused variable warning
}

pub fn OnOpen( ng : *def.Engine ) void
{
  // Adjusting grid scalling to fit the screen
  const scaleFactor : f32 = @floatFromInt( 1 + @max( GRID_WIDTH, GRID_HEIGHT * 2 ));

  const scale2 = def.getScreenSize().addVal( 128 ).divVal( scaleFactor ).?;

  GRID_SCALE = @max( scale2.x, scale2.y );


  // Setting up the grid
  const tlm = ng.tilemapManager.loadTilemapFromParams(
  .{
    .mapPos    = .{ .x = 0,          .y = GRID_SCALE  },
    .mapSize   = .{ .x = GRID_WIDTH, .y = GRID_HEIGHT },
    .tileScale = .{ .x = GRID_SCALE, .y = GRID_SCALE  },
    .tileShape = .HEX1,
  }, TILE_HIDDEN );


  if( tlm == null ){ def.qlog( .ERROR, 0, @src(), "Failed to create tilemap" ); }

  var grid : *def.Tilemap = tlm.?;

  GRID_ID = grid.id;

  for( 0 .. grid.getTileCount() )| index |
  {
    var tile : *def.Tile = &grid.tileArray.items.ptr[ index ];

    tile.colour = .mGray;
  }
}



