const std = @import( "std" );
const h   = @import( "defs" );

pub var P1_ID              : u32 = 0;
pub var P2_ID              : u32 = 0;
pub var SHADOW_RANGE_START : u32 = 0;
pub var SHADOW_RANGE_END   : u32 = 0;
pub var BALL_ID            : u32 = 0;

// ================================ STATE INJECTION FUNCTIONS ================================

pub fn OnLaunch( ng : *h.eng.engine ) void // Called by engine.launch()
{

  if( ng.entityManager.addEntity( // player 1
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 128, .y = 32 },
    .colour = h.ray.Color.blue,
    .pos    = .{ .x = -512, .y = 512 },
  })
  )| p1 |{ P1_ID = p1.id; } else { h.qlog( .ERROR, 0, @src(), "Failed to create player 1 entity" ); }

  if( ng.entityManager.addEntity( // player 2
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 128, .y = 32 },
    .colour = h.ray.Color.red,
    .pos    = .{ .x = 512, .y = 512 },
  })
  )| p2 |{ P2_ID = p2.id; } else { h.qlog( .ERROR, 0, @src(), "Failed to create player 2 entity" ); }

  _ = ng.entityManager.addEntity( // separator
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 16, .y = 1024 },
    .colour = h.ray.Color.dark_gray,
    .pos    = .{ .x = 0, .y = 0 },
  });

  if( ng.entityManager.addEntity( // ball shadow
  .{
    .shape  = .CIRC,
    .scale  = .{ .x = 6, .y = 6 },
    .colour = h.ray.Color.pink,
    .pos    = .{ .x = 0, .y = 0 },
  })
  )| shad1 |{ SHADOW_RANGE_START = shad1.id; } else { h.qlog( .ERROR, 0, @src(), "Failed to create ball shadow 1 entity" ); }

  {
    _ = ng.entityManager.addEntity( // ball shadow
    .{
      .shape  = .CIRC,
      .scale  = .{ .x = 8, .y = 8 },
      .colour = h.ray.Color.red,
      .pos    = .{ .x = 0, .y = 0 },
    });

    _ = ng.entityManager.addEntity( // ball shadow
    .{
      .shape  = .CIRC,
      .scale  = .{ .x = 10, .y = 10 },
      .colour = h.ray.Color.orange,
      .pos    = .{ .x = 0, .y = 0 },
    });

    _ = ng.entityManager.addEntity( // ball shadow
    .{
      .shape  = .CIRC,
      .scale  = .{ .x = 12, .y = 12 },
      .colour = h.ray.Color.yellow,
      .pos    = .{ .x = 0, .y = 0 },
    });

    _ = ng.entityManager.addEntity( // ball shadow
    .{
      .shape  = .CIRC,
      .scale  = .{ .x = 14, .y = 14 },
      .colour = h.ray.Color.green,
      .pos    = .{ .x = 0, .y = 0 },
    });

    _ = ng.entityManager.addEntity( // ball shadow
    .{
      .shape  = .CIRC,
      .scale  = .{ .x = 16, .y = 16 },
      .colour = h.ray.Color.sky_blue,
      .pos    = .{ .x = 0, .y = 0 },
    });

    _ = ng.entityManager.addEntity( // ball shadow
    .{
      .shape  = .CIRC,
      .scale  = .{ .x = 18, .y = 18 },
      .colour = h.ray.Color.blue,
      .pos    = .{ .x = 0, .y = 0 },
    });

    _ = ng.entityManager.addEntity( // ball shadow
    .{
      .shape  = .CIRC,
      .scale  = .{ .x = 20, .y = 20 },
      .colour = h.ray.Color.violet,
      .pos    = .{ .x = 0, .y = 0 },
    });
  }

  if( ng.entityManager.addEntity( // ball shadow
  .{
    .shape  = .CIRC,
    .scale  = .{ .x = 22, .y = 22 },
    .colour = h.ray.Color.magenta,
    .pos    = .{ .x = 0, .y = 0 },
  })
  )| shad2 |{ SHADOW_RANGE_END = shad2.id; } else { h.qlog( .ERROR, 0, @src(), "Failed to create ball shadow * entity" ); }

  if( ng.entityManager.addEntity( // ball
  .{
    .shape  = .CIRC,
    .scale  = .{ .x = 24, .y = 24 },
    .colour = h.ray.Color.white,
    .pos    = .{ .x = 0, .y = 0 },
  })
  )| ball |{ BALL_ID = ball.id; } else { h.qlog( .ERROR, 0, @src(), "Failed to create ball entity" ); }
}