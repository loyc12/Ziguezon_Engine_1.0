const std = @import( "std" );
const utl = @import( "utils" );

const entity  = @import( "entity.zig" );
const comp    = @import( "components/component.zig" );
const compMgr = @import( "components/compManager.zig" );
const rel     = @import( "relations/relation.zig" );
const relMgr  = @import( "relations/relationManager.zig" );
const evt     = @import( "events/event.zig" );
const evtMgr  = @import( "events/eventManager.zig" );
const evtQue  = @import( "events/eventQueue.zig" );
const view    = @import( "views/view.zig" );

const Entity               = entity.Entity;
const EntityId             = entity.EntityId;
const EntityIdRegistry     = entity.EntityIdRegistry;
const CompManager          = compMgr.CompManager;
const CompStoreFactory     = comp.CompStoreFactory;
const RelationManager      = relMgr.RelationManager;
const RelationStoreFactory = rel.RelationStoreFactory;
const EventManager         = evtMgr.EventManager;
const EventQueueFactory    = evtQue.EventQueueFactory;
const Duration             = utl.Duration;


/// Timing snapshot passed to World once per consumed engine base tick.
/// Systems should use this as the simulation-time boundary, not wall-clock time.
pub const TickInfo = struct
{
  baseTickIndex : u128     = 0,
  targetDelta   : Duration = .{},
  measuredDelta : Duration = .{},
  isForced      : bool     = false,
};


