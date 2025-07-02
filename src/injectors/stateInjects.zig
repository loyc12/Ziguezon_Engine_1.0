const std = @import( "std" );
const h   = @import( "../headers.zig" );
const eng = @import( "../core/engine.zig" );

pub fn OnStart( ng : *eng.engine ) void // Called by engine.start()
{
  _ = ng; // Prevent unused variable warning
  return;
}

pub fn OnLaunch( ng : *eng.engine ) void // Called by engine.launch()
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
    .colour = h.rl.Color.blue,
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
    .colour = h.rl.Color.red,
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
    .colour = h.rl.Color.dark_gray,
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
    .colour = h.rl.Color.white,
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
    .colour = h.rl.Color.gray,
  });
}

pub fn OnPlay( ng : *eng.engine ) void // Called by engine.play()
{
  _ = ng; // Prevent unused variable warning
  return;
}

pub fn OnPause( ng : *eng.engine ) void // Called by engine.pause()
{
  _ = ng; // Prevent unused variable warning
  return;
}

pub fn OnStop( ng : *eng.engine ) void // Called by engine.stop()
{
  _ = ng; // Prevent unused variable warning
  return;
}

pub fn OnClose( ng : *eng.engine ) void // Called by engine.close()
{
  _ = ng; // Prevent unused variable warning
  return;
}

