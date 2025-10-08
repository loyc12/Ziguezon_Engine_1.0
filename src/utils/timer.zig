const std = @import( "std" );
const def = @import( "defs" );

// NOTE : We treat time zero ( the exact time of the "universal" epoch : UTC 1970-01-01 )
// as a uninitialized time. This hopefully shouldn't cause any issues, as time is mesured
// in nanoseconds, and 0 == 1970-01-01 00:00:00Z, which is >55 years ago

pub inline fn getNow() TimeVal { return TimeVal.newNow(); }


// ================================ TIMEVAL STRUCT ================================

pub const TimeVal = struct
{
  value : i128 = 0,


  // ======== INITIALIZATION ========

  pub inline fn newNow() TimeVal
  {
    return TimeVal{ .value = std.time.nanoTimestamp() };
  }

  pub inline fn timeSince( since : TimeVal ) TimeVal
  {
    if( !since.isSet() )
    {
      def.qlog( .WARN, 0, @src(), "Tried to get time since on an uninitialized TimeVal" );
      return .{};
    }
    return TimeVal{ .value = std.time.nanoTimestamp() - since.value };
  }

  pub inline fn timeUntil( until : TimeVal ) TimeVal
  {
    if( !until.isSet() )
    {
      def.qlog( .WARN, 0, @src(), "Tried to get time until on an uninitialized TimeVal" );
      return .{};
    }
    return TimeVal{ .value = until.value - std.time.nanoTimestamp() };
  }

  pub inline fn timeDiff( t1 : TimeVal, t2 : TimeVal ) TimeVal
  {
    if( !t1.isSet() or !t2.isSet() )
    {
      def.qlog( .WARN, 0, @src(), "Tried to get time diff with an uninitialized TimeVal" );
      return .{};
    }
    return TimeVal.new( @abs( t1.value - t2.value ) );
  }

  pub inline fn fromRayDeltaTime( deltaTime : f32 ) TimeVal
  {
    return TimeVal.new( deltaTime * TimeVal.nsPerSec() );
  }
  pub inline fn toRayDeltaTime( deltaTime : TimeVal ) f32
  {
    return deltaTime.convTo( f32 ) / @as( f32, @floatFromInt( TimeVal.nsPerSec() ));
  }

  pub inline fn fromTimeRate( timeRate : f32 ) TimeVal
  {
    return TimeVal.new( @as( f32, @floatFromInt( TimeVal.nsPerSec() )) / timeRate );
  }
  pub inline fn toTimeRate( deltaTime : TimeVal ) f32
  {
    return @as( f32, @floatFromInt( TimeVal.nsPerSec() )) / deltaTime.convTo( f32 );
  }

  // ======== CHECKERS ========

  pub inline fn isSet( self : *const TimeVal ) bool { return self.value != 0; }
  pub inline fn isPos( self : *const TimeVal ) bool { return self.value >  0; }
  pub inline fn isNeg( self : *const TimeVal ) bool { return self.value <  0; }


  // ======== CASTING ========

  pub inline fn clear( self : *TimeVal ) void { self.value = 0; }

  pub inline fn toYear( self : *const TimeVal ) i128 { return @divTrunc( self.value, TimeVal.nsPerYear() ); }
  pub inline fn toWeek( self : *const TimeVal ) i128 { return @divTrunc( self.value, TimeVal.nsPerWeek() ); }
  pub inline fn toDay(  self : *const TimeVal ) i128 { return @divTrunc( self.value, TimeVal.nsPerDay()  ); }
  pub inline fn toHour( self : *const TimeVal ) i128 { return @divTrunc( self.value, TimeVal.nsPerHour() ); }
  pub inline fn toMin(  self : *const TimeVal ) i128 { return @divTrunc( self.value, TimeVal.nsPerMin()  ); }
  pub inline fn toSec(  self : *const TimeVal ) i128 { return @divTrunc( self.value, TimeVal.nsPerSec()  ); }
  pub inline fn toMs(   self : *const TimeVal ) i128 { return @divTrunc( self.value, TimeVal.nsPerMs()   ); }
  pub inline fn toUs(   self : *const TimeVal ) i128 { return @divTrunc( self.value, TimeVal.nsPerUs()   ); }
  pub inline fn toNs(   self : *const TimeVal ) i128 { return self.value; }

  pub inline fn nsPerYear() i128 { return 31_536_000_000_000_000; }
  pub inline fn nsPerWeek() i128 { return 604_800_000_000_000; }
  pub inline fn nsPerDay()  i128 { return 86_400_000_000_000; }
  pub inline fn nsPerHour() i128 { return 3_600_000_000_000; }
  pub inline fn nsPerMin()  i128 { return 60_000_000_000; }
  pub inline fn nsPerSec()  i128 { return 1_000_000_000; }
  pub inline fn nsPerMs()   i128 { return 1_000_000; }
  pub inline fn nsPerUs()   i128 { return 1_000; }
  pub inline fn nsPerNs()   i128 { return 1; }


  // ======== TYPE CONVERSION ========

  pub inline fn new( value : anytype ) TimeVal
  {
    switch( @typeInfo( @TypeOf( value )))
    {
      .int,   .comptime_int   => return TimeVal{ .value = @intCast( value )},
      .float, .comptime_float => return TimeVal{ .value = @as( i128, @intFromFloat( value ))},
      else =>
      {
        def.log( .WARN, 0, @src(), "Tried to get TimeVal from unsuported type {}", @typeInfo( @TypeOf( value )));
        return .{};
      },
    }
  }

  pub fn setTo( self : *TimeVal, newValue : anytype ) void
  {
    switch( @typeInfo( @TypeOf( newValue )))
    {
      .int,   .comptime_int   => self.value = @intCast( newValue ),
      .float, .comptime_float => self.value = @as( i128, @intFromFloat( newValue )),
      else =>
      {
        def.log( .WARN, 0, @src(), "Tried to set TimeVal via unsuported type {}", @typeInfo( @TypeOf( newValue )));
        return .{};
      },
    }
  }
  pub fn convTo( self : *const TimeVal, comptime retType : type ) retType
  {
    switch( @typeInfo( retType ))
    {
      .int,   .comptime_int   => return @intCast( self.value ),
      .float, .comptime_float => return @as( retType, @floatFromInt( self.value )),
      else =>
      {
        def.log( .WARN, 0, @src(), "Tried to convert TimeVal to unsuported type {}", @typeInfo( retType ));
        return .{};
      },
    }
  }
};


// ================================ TIMER FLAGS ================================pub inline fn hasTrueLoop( self : *const timer ) bool { return self.canLoop() and self.loopLimit != 0; }pub inline fn hasTrueLoop( self : *const timer ) bool { return self.canLoop() and self.loopLimit != 0; }

pub const e_timer_flags = enum( u8 )
{
  DELETE  = 0b10000000, // Timer is marked for deletion
  STARTED = 0b01000000, // Timer has started
  STOPPED = 0b00100000, // Timer has completed ( expired )
  PAUSED  = 0b00010000, // Timer is currently paused
  LOOP    = 0b00001000, // Timer will restart after reaching duration
//MORE... = 0b00000100,
//MORE... = 0b00000010,
  DEBUG   = 0b00000001, // Timer will output debug info

//DEFAULT = 0b00000000, // Default flags for default timers
  TO_CPY  = 0b00011111, // Flags to copy when creating a new entity from params
  NONE    = 0b00000000, // No flags set
  ALL     = 0b11111111, // All flags set
};

// ================================ TIMER STRUCT ================================

pub const Timer = struct
{
  // All times are in nanoseconds
  flags  : def.BitField8 = def.BitField8.new( e_timer_flags.NONE ),

  progress : TimeVal = .{}, // current progress ( where between 0 and duration )
  duration : TimeVal = .{}, // End time ( 0 means no duration )

  lapLimit : u32  = 0, // Maximum number of laps
  lapCount : u32  = 0, // number of laps completed


  // ================ FLAG MANAGEMENT ================

  pub inline fn hasFlag( self : *const Timer, flag : e_timer_flags ) bool { return self.flags.hasFlag( @intFromEnum( flag )); }

  pub inline fn setAllFlags( self : *Timer, flags : u8 )                        void { self.flags.bitField = flags; }
  pub inline fn setFlag(     self : *Timer, flag  : e_timer_flags, val : bool ) void { self.flags = self.flags.setFlag( @intFromEnum( flag ), val); }
  pub inline fn addFlag(     self : *Timer, flag  : e_timer_flags )             void { self.flags = self.flags.addFlag( @intFromEnum( flag )); }
  pub inline fn delFlag(     self : *Timer, flag  : e_timer_flags )             void { self.flags = self.flags.delFlag( @intFromEnum( flag )); }

  pub inline fn pause(       self : *Timer ) void { self.addFlag( e_timer_flags.PAUSED ); }
  pub inline fn play(        self : *Timer ) void { self.delFlag( e_timer_flags.PAUSED ); }
  pub inline fn togglePause( self : *Timer ) void
  {
    if( self.isPaused() ){ self.play(); } else { self.pause(); }
  }
  pub inline fn canBeDel(  self : *const Timer ) bool { return self.hasFlag( e_timer_flags.DELETE  ); }
  pub inline fn isStarted( self : *const Timer ) bool { return self.hasFlag( e_timer_flags.STARTED ); }
  pub inline fn isPaused(  self : *const Timer ) bool { return self.hasFlag( e_timer_flags.PAUSED  ); }
  pub inline fn isStopped( self : *const Timer ) bool { return self.hasFlag( e_timer_flags.STOPPED ); }
  pub inline fn canLoop(   self : *const Timer ) bool { return self.hasFlag( e_timer_flags.LOOP    ); }
  pub inline fn isDebug(   self : *const Timer ) bool { return self.hasFlag( e_timer_flags.DEBUG   ); }


  // ================ ACCESSORS & MUTATORS ================

  pub inline fn hasDuration( self : *const Timer ) bool { return self.duration.isSet(); }
  pub inline fn hasLapLimit( self : *const Timer ) bool { return self.lapLimit != 0; }
  pub inline fn hasTrueLoop( self : *const Timer ) bool { return self.canLoop() and self.lapLimit != 0; }

  pub inline fn getDuration(   self : *const Timer ) TimeVal { return self.duration; }
  pub inline fn getMaxLap(     self : *const Timer ) u32     { return self.lapLimit; }
  pub inline fn getCurrentLap( self : *const Timer ) u32     { return self.lapCount; }

  // NOTE : Be careful when using those setters, as they also update the Timer state
  pub inline fn setDuration(   self : *Timer, duration : TimeVal ) void { self.duration = duration; _ = self.updateSelf( .{} ); }
  pub inline fn setMaxLap(     self : *Timer, maxLap   : u32     ) void { self.lapLimit = maxLap;   _ = self.updateSelf( .{} ); }
  pub inline fn setCurrentLap( self : *Timer, curLap   : u32     ) void { self.lapCount = curLap;   _ = self.updateSelf( .{} ); }

  // ================ INITIALIZATION ================

  pub fn copyTimerSettings( self : *Timer, params : Timer ) void
  {
    self.flags    = params.flags.filterField( e_timer_flags.TO_CPY );

    self.progress = .{};
    self.duration = params.duration;

    self.lapLimit = params.lapLimit;
    self.lapCount = 0;
  }

  pub fn getDefaultTimer() Timer
  {
    return Timer{
      .flags    = def.BitField8.new( e_timer_flags.NONE ),

      .progress = .{},
      .duration = .{},

      .lapLimit = 0,
      .lapCount = 0,
    };
  }

  pub fn getSimpleTimer( duration : TimeVal, maxLoopCount : u32 ) Timer
  {
    var tmp : Timer = .{};

    tmp.duration = duration;
    tmp.addFlag( e_timer_flags.STARTED );

    if( maxLoopCount > 0 )
    {
      tmp.addFlag( e_timer_flags.LOOP );
      tmp.lapLimit = maxLoopCount;
    }
    return tmp;
  }


  // ================ UPDATE ================

  pub fn resetSelf( self : *Timer ) void
  {
    self.progress = .{};
    self.lapCount = 0;

    self.delFlag( e_timer_flags.STARTED );
    self.delFlag( e_timer_flags.STOPPED );
    self.delFlag( e_timer_flags.PAUSED  );
  }

  pub fn startSelf( self : *Timer ) void
  {
    if( self.isStarted() ){ return; }

    self.progress = .{};
    self.lapCount = 0;

    self.addFlag( e_timer_flags.STARTED );
    self.delFlag( e_timer_flags.STOPPED );
    self.delFlag( e_timer_flags.PAUSED  );
  }

  pub fn stopSelf( self : *Timer ) void
  {
    if( !self.isStarted() ){ return; }

    self.delFlag( e_timer_flags.STARTED );
    self.addFlag( e_timer_flags.STOPPED );
    self.delFlag( e_timer_flags.PAUSED  );
  }

  // Returns true if the Timer lapped or ended
  pub fn updateSelf( self : *Timer, deltaTime : TimeVal ) bool
  {
    if( !self.isStarted() ){ return false; }
    if(  self.isPaused()  ){ return false; }
    if(  self.isStopped() ){ return false; }

    if( deltaTime )| dt |{ self.incrementBy( dt ); }

    return self.tryLap();
  }

  fn incrementBy( self : *Timer, delta : TimeVal ) void
  {
    if( delta.isNeg() )  // TODO : figure out if we want to handle negative delta time as a feature ??
    {
      def.log( .WARN, 0, @src(), "Tried to update Timer with a negative delta time ({d})", .{ delta.value });
    }
    self.progress.value += delta.value;
  }

  fn tryLap( self : *Timer ) bool
  {
    if( !self.hasDuration() ){ return false; }
    if( !self.canLoop() )
    {
      if( self.progress.value >= self.duration.value )
      {
        if( self.isDebug() ){ def.log( .DEBUG, 0, @src(), "Timer completed its duration of {d}ns", .{ self.duration.value }); }
        self.stopSelf();
        return true;
      }
      return false;
    }

    const lapped = self.doLap();

    // Checking if we reached the lap limit
    if( lapped and self.lapLimit != 0 and self.lapCount >= self.lapLimit )
    {
      if( self.isDebug() ){ def.log( .DEBUG, 0, @src(), "Timer reached its lap limit of {d}", .{ self.lapLimit }); }
      self.addFlag( e_timer_flags.STOPPED );
    }
    return lapped;
  }

  fn doLap( self : *Timer ) bool
  {
    var lapped = false;

    // Making sure we lap as many times as needed if the progress exceeded duration
    while( self.progress.value >= self.duration.value )
    {
      if( self.isDebug() ){ def.log( .DEBUG, 0, @src(), "Timer completed a lap of {d}ns", .{ self.duration.value }); }
      self.progress.value -= self.duration.value;
      self.lapCount += 1;
      lapped = lapped;
    }

    return lapped;
  }

  // Forces a lap, regardless of current progress or flags limitations
  pub inline fn forceLap( self : *Timer ) void
  {
    self.progress.value = 0;
    self.lapCount += 1;

    if( self.hasLapLimit() and self.lapCount >= self.lapLimit )
    {
      if( self.isDebug() ){ def.log( .DEBUG, 0, @src(), "Timer reached its lap limit of {d}", .{ self.lapLimit }); }
      self.addFlag( e_timer_flags.STOPPED );
    }
  }


  // ======== LAP PROGRESS ========

  pub inline fn getLapProgress( self : *const Timer ) TimeVal { return self.progress; }
  pub inline fn getLapDuration( self : *const Timer ) TimeVal
  {
    if( !self.hasDuration() )
    {
      if( self.isDebug() ){ def.qlog( .DEBUG, 0, @src(), "Tried to get lap duration with no duration" ); }
      return .{};
    }
    return self.duration;
  }

  pub inline fn getLapProgressFactor( self : *const Timer ) f32
  {
    if( !self.hasDuration() )
    {
      if( self.isDebug() ){ def.qlog( .DEBUG, 0, @src(), "Tried to get lap progress factor with no duration" ); }
      return 0.0;
    }

    const prog : f32 = @floatFromInt( self.progress.value );
    const dura : f32 = @floatFromInt( self.duration.value );

    return( prog / dura );
  }

  // ======== TOTAL PROGRESS ======== ( for lapping timers )

  pub inline fn getTotalProgress( self : *const Timer ) TimeVal
  {
    if( !self.hasTrueLoop() )
    {
      if( self.isDebug() ){ def.qlog( .DEBUG, 0, @src(), "Tried to get total progress on a non-looping Timer" ); }
      return self.getLapProgress();
    }

    return TimeVal{ .value = self.progress.value + ( @as( i128, @intCast( self.lapCount )) * self.duration.value )};
  }

  pub inline fn getTotalDuration( self : *const Timer ) TimeVal
  {
    if( !self.hasTrueLoop() )
    {
      if( self.isDebug() ){ def.qlog( .DEBUG, 0, @src(), "Tried to get total duration on a non-looping Timer" ); }
      return self.getLapDuration();
    }

    if( !self.hasDuration() or !self.hasLapLimit() )
    {
      if( self.isDebug() ){ def.qlog( .DEBUG, 0, @src(), "Tried to get total duration on a looping Timer with no duration and/or lap limit" ); }
      return .{};
    }

    return TimeVal{ .value = @as( i128, @intCast( self.lapLimit )) * self.duration.value };
  }

  pub inline fn getTotalProgressFactor( self : *const Timer ) f32
  {
    if( !self.hasTrueLoop() )
    {
      if( self.isDebug() ){ def.qlog( .DEBUG, 0, @src(), "Tried to get total progress factor on a non-looping Timer" ); }
      return self.getLapProgressFactor();
    }

    if( !self.hasDuration() or !self.hasLapLimit() )
    {
      if( self.isDebug() ){ def.qlog( .DEBUG, 0, @src(), "Tried to get total progress factor on a looping Timer with no duration and/or lap limit" ); }
      return 0.0;
    }

    const totProg : f32 = @floatFromInt( self.getTotalProgress().value );
    const totDura : f32 = @floatFromInt( self.getTotalDuration().value );

    return( totProg / totDura );
  }


  // ======== REMAINING LAP/TOTAL TIME ========

  pub inline fn getRemainingLapCount( self : *const Timer ) u32
  {
    if( !self.hasLapLimit() )
    {
      if( self.isDebug() ){ def.qlog( .DEBUG, 0, @src(), "Tried to get remaining laps with no lap limit" ); }
      return 0;
    }
    return( self.lapLimit - self.lapCount );
  }

  pub inline fn getRemainingLapTime( self : *const Timer ) TimeVal
  {
    if( !self.hasDuration() )
    {
      if( self.isDebug() ){ def.qlog( .DEBUG, 0, @src(), "Tried to get remaining lap time with no duration" ); }
      return .{};
    }
    if( self.progress.value >= self.duration.value ){ return .{}; }
    return( TimeVal{ .value  = self.duration.value - self.progress.value });
  }

  pub inline fn getRemainingTotalTime( self : *const Timer ) TimeVal
  {
    if( !self.hasTrueLoop() )
    {
      if( self.isDebug() ){ def.qlog( .DEBUG, 0, @src(), "Tried to get remaining total time on a non-looping Timer" ); }
      return self.getRemainingLapTime();
    }

    if( !self.hasDuration() or !self.hasLapLimit() )
    {
      if( self.isDebug() ){ def.qlog( .DEBUG, 0, @src(), "Tried to get remaining total time on a looping Timer with no duration and/or lap limit" ); }
      return .{};
    }

    const totalDura = self.getTotalDuration().value;
    const totalProg = self.getTotalProgress().value;

    if( totalProg >= totalDura ){ return .{}; }
    return( TimeVal{ .value = totalDura - totalProg });
  }
};