const std = @import( "std" );
const def = @import( "defs" );

// ================================ GLOBAL IDs ================================

pub var EXAMPLE_NTT_ID : u32 = 0;
pub var EXAMPLE_TLM_ID : u32 = 0;

pub var EXAMPLE_RLIN_ID : u32 = 0;
pub var EXAMPLE_DLIN_ID : u32 = 0;
pub var EXAMPLE_TRIA_ID : u32 = 0;
pub var EXAMPLE_RECT_ID : u32 = 0;
pub var EXAMPLE_HEXA_ID : u32 = 0;
pub var EXAMPLE_ELLI_ID : u32 = 0;


// ================================ STATE INJECTION FUNCTIONS ================================

pub fn OnStart( ng : *def.Engine ) void // Called by engine.start()    // NOTE : This is where you should initialize your resources
{
  ng.addAudioFromFile( "hit_1", "exampleGames/__assets/sounds/Boop_2.wav" ) catch | err |
  {
    def.log( .ERROR, 0, @src(), "Failed to load audio 'hit_2': {}\n", .{ err } );
  };
}

pub fn OnOpen( ng : *def.Engine ) void // Called by engine.open()      // NOTE : This is where you should initialize your entities
{
  if( ng.loadEntityFromParams(
  .{
    .shape  = .HSTR,
    .scale  = .{ .x = 64, .y = 64 },
    .colour = def.Colour.white,
    .pos    = .{ .x = 512, .y = 0 },
  })
  )| ntt |{ EXAMPLE_NTT_ID = ntt.id; } else { def.qlog( .ERROR, 0, @src(), "Failed to create example entity" ); }

  if( ng.loadEntityFromParams(
  .{
    .shape  = .RLIN,
    .scale  = .{ .x = 32, .y = 16 },
    .colour = def.Colour.white,
    .pos    = .{ .x = -256, .y = 256 },
  })
  )| ntt |{ EXAMPLE_RLIN_ID = ntt.id; } else { def.qlog( .ERROR, 0, @src(), "Failed to create example radius line" ); }

  if( ng.loadEntityFromParams(
  .{
    .shape  = .DLIN,
    .scale  = .{ .x = 32, .y = 16 },
    .colour = def.Colour.white,
    .pos    = .{ .x = -128, .y = 256 },
  })
  )| ntt |{ EXAMPLE_DLIN_ID = ntt.id; } else { def.qlog( .ERROR, 0, @src(), "Failed to create example diametre line" ); }

  if( ng.loadEntityFromParams(
  .{
    .shape  = .TRIA,
    .scale  = .{ .x = 32, .y = 16 },
    .colour = def.Colour.white,
    .pos    = .{ .x = 0, .y = 256 },
  })
  )| ntt |{ EXAMPLE_TRIA_ID = ntt.id; } else { def.qlog( .ERROR, 0, @src(), "Failed to create example triangle" ); }

  if( ng.loadEntityFromParams(
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 32, .y = 16 },
    .colour = def.Colour.white,
    .pos    = .{ .x = 128, .y = 256 },
  })
  )| ntt |{ EXAMPLE_RECT_ID = ntt.id; } else { def.qlog( .ERROR, 0, @src(), "Failed to create example rectangle" ); }

  if( ng.loadEntityFromParams(
  .{
    .shape  = .HEXA,
    .scale  = .{ .x = 32, .y = 16 },
    .colour = def.Colour.white,
    .pos    = .{ .x = 256, .y = 256 },
  })
  )| ntt |{ EXAMPLE_HEXA_ID = ntt.id; } else { def.qlog( .ERROR, 0, @src(), "Failed to create example hexagon" ); }


  if( ng.loadEntityFromParams(
  .{
    .shape  = .ELLI,
    .scale  = .{ .x = 32, .y = 16 },
    .colour = def.Colour.white,
    .pos    = .{ .x = 380, .y = 256 },
  })
  )| ntt |{ EXAMPLE_ELLI_ID = ntt.id; } else { def.qlog( .ERROR, 0, @src(), "Failed to create example ellipse" ); }


  if( ng.loadTilemapFromParams(
  .{
    .gridPos   = .{ .x = -512, .y = 0 },
    .gridSize  = .{ .x = 8,  .y = 8  },
    .tileScale = .{ .x = 64, .y = 64 },
    .tileShape = .TRI1,
  }, .FLOOR )
  )| tlm |{ EXAMPLE_TLM_ID = tlm.id; } else { def.qlog( .ERROR, 0, @src(), "Failed to create example tilemap" ); }
}



