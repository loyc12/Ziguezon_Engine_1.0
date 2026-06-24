const std = @import( "std" );
const utl = @import( "utils" );

const cmd      = @import( "command.zig" );
const cmdQueue = @import( "commandQueue.zig" );


/// Owns all typed command queues for a World.
/// Queues are registered by command payload type and remain transient.
pub const CommandManager = struct
{
  const QueueEntry = struct
  {
    queuePtr        : *anyopaque,
    deinitDestroyFn : *const fn ( std.mem.Allocator, *anyopaque ) void,
    clearFn         : *const fn ( *anyopaque ) void,
    countFn         : *const fn ( *anyopaque ) usize,
    execAllFn       : *const fn ( *anyopaque, *cmd.CommandContext ) cmd.CommandExecResult,
  };

  alloc             : std.mem.Allocator               = undefined,
  queues            : std.StringHashMap( QueueEntry ) = undefined,
  registrationOrder : std.ArrayList( []const u8 )     = .empty,

  nextSequence  : u64   = 0,
  nextTickOrder : u64   = 0,
  baseTickIndex : ?u128 = null,

  isInit : bool = false,


  // ================================ LIFECYCLE FUNCTIONS ================================

  /// Initializes the typed queue registry and command sequence counters.
  pub fn init( self : *CommandManager, alloc : std.mem.Allocator ) void
  {
    if( self.isInit )
    {
      utl.qlog( .WARN, @src(), "CommandManager is already initialized : returning" );
      return;
    }

    self.alloc             = alloc;
    self.queues            = .init( alloc );
    self.registrationOrder = .empty;
    self.nextSequence      = 0;
    self.nextTickOrder     = 0;
    self.baseTickIndex     = null;
    self.isInit            = true;
  }

  /// Deinitializes and destroys every registered typed command queue.
  pub fn deinit( self : *CommandManager ) void
  {
    if( !self.isInit )
    {
      utl.qlog( .WARN, @src(), "CommandManager is uninitialized : returning" );
      return;
    }

    var iter = self.queues.valueIterator();
    while( iter.next() )| entry |{ entry.deinitDestroyFn( self.alloc, entry.queuePtr ); }

    self.queues.deinit();
    self.registrationOrder.deinit( self.alloc );
    self.registrationOrder = .empty;
    self.nextSequence      = 0;
    self.nextTickOrder     = 0;
    self.baseTickIndex     = null;
    self.isInit            = false;
  }


  // ================================ QUEUE FUNCTIONS ================================

  /// Registers a queue for one command payload type.
  /// Duplicate registration returns false and keeps the existing queue.
  pub fn register( self : *CommandManager, comptime CommandType : type ) bool
  {
    return self.registerInternal( CommandType, null );
  }

  /// Registers one executable command payload type and its drain callback.
  /// The callback cannot be replaced without unregistering the command type.
  pub fn registerExec( self : *CommandManager, comptime CommandType : type, execFn : cmd.CommandExecFn( CommandType )) bool
  {
    return self.registerInternal( CommandType, execFn );
  }

  fn registerInternal( self : *CommandManager, comptime CommandType : type, execFn : ?cmd.CommandExecFn( CommandType )) bool
  {
    const typeName = @typeName( CommandType );

    if( !self.isInit )
    {
      utl.log( .WARN, @src(), "Cannot register CommandQueue for type {s} : CommandManager is uninitialized", .{ typeName });
      return false;
    }
    if( self.queues.contains( typeName ))
    {
      utl.log( .WARN, @src(), "Cannot register CommandQueue for type {s} : type already registered", .{ typeName });
      return false;
    }

    const QueueType = cmdQueue.CommandQueueFactory( CommandType );
    const queue = self.alloc.create( QueueType ) catch
    {
      utl.log( .ERROR, @src(), "Failed to allocate CommandQueue for type {s}", .{ typeName });
      return false;
    };

    queue.* = .{};
    queue.init( self.alloc );
    queue.execFn = execFn;

    self.registrationOrder.append( self.alloc, typeName ) catch
    {
      utl.log( .ERROR, @src(), "Failed to track CommandQueue registration order for type {s}", .{ typeName });

      queue.deinit();
      self.alloc.destroy( queue );
      return false;
    };

    self.queues.put( typeName,
    .{
      .queuePtr        = queue,
      .deinitDestroyFn = deinitDestroyQueue( CommandType ),
      .clearFn         = clearQueue(        CommandType ),
      .countFn         = countQueue(        CommandType ),
      .execAllFn       = execAllQueue(      CommandType ),
    })
    catch
    {
      utl.log( .ERROR, @src(), "Failed to register CommandQueue for type {s}", .{ typeName });

      _ = self.registrationOrder.orderedRemove( self.registrationOrder.items.len - 1 );
      queue.deinit();
      self.alloc.destroy( queue );
      return false;
    };

    return true;
  }

  /// Removes and destroys the queue for one command payload type.
  pub fn unregister( self : *CommandManager, comptime CommandType : type ) bool
  {
    const typeName = @typeName( CommandType );

    if( !self.isInit )
    {
      utl.log( .WARN, @src(), "Cannot unregister CommandQueue for type {s} : CommandManager is uninitialized", .{ typeName });
      return false;
    }

    const entry = self.queues.get( typeName ) orelse
    {
      utl.log( .DEBUG, @src(), "Cannot unregister CommandQueue for type {s} : type not registered", .{ typeName });
      return false;
    };

    if( !self.queues.remove( typeName )){ return false; }
    self.removeRegisteredType( typeName );
    entry.deinitDestroyFn( self.alloc, entry.queuePtr );
    return true;
  }

  /// Returns the typed queue for direct inspection, or null if unregistered.
  pub fn getQueue( self : *CommandManager, comptime CommandType : type ) ?*cmdQueue.CommandQueueFactory( CommandType )
  {
    const typeName = @typeName( CommandType );

    if( !self.isInit )
    {
      utl.log( .WARN, @src(), "Cannot get CommandQueue for type {s} : CommandManager is uninitialized", .{ typeName });
      return null;
    }

    const entry = self.queues.get( typeName ) orelse return null;
    return @ptrCast( @alignCast( entry.queuePtr ));
  }

  /// Returns true when a command type has a registered queue.
  pub inline fn hasQueue( self : *const CommandManager, comptime CommandType : type ) bool
  {
    if( !self.isInit ){ return false; }
    return self.queues.contains( @typeName( CommandType ));
  }

  /// Appends a command with global sequence and tick-order metadata.
  pub fn enqueue( self : *CommandManager, comptime CommandType : type, value : CommandType ) bool
  {
    const queue = self.getQueue( CommandType ) orelse return false;
    const meta  = self.makeCommandMeta();

    if( !queue.pushRecord( .{ .meta = meta, .value = value })){ return false; }

    self.nextSequence  +%= 1;
    self.nextTickOrder +%= 1;
    return true;
  }

  /// Pops the oldest command record for one type.
  pub fn pop( self : *CommandManager, comptime CommandType : type ) ?cmd.CommandRecord( CommandType )
  {
    const queue = self.getQueue( CommandType ) orelse return null;
    return queue.pop();
  }

  /// Clears queued commands for one command type.
  pub fn clear( self : *CommandManager, comptime CommandType : type ) bool
  {
    const queue = self.getQueue( CommandType ) orelse return false;

    queue.clear();
    return true;
  }

  /// Counts queued commands for one command type.
  pub fn getCommandCount( self : *CommandManager, comptime CommandType : type ) usize
  {
    const queue = self.getQueue( CommandType ) orelse return 0;
    return queue.getCommandCount();
  }

  /// Executes queued commands of one registered command type.
  /// `amount == 0` executes all records queued for that type at call start.
  pub fn execCommandType( self : *CommandManager, comptime CommandType : type, amount : usize, context : *cmd.CommandContext ) cmd.CommandExecResult
  {
    var result : cmd.CommandExecResult = .{};
    const typeName = @typeName( CommandType );

    if( !self.isInit )
    {
      utl.log( .ERROR, @src(), "Cannot execute Commands for type {s} : CommandManager is uninitialized", .{ typeName });
      result.failed = 1;
      return result;
    }

    const queue = self.getQueue( CommandType ) orelse
    {
      utl.log( .ERROR, @src(), "Cannot execute Commands for type {s} : queue is not registered", .{ typeName });
      result.failed = 1;
      return result;
    };

    return queue.execCommands( amount, context );
  }

  /// Executes every registered command type once in registration order.
  /// Queue-only types without queued records are a no-op; queued records without
  /// callbacks produce visible failures without blocking later command types.
  pub fn execAllCommands( self : *CommandManager, context : *cmd.CommandContext ) cmd.CommandExecResult
  {
    var result : cmd.CommandExecResult = .{};

    if( !self.isInit )
    {
      utl.log( .ERROR, @src(), "Cannot execute all Commands : CommandManager is uninitialized", .{} );
      result.failed = 1;
      return result;
    }

    for( self.registrationOrder.items )| typeName |
    {
      const entry = self.queues.get( typeName ) orelse
      {
        utl.log( .ERROR, @src(), "Cannot execute Commands for type {s} : registration order points to a missing queue", .{ typeName });
        result.failed += 1;
        continue;
      };

      const typeResult = entry.execAllFn( entry.queuePtr, context );
      result.attempted += typeResult.attempted;
      result.succeeded += typeResult.succeeded;
      result.failed    += typeResult.failed;
    }

    return result;
  }

  /// Clears every registered command queue without unregistering any type.
  pub fn clearAll( self : *CommandManager ) void
  {
    if( !self.isInit )
    {
      utl.log( .WARN, @src(), "Cannot clear CommandManager : uninitialized", .{} );
      return;
    }

    var iter = self.queues.valueIterator();
    while( iter.next() )| entry |{ entry.clearFn( entry.queuePtr ); }
  }

  /// Counts queued commands across every registered command queue.
  pub fn getTotalCommandCount( self : *CommandManager ) usize
  {
    if( !self.isInit ){ return 0; }

    var total : usize = 0;
    var iter = self.queues.valueIterator();
    while( iter.next() )| entry |{ total += entry.countFn( entry.queuePtr ); }

    return total;
  }

  /// Starts metadata for a World tick and resets tick-local ordering.
  pub fn beginTick( self : *CommandManager, baseTickIndex : u128 ) void
  {
    if( !self.isInit )
    {
      utl.log( .WARN, @src(), "Cannot begin CommandManager tick : uninitialized", .{} );
      return;
    }

    self.baseTickIndex = baseTickIndex;
    self.nextTickOrder = 0;
  }


  // ================================ INTERNAL FUNCTIONS ================================

  fn makeCommandMeta( self : *CommandManager ) cmd.CommandMeta
  {
    return .{
      .sequence      = self.nextSequence,
      .tickOrder     = self.nextTickOrder,
      .baseTickIndex = self.baseTickIndex,
    };
  }

  fn deinitDestroyQueue( comptime CommandType : type ) *const fn ( std.mem.Allocator, *anyopaque ) void
  {
    return struct
    {
      fn call( alloc : std.mem.Allocator, queuePtr : *anyopaque ) void
      {
        const queue : *cmdQueue.CommandQueueFactory( CommandType ) = @ptrCast( @alignCast( queuePtr ));

        queue.deinit();
        alloc.destroy( queue );
      }
    }.call;
  }

  fn clearQueue( comptime CommandType : type ) *const fn ( *anyopaque ) void
  {
    return struct
    {
      fn call( queuePtr : *anyopaque ) void
      {
        const queue : *cmdQueue.CommandQueueFactory( CommandType ) = @ptrCast( @alignCast( queuePtr ));
        queue.clear();
      }
    }.call;
  }

  fn countQueue( comptime CommandType : type ) *const fn ( *anyopaque ) usize
  {
    return struct
    {
      fn call( queuePtr : *anyopaque ) usize
      {
        const queue : *cmdQueue.CommandQueueFactory( CommandType ) = @ptrCast( @alignCast( queuePtr ));
        return queue.getCommandCount();
      }
    }.call;
  }

  fn execAllQueue( comptime CommandType : type ) *const fn ( *anyopaque, *cmd.CommandContext ) cmd.CommandExecResult
  {
    return struct
    {
      fn call( queuePtr : *anyopaque, context : *cmd.CommandContext ) cmd.CommandExecResult
      {
        const queue : *cmdQueue.CommandQueueFactory( CommandType ) = @ptrCast( @alignCast( queuePtr ));
        return queue.execAllCommands( context );
      }
    }.call;
  }

  fn removeRegisteredType( self : *CommandManager, typeName : []const u8 ) void
  {
    for( self.registrationOrder.items, 0.. )| registeredName, index |
    {
      if( std.mem.eql( u8, registeredName, typeName ))
      {
        _ = self.registrationOrder.orderedRemove( index );
        return;
      }
    }
  }
};


