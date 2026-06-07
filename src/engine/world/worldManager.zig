const std = @import( "std" );
const utl = @import( "utils" );

const entity  = @import( "entity.zig" );
const comp    = @import( "components/component.zig" );
const compMgr = @import( "components/compManager.zig" );
const view    = @import( "views/view.zig" );

const Entity               = entity.Entity;
const EntityId             = entity.EntityId;
const EntityIdRegistry     = entity.EntityIdRegistry;
const CompManager          = compMgr.CompManager;
const CompStoreFactory     = comp.CompStoreFactory;
const Duration             = utl.Duration;


pub const TickInfo = struct
{
  baseTickIndex : u128    = 0,
  targetDelta   : Duration = .{},
  measuredDelta : Duration = .{},
  isForced      : bool    = false,
};


pub const World = struct
{
  entityIdRegistry : EntityIdRegistry = .{},
  compManager      : CompManager      = .{},
  activeEntities   : std.AutoHashMap( EntityId, void ) = undefined,
  viewGeneration   : u64              = 0,

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
    self.compManager.init( alloc );
    self.activeEntities = .init( alloc );
    self.isInit = true;
    self.bumpViewGeneration();
  }

  pub fn deinit( self : *World ) void
  {
    if( !self.isInit )
    {
      utl.qlog( .WARN, 0, @src(), "World is uninitialized : returning" );
      return;
    }

    self.compManager.deinit();
    self.activeEntities.deinit();
    self.entityIdRegistry.reinit();
    self.isInit = false;
    self.bumpViewGeneration();
  }


  // ================================ ENTITY FUNCTIONS ================================

  pub inline fn createEntity( self : *World ) Entity
  {
    if( !self.isInit )
    {
      utl.qlog( .WARN, 0, @src(), "Cannot create Entity : World is uninitialized" );
      return .{};
    }

    const entityVal = self.entityIdRegistry.getNewEntity();
    self.activeEntities.put( entityVal.id, {} ) catch
    {
      utl.log( .ERROR, 0, @src(), "Failed to mark Entity {d} alive", .{ entityVal.id });
      return .{};
    };

    return entityVal;
  }

  pub inline fn isEntityAlive( self : *const World, entityId : EntityId ) bool
  {
    if( entityId == 0 ){ return false; }
    if( !self.isInit ){ return false; }

    return self.activeEntities.contains( entityId );
  }

  pub fn destroyEntity( self : *World, entityId : EntityId ) bool
  {
    if( !self.isInit )
    {
      utl.qlog( .WARN, 0, @src(), "Cannot destroy Entity : World is uninitialized" );
      return false;
    }
    if( entityId == 0 )
    {
      utl.qlog( .DEBUG, 0, @src(), "Cannot destroy Entity 0" );
      return false;
    }
    if( !self.isEntityAlive( entityId ))
    {
      utl.log( .DEBUG, 0, @src(), "Cannot destroy Entity {d} : Entity is not alive", .{ entityId });
      return false;
    }

    const cleanup = self.compManager.removeEntity( entityId );
    if( !cleanup.isSuccess() )
    {
      utl.log( .ERROR, 0, @src(), "Failed to clean up Entity {d} from {d} CompStores", .{ entityId, cleanup.failedCount });
      return false;
    }

    _ = self.activeEntities.remove( entityId );
    return true;
  }


  // ================================ OWNED COMPONENT FUNCTIONS ================================

  pub inline fn registerComp( self : *World, comptime CompType : type ) bool
  {
    if( !self.compManager.register( CompType )){ return false; }

    self.bumpViewGeneration();
    return true;
  }

  pub inline fn unregisterComp( self : *World, comptime CompType : type ) bool
  {
    if( !self.compManager.unregister( CompType )){ return false; }

    self.bumpViewGeneration();
    return true;
  }

  pub inline fn getCompStore( self : *World, comptime CompType : type ) ?*CompStoreFactory( CompType )
  {
    return self.compManager.getStore( CompType );
  }

  pub inline fn getCompView( self : *World, comptime CompTypes : anytype ) ?view.CompView( CompTypes )
  {
    return view.CompView( CompTypes ).init( self );
  }

  pub inline fn getCompViewGeneration( self : *const World ) u64
  {
    return self.viewGeneration;
  }

  pub inline fn addComp( self : *World, comptime CompType : type, entityId : EntityId, value : CompType ) bool
  {
    if( !self.isEntityAlive( entityId )){ return false; }

    const store = self.getCompStore( CompType ) orelse return false;
    return store.add( entityId, value );
  }

  pub inline fn getComp( self : *World, comptime CompType : type, entityId : EntityId ) ?*CompType
  {
    if( !self.isEntityAlive( entityId )){ return null; }

    const store = self.getCompStore( CompType ) orelse return null;
    return store.get( entityId );
  }

  pub inline fn hasComp( self : *World, comptime CompType : type, entityId : EntityId ) bool
  {
    if( !self.isEntityAlive( entityId )){ return false; }

    const store = self.getCompStore( CompType ) orelse return false;
    return store.has( entityId );
  }

  pub inline fn removeComp( self : *World, comptime CompType : type, entityId : EntityId ) bool
  {
    if( !self.isEntityAlive( entityId )){ return false; }

    const store = self.getCompStore( CompType ) orelse return false;
    return store.remove( entityId );
  }

  // ================================ TICK FUNCTIONS ================================

  pub inline fn tick( self : *World, info : TickInfo ) void
  {
    if( !self.isInit )
    {
      utl.qlog( .WARN, 0, @src(), "Cannot tick World : uninitialized" );
      return;
    }

    _ = info;
  }


  // ================================ INTERNAL FUNCTIONS ================================

  inline fn bumpViewGeneration( self : *World ) void
  {
    self.viewGeneration +%= 1;
  }
};



