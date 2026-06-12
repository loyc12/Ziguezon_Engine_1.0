const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

pub var GRID_ID : u32 = 0;

pub const GRID_WIDTH  = 128;
pub const GRID_HEIGHT = 128;

pub const TileData = struct
{
  popCount : u32 = 0, // Population on the tile
  resCount : u32 = 0, // Usable resources on the tile
  infCount : u32 = 0, // Maintained infrastructure on the tile

  nextPopCount : u32 = 0,
  nextResCount : u32 = 0,
  nextInfCount : u32 = 0,

  lastPopGrowth : u32 = 0,
  lastPopLoss   : u32 = 0,

  lastPopIn     : u32 = 0,
  lastPopOut    : u32 = 0,

  lastInfGrowth : u32 = 0,
  lastInfLoss   : u32 = 0,

  lastResGrowth : u32 = 0,
  lastResLoss   : u32 = 0,
};

pub var TILEMAP_DATA      = std.mem.zeroes([ GRID_WIDTH * GRID_HEIGHT ] TileData );
pub var TILEMAP_DATA_NEXT = std.mem.zeroes([ GRID_WIDTH * GRID_HEIGHT ] TileData );


// ================================ STATE INJECTION FUNCTIONS ================================
// These functions are called by the engine whenever it changes state ( see changeState() in engine.zig )

pub fn OnGameStart( ng : *eng.Engine ) void
{
  _ = ng; // Prevent unused variable warning
}

pub fn OnGameOpen( ng : *eng.Engine ) void
{
  const tlm = ng.tilemapManager.loadTilemapFromParams(
  .{
    .mapPos    = .{ .x = 0,   .y = 0   },
    .mapSize   = .{ .x = 128, .y = 128 },
    .tileScale = .{ .x = 64,  .y = 64  },
    .tileShape = .HEX2,
  }, .RANDOM );

  if( tlm == null ){ utl.qlog( .ERROR, @src(), "Failed to create tilemap" ); }

  var worldGrid : *eng.Tilemap = tlm.?;

  GRID_ID = worldGrid.id;

  for( 0 .. worldGrid.getTileCount() )| index |
  {
    var tile : *eng.Tile = &worldGrid.tileArray[ index ];

    TILEMAP_DATA[ index ] =
    .{
      .popCount = @intCast( eng.G_ENG.rng.getClampedInt( 0, 256 )),
      .infCount = @intCast( eng.G_ENG.rng.getClampedInt( 0, 128 )),
      .resCount = @intCast( eng.G_ENG.rng.getClampedInt( 0, 512 )),
    };

    tile.colour = .{ .r = 0, .g = 0, .b = 0, .a = 255 };
  }

}



