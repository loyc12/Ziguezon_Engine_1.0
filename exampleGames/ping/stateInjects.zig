const std = @import( "std" );
const h   = @import( "defs" );

pub fn OnStart( ng : *h.eng.engine ) void // Called by engine.start()
{
  _ = ng; // Prevent unused variable warning
  return;
}

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

  _ = ng.entityManager.addEntity( // ball
  .{
    .id     = 4,
    .active = true,
    .pos    = .{ .x = 0, .y = 0 },
    .vel    = .{ .x = 0, .y = 0 },
    .acc    = .{ .x = 0, .y = 0 },
    .rotPos = 0.0,
    .shape  = .CIRC,
    .scale  = .{ .x = 32, .y = 32 },
    .colour = h.ray.Color.white,
  });

  _ = ng.entityManager.addEntity( // ball 2 ( debug )
  .{
    .id     = 5,
    .active = true,
    .pos    = .{ .x = 0, .y = 0 },
    .vel    = .{ .x = 0, .y = 0 },
    .acc    = .{ .x = 0, .y = 0 },
    .rotPos = 0.0,
    .shape  = .CIRC,
    .scale  = .{ .x = 32, .y = 32 },
    .colour = h.ray.Color.gray,
  });
}

pub fn OnPlay( ng : *h.eng.engine ) void // Called by engine.play()
{
  _ = ng; // Prevent unused variable warning
  return;
}

pub fn OnPause( ng : *h.eng.engine ) void // Called by engine.pause()
{
  _ = ng; // Prevent unused variable warning
  return;
}

pub fn OnStop( ng : *h.eng.engine ) void // Called by engine.stop()
{
  _ = ng; // Prevent unused variable warning
  return;
}

pub fn OnClose( ng : *h.eng.engine ) void // Called by engine.close()
{
  _ = ng; // Prevent unused variable warning
  return;
}

