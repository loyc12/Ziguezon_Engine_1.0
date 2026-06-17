const std = @import( "std" );

const cmdMgr = @import( "../commands/commandManager.zig" );
const query  = @import( "../queries/query.zig" );

const CommandManager = cmdMgr.CommandManager;
const WorldQuery     = query.WorldQuery;


/// Runtime context passed to simulation systems.
/// Systems inspect World through `query` and request changes through commands.
pub const SystemContext = struct
{
  query    : WorldQuery,
  commands : *CommandManager,

  /// Enqueues one requested-change fact through the active command surface.
  pub inline fn enqueueCommand( self : *SystemContext, comptime CommandType : type, value : CommandType ) bool
  {
    return self.commands.enqueue( CommandType, value );
  }
};

/// Callback shape for compact systems.
/// Returning false signals a failed system pass without mutating manager state.
pub const SystemFn = *const fn ( *SystemContext ) bool;

/// Minimal named system declaration with deterministic order metadata.
pub const System = struct
{
  name  : []const u8,
  order : i32      = 0,
  runFn : SystemFn,

  /// Runs this system once against the provided context.
  pub inline fn run( self : *const System, context : *SystemContext ) bool
  {
    return self.runFn( context );
  }
};


// ================================ TESTS ================================

test "System runs with query access and command emission"
{
  const TestCommand = struct
  {
    value : u32 = 0,
  };

  const Runner = struct
  {
    fn run( context : *SystemContext ) bool
    {
      if( !context.query.hasEntity( 1 )){ return false; }
      return context.enqueueCommand( TestCommand, .{ .value = 42 });
    }
  };

  var manager : CommandManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  try std.testing.expect( manager.register( TestCommand ));

  var world = @import( "../worldManager.zig" ).World{};
  world.init( std.testing.allocator );
  defer world.deinit();

  const entityId = world.createEntity().id;
  try std.testing.expect( entityId == 1 );

  var context : SystemContext =
  .{
    .query    = WorldQuery.init( &world ).?,
    .commands = &manager,
  };
  const system : System = .{ .name = "runner", .runFn = Runner.run };

  try std.testing.expect( system.run( &context ));
  try std.testing.expect( manager.getCommandCount( TestCommand ) == 1 );
  try std.testing.expect( manager.pop( TestCommand ).?.value.value == 42 );
}