// ================================ TESTS ================================

test "CommandManager owns typed queue registration and lifecycle"
{
  const TestCommand = struct
  {
    value : u32 = 0,
  };

  var manager : CommandManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  try std.testing.expect(  manager.register( TestCommand ));
  try std.testing.expect( !manager.register( TestCommand ));
  try std.testing.expect(  manager.getQueue( TestCommand ) != null );

  try std.testing.expect(  manager.unregister( TestCommand ));
  try std.testing.expect(  manager.getQueue(   TestCommand ) == null );
  try std.testing.expect(  manager.register(   TestCommand ));
}

test "CommandManager enqueues pops and preserves global metadata order"
{
  const TestCommand = struct
  {
    entityId : u32 = 0,
    value    : u32 = 0,
  };

  var manager : CommandManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  try std.testing.expect( manager.register( TestCommand ));

  manager.beginTick( 5 );

  try std.testing.expect( manager.enqueue( TestCommand, .{ .entityId = 11, .value = 10 }));
  try std.testing.expect( manager.enqueue( TestCommand, .{ .entityId = 12, .value = 20 }));
  try std.testing.expect( manager.getCommandCount( TestCommand ) == 2 );

  const first  = manager.pop( TestCommand ).?;
  const second = manager.pop( TestCommand ).?;

  try std.testing.expect( first.value.value          == 10 );
  try std.testing.expect( second.value.value         == 20 );
  try std.testing.expect( first.meta.sequence        == 0  );
  try std.testing.expect( second.meta.sequence       == 1  );
  try std.testing.expect( first.meta.tickOrder       == 0  );
  try std.testing.expect( second.meta.tickOrder      == 1  );
  try std.testing.expect( first.meta.baseTickIndex.? == 5 );
}

