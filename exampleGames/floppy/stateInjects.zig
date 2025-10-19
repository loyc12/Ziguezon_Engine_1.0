const std = @import( "std" );
const def = @import( "defs" );

pub var DISK_ID : u32 = 0;

// ================================ STATE INJECTION FUNCTIONS ================================

pub fn OnOpen( ng : *def.Engine ) void
{

  if( ng.loadEntityFromParams( // disk
  .{
    .pos    = .{ .x = -720, .y = 0 },
    .scale  = .{ .x = 32, .y = 32 },
    .shape  = .RECT,
    .colour = def.Colour.dGray,
  })
  )| disk |{ DISK_ID = disk.id; } else { def.qlog( .ERROR, 0, @src(), "Failed to create disk entity" ); }
}