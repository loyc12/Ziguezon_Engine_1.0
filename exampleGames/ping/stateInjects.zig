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
    .scale  = .{ .x = 24, .y = 24 },
    .colour = h.ray.Color.gray,
  });

  _ = ng.entityManager.addEntity( // ball
  .{
    .id     = 5,
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