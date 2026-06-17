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
  };

  alloc  : std.mem.Allocator                = undefined,
  queues : std.StringHashMap( QueueEntry ) = undefined,

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

    self.alloc         = alloc;
    self.queues        = .init( alloc );
    self.nextSequence  = 0;
    self.nextTickOrder = 0;
    self.baseTickIndex = null;
    self.isInit        = true;
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
    self.nextSequence  = 0;
    self.nextTickOrder = 0;
    self.baseTickIndex = null;
    self.isInit        = false;
  }


  // ================================ QUEUE FUNCTIONS ================================

  /// Registers a queue for one command payload type.
  /// Duplicate registration returns false and keeps the existing queue.
  pub fn register( self : *CommandManager, comptime CommandType : type ) bool
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

    self.queues.put( typeName,
    .{
      .queuePtr        = queue,
      .deinitDestroyFn = deinitDestroyQueue( CommandType ),
      .clearFn         = clearQueue(        CommandType ),
      .countFn         = countQueue(        CommandType ),
    })
    catch
    {
      utl.log( .ERROR, @src(), "Failed to register CommandQueue for type {s}", .{ typeName });

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
