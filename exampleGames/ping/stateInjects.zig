const std = @import( "std" );
const def = @import( "defs" );

pub var P1_ID              : u32 = 0;
pub var P2_ID              : u32 = 0;
pub var SHADOW_RANGE_START : u32 = 0;
pub var SHADOW_RANGE_END   : u32 = 0;
pub var BALL_ID            : u32 = 0;

// ================================ STATE INJECTION FUNCTIONS ================================

pub fn OnStart( ng : *def.Engine ) void // Called by engine.start()
{
  ng.resourceManager.addAudioFromFile( "hit_1", "exampleGames/assets/sounds/Boop_1.wav" ) catch | err |
  {
    def.log( .ERROR, 0, @src(), "Failed to load audio 'hit_1': {}\n", .{ err } );
  };
  ng.resourceManager.addAudioFromFile( "hit_2", "exampleGames/assets/sounds/Boop_2.wav" ) catch | err |
  {
    def.log( .ERROR, 0, @src(), "Failed to load audio 'hit_2': {}\n", .{ err } );
  };
}

pub fn OnOpen( ng : *def.Engine ) void // Called by engine.open()
{

  if( ng.entityManager.loadEntityFromParams( // player 1
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 128, .y = 16 },
    .colour = def.Colour.blue,
    .pos    = .{ .x = -512, .y = 512, .z = 0 },
  })
  )| p1 |{ P1_ID = p1.id; } else { def.qlog( .ERROR, 0, @src(), "Failed to create player 1 entity" ); }

  if( ng.entityManager.loadEntityFromParams( // player 2
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 128, .y = 16 },
    .colour = def.Colour.red,
    .pos    = .{ .x = 512, .y = 512, .z = 0 },
  })
  )| p2 |{ P2_ID = p2.id; } else { def.qlog( .ERROR, 0, @src(), "Failed to create player 2 entity" ); }

  _ = ng.entityManager.loadEntityFromParams( // separator
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 8, .y = 512 },
    .colour = def.Colour.dark_gray,
    .pos    = .{ .x = 0, .y = 0, .z = 0 },
  });

  _ = ng.entityManager.loadEntityFromParams( // separator
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 8, .y = 512 },
    .colour = def.Colour.light_gray,
    .pos    = .{ .x = 1024, .y = 0, .z = 0 },
  });

  _ = ng.entityManager.loadEntityFromParams( // separator
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 8, .y = 512 },
    .colour = def.Colour.light_gray,
    .pos    = .{ .x = -1024, .y = 0, .z = 0 },
  });

  _ = ng.entityManager.loadEntityFromParams( // separator
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 1024, .y = 8 },
    .colour = def.Colour.light_gray,
    .pos    = .{ .x = 0, .y = -512, .z = 0 },
  });

  if( ng.entityManager.loadEntityFromParams( // ball shadow
  .{
    .shape  = .ELLI,
    .scale  = .{ .x = 6, .y = 6 },
    .colour = def.Colour.pink,
    .pos    = .{ .x = 0, .y = 0, .z = 0 },
  })
  )| shad1 |{ SHADOW_RANGE_START = shad1.id; } else { def.qlog( .ERROR, 0, @src(), "Failed to create ball shadow 1 entity" ); }

  {
    _ = ng.entityManager.loadEntityFromParams( // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 8, .y = 8 },
      .colour = def.Colour.red,
      .pos    = .{ .x = 0, .y = 0, .z = 0 },
    });

    _ = ng.entityManager.loadEntityFromParams( // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 10, .y = 10 },
      .colour = def.Colour.orange,
      .pos    = .{ .x = 0, .y = 0, .z = 0 },
    });

    _ = ng.entityManager.loadEntityFromParams( // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 12, .y = 12 },
      .colour = def.Colour.yellow,
      .pos    = .{ .x = 0, .y = 0, .z = 0 },
    });

    _ = ng.entityManager.loadEntityFromParams( // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 14, .y = 14 },
      .colour = def.Colour.green,
      .pos    = .{ .x = 0, .y = 0, .z = 0 },
    });

    _ = ng.entityManager.loadEntityFromParams( // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 16, .y = 16 },
      .colour = def.Colour.sky_blue,
      .pos    = .{ .x = 0, .y = 0, .z = 0 },
    });

    _ = ng.entityManager.loadEntityFromParams( // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 18, .y = 18 },
      .colour = def.Colour.blue,
      .pos    = .{ .x = 0, .y = 0, .z = 0 },
    });

    _ = ng.entityManager.loadEntityFromParams( // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 20, .y = 20 },
      .colour = def.Colour.violet,
      .pos    = .{ .x = 0, .y = 0, .z = 0 },
    });
  }

  if( ng.entityManager.loadEntityFromParams( // ball shadow
  .{
    .shape  = .ELLI,
    .scale  = .{ .x = 22, .y = 22 },
    .colour = def.Colour.magenta,
    .pos    = .{ .x = 0, .y = 0, .z = 0 },
  })
  )| shad2 |{ SHADOW_RANGE_END = shad2.id; } else { def.qlog( .ERROR, 0, @src(), "Failed to create ball shadow * entity" ); }

  if( ng.entityManager.loadEntityFromParams( // ball
  .{
    .shape  = .ELLI,
    .scale  = .{ .x = 24, .y = 24 },
    .colour = def.Colour.white,
    .pos    = .{ .x = 0, .y = 0, .z = 0 },
  })
  )| ball |{ BALL_ID = ball.id; } else { def.qlog( .ERROR, 0, @src(), "Failed to create ball entity" ); }
}