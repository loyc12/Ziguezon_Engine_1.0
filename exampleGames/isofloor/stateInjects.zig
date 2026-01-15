const std = @import( "std" );
const def = @import( "defs" );

pub var GRID_ID : u32 = 0;

pub const GRID_WIDTH  = 15;
pub const GRID_HEIGHT = 15;


pub const ground_type_e = enum
{
  Empty,
  Floor,

  Entry,
  Exit,
};

pub const object_type_e = enum
{
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

// ================================ STATE INJECTION FUNCTIONS ================================
// These functions are called by the engine whenever it changes state ( see changeState() in engine.zig )

pub fn OnStart( ng : *def.Engine ) void
{
  _ = ng; // Prevent unused variable warning
}

pub fn OnOpen( ng : *def.Engine ) void
{

  ng.addSpriteFromFile( "cubes_1", .{ .x = 32, .y = 32 }, 256, "src/assets/textures/Cubes.png" ) catch | err |
  {
    def.log( .ERROR, 0, @src(), "Failed to load sprite 'cubes_1': {}\n", .{ err } );
  };

  const tlm = ng.loadTilemapFromParams(
  .{
    .mapPos    = .{ .x = 0,          .y = 0            },
    .mapSize   = .{ .x = GRID_WIDTH, .y = GRID_HEIGHT  },
    .tileScale = .{ .x = 64,         .y = 32           },
    .tileShape = .DIAM,
  }, .EMPTY );

  if( tlm == null ){ def.qlog( .ERROR, 0, @src(), "Failed to create tilemap" ); }

  var worldGrid : *def.Tilemap = tlm.?;

  GRID_ID = worldGrid.id;


  for( 0 .. worldGrid.getTileCount() )| index |
  {
    var tile : *def.Tile = &worldGrid.tileArray.items.ptr[ index ];

    TILEMAP_DATA[ index ] = .{};

    tile.script.data = &TILEMAP_DATA[ index ];
  }

  worldGrid.fillWithColour( .lGreen );
}

