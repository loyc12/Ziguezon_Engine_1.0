const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

const tlmp = utl.legacy_tilemap;

const Tilemap = tlmp.Tilemap;

pub var GRID : Tilemap = .{};

pub const GRID_WIDTH  = 128;
pub const GRID_HEIGHT = 128;

pub const TileData = struct
{
  noiseVal : f32 = 0.0,
};

pub var TILEMAP_DATA = std.mem.zeroes([ GRID_WIDTH * GRID_HEIGHT ] TileData );

pub const NOISE_SCALE : f32 = 1.0 / 32.0;
pub var NOISE_GEN : utl.Noise2D =
.{
  .seed = 0,

  .warpCount    = 1,
  .warpStrength = 1.5,

  .octaveCount = 6,
};

/// Returns the game-owned grid after `OnGameOpen` initializes it.
pub fn getGrid() ?*Tilemap
{
  if( GRID.isInit() ){ return &GRID; }

  utl.qlog( .WARN, @src(), "Granulater grid is not initialized" );
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

  GRID = Tilemap.createTilemapFromParams(
  .{
    .mapPos    = .{ .x = 0,   .y = 0   },
    .mapSize   = .{ .x = 128, .y = 128 },
    .tileScale = .{ .x = 64,  .y = 64  },
    .tileShape = .RECT,
  }, .T1, utl.getDefaultAlloc() ) orelse
  {
    utl.qlog( .ERROR, @src(), "Failed to create tilemap" );
    return;
  };

  var worldGrid = &GRID;

  var min_noise : f32 = 1.0;
  var max_noise : f32 = 0.0;

  NOISE_GEN.seed = eng.G_ENG.rng.getInt( u64 );
  utl.log( .INFO, @src(), "Generating world with seed '{}'", .{ NOISE_GEN.seed });

  for( 0 .. worldGrid.getTileCount() )| index |
  {
    const tile : *tlmp.Tile = &worldGrid.tileArray[ index ];

    const noise : f32 = NOISE_GEN.warpedFractalSample( tile.mapCoords.toVec2().mulVal( NOISE_SCALE ));

    if( noise < min_noise ){ min_noise = noise; }
    if( noise > max_noise ){ max_noise = noise; }

    TILEMAP_DATA[ index ] = .{ .noiseVal = noise };
  }

  utl.log( .INFO, @src(), "Min : {d}, Max : {d}", .{ min_noise, max_noise });
}

pub fn OnGameClose( ng : *eng.Engine ) void
{
  _ = ng;

  if( GRID.isInit() ){ GRID.deinit( utl.getDefaultAlloc() ); }
}

