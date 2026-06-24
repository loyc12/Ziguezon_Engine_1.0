const std = @import( "std" );

const entity   = @import( "../entity.zig" );
const comp     = @import( "../components/component.zig" );
const evt      = @import( "../events/event.zig" );
const evtQue   = @import( "../events/eventQueue.zig" );
const rel      = @import( "../relations/relation.zig" );
const trt      = @import( "../traits/trait.zig" );
const worldCore = @import( "../core/world.zig" );

const EntityId = entity.EntityId;
const World    = worldCore.World;


// Query helpers provide read-only access to World-owned fact stores.
// They never cache mutable fact state, retain event history, or replace CompView's
// narrow component fast path.

/// Stateless helper namespace for inspecting World-owned facts.
/// Callers pass the inspected World explicitly for every query.
pub const WorldQuery = struct
{
  // ================================ ENTITY FUNCTIONS ================================

  /// Returns true only when the entity id is live in this World.
  pub inline fn hasEntity( world : *const World, entityId : EntityId ) bool
  {
    return world.isEntityAlive( entityId );
  }


  // ================================ COMPONENT FUNCTIONS ================================

  /// Tests whether a live entity has a registered component row.
  pub inline fn hasComp( world : *World, comptime CompType : type, entityId : EntityId ) bool
  {
    return world.hasComp( CompType, entityId );
  }

  /// Returns a read-only component pointer for a live entity, or null.
  pub inline fn getComp( world : *World, comptime CompType : type, entityId : EntityId ) ?*const CompType
  {
    return world.getCompConst( CompType, entityId );
  }

  /// Checks whether a cached component view still matches the World's store generation.
  pub inline fn isCompViewValid( world : *const World, view : anytype ) bool
  {
    return view.isStillValid( world );
  }

  /// Tests a component row through an already-built CompView after validating generation.
  pub inline fn hasCompInView( world : *const World, view : anytype, comptime CompType : type, entityId : EntityId ) bool
  {
    if( !WorldQuery.hasEntity( world, entityId )){ return false; }
    if( !view.isStillValid( world )){ return false; }

    return view.has( CompType, entityId );
  }

  /// Returns a read-only component pointer from a CompView after validating generation.
  pub inline fn getCompFromView( world : *const World, view : anytype, comptime CompType : type, entityId : EntityId ) ?*const CompType
  {
    if( !WorldQuery.hasEntity( world, entityId )){ return null; }
    if( !view.isStillValid( world )){ return null; }

    return view.getConst( CompType, entityId );
  }


  // ================================ RELATION FUNCTIONS ================================

  /// Tests whether a live source-target relation fact exists.
  /// This covers dataless relations as well as payload-bearing relations.
  pub inline fn hasRelation( world : *World, comptime RelType : type, sourceId : EntityId, targetId : EntityId ) bool
  {
    return world.hasRelation( RelType, sourceId, targetId );
  }

  /// Returns a read-only payload pointer for a live source-target relation, or null.
  /// Dataless relation facts must use `hasRelation`.
  pub inline fn getRelation( world : *World, comptime RelType : type, sourceId : EntityId, targetId : EntityId ) ?*const RelType
  {
    return world.getRelationConst( RelType, sourceId, targetId );
  }

  /// Iterates relation rows with this live source endpoint.
  pub inline fn getRelationsFrom( world : *World, comptime RelType : type, sourceId : EntityId ) ?rel.RelationStoreFactory( RelType ).ConstIterator
  {
    return world.getRelationsFrom( RelType, sourceId );
  }

  /// Iterates relation rows with this live target endpoint.
  pub inline fn getRelationsTo( world : *World, comptime RelType : type, targetId : EntityId ) ?rel.RelationStoreFactory( RelType ).ConstIterator
  {
    return world.getRelationsTo( RelType, targetId );
  }


  // ================================ TRAIT FUNCTIONS ================================

  /// Tests whether a live entity has a registered trait.
  pub inline fn hasTrait( world : *World, comptime TraitType : type, entityId : EntityId ) bool
  {
    return world.hasTrait( TraitType, entityId );
  }

  /// Iterates entity ids that currently have this trait.
  pub inline fn getTraitEntityIterator( world : *World, comptime TraitType : type ) ?trt.TraitSetFactory( TraitType ).EntityIterator
  {
    return world.getTraitEntityIterator( TraitType );
  }


  // ================================ EVENT FUNCTIONS ================================

  /// Returns the number of queued transient records for one event type.
  pub inline fn getEventCount( world : *World, comptime EventType : type ) usize
  {
    return world.getEventCount( EventType );
  }

  /// Returns a read-only queued event record without popping it.
  pub inline fn peekEvent( world : *World, comptime EventType : type, index : usize ) ?*const evt.EventRecord( EventType )
  {
    return world.peekEvent( EventType, index );
  }

  /// Iterates queued event records without popping them.
  pub inline fn getEventIterator( world : *World, comptime EventType : type ) ?evtQue.EventQueueFactory( EventType ).ConstIterator
  {
    return world.getEventIterator( EventType );
  }


  // ================================ UNSUPPORTED SHAPES ================================

  /// Rejects broad query shapes that this first slice deliberately does not support.
  /// Add concrete helpers instead of routing calls through this placeholder.
  pub fn rejectUnsupportedBroadQuery( comptime shape : []const u8 ) void
  {
    @compileError( "Unsupported WorldQuery shape for this slice: " ++ shape );
  }
};


