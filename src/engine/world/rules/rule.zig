const std = @import( "std" );

const cmdMgr = @import( "../commands/commandManager.zig" );
const query  = @import( "../queries/query.zig" );

const CommandManager = cmdMgr.CommandManager;
const WorldQuery     = query.WorldQuery;


/// Runtime context passed to rule reactions.
/// Rules inspect events or current facts through `query` and request changes
/// through commands.
pub const RuleContext = struct
{
  query    : WorldQuery,
  commands : *CommandManager,

  /// Enqueues one requested-change fact through the active command surface.
  pub inline fn enqueueCommand( self : *RuleContext, comptime CommandType : type, value : CommandType ) bool
  {
    return self.commands.enqueue( CommandType, value );
  }
};

/// Callback shape for compact rule reactions.
/// Returning false signals a failed rule pass without consuming events.
pub const RuleFn = *const fn ( *RuleContext ) bool;

/// Minimal named rule declaration with deterministic order metadata.
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
      const eventRecord = context.query.peekEvent( TestEvent, 0 ) orelse return false;
      return context.enqueueCommand( TestCommand, .{ .value = eventRecord.value.value + 1 });
    }
  };

  var manager : CommandManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  try std.testing.expect( manager.register( TestCommand ));

  var world = @import( "../worldManager.zig" ).World{};
  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect( world.registerEvent( TestEvent ));
  try std.testing.expect( world.emitEvent( TestEvent, .{ .value = 41 }));

  var context : RuleContext =
  .{
    .query    = WorldQuery.init( &world ).?,
    .commands = &manager,
  };
  const rule : Rule = .{ .name = "event-to-command", .runFn = Runner.run };

  try std.testing.expect( rule.run( &context ));
  try std.testing.expect( world.getEventCount( TestEvent ) == 1 );
  try std.testing.expect( manager.pop( TestCommand ).?.value.value == 42 );
}