test "CommandManager clears typed and all queues"
{
  const CommandA = struct
  {
    value : u32 = 0,
  };
  const CommandB = struct
  {
    value : u32 = 0,
  };

  var manager : CommandManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  try std.testing.expect( manager.register( CommandA ));
  try std.testing.expect( manager.register( CommandB ));
  try std.testing.expect( manager.enqueue( CommandA, .{ .value = 1 }));
  try std.testing.expect( manager.enqueue( CommandB, .{ .value = 2 }));
  try std.testing.expect( manager.getTotalCommandCount() == 2 );

  try std.testing.expect( manager.clear( CommandA ));
  try std.testing.expect( manager.getCommandCount( CommandA ) == 0 );
  try std.testing.expect( manager.getCommandCount( CommandB ) == 1 );

  manager.clearAll();
  try std.testing.expect( manager.getTotalCommandCount() == 0 );
}

test "CommandManager rejects uninitialized and unregistered operations"
{
  const TestCommand = struct
  {
    value : u32 = 0,
  };

  var manager : CommandManager = .{};

  try std.testing.expect( !manager.register(        TestCommand ));
  try std.testing.expect(  manager.getQueue(        TestCommand ) == null );
  try std.testing.expect( !manager.enqueue(         TestCommand, .{ .value = 1 }));
  try std.testing.expect(  manager.pop(             TestCommand ) == null );
  try std.testing.expect(  manager.getCommandCount( TestCommand ) == 0 );

  manager.init( std.testing.allocator );
  defer manager.deinit();

  try std.testing.expect( !manager.enqueue(    TestCommand, .{ .value = 1 }));
  try std.testing.expect( !manager.clear(      TestCommand ));
  try std.testing.expect( !manager.unregister( TestCommand ));
}

