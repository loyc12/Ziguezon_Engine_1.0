const std = @import( "std" );
const def = @import( "defs" );

pub var MAZE_ID : u32 = 0;

// ================================ STATE INJECTION FUNCTIONS ================================
// These functions are called by the engine whenever it changes state ( see changeState() in engine.zig )

pub fn OnStart( ng : *def.Engine ) void
{
  _ = ng; // Prevent unused variable warning
}

pub fn OnOpen( ng : *def.Engine ) void
{
  if( ng.loadTilemapFromParams(
  .{
    .gridPos   = .{ .x = 0, .y = 0 },
    .gridSize  = .{ .x = 256, .y = 256  },
    .tileScale = .{ .x = 64, .y = 64 },
    .tileShape = .RECT,
  }, .RANDOM )
  )| tlm |{ MAZE_ID = tlm.id; } else { def.qlog( .ERROR, 0, @src(), "Failed to create maze tilemap" ); }
}




