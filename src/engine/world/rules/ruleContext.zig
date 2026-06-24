const std = @import( "std" );

const entity  = @import( "../entity.zig" );
const comp    = @import( "../components/component.zig" );
const compMgr = @import( "../components/compManager.zig" );
const rel     = @import( "../relations/relation.zig" );
const relMgr  = @import( "../relations/relationManager.zig" );
const trt     = @import( "../traits/trait.zig" );
const trtMgr  = @import( "../traits/traitManager.zig" );
const evt     = @import( "../events/event.zig" );
const evtQue  = @import( "../events/eventQueue.zig" );
const evtMgr  = @import( "../events/eventManager.zig" );
const cmdMgr  = @import( "../commands/commandManager.zig" );

const EntityId        = entity.EntityId;
const CompManager     = compMgr.CompManager;
const RelationManager = relMgr.RelationManager;
const TraitManager    = trtMgr.TraitManager;
const EventManager    = evtMgr.EventManager;
const CommandManager  = cmdMgr.CommandManager;


/// Rule-only view over World-owned managers for one explicit rule pass.
/// This context is manager-pointer-backed to prevent dependency loops between
/// `World` and `RuleManager`. Future non-rule contexts should duplicate and
/// tailor this shape instead of broadening `RuleContext` for unrelated work.
pub const RuleContext = struct
{
  activeEntities  : *const std.AutoHashMap( EntityId, void ),
  compManager     : *CompManager,
  relationManager : *RelationManager,
  traitManager    : *TraitManager,
  eventManager    : *EventManager,
  commandManager  : *CommandManager,


  // ================================ ENTITY FUNCTIONS ================================

  /// Returns true only when the entity id is live in the owning World.
  pub inline fn hasEntity( self : *const RuleContext, entityId : EntityId ) bool
  {
    if( entityId == 0 ){ return false; }
    return self.activeEntities.contains( entityId );
  }


  // ================================ COMPONENT FUNCTIONS ================================

  /// Tests whether a live entity has a registered component row.
  pub inline fn hasComp( self : *RuleContext, comptime CompType : type, entityId : EntityId ) bool
  {
    if( !self.hasEntity( entityId )){ return false; }

    const store = self.compManager.getStore( CompType ) orelse return false;
    return store.has( entityId );
  }

  /// Returns a read-only component pointer for a live entity, or null.
  pub inline fn getComp( self : *RuleContext, comptime CompType : type, entityId : EntityId ) ?*const CompType
  {
    if( !self.hasEntity( entityId )){ return null; }

    const store = self.compManager.getStore( CompType ) orelse return null;
    return store.getConst( entityId );
  }


  // ================================ RELATION FUNCTIONS ================================

  /// Tests whether a live source-target relation fact exists.
  pub inline fn hasRelation( self : *RuleContext, comptime RelType : type, sourceId : EntityId, targetId : EntityId ) bool
  {
    if( !self.areEntitiesAlive( sourceId, targetId )){ return false; }

    const store = self.relationManager.getStore( RelType ) orelse return false;
    return store.has( sourceId, targetId );
  }

  /// Returns a read-only payload pointer for a live source-target relation, or null.
  /// Dataless relation facts must use `hasRelation`.
  pub inline fn getRelation( self : *RuleContext, comptime RelType : type, sourceId : EntityId, targetId : EntityId ) ?*const RelType
  {
    if( rel.isDatalessRelation( RelType ))
    {
      @compileError( "Relation type " ++ @typeName( RelType ) ++ " has zero size. Use hasRelation on dataless relation facts instead of getRelation." );
    }

    if( !self.areEntitiesAlive( sourceId, targetId )){ return null; }

    const store = self.relationManager.getStore( RelType ) orelse return null;
    return store.getConst( sourceId, targetId );
  }

  /// Iterates relation rows with this live source endpoint.
  pub inline fn getRelationsFrom( self : *RuleContext, comptime RelType : type, sourceId : EntityId ) ?rel.RelationStoreFactory( RelType ).ConstIterator
  {
    if( !self.hasEntity( sourceId )){ return null; }

    const store = self.relationManager.getStore( RelType ) orelse return null;
    return store.getConstRelToSource( sourceId );
  }

  /// Iterates relation rows with this live target endpoint.
  pub inline fn getRelationsTo( self : *RuleContext, comptime RelType : type, targetId : EntityId ) ?rel.RelationStoreFactory( RelType ).ConstIterator
  {
    if( !self.hasEntity( targetId )){ return null; }

    const store = self.relationManager.getStore( RelType ) orelse return null;
    return store.getConstRelToTarget( targetId );
  }


  // ================================ TRAIT FUNCTIONS ================================

  /// Tests whether a live entity has a registered trait.
  pub inline fn hasTrait( self : *RuleContext, comptime TraitType : type, entityId : EntityId ) bool
  {
    if( !self.hasEntity( entityId )){ return false; }

    const set = self.traitManager.getSet( TraitType ) orelse return false;
    return set.has( entityId );
  }

  /// Iterates entity ids that currently have this trait.
  pub inline fn getTraitEntityIterator( self : *RuleContext, comptime TraitType : type ) ?trt.TraitSetFactory( TraitType ).EntityIterator
  {
    const set = self.traitManager.getSet( TraitType ) orelse return null;
    return set.getEntityIterator();
  }


  // ================================ EVENT FUNCTIONS ================================

  /// Returns the number of queued transient records for one event type.
  pub inline fn getEventCount( self : *RuleContext, comptime EventType : type ) usize
  {
    return self.eventManager.getEventCount( EventType );
  }

  /// Returns a read-only queued event record without popping it.
  pub inline fn peekEvent( self : *RuleContext, comptime EventType : type, index : usize ) ?*const evt.EventRecord( EventType )
  {
    const queue = self.eventManager.getQueue( EventType ) orelse return null;
    return queue.peek( index );
  }

  /// Iterates queued event records without popping them.
  pub inline fn getEventIterator( self : *RuleContext, comptime EventType : type ) ?evtQue.EventQueueFactory( EventType ).ConstIterator
  {
    const queue = self.eventManager.getQueue( EventType ) orelse return null;
    return queue.getIteratorConst();
  }


  // ================================ COMMAND FUNCTIONS ================================

  /// Enqueues one requested-change fact through the active command surface.
  pub inline fn enqueueCommand( self : *RuleContext, comptime CommandType : type, value : CommandType ) bool
  {
    return self.commandManager.enqueue( CommandType, value );
  }


  // ================================ INTERNAL FUNCTIONS ================================

  inline fn areEntitiesAlive( self : *const RuleContext, sourceId : EntityId, targetId : EntityId ) bool
  {
    return self.hasEntity( sourceId ) and self.hasEntity( targetId );
  }
};


