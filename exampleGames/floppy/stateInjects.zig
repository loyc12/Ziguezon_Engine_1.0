const std = @import( "std" );
const def = @import( "defs" );

pub var DISK_ID : def.EntityId = 0;

pub const Mobile = struct
{
  scale : def.Vec2   = .{},
  pos   : def.VecA   = .{},
  vel   : def.Vec2   = .{},
  acc   : def.Vec2   = .{},

  col   : def.Colour = def.Colour.white,
};

pub const MobileStore = def.componentStoreFactory( Mobile );

// ================================ STATE INJECTION FUNCTIONS ================================

pub fn OnOpen( ng : *def.Engine ) void
{
  var mobileStore : MobileStore = .{};
      mobileStore.init( def.getAlloc() );

  if( !ng.registerComponentStore( "mobileStore", &mobileStore ))
  {
    def.qlog( .ERROR, 0, @src(), "Failed to register mobileStore" );
  }

  const compMngr = ng.getComponentManager() catch | err |
  {
    def.log( .ERROR, 0, @src(), "Failed to obtain componentManager : {}", .{ err });
    return;
  };

  DISK_ID = compMngr.idReg.getNewEntity().id;

  if( mobileStore.add( DISK_ID,
    .{
      .scale = .{ .x =   32, .y = 32 },
      .pos   = .{ .x = -720, .y =  0 },
      .col   = def.Colour.dGray,
    }
  ))
  {
    def.log( .INFO, 0, @src(), "Added disk entity with Id {} to mobileStore", .{ DISK_ID });
  }
  else
  {
    def.qlog( .ERROR, 0, @src(), "Failed to add disk entity to mobileStore" );
  }
}