const std = @import( "std" );

const Duration = @import( "duration.zig" ).Duration;


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
  NONE,
  FOREVER,
  COUNT : u32,

  pub inline fn hasLimit( self : TimerLoop ) bool
  {
    return switch( self )
    {
      .COUNT => true,
      else   => false,
    };
  }

  pub inline fn getLimit( self : TimerLoop ) ?u32
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
  deltaUsed     : Duration = .{},
  lapsCompleted : u32      = 0,
  completed     : bool     = false,
};


// ================================ TIMER CORE ================================

pub const TimerCore = struct
{
  elapsed   : Duration   = .{},
  duration  : ?Duration  = null,
  lapCount  : u32        = 0,
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
    if( !self.isRunning() or delta.value <= 0 ){ return .{}; }

    const duration = self.duration orelse
    {
      self.elapsed.value += delta.value;
      return .{ .deltaUsed = delta };
    };

    if( duration.value <= 0 )
    {
      self.elapsed = .{};
      self.state   = .DONE;
      return .{ .deltaUsed = delta, .completed = true };
    }

    self.elapsed.value += delta.value;

    return switch( self.loop )
    {
      .NONE    => self.updateNoLoop( duration, delta ),
      .FOREVER => self.updateForeverLoop( duration, delta ),
      .COUNT   => | limit | self.updateCountedLoop( duration, delta, limit ),
    };
  }

  fn updateNoLoop( self : *TimerCore, duration : Duration, delta : Duration ) TimerUpdate
  {
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
    const laps : u32 = @intCast( @divTrunc( self.elapsed.value, duration.value ));

    if( laps == 0 ){ return .{ .deltaUsed = delta }; }

    self.elapsed.value = @mod( self.elapsed.value, duration.value );
    self.lapCount     += laps;

    return .{ .deltaUsed = delta, .lapsCompleted = laps };
  }

  fn updateCountedLoop( self : *TimerCore, duration : Duration, delta : Duration, limit : u32 ) TimerUpdate
  {
    if( limit == 0 )
    {
      self.state = .DONE;
      return .{ .deltaUsed = delta, .completed = true };
    }

    const laps : u32 = @intCast( @divTrunc( self.elapsed.value, duration.value ));
    if( laps == 0 ){ return .{ .deltaUsed = delta }; }

    const remaining = limit -| self.lapCount;
    const applied   = @min( laps, remaining );

    self.lapCount += applied;

    if( self.lapCount >= limit )
    {
      self.elapsed = duration;
      self.state   = .DONE;
      return .{ .deltaUsed = delta, .lapsCompleted = applied, .completed = true };
    }

    self.elapsed.value = @mod( self.elapsed.value, duration.value );
    return .{ .deltaUsed = delta, .lapsCompleted = applied };
  }

  fn enforceBounds( self : *TimerCore ) void
  {
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
    const duration = self.duration orelse return 0.0;
    if( duration.value <= 0 ){ return 1.0; }
    if( self.isDone() ){ return 1.0; }

    const prog : f64 = @floatFromInt( self.elapsed.value );
    const dura : f64 = @floatFromInt( duration.value );

    return @min( prog / dura, 1.0 );
  }

  pub inline fn getTotalDuration( self : *const TimerCore ) ?Duration
  {
    const duration = self.duration orelse return null;

    return switch( self.loop )
    {
      .COUNT => | limit | .{ .value = duration.value * @as( i128, @intCast( limit ))},
      .NONE  => duration,
      else   => null,
    };
  }

  pub inline fn getTotalProgress( self : *const TimerCore ) Duration
  {
    const duration = self.duration orelse return self.elapsed;

    if( self.isDone() )
    {
      if( self.loop.getLimit() )| limit |
      {
        return .{ .value = duration.value * @as( i128, @intCast( limit ))};
      }
      return duration;
    }

    return .{ .value = self.elapsed.value + ( @as( i128, @intCast( self.lapCount )) * duration.value )};
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
  var timer = TimerCore.started( .new( 10 ));

  try std.testing.expect( !timer.updateBy( .new( 4 )).completed );
  try std.testing.expectEqual( @as( i128, 4 ), timer.elapsed.value );

  const update = timer.updateBy( .new( 6 ));

  try std.testing.expect( update.completed );
  try std.testing.expect( timer.isDone() );
  try std.testing.expectEqual( @as( i128, 10 ), timer.elapsed.value );
}

test "TimerCore reports multiple laps"
{
  var timer = TimerCore.looping( .new( 10 ), .FOREVER );

  const update = timer.updateBy( .new( 35 ));

  try std.testing.expectEqual( @as( u32, 3 ), update.lapsCompleted );
  try std.testing.expectEqual( @as( u32, 3 ), timer.lapCount );
  try std.testing.expectEqual( @as( i128, 5 ), timer.elapsed.value );
}

test "TimerCore stops counted loops at their limit"
{
  var timer = TimerCore.looping( .new( 10 ), .{ .COUNT = 2 });

  const update = timer.updateBy( .new( 35 ));

  try std.testing.expect( update.completed );
  try std.testing.expectEqual( @as( u32, 2 ), update.lapsCompleted );
  try std.testing.expectEqual( @as( u32, 2 ), timer.lapCount );
  try std.testing.expectEqual( @as( i128, 10 ), timer.elapsed.value );
}
