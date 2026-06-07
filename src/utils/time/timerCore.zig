const std = @import( "std" );

const durationMod = @import( "duration.zig" );

const Duration = durationMod.Duration;


// ================================ DEFINITIONS ================================

pub const TimerState = enum( u8 )
{
  IDLE,
  RUNNING,
  PAUSED,
  DONE,
};

pub const TimerLoop = union( enum )
{
  // NONE completes once, FOREVER wraps every duration, COUNT wraps until limit.
  NONE,
  FOREVER,
  COUNT : u64,

  pub inline fn hasLimit( self : TimerLoop ) bool
  {
    return switch( self )
    {
      .COUNT => true,
      else   => false,
    };
  }

  pub inline fn getLimit( self : TimerLoop ) ?u64
  {
    return switch( self )
    {
      .COUNT => | limit | limit,
      else   => null,
    };
  }
};

pub const TimerUpdate = struct
{
  // Returned by update calls so game code can react to completions without
  // inspecting internal timer state.
  deltaUsed     : Duration = .{},
  lapsCompleted : u64      = 0,
  completed     : bool     = false,
};


inline fn clampI128ToU64( value : i128 ) u64
{
  // Lap counts come from i128 duration math, but public counters are u64.
  // Clamp extreme hitches instead of trapping on cast.
  if( value <= 0 ){ return 0; }
  if( value > std.math.maxInt( u64 )){ return std.math.maxInt( u64 ); }

  return @intCast( value );
}

inline fn saturatingAddU64( a : u64, b : u64 ) u64
{
  return std.math.add( u64, a, b ) catch std.math.maxInt( u64 );
}

inline fn saturatingMulDuration( duration : Duration, factor : u64 ) Duration
{
  // Used for "duration per lap * lap count" totals.
  return .{ .value = durationMod.saturatingMul( duration.value, @intCast( factor ))};
}

inline fn saturatingAddDuration( a : Duration, b : Duration ) Duration
{
  return .{ .value = durationMod.saturatingAdd( a.value, b.value )};
}


// ================================ TIMER CORE ================================

pub const TimerCore = struct
{
  // `elapsed` tracks the current lap for looping timers. Total progress is
  // reconstructed from `lapCount` plus `elapsed`.
  elapsed   : Duration   = .{},
  duration  : ?Duration  = null,
  lapCount  : u64        = 0,
  loop      : TimerLoop  = .NONE,
  state     : TimerState = .IDLE,


  // ================ INITIALIZATION ================

  pub inline fn init( duration : ?Duration ) TimerCore
  {
    return .{ .duration = duration };
  }

  pub inline fn started( duration : ?Duration ) TimerCore
  {
    var timer = TimerCore.init( duration );
    timer.start();
    return timer;
  }

  pub inline fn looping( duration : Duration, loop : TimerLoop ) TimerCore
  {
    var timer = TimerCore.init( duration );
    timer.loop = loop;
    timer.start();
    return timer;
  }


  // ================ STATE ================

  pub inline fn isIdle(    self : *const TimerCore ) bool { return self.state == .IDLE;    }
  pub inline fn isRunning( self : *const TimerCore ) bool { return self.state == .RUNNING; }
  pub inline fn isPaused(  self : *const TimerCore ) bool { return self.state == .PAUSED;  }
  pub inline fn isDone(    self : *const TimerCore ) bool { return self.state == .DONE;    }

  pub inline fn start( self : *TimerCore ) void
  {
    self.elapsed  = .{};
    self.lapCount = 0;
    self.state    = .RUNNING;
  }

  pub inline fn restart( self : *TimerCore ) void
  {
    self.start();
  }

  pub inline fn reset( self : *TimerCore ) void
  {
    self.elapsed  = .{};
    self.lapCount = 0;
    self.state    = .IDLE;
  }

  pub inline fn stop( self : *TimerCore ) void
  {
    self.state = .DONE;
  }

  pub inline fn pause( self : *TimerCore ) void
  {
    if( self.isRunning() ){ self.state = .PAUSED; }
  }

  pub inline fn unpause( self : *TimerCore ) void
  {
    if( self.isPaused() ){ self.state = .RUNNING; }
  }

  pub inline fn setDuration( self : *TimerCore, duration : ?Duration ) void
  {
    self.duration = duration;
    self.enforceBounds();
  }

  pub inline fn setLoop( self : *TimerCore, loop : TimerLoop ) void
  {
    self.loop = loop;
    self.enforceBounds();
  }


  // ================ UPDATE ================

  pub fn updateBy( self : *TimerCore, delta : Duration ) TimerUpdate
  {
    // Timers only advance forward while running. Negative deltas are ignored
    // rather than rewinding state.
    if( !self.isRunning() or delta.value <= 0 ){ return .{}; }

    const duration = self.duration orelse
    {
      // A null duration means "free-running"; it never completes by itself.
      self.elapsed.value = durationMod.saturatingAdd( self.elapsed.value, delta.value );
      return .{ .deltaUsed = delta };
    };

    if( duration.value <= 0 )
    {
      // Zero/negative durations are treated as immediately complete.
      self.elapsed = .{};
      self.state   = .DONE;
      return .{ .deltaUsed = delta, .completed = true };
    }

    self.elapsed.value = durationMod.saturatingAdd( self.elapsed.value, delta.value );

    return switch( self.loop )
    {
      .NONE    => self.updateNoLoop( duration, delta ),
      .FOREVER => self.updateForeverLoop( duration, delta ),
      .COUNT   => | limit | self.updateCountedLoop( duration, delta, limit ),
    };
  }

  fn updateNoLoop( self : *TimerCore, duration : Duration, delta : Duration ) TimerUpdate
  {
    // Non-looping timers clamp at their target duration and enter DONE.
    if( self.elapsed.value < duration.value )
    {
      return .{ .deltaUsed = delta };
    }

    self.elapsed = duration;
    self.state   = .DONE;

    return .{ .deltaUsed = delta, .completed = true };
  }

  fn updateForeverLoop( self : *TimerCore, duration : Duration, delta : Duration ) TimerUpdate
  {
    // A large delta may cover multiple laps. Keep only the remainder in elapsed
    // so progress within the current lap stays bounded.
    const laps : u64 = clampI128ToU64( @divTrunc( self.elapsed.value, duration.value ));

    if( laps == 0 ){ return .{ .deltaUsed = delta }; }

    self.elapsed.value = @mod( self.elapsed.value, duration.value );
    self.lapCount      = saturatingAddU64( self.lapCount, laps );

    return .{ .deltaUsed = delta, .lapsCompleted = laps };
  }

  fn updateCountedLoop( self : *TimerCore, duration : Duration, delta : Duration, limit : u64 ) TimerUpdate
  {
    // Counted loops behave like FOREVER until the configured lap limit is hit.
    if( limit == 0 )
    {
      self.state = .DONE;
      return .{ .deltaUsed = delta, .completed = true };
    }

    const laps : u64 = clampI128ToU64( @divTrunc( self.elapsed.value, duration.value ));
    if( laps == 0 ){ return .{ .deltaUsed = delta }; }

    const remaining = limit -| self.lapCount;
    const applied   = @min( laps, remaining );

    self.lapCount = saturatingAddU64( self.lapCount, applied );

    if( self.lapCount >= limit )
    {
      // Store a completed counted loop as one full final lap, not a remainder.
      self.elapsed = duration;
      self.state   = .DONE;
      return .{ .deltaUsed = delta, .lapsCompleted = applied, .completed = true };
    }

    self.elapsed.value = @mod( self.elapsed.value, duration.value );
    return .{ .deltaUsed = delta, .lapsCompleted = applied };
  }

  fn enforceBounds( self : *TimerCore ) void
  {
    // If duration/loop settings change while a timer is active, bring elapsed
    // back into the range expected by the new mode.
    const duration = self.duration orelse return;

    if( duration.value <= 0 or self.elapsed.value <= duration.value ){ return; }

    self.elapsed = switch( self.loop )
    {
      .NONE  => duration,
      .COUNT => | limit | if( self.lapCount >= limit ) duration else .{ .value = @mod( self.elapsed.value, duration.value )},
      else   => .{ .value = @mod( self.elapsed.value, duration.value )},
    };
  }


  // ================ QUERIES ================

  pub inline fn getElapsed( self : *const TimerCore ) Duration
  {
    return self.elapsed;
  }

  pub inline fn getDuration( self : *const TimerCore ) ?Duration
  {
    return self.duration;
  }

  pub inline fn getRemaining( self : *const TimerCore ) ?Duration
  {
    const duration = self.duration orelse return null;

    if( self.isDone() ){ return .{}; }
    if( self.elapsed.value >= duration.value ){ return .{}; }

    return .{ .value = duration.value - self.elapsed.value };
  }

  pub inline fn getProgressFactor( self : *const TimerCore ) f64
  {
    // Current-lap progress in [0, 1]. Infinite/free-running timers report 0.
    const duration = self.duration orelse return 0.0;
    if( duration.value <= 0 ){ return 1.0; }
    if( self.isDone() ){ return 1.0; }

    const prog : f64 = @floatFromInt( self.elapsed.value );
    const dura : f64 = @floatFromInt( duration.value );

    return @min( prog / dura, 1.0 );
  }

  pub inline fn getTotalDuration( self : *const TimerCore ) ?Duration
  {
    // FOREVER and free-running timers have no finite total duration.
    const duration = self.duration orelse return null;

    return switch( self.loop )
    {
      .COUNT => | limit | saturatingMulDuration( duration, limit ),
      .NONE  => duration,
      else   => null,
    };
  }

  pub inline fn getTotalProgress( self : *const TimerCore ) Duration
  {
    // For loops, total progress includes completed laps plus current-lap elapsed.
    const duration = self.duration orelse return self.elapsed;

    if( self.isDone() )
    {
      if( self.loop.getLimit() )| limit |
      {
        return saturatingMulDuration( duration, limit );
      }
      return duration;
    }

    return saturatingAddDuration( self.elapsed, saturatingMulDuration( duration, self.lapCount ));
  }

  pub inline fn getTotalProgressFactor( self : *const TimerCore ) f64
  {
    const duration = self.getTotalDuration() orelse return 0.0;
    if( duration.value <= 0 ){ return 1.0; }

    const prog : f64 = @floatFromInt( self.getTotalProgress().value );
    const dura : f64 = @floatFromInt( duration.value );

    return @min( prog / dura, 1.0 );
  }
};


// ================================ TESTS ================================

test "TimerCore completes non-looping timers"
{
  var timer = TimerCore.started( .new( 10, .NS ));

  try std.testing.expect( !timer.updateBy( .new( 4, .NS )).completed );
  try std.testing.expectEqual( @as( i128, 4 ), timer.elapsed.value );

  const update = timer.updateBy( .new( 6, .NS ));

  try std.testing.expect( update.completed );
  try std.testing.expect( timer.isDone() );
  try std.testing.expectEqual( @as( i128, 10 ), timer.elapsed.value );
}

test "TimerCore reports multiple laps"
{
  var timer = TimerCore.looping( .new( 10, .NS ), .FOREVER );

  const update = timer.updateBy( .new( 35, .NS ));

  try std.testing.expectEqual( @as( u64, 3 ), update.lapsCompleted );
  try std.testing.expectEqual( @as( u64, 3 ), timer.lapCount );
  try std.testing.expectEqual( @as( i128, 5 ), timer.elapsed.value );
}

test "TimerCore stops counted loops at their limit"
{
  var timer = TimerCore.looping( .new( 10, .NS ), .{ .COUNT = 2 });

  const update = timer.updateBy( .new( 35, .NS ));

  try std.testing.expect( update.completed );
  try std.testing.expectEqual( @as( u64, 2 ), update.lapsCompleted );
  try std.testing.expectEqual( @as( u64, 2 ), timer.lapCount );
  try std.testing.expectEqual( @as( i128, 10 ), timer.elapsed.value );
}

test "TimerCore saturates very large loop counts"
{
  var forever = TimerCore.looping( .new( 1, .NS ), .FOREVER );
  forever.elapsed = .{ .value = std.math.maxInt( i128 )};

  const foreverUpdate = forever.updateBy( .new( 1, .NS ));

  try std.testing.expectEqual( std.math.maxInt( u64 ), foreverUpdate.lapsCompleted );
  try std.testing.expectEqual( std.math.maxInt( u64 ), forever.lapCount );

  var counted = TimerCore.looping( .new( 1, .NS ), .{ .COUNT = 3 });
  counted.elapsed = .{ .value = std.math.maxInt( i128 )};

  const countedUpdate = counted.updateBy( .new( 1, .NS ));

  try std.testing.expect( countedUpdate.completed );
  try std.testing.expectEqual( @as( u64, 3 ), countedUpdate.lapsCompleted );
  try std.testing.expectEqual( @as( u64, 3 ), counted.lapCount );
}
