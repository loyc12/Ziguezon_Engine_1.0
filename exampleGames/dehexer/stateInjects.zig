const std = @import( "std" );
const def = @import( "defs" );

pub var GRID_ID     : u32 = 0;
pub var MINE_COUNT  : u32 = 200;

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
    .gridPos   = .{ .x = 0,  .y = 32 },
    .gridSize  = .{ .x = GRID_WIDTH, .y = GRID_HEIGHT },
    .tileScale = .{ .x = GRID_SCALE, .y = GRID_SCALE },
    .tileShape = .HEX1,
  }, TILE_HIDDEN);


  if( tlm == null ){ def.qlog( .ERROR, 0, @src(), "Failed to create tilemap" ); }

  var grid : *def.Tilemap = tlm.?;

  GRID_ID = grid.id;

  var remaingingMineCount = MINE_COUNT;
  var remaingingTileCount = grid.getTileCount();

  for( 0 .. grid.getTileCount() )| index |
  {
    var tile : *def.Tile = &grid.tileArray.items.ptr[ index ];

    // getting a random value between 0.0 and 1.0
    const noiseVal = def.G_RNG.getFloat( f32 );

    // determining the odds of this tile being a mine
    var threshold : f32 = @floatFromInt( remaingingMineCount );
        threshold      /= @floatFromInt( remaingingTileCount );

    // if value > odds, tile is set as mine ( wall )
    if( remaingingMineCount > 0 and noiseVal < threshold )
    {
      remaingingMineCount -= 1;
      const mineTypeNoiseVal = def.G_RNG.getFloat( f32 );

      if(      mineTypeNoiseVal < 0.5 ){ tile.tType  = TILE_MINE_1; } //tile.colour = .lGreen; }
      else if( mineTypeNoiseVal < 0.8 ){ tile.tType  = TILE_MINE_2; } //tile.colour = .mGreen; }
      else{                              tile.tType  = TILE_MINE_3; } //tile.colour = .dGreen; }
    }
    remaingingTileCount -= 1;
  }

  if( remaingingMineCount != 0 )
  {
    def.qlog( .ERROR, 0, @src(), "@ Failed to assign the proper amount of mines !" );
  }
  else
  {
    def.qlog( .INFO, 0, @src(), "$ Assigned all mines properly !" );
  }

}



