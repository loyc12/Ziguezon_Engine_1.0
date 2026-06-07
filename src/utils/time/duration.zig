const std = @import( "std" );


// ================================ TIME UNITS ================================

pub const TimeUnit = enum( u8 )
{
  YEAR,
  WEEK,
  DAY,
  HOUR,
  MIN,
  SEC,
  MS,
  US,
  NS,
};

pub const TimeRatio = struct
{
  numer : i128,
  denom : i128,

  pub inline fn toFloat( self : *const TimeRatio ) f64
  {
    const numer : f64 = @floatFromInt( self.numer );
    const denom : f64 = @floatFromInt( self.denom );

    return numer / denom;
  }

  pub inline fn isWhole( self : *const TimeRatio ) bool
  {
    return @mod( self.numer, self.denom ) == 0;
  }

  pub inline fn toWhole( self : *const TimeRatio ) i128
  {
    if( !self.isWhole() ){ @panic( "Tried to convert fractional TimeRatio to integer" ); }

    return @divExact( self.numer, self.denom );
  }

  pub inline fn applyTrunc( self : *const TimeRatio, value : i128 ) i128
  {
    return @divTrunc( value * self.numer, self.denom );
  }
};

pub inline fn getNsPerUnit( unit : TimeUnit ) i128
{
  return switch( unit )
  {
    .YEAR => 31_536_000_000_000_000,
    .WEEK =>    604_800_000_000_000,
    .DAY  =>     86_400_000_000_000,
    .HOUR =>      3_600_000_000_000,
    .MIN  =>         60_000_000_000,
    .SEC  =>          1_000_000_000,
    .MS   =>              1_000_000,
    .US   =>                  1_000,
    .NS   =>                      1,
  };
}

pub inline fn getWholeUnitsPerClip( unit : TimeUnit ) ?i128
{
  return switch( unit )
  {
    .YEAR => null,
    .WEEK => null,
    .DAY  => 7,
    .HOUR => 24,
    .MIN  => 60,
    .SEC  => 60,
    .MS   => 1_000,
    .US   => 1_000,
    .NS   => 1_000,
  };
}

// Returns the ratio needed to convert a value from `from` units into `to` units.
// Example: getTimeRatio( .NS, .YEAR ).toWhole() == nanoseconds per year.
pub inline fn getTimeRatio( to : TimeUnit, from : TimeUnit ) TimeRatio
{
  return .{
    .numer = getNsPerUnit( from ),
    .denom = getNsPerUnit( to   ),
  };
}


// ================================ DURATION STRUCT ================================

pub const Duration = struct
{
  value : i128 = 0,


  // ======== INITIALIZATION ========

  pub inline fn new( value : anytype ) Duration
  {
    switch( @typeInfo( @TypeOf( value )))
    {
      .int,   .comptime_int   => return .{ .value = @intCast( value )},
      .float, .comptime_float => return .{ .value = @as( i128, @intFromFloat( value ))},
      else => @compileError( "Duration.new() only supports Int and Float values" ),
    }
  }

  pub inline fn fromUnit( value : anytype, unit : TimeUnit ) Duration
  {
    const ratio = getTimeRatio( .NS, unit );

    switch( @typeInfo( @TypeOf( value )))
    {
      .int,   .comptime_int   => return .{ .value = @as( i128, @intCast( value )) * ratio.toWhole() },
      .float, .comptime_float => return .{ .value = @as( i128, @intFromFloat( @as( f64, @floatCast( value )) * ratio.toFloat() ))},
      else => @compileError( "Duration.fromUnit() only supports Int and Float values" ),
    }
  }

  pub inline fn fromRayDeltaTime( deltaTime : f32 ) Duration
  {
    return .fromUnit( deltaTime, .SEC );
  }
  pub inline fn toRayDeltaTime( self : Duration ) f32
  {
    return @floatCast( self.castTo( .SEC ));
  }

  pub inline fn fromTimeRate( timeRate : f32 ) Duration
  {
    return .fromUnit( 1.0 / timeRate, .SEC );
  }
  pub inline fn toTimeRate( self : Duration ) f32
  {
    return 1.0 / self.toRayDeltaTime();
  }


  // ======== CHECKERS ========

  pub inline fn isZero( self : *const Duration ) bool { return self.value == 0; }
  pub inline fn isPos(  self : *const Duration ) bool { return self.value >  0; }
  pub inline fn isNeg(  self : *const Duration ) bool { return self.value <  0; }

  // Compatibility helper for old duration-as-maybe-time code. New code should
  // prefer optional Duration fields when "unset" is meaningful.
  pub inline fn isSet( self : *const Duration ) bool { return self.value != 0; }


  // ======== MUTATORS ========

  pub inline fn clear( self : *Duration ) void { self.value = 0; }
  pub inline fn setTo( self : *Duration, newValue : anytype ) void
  {
    self.* = .new( newValue );
  }


  // ======== CONVERSION ========

  pub inline fn castTo( self : *const Duration, unit : TimeUnit ) f64
  {
    const ratio = getTimeRatio( unit, .NS );
    const value : f64 = @floatFromInt( self.value );

    return value * ratio.toFloat();
  }

  pub inline fn truncTo( self : *const Duration, unit : TimeUnit ) i128
  {
    return getTimeRatio( unit, .NS ).applyTrunc( self.value );
  }

  pub inline fn getRemainder( self : *const Duration, unit : TimeUnit ) Duration
  {
    return .{ .value = @mod( self.value, getTimeRatio( .NS, unit ).toWhole() )};
  }

  // Returns this duration's component for `unit`, clipped by that unit's natural
  // parent size. Examples: seconds within a minute, or nanoseconds within a microsecond.
  pub inline fn getUnitPart( self : *const Duration, unit : TimeUnit ) i128
  {
    const total = self.truncTo( unit );
    const clip  = getWholeUnitsPerClip( unit ) orelse return total;

    return @mod( total, clip );
  }

  pub inline fn getClippedUnit( self : *const Duration, unit : TimeUnit ) Duration
  {
    return .fromUnit( self.getUnitPart( unit ), unit );
  }

  pub inline fn toYear( self : *const Duration ) i128 { return self.truncTo( .YEAR ); }
  pub inline fn toWeek( self : *const Duration ) i128 { return self.truncTo( .WEEK ); }
  pub inline fn toDay(  self : *const Duration ) i128 { return self.truncTo( .DAY  ); }
  pub inline fn toHour( self : *const Duration ) i128 { return self.truncTo( .HOUR ); }
  pub inline fn toMin(  self : *const Duration ) i128 { return self.truncTo( .MIN  ); }
  pub inline fn toSec(  self : *const Duration ) i128 { return self.truncTo( .SEC  ); }
  pub inline fn toMs(   self : *const Duration ) i128 { return self.truncTo( .MS   ); }
  pub inline fn toUs(   self : *const Duration ) i128 { return self.truncTo( .US   ); }
  pub inline fn toNs(   self : *const Duration ) i128 { return self.value; }

  pub inline fn convTo( self : *const Duration, comptime retType : type ) retType
  {
    switch( @typeInfo( retType ))
    {
      .int,   .comptime_int   => return @intCast( self.value ),
      .float, .comptime_float => return @as( retType, @floatFromInt( self.value )),
      else => @compileError( "Duration.convTo() only supports Int and Float return types" ),
    }
  }


  // ======== MATH ========

  pub inline fn scaleByFloat( self : *const Duration, scale : f64 ) Duration
  {
    const unscaledFloat : f64 = @floatFromInt( self.value );
    const scaledFloat   : f64 = scale * unscaledFloat;

    return .{ .value = @intFromFloat( @floor( scaledFloat ))};
  }

  pub inline fn clampedMin( self : *const Duration, min : Duration ) Duration
  {
    return .{ .value = @max( self.value, min.value )};
  }
  pub inline fn clampedMax( self : *const Duration, max : Duration ) Duration
  {
    return .{ .value = @min( self.value, max.value )};
  }


  // ======== CONSTANTS ========

  pub inline fn secPerYear() i128 { return getTimeRatio( .SEC, .YEAR ).toWhole(); }
  pub inline fn secPerWeek() i128 { return getTimeRatio( .SEC, .WEEK ).toWhole(); }
  pub inline fn secPerDay()  i128 { return getTimeRatio( .SEC, .DAY  ).toWhole(); }
  pub inline fn secPerHour() i128 { return getTimeRatio( .SEC, .HOUR ).toWhole(); }
  pub inline fn secPerMin()  i128 { return getTimeRatio( .SEC, .MIN  ).toWhole(); }
  pub inline fn secPerSec()  i128 { return getTimeRatio( .SEC, .SEC  ).toWhole(); }

  pub inline fn nsPerYear() i128 { return getTimeRatio( .NS, .YEAR ).toWhole(); }
  pub inline fn nsPerWeek() i128 { return getTimeRatio( .NS, .WEEK ).toWhole(); }
  pub inline fn nsPerDay()  i128 { return getTimeRatio( .NS, .DAY  ).toWhole(); }
  pub inline fn nsPerHour() i128 { return getTimeRatio( .NS, .HOUR ).toWhole(); }
  pub inline fn nsPerMin()  i128 { return getTimeRatio( .NS, .MIN  ).toWhole(); }
  pub inline fn nsPerSec()  i128 { return getTimeRatio( .NS, .SEC  ).toWhole(); }
  pub inline fn nsPerMs()   i128 { return getTimeRatio( .NS, .MS   ).toWhole(); }
  pub inline fn nsPerUs()   i128 { return getTimeRatio( .NS, .US   ).toWhole(); }
  pub inline fn nsPerNs()   i128 { return getTimeRatio( .NS, .NS   ).toWhole(); }

  pub inline fn msPerSec()  i128 { return getTimeRatio( .MS, .SEC ).toWhole(); }
  pub inline fn usPerSec()  i128 { return getTimeRatio( .US, .SEC ).toWhole(); }
};


// ================================ TESTS ================================

test "Duration converts between ray delta seconds and nanoseconds"
{
  const delta = Duration.fromRayDeltaTime( 0.25 );

  try std.testing.expectEqual( @as( i128, 250_000_000 ), delta.value );
  try std.testing.expectApproxEqAbs( @as( f32, 0.25 ), delta.toRayDeltaTime(), 0.0001 );
}

test "Duration routes unit constants through time ratios"
{
  try std.testing.expectEqual( @as( i128, 60_000_000_000 ),         Duration.nsPerMin() );
  try std.testing.expectEqual( @as( i128, 31_536_000_000_000_000 ), getTimeRatio( .NS,  .YEAR ).toWhole() );
  try std.testing.expectEqual( @as( i128, 60 ),                     getTimeRatio( .SEC, .MIN  ).toWhole() );
}

test "Duration casts to requested unit"
{
  const duration = Duration.fromUnit( 90, .SEC );

  try std.testing.expectEqual( @as( i128, 1 ), duration.toMin() );
  try std.testing.expectApproxEqAbs( @as( f64, 1.5 ), duration.castTo( .MIN ), 0.0001 );
}

test "Duration clips unit parts and remainders"
{
  const duration = Duration.fromUnit( 90, .SEC ).scaleByFloat( 1.0 );
  const precise  = Duration.fromUnit( 1, .SEC );

  try std.testing.expectEqual( @as( i128, 30 ), duration.getUnitPart( .SEC ));
  try std.testing.expectEqual( @as( i128, 1  ), duration.getUnitPart( .MIN ));
  try std.testing.expectEqual( @as( i128, 0  ), precise.getRemainder( .SEC ).value );
  try std.testing.expectEqual( @as( i128, 500_000_000 ), Duration.fromUnit( 1.5, .SEC ).getRemainder( .SEC ).value );
}
