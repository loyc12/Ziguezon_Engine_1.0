const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

const tlmp = utl.legacy_tilemap;

const Tilemap = tlmp.Tilemap;

pub var GRID : Tilemap = .{};

pub const GRID_WIDTH  = 64;
pub const GRID_HEIGHT = 64;


pub const ground_type_e = enum
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  Empty,
  Floor,

  Entry,
  Exit,
};

pub const object_type_e = enum
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  Empty,

  Player,
  Enemy,

  Wall,

  Door1,
  Key1,
};


pub const TileData = struct
{
  ground : ground_type_e = .Floor,
  object : object_type_e = .Empty,
};

pub var TILEMAP_DATA      = std.mem.zeroes([ GRID_WIDTH * GRID_HEIGHT ] TileData );
pub var TILEMAP_DATA_NEXT = std.mem.zeroes([ GRID_WIDTH * GRID_HEIGHT ] TileData );

/// Returns the game-owned grid after `OnGameOpen` initializes it.
pub fn getGrid() ?*Tilemap
{
  if( GRID.isInit() ){ return &GRID; }

  utl.qlog( .WARN, @src(), "Isofloor grid is not initialized" );
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

  ng.resourceManager.addSpriteFromFile( "cubes_1", .{ .x = 32, .y = 32 }, 256, "assets/textures/Cubes.png" ) catch | err |
  {
    utl.log( .ERROR, @src(), "Failed to load sprite 'cubes_1': {}\n", .{ err } );
  };

  GRID = Tilemap.createTilemapFromParams(
  .{
    .mapPos    = .{ .x = 0,          .y = 0            },
    .mapSize   = .{ .x = GRID_WIDTH, .y = GRID_HEIGHT  },
    .tileScale = .{ .x = 64,         .y = 32           },
    .tileShape = .DIAM,
  }, .T1, utl.getDefaultAlloc() ) orelse
  {
    utl.qlog( .ERROR, @src(), "Failed to create tilemap" );
    return;
  };

  var worldGrid = &GRID;

  for( 0 .. worldGrid.getTileCount() )| index |
  {
    TILEMAP_DATA[ index ] = .{};
  }

  worldGrid.fillWithColour( .lGreen );
}

pub fn OnGameClose( ng : *eng.Engine ) void
{
  _ = ng;

  if( GRID.isInit() ){ GRID.deinit( utl.getDefaultAlloc() ); }
}
