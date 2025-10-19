const std = @import( "std" );
const def = @import( "defs" );

pub var MAZE_ID : u32 = 0;

// ================================ STATE INJECTION FUNCTIONS ================================

pub fn OnStart( ng : *def.Engine ) void
{
  _ = ng; // Prevent unused variable warning
}

pub fn OnOpen( ng : *def.Engine ) void
{
  if( ng.loadTilemapFromParams(
  .{
    .gridPos   = .{ .x = 0,  .y = 0  },
    .gridSize  = .{ .x = 64, .y = 32 },
    .tileScale = .{ .x = 32, .y = 32 },
    .tileShape = .HEX1,
  }, .PARITY )
  )| tlm |{ MAZE_ID = tlm.id; } else { def.qlog( .ERROR, 0, @src(), "Failed to create tilemap" ); }
}



