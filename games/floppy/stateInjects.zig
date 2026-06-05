const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

pub var DISK_ID : eng.EntityId = 0;

//pub const Mobile = struct
//{
//  scale : utl.Vec2   = .{},
//  pos   : utl.VecA   = .{},
//  vel   : utl.Vec2   = .{},
//  acc   : utl.Vec2   = .{},
//
//  col   : utl.Colour = utl.Colour.white,
//};
//
//pub const MobileStore = eng.ComponentStoreFactory( Mobile );
//
//pub var mobileStore : MobileStore = .{};

pub const TransformStore = eng.TransComp.StoreType();
pub const ShapeStore     = eng.ShapeComp.StoreType();

var transformStore : TransformStore = .{};
var shapeStore     : ShapeStore = .{};


pub const diskStartPos = utl.VecA.new( -800,    0, .{} );
pub const diskStartVel = utl.VecA.new(    0, -4000, .{} );


// ================================ STATE INJECTION FUNCTIONS ================================

pub fn OnGameOpen( ng : *eng.Engine ) void // Init and register ComponentStores here
{
  transformStore.init( utl.getDefaultAlloc() );
  shapeStore.init(     utl.getDefaultAlloc() );


  if( !ng.world.registerComponentStore( "transformStore", &transformStore ))
  {
    utl.qlog( .ERROR, 0, @src(), "Failed to register transformStore" );
  }
  if( !ng.world.registerComponentStore( "shapeStore", &shapeStore ))
  {
    utl.qlog( .ERROR, 0, @src(), "Failed to register shapeStore" );
  }


  DISK_ID = ng.world.createEntity().id;


  if( transformStore.add( DISK_ID,
    .{
      .pos   = diskStartPos,
      .vel   = diskStartVel,
    }
  ))
  {
    utl.log( .INFO, 0, @src(), "Added disk entity with Id {} to transformStore", .{ DISK_ID });
  }
  else
  {
    utl.qlog( .ERROR, 0, @src(), "Failed to add disk entity to transformStore" );
  }

  if( shapeStore.add( DISK_ID,
    .{
      .scale  = .{ .x = 32, .y = 32 },
      .shape  = .RECT,
      .colour = .green,
    }
  ))
  {
    utl.log( .INFO, 0, @src(), "Added disk entity with Id {} to shapeStore", .{ DISK_ID });
  }
  else
  {
    utl.qlog( .ERROR, 0, @src(), "Failed to add disk entity to shapeStore" );
  }
}


pub fn OnGameClose( ng : *eng.Engine ) void // Deinit ComponentStores here
{
  _ = ng.world.unregisterComponentStore( "transformStore" );
  _ = ng.world.unregisterComponentStore( "shapeStore" );

  transformStore.deinit();
  shapeStore.deinit();
}
