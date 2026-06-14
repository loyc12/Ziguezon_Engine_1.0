const std = @import( "std" );
const utl = @import( "utils" );

const evt = @import( "event.zig" );


/// Builds a transient FIFO queue for one plain Zig event type.
/// Most game code should use `World.emitEvent` / `World.popEvent` instead of
/// owning queues directly.
pub fn EventQueueFactory( comptime EventType : type ) type
{
  return struct
  {
    const TypeName = @typeName( EventType );
    const Queue    = @This();
    const Record   = evt.EventRecord( EventType );

    /// Iterates queued records without popping them.
    /// The iterator becomes stale when the queue is cleared, popped, or deinitialized.
    pub const ConstIterator = struct
    {
      records : []const Record = &[_]Record{},
      index   : usize          = 0,

      pub fn next( self : *ConstIterator ) ?*const Record
      {
        if( self.index >= self.records.len ){ return null; }

        const index = self.index;
        self.index += 1;
        return &self.records[ index ];
      }
    };

    alloc   : std.mem.Allocator       = undefined,
    records : std.ArrayList( Record ) = .empty,

    nextSequence : u64  = 0,
    isInit       : bool = false,


    // ================================ LIFECYCLE FUNCTIONS ================================

    /// Initializes queue storage. Must be called before push/pop operations.
    pub fn init( self : *Queue, alloc : std.mem.Allocator ) void
    {
      if( self.isInit )
      {
        utl.log( .WARN, @src(), "EventQueue for type {s} is already initialized : returning", .{ TypeName });
        return;
      }

      self.alloc        = alloc;
      self.records      = .empty;
      self.nextSequence = 0;
      self.isInit       = true;
    }

    /// Releases queued records and resets the queue to an unusable state.
    pub fn deinit( self : *Queue ) void
    {
      if( !self.isInit )
      {
        utl.log( .WARN, @src(), "EventQueue for type {s} is uninitialized : returning", .{ TypeName });
        return;
      }

      self.records.deinit( self.alloc );
      self.records      = .empty;
      self.nextSequence = 0;
      self.isInit       = false;
    }


    // ================================ QUEUE FUNCTIONS ================================

    /// Appends an event value with queue-local metadata.
    /// `EventManager.emit` is preferred when World tick/global sequence matters.
    pub fn push( self : *Queue, value : EventType ) bool
    {
      if( !self.isInit )
      {
        utl.log( .WARN, @src(), "Cannot push EventRecord for type {s} : EventQueue is uninitialized", .{ TypeName });
        return false;
      }

      const meta : evt.EventMeta =
      .{
        .sequence      = self.nextSequence,
        .tickOrder     = self.nextSequence,
        .primaryEntity = evt.inferPrimaryEntity( EventType, value ),
      };

      if( !self.pushRecord( .{ .meta = meta, .value = value })){ return false; }

      self.nextSequence +%= 1;
      return true;
    }

    /// Appends a fully-built record.
    /// Used by `EventManager` after it attaches World-level metadata.
    pub fn pushRecord( self : *Queue, record : Record ) bool
    {
      if( !self.isInit )
      {
        utl.log( .WARN, @src(), "Cannot push EventRecord for type {s} : EventQueue is uninitialized", .{ TypeName });
        return false;
      }

      self.records.append( self.alloc, record ) catch
      {
        utl.log( .ERROR, @src(), "Failed to push EventRecord for type {s}", .{ TypeName });
        return false;
      };

      return true;
    }

    /// Removes and returns the oldest record, or null if empty/uninitialized.
    pub fn pop( self : *Queue ) ?Record
    {
      if( !self.isInit )
      {
        utl.log( .WARN, @src(), "Cannot pop EventRecord for type {s} : EventQueue is uninitialized", .{ TypeName });
        return null;
      }

      if( self.records.items.len == 0 ){ return null; }
      return self.records.orderedRemove( 0 );
    }

    /// Returns a read-only record pointer without removing it.
    pub fn peek( self : *const Queue, index : usize ) ?*const Record
    {
      if( !self.isInit )
      {
        utl.log( .WARN, @src(), "Cannot inspect EventRecord for type {s} : EventQueue is uninitialized", .{ TypeName });
        return null;
      }
      if( index >= self.records.items.len ){ return null; }

      return &self.records.items[ index ];
    }

    /// Returns the number of queued records.
    pub inline fn getEventCount( self : *const Queue ) usize
    {
      if( !self.isInit ){ return 0; }
      return self.records.items.len;
    }

    /// Returns a read-only iterator over currently queued records.
    pub fn getIteratorConst( self : *const Queue ) ConstIterator
    {
      if( !self.isInit )
      {
        utl.log( .WARN, @src(), "Cannot inspect EventQueue for type {s} : uninitialized", .{ TypeName });
        return .{};
      }

      return .{ .records = self.records.items };
    }

    /// Drops queued records while keeping allocated capacity for reuse.
    pub fn clear( self : *Queue ) void
    {
      if( !self.isInit )
      {
        utl.log( .WARN, @src(), "Cannot clear EventQueue for type {s} : uninitialized", .{ TypeName });
        return;
      }

      self.records.clearRetainingCapacity();
    }
  };
}


// ================================ TESTS ================================

test "EventQueue push pop preserves insertion order"
{
  const TestEvent = struct
  {
    value : u32 = 0,
  };

  var queue : EventQueueFactory( TestEvent ) = .{};
  queue.init( std.testing.allocator );
  defer queue.deinit();

  try std.testing.expect( queue.push( .{ .value = 10 }));
  try std.testing.expect( queue.push( .{ .value = 20 }));
  try std.testing.expect( queue.getEventCount() == 2 );

  const first  = queue.pop().?;
  const second = queue.pop().?;

  try std.testing.expect( first.value.value  == 10 );
  try std.testing.expect( second.value.value == 20 );
  try std.testing.expect( first.meta.sequence  == 0 );
  try std.testing.expect( second.meta.sequence == 1 );
  try std.testing.expect( queue.pop() == null );
}

test "EventQueue supports empty pop clear and dataless facts"
{
  const Dataless = struct {};

  var queue : EventQueueFactory( Dataless ) = .{};
  queue.init( std.testing.allocator );
  defer queue.deinit();

  try std.testing.expect( queue.pop() == null );
  try std.testing.expect( queue.push( .{} ));
  try std.testing.expect( queue.push( .{} ));
  try std.testing.expect( queue.getEventCount() == 2 );

  queue.clear();

  try std.testing.expect( queue.getEventCount() == 0 );
  try std.testing.expect( queue.pop() == null );
}

test "EventQueue deinit releases storage"
{
  const TestEvent = struct
  {
    value : u32 = 0,
  };

  var queue : EventQueueFactory( TestEvent ) = .{};
  queue.init( std.testing.allocator );

  try std.testing.expect( queue.push( .{ .value = 1 }));

  queue.deinit();
  try std.testing.expect( !queue.isInit );
  try std.testing.expect( queue.getEventCount() == 0 );
}
