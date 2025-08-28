const std = @import( "std" );
const def = @import( "defs" );

pub var MAZE_ID : u32 = 0;

// ================================ STATE INJECTION FUNCTIONS ================================
// These functions are called by the engine whenever it changes state ( see changeState() in engine.zig )

pub fn OnStart( ng : *def.Engine ) void // Called by engine.start()    // NOTE : This is where you should initialize your resources
{
  _ = ng; // Prevent unused variable warning
}
pub fn OnStop( ng : *def.Engine ) void // Called by engine.stop()
{
  _ = ng; // Prevent unused variable warning
}


pub fn OnOpen( ng : *def.Engine ) void // Called by engine.open()      // NOTE : This is where you should initialize your entities
{
  if( ng.loadTilemapFromParams(
  .{
    .gridPos   = .{ .x = 0, .y = 0 },
    .gridSize  = .{ .x = 31, .y = 31  },
    .tileScale = .{ .x = 64, .y = 64 },
    .tileShape = .RECT,
  }, .RANDOM )
  )| tlm |{ MAZE_ID = tlm.id; } else { def.qlog( .ERROR, 0, @src(), "Failed to create maze tilemap" ); }
}
pub fn OnClose( ng : *def.Engine ) void // Called by engine.close()
{
  _ = ng; // Prevent unused variable warning
}


pub fn OnPlay( ng : *def.Engine ) void // Called by engine.play()
{
  _ = ng; // Prevent unused variable warning
}
pub fn OnPause( ng : *def.Engine ) void // Called by engine.pause()
{
  _ = ng; // Prevent unused variable warning
}





