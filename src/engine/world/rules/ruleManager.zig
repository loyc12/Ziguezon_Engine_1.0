const std = @import( "std" );
const utl = @import( "utils" );

const rule = @import( "rule.zig" );
const cntx = @import( "ruleContext.zig" );

const Rule        = rule.Rule;
const RuleContext = cntx.RuleContext;
const EntityId    = @import( "../entity.zig" ).EntityId;


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

  /// Evaluates registered rules in order against one short-lived rule context.
  pub fn applyRules( self : *RuleManager, context : *RuleContext ) bool
  {
    if( !self.isInit )
    {
      utl.qlog( .WARN, @src(), "Cannot run Rules : RuleManager is uninitialized" );
      return false;
    }

    for( self.rules.items )| *ruleDef |
    {
      if( !ruleDef.run( context ))
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
      var iter = context.getEventIterator( TestEvent ) orelse return false;
      while( iter.next() )| record |
      {
        count += 1;
        sum   += record.value.value;
      }

      if( count == 0 ){ return false; }
      return context.enqueueCommand( TestCommand, .{ .value = sum });
    }
  };

  var manager : RuleManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  var activeEntities : std.AutoHashMap( EntityId, void ) = .init( std.testing.allocator );
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
  try std.testing.expect( events.emit( TestEvent, .{ .value = 10 }));
  try std.testing.expect( events.emit( TestEvent, .{ .value = 32 }));

  var context : RuleContext =
  .{
    .activeEntities  = &activeEntities,
    .compManager     = &comps,
    .relationManager = &relations,
    .traitManager    = &traits,
    .eventManager    = &events,
    .commandManager  = &commands,
  };

  try std.testing.expect( manager.register( .{ .name = "event-sum", .runFn = Runner.run }));
  try std.testing.expect( manager.applyRules( &context ));

  try std.testing.expect( events.getEventCount( TestEvent ) == 2 );
  try std.testing.expect( commands.pop( TestCommand ).?.value.value == 42 );
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
      const comp = context.getComp( TestComp, entityId ) orelse return false;
      return context.enqueueCommand( TestCommand, .{ .entityId = entityId, .value = comp.value + 1 });
    }
  };

  var manager : RuleManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  var activeEntities : std.AutoHashMap( EntityId, void ) = .init( std.testing.allocator );
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

  try std.testing.expect( comps.register(    TestComp ));
  try std.testing.expect( commands.register( TestCommand ));

  Runner.entityId = 1;
  try activeEntities.put( Runner.entityId, {} );
  try std.testing.expect( comps.getStore( TestComp ).?.add( Runner.entityId, .{ .value = 41 }));

  var context : RuleContext =
  .{
    .activeEntities  = &activeEntities,
    .compManager     = &comps,
    .relationManager = &relations,
    .traitManager    = &traits,
    .eventManager    = &events,
    .commandManager  = &commands,
  };

  try std.testing.expect( manager.register( .{ .name = "fact-reader", .runFn = Runner.run }));
  try std.testing.expect( manager.applyRules( &context ));

  const record = commands.pop( TestCommand ).?;
  try std.testing.expect( record.value.entityId == Runner.entityId );
  try std.testing.expect( record.value.value    == 42 );
}

test "RuleManager rejects uninitialized use"
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
  var activeEntities : std.AutoHashMap( EntityId, void ) = .init( std.testing.allocator );
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

  var context : RuleContext =
  .{
    .activeEntities  = &activeEntities,
    .compManager     = &comps,
    .relationManager = &relations,
    .traitManager    = &traits,
    .eventManager    = &events,
    .commandManager  = &commands,
  };

  try std.testing.expect( !manager.register( .{ .name = "reaction", .runFn = Runner.run }));
  try std.testing.expect( !manager.applyRules( &context ));

  manager.init( std.testing.allocator );
  defer manager.deinit();

  try std.testing.expect( manager.register( .{ .name = "reaction", .runFn = Runner.run }));
  try std.testing.expect( manager.applyRules( &context ));
}
