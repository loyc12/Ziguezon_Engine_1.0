const std = @import( "std" );
const def = @import( "defs" );

pub var DISK_ID : u32 = 0;

// ================================ STATE INJECTION FUNCTIONS ================================

pub fn OnLaunch( ng : *def.eng.engine ) void // Called by engine.launch()
{

  if( ng.entityManager.addEntity( // disk
  .{
    .shape  = .RECT,
    .scale  = .{ .x = 32, .y = 32 },
    .colour = def.ray.Color.yellow,
    .pos    = .{ .x = -720, .y = 0 },
  })
  )| disk |{ DISK_ID = disk.id; } else { def.qlog( .ERROR, 0, @src(), "Failed to create disk entity" ); }
}