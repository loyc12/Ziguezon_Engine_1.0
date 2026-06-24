const std = @import( "std" );
const utl = @import( "utils" );

const entity  = @import( "../entity.zig" );
const comp    = @import( "../components/component.zig" );
const compMgr = @import( "../components/compManager.zig" );
const rel     = @import( "../relations/relation.zig" );
const relMgr  = @import( "../relations/relationManager.zig" );
const trt     = @import( "../traits/trait.zig" );
const trtMgr  = @import( "../traits/traitManager.zig" );
const evt     = @import( "../events/event.zig" );
const evtMgr  = @import( "../events/eventManager.zig" );
const evtQue  = @import( "../events/eventQueue.zig" );
const cmd     = @import( "../commands/command.zig" );
const cmdMgr  = @import( "../commands/commandManager.zig" );
const cmdQue  = @import( "../commands/commandQueue.zig" );
const rule    = @import( "../rules/rule.zig" );
const ruleCtx = @import( "../rules/ruleContext.zig" );
const ruleMgr = @import( "../rules/ruleManager.zig" );
const view    = @import( "../views/view.zig" );
const arch    = @import( "../archetypes/archetype.zig" );
const archMgr = @import( "../archetypes/archetypeManager.zig" );
const archCtx = @import( "../archetypes/spawnContext.zig" );

const Entity               = entity.Entity;
const EntityId             = entity.EntityId;
const EntityIdRegistry     = entity.EntityIdRegistry;
const CompManager          = compMgr.CompManager;
const CompStoreFactory     = comp.CompStoreFactory;
const RelationManager      = relMgr.RelationManager;
const RelationStoreFactory = rel.RelationStoreFactory;
const TraitManager         = trtMgr.TraitManager;
const TraitSetFactory      = trt.TraitSetFactory;
const EventManager         = evtMgr.EventManager;
const EventQueueFactory    = evtQue.EventQueueFactory;
const CommandManager       = cmdMgr.CommandManager;
const CommandQueueFactory  = cmdQue.CommandQueueFactory;
const Rule                 = rule.Rule;
const RuleContext          = ruleCtx.RuleContext;
const RuleManager          = ruleMgr.RuleManager;
const ArchetypeSpawnResult = arch.ArchetypeSpawnResult;
const Duration             = utl.Duration;


/// Timing snapshot passed to World once per consumed engine base tick.
/// Scheduler / rules should use this as the simulation-time boundary, not wall-clock time.
pub const TickInfo = struct
{
  baseTickIndex : u128     = 0,
  targetDelta   : Duration = .{},
  measuredDelta : Duration = .{},
  isForced      : bool     = false,
};


pub const Archetype             = arch.ArchetypeFactory( ArchetypeSpawnContext );
pub const ArchetypeManager      = archMgr.ArchetypeManagerFactory( Archetype );
pub const ArchetypeSpawnContext = archCtx.ArchetypeSpawnContextFactory( World );


