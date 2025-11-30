const std = @import( "std" );
const def = @import( "defs" );

pub var GRID_ID     : u32 = 0;   //        12%        16%            20%         24%           28%
pub var MINE_COUNT  : u32 = 250; // baby = 150 easy = 200, normal == 250, hard = 300, insane = 350

pub var GRID_SCALE  : f32 = 43;

pub var GRID_WIDTH  : i32 = 50;
pub var GRID_HEIGHT : i32 = 25;

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
  const tlm = ng.loadTilemapFromParams(
  .{
    .mapPos    = .{ .x = 0,  .y = 32 },
    .mapSize   = .{ .x = GRID_WIDTH, .y = GRID_HEIGHT },
    .tileScale = .{ .x = GRID_SCALE, .y = GRID_SCALE },
    .tileShape = .HEX1,
  }, TILE_HIDDEN);


  if( tlm == null ){ def.qlog( .ERROR, 0, @src(), "Failed to create tilemap" ); }

  var grid : *def.Tilemap = tlm.?;

  GRID_ID = grid.id;

  for( 0 .. grid.getTileCount() )| index |
  {
    var tile : *def.Tile = &grid.tileArray.items.ptr[ index ];

    tile.colour = .mGray;
  }
}



