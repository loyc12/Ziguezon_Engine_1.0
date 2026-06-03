const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

pub var P1_ID              : u32 = 0;
pub var P2_ID              : u32 = 0;
pub var SHADOW_RANGE_START : u32 = 0;
pub var SHADOW_RANGE_END   : u32 = 0;
pub var BALL_ID            : u32 = 0;

// ================================ STATE INJECTION FUNCTIONS ================================

pub fn OnStart( ng : *eng.Engine ) void
{
  ng.resourceManager.addAudioFromFile( "hit_1", "assets/sounds/Boop_1.wav" ) catch | err |
  {
    utl.log( .ERROR, 0, @src(), "Failed to load audio 'hit_1': {}\n", .{ err } );
  };
  ng.resourceManager.addAudioFromFile( "hit_2", "assets/sounds/Boop_2.wav" ) catch | err |
  {
    utl.log( .ERROR, 0, @src(), "Failed to load audio 'hit_2': {}\n", .{ err } );
  };
}

pub fn OnOpen( ng : *eng.Engine ) void
{
  if( ng.bodyManager.loadBodyFromParams( // player 1
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 128, .y = 16 },
    .colour = utl.Colour.blue,
    .pos    = .{ .x = -512, .y = 512 },
  })
  )| p1 |{ P1_ID = p1.id; } else { utl.qlog( .ERROR, 0, @src(), "Failed to create player 1 body" ); }

  if( ng.bodyManager.loadBodyFromParams( // player 2
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 128, .y = 16 },
    .colour = utl.Colour.red,
    .pos    = .{ .x = 512, .y = 512 },
  })
  )| p2 |{ P2_ID = p2.id; } else { utl.qlog( .ERROR, 0, @src(), "Failed to create player 2 body" ); }

  _ = ng.bodyManager.loadBodyFromParams( // separator
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 8, .y = 512 },
    .colour = utl.Colour.dGray,
    .pos    = .{ .x = 0, .y = 0 },
  });

  _ = ng.bodyManager.loadBodyFromParams( // separator
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 8, .y = 512 },
    .colour = utl.Colour.lGray,
    .pos    = .{ .x = 1024, .y = 0 },
  });

  _ = ng.bodyManager.loadBodyFromParams( // separator
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 8, .y = 512 },
    .colour = utl.Colour.lGray,
    .pos    = .{ .x = -1024, .y = 0 },
  });

  _ = ng.bodyManager.loadBodyFromParams( // separator
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 1024, .y = 8 },
    .colour = utl.Colour.lGray,
    .pos    = .{ .x = 0, .y = -512 },
  });

  if( ng.bodyManager.loadBodyFromParams( // ball shadow
  .{
    .shape  = .ELLI,
    .scale  = .{ .x = 6, .y = 6 },
    .colour = utl.Colour.pMagenta,
    .pos    = .{},
  })
  )| shad1 |{ SHADOW_RANGE_START = shad1.id; } else { utl.qlog( .ERROR, 0, @src(), "Failed to create ball shadow 1 body" ); }

  {
    _ = ng.bodyManager.loadBodyFromParams( // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 8, .y = 8 },
      .colour = utl.Colour.red,
      .pos    = .{},
    });

    _ = ng.bodyManager.loadBodyFromParams( // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 10, .y = 10 },
      .colour = utl.Colour.orange,
      .pos    = .{},
    });

    _ = ng.bodyManager.loadBodyFromParams( // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 12, .y = 12 },
      .colour = utl.Colour.yellow,
      .pos    = .{},
    });

    _ = ng.bodyManager.loadBodyFromParams( // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 14, .y = 14 },
      .colour = utl.Colour.green,
      .pos    = .{},
    });

    _ = ng.bodyManager.loadBodyFromParams( // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 16, .y = 16 },
      .colour = utl.Colour.cyan,
      .pos    = .{},
    });

    _ = ng.bodyManager.loadBodyFromParams( // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 18, .y = 18 },
      .colour = utl.Colour.blue,
      .pos    = .{},
    });

    _ = ng.bodyManager.loadBodyFromParams( // ball shadow
    .{
      .shape  = .ELLI,
      .scale  = .{ .x = 20, .y = 20 },
      .colour = utl.Colour.violet,
      .pos    = .{},
    });
  }

  if( ng.bodyManager.loadBodyFromParams( // ball shadow
  .{
    .shape  = .ELLI,
    .scale  = .{ .x = 22, .y = 22 },
    .colour = utl.Colour.magenta,
    .pos    = .{},
  })
  )| shad2 |{ SHADOW_RANGE_END = shad2.id; } else { utl.qlog( .ERROR, 0, @src(), "Failed to create ball shadow * body" ); }

  if( ng.bodyManager.loadBodyFromParams( // ball
  .{
    .shape  = .ELLI,
    .scale  = .{ .x = 24, .y = 24 },
    .colour = utl.Colour.white,
    .pos    = .{},
  })
  )| ball |{ BALL_ID = ball.id; } else { utl.qlog( .ERROR, 0, @src(), "Failed to create ball body" ); }
}
