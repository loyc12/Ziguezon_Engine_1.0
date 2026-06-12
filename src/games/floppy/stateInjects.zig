const eng = @import( "engine" );
const utl = @import( "utils" );

pub var DISK_ID : eng.EntityId = 0;

pub const diskStartPos = utl.VecA.new( -800,    0, .{} );
pub const diskStartVel = utl.VecA.new(    0, -4000, .{} );


// ================================ STATE INJECTION FUNCTIONS ================================

pub fn OnGameOpen( ng : *eng.Engine ) void
{
  if( !ng.world.registerComp( eng.TransComp ))
  {
    utl.qlog( .ERROR, @src(), "Failed to register TransComp" );
    return;
  }
  if( !ng.world.registerComp( eng.ShapeComp ))
  {
    _ = ng.world.unregisterComp( eng.TransComp );
    utl.qlog( .ERROR, @src(), "Failed to register ShapeComp" );
    return;
  }


  DISK_ID = ng.world.createEntity().id;


  if( ng.world.addComp( eng.TransComp, DISK_ID,
    .{
      .pos   = diskStartPos,
      .vel   = diskStartVel,
    }
  ))
  {
    utl.log( .INFO, @src(), "Added disk entity with Id {} to TransComp store", .{ DISK_ID });
  }
  else
  {
    utl.qlog( .ERROR, @src(), "Failed to add disk entity to TransComp store" );
  }

  if( ng.world.addComp( eng.ShapeComp, DISK_ID,
    .{
      .scale  = .{ .x = 32, .y = 32 },
      .shape  = .RECT,
      .colour = .green,
    }
  ))
  {
    utl.log( .INFO, @src(), "Added disk entity with Id {} to ShapeComp store", .{ DISK_ID });
  }
  else
  {
    utl.qlog( .ERROR, @src(), "Failed to add disk entity to ShapeComp store" );
  }
}


pub fn OnGameClose( ng : *eng.Engine ) void
{
  if( DISK_ID != 0 )
  {
    _ = ng.world.destroyEntity( DISK_ID );
    DISK_ID = 0;
  }

  _ = ng.world.unregisterComp( eng.ShapeComp );
  _ = ng.world.unregisterComp( eng.TransComp );
}
