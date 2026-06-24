const std = @import( "std" );
const utl = @import( "utils" );

const cmd = @import( "command.zig" );


/// Builds a transient FIFO queue for one plain Zig command type.
/// Most runtime code should use `World.enqueueCommand` so metadata stays global.
pub fn CommandQueueFactory( comptime CommandType : type ) type
{
  return struct
  {
    const TypeName = @typeName( CommandType );
    const Queue    = @This();
    const Record   = cmd.CommandRecord( CommandType );
    const ExecFn   = cmd.CommandExecFn( CommandType );

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
    execFn  : ?ExecFn                 = null,

    nextSequence : u64  = 0,
    isInit       : bool = false,


    // ================================ LIFECYCLE FUNCTIONS ================================

    /// Initializes queue storage. Must be called before queue operations.
    pub fn init( self : *Queue, alloc : std.mem.Allocator ) void
    {
      if( self.isInit )
      {
        utl.log( .WARN, @src(), "CommandQueue for type {s} is already initialized : returning", .{ TypeName });
        return;
      }

      self.alloc        = alloc;
      self.records      = .empty;
      self.execFn       = null;
      self.nextSequence = 0;
      self.isInit       = true;
    }

    /// Releases queued commands and resets the queue to an unusable state.
    pub fn deinit( self : *Queue ) void
    {
      if( !self.isInit )
      {
        utl.log( .WARN, @src(), "CommandQueue for type {s} is uninitialized : returning", .{ TypeName });
        return;
      }

      self.records.deinit( self.alloc );
      self.records      = .empty;
      self.execFn       = null;
      self.nextSequence = 0;
      self.isInit       = false;
    }


    // ================================ QUEUE FUNCTIONS ================================

    /// Appends a command value with queue-local ordering metadata.
    /// `CommandManager.enqueue` is preferred when World tick/global order matters.
    pub fn push( self : *Queue, value : CommandType ) bool
    {
      if( !self.isInit )
      {
        utl.log( .WARN, @src(), "Cannot push CommandRecord for type {s} : CommandQueue is uninitialized", .{ TypeName });
        return false;
      }

      const meta : cmd.CommandMeta =
      .{
        .sequence  = self.nextSequence,
        .tickOrder = self.nextSequence,
      };

      if( !self.pushRecord( .{ .meta = meta, .value = value })){ return false; }

      self.nextSequence +%= 1;
      return true;
    }

    /// Appends a fully-built command record.
    /// Used by `CommandManager` after it attaches World-level metadata.
    pub fn pushRecord( self : *Queue, record : Record ) bool
    {
      if( !self.isInit )
      {
        utl.log( .WARN, @src(), "Cannot push CommandRecord for type {s} : CommandQueue is uninitialized", .{ TypeName });
        return false;
      }

      self.records.append( self.alloc, record ) catch
      {
        utl.log( .ERROR, @src(), "Failed to push CommandRecord for type {s}", .{ TypeName });
        return false;
      };

      return true;
    }

    /// Removes and returns the oldest command, or null if empty/uninitialized.
    pub fn pop( self : *Queue ) ?Record
    {
      if( !self.isInit )
      {
        utl.log( .WARN, @src(), "Cannot pop CommandRecord for type {s} : CommandQueue is uninitialized", .{ TypeName });
        return null;
      }

      if( self.records.items.len == 0 ){ return null; }
      return self.records.orderedRemove( 0 );
    }

    /// Returns a read-only command record pointer without removing it.
    pub fn peek( self : *const Queue, index : usize ) ?*const Record
    {
      if( !self.isInit )
      {
        utl.log( .WARN, @src(), "Cannot inspect CommandRecord for type {s} : CommandQueue is uninitialized", .{ TypeName });
        return null;
      }
      if( index >= self.records.items.len ){ return null; }

      return &self.records.items[ index ];
    }

    /// Returns the number of queued commands.
    pub inline fn getCommandCount( self : *const Queue ) usize
    {
      if( !self.isInit ){ return 0; }
      return self.records.items.len;
    }

    /// Returns a read-only iterator over currently queued commands.
    pub fn getIteratorConst( self : *const Queue ) ConstIterator
    {
      if( !self.isInit )
      {
        utl.log( .WARN, @src(), "Cannot inspect CommandQueue for type {s} : uninitialized", .{ TypeName });
        return .{};
      }

      return .{ .records = self.records.items };
    }

    /// Drops queued commands while keeping allocated capacity for reuse.
    pub fn clear( self : *Queue ) void
    {
      if( !self.isInit )
      {
        utl.log( .WARN, @src(), "Cannot clear CommandQueue for type {s} : uninitialized", .{ TypeName });
        return;
      }

      self.records.clearRetainingCapacity();
    }


    // ================================ EXECUTION FUNCTIONS ================================

    pub inline fn execAllCommands( self : *Queue, context : *cmd.CommandContext ) cmd.CommandExecResult
    {
      return self.execCommands( 0, context );
    }

    /// Drains queued command records through the registered execution callback.
    /// `amount == 0` drains every command present when this function starts.
    /// Each record is popped before its callback runs, so attempted commands
    /// apply at most once even when the callback reports failure.
    pub fn execCommands( self : *Queue, amount : usize, context : *cmd.CommandContext ) cmd.CommandExecResult
    {
      var result : cmd.CommandExecResult = .{};

      if( !self.isInit )
      {
        utl.log( .ERROR, @src(), "Cannot execute Commands for type {s} : CommandQueue is uninitialized", .{ TypeName });
        result.failed = 1;
        return result;
      }

      const execFn = self.execFn orelse
      {
        utl.log( .ERROR, @src(), "Cannot execute Commands for type {s} : execution callback is missing", .{ TypeName });
        result.failed = 1;
        return result;
      };

      const initialCount = self.records.items.len;
      const targetCount  = if( amount == 0 or amount > initialCount ) initialCount else amount;

      while( result.attempted < targetCount )
      {
        const record = self.pop() orelse break;
        result.attempted += 1;

        if( execFn( context, record ))
        {
          result.succeeded += 1;
        }
        else
        {
          result.failed += 1;
          utl.log( .WARN, @src(), "Command callback for type {s} returned failure", .{ TypeName });
        }
      }

      return result;
    }
  };
}


