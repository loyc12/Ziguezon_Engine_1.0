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

pub const NOISE_SCALE : f32 = 1.0 / 32.0;
pub var NOISE_GEN : def.Noise2D =
.{
  .seed = 0,

  .warpCount    = 1,
  .warpStrenght = 1.5,

  .octaveCount = 6,
};


// ================================ STATE INJECTION FUNCTIONS ================================
// These functions are called by the engine whenever it changes state ( see changeState() in engine.zig )

pub fn OnStart( ng : *def.Engine ) void
{
  _ = ng; // Prevent unused variable warning
}

pub fn OnOpen( ng : *def.Engine ) void
{
  const tlm = ng.tilemapManager.loadTilemapFromParams(
  .{
    .mapPos    = .{ .x = 0,   .y = 0   },
    .mapSize   = .{ .x = 128, .y = 128 },
    .tileScale = .{ .x = 64,  .y = 64  },
    .tileShape = .RECT,
  }, .RANDOM );

  if( tlm == null ){ def.qlog( .ERROR, 0, @src(), "Failed to create tilemap" ); }

  var worldGrid : *def.Tilemap = tlm.?;

  GRID_ID = worldGrid.id;


  var min_noise : f32 = 1.0;
  var max_noise : f32 = 0.0;

  NOISE_GEN.seed = def.G_RNG.getInt( u64 );
  def.log( .INFO, 0, @src(), "Generating world with seed '{}'", .{ NOISE_GEN.seed });

  for( 0 .. worldGrid.getTileCount() )| index |
  {
    var tile : *def.Tile = &worldGrid.tileArray.items.ptr[ index ];

    const noise : f32 = NOISE_GEN.warpedFractalSample( tile.mapCoords.toVec2().mulVal( NOISE_SCALE ));

    if( noise < min_noise ){ min_noise = noise; }
    if( noise > max_noise ){ max_noise = noise; }

    TILEMAP_DATA[ index ] = .{ .noiseVal = noise };
    tile.script.data = &TILEMAP_DATA[ index ];
  }

  def.log( .INFO, 0, @src(), "Min : {d}, Max : {d}", .{ min_noise, max_noise });
}