// ================================ TESTS ================================

test "RuleContext observes events and emits commands without consuming events"
{
  const TestEvent = struct
  {
    value : u32 = 0,
  };
  const TestCommand = struct
  {
    value : u32 = 0,
  };

  var activeEntities : std.AutoHashMap( EntityId, void ) = .init( std.testing.allocator );
  defer activeEntities.deinit();

  var comps : CompManager = .{};
  comps.init( std.testing.allocator );
  defer comps.deinit();

  var relations : RelationManager = .{};
  relations.init( std.testing.allocator );
  defer relations.deinit();

  var traits : TraitManager = .{};
  traits.init( std.testing.allocator );
  defer traits.deinit();

  var events : EventManager = .{};
  events.init( std.testing.allocator );
  defer events.deinit();

  var commands : CommandManager = .{};
  commands.init( std.testing.allocator );
  defer commands.deinit();

  try std.testing.expect( events.register(   TestEvent   ));
  try std.testing.expect( commands.register( TestCommand ));
  try std.testing.expect( events.emit( TestEvent, .{ .value = 41 }));

  var context : RuleContext =
  .{
    .activeEntities  = &activeEntities,
    .compManager     = &comps,
    .relationManager = &relations,
    .traitManager    = &traits,
    .eventManager    = &events,
    .commandManager  = &commands,
  };

  const eventRecord = context.peekEvent( TestEvent, 0 ) orelse return error.TestExpectedEqual;
  try std.testing.expect( context.enqueueCommand( TestCommand, .{ .value = eventRecord.value.value + 1 }));
  try std.testing.expect( context.getEventCount( TestEvent ) == 1 );
  try std.testing.expect( commands.pop( TestCommand ).?.value.value == 42 );
}

test "RuleContext reads current facts through manager-backed helpers"
{
  const TestComp = struct
  {
    pub const compStorePolicy : comp.CompStorePolicy = .SPARSE;

    value : u32 = 0,
  };
  const TestTrait = struct {};

  var activeEntities : std.AutoHashMap( EntityId, void ) = .init( std.testing.allocator );
  defer activeEntities.deinit();

  var comps : CompManager = .{};
  comps.init( std.testing.allocator );
  defer comps.deinit();

  var relations : RelationManager = .{};
  relations.init( std.testing.allocator );
  defer relations.deinit();

  var traits : TraitManager = .{};
  traits.init( std.testing.allocator );
  defer traits.deinit();

  var events : EventManager = .{};
  events.init( std.testing.allocator );
  defer events.deinit();

  var commands : CommandManager = .{};
  commands.init( std.testing.allocator );
  defer commands.deinit();

  const entityId : EntityId = 1;

  try activeEntities.put( entityId, {} );
  try std.testing.expect( comps.register(  TestComp  ));
  try std.testing.expect( traits.register( TestTrait ));
  try std.testing.expect( comps.getStore(  TestComp  ).?.add( entityId, .{ .value = 41 }));
  try std.testing.expect( traits.getSet(   TestTrait ).?.apply( entityId ));

  var context : RuleContext =
  .{
    .activeEntities  = &activeEntities,
    .compManager     = &comps,
    .relationManager = &relations,
    .traitManager    = &traits,
    .eventManager    = &events,
    .commandManager  = &commands,
  };

  try std.testing.expect(  context.hasEntity( entityId ));
  try std.testing.expect(  context.hasComp(   TestComp,  entityId ));
  try std.testing.expect(  context.getComp(   TestComp,  entityId ).?.value == 41 );
  try std.testing.expect(  context.hasTrait(  TestTrait, entityId ));

  _ = activeEntities.remove( entityId );

  try std.testing.expect( !context.hasEntity( entityId ));
  try std.testing.expect( !context.hasComp(   TestComp,  entityId ));
  try std.testing.expect(  context.getComp(   TestComp,  entityId ) == null );
  try std.testing.expect( !context.hasTrait(  TestTrait, entityId ));
}
