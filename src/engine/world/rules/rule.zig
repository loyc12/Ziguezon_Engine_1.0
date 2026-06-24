const std = @import( "std" );

const cntx = @import( "ruleContext.zig" );

const RuleContext = cntx.RuleContext;

/// Callback shape for compact simulation rules.
/// Rules are user-defined logic passes: they may inspect facts, validate
/// conditions, emit suitable transient facts, or enqueue commands when durable
/// World mutation is requested. They do not have to emit a command every run.
/// Returning false signals a failed rule pass without consuming events or
/// retaining history.
pub const RuleFn = *const fn ( *RuleContext ) bool;

/// Minimal named rule declaration with deterministic order metadata.
/// Use rules for both broad simulation passes and event/fact reactions.
pub const Rule = struct
{
  name  : []const u8,
  order : i32    = 0,
  runFn : RuleFn,

  /// Evaluates this rule once against the provided context.
  pub inline fn run( self : *const Rule, context : *RuleContext ) bool
  {
    return self.runFn( context );
  }
};


// ================================ TESTS ================================

test "Rule observes events and emits commands without consuming events"
{
  const TestEvent = struct
  {
    value : u32 = 0,
  };
  const TestCommand = struct
  {
    value : u32 = 0,
  };

  const Runner = struct
  {
    fn run( context : *RuleContext ) bool
    {
      const eventQueue  = context.eventManager.getQueue( TestEvent ) orelse return false;
      const eventRecord = eventQueue.peek( 0 ) orelse return false;

      return context.commandManager.enqueue( TestCommand, .{ .value = eventRecord.value.value + 1 });
    }
  };

  var activeEntities : std.AutoHashMap( @import( "../entity.zig" ).EntityId, void ) = .init( std.testing.allocator );
  defer activeEntities.deinit();

  var comps = @import( "../components/compManager.zig" ).CompManager{};
  comps.init( std.testing.allocator );
  defer comps.deinit();

  var relations = @import( "../relations/relationManager.zig" ).RelationManager{};
  relations.init( std.testing.allocator );
  defer relations.deinit();

  var traits = @import( "../traits/traitManager.zig" ).TraitManager{};
  traits.init( std.testing.allocator );
  defer traits.deinit();

  var events = @import( "../events/eventManager.zig" ).EventManager{};
  events.init( std.testing.allocator );
  defer events.deinit();

  var commands = @import( "../commands/commandManager.zig" ).CommandManager{};
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
  const rule : Rule = .{ .name = "event-to-command", .runFn = Runner.run };

  try std.testing.expect( rule.run( &context ));
  try std.testing.expect( events.getEventCount( TestEvent ) == 1 );
  try std.testing.expect( commands.pop( TestCommand ).?.value.value == 42 );
}
