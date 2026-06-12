const std = @import( "std" );
const utl = @import( "utils" );

const evt      = @import( "event.zig" );
const evtQueue = @import( "eventQueue.zig" );


/// Owns all typed event queues for a World.
/// Queues are registered by event payload type and keyed internally by `@typeName`.
pub const EventManager = struct
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

  /// Initializes the typed queue registry and event sequence counters.
  pub fn init( self : *EventManager, alloc : std.mem.Allocator ) void
  {
    if( self.isInit )
    {
      utl.qlog( .WARN, @src(), "EventManager is already initialized : returning" );
      return;
    }

    self.alloc         = alloc;
    self.queues        = .init( alloc );
    self.nextSequence  = 0;
    self.nextTickOrder = 0;
    self.baseTickIndex = null;
    self.isInit        = true;
  }

  /// Deinitializes and destroys every registered typed queue.
  pub fn deinit( self : *EventManager ) void
  {
    if( !self.isInit )
    {
      utl.qlog( .WARN, @src(), "EventManager is uninitialized : returning" );
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

  /// Registers a queue for one event payload type.
  /// Duplicate registration returns false and keeps the existing queue.
  pub fn register( self : *EventManager, comptime EventType : type ) bool
  {
    const typeName = @typeName( EventType );

    if( !self.isInit )
    {
      utl.log( .WARN, @src(), "Cannot register EventQueue for type {s} : EventManager is uninitialized", .{ typeName });
      return false;
    }
    if( self.queues.contains( typeName ))
    {
      utl.log( .WARN, @src(), "Cannot register EventQueue for type {s} : type already registered", .{ typeName });
      return false;
    }

    const QueueType = evtQueue.EventQueueFactory( EventType );
    const queue = self.alloc.create( QueueType ) catch
    {
      utl.log( .ERROR, @src(), "Failed to allocate EventQueue for type {s}", .{ typeName });
      return false;
    };

    queue.* = .{};
    queue.init( self.alloc );

    self.queues.put( typeName,
    .{
      .queuePtr        = queue,
      .deinitDestroyFn = deinitDestroyQueue( EventType ),
      .clearFn         = clearQueue(        EventType ),
      .countFn         = countQueue(        EventType ),
    })
    catch
    {
      utl.log( .ERROR, @src(), "Failed to register EventQueue for type {s}", .{ typeName });

      queue.deinit();
      self.alloc.destroy( queue );
      return false;
    };

    return true;
  }

  /// Removes and destroys the queue for one event payload type.
  pub fn unregister( self : *EventManager, comptime EventType : type ) bool
  {
    const typeName = @typeName( EventType );

    if( !self.isInit )
    {
      utl.log( .WARN, @src(), "Cannot unregister EventQueue for type {s} : EventManager is uninitialized", .{ typeName });
      return false;
    }

    const entry = self.queues.get( typeName ) orelse
    {
      utl.log( .DEBUG, @src(), "Cannot unregister EventQueue for type {s} : type not registered", .{ typeName });
      return false;
    };

    if( !self.queues.remove( typeName )){ return false; }
    entry.deinitDestroyFn( self.alloc, entry.queuePtr );
    return true;
  }

  /// Returns the typed queue for direct access, or null if unregistered.
  pub fn getQueue( self : *EventManager, comptime EventType : type ) ?*evtQueue.EventQueueFactory( EventType )
  {
    const typeName = @typeName( EventType );

    if( !self.isInit )
    {
      utl.log( .WARN, @src(), "Cannot get EventQueue for type {s} : EventManager is uninitialized", .{ typeName });
      return null;
    }

    const entry = self.queues.get( typeName ) orelse return null;
    return @ptrCast( @alignCast( entry.queuePtr ));
  }

  /// Returns true when an event type has a registered queue.
  pub inline fn hasQueue( self : *const EventManager, comptime EventType : type ) bool
  {
    if( !self.isInit ){ return false; }
    return self.queues.contains( @typeName( EventType ));
  }

  /// Appends an event with global sequence, tick order, and inferred entity metadata.
  pub fn emit( self : *EventManager, comptime EventType : type, value : EventType ) bool
  {
    const queue = self.getQueue( EventType ) orelse return false;
    const meta  = self.makeEventMeta( evt.inferPrimaryEntity( EventType, value ));

    if( !queue.pushRecord( .{ .meta = meta, .value = value })){ return false; }

    self.nextSequence  +%= 1;
    self.nextTickOrder +%= 1;
    return true;
  }

  /// Pops the oldest event record for one type.
  pub fn pop( self : *EventManager, comptime EventType : type ) ?evt.EventRecord( EventType )
  {
    const queue = self.getQueue( EventType ) orelse return null;
    return queue.pop();
  }

  /// Clears queued records for one event type.
  pub fn clear( self : *EventManager, comptime EventType : type ) bool
  {
    const queue = self.getQueue( EventType ) orelse return false;

    queue.clear();
    return true;
  }

  /// Counts queued records for one event type.
  pub fn count( self : *EventManager, comptime EventType : type ) usize
  {
    const queue = self.getQueue( EventType ) orelse return 0;
    return queue.count();
  }

  /// Clears every registered event queue without unregistering any type.
  pub fn clearAll( self : *EventManager ) void
  {
    if( !self.isInit )
    {
      utl.log( .WARN, @src(), "Cannot clear EventManager : uninitialized", .{} );
      return;
    }

    var iter = self.queues.valueIterator();
    while( iter.next() )| entry |{ entry.clearFn( entry.queuePtr ); }
  }

  /// Counts queued records across every registered event queue.
  pub fn countAll( self : *EventManager ) usize
  {
    if( !self.isInit ){ return 0; }

    var total : usize = 0;
    var iter = self.queues.valueIterator();
    while( iter.next() )| entry |{ total += entry.countFn( entry.queuePtr ); }

    return total;
  }

  /// Starts metadata for a World tick and resets tick-local ordering.
  pub fn beginTick( self : *EventManager, baseTickIndex : u128 ) void
  {
    if( !self.isInit )
    {
      utl.log( .WARN, @src(), "Cannot begin EventManager tick : uninitialized", .{} );
      return;
    }

    self.baseTickIndex = baseTickIndex;
    self.nextTickOrder = 0;
  }


  // ================================ INTERNAL FUNCTIONS ================================

  fn makeEventMeta( self : *EventManager, primaryEntity : ?evt.EntityId ) evt.EventMeta
  {
    return .{
      .sequence      = self.nextSequence,
      .tickOrder     = self.nextTickOrder,
      .baseTickIndex = self.baseTickIndex,
      .primaryEntity = primaryEntity,
    };
  }

  fn deinitDestroyQueue( comptime EventType : type ) *const fn ( std.mem.Allocator, *anyopaque ) void
  {
    return struct
    {
      fn call( alloc : std.mem.Allocator, queuePtr : *anyopaque ) void
      {
        const queue : *evtQueue.EventQueueFactory( EventType ) = @ptrCast( @alignCast( queuePtr ));

        queue.deinit();
        alloc.destroy( queue );
      }
    }.call;
  }

  fn clearQueue( comptime EventType : type ) *const fn ( *anyopaque ) void
  {
    return struct
    {
      fn call( queuePtr : *anyopaque ) void
      {
        const queue : *evtQueue.EventQueueFactory( EventType ) = @ptrCast( @alignCast( queuePtr ));
        queue.clear();
      }
    }.call;
  }

  fn countQueue( comptime EventType : type ) *const fn ( *anyopaque ) usize
  {
    return struct
    {
      fn call( queuePtr : *anyopaque ) usize
      {
        const queue : *evtQueue.EventQueueFactory( EventType ) = @ptrCast( @alignCast( queuePtr ));
        return queue.count();
      }
    }.call;
  }
};


// ================================ TESTS ================================

test "EventManager owns typed queue registration and lifecycle"
{
  const TestEvent = struct
  {
    value : u32 = 0,
  };

  var manager : EventManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  try std.testing.expect(  manager.register( TestEvent ));
  try std.testing.expect( !manager.register( TestEvent ));
  try std.testing.expect(  manager.getQueue( TestEvent ) != null );

  try std.testing.expect(  manager.unregister( TestEvent ));
  try std.testing.expect(  manager.getQueue(   TestEvent ) == null );
  try std.testing.expect(  manager.register(   TestEvent ));
}

test "EventManager emits pops and preserves global metadata order"
{
  const TestEvent = struct
  {
    entityId : evt.EntityId = 0,
    value    : u32          = 0,
  };

  var manager : EventManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  try std.testing.expect( manager.register( TestEvent ));

  manager.beginTick( 5 );

  try std.testing.expect( manager.emit( TestEvent, .{ .entityId = 11, .value = 10 }));
  try std.testing.expect( manager.emit( TestEvent, .{ .entityId = 12, .value = 20 }));
  try std.testing.expect( manager.count( TestEvent ) == 2 );

  const first  = manager.pop( TestEvent ).?;
  const second = manager.pop( TestEvent ).?;

  try std.testing.expect( first.value.value          == 10 );
  try std.testing.expect( second.value.value         == 20 );
  try std.testing.expect( first.meta.sequence        == 0  );
  try std.testing.expect( second.meta.sequence       == 1  );
  try std.testing.expect( first.meta.tickOrder       == 0  );
  try std.testing.expect( second.meta.tickOrder      == 1  );
  try std.testing.expect( first.meta.baseTickIndex.? == 5 );
  try std.testing.expect( first.meta.primaryEntity.? == 11 );
}

test "EventManager clears typed and all queues"
{
  const EventA = struct
  {
    value : u32 = 0,
  };
  const EventB = struct
  {
    value : u32 = 0,
  };

  var manager : EventManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  try std.testing.expect( manager.register( EventA ));
  try std.testing.expect( manager.register( EventB ));
  try std.testing.expect( manager.emit( EventA, .{ .value = 1 }));
  try std.testing.expect( manager.emit( EventB, .{ .value = 2 }));
  try std.testing.expect( manager.countAll() == 2 );

  try std.testing.expect( manager.clear( EventA ));
  try std.testing.expect( manager.count( EventA ) == 0 );
  try std.testing.expect( manager.count( EventB ) == 1 );

  manager.clearAll();
  try std.testing.expect( manager.countAll() == 0 );
}

test "EventManager rejects uninitialized and unregistered operations"
{
  const TestEvent = struct
  {
    value : u32 = 0,
  };

  var manager : EventManager = .{};

  try std.testing.expect( !manager.register( TestEvent ));
  try std.testing.expect( !manager.emit( TestEvent, .{ .value = 1 }));
  try std.testing.expect(  manager.pop( TestEvent ) == null );
  try std.testing.expect( !manager.clear( TestEvent ));

  manager.init( std.testing.allocator );
  defer manager.deinit();

  try std.testing.expect( !manager.emit( TestEvent, .{ .value = 2 }));
  try std.testing.expect(  manager.pop( TestEvent ) == null );
  try std.testing.expect( !manager.clear( TestEvent ));
}

test "EventManager deinit releases registered queues"
{
  const TestEvent = struct
  {
    value : u32 = 0,
  };

  var manager : EventManager = .{};
  manager.init( std.testing.allocator );

  try std.testing.expect( manager.register( TestEvent ));
  try std.testing.expect( manager.emit( TestEvent, .{ .value = 1 }));

  manager.deinit();
  try std.testing.expect( !manager.isInit );
  try std.testing.expect( manager.countAll() == 0 );
}
