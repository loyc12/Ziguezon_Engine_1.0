const std = @import( "std" );
const utl = @import( "utils" );

const rule     = @import( "rule.zig" );
const query    = @import( "../queries/query.zig" );
const worldCore = @import( "../core/world.zig" );

const Rule        = rule.Rule;
const RuleContext = rule.RuleContext;
const EntityId    = @import( "../entity.zig" ).EntityId;
const World       = worldCore.World;
const WorldQuery  = query.WorldQuery;


/// Small ordered registry for explicit simulation rule passes.
/// Rules cover both broad current-fact passes and event/fact reactions.
/// This does not own cadence, a rule graph, or temporary rules.
pub const RuleManager = struct
{
  alloc : std.mem.Allocator    = undefined,
  rules : std.ArrayList( Rule ) = .empty,

  isInit : bool = false,


  // ================================ LIFECYCLE FUNCTIONS ================================

  /// Initializes rule registry storage.
  pub fn init( self : *RuleManager, alloc : std.mem.Allocator ) void
  {
    if( self.isInit )
    {
      utl.qlog( .WARN, @src(), "RuleManager is already initialized : returning" );
      return;
    }

    self.alloc  = alloc;
    self.rules  = .empty;
    self.isInit = true;
  }

  /// Releases registered rule declarations.
  pub fn deinit( self : *RuleManager ) void
  {
    if( !self.isInit )
    {
      utl.qlog( .WARN, @src(), "RuleManager is uninitialized : returning" );
      return;
    }

    self.rules.deinit( self.alloc );
    self.rules  = .empty;
    self.isInit = false;
  }


  // ================================ REGISTRATION FUNCTIONS ================================

  /// Registers one named rule and keeps lower `order` values earlier.
  pub fn register( self : *RuleManager, ruleDef : Rule ) bool
  {
    if( !self.isInit )
    {
      utl.qlog( .WARN, @src(), "Cannot register Rule : RuleManager is uninitialized" );
      return false;
    }
    if( ruleDef.name.len == 0 )
    {
      utl.qlog( .WARN, @src(), "Cannot register Rule : name is empty" );
      return false;
    }
    if( self.hasRule( ruleDef.name ))
    {
      utl.log( .WARN, @src(), "Cannot register Rule {s} : name already registered", .{ ruleDef.name });
      return false;
    }

    self.rules.append( self.alloc, ruleDef ) catch
    {
      utl.log( .ERROR, @src(), "Failed to register Rule {s}", .{ ruleDef.name });
      return false;
    };

    self.reorderLastRule();
    return true;
  }

  /// Returns true when a rule name is already registered.
  pub fn hasRule( self : *const RuleManager, name : []const u8 ) bool
  {
    if( !self.isInit ){ return false; }

    for( self.rules.items )| ruleDef |
    {
      if( std.mem.eql( u8, ruleDef.name, name )){ return true; }
    }

    return false;
  }

  /// Returns the number of registered rules.
  pub inline fn getRuleCount( self : *const RuleManager ) usize
  {
    if( !self.isInit ){ return 0; }
    return self.rules.items.len;
  }


  // ================================ EXECUTION FUNCTIONS ================================

  /// Evaluates registered rules in order against one initialized World.
  /// Rules can inspect current facts or queued events through WorldQuery without
  /// mutating broad query results.
  pub fn runAll( self : *RuleManager, world : *World ) bool
  {
    if( !self.isInit )
    {
      utl.qlog( .WARN, @src(), "Cannot run Rules : RuleManager is uninitialized" );
      return false;
    }

    if( !world.isInit )
    {
      utl.qlog( .WARN, @src(), "Cannot run Rules : World is uninitialized" );
      return false;
    }

    var context : RuleContext =
    .{
      .world    = world,
      .commands = &world.commandManager,
    };

    for( self.rules.items )| *ruleDef |
    {
      if( !ruleDef.run( &context ))
      {
        utl.log( .WARN, @src(), "Rule {s} returned failure", .{ ruleDef.name });
        return false;
      }
    }

    return true;
  }


  // ================================ INTERNAL FUNCTIONS ================================

  fn reorderLastRule( self : *RuleManager ) void
  {
    var idx = self.rules.items.len - 1;

    while( idx > 0 and self.rules.items[ idx - 1 ].order > self.rules.items[ idx ].order )
    {
      const tmp = self.rules.items[ idx - 1 ];
      self.rules.items[ idx - 1 ] = self.rules.items[ idx ];
      self.rules.items[ idx ] = tmp;
      idx -= 1;
    }
  }
};


