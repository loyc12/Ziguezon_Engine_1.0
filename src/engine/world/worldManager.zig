const std = @import( "std" );
const utl = @import( "utils" );

const entity  = @import( "entity.zig" );
const comp    = @import( "components/component.zig" );
const compMgr = @import( "components/compManager.zig" );
const rel     = @import( "relations/relation.zig" );
const relMgr  = @import( "relations/relationManager.zig" );
const view    = @import( "views/view.zig" );

const Entity               = entity.Entity;
const EntityId             = entity.EntityId;
const EntityIdRegistry     = entity.EntityIdRegistry;
const CompManager          = compMgr.CompManager;
const CompStoreFactory     = comp.CompStoreFactory;
const RelationManager      = relMgr.RelationManager;
const RelationStoreFactory = rel.RelationStoreFactory;
const Duration             = utl.Duration;


pub const TickInfo = struct
{
  baseTickIndex : u128     = 0,
  targetDelta   : Duration = .{},
  measuredDelta : Duration = .{},
  isForced      : bool     = false,
};


pub const World = struct
{
  entityIdRegistry : EntityIdRegistry = .{},
  compManager      : CompManager      = .{},
  relationManager  : RelationManager  = .{},
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
    self.initFactManagers( alloc );
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

    self.deinitFactManagers();
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

    if( !self.cleanupEntityFacts( entityId )){ return false; }

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


  // ================================ OWNED RELATION FUNCTIONS ================================

  pub inline fn registerRelation( self : *World, comptime RelType : type ) bool
  {
    return self.relationManager.register( RelType );
  }

  pub inline fn unregisterRelation( self : *World, comptime RelType : type ) bool
  {
    return self.relationManager.unregister( RelType );
  }

  pub inline fn getRelationStore( self : *World, comptime RelType : type ) ?*RelationStoreFactory( RelType )
  {
    return self.relationManager.getStore( RelType );
  }

  pub inline fn addRelation( self : *World, comptime RelType : type, sourceId : EntityId, targetId : EntityId, value : RelType ) bool
  {
    if( !self.areEntitiesAlive( sourceId, targetId )){ return false; }

    const store = self.getRelationStore( RelType ) orelse return false;
    return store.add( sourceId, targetId, value );
  }

  pub inline fn getRelation( self : *World, comptime RelType : type, sourceId : EntityId, targetId : EntityId ) ?*RelType
  {
    if( rel.isDatalessRelation( RelType ))
    {
      @compileError( "Relation type " ++ @typeName( RelType ) ++ " has zero size. Use hasRelation on dataless relation facts instead of getRelation." );
    }

    if( !self.areEntitiesAlive( sourceId, targetId )){ return null; }

    const store = self.getRelationStore( RelType ) orelse return null;
    return store.get( sourceId, targetId );
  }

  pub inline fn hasRelation( self : *World, comptime RelType : type, sourceId : EntityId, targetId : EntityId ) bool
  {
    if( !self.areEntitiesAlive( sourceId, targetId )){ return false; }

    const store = self.getRelationStore( RelType ) orelse return false;
    return store.has( sourceId, targetId );
  }

  pub inline fn removeRelation( self : *World, comptime RelType : type, sourceId : EntityId, targetId : EntityId ) bool
  {
    if( !self.areEntitiesAlive( sourceId, targetId )){ return false; }

    const store = self.getRelationStore( RelType ) orelse return false;
    return store.remove( sourceId, targetId );
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

  inline fn initFactManagers( self : *World, alloc : std.mem.Allocator ) void
  {
    self.compManager.init( alloc );
    self.relationManager.init( alloc );
  }

  inline fn deinitFactManagers( self : *World ) void
  {
    self.relationManager.deinit();
    self.compManager.deinit();
  }

  inline fn areEntitiesAlive( self : *const World, sourceId : EntityId, targetId : EntityId ) bool
  {
    return self.isEntityAlive( sourceId ) and self.isEntityAlive( targetId );
  }

  fn cleanupEntityFacts( self : *World, entityId : EntityId ) bool
  {
    const relationCleanup = self.relationManager.removeEntity( entityId );
    if( !relationCleanup.isSuccess() )
    {
      utl.log( .ERROR, 0, @src(), "Failed to clean up Entity {d} from {d} RelationStores", .{ entityId, relationCleanup.failedCount });
      return false;
    }

    const compCleanup = self.compManager.removeEntity( entityId );
    if( !compCleanup.isSuccess() )
    {
      utl.log( .ERROR, 0, @src(), "Failed to clean up Entity {d} from {d} CompStores", .{ entityId, compCleanup.failedCount });
      return false;
    }

    return true;
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
    pub const compStorePolicy : comp.CompStorePolicy = .SPARSE;

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
    pub const compStorePolicy : comp.CompStorePolicy = .SPARSE;

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

test "World destroyEntity removes packed and sparse components"
{
  const SparseComp = struct
  {
    pub const compStorePolicy : comp.CompStorePolicy = .SPARSE;

    value : u32 = 0,
  };
  const PackedComp = struct
  {
    pub const compStorePolicy : comp.CompStorePolicy = .PACKED;

    value : u32 = 0,
  };

  var world : World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect( world.registerComp( SparseComp ));
  try std.testing.expect( world.registerComp( PackedComp  ));

  const entityId = world.createEntity().id;
  try std.testing.expect( world.addComp( SparseComp, entityId, .{ .value = 10 }));
  try std.testing.expect( world.addComp( PackedComp,  entityId, .{ .value = 20 }));

  const sparseStore = world.getCompStore( SparseComp ).?;
  const packedStore  = world.getCompStore( PackedComp  ).?;

  try std.testing.expect(  world.destroyEntity( entityId ));
  try std.testing.expect( !world.isEntityAlive( entityId ));
  try std.testing.expect( !sparseStore.has( entityId ));
  try std.testing.expect( !packedStore.has(  entityId ));
  try std.testing.expect(  world.getComp( SparseComp, entityId ) == null );
  try std.testing.expect( !world.hasComp( PackedComp, entityId ));
}

test "World destroyEntity succeeds without components and preserves other entities"
{
  const TestComp = struct
  {
    pub const compStorePolicy : comp.CompStorePolicy = .PACKED;

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
    pub const compStorePolicy : comp.CompStorePolicy = .SPARSE;

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

test "World owns typed relation CRUD and registration lifecycle"
{
  const TestRel = struct
  {
    value : u32 = 0,
  };

  var world : World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect(  world.registerRelation( TestRel ));
  try std.testing.expect( !world.registerRelation( TestRel ));
  try std.testing.expect(  world.getRelationStore( TestRel ) != null );

  const sourceId = world.createEntity().id;
  const targetId = world.createEntity().id;

  try std.testing.expect(  world.addRelation(    TestRel, sourceId, targetId, .{ .value = 42 }));
  try std.testing.expect(  world.hasRelation(    TestRel, sourceId, targetId ));
  try std.testing.expect(  world.getRelation(    TestRel, sourceId, targetId ).?.value == 42 );
  try std.testing.expect(  world.removeRelation( TestRel, sourceId, targetId ));
  try std.testing.expect( !world.hasRelation(    TestRel, sourceId, targetId ));
  try std.testing.expect(  world.getRelation(    TestRel, sourceId, targetId ) == null );

  try std.testing.expect( world.unregisterRelation( TestRel ));
  try std.testing.expect( world.getRelationStore(   TestRel ) == null );
  try std.testing.expect( world.registerRelation(   TestRel ));
}

test "World supports dataless relation facts through hasRelation"
{
  var world : World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect( world.registerRelation( rel.LinkedTo ));

  const sourceId = world.createEntity().id;
  const targetId = world.createEntity().id;

  try std.testing.expect(  world.addRelation( rel.LinkedTo, sourceId, targetId, .{} ));
  try std.testing.expect(  world.hasRelation( rel.LinkedTo, sourceId, targetId ));
  try std.testing.expect( !world.hasRelation( rel.LinkedTo, targetId, sourceId ));
}

test "World deinit releases registered owned relation stores"
{
  const TestRel = struct
  {
    value : u32 = 0,
  };

  var world : World = .{};
  world.init( std.testing.allocator );

  try std.testing.expect( world.registerRelation( TestRel ));

  const sourceId = world.createEntity().id;
  const targetId = world.createEntity().id;
  try std.testing.expect( world.addRelation( TestRel, sourceId, targetId, .{ .value = 42 }));

  world.deinit();
  try std.testing.expect( !world.relationManager.isInit );
}

test "World relation API rejects invalid endpoints and unregistered stores"
{
  const TestRel = struct
  {
    value : u32 = 0,
  };

  var world : World = .{};

  try std.testing.expect( !world.registerRelation( TestRel ));
  try std.testing.expect( !world.addRelation(    TestRel, 1, 2, .{ .value = 1 }));
  try std.testing.expect(  world.getRelation(    TestRel, 1, 2 ) == null );
  try std.testing.expect( !world.hasRelation(    TestRel, 1, 2 ));
  try std.testing.expect( !world.removeRelation( TestRel, 1, 2 ));

  world.init( std.testing.allocator );
  defer world.deinit();

  const sourceId = world.createEntity().id;
  const targetId = world.createEntity().id;

  try std.testing.expect( !world.addRelation(    TestRel, sourceId, targetId, .{ .value = 2 }));
  try std.testing.expect(  world.getRelation(    TestRel, sourceId, targetId ) == null );
  try std.testing.expect( !world.hasRelation(    TestRel, sourceId, targetId ));
  try std.testing.expect( !world.removeRelation( TestRel, sourceId, targetId ));

  try std.testing.expect( world.registerRelation( TestRel ));

  try std.testing.expect( !world.addRelation(    TestRel, 0,        targetId, .{ .value = 3 }));
  try std.testing.expect( !world.addRelation(    TestRel, sourceId, 0,        .{ .value = 3 }));
  try std.testing.expect( !world.addRelation(    TestRel, 99,       targetId, .{ .value = 3 }));
  try std.testing.expect( !world.addRelation(    TestRel, sourceId, 99,       .{ .value = 3 }));
  try std.testing.expect(  world.getRelation(    TestRel, sourceId, 99 ) == null );
  try std.testing.expect( !world.hasRelation(    TestRel, 99,       targetId ));
  try std.testing.expect( !world.removeRelation( TestRel, sourceId, 99 ));

  try std.testing.expect(  world.addRelation( TestRel, sourceId, targetId, .{ .value = 4 }));
  try std.testing.expect(  world.destroyEntity( targetId ));

  try std.testing.expect( !world.addRelation(    TestRel, sourceId, targetId, .{ .value = 5 }));
  try std.testing.expect(  world.getRelation(    TestRel, sourceId, targetId ) == null );
  try std.testing.expect( !world.hasRelation(    TestRel, sourceId, targetId ));
  try std.testing.expect( !world.removeRelation( TestRel, sourceId, targetId ));
}

test "World destroyEntity removes source and target relation rows"
{
  const TestRel = struct
  {
    value : u32 = 0,
  };

  var world : World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect( world.registerRelation( TestRel ));

  const destroyedId = world.createEntity().id;
  const targetId    = world.createEntity().id;
  const sourceId    = world.createEntity().id;
  const keptAId     = world.createEntity().id;
  const keptBId     = world.createEntity().id;

  try std.testing.expect( world.addRelation( TestRel, destroyedId, targetId,    .{ .value = 10 }));
  try std.testing.expect( world.addRelation( TestRel, sourceId,    destroyedId, .{ .value = 20 }));
  try std.testing.expect( world.addRelation( TestRel, keptAId,     keptBId,     .{ .value = 30 }));

  const store = world.getRelationStore( TestRel ).?;

  try std.testing.expect( world.destroyEntity( destroyedId ));
  try std.testing.expect( !world.isEntityAlive( destroyedId ));
  try std.testing.expect( !store.has( destroyedId, targetId    ));
  try std.testing.expect( !store.has( sourceId,    destroyedId ));
  try std.testing.expect(  store.has( keptAId,     keptBId     ));
  try std.testing.expect(  world.hasRelation( TestRel, keptAId, keptBId ));
}
