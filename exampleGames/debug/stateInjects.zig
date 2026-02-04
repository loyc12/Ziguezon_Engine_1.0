const std = @import( "std" );
const def = @import( "defs" );

// ================================ GLOBAL IDs ================================

pub var EXAMPLE_BDY_ID : u32 = 0;
pub var EXAMPLE_TLM_ID : u32 = 0;

pub var EXAMPLE_RLIN_ID : u32 = 0;
pub var EXAMPLE_DLIN_ID : u32 = 0;
pub var EXAMPLE_TRIA_ID : u32 = 0;
pub var EXAMPLE_RECT_ID : u32 = 0;
pub var EXAMPLE_HEXA_ID : u32 = 0;
pub var EXAMPLE_ELLI_ID : u32 = 0;


// ================================ STATE INJECTION FUNCTIONS ================================

pub fn OnStart( ng : *def.Engine ) void
{
  _ = ng;
}

pub fn OnOpen( ng : *def.Engine ) void
{
  ng.resourceManager.addAudioFromFile( "hit_1", "src/assets/sounds/Boop_2.wav" ) catch | err |
  {
    def.log( .ERROR, 0, @src(), "Failed to load audio 'hit_1': {}\n", .{ err } );
  };

  ng.resourceManager.addSpriteFromFile( "cubes_1", .{ .x = 32, .y = 32 }, 256, "src/assets/textures/Cubes.png" ) catch | err |
  {
    def.log( .ERROR, 0, @src(), "Failed to load sprite 'cubes_1': {}\n", .{ err } );
  };

  if( ng.bodyManager.loadBodyFromParams(
  .{
    .shape  = .HSTR,
    .scale  = .{ .x = 64, .y = 64 },
    .colour = def.Colour.white,
    .pos    = .{ .x = 512, .y = 0 },
  })
  )| bdy |{ EXAMPLE_BDY_ID = bdy.id; } else { def.qlog( .ERROR, 0, @src(), "Failed to create example body" ); }

  if( ng.bodyManager.loadBodyFromParams(
  .{
    .shape  = .RLIN,
    .scale  = .{ .x = 32, .y = 16 },
    .colour = def.Colour.white,
    .pos    = .{ .x = -256, .y = 256 },
  })
  )| bdy |{ EXAMPLE_RLIN_ID = bdy.id; } else { def.qlog( .ERROR, 0, @src(), "Failed to create example radius line" ); }

  if( ng.bodyManager.loadBodyFromParams(
  .{
    .shape  = .DLIN,
    .scale  = .{ .x = 32, .y = 16 },
    .colour = def.Colour.white,
    .pos    = .{ .x = -128, .y = 256 },
  })
  )| bdy |{ EXAMPLE_DLIN_ID = bdy.id; } else { def.qlog( .ERROR, 0, @src(), "Failed to create example diametre line" ); }

  if( ng.bodyManager.loadBodyFromParams(
  .{
    .shape  = .TRIA,
    .scale  = .{ .x = 32, .y = 16 },
    .colour = def.Colour.white,
    .pos    = .{ .x = 0, .y = 256 },
  })
  )| bdy |{ EXAMPLE_TRIA_ID = bdy.id; } else { def.qlog( .ERROR, 0, @src(), "Failed to create example triangle" ); }

  if( ng.bodyManager.loadBodyFromParams(
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 32, .y = 16 },
    .colour = def.Colour.white,
    .pos    = .{ .x = 128, .y = 256 },
  })
  )| bdy |{ EXAMPLE_RECT_ID = bdy.id; } else { def.qlog( .ERROR, 0, @src(), "Failed to create example rectangle" ); }

  if( ng.bodyManager.loadBodyFromParams(
  .{
    .shape  = .HEXA,
    .scale  = .{ .x = 32, .y = 16 },
    .colour = def.Colour.white,
    .pos    = .{ .x = 256, .y = 256 },
  })
  )| bdy |{ EXAMPLE_HEXA_ID = bdy.id; } else { def.qlog( .ERROR, 0, @src(), "Failed to create example hexagon" ); }


  if( ng.bodyManager.loadBodyFromParams(
  .{
    .shape  = .ELLI,
    .scale  = .{ .x = 32, .y = 16 },
    .colour = def.Colour.white,
    .pos    = .{ .x = 380, .y = 256 },
  })
  )| bdy |{ EXAMPLE_ELLI_ID = bdy.id; } else { def.qlog( .ERROR, 0, @src(), "Failed to create example ellipse" ); }


  if( ng.tilemapManager.loadTilemapFromParams(
  .{
    .mapPos    = .{ .x = -512, .y = 0 },
    .mapSize   = .{ .x = 8,  .y = 8  },
    .tileScale = .{ .x = 64, .y = 64 },
    .tileShape = .TRI1,
  }, .T1 )
  )| tlm |{ EXAMPLE_TLM_ID = tlm.id; } else { def.qlog( .ERROR, 0, @src(), "Failed to create example tilemap" ); }
}