// ================================ TESTS ================================

test "WorldQuery rejects uninitialized worlds and missing stores"
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
  const TestTrait = struct {};
  const TestEvent = struct
  {
    value : u32 = 0,
  };

  var world : World = .{};

  world.init( std.testing.allocator );
  defer world.deinit();

  const entityId = world.createEntity().id;

  try std.testing.expect( !WorldQuery.hasComp( &world, TestComp, entityId ));
  try std.testing.expect(  WorldQuery.getComp( &world, TestComp, entityId ) == null );

  try std.testing.expect( !WorldQuery.hasRelation(      &world, TestRel, entityId, entityId ));
  try std.testing.expect(  WorldQuery.getRelationsFrom( &world, TestRel, entityId ) == null );
  try std.testing.expect(  WorldQuery.getRelationsTo(   &world, TestRel, entityId ) == null );

  try std.testing.expect( !WorldQuery.hasTrait( &world, TestTrait, entityId ));
  try std.testing.expect(  WorldQuery.getTraitEntityIterator( &world, TestTrait ) == null );

  try std.testing.expect(  WorldQuery.getEventCount(    &world, TestEvent    ) == 0 );
  try std.testing.expect(  WorldQuery.peekEvent(        &world, TestEvent, 0 ) == null );
  try std.testing.expect(  WorldQuery.getEventIterator( &world, TestEvent    ) == null );
}

test "WorldQuery rejects dead entities and stale component views"
{
  const TransComp = struct
  {
    pub const compStorePolicy : comp.CompStorePolicy = .PACKED;

    value : u32 = 0,
  };
  const FlagComp = struct
  {
    pub const compStorePolicy : comp.CompStorePolicy = .SPARSE;

    value : bool = true,
  };

  var world : World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect( world.registerComp( TransComp ));

  const entityId = world.createEntity().id;
  try std.testing.expect( world.addComp( TransComp, entityId, .{ .value = 42 }));

  var view = world.getCompView( .{ TransComp }).?;

  try std.testing.expect(  WorldQuery.isCompViewValid( &world, &view ));
  try std.testing.expect(  WorldQuery.hasCompInView( &world, &view, TransComp, entityId ));
  try std.testing.expect(  WorldQuery.getCompFromView( &world, &view, TransComp, entityId ).?.value == 42 );

  try std.testing.expect( world.registerComp( FlagComp ));

  try std.testing.expect( !WorldQuery.isCompViewValid( &world, &view ));
  try std.testing.expect( !WorldQuery.hasCompInView( &world, &view, TransComp, entityId ));
  try std.testing.expect(  WorldQuery.getCompFromView( &world, &view, TransComp, entityId ) == null );

  try std.testing.expect( world.destroyEntity( entityId ));
  try std.testing.expect( !WorldQuery.hasEntity( &world, entityId ));
  try std.testing.expect( !WorldQuery.hasComp(   &world, TransComp, entityId ));
  try std.testing.expect(  WorldQuery.getComp(   &world, TransComp, entityId ) == null );
}

