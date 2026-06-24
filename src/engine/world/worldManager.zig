const std = @import( "std" );

const entity    = @import( "entity.zig" );
const comp      = @import( "components/component.zig" );
const rel       = @import( "relations/relation.zig" );
const trt       = @import( "traits/trait.zig" );
const evt       = @import( "events/event.zig" );
const evtQue    = @import( "events/eventQueue.zig" );
const cmd       = @import( "commands/command.zig" );
const cmdQue    = @import( "commands/commandQueue.zig" );
const rule      = @import( "rules/rule.zig" );
const view      = @import( "views/view.zig" );
const worldCore = @import( "core/world.zig" );

pub const World                 = worldCore.World;
pub const TickInfo              = worldCore.TickInfo;
pub const Archetype             = worldCore.Archetype;
pub const ArchetypeManager      = worldCore.ArchetypeManager;
pub const ArchetypeSpawnContext = worldCore.ArchetypeSpawnContext;

const Entity               = entity.Entity;
const EntityId             = entity.EntityId;
const CompStoreFactory     = comp.CompStoreFactory;
const RelationStoreFactory = rel.RelationStoreFactory;
const TraitSetFactory      = trt.TraitSetFactory;
const EventQueueFactory    = evtQue.EventQueueFactory;
const CommandQueueFactory  = cmdQue.CommandQueueFactory;
const CommandExecResult    = cmd.CommandExecResult;
const Rule                 = rule.Rule;
const ArchetypeSpawnResult = @import( "archetypes/archetype.zig" ).ArchetypeSpawnResult;


