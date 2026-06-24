const std = @import( "std" );

const entity  = @import( "../entity.zig" );
const compMgr = @import( "../components/compManager.zig" );
const relMgr  = @import( "../relations/relationManager.zig" );
const trtMgr  = @import( "../traits/traitManager.zig" );
const evtMgr  = @import( "../events/eventManager.zig" );
const cmdMgr  = @import( "../commands/commandManager.zig" );

const EntityId        = entity.EntityId;
const CompManager     = compMgr.CompManager;
const RelationManager = relMgr.RelationManager;
const TraitManager    = trtMgr.TraitManager;
const EventManager    = evtMgr.EventManager;
const CommandManager  = cmdMgr.CommandManager;


/// Rule-only view over World-owned managers for one explicit rule pass.
/// This context stays field-only to prevent dependency loops between `World`
/// and `RuleManager`. Other context-like needs should duplicate and tailor this
/// shape instead of broadening `RuleContext` for unrelated work.
pub const RuleContext = struct
{
  activeEntities  : *const std.AutoHashMap( EntityId, void ),
  compManager     : *CompManager,
  relationManager : *RelationManager,
  traitManager    : *TraitManager,
  eventManager    : *EventManager,
  commandManager  : *CommandManager,
};


// ================================ TESTS ================================

test "RuleContext is a field-only manager pointer bundle"
{
  try std.testing.expect( !@hasDecl( RuleContext, "hasEntity"              ));
  try std.testing.expect( !@hasDecl( RuleContext, "hasComp"                ));
  try std.testing.expect( !@hasDecl( RuleContext, "getComp"                ));
  try std.testing.expect( !@hasDecl( RuleContext, "hasRelation"            ));
  try std.testing.expect( !@hasDecl( RuleContext, "getTraitEntityIterator" ));
  try std.testing.expect( !@hasDecl( RuleContext, "peekEvent"              ));
  try std.testing.expect( !@hasDecl( RuleContext, "enqueueCommand"         ));
}

test "RuleContext exposes managers for direct rule inspection and command emission"
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

  const eventQueue  = context.eventManager.getQueue( TestEvent ) orelse return error.TestExpectedEqual;
  const eventRecord = eventQueue.peek( 0 ) orelse return error.TestExpectedEqual;

  try std.testing.expect( context.commandManager.enqueue( TestCommand, .{ .value = eventRecord.value.value + 1 }));
  try std.testing.expect( context.eventManager.getEventCount( TestEvent ) == 1 );
  try std.testing.expect( commands.pop( TestCommand ).?.value.value == 42 );
}

test "RuleContext direct manager access can inspect current facts"
{
  const comp = @import( "../components/component.zig" );

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

  try std.testing.expect(  context.activeEntities.contains( entityId ));
  try std.testing.expect(  context.compManager.getStore( TestComp ).?.has( entityId ));
  try std.testing.expect(  context.compManager.getStore( TestComp ).?.getConst( entityId ).?.value == 41 );
  try std.testing.expect(  context.traitManager.getSet( TestTrait ).?.has( entityId ));

  _ = activeEntities.remove( entityId );

  try std.testing.expect( !context.activeEntities.contains( entityId ));
}
