const std = @import( "std" );
const def = @import( "defs" );

pub var GRID_ID : u32 = 0;

pub const GRID_WIDTH  = 15;
pub const GRID_HEIGHT = 15;


pub const ground_type_e = enum
{
  Empty,
  Floor,
  Wall,
  Entry,
  Exit,
  Door1,
};

pub const mobile_type_e = enum
{
  Empty,
  Player,
  Enemy,
};

pub const object_type_e = enum
{
  Empty,
  Key1,
};

pub const TileData = struct
{
  ground : ground_type_e = .Floor,
  mobile : mobile_type_e = .Empty,
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
  const tlm = ng.loadTilemapFromParams(
  .{
    .mapPos    = .{ .x = 0,          .y = 0            },
    .mapSize   = .{ .x = GRID_WIDTH, .y = GRID_HEIGHT  },
    .tileScale = .{ .x = 64,         .y = 32           },
    .tileShape = .DIAM,
  }, .T1 );

  if( tlm == null ){ def.qlog( .ERROR, 0, @src(), "Failed to create tilemap" ); }

  var worldGrid : *def.Tilemap = tlm.?;

  GRID_ID = worldGrid.id;


  for( 0 .. worldGrid.getTileCount() )| index |
  {
    var tile : *def.Tile = &worldGrid.tileArray.items.ptr[ index ];

    tile.script.data = &TILEMAP_DATA[ index ];
  }

  worldGrid.fillWithColour( .lGreen );
}