/// Engine-owned facade for the currently active simulation World.
/// It wraps one World for now so callers do not own concrete World storage.
pub const WorldManager = struct
{
  world : World = .{},


  // ================================ WORLD ACCESS FUNCTIONS ================================

  /// Returns the current concrete World for systems that need narrow direct access.
  pub inline fn getWorld( self : *WorldManager ) *World
  {
    return &self.world;
  }

  /// Returns the current concrete World for read-only inspection.
  pub inline fn getWorldConst( self : *const WorldManager ) *const World
  {
    return &self.world;
  }


  // ================================ LIFECYCLE FUNCTIONS ================================

  pub inline fn init(   self : *WorldManager, alloc : std.mem.Allocator ) void { self.world.init( alloc ); }
  pub inline fn deinit( self : *WorldManager                            ) void { self.world.deinit();     }


  // ================================ ENTITY FUNCTIONS ================================

  pub inline fn createEntity(  self : *WorldManager                            ) Entity { return self.world.createEntity();            }
  pub inline fn isEntityAlive( self : *const WorldManager, entityId : EntityId ) bool   { return self.world.isEntityAlive( entityId ); }
  pub inline fn destroyEntity( self : *WorldManager, entityId : EntityId       ) bool   { return self.world.destroyEntity( entityId ); }


  // ================================ COMPONENT FUNCTIONS ================================

  pub inline fn registerComp(   self : *WorldManager, comptime CompType : type ) bool { return self.world.registerComp(   CompType ); }
  pub inline fn unregisterComp( self : *WorldManager, comptime CompType : type ) bool { return self.world.unregisterComp( CompType ); }

  pub inline fn getCompStore( self : *WorldManager, comptime CompType  : type    ) ?*CompStoreFactory( CompType ){ return self.world.getCompStore( CompType ); }
  pub inline fn getCompView(  self : *WorldManager, comptime CompTypes : anytype ) ?view.CompView( CompTypes )   { return self.world.getCompView(  CompTypes ); }

  pub inline fn addComp(      self : *WorldManager, comptime CompType : type, entityId : EntityId, value : CompType ) bool { return self.world.addComp(      CompType, entityId, value ); }
  pub inline fn getComp(      self : *WorldManager, comptime CompType : type, entityId : EntityId ) ?*CompType             { return self.world.getComp(      CompType, entityId ); }
  pub inline fn getCompConst( self : *WorldManager, comptime CompType : type, entityId : EntityId ) ?*const CompType       { return self.world.getCompConst( CompType, entityId ); }
  pub inline fn hasComp(      self : *WorldManager, comptime CompType : type, entityId : EntityId ) bool                   { return self.world.hasComp(      CompType, entityId ); }
  pub inline fn removeComp(   self : *WorldManager, comptime CompType : type, entityId : EntityId ) bool                   { return self.world.removeComp(   CompType, entityId ); }

  pub inline fn getCompViewGen( self : *const WorldManager ) u64 { return self.world.getCompViewGen(); }


  // ================================ RELATION FUNCTIONS ================================

  pub inline fn registerRelation(   self : *WorldManager, comptime RelType : type ) bool { return self.world.registerRelation(   RelType ); }
  pub inline fn unregisterRelation( self : *WorldManager, comptime RelType : type ) bool { return self.world.unregisterRelation( RelType ); }
  pub inline fn getRelationStore(   self : *WorldManager, comptime RelType : type ) ?*RelationStoreFactory( RelType ) { return self.world.getRelationStore( RelType ); }

  pub inline fn addRelation(      self : *WorldManager, comptime RelType : type, sourceId : EntityId, targetId : EntityId, value : RelType ) bool { return self.world.addRelation(      RelType, sourceId, targetId, value ); }
  pub inline fn getRelation(      self : *WorldManager, comptime RelType : type, sourceId : EntityId, targetId : EntityId ) ?*RelType             { return self.world.getRelation(      RelType, sourceId, targetId ); }
  pub inline fn getRelationConst( self : *WorldManager, comptime RelType : type, sourceId : EntityId, targetId : EntityId ) ?*const RelType       { return self.world.getRelationConst( RelType, sourceId, targetId ); }
  pub inline fn hasRelation(      self : *WorldManager, comptime RelType : type, sourceId : EntityId, targetId : EntityId ) bool                  { return self.world.hasRelation(      RelType, sourceId, targetId ); }
  pub inline fn removeRelation(   self : *WorldManager, comptime RelType : type, sourceId : EntityId, targetId : EntityId ) bool                  { return self.world.removeRelation(   RelType, sourceId, targetId ); }

  pub inline fn getRelationsFrom( self : *WorldManager, comptime RelType : type, sourceId : EntityId ) ?rel.RelationStoreFactory( RelType ).ConstIterator { return self.world.getRelationsFrom( RelType, sourceId ); }
  pub inline fn getRelationsTo(   self : *WorldManager, comptime RelType : type, targetId : EntityId ) ?rel.RelationStoreFactory( RelType ).ConstIterator { return self.world.getRelationsTo(   RelType, targetId ); }


  // ================================ TRAIT FUNCTIONS ================================

  pub inline fn registerTrait(   self : *WorldManager, comptime TraitType : type ) bool { return self.world.registerTrait(    TraitType ); }
  pub inline fn unregisterTrait( self : *WorldManager, comptime TraitType : type ) bool { return self.world.unregisterTrait(  TraitType ); }
  pub inline fn getTraitSet(     self : *WorldManager, comptime TraitType : type ) ?*TraitSetFactory( TraitType ) { return self.world.getTraitSet( TraitType ); }

  pub inline fn applyTrait(  self : *WorldManager, comptime TraitType : type, entityId : EntityId ) bool { return self.world.applyTrait(  TraitType, entityId ); }
  pub inline fn hasTrait(    self : *WorldManager, comptime TraitType : type, entityId : EntityId ) bool { return self.world.hasTrait(    TraitType, entityId ); }
  pub inline fn removeTrait( self : *WorldManager, comptime TraitType : type, entityId : EntityId ) bool { return self.world.removeTrait( TraitType, entityId ); }

  pub inline fn getTraitEntityIterator( self : *WorldManager, comptime TraitType : type ) ?trt.TraitSetFactory( TraitType ).EntityIterator { return self.world.getTraitEntityIterator( TraitType ); }


  // ================================ EVENT FUNCTIONS ================================

  pub inline fn registerEvent(   self : *WorldManager, comptime EventType : type ) bool { return self.world.registerEvent(   EventType ); }
  pub inline fn unregisterEvent( self : *WorldManager, comptime EventType : type ) bool { return self.world.unregisterEvent( EventType ); }
  pub inline fn getEventQueue(   self : *WorldManager, comptime EventType : type ) ?*EventQueueFactory( EventType ) { return self.world.getEventQueue( EventType ); }

  pub inline fn emitEvent( self : *WorldManager, comptime EventType : type, value : EventType ) bool { return self.world.emitEvent( EventType, value ); }
  pub inline fn peekEvent( self : *WorldManager, comptime EventType : type, index : usize     ) ?*const evt.EventRecord( EventType ) { return self.world.peekEvent( EventType, index ); }

  pub inline fn popEvent(         self : *WorldManager, comptime EventType : type ) ?evt.EventRecord( EventType ) { return self.world.popEvent( EventType ); }
  pub inline fn getEventIterator( self : *WorldManager, comptime EventType : type ) ?evtQue.EventQueueFactory( EventType ).ConstIterator { return self.world.getEventIterator( EventType ); }
  pub inline fn clearEvents(      self : *WorldManager, comptime EventType : type ) bool  { return self.world.clearEvents(   EventType ); }
  pub inline fn getEventCount(    self : *WorldManager, comptime EventType : type ) usize { return self.world.getEventCount( EventType ); }


  // ================================ COMMAND FUNCTIONS ================================

  pub inline fn registerCommand(     self : *WorldManager, comptime CommandType : type ) bool { return self.world.registerCommand( CommandType ); }
  pub inline fn registerCommandExec( self : *WorldManager, comptime CommandType : type, execFn : cmd.CommandExecFn( CommandType )) bool
  {
    return self.world.registerCommandExec( CommandType, execFn );
  }
  pub inline fn unregisterCommand( self : *WorldManager, comptime CommandType : type ) bool { return self.world.unregisterCommand( CommandType ); }
  pub inline fn getCommandQueue(   self : *WorldManager, comptime CommandType : type ) ?*CommandQueueFactory( CommandType ) { return self.world.getCommandQueue( CommandType ); }

  pub inline fn enqueueCommand( self : *WorldManager, comptime CommandType : type, value : CommandType  ) bool { return self.world.enqueueCommand( CommandType, value ); }
  pub inline fn peekCommand(    self : *WorldManager, comptime CommandType : type, index : usize        ) ?*const cmd.CommandRecord( CommandType ) { return self.world.peekCommand( CommandType, index ); }

  pub inline fn popCommand(         self : *WorldManager, comptime CommandType : type ) ?cmd.CommandRecord( CommandType ) { return self.world.popCommand( CommandType ); }
  pub inline fn getCommandIterator( self : *WorldManager, comptime CommandType : type ) ?cmdQue.CommandQueueFactory( CommandType ).ConstIterator { return self.world.getCommandIterator( CommandType ); }
  pub inline fn clearCommands(      self : *WorldManager, comptime CommandType : type ) bool  { return self.world.clearCommands(   CommandType ); }
  pub inline fn getCommandCount(    self : *WorldManager, comptime CommandType : type ) usize { return self.world.getCommandCount( CommandType ); }
  pub inline fn execCommandType(    self : *WorldManager, comptime CommandType : type, amount : usize ) CommandExecResult
  {
    return self.world.execCommandType( CommandType, amount );
  }


  // ================================ RULE FUNCTIONS ================================

  pub inline fn hasRule(      self : *const WorldManager, name : []const u8 ) bool { return self.world.hasRule( name ); }
  pub inline fn registerRule( self : *WorldManager, ruleDef : Rule ) bool          { return self.world.registerRule( ruleDef ); }

  pub inline fn getRuleCount( self : *const WorldManager ) usize { return self.world.getRuleCount(); }
  pub inline fn applyRules(   self : *WorldManager       ) bool  { return self.world.applyRules();   }


  // ================================ ARCHETYPE FUNCTIONS ================================

  pub inline fn registerArchetype( self : *WorldManager, archetypeVal : Archetype ) bool { return self.world.registerArchetype( archetypeVal ); }
  pub inline fn spawnArchetype(    self : *WorldManager, name : []const u8        ) ?ArchetypeSpawnResult { return self.world.spawnArchetype( name ); }
  pub inline fn getArchetypeCount( self : *const WorldManager                     ) usize { return self.world.getArchetypeCount(); }


  // ================================ TICK FUNCTIONS ================================

  pub inline fn tick( self : *WorldManager, info : TickInfo ) void
  {
    self.world.tick( info );
  }
};


