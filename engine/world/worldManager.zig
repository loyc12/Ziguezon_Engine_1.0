const std = @import( "std" );
const utl = @import( "utils" );

const entity    = @import( "entity.zig" );
const component = @import( "components/component.zig" );

const Entity            = entity.Entity;
const EntityIdRegistry  = entity.EntityIdRegistry;
const ComponentRegistry = component.ComponentRegistry;
const TimeVal           = utl.TimeVal;


pub const TickContext = struct
{
  baseTickIndex : u128    = 0,
  targetDelta   : TimeVal = .{},
  measuredDelta : TimeVal = .{},
  isForced      : bool    = false,
};


pub const World = struct
{
  entityIdRegistry  : EntityIdRegistry  = .{},
  componentRegistry : ComponentRegistry = .{},

  isInit : bool = false,


  // ================================ LIFECYCLE FUNCTIONS ================================

  pub fn init( self : *World, alloc : std.mem.Allocator ) void
  {
    if( self.isInit )
    {
      utl.qlog( .WARN, 0, @src(), "World is already initialized : returning" );
      return;
    }

    self.entityIdRegistry.reinit();
    self.componentRegistry.init( alloc );
    self.isInit = true;
  }

  pub fn deinit( self : *World ) void
  {
    if( !self.isInit )
    {
      utl.qlog( .WARN, 0, @src(), "World is uninitialized : returning" );
      return;
    }

    self.componentRegistry.deinit();
    self.entityIdRegistry.reinit();
    self.isInit = false;
  }


  // ================================ ENTITY FUNCTIONS ================================

  pub inline fn createEntity( self : *World ) Entity
  {
    if( !self.isInit )
    {
      utl.qlog( .WARN, 0, @src(), "Cannot create Entity : World is uninitialized" );
      return .{};
    }

    return self.entityIdRegistry.getNewEntity();
  }


  // ================================ COMPONENT STORE COMPATIBILITY ================================

  pub inline fn registerComponentStore( self : *World, name : []const u8, storePtr : *anyopaque ) bool
  {
    return self.componentRegistry.register( name, storePtr );
  }

  pub inline fn unregisterComponentStore( self : *World, name : []const u8 ) bool
  {
    return self.componentRegistry.unregister( name );
  }

  pub inline fn getComponentStore( self : *World, name : []const u8 ) ?*anyopaque
  {
    return self.componentRegistry.get( name );
  }

  pub inline fn hasComponentStore( self : *World, name : []const u8 ) bool
  {
    return self.componentRegistry.has( name );
  }


  // ================================ TICK FUNCTIONS ================================

  pub inline fn tick( self : *World, context : TickContext ) void
  {
    if( !self.isInit )
    {
      utl.qlog( .WARN, 0, @src(), "Cannot tick World : uninitialized" );
      return;
    }

    _ = context;
  }
};


test "World lifecycle resets entity creation"
{
  var world : World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect( world.createEntity().id == 1 );
  try std.testing.expect( world.createEntity().id == 2 );

  world.deinit();
  world.init( std.testing.allocator );

  try std.testing.expect( world.createEntity().id == 1 );
}

test "World compatibility registry borrows component stores"
{
  var world : World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  var dummyStore : u32 = 42;

  try std.testing.expect( world.registerComponentStore( "dummyStore", &dummyStore ));
  try std.testing.expect( world.hasComponentStore( "dummyStore" ));

  const storePtr : *u32 = @ptrCast( @alignCast( world.getComponentStore( "dummyStore" ).? ));
  try std.testing.expect( storePtr.* == dummyStore );

  try std.testing.expect( world.unregisterComponentStore( "dummyStore" ));
  try std.testing.expect( !world.hasComponentStore( "dummyStore" ));
  try std.testing.expect( dummyStore == 42 );

  try std.testing.expect( world.registerComponentStore( "dummyStore", &dummyStore ));
  try std.testing.expect( world.unregisterComponentStore( "dummyStore" ));
}