// ================================ TESTS ================================

test "World lifecycle resets entity creation"
{
  var world : World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  const entityA = world.createEntity();
  const entityB = world.createEntity();

  try std.testing.expect( entityA.id == 1 );
  try std.testing.expect( entityB.id == 2 );
  try std.testing.expect( world.isEntityAlive( entityA.id ));
  try std.testing.expect( world.isEntityAlive( entityB.id ));

  world.deinit();
  world.init( std.testing.allocator );

  try std.testing.expect( !world.isEntityAlive( entityA.id ));
  try std.testing.expect( world.createEntity().id == 1 );
  try std.testing.expect( !world.isEntityAlive( 0 ));
}

test "World owns typed component CRUD and registration lifecycle"
{
  const TestComp = struct
  {
    pub const storeType : comp.CompStorePolicy = .SPARSE;

    value : u32 = 0,
  };

  var world : World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect(  world.registerComp( TestComp ));
  try std.testing.expect( !world.registerComp( TestComp ));
  try std.testing.expect(  world.getCompStore( TestComp ) != null );
  try std.testing.expect( !world.addComp( TestComp, 0, .{ .value = 1 }));

  const entityId = world.createEntity().id;

  try std.testing.expect(  world.addComp(    TestComp, entityId, .{ .value = 42 }));
  try std.testing.expect(  world.hasComp(    TestComp, entityId ));
  try std.testing.expect(  world.getComp(    TestComp, entityId ).?.value == 42 );
  try std.testing.expect(  world.removeComp( TestComp, entityId ));
  try std.testing.expect( !world.hasComp(    TestComp, entityId ));
  try std.testing.expect(  world.getComp(    TestComp, entityId ) == null );

  try std.testing.expect( world.unregisterComp( TestComp ));
  try std.testing.expect( world.getCompStore(   TestComp ) == null );
  try std.testing.expect( world.registerComp(   TestComp ));
}