/// Central simulation database for entity identity and World-owned facts.
/// Games create entities here, register typed fact stores, then add/query
/// components, relations, and events through this API.
pub const World = struct
{
  activeEntities   : std.AutoHashMap( EntityId, void ) = undefined,
  entityIdRegistry : EntityIdRegistry = .{},
  compManager      : CompManager      = .{},
  relationManager  : RelationManager  = .{},
  eventManager     : EventManager     = .{},
  viewGeneration   : u64              = 0,

  isInit : bool = false,


  // ================================ LIFECYCLE FUNCTIONS ================================

  /// Initializes entity tracking and all fact managers.
  /// Must be called before creating entities or registering stores.
  pub fn init( self : *World, alloc : std.mem.Allocator ) void
  {
    if( self.isInit )
    {
      utl.qlog( .WARN, @src(), "World is already initialized : returning" );
      return;
    }

    self.entityIdRegistry.reinit();
    self.initFactManagers( alloc );
    self.activeEntities = .init( alloc );
    self.isInit = true;
    self.bumpViewGeneration();
  }

  /// Releases all World-owned stores and invalidates existing entity ids.
  /// Component/relation/event pointers obtained from this World become stale.
  pub fn deinit( self : *World ) void
  {
    if( !self.isInit )
    {
      utl.qlog( .WARN, @src(), "World is uninitialized : returning" );
      return;
    }

    self.deinitFactManagers();
    self.activeEntities.deinit();
    self.entityIdRegistry.reinit();
    self.isInit = false;
    self.bumpViewGeneration();
  }


  // ================================ ENTITY FUNCTIONS ================================

  /// Creates a live entity id.
  /// The returned entity has no components or relations until added explicitly.
  pub inline fn createEntity( self : *World ) Entity
  {
    if( !self.isInit )
    {
      utl.qlog( .WARN, @src(), "Cannot create Entity : World is uninitialized" );
      return .{};
    }

    const entityVal = self.entityIdRegistry.getNewEntity();
    self.activeEntities.put( entityVal.id, {} ) catch
    {
      utl.log( .ERROR, @src(), "Failed to mark Entity {d} alive", .{ entityVal.id });
      return .{};
    };

    self.emitRegisteredEvent( evt.EntityCreated, .{ .entityId = entityVal.id });
    return entityVal;
  }

  /// Returns true only for ids created by this initialized World and not destroyed.
  pub inline fn isEntityAlive( self : *const World, entityId : EntityId ) bool
  {
    if( entityId == 0 ){ return false; }
    if( !self.isInit ){ return false; }

    return self.activeEntities.contains( entityId );
  }

  /// Destroys a live entity and removes its relation/component facts.
  /// Relation cleanup runs before component cleanup so dangling endpoints vanish first.
  pub fn destroyEntity( self : *World, entityId : EntityId ) bool
  {
    if( !self.isInit )
    {
      utl.qlog( .WARN, @src(), "Cannot destroy Entity : World is uninitialized" );
      return false;
    }
    if( entityId == 0 )
    {
      utl.qlog( .DEBUG, @src(), "Cannot destroy Entity 0" );
      return false;
    }
    if( !self.isEntityAlive( entityId ))
    {
      utl.log( .DEBUG, @src(), "Cannot destroy Entity {d} : Entity is not alive", .{ entityId });
      return false;
    }

    if( !self.cleanupEntityFacts( entityId )){ return false; }

    _ = self.activeEntities.remove( entityId );
    self.emitRegisteredEvent( evt.EntityDestroyed, .{ .entityId = entityId });
    return true;
  }


  // ================================ OWNED COMPONENT FUNCTIONS ================================

  /// Registers storage for one component payload type.
  /// Call before `addComp`; duplicate registrations return false.
  pub inline fn registerComp( self : *World, comptime CompType : type ) bool
  {
    if( !self.compManager.register( CompType )){ return false; }

    self.bumpViewGeneration();
    return true;
  }

  /// Removes storage for a component type and invalidates matching component pointers/views.
  pub inline fn unregisterComp( self : *World, comptime CompType : type ) bool
  {
    if( !self.compManager.unregister( CompType )){ return false; }

    self.bumpViewGeneration();
    return true;
  }

  /// Returns the typed component store, or null if the type is unregistered.
  pub inline fn getCompStore( self : *World, comptime CompType : type ) ?*CompStoreFactory( CompType )
  {
    return self.compManager.getStore( CompType );
  }

  /// Builds a transient typed view over multiple registered component stores.
  /// Views cache store pointers; check `isStillValid` after register/unregister calls.
  pub inline fn getCompView( self : *World, comptime CompTypes : anytype ) ?view.CompView( CompTypes )
  {
    return view.CompView( CompTypes ).init( self );
  }

  /// Returns the generation used to detect stale component views.
  pub inline fn getCompViewGeneration( self : *const World ) u64
  {
    return self.viewGeneration;
  }

  /// Adds one component row to a live entity.
  /// Fails if the entity is dead, the store is unregistered, or the row exists.
  pub inline fn addComp( self : *World, comptime CompType : type, entityId : EntityId, value : CompType ) bool
  {
    if( !self.isEntityAlive( entityId )){ return false; }

    const store = self.getCompStore( CompType ) orelse return false;
    if( !store.add( entityId, value )){ return false; }

    self.emitRegisteredEvent( evt.ComponentAdded, .{ .entityId = entityId, .compTypeName = @typeName( CompType )});
    return true;
  }

  /// Returns a mutable component pointer for a live entity, or null.
  /// The pointer is invalidated by component removal, store unregister, or World deinit.
  pub inline fn getComp( self : *World, comptime CompType : type, entityId : EntityId ) ?*CompType
  {
    if( !self.isEntityAlive( entityId )){ return null; }

    const store = self.getCompStore( CompType ) orelse return null;
    return store.get( entityId );
  }

  /// Tests whether a live entity currently has a component row of this type.
  pub inline fn hasComp( self : *World, comptime CompType : type, entityId : EntityId ) bool
  {
    if( !self.isEntityAlive( entityId )){ return false; }

    const store = self.getCompStore( CompType ) orelse return false;
    return store.has( entityId );
  }

  /// Removes a component row from a live entity.
  pub inline fn removeComp( self : *World, comptime CompType : type, entityId : EntityId ) bool
  {
    if( !self.isEntityAlive( entityId )){ return false; }

    const store = self.getCompStore( CompType ) orelse return false;
    if( !store.remove( entityId )){ return false; }

    self.emitRegisteredEvent( evt.ComponentRemoved, .{ .entityId = entityId, .compTypeName = @typeName( CompType )});
    return true;
  }


  // ================================ OWNED RELATION FUNCTIONS ================================

  /// Registers storage for one source-target relation fact type.
  pub inline fn registerRelation( self : *World, comptime RelType : type ) bool
  {
    return self.relationManager.register( RelType );
  }

  /// Removes storage for a relation type and invalidates relation pointers/iterators.
  pub inline fn unregisterRelation( self : *World, comptime RelType : type ) bool
  {
    return self.relationManager.unregister( RelType );
  }

  /// Returns the typed relation store, or null if the type is unregistered.
  pub inline fn getRelationStore( self : *World, comptime RelType : type ) ?*RelationStoreFactory( RelType )
  {
    return self.relationManager.getStore( RelType );
  }

  /// Adds a source -> target relation fact between two live entities.
  /// Fails if either endpoint is dead or the relation policy rejects the row.
  pub inline fn addRelation( self : *World, comptime RelType : type, sourceId : EntityId, targetId : EntityId, value : RelType ) bool
  {
    if( !self.areEntitiesAlive( sourceId, targetId )){ return false; }

    const store = self.getRelationStore( RelType ) orelse return false;

    if( !store.add( sourceId, targetId, value )){ return false; }

    self.emitRegisteredEvent( evt.RelationAdded, .{ .sourceId = sourceId, .targetId = targetId, .relationTypeName = @typeName( RelType )});
    return true;
  }

  /// Returns a mutable payload pointer for a source-target relation.
  /// Dataless relation facts must use `hasRelation` instead.
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

  /// Tests whether a source-target relation fact exists.
  /// This is the correct lookup API for dataless relation facts.
  pub inline fn hasRelation( self : *World, comptime RelType : type, sourceId : EntityId, targetId : EntityId ) bool
  {
    if( !self.areEntitiesAlive( sourceId, targetId )){ return false; }

    const store = self.getRelationStore( RelType ) orelse return false;
    return store.has( sourceId, targetId );
  }

  /// Removes a source-target relation fact.
  pub inline fn removeRelation( self : *World, comptime RelType : type, sourceId : EntityId, targetId : EntityId ) bool
  {
    if( !self.areEntitiesAlive( sourceId, targetId )){ return false; }

    const store = self.getRelationStore( RelType ) orelse return false;
    if( !store.remove( sourceId, targetId )){ return false; }

    self.emitRegisteredEvent( evt.RelationRemoved, .{ .sourceId = sourceId, .targetId = targetId, .relationTypeName = @typeName( RelType )});
    return true;
  }


  // ================================ OWNED EVENT FUNCTIONS ================================

  /// Registers a transient queue for one event fact type.
  /// Events of this type cannot be emitted or popped until registered.
  pub inline fn registerEvent( self : *World, comptime EventType : type ) bool
  {
    return self.eventManager.register( EventType );
  }

  /// Removes the queue for an event type and drops any queued records.
  pub inline fn unregisterEvent( self : *World, comptime EventType : type ) bool
  {
    return self.eventManager.unregister( EventType );
  }

  /// Returns the typed event queue for direct inspection or advanced draining.
  pub inline fn getEventQueue( self : *World, comptime EventType : type ) ?*EventQueueFactory( EventType )
  {
    return self.eventManager.getQueue( EventType );
  }

  /// Appends a typed event record with World-level metadata.
  /// Events record completed changes; use commands for requested future changes.
  pub inline fn emitEvent( self : *World, comptime EventType : type, value : EventType ) bool
  {
    if( !self.isInit )
    {
      utl.log( .WARN, @src(), "Cannot emit Event for type {s} : World is uninitialized", .{ @typeName( EventType )});
      return false;
    }

    return self.eventManager.emit( EventType, value );
  }

  /// Pops the oldest queued event record of this type.
  /// Returns null when the event type is unregistered or the queue is empty.
  pub inline fn popEvent( self : *World, comptime EventType : type ) ?evt.EventRecord( EventType )
  {
    return self.eventManager.pop( EventType );
  }

  /// Clears queued records for one event type without unregistering it.
  pub inline fn clearEvents( self : *World, comptime EventType : type ) bool
  {
    return self.eventManager.clear( EventType );
  }

  /// Returns the number of queued records for one event type.
  pub inline fn getEventCount( self : *World, comptime EventType : type ) usize
  {
    return self.eventManager.count( EventType );
  }


  // ================================ TICK FUNCTIONS ================================

  /// Advances World-owned per-tick bookkeeping.
  /// Currently this establishes event tick metadata; future systems should hook here.
  pub inline fn tick( self : *World, info : TickInfo ) void
  {
    if( !self.isInit )
    {
      utl.qlog( .WARN, @src(), "Cannot tick World : uninitialized" );
      return;
    }

    self.eventManager.beginTick( info.baseTickIndex );
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
    self.eventManager.init( alloc );
  }

  inline fn deinitFactManagers( self : *World ) void
  {
    self.eventManager.deinit();
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
      utl.log( .ERROR, @src(), "Failed to clean up Entity {d} from {d} RelationStores", .{ entityId, relationCleanup.failedCount });
      return false;
    }

    const compCleanup = self.compManager.removeEntity( entityId );
    if( !compCleanup.isSuccess() )
    {
      utl.log( .ERROR, @src(), "Failed to clean up Entity {d} from {d} CompStores", .{ entityId, compCleanup.failedCount });
      return false;
    }

    return true;
  }

  inline fn emitRegisteredEvent( self : *World, comptime EventType : type, value : EventType ) void
  {
    if( !self.eventManager.hasQueue( EventType )){ return; }
    _ = self.eventManager.emit( EventType, value );
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

test "World owns typed event queue API and registration lifecycle"
{
  const TestEvent = struct
  {
    entityId : EntityId = 0,
    value    : u32      = 0,
  };

  var world : World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect(  world.registerEvent( TestEvent ));
  try std.testing.expect( !world.registerEvent( TestEvent ));
  try std.testing.expect(  world.getEventQueue( TestEvent ) != null );

  world.tick( .{ .baseTickIndex = 9 });

  try std.testing.expect( world.emitEvent( TestEvent, .{ .entityId = 1, .value = 42 }));
  try std.testing.expect( world.getEventCount( TestEvent ) == 1 );

  const record = world.popEvent( TestEvent ).?;
  try std.testing.expect( record.value.value          == 42 );
  try std.testing.expect( record.meta.sequence        == 0  );
  try std.testing.expect( record.meta.tickOrder       == 0  );
  try std.testing.expect( record.meta.baseTickIndex.? == 9  );
  try std.testing.expect( record.meta.primaryEntity.? == 1  );
  try std.testing.expect( world.popEvent( TestEvent ) == null );

  try std.testing.expect( world.emitEvent( TestEvent, .{ .entityId = 2, .value = 11 }));
  try std.testing.expect( world.clearEvents( TestEvent ));
  try std.testing.expect( world.getEventCount( TestEvent ) == 0 );

  try std.testing.expect( world.unregisterEvent( TestEvent ));
  try std.testing.expect( world.getEventQueue(   TestEvent ) == null );
}

test "World event API rejects uninitialized worlds and unregistered queues"
{
  const TestEvent = struct
  {
    value : u32 = 0,
  };

  var world : World = .{};

  try std.testing.expect( !world.registerEvent( TestEvent ));
  try std.testing.expect( !world.emitEvent( TestEvent, .{ .value = 1 }));
  try std.testing.expect(  world.popEvent( TestEvent ) == null );
  try std.testing.expect( !world.clearEvents( TestEvent ));

  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect( !world.emitEvent( TestEvent, .{ .value = 2 }));
  try std.testing.expect(  world.popEvent( TestEvent ) == null );
  try std.testing.expect( !world.clearEvents( TestEvent ));
}

test "World emits registered generic entity component and relation events"
{
  const TestComp = struct
  {
    pub const compStorePolicy : comp.CompStorePolicy = .SPARSE;

    value : u32 = 0,
  };
  const TestRel = struct
  {
    value : u32 = 0,
  };

  var world : World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect( world.registerEvent( evt.EntityCreated    ));
  try std.testing.expect( world.registerEvent( evt.EntityDestroyed  ));
  try std.testing.expect( world.registerEvent( evt.ComponentAdded   ));
  try std.testing.expect( world.registerEvent( evt.ComponentRemoved ));
  try std.testing.expect( world.registerEvent( evt.RelationAdded    ));
  try std.testing.expect( world.registerEvent( evt.RelationRemoved  ));

  world.tick( .{ .baseTickIndex = 14 });

  const sourceId = world.createEntity().id;
  const targetId = world.createEntity().id;

  try std.testing.expect( world.registerComp( TestComp ));
  try std.testing.expect( world.addComp(    TestComp, sourceId, .{ .value = 1 }));
  try std.testing.expect( world.removeComp( TestComp, sourceId ));

  try std.testing.expect( world.registerRelation( TestRel ));
  try std.testing.expect( world.addRelation(    TestRel, sourceId, targetId, .{ .value = 2 }));
  try std.testing.expect( world.removeRelation( TestRel, sourceId, targetId ));
  try std.testing.expect( world.destroyEntity( sourceId ));

  const createdA = world.popEvent( evt.EntityCreated ).?;
  const createdB = world.popEvent( evt.EntityCreated ).?;
  const compAdd  = world.popEvent( evt.ComponentAdded ).?;
  const compRem  = world.popEvent( evt.ComponentRemoved ).?;
  const relAdd   = world.popEvent( evt.RelationAdded ).?;
  const relRem   = world.popEvent( evt.RelationRemoved ).?;
  const destroyed = world.popEvent( evt.EntityDestroyed ).?;

  try std.testing.expect( createdA.value.entityId == sourceId );
  try std.testing.expect( createdB.value.entityId == targetId );
  try std.testing.expect( compAdd.value.entityId  == sourceId );
  try std.testing.expect( compRem.value.entityId  == sourceId );
  try std.testing.expect( relAdd.value.sourceId   == sourceId );
  try std.testing.expect( relAdd.value.targetId   == targetId );
  try std.testing.expect( relRem.value.sourceId   == sourceId );
  try std.testing.expect( destroyed.value.entityId == sourceId );

  try std.testing.expect( createdA.meta.sequence       == 0  );
  try std.testing.expect( createdB.meta.sequence       == 1  );
  try std.testing.expect( compAdd.meta.sequence        == 2  );
  try std.testing.expect( compRem.meta.sequence        == 3  );
  try std.testing.expect( relAdd.meta.sequence         == 4  );
  try std.testing.expect( relRem.meta.sequence         == 5  );
  try std.testing.expect( destroyed.meta.sequence      == 6  );
  try std.testing.expect( destroyed.meta.baseTickIndex.? == 14 );
}

test "World deinit releases registered owned event queues"
{
  const TestEvent = struct
  {
    value : u32 = 0,
  };

  var world : World = .{};
  world.init( std.testing.allocator );

  try std.testing.expect( world.registerEvent( TestEvent ));
  try std.testing.expect( world.emitEvent( TestEvent, .{ .value = 1 }));

  world.deinit();
  try std.testing.expect( !world.eventManager.isInit );
}