/// Central simulation database for entity identity and World-owned facts.
/// Games create entities here, register typed fact stores, then add/query
/// components, relations, traits, and events through this API.
pub const World = struct
{
  activeEntities   : std.AutoHashMap( EntityId, void ) = undefined, // NTOE : Should this be stored in the registry ( or at all ) ?
  entityIdRegistry : EntityIdRegistry = .{},
  compManager      : CompManager      = .{},
  relationManager  : RelationManager  = .{},
  traitManager     : TraitManager     = .{},
  eventManager     : EventManager     = .{},
  commandManager   : CommandManager   = .{},
  ruleManager      : RuleManager      = .{},
  archetypeManager : ArchetypeManager = .{},
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
  /// Component/relation/trait/event pointers obtained from this World become stale.
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
  /// The returned entity has no components, relations, or traits until added explicitly.
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

  /// Destroys a live entity and removes its relation/component/trait facts.
  /// Fact cleanup finishes before the entity id is invalidated.
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
  /// Views cachgetCompViewGenck `isStillValid` after register/unregister calls.
  pub inline fn getCompView( self : *World, comptime CompTypes : anytype ) ?view.CompView( CompTypes )
  {
    return view.CompView( CompTypes ).init( self );
  }

  /// Returns the generation used to detect stale component views.
  pub inline fn getCompViewGen( self : *const World ) u64
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

  /// Returns a read-only component pointer for a live entity, or null.
  /// Query helpers use this path so inspection code cannot mutate component rows.
  pub inline fn getCompConst( self : *World, comptime CompType : type, entityId : EntityId ) ?*const CompType
  {
    if( !self.isEntityAlive( entityId )){ return null; }

    const store = self.getCompStore( CompType ) orelse return null;
    return store.getConst( entityId );
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

  /// Returns a read-only payload pointer for a source-target relation.
  /// Dataless relation facts must use `hasRelation` instead.
  pub inline fn getRelationConst( self : *World, comptime RelType : type, sourceId : EntityId, targetId : EntityId ) ?*const RelType
  {
    if( rel.isDatalessRelation( RelType ))
    {
      @compileError( "Relation type " ++ @typeName( RelType ) ++ " has zero size. Use hasRelation on dataless relation facts instead of getRelation." );
    }

    if( !self.areEntitiesAlive( sourceId, targetId )){ return null; }

    const store = self.getRelationStore( RelType ) orelse return null;
    return store.getConst( sourceId, targetId );
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

  /// Iterates relation rows where `sourceId` is the source endpoint.
  /// Returns null for uninitialized Worlds, dead sources, or unregistered relation stores.
  pub inline fn getRelationsFrom( self : *World, comptime RelType : type, sourceId : EntityId ) ?rel.RelationStoreFactory( RelType ).ConstIterator
  {
    if( !self.isEntityAlive( sourceId )){ return null; }

    const store = self.getRelationStore( RelType ) orelse return null;
    return store.getConstRelToSource( sourceId );
  }

  /// Iterates relation rows where `targetId` is the target endpoint.
  /// Returns null for uninitialized Worlds, dead targets, or unregistered relation stores.
  pub inline fn getRelationsTo( self : *World, comptime RelType : type, targetId : EntityId ) ?rel.RelationStoreFactory( RelType ).ConstIterator
  {
    if( !self.isEntityAlive( targetId )){ return null; }

    const store = self.getRelationStore( RelType ) orelse return null;
    return store.getConstRelToTarget( targetId );
  }


  // ================================ OWNED TRAIT FUNCTIONS ================================

  /// Registers presence storage for one dataless trait type.
  pub inline fn registerTrait( self : *World, comptime TraitType : type ) bool
  {
    return self.traitManager.register( TraitType );
  }

  /// Removes storage for a trait type and drops all matching trait rows.
  pub inline fn unregisterTrait( self : *World, comptime TraitType : type ) bool
  {
    return self.traitManager.unregister( TraitType );
  }

  /// Returns the typed trait set, or null if the type is unregistered.
  pub inline fn getTraitSet( self : *World, comptime TraitType : type ) ?*TraitSetFactory( TraitType )
  {
    return self.traitManager.getSet( TraitType );
  }

  /// Applies one dataless classification trait to a live entity.
  /// Use components instead when the fact needs per-entity payload data.
  pub inline fn applyTrait( self : *World, comptime TraitType : type, entityId : EntityId ) bool
  {
    if( !self.isEntityAlive( entityId )){ return false; }

    const set = self.getTraitSet( TraitType ) orelse return false;
    if( !set.apply( entityId )){ return false; }

    self.emitRegisteredEvent( evt.TraitApplied, .{ .entityId = entityId, .traitTypeName = @typeName( TraitType )});
    return true;
  }

  /// Tests whether a live entity currently has a trait.
  pub inline fn hasTrait( self : *World, comptime TraitType : type, entityId : EntityId ) bool
  {
    if( !self.isEntityAlive( entityId )){ return false; }

    const set = self.getTraitSet( TraitType ) orelse return false;
    return set.has( entityId );
  }

  /// Removes one dataless classification trait from a live entity.
  pub inline fn removeTrait( self : *World, comptime TraitType : type, entityId : EntityId ) bool
  {
    if( !self.isEntityAlive( entityId )){ return false; }

    const set = self.getTraitSet( TraitType ) orelse return false;
    if( !set.remove( entityId )){ return false; }

    self.emitRegisteredEvent( evt.TraitRemoved, .{ .entityId = entityId, .traitTypeName = @typeName( TraitType )});
    return true;
  }

  /// Iterates live entity ids that currently have a trait.
  /// Returns null when the World or trait set is unavailable.
  pub inline fn getTraitEntityIterator( self : *World, comptime TraitType : type ) ?trt.TraitSetFactory( TraitType ).EntityIterator
  {
    if( !self.isInit ){ return null; }

    const set = self.getTraitSet( TraitType ) orelse return null;
    return set.getEntityIterator();
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

  /// Returns a read-only queued event record by queue index without popping it.
  pub inline fn peekEvent( self : *World, comptime EventType : type, index : usize ) ?*const evt.EventRecord( EventType )
  {
    if( !self.isInit ){ return null; }

    const queue = self.getEventQueue( EventType ) orelse return null;
    return queue.peek( index );
  }

  /// Iterates queued event records without popping them.
  /// The returned iterator is transient and becomes stale when the queue changes.
  pub inline fn getEventIterator( self : *World, comptime EventType : type ) ?evtQue.EventQueueFactory( EventType ).ConstIterator
  {
    if( !self.isInit ){ return null; }

    const queue = self.getEventQueue( EventType ) orelse return null;
    return queue.getIteratorConst();
  }

  /// Clears queued records for one event type without unregistering it.
  pub inline fn clearEvents( self : *World, comptime EventType : type ) bool
  {
    return self.eventManager.clear( EventType );
  }

  /// Returns the number of queued records for one event type.
  pub inline fn getEventCount( self : *World, comptime EventType : type ) usize
  {
    return self.eventManager.getEventCount( EventType );
  }


  // ================================ OWNED COMMAND FUNCTIONS ================================

  /// Registers a transient queue for one command fact type.
  /// Commands of this type cannot be enqueued or popped until registered.
  pub inline fn registerCommand( self : *World, comptime CommandType : type ) bool
  {
    return self.commandManager.register( CommandType );
  }

  /// Removes the queue for a command type and drops any queued command records.
  pub inline fn unregisterCommand( self : *World, comptime CommandType : type ) bool
  {
    return self.commandManager.unregister( CommandType );
  }

  /// Returns the typed command queue for direct inspection or advanced draining.
  pub inline fn getCommandQueue( self : *World, comptime CommandType : type ) ?*CommandQueueFactory( CommandType )
  {
    return self.commandManager.getQueue( CommandType );
  }

  /// Appends a typed requested-change command with World-level metadata.
  /// Commands request future changes; events record changes that already happened.
  pub inline fn enqueueCommand( self : *World, comptime CommandType : type, value : CommandType ) bool
  {
    if( !self.isInit )
    {
      utl.log( .WARN, @src(), "Cannot enqueue Command for type {s} : World is uninitialized", .{ @typeName( CommandType )});
      return false;
    }

    return self.commandManager.enqueue( CommandType, value );
  }

  /// Pops the oldest queued command record of this type.
  /// Returns null when the command type is unregistered or the queue is empty.
  pub inline fn popCommand( self : *World, comptime CommandType : type ) ?cmd.CommandRecord( CommandType )
  {
    return self.commandManager.pop( CommandType );
  }

  /// Returns a read-only queued command record by queue index without popping it.
  pub inline fn peekCommand( self : *World, comptime CommandType : type, index : usize ) ?*const cmd.CommandRecord( CommandType )
  {
    if( !self.isInit ){ return null; }

    const queue = self.getCommandQueue( CommandType ) orelse return null;
    return queue.peek( index );
  }

  /// Iterates queued command records without popping them.
  /// The returned iterator is transient and becomes stale when the queue changes.
  pub inline fn getCommandIterator( self : *World, comptime CommandType : type ) ?cmdQue.CommandQueueFactory( CommandType ).ConstIterator
  {
    if( !self.isInit ){ return null; }

    const queue = self.getCommandQueue( CommandType ) orelse return null;
    return queue.getIteratorConst();
  }

  /// Clears queued records for one command type without unregistering it.
  pub inline fn clearCommands( self : *World, comptime CommandType : type ) bool
  {
    return self.commandManager.clear( CommandType );
  }

  /// Returns the number of queued records for one command type.
  pub inline fn getCommandCount( self : *World, comptime CommandType : type ) usize
  {
    return self.commandManager.getCommandCount( CommandType );
  }


  // ================================ RULE FUNCTIONS ================================

  /// Registers one named rule for explicit rule passes.
  pub inline fn registerRule( self : *World, ruleDef : Rule ) bool
  {
    return self.ruleManager.register( ruleDef );
  }

  /// Returns true when a rule name is already registered.
  pub inline fn hasRule( self : *const World, name : []const u8 ) bool
  {
    return self.ruleManager.hasRule( name );
  }

  /// Returns the number of registered explicit rules.
  pub inline fn getRuleCount( self : *const World ) usize
  {
    return self.ruleManager.getRuleCount();
  }

  /// Packages World-owned managers into a short-lived rule-only context.
  /// This helper avoids a `World -> RuleManager -> World` dependency loop.
  /// Other context-like needs should use their own tailored conversion helpers
  /// instead of broadening `RuleContext` beyond rule execution.
  pub inline fn toRuleContext( self : *World ) RuleContext
  {
    return .{
      .activeEntities  = &self.activeEntities,
      .compManager     = &self.compManager,
      .relationManager = &self.relationManager,
      .traitManager    = &self.traitManager,
      .eventManager    = &self.eventManager,
      .commandManager  = &self.commandManager,
    };
  }

  /// Runs registered rules once in deterministic order.
  /// This is explicit for now; `World.tick(...)` does not run rules.
  pub fn applyRules( self : *World ) bool
  {
    if( !self.isInit )
    {
      utl.qlog( .WARN, @src(), "Cannot apply Rules : World is uninitialized" );
      return false;
    }

    var context = self.toRuleContext();
    return self.ruleManager.applyRules( &context );
  }


  // ================================ ARCHETYPE FUNCTIONS ================================

  /// Registers one data-only archetype declaration for name-based spawning.
  pub inline fn registerArchetype( self : *World, archetypeVal : Archetype ) bool
  {
    return self.archetypeManager.register( archetypeVal );
  }

  /// Spawns a registered archetype and returns the ids it reports.
  /// Failed spawns destroy every entity created by the archetype callback.
  pub fn spawnArchetype( self : *World, name : []const u8 ) ?ArchetypeSpawnResult
  {
    if( !self.isInit )
    {
      utl.qlog( .WARN, @src(), "Cannot spawn Archetype : World is uninitialized" );
      return null;
    }

    const archetypeVal = self.archetypeManager.get( name ) orelse
    {
      utl.log( .WARN, @src(), "Cannot spawn Archetype {s} : not registered", .{ name });
      return null;
    };

    return self.spawnArchetypeValue( archetypeVal.* );
  }

  /// Returns the number of registered archetype declarations.
  pub inline fn getArchetypeCount( self : *const World ) usize
  {
    return self.archetypeManager.getCount();
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
    self.commandManager.beginTick( info.baseTickIndex );
  }


  // ================================ INTERNAL FUNCTIONS ================================

  fn spawnArchetypeValue( self : *World, archetypeVal : Archetype ) ?ArchetypeSpawnResult
  {
    var rollbackEntityIds : std.ArrayList( EntityId ) = .empty;
    defer rollbackEntityIds.deinit( self.archetypeManager.alloc );

    var cntx : ArchetypeSpawnContext =
    .{
      .worldPtr             = self,
      .rollbackEntityIdsPtr = &rollbackEntityIds,
    };

    const didSpawn = archetypeVal.spawnFn( &cntx );
    if( !didSpawn or cntx.didFail or !self.isValidArchetypeSpawnResult( cntx.result, &rollbackEntityIds ))
    {
      self.rollbackFailedArchetypeSpawn( &rollbackEntityIds );
      return null;
    }

    return cntx.result;
  }

  fn isValidArchetypeSpawnResult( self : *World, result : ArchetypeSpawnResult, rollbackEntityIds : *const std.ArrayList( EntityId )) bool
  {
    if( result.rootId == 0 )
    {
      utl.qlog( .WARN, @src(), "Cannot complete Archetype spawn : root entity was not reported" );
      return false;
    }
    if( !self.isRollbackEntityId( rollbackEntityIds, result.rootId ))
    {
      utl.log( .WARN, @src(), "Cannot complete Archetype spawn : root Entity {d} was not created by this spawn", .{ result.rootId });
      return false;
    }

    for( result.reportedIds[ 0..result.idCount ] )| entry |
    {
      if( !self.isRollbackEntityId( rollbackEntityIds, entry.id ))
      {
        utl.log( .WARN, @src(), "Cannot complete Archetype spawn : reported Entity {d} was not created by this spawn", .{ entry.id });
        return false;
      }
    }

    return true;
  }

  inline fn isRollbackEntityId( self : *World, rollbackEntityIds : *const std.ArrayList( EntityId ), entityId : EntityId ) bool
  {
    if( !self.isEntityAlive( entityId )){ return false; }

    for( rollbackEntityIds.items )| rollbackEntityId |
    {
      if( rollbackEntityId == entityId ){ return true; }
    }

    return false;
  }

  fn rollbackFailedArchetypeSpawn( self : *World, rollbackEntityIds : *std.ArrayList( EntityId )) void
  {
    var index = rollbackEntityIds.items.len;
    while( index > 0 )
    {
      index -= 1;

      const entityId = rollbackEntityIds.items[ index ];
      if( self.isEntityAlive( entityId ))
      {
        if( !self.destroyEntity( entityId ))
        {
          utl.log( .ERROR, @src(), "Failed to clean up Archetype-created Entity {d}", .{ entityId });
        }
      }
    }
  }

  inline fn bumpViewGeneration( self : *World ) void
  {
    self.viewGeneration +%= 1;
  }

  inline fn initFactManagers( self : *World, alloc : std.mem.Allocator ) void
  {
    self.compManager.init( alloc );
    self.relationManager.init( alloc );
    self.traitManager.init( alloc );
    self.eventManager.init( alloc );
    self.commandManager.init( alloc );
    self.ruleManager.init( alloc );
    self.archetypeManager.init( alloc );
  }

  inline fn deinitFactManagers( self : *World ) void
  {
    self.archetypeManager.deinit();
    self.ruleManager.deinit();
    self.commandManager.deinit();
    self.eventManager.deinit();
    self.traitManager.deinit();
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

    const traitCleanup = self.traitManager.removeEntity( entityId );
    if( !traitCleanup.isSuccess() )
    {
      utl.log( .ERROR, @src(), "Failed to clean up Entity {d} from {d} TraitSets", .{ entityId, traitCleanup.failedCount });
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

test "World owns typed trait CRUD and registration lifecycle"
{
  const Selectable = struct {};

  var world : World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect(  world.registerTrait( Selectable ));
  try std.testing.expect( !world.registerTrait( Selectable ));
  try std.testing.expect(  world.getTraitSet( Selectable ) != null );

  const entityId = world.createEntity().id;

  try std.testing.expect(  world.applyTrait(  Selectable, entityId ));
  try std.testing.expect(  world.hasTrait(    Selectable, entityId ));
  try std.testing.expect( !world.applyTrait(  Selectable, entityId ));
  try std.testing.expect(  world.removeTrait( Selectable, entityId ));
  try std.testing.expect( !world.hasTrait(    Selectable, entityId ));

  try std.testing.expect( world.unregisterTrait( Selectable ));
  try std.testing.expect( world.getTraitSet(   Selectable ) == null );
  try std.testing.expect( world.registerTrait(   Selectable ));
}

test "World deinit releases registered owned trait sets"
{
  const Selectable = struct {};

  var world : World = .{};
  world.init( std.testing.allocator );

  try std.testing.expect( world.registerTrait( Selectable ));
  try std.testing.expect( world.applyTrait( Selectable, world.createEntity().id ));

  world.deinit();
  try std.testing.expect( !world.traitManager.isInit );
}

test "World trait API rejects dead and unregistered entities"
{
  const Selectable = struct {};

  var world : World = .{};

  try std.testing.expect( !world.registerTrait( Selectable ));
  try std.testing.expect( !world.applyTrait(    Selectable, 1 ));
  try std.testing.expect( !world.hasTrait(      Selectable, 1 ));
  try std.testing.expect( !world.removeTrait(   Selectable, 1 ));

  world.init( std.testing.allocator );
  defer world.deinit();

  const entityId = world.createEntity().id;

  try std.testing.expect( !world.applyTrait(  Selectable, entityId ));
  try std.testing.expect( !world.hasTrait(    Selectable, entityId ));
  try std.testing.expect( !world.removeTrait( Selectable, entityId ));

  try std.testing.expect( world.registerTrait( Selectable ));

  try std.testing.expect( !world.applyTrait(  Selectable, 0  ));
  try std.testing.expect( !world.applyTrait(  Selectable, 99 ));
  try std.testing.expect( !world.hasTrait(    Selectable, 99 ));
  try std.testing.expect( !world.removeTrait( Selectable, 99 ));

  try std.testing.expect(  world.applyTrait( Selectable, entityId ));
  try std.testing.expect(  world.destroyEntity( entityId ));
  try std.testing.expect( !world.applyTrait(  Selectable, entityId ));
  try std.testing.expect( !world.hasTrait(    Selectable, entityId ));
  try std.testing.expect( !world.removeTrait( Selectable, entityId ));
}

test "World destroyEntity removes component relation and trait facts together"
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
  const Selectable = struct {};

  var world : World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect( world.registerComp(     TestComp   ));
  try std.testing.expect( world.registerRelation( TestRel    ));
  try std.testing.expect( world.registerTrait(    Selectable ));

  const destroyedId = world.createEntity().id;
  const targetId    = world.createEntity().id;
  const sourceId    = world.createEntity().id;
  const keptId      = world.createEntity().id;

  try std.testing.expect( world.addComp( TestComp, destroyedId, .{ .value = 10 }));
  try std.testing.expect( world.addComp( TestComp, keptId,      .{ .value = 20 }));
  try std.testing.expect( world.addRelation( TestRel, destroyedId, targetId,    .{ .value = 30 }));
  try std.testing.expect( world.addRelation( TestRel, sourceId,    destroyedId, .{ .value = 40 }));
  try std.testing.expect( world.applyTrait( Selectable, destroyedId ));
  try std.testing.expect( world.applyTrait( Selectable, keptId      ));

  const compStore = world.getCompStore(     TestComp   ).?;
  const relStore  = world.getRelationStore( TestRel    ).?;
  const traitSet  = world.getTraitSet(      Selectable ).?;

  try std.testing.expect( world.destroyEntity( destroyedId ));

  try std.testing.expect( !world.isEntityAlive( destroyedId ));
  try std.testing.expect( !compStore.has( destroyedId ));
  try std.testing.expect( !relStore.has( destroyedId, targetId    ));
  try std.testing.expect( !relStore.has( sourceId,    destroyedId ));
  try std.testing.expect( !traitSet.has( destroyedId ));

  try std.testing.expect(  world.isEntityAlive( keptId ));
  try std.testing.expect(  compStore.has( keptId ));
  try std.testing.expect(  traitSet.has(  keptId ));
}

test "World archetype registration rejects duplicates and uninitialized use"
{
  const TestArch = struct
  {
    const archetype : Archetype =
    .{
      .name    = "test.registration",
      .spawnFn = spawn,
    };

    fn spawn( cntx : *ArchetypeSpawnContext ) bool
    {
      const root = cntx.createEntity();
      return cntx.setRootEntity( root );
    }
  };

  var world : World = .{};

  try std.testing.expect( !world.registerArchetype( TestArch.archetype ));
  try std.testing.expect(  world.spawnArchetype( TestArch.archetype.name ) == null );

  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect( world.getArchetypeCount() == 0 );
  try std.testing.expect(  world.registerArchetype( TestArch.archetype ));
  try std.testing.expect( !world.registerArchetype( TestArch.archetype ));
  try std.testing.expect( world.getArchetypeCount() == 1 );
  try std.testing.expect( world.spawnArchetype( "missing.archetype" ) == null );
}

test "World archetype spawning attaches initial components relations and traits"
{
  const Bundle = struct
  {
    const RootComp = struct
    {
      pub const compStorePolicy : comp.CompStorePolicy = .SPARSE;

      value : u32 = 0,
    };
    const ChildComp = struct
    {
      pub const compStorePolicy : comp.CompStorePolicy = .PACKED;

      value : u32 = 0,
    };

    const archetype : Archetype =
    .{
      .name    = "test.fact_bundle",
      .spawnFn = spawn,
    };

    fn spawn( cntx : *ArchetypeSpawnContext ) bool
    {
      const root  = cntx.createEntity();
      const child = cntx.createEntity();

      return cntx.setRootEntity( root )
        and cntx.reportEntity( "child", child )
        and cntx.addComp( RootComp,  root,  .{ .value = 10 })
        and cntx.addComp( ChildComp, child, .{ .value = 20 })
        and cntx.addRelation( rel.LinkedTo, root, child, .{} )
        and cntx.applyTrait( trt.Persistent, root );
    }
  };

  var world : World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect( world.registerComp(     Bundle.RootComp  ));
  try std.testing.expect( world.registerComp(     Bundle.ChildComp ));
  try std.testing.expect( world.registerRelation( rel.LinkedTo     ));
  try std.testing.expect( world.registerTrait(    trt.Persistent   ));
  try std.testing.expect( world.registerArchetype( Bundle.archetype ));

  const result  = world.spawnArchetype( Bundle.archetype.name ).?;
  const rootId  = result.rootId;
  const childId = result.getReportedId( "child" ).?;

  try std.testing.expect( world.isEntityAlive( rootId  ));
  try std.testing.expect( world.isEntityAlive( childId ));
  try std.testing.expect( world.getComp( Bundle.RootComp,  rootId  ).?.value == 10 );
  try std.testing.expect( world.getComp( Bundle.ChildComp, childId ).?.value == 20 );
  try std.testing.expect( world.hasRelation( rel.LinkedTo, rootId, childId ));
  try std.testing.expect( world.hasTrait( trt.Persistent, rootId ));
}

test "World archetype spawning fails and cleans up when fact stores are missing"
{
  const Bundle = struct
  {
    const MissingComp = struct
    {
      pub const compStorePolicy : comp.CompStorePolicy = .SPARSE;

      value : u32 = 0,
    };

    const missingComp : Archetype =
    .{
      .name    = "test.missing_comp",
      .spawnFn = spawnMissingComp,
    };
    const missingRel : Archetype =
    .{
      .name    = "test.missing_rel",
      .spawnFn = spawnMissingRel,
    };
    const missingTrait : Archetype =
    .{
      .name    = "test.missing_trait",
      .spawnFn = spawnMissingTrait,
    };

    fn spawnMissingComp( cntx : *ArchetypeSpawnContext ) bool
    {
      const root = cntx.createEntity();
      return cntx.setRootEntity( root )
        and cntx.addComp( MissingComp, root, .{ .value = 1 });
    }

    fn spawnMissingRel( cntx : *ArchetypeSpawnContext ) bool
    {
      const root  = cntx.createEntity();
      const child = cntx.createEntity();
      return cntx.setRootEntity( root )
        and cntx.reportEntity( "child", child )
        and cntx.addRelation( rel.LinkedTo, root, child, .{} );
    }

    fn spawnMissingTrait( cntx : *ArchetypeSpawnContext ) bool
    {
      const root = cntx.createEntity();
      return cntx.setRootEntity( root )
        and cntx.applyTrait( trt.Persistent, root );
    }
  };

  var world : World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect( world.registerArchetype( Bundle.missingComp  ));
  try std.testing.expect( world.registerArchetype( Bundle.missingRel   ));
  try std.testing.expect( world.registerArchetype( Bundle.missingTrait ));

  try std.testing.expect( world.spawnArchetype( Bundle.missingComp.name  ) == null );
  try std.testing.expect( !world.isEntityAlive( 1 ));

  try std.testing.expect( world.registerComp( Bundle.MissingComp ));
  try std.testing.expect( world.spawnArchetype( Bundle.missingRel.name   ) == null );
  try std.testing.expect( !world.isEntityAlive( 2 ));
  try std.testing.expect( !world.isEntityAlive( 3 ));

  try std.testing.expect( world.registerRelation( rel.LinkedTo ));
  try std.testing.expect( world.spawnArchetype( Bundle.missingTrait.name ) == null );
  try std.testing.expect( !world.isEntityAlive( 4 ));
}

test "World archetype spawning does not enqueue commands or custom events"
{
  const TestArch = struct
  {
    const archetype : Archetype =
    .{
      .name    = "test.silent_spawn",
      .spawnFn = spawn,
    };

    fn spawn( cntx : *ArchetypeSpawnContext ) bool
    {
      const root = cntx.createEntity();
      return cntx.setRootEntity( root );
    }
  };
  const TestCommand = struct
  {
    value : u32 = 0,
  };
  const TestEvent = struct
  {
    value : u32 = 0,
  };

  var world : World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect( world.registerCommand( TestCommand ));
  try std.testing.expect( world.registerEvent(   TestEvent   ));
  try std.testing.expect( world.registerArchetype( TestArch.archetype ));
  try std.testing.expect( world.spawnArchetype( TestArch.archetype.name ) != null );

  try std.testing.expect( world.getCommandCount( TestCommand ) == 0 );
  try std.testing.expect( world.getEventCount(   TestEvent   ) == 0 );
}

test "World owns explicit rule registration and execution"
{
  const TestComp = struct
  {
    pub const compStorePolicy : comp.CompStorePolicy = .SPARSE;

    value : u32 = 0,
  };
  const TestEvent = struct
  {
    value : u32 = 0,
  };
  const TestCommand = struct
  {
    entityId : EntityId = 0,
    value    : u32     = 0,
  };

  const Runner = struct
  {
    var entityId : EntityId = 0;
    var order    : [2]u8    = .{ 0, 0 };
    var count    : usize   = 0;

    fn first( context : *RuleContext ) bool
    {
      order[ count ] = 1;
      count += 1;
      return context.enqueueCommand( TestCommand, .{ .entityId = entityId, .value = 10 });
    }

    fn second( context : *RuleContext ) bool
    {
      order[ count ] = 2;
      count += 1;

      const compVal    = context.getComp( TestComp, entityId ) orelse return false;
      const eventCount = context.getEventCount( TestEvent );
      return context.enqueueCommand( TestCommand, .{ .entityId = entityId, .value = compVal.value + @as( u32, @intCast( eventCount ))});
    }
  };

  var world : World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect( world.ruleManager.isInit );
  try std.testing.expect( world.getRuleCount() == 0 );

  try std.testing.expect( world.registerComp(    TestComp    ));
  try std.testing.expect( world.registerEvent(   TestEvent   ));
  try std.testing.expect( world.registerCommand( TestCommand ));

  Runner.entityId = world.createEntity().id;
  Runner.order    = .{ 0, 0 };
  Runner.count    = 0;

  try std.testing.expect( world.addComp( TestComp, Runner.entityId, .{ .value = 40 }));
  try std.testing.expect( world.emitEvent( TestEvent, .{ .value = 99 }));

  try std.testing.expect(  world.registerRule( .{ .name = "second", .order = 20, .runFn = Runner.second }));
  try std.testing.expect(  world.registerRule( .{ .name = "first",  .order = 10, .runFn = Runner.first  }));
  try std.testing.expect( !world.registerRule( .{ .name = "first",  .order = 30, .runFn = Runner.first  }));
  try std.testing.expect(  world.hasRule( "first" ));
  try std.testing.expect(  world.getRuleCount() == 2 );

  try std.testing.expect( world.applyRules() );
  try std.testing.expect( Runner.order[ 0 ] == 1 );
  try std.testing.expect( Runner.order[ 1 ] == 2 );
  try std.testing.expect( world.getEventCount( TestEvent ) == 1 );
  try std.testing.expect( world.popCommand( TestCommand ).?.value.value == 10 );
  try std.testing.expect( world.popCommand( TestCommand ).?.value.value == 41 );

  world.deinit();
  try std.testing.expect( !world.ruleManager.isInit );
}

test "World rule failure is visible and stops later rules"
{
  const TestCommand = struct
  {
    value : u32 = 0,
  };

  const Runner = struct
  {
    fn fail( context : *RuleContext ) bool
    {
      _ = context;
      return false;
    }

    fn later( context : *RuleContext ) bool
    {
      return context.enqueueCommand( TestCommand, .{ .value = 99 });
    }
  };

  var world : World = .{};

  try std.testing.expect( !world.registerRule( .{ .name = "uninit", .runFn = Runner.fail }));
  try std.testing.expect( !world.applyRules() );

  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect( world.registerCommand( TestCommand ));
  try std.testing.expect( world.registerRule( .{ .name = "fail",  .order = 10, .runFn = Runner.fail  }));
  try std.testing.expect( world.registerRule( .{ .name = "later", .order = 20, .runFn = Runner.later }));

  try std.testing.expect( !world.applyRules() );
  try std.testing.expect( world.getCommandCount( TestCommand ) == 0 );
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

test "World owns typed command queue API and registration lifecycle"
{
  const TestCommand = struct
  {
    entityId : EntityId = 0,
    value    : u32      = 0,
  };

  var world : World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect(  world.registerCommand( TestCommand ));
  try std.testing.expect( !world.registerCommand( TestCommand ));
  try std.testing.expect(  world.getCommandQueue( TestCommand ) != null );

  world.tick( .{ .baseTickIndex = 9 });

  try std.testing.expect( world.enqueueCommand( TestCommand, .{ .entityId = 1, .value = 42 }));
  try std.testing.expect( world.enqueueCommand( TestCommand, .{ .entityId = 2, .value = 11 }));
  try std.testing.expect( world.getCommandCount( TestCommand ) == 2 );
  try std.testing.expect( world.peekCommand(     TestCommand, 0 ).?.value.value == 42 );

  var count : usize = 0;
  var sum   : u32   = 0;
  var iter = world.getCommandIterator( TestCommand ).?;
  while( iter.next() )| record |
  {
    count += 1;
    sum   += record.value.value;
  }

  try std.testing.expect( count == 2 );
  try std.testing.expect( sum   == 53 );
  try std.testing.expect( world.getCommandCount( TestCommand ) == 2 );

  const record = world.popCommand( TestCommand ).?;
  try std.testing.expect( record.value.value          == 42 );
  try std.testing.expect( record.meta.sequence        == 0  );
  try std.testing.expect( record.meta.tickOrder       == 0  );
  try std.testing.expect( record.meta.baseTickIndex.? == 9  );

  try std.testing.expect( world.clearCommands( TestCommand ));
  try std.testing.expect( world.getCommandCount( TestCommand ) == 0 );

  try std.testing.expect( world.unregisterCommand( TestCommand ));
  try std.testing.expect( world.getCommandQueue(   TestCommand ) == null );
}

test "World command API rejects uninitialized worlds and unregistered queues"
{
  const TestCommand = struct
  {
    value : u32 = 0,
  };

  var world : World = .{};

  try std.testing.expect( !world.registerCommand( TestCommand ));
  try std.testing.expect( !world.enqueueCommand(  TestCommand, .{ .value = 1 }));
  try std.testing.expect(  world.popCommand(      TestCommand ) == null );
  try std.testing.expect( !world.clearCommands(   TestCommand ));

  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect( !world.enqueueCommand( TestCommand, .{ .value = 2 }));
  try std.testing.expect(  world.popCommand(     TestCommand ) == null );
  try std.testing.expect( !world.clearCommands(  TestCommand ));
}

test "World leaves generic entity component relation and trait events silent when queues are absent"
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
  const Selectable = struct {};

  var world : World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect( world.registerComp(     TestComp   ));
  try std.testing.expect( world.registerRelation( TestRel    ));
  try std.testing.expect( world.registerTrait(    Selectable ));

  const sourceId = world.createEntity().id;
  const targetId = world.createEntity().id;

  try std.testing.expect( world.addComp(      TestComp,   sourceId, .{ .value = 1 }));
  try std.testing.expect( world.addRelation(  TestRel,    sourceId, targetId, .{ .value = 2 }));
  try std.testing.expect( world.applyTrait(   Selectable, sourceId ));
  try std.testing.expect( world.removeTrait(  Selectable, sourceId ));
  try std.testing.expect( world.removeRelation( TestRel,  sourceId, targetId ));
  try std.testing.expect( world.removeComp(     TestComp, sourceId ));
  try std.testing.expect( world.destroyEntity( sourceId ));

  try std.testing.expect( world.eventManager.getToalEvetnCount() == 0 );
}

test "World emits registered generic entity component relation and trait events"
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
  const Selectable = struct {};

  var world : World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect( world.registerEvent( evt.EntityCreated    ));
  try std.testing.expect( world.registerEvent( evt.EntityDestroyed  ));
  try std.testing.expect( world.registerEvent( evt.ComponentAdded   ));
  try std.testing.expect( world.registerEvent( evt.ComponentRemoved ));
  try std.testing.expect( world.registerEvent( evt.RelationAdded    ));
  try std.testing.expect( world.registerEvent( evt.RelationRemoved  ));
  try std.testing.expect( world.registerEvent( evt.TraitApplied     ));
  try std.testing.expect( world.registerEvent( evt.TraitRemoved     ));

  world.tick( .{ .baseTickIndex = 14 });

  const sourceId = world.createEntity().id;
  const targetId = world.createEntity().id;

  try std.testing.expect( world.registerComp( TestComp ));
  try std.testing.expect( world.addComp(    TestComp, sourceId, .{ .value = 1 }));
  try std.testing.expect( world.removeComp( TestComp, sourceId ));

  try std.testing.expect( world.registerRelation( TestRel ));
  try std.testing.expect( world.addRelation(    TestRel, sourceId, targetId, .{ .value = 2 }));
  try std.testing.expect( world.removeRelation( TestRel, sourceId, targetId ));
  try std.testing.expect( world.registerTrait( Selectable ));
  try std.testing.expect( world.applyTrait(    Selectable, sourceId ));
  try std.testing.expect( world.removeTrait(   Selectable, sourceId ));
  try std.testing.expect( world.destroyEntity( sourceId ));

  const createdA = world.popEvent( evt.EntityCreated ).?;
  const createdB = world.popEvent( evt.EntityCreated ).?;
  const compAdd  = world.popEvent( evt.ComponentAdded ).?;
  const compRem  = world.popEvent( evt.ComponentRemoved ).?;
  const relAdd   = world.popEvent( evt.RelationAdded ).?;
  const relRem   = world.popEvent( evt.RelationRemoved ).?;
  const traitAdd  = world.popEvent( evt.TraitApplied ).?;
  const traitRem  = world.popEvent( evt.TraitRemoved ).?;
  const destroyed = world.popEvent( evt.EntityDestroyed ).?;

  try std.testing.expect( createdA.value.entityId == sourceId );
  try std.testing.expect( createdB.value.entityId == targetId );
  try std.testing.expect( compAdd.value.entityId  == sourceId );
  try std.testing.expect( compRem.value.entityId  == sourceId );
  try std.testing.expect( relAdd.value.sourceId   == sourceId );
  try std.testing.expect( relAdd.value.targetId   == targetId );
  try std.testing.expect( relRem.value.sourceId   == sourceId );
  try std.testing.expect( traitAdd.value.entityId == sourceId );
  try std.testing.expect( traitRem.value.entityId == sourceId );
  try std.testing.expect( destroyed.value.entityId == sourceId );

  try std.testing.expect( createdA.meta.sequence       == 0  );
  try std.testing.expect( createdB.meta.sequence       == 1  );
  try std.testing.expect( compAdd.meta.sequence        == 2  );
  try std.testing.expect( compRem.meta.sequence        == 3  );
  try std.testing.expect( relAdd.meta.sequence         == 4  );
  try std.testing.expect( relRem.meta.sequence         == 5  );
  try std.testing.expect( traitAdd.meta.sequence       == 6  );
  try std.testing.expect( traitRem.meta.sequence       == 7  );
  try std.testing.expect( destroyed.meta.sequence      == 8  );
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
