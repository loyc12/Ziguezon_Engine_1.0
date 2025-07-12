const std = @import( "std" );
const h   = @import( "defs" );

// ================================ STATE INJECTION FUNCTIONS ================================

pub fn OnLaunch( ng : *h.eng.engine ) void // Called by engine.launch()
{

  _ = ng.entityManager.addEntity( // player 1
  .{
    .id     = 1,
    .active = true,
    .pos    = .{ .x = -512, .y = 512 },
    .vel    = .{ .x = 0, .y = 0 },
    .acc    = .{ .x = 0, .y = 0 },
    .rotPos = 0.0,
    .shape  = .RECT,
    .scale  = .{ .x = 128, .y = 32 },
    .colour = h.ray.Color.blue,
  });

_ = ng.entityManager.addEntity( // player 2
  .{
    .id     = 2,
    .active = true,
    .pos    = .{ .x = 512, .y = 512 },
    .vel    = .{ .x = 0, .y = 0 },
    .acc    = .{ .x = 0, .y = 0 },
    .rotPos = 0.0,
    .shape  = .RECT,
    .scale  = .{ .x = 128, .y = 32 },
    .colour = h.ray.Color.red,
  });

  _ = ng.entityManager.addEntity( // separator
  .{
    .id     = 3,
    .active = true,
    .pos    = .{ .x = 0, .y = 0 },
    .vel    = .{ .x = 0, .y = 0 },
    .acc    = .{ .x = 0, .y = 0 },
    .rotPos = 0.0,
    .shape  = .RECT,
    .scale  = .{ .x = 16, .y = 1024 },
    .colour = h.ray.Color.dark_gray,
  });

  _ = ng.entityManager.addEntity( // ball shaddow
  .{
    .id     = 4,
    .active = true,
    .pos    = .{ .x = 0, .y = 0 },
    .vel    = .{ .x = 0, .y = 0 },
    .acc    = .{ .x = 0, .y = 0 },
    .rotPos = 0.0,
    .shape  = .CIRC,
    .scale  = .{ .x = 12, .y = 12 },
    .colour = h.ray.Color.dark_gray
  });

  _ = ng.entityManager.addEntity( // ball shaddow
  .{
    .id     = 5,
    .active = true,
    .pos    = .{ .x = 0, .y = 0 },
    .vel    = .{ .x = 0, .y = 0 },
    .acc    = .{ .x = 0, .y = 0 },
    .rotPos = 0.0,
    .shape  = .CIRC,
    .scale  = .{ .x = 13, .y = 13 },
    .colour = h.ray.Color.gray,
  });

  _ = ng.entityManager.addEntity( // ball shaddow
  .{
    .id     = 6,
    .active = true,
    .pos    = .{ .x = 0, .y = 0 },
    .vel    = .{ .x = 0, .y = 0 },
    .acc    = .{ .x = 0, .y = 0 },
    .rotPos = 0.0,
    .shape  = .CIRC,
    .scale  = .{ .x = 14, .y = 14 },
    .colour = h.ray.Color.light_gray
  });

  _ = ng.entityManager.addEntity( // ball shaddow
  .{
    .id     = 7,
    .active = true,
    .pos    = .{ .x = 0, .y = 0 },
    .vel    = .{ .x = 0, .y = 0 },
    .acc    = .{ .x = 0, .y = 0 },
    .rotPos = 0.0,
    .shape  = .CIRC,
    .scale  = .{ .x = 15, .y = 15 },
    .colour = h.ray.Color.pink,
  });

  _ = ng.entityManager.addEntity( // ball shaddow
  .{
    .id     = 8,
    .active = true,
    .pos    = .{ .x = 0, .y = 0 },
    .vel    = .{ .x = 0, .y = 0 },
    .acc    = .{ .x = 0, .y = 0 },
    .rotPos = 0.0,
    .shape  = .CIRC,
    .scale  = .{ .x = 16, .y = 16 },
    .colour = h.ray.Color.red,
  });

  _ = ng.entityManager.addEntity( // ball shaddow
  .{
    .id     = 9,
    .active = true,
    .pos    = .{ .x = 0, .y = 0 },
    .vel    = .{ .x = 0, .y = 0 },
    .acc    = .{ .x = 0, .y = 0 },
    .rotPos = 0.0,
    .shape  = .CIRC,
    .scale  = .{ .x = 17, .y = 17 },
    .colour = h.ray.Color.orange,
  });

  _ = ng.entityManager.addEntity( // ball shaddow
  .{
    .id     = 10,
    .active = true,
    .pos    = .{ .x = 0, .y = 0 },
    .vel    = .{ .x = 0, .y = 0 },
    .acc    = .{ .x = 0, .y = 0 },
    .rotPos = 0.0,
    .shape  = .CIRC,
    .scale  = .{ .x = 18, .y = 18 },
    .colour = h.ray.Color.yellow,
  });

  _ = ng.entityManager.addEntity( // ball shaddow
  .{
    .id     = 11,
    .active = true,
    .pos    = .{ .x = 0, .y = 0 },
    .vel    = .{ .x = 0, .y = 0 },
    .acc    = .{ .x = 0, .y = 0 },
    .rotPos = 0.0,
    .shape  = .CIRC,
    .scale  = .{ .x = 19, .y = 19 },
    .colour = h.ray.Color.green,
  });

  _ = ng.entityManager.addEntity( // ball shaddow
  .{
    .id     = 12,
    .active = true,
    .pos    = .{ .x = 0, .y = 0 },
    .vel    = .{ .x = 0, .y = 0 },
    .acc    = .{ .x = 0, .y = 0 },
    .rotPos = 0.0,
    .shape  = .CIRC,
    .scale  = .{ .x = 20, .y = 20 },
    .colour = h.ray.Color.sky_blue,
  });

  _ = ng.entityManager.addEntity( // ball shaddow
  .{
    .id     = 13,
    .active = true,
    .pos    = .{ .x = 0, .y = 0 },
    .vel    = .{ .x = 0, .y = 0 },
    .acc    = .{ .x = 0, .y = 0 },
    .rotPos = 0.0,
    .shape  = .CIRC,
    .scale  = .{ .x = 21, .y = 21 },
    .colour = h.ray.Color.blue,
  });

  _ = ng.entityManager.addEntity( // ball shaddow
  .{
    .id     = 14,
    .active = true,
    .pos    = .{ .x = 0, .y = 0 },
    .vel    = .{ .x = 0, .y = 0 },
    .acc    = .{ .x = 0, .y = 0 },
    .rotPos = 0.0,
    .shape  = .CIRC,
    .scale  = .{ .x = 22, .y = 22 },
    .colour = h.ray.Color.violet,
  });

  _ = ng.entityManager.addEntity( // ball shaddow
  .{
    .id     = 15,
    .active = true,
    .pos    = .{ .x = 0, .y = 0 },
    .vel    = .{ .x = 0, .y = 0 },
    .acc    = .{ .x = 0, .y = 0 },
    .rotPos = 0.0,
    .shape  = .CIRC,
    .scale  = .{ .x = 23, .y = 23 },
    .colour = h.ray.Color.magenta,
  });

  _ = ng.entityManager.addEntity( // ball
  .{
    .id     = 16,
    .active = true,
    .pos    = .{ .x = 0, .y = 0 },
    .vel    = .{ .x = 0, .y = 0 },
    .acc    = .{ .x = 0, .y = 0 },
    .rotPos = 0.0,
    .shape  = .CIRC,
    .scale  = .{ .x = 24, .y = 24 },
    .colour = h.ray.Color.white,
  });
}