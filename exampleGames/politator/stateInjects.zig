const std = @import( "std" );
const def = @import( "defs" );

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

  lastPopIn  : u32 = 0,
  lastPopOut : u32 = 0,

  lastInfGrowth : u32 = 0,
  lastInfLoss   : u32 = 0,

  lastResGrowth : u32 = 0,
  lastResLoss   : u32 = 0,
};

pub var TILEMAP_DATA      = std.mem.zeroes([ GRID_WIDTH * GRID_HEIGHT ] TileData );
pub var TILEMAP_DATA_NEXT = std.mem.zeroes([ GRID_WIDTH * GRID_HEIGHT ] TileData );

//: [ GRID_WIDTH * GRID_HEIGHT ]TileData = .{ .{} ** ( GRID_WIDTH * GRID_HEIGHT )};


// ================================ STATE INJECTION FUNCTIONS ================================
// These functions are called by the engine whenever it changes state ( see changeState() in engine.zig )

pub fn OnStart( ng : *def.Engine ) void
{
  _ = ng; // Prevent unused variable warning
}

pub fn OnOpen( ng : *def.Engine ) void
{
  const tlm = ng.loadTilemapFromParams(
  .{
    .mapPos    = .{ .x = 0,   .y = 0   },
    .mapSize   = .{ .x = 128, .y = 128 },
    .tileScale = .{ .x = 64,  .y = 64  },
    .tileShape = .HEX2,
  }, .RANDOM );

  if( tlm == null ){ def.qlog( .ERROR, 0, @src(), "Failed to create tilemap" ); }

  var worldGrid : *def.Tilemap = tlm.?;

  GRID_ID = worldGrid.id;

  for( 0 .. worldGrid.getTileCount() )| index |
  {
    var tile : *def.Tile = &worldGrid.tileArray.items.ptr[ index ];

    TILEMAP_DATA[ index ] =
    .{
      .popCount = @intCast( def.G_RNG.getClampedInt( 0, 256 )),
      .infCount = @intCast( def.G_RNG.getClampedInt( 0, 128 )),
      .resCount = @intCast( def.G_RNG.getClampedInt( 0, 512 )),
    };

    const red  : f32 = @floor( ( 256.0 - def.EPS ) * def.clmp( @as( f32, @floatFromInt( TILEMAP_DATA[ index ].popCount )) / 1024, 0.0, 1.0 ));
    const blue : f32 = @floor( ( 256.0 - def.EPS ) * def.clmp( @as( f32, @floatFromInt( TILEMAP_DATA[ index ].resCount )) / 1024, 0.0, 1.0 ));

    tile.colour = .{ .r = @intFromFloat( red ), .g = 0, .b = @intFromFloat( blue ), .a = 255 };

    tile.script.data = &TILEMAP_DATA[ index ];
  }

}




