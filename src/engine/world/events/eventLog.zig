const std = @import( "std" );
const utl = @import( "utils" );

const evt = @import( "event.zig" );


/// Optional bounded retention buffer for one event type.
/// This is for lightweight inspection/debugging only; replay/history tooling is deferred.
pub fn EventLogFactory( comptime EventType : type ) type
{
  return struct
  {
    const TypeName = @typeName( EventType );
    const Log      = @This();
    const Record   = evt.EventRecord( EventType );

    alloc       : std.mem.Allocator       = undefined,
    records     : std.ArrayList( Record ) = .empty,
    retainLimit : usize                   = 0,

    isInit : bool = false,


    // ================================ LIFECYCLE FUNCTIONS ================================

    /// Initializes the log with a maximum retained record count.
    /// A limit of 0 accepts appends but stores nothing.
    pub fn init( self : *Log, alloc : std.mem.Allocator, retainLimit : usize ) void
    {
      if( self.isInit )
      {
        utl.log( .WARN, 0, @src(), "EventLog for type {s} is already initialized : returning", .{ TypeName });
        return;
      }

      self.alloc       = alloc;
      self.records     = .empty;
      self.retainLimit = retainLimit;
      self.isInit      = true;
    }

    /// Releases retained records.
    pub fn deinit( self : *Log ) void
    {
      if( !self.isInit )
      {
        utl.log( .WARN, 0, @src(), "EventLog for type {s} is uninitialized : returning", .{ TypeName });
        return;
      }

      self.records.deinit( self.alloc );
      self.records     = .empty;
      self.retainLimit = 0;
      self.isInit      = false;
    }


    // ================================ LOG FUNCTIONS ================================

    /// Retains one record, dropping oldest records past `retainLimit`.
    pub fn append( self : *Log, record : Record ) bool
    {
      if( !self.isInit )
      {
        utl.log( .WARN, 0, @src(), "Cannot append EventRecord for type {s} : EventLog is uninitialized", .{ TypeName });
        return false;
      }
      if( self.retainLimit == 0 ){ return true; }

      self.records.append( self.alloc, record ) catch
      {
        utl.log( .ERROR, 0, @src(), "Failed to append EventRecord for type {s}", .{ TypeName });
        return false;
      };

      while( self.records.items.len > self.retainLimit )
      {
        _ = self.records.orderedRemove( 0 );
      }

      return true;
    }

    /// Returns the number of retained records.
    pub inline fn count( self : *const Log ) usize
    {
      if( !self.isInit ){ return 0; }
      return self.records.items.len;
    }

    /// Clears retained records while keeping capacity.
    pub fn clear( self : *Log ) void
    {
      if( !self.isInit )
      {
        utl.log( .WARN, 0, @src(), "Cannot clear EventLog for type {s} : uninitialized", .{ TypeName });
        return;
      }

      self.records.clearRetainingCapacity();
    }
  };
}


// ================================ TESTS ================================

test "EventLog optionally retains bounded records"
{
  const TestEvent = struct
  {
    value : u32 = 0,
  };

  var log : EventLogFactory( TestEvent ) = .{};
  log.init( std.testing.allocator, 2 );
  defer log.deinit();

  try std.testing.expect( log.append( .{ .meta = .{ .sequence = 0 }, .value = .{ .value = 10 }}));
  try std.testing.expect( log.append( .{ .meta = .{ .sequence = 1 }, .value = .{ .value = 20 }}));
  try std.testing.expect( log.append( .{ .meta = .{ .sequence = 2 }, .value = .{ .value = 30 }}));

  try std.testing.expect( log.count() == 2 );
  try std.testing.expect( log.records.items[ 0 ].value.value == 20 );
  try std.testing.expect( log.records.items[ 1 ].value.value == 30 );
}

test "EventLog retain limit zero records nothing"
{
  const TestEvent = struct
  {
    value : u32 = 0,
  };

  var log : EventLogFactory( TestEvent ) = .{};
  log.init( std.testing.allocator, 0 );
  defer log.deinit();

  try std.testing.expect( log.append( .{ .value = .{ .value = 10 }}));
  try std.testing.expect( log.count() == 0 );
}