test "WorldQuery inspects events without popping records"
{
  const TestEvent = struct
  {
    entityId : EntityId = 0,
    value    : u32      = 0,
  };

  var world : World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect( world.registerEvent( TestEvent ));
  try std.testing.expect( world.emitEvent( TestEvent, .{ .entityId = 1, .value = 10 }));
  try std.testing.expect( world.emitEvent( TestEvent, .{ .entityId = 2, .value = 20 }));

  try std.testing.expect( WorldQuery.getEventCount( &world, TestEvent ) == 2 );
  try std.testing.expect( WorldQuery.peekEvent(     &world, TestEvent, 0 ).?.value.value == 10 );
  try std.testing.expect( WorldQuery.peekEvent(     &world, TestEvent, 1 ).?.value.value == 20 );

  var count : usize = 0;
  var sum   : u32   = 0;
  var iter = WorldQuery.getEventIterator( &world, TestEvent ).?;
  while( iter.next() )| record |
  {
    count += 1;
    sum   += record.value.value;
  }

  try std.testing.expect( count == 2 );
  try std.testing.expect( sum   == 30 );
  try std.testing.expect( world.getEventCount( TestEvent ) == 2 );
  try std.testing.expect( world.popEvent( TestEvent ).?.value.value == 10 );
}

test "WorldQuery traverses traits without mutable set access"
{
  const Selectable = struct {};

  var world : World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect( world.registerTrait( Selectable ));

  const entityA = world.createEntity().id;
  const entityB = world.createEntity().id;
  const entityC = world.createEntity().id;

  try std.testing.expect( world.applyTrait( Selectable, entityA ));
  try std.testing.expect( world.applyTrait( Selectable, entityC ));

  try std.testing.expect(  WorldQuery.hasTrait( &world, Selectable, entityA ));
  try std.testing.expect( !WorldQuery.hasTrait( &world, Selectable, entityB ));

  var count : usize = 0;
  var seenA = false;
  var seenC = false;
  var iter = WorldQuery.getTraitEntityIterator( &world, Selectable ).?;
  while( iter.next() )| entityId |
  {
    count += 1;
    if( entityId == entityA ){ seenA = true; }
    if( entityId == entityC ){ seenC = true; }
  }

  try std.testing.expect( count == 2 );
  try std.testing.expect( seenA );
  try std.testing.expect( seenC );
}

test "WorldQuery relation traversal preserves source target indexes"
{
  const TestRel = struct
  {
    pub const cardinalityPolicy : rel.RelationLimitPolicy = .ONE_TO_MANY;

    value : u32 = 0,
  };

  var world : World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect( world.registerRelation( TestRel ));

  const sourceA = world.createEntity().id;
  const sourceB = world.createEntity().id;
  const targetA = world.createEntity().id;
  const targetB = world.createEntity().id;
  const targetC = world.createEntity().id;

  try std.testing.expect(  world.addRelation( TestRel, sourceA, targetA, .{ .value = 10 }));
  try std.testing.expect(  world.addRelation( TestRel, sourceA, targetB, .{ .value = 20 }));
  try std.testing.expect(  world.addRelation( TestRel, sourceB, targetC, .{ .value = 30 }));
  try std.testing.expect( !world.addRelation( TestRel, sourceB, targetA, .{ .value = 40 }));

  var sourceCount : usize = 0;
  var sourceSum   : u32   = 0;
  var srcIter = WorldQuery.getRelationsFrom( &world, TestRel, sourceA ).?;
  while( srcIter.next() )| entry |
  {
    sourceCount += 1;
    sourceSum   += entry.value_ptr.?.value;
    try std.testing.expect( entry.key.sourceId == sourceA );
  }

  var targetCount : usize = 0;
  var tgtIter = WorldQuery.getRelationsTo( &world, TestRel, targetA ).?;
  while( tgtIter.next() )| entry |
  {
    targetCount += 1;
    try std.testing.expect( entry.key.targetId == targetA );
  }

  try std.testing.expect( sourceCount == 2 );
  try std.testing.expect( sourceSum   == 30 );
  try std.testing.expect( targetCount == 1 );
  try std.testing.expect( WorldQuery.getRelation( &world, TestRel, sourceA, targetA ).?.value == 10 );

  try std.testing.expect( world.destroyEntity( targetA ));
  try std.testing.expect( !WorldQuery.hasRelation( &world, TestRel, sourceA, targetA ));
  try std.testing.expect(  WorldQuery.getRelation( &world, TestRel, sourceA, targetA ) == null );
}