test "World deinit releases registered owned component stores"
{
  const TestComp = struct
  {
    pub const storeType : comp.CompStorePolicy = .SPARSE;

    value : u32 = 0,
  };

  var world : World = .{};
  world.init( std.testing.allocator );

  try std.testing.expect( world.registerComp( TestComp ));
  try std.testing.expect( world.addComp( TestComp, world.createEntity().id, .{ .value = 42 }));

  world.deinit();
  try std.testing.expect( !world.compManager.isInit );
}

test "World rejects invalid entity destruction"
{
  var world : World = .{};

  try std.testing.expect( !world.destroyEntity( 1 ));

  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect( !world.destroyEntity( 0 ));
  try std.testing.expect( !world.destroyEntity( 99 ));

  const entityId = world.createEntity().id;
  try std.testing.expect(  world.destroyEntity( entityId ));
  try std.testing.expect( !world.destroyEntity( entityId ));
  try std.testing.expect( !world.isEntityAlive( entityId ));
}

test "World destroyEntity removes dense and sparse components"
{
  const SparseComp = struct
  {
    pub const storeType : comp.CompStorePolicy = .SPARSE;

    value : u32 = 0,
  };
  const DenseComp = struct
  {
    pub const storeType : comp.CompStorePolicy = .DENSE;

    value : u32 = 0,
  };

  var world : World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect( world.registerComp( SparseComp ));
  try std.testing.expect( world.registerComp( DenseComp  ));

  const entityId = world.createEntity().id;
  try std.testing.expect( world.addComp( SparseComp, entityId, .{ .value = 10 }));
  try std.testing.expect( world.addComp( DenseComp,  entityId, .{ .value = 20 }));

  const sparseStore = world.getCompStore( SparseComp ).?;
  const denseStore  = world.getCompStore( DenseComp  ).?;

  try std.testing.expect(  world.destroyEntity( entityId ));
  try std.testing.expect( !world.isEntityAlive( entityId ));
  try std.testing.expect( !sparseStore.has( entityId ));
  try std.testing.expect( !denseStore.has(  entityId ));
  try std.testing.expect(  world.getComp( SparseComp, entityId ) == null );
  try std.testing.expect( !world.hasComp( DenseComp, entityId ));
}

test "World destroyEntity succeeds without components and preserves other entities"
{
  const TestComp = struct
  {
    pub const storeType : comp.CompStorePolicy = .DENSE;

    value : u32 = 0,
  };

  var world : World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect( world.registerComp( TestComp ));

  const emptyId = world.createEntity().id;
  const keptId  = world.createEntity().id;

  try std.testing.expect( world.addComp( TestComp, keptId, .{ .value = 42 }));
  try std.testing.expect( world.destroyEntity( emptyId ));

  try std.testing.expect( !world.isEntityAlive( emptyId ));
  try std.testing.expect(  world.isEntityAlive( keptId  ));
  try std.testing.expect(  world.hasComp( TestComp, keptId ));
  try std.testing.expect(  world.getComp( TestComp, keptId ).?.value == 42 );
}

test "World component API rejects dead and never-created entities"
{
  const TestComp = struct
  {
    pub const storeType : comp.CompStorePolicy = .SPARSE;

    value : u32 = 0,
  };

  var world : World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect( world.registerComp( TestComp ));

  const entityId = world.createEntity().id;
  try std.testing.expect(  world.addComp( TestComp, entityId, .{ .value = 42 }));
  try std.testing.expect(  world.destroyEntity( entityId ));

  try std.testing.expect( !world.addComp(    TestComp, entityId, .{ .value = 99 }));
  try std.testing.expect(  world.getComp(    TestComp, entityId ) == null );
  try std.testing.expect( !world.hasComp(    TestComp, entityId ));
  try std.testing.expect( !world.removeComp( TestComp, entityId ));

  try std.testing.expect( !world.addComp(    TestComp, 99, .{ .value = 99 }));
  try std.testing.expect(  world.getComp(    TestComp, 99 ) == null );
  try std.testing.expect( !world.hasComp(    TestComp, 99 ));
  try std.testing.expect( !world.removeComp( TestComp, 99 ));
}