test "CommandManager registers executable queues and rejects replacement"
{
  const TestCommand = struct
  {
    value : u32 = 0,
  };

  const Runner = struct
  {
    fn exec( context : *cmd.CommandContext, record : cmd.CommandRecord( TestCommand )) bool
    {
      _ = context;
      _ = record;
      return true;
    }
  };

  var manager : CommandManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  try std.testing.expect(  manager.registerExec( TestCommand, Runner.exec ));
  try std.testing.expect( !manager.registerExec( TestCommand, Runner.exec ));
  try std.testing.expect( !manager.register(     TestCommand ));
}

test "CommandManager reports missing queue and missing callback execution failures"
{
  const MissingCommand = struct
  {
    value : u32 = 0,
  };
  const NoCallbackCommand = struct
  {
    value : u32 = 0,
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

  var context : cmd.CommandContext =
  .{
    .activeEntities  = &activeEntities,
    .compManager     = &comps,
    .relationManager = &relations,
    .traitManager    = &traits,
    .eventManager    = &events,
  };

  var manager : CommandManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  const missingQueue = manager.execCommandType( MissingCommand, 0, &context );
  try std.testing.expect( missingQueue.attempted == 0 );
  try std.testing.expect( missingQueue.failed    == 1 );

  try std.testing.expect( manager.register( NoCallbackCommand ));
  try std.testing.expect( manager.enqueue(  NoCallbackCommand, .{ .value = 1 }));

  const missingCallback = manager.execCommandType( NoCallbackCommand, 0, &context );
  try std.testing.expect( missingCallback.attempted == 1 );
  try std.testing.expect( missingCallback.failed    == 1 );
  try std.testing.expect( manager.getCommandCount( NoCallbackCommand ) == 0 );
}

test "CommandManager executes all commands in registration order and keeps later work running"
{
  const EarlyCommand = struct
  {
    value : u32 = 0,
  };
  const EmptyNoCallbackCommand = struct
  {
    value : u32 = 0,
  };
  const MissingCallbackCommand = struct
  {
    value : u32 = 0,
  };
  const LateCommand = struct
  {
    value : u32 = 0,
  };

  const Runner = struct
  {
    var order : [2]u32 = .{ 0, 0 };
    var count : usize  = 0;

    fn early( context : *cmd.CommandContext, record : cmd.CommandRecord( EarlyCommand )) bool
    {
      _ = context;

      order[ count ] = record.value.value;
      count += 1;
      return true;
    }

    fn late( context : *cmd.CommandContext, record : cmd.CommandRecord( LateCommand )) bool
    {
      _ = context;

      order[ count ] = record.value.value;
      count += 1;
      return true;
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

  var context : cmd.CommandContext =
  .{
    .activeEntities  = &activeEntities,
    .compManager     = &comps,
    .relationManager = &relations,
    .traitManager    = &traits,
    .eventManager    = &events,
  };

  var manager : CommandManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  Runner.order = .{ 0, 0 };
  Runner.count = 0;

  try std.testing.expect( manager.registerExec( EarlyCommand, Runner.early ));
  try std.testing.expect( manager.register(     EmptyNoCallbackCommand     ));
  try std.testing.expect( manager.register(     MissingCallbackCommand     ));
  try std.testing.expect( manager.registerExec( LateCommand,  Runner.late  ));

  try std.testing.expect( manager.enqueue( EarlyCommand,           .{ .value = 1 }));
  try std.testing.expect( manager.enqueue( MissingCallbackCommand, .{ .value = 2 }));
  try std.testing.expect( manager.enqueue( LateCommand,            .{ .value = 3 }));

  const result = manager.execAllCommands( &context );

  try std.testing.expect( result.attempted == 3 );
  try std.testing.expect( result.succeeded == 2 );
  try std.testing.expect( result.failed    == 1 );
  try std.testing.expect( Runner.order[ 0 ] == 1 );
  try std.testing.expect( Runner.order[ 1 ] == 3 );
  try std.testing.expect( manager.getCommandCount( MissingCallbackCommand ) == 0 );
}

test "CommandManager executes requested amount in FIFO order"
{
  const TestCommand = struct
  {
    value : u32 = 0,
  };

  const Runner = struct
  {
    var order : [2]u32 = .{ 0, 0 };
    var count : usize  = 0;

    fn exec( context : *cmd.CommandContext, record : cmd.CommandRecord( TestCommand )) bool
    {
      _ = context;

      order[ count ] = record.value.value;
      count += 1;

      return true;
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

  var context : cmd.CommandContext =
  .{
    .activeEntities  = &activeEntities,
    .compManager     = &comps,
    .relationManager = &relations,
    .traitManager    = &traits,
    .eventManager    = &events,
  };

  var manager : CommandManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  Runner.order = .{ 0, 0 };
  Runner.count = 0;

  try std.testing.expect( manager.registerExec( TestCommand, Runner.exec ));
  try std.testing.expect( manager.enqueue( TestCommand, .{ .value = 10 }));
  try std.testing.expect( manager.enqueue( TestCommand, .{ .value = 20 }));
  try std.testing.expect( manager.enqueue( TestCommand, .{ .value = 30 }));

  const result = manager.execCommandType( TestCommand, 2, &context );

  try std.testing.expect( result.attempted == 2 );
  try std.testing.expect( result.succeeded == 2 );
  try std.testing.expect( result.failed    == 0 );
  try std.testing.expect( manager.getCommandCount( TestCommand ) == 1 );
  try std.testing.expect( Runner.order[ 0 ] == 10 );
  try std.testing.expect( Runner.order[ 1 ] == 20 );
}
