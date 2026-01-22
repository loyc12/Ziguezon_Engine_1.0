const std = @import( "std" );
const def = @import( "defs" );

pub var GRID_ID : u32 = 0;

pub const GRID_WIDTH  = 128;
pub const GRID_HEIGHT = 128;

pub const TileData = struct
{
  noiseVal : f32 = 0.0,
};

pub var TILEMAP_DATA = std.mem.zeroes([ GRID_WIDTH * GRID_HEIGHT ] TileData );


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

    TILEMAP_DATA[ index ] = .{ .noiseVal = def.G_RNG.getFloat( f32 )};

    const shade : u8 = @intFromFloat( @floor( 256 * def.clmp( TILEMAP_DATA[ index ].noiseVal, 0.0, 1.0 - def.EPS )));

    tile.colour      = .{ .r = shade, .g = shade, .b = shade, .a = 255 };
    tile.script.data = &TILEMAP_DATA[ index ];
  }

}