// ================================ TESTS ================================

test "RuleManager registers rules in order"
{
  const Runner = struct
  {
    fn run( context : *RuleContext ) bool
    {
      _ = context;
      return true;
    }
  };

  var manager : RuleManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  try std.testing.expect( manager.register( .{ .name = "late",  .order = 20, .runFn = Runner.run }));
  try std.testing.expect( manager.register( .{ .name = "early", .order = 10, .runFn = Runner.run }));
  try std.testing.expect( !manager.register( .{ .name = "early", .order = 30, .runFn = Runner.run }));

  try std.testing.expect( manager.getRuleCount() == 2 );
  try std.testing.expect( std.mem.eql( u8, manager.rules.items[ 0 ].name, "early" ));
  try std.testing.expect( std.mem.eql( u8, manager.rules.items[ 1 ].name, "late"  ));
}

test "RuleManager observes events and emits commands without consuming events"
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
      var count : usize = 0;
      var sum   : u32   = 0;
      var iter = WorldQuery.getEventIterator( context.world, TestEvent ) orelse return false;
      while( iter.next() )| record |
      {
        count += 1;
        sum   += record.value.value;
      }

      if( count == 0 ){ return false; }
      return context.enqueueCommand( TestCommand, .{ .value = sum });
    }
  };

  var world : World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect( world.registerEvent(   TestEvent   ));
  try std.testing.expect( world.registerCommand( TestCommand ));
  try std.testing.expect( world.emitEvent( TestEvent, .{ .value = 10 }));
  try std.testing.expect( world.emitEvent( TestEvent, .{ .value = 32 }));

  var manager : RuleManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  try std.testing.expect( manager.register( .{ .name = "event-sum", .runFn = Runner.run }));
  try std.testing.expect( manager.runAll( &world ));

  try std.testing.expect( world.getEventCount( TestEvent ) == 2 );
  try std.testing.expect( world.popCommand( TestCommand ).?.value.value == 42 );
}

test "RuleManager reads current facts and emits commands"
{
  const TestComp = struct
  {
    pub const compStorePolicy : @import( "../components/component.zig" ).CompStorePolicy = .SPARSE;

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

    fn run( context : *RuleContext ) bool
    {
      const comp = WorldQuery.getComp( context.world, TestComp, entityId ) orelse return false;
      return context.enqueueCommand( TestCommand, .{ .entityId = entityId, .value = comp.value + 1 });
    }
  };

  var world : World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect( world.registerComp(    TestComp ));
  try std.testing.expect( world.registerCommand( TestCommand ));

  Runner.entityId = world.createEntity().id;
  try std.testing.expect( world.addComp( TestComp, Runner.entityId, .{ .value = 41 }));

  var manager : RuleManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  try std.testing.expect( manager.register( .{ .name = "fact-reader", .runFn = Runner.run }));
  try std.testing.expect( manager.runAll( &world ));

  const record = world.popCommand( TestCommand ).?;
  try std.testing.expect( record.value.entityId == Runner.entityId );
  try std.testing.expect( record.value.value    == 42 );
}

test "RuleManager rejects uninitialized use and uninitialized worlds"
{
  const Runner = struct
  {
    fn run( context : *RuleContext ) bool
    {
      _ = context;
      return true;
    }
  };

  var manager : RuleManager = .{};
  var world   : World       = .{};

  try std.testing.expect( !manager.register( .{ .name = "reaction", .runFn = Runner.run }));
  try std.testing.expect( !manager.runAll( &world ));

  manager.init( std.testing.allocator );
  defer manager.deinit();

  try std.testing.expect( manager.register( .{ .name = "reaction", .runFn = Runner.run }));
  try std.testing.expect( !manager.runAll( &world ));
}