// ================================ TESTS ================================

test "WorldManager owns a single active world facade"
{
  var manager : WorldManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  const entityVal = manager.createEntity();

  try std.testing.expect( entityVal.id != 0 );
  try std.testing.expect( manager.isEntityAlive( entityVal.id ));
  try std.testing.expect( manager.getWorld() == &manager.world );
}

test "WorldManager forwards one-type command execution"
{
  const TestCommand = struct
  {
    value : u32 = 0,
  };

  const Runner = struct
  {
    var sum : u32 = 0;

    fn exec( context : *cmd.CommandContext, record : cmd.CommandRecord( TestCommand )) bool
    {
      _ = context;
      sum += record.value.value;
      return true;
    }
  };

  var manager : WorldManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  Runner.sum = 0;

  try std.testing.expect( manager.registerCommandExec( TestCommand, Runner.exec ));
  try std.testing.expect( manager.enqueueCommand( TestCommand, .{ .value = 10 }));
  try std.testing.expect( manager.enqueueCommand( TestCommand, .{ .value = 32 }));

  const result = manager.execCommandType( TestCommand, 0 );

  try std.testing.expect( result.attempted == 2 );
  try std.testing.expect( result.succeeded == 2 );
  try std.testing.expect( result.failed    == 0 );
  try std.testing.expect( Runner.sum == 42 );
}