// ================================ TESTS ================================

test "CommandQueue push pop preserves insertion order"
{
  const TestCommand = struct
  {
    value : u32 = 0,
  };

  var queue : CommandQueueFactory( TestCommand ) = .{};
  queue.init( std.testing.allocator );
  defer queue.deinit();

  try std.testing.expect( queue.push( .{ .value = 10 }));
  try std.testing.expect( queue.push( .{ .value = 20 }));
  try std.testing.expect( queue.getCommandCount() == 2 );

  const first  = queue.pop().?;
  const second = queue.pop().?;

  try std.testing.expect( first.value.value  == 10 );
  try std.testing.expect( second.value.value == 20 );
  try std.testing.expect( first.meta.sequence  == 0 );
  try std.testing.expect( second.meta.sequence == 1 );
  try std.testing.expect( queue.pop() == null );
}

test "CommandQueue supports peek iteration and clear without popping"
{
  const TestCommand = struct
  {
    value : u32 = 0,
  };

  var queue : CommandQueueFactory( TestCommand ) = .{};
  queue.init( std.testing.allocator );
  defer queue.deinit();

  try std.testing.expect( queue.push( .{ .value = 10 }));
  try std.testing.expect( queue.push( .{ .value = 20 }));
  try std.testing.expect( queue.peek( 0 ).?.value.value == 10 );
  try std.testing.expect( queue.peek( 1 ).?.value.value == 20 );

  var count : usize = 0;
  var sum   : u32   = 0;
  var iter = queue.getIteratorConst();
  while( iter.next() )| record |
  {
    count += 1;
    sum   += record.value.value;
  }

  try std.testing.expect( count == 2 );
  try std.testing.expect( sum   == 30 );
  try std.testing.expect( queue.getCommandCount() == 2 );

  queue.clear();

  try std.testing.expect( queue.getCommandCount() == 0 );
  try std.testing.expect( queue.pop() == null );
}

test "CommandQueue rejects uninitialized operations"
{
  const TestCommand = struct
  {
    value : u32 = 0,
  };

  var queue : CommandQueueFactory( TestCommand ) = .{};

  try std.testing.expect( !queue.push( .{ .value = 1 }));
  try std.testing.expect(  queue.pop() == null );
  try std.testing.expect(  queue.peek( 0 ) == null );
  try std.testing.expect(  queue.getCommandCount() == 0 );

  var iter = queue.getIteratorConst();
  try std.testing.expect( iter.next() == null );
}

test "CommandQueue executes queued records once in FIFO order"
{
  const TestCommand = struct
  {
    value : u32 = 0,
  };

  const Runner = struct
  {
    var order : [3]u32 = .{ 0, 0, 0 };
    var count : usize  = 0;

    fn exec( context : *cmd.CommandContext, record : cmd.CommandRecord( TestCommand )) bool
    {
      _ = context;

      order[ count ] = record.value.value;
      count += 1;

      return record.value.value != 2;
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

  var queue : CommandQueueFactory( TestCommand ) = .{};
  queue.init( std.testing.allocator );
  defer queue.deinit();
  queue.execFn = Runner.exec;

  Runner.order = .{ 0, 0, 0 };
  Runner.count = 0;

  try std.testing.expect( queue.push( .{ .value = 1 }));
  try std.testing.expect( queue.push( .{ .value = 2 }));
  try std.testing.expect( queue.push( .{ .value = 3 }));

  const result = queue.execCommands( 0, &context );

  try std.testing.expect( result.attempted == 3 );
  try std.testing.expect( result.succeeded == 2 );
  try std.testing.expect( result.failed    == 1 );
  try std.testing.expect( queue.getCommandCount() == 0 );
  try std.testing.expect( Runner.order[ 0 ] == 1 );
  try std.testing.expect( Runner.order[ 1 ] == 2 );
  try std.testing.expect( Runner.order[ 2 ] == 3 );
}

test "CommandQueue reports missing execution callback without popping"
{
  const TestCommand = struct
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

  var queue : CommandQueueFactory( TestCommand ) = .{};
  queue.init( std.testing.allocator );
  defer queue.deinit();

  try std.testing.expect( queue.push( .{ .value = 1 }));

  const result = queue.execCommands( 0, &context );

  try std.testing.expect( result.attempted == 0 );
  try std.testing.expect( result.succeeded == 0 );
  try std.testing.expect( result.failed    == 1 );
  try std.testing.expect( queue.getCommandCount() == 1 );
}
