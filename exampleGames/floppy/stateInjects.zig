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

pub var mobileStore : MobileStore = .{};

// ================================ STATE INJECTION FUNCTIONS ================================

pub fn OnOpen( ng : *def.Engine ) void // Init and register ComponentStores here
{
  mobileStore.init( def.getAlloc() );

  if( !ng.registerComponentStore( "mobileStore", &mobileStore ))
  {
    def.qlog( .ERROR, 0, @src(), "Failed to register mobileStore" );
  }

  DISK_ID = ng.EntityIdRegistry.getNewEntity().id;

  if( mobileStore.add( DISK_ID,
    .{
      .scale = .{ .x =   32, .y =    32 },
      .pos   = .{ .x = -800, .y =     0 },
      .vel   = .{ .x =    0, .y = -1000 },
      .col   = def.Colour.green,
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

pub fn OnClose( ng : *def.Engine ) void // Deinit ComponentStores here
{
  _ = ng;
  mobileStore.deinit();
}