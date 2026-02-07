const std = @import( "std" );
const def = @import( "defs" );

pub var DISK_ID : def.EntityId = 0;

//pub const Mobile = struct
//{
//  scale : def.Vec2   = .{},
//  pos   : def.VecA   = .{},
//  vel   : def.Vec2   = .{},
//  acc   : def.Vec2   = .{},
//
//  col   : def.Colour = def.Colour.white,
//};
//
//pub const MobileStore = def.componentStoreFactory( Mobile );
//
//pub var mobileStore : MobileStore = .{};

pub const TransformStore = def.TransComp.getStoreType();
pub const ShapeStore     = def.ShapeComp.getStoreType();

var transformStore : TransformStore = .{};
var shapeStore     : ShapeStore = .{};


pub const diskStartPos = def.VecA.new( -400,   200, .{} );
pub const diskStartVel = def.VecA.new(    0, -2400, .{} );


// ================================ STATE INJECTION FUNCTIONS ================================

pub fn OnOpen( ng : *def.Engine ) void // Init and register ComponentStores here
{
  transformStore.init( def.getAlloc() );
  shapeStore.init(     def.getAlloc() );


  if( !ng.componentRegistry.register( "transformStore", &transformStore ))
  {
    def.qlog( .ERROR, 0, @src(), "Failed to register transformStore" );
  }
  if( !ng.componentRegistry.register( "shapeStore", &shapeStore ))
  {
    def.qlog( .ERROR, 0, @src(), "Failed to register shapeStore" );
  }


  DISK_ID = ng.entityIdRegistry.getNewEntity().id;


  if( transformStore.add( DISK_ID,
    .{
      .pos   = diskStartPos,
      .vel   = diskStartVel,
    }
  ))
  {
    def.log( .INFO, 0, @src(), "Added disk entity with Id {} to transformStore", .{ DISK_ID });
  }
  else
  {
    def.qlog( .ERROR, 0, @src(), "Failed to add disk entity to transformStore" );
  }

  if( shapeStore.add( DISK_ID,
    .{
      .scale  = .{ .x = 32, .y = 32 },
      .shape  = .RECT,
      .colour = .green,
    }
  ))
  {
    def.log( .INFO, 0, @src(), "Added disk entity with Id {} to shapeStore", .{ DISK_ID });
  }
  else
  {
    def.qlog( .ERROR, 0, @src(), "Failed to add disk entity to shapeStore" );
  }
}


pub fn OnClose( ng : *def.Engine ) void // Deinit ComponentStores here
{
  _ = ng;

  transformStore.deinit();
  shapeStore.deinit();
}