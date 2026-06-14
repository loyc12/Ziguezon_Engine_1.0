const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

const tlmp = utl.legacy_tilemap;

const Tilemap  = tlmp.Tilemap;
const TileType = tlmp.TileType;

pub var GRID : Tilemap = .{};

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

/// Returns the game-owned grid after `OnGameOpen` initializes it.
pub fn getGrid() ?*Tilemap
{
  if( GRID.isInit() ){ return &GRID; }

  utl.qlog( .WARN, @src(), "Politator grid is not initialized" );
  return null;
}

fn getRandomTileType() TileType
{
  return switch( eng.G_ENG.rng.getClampedInt( 1, 8 ))
  {
    1    => .T1,
    2    => .T2,
    3    => .T3,
    4    => .T4,
    5    => .T5,
    6    => .T6,
    7    => .T7,
    8    => .T8,
    else => unreachable,
  };
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
    .tileShape = .HEX2,
  }, .T1, utl.getDefaultAlloc() ) orelse
  {
    utl.qlog( .ERROR, @src(), "Failed to create tilemap" );
    return;
  };

  var worldGrid = &GRID;
  for( 0 .. worldGrid.getTileCount() )| index |
  {
    var tile : *tlmp.Tile = &worldGrid.tileArray[ index ];

    TILEMAP_DATA[ index ] =
    .{
      .popCount = @intCast( eng.G_ENG.rng.getClampedInt( 0, 256 )),
      .infCount = @intCast( eng.G_ENG.rng.getClampedInt( 0, 128 )),
      .resCount = @intCast( eng.G_ENG.rng.getClampedInt( 0, 512 )),
    };

    tile.tType  = getRandomTileType();
    tile.colour = .{ .r = 0, .g = 0, .b = 0, .a = 255 };
  }

}

pub fn OnGameClose( ng : *eng.Engine ) void
{
  _ = ng;

  GRID.deinit( utl.getDefaultAlloc() );
}


