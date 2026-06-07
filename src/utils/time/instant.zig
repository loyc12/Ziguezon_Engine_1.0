const std = @import( "std" );

const durationMod = @import( "duration.zig" );

const Duration = durationMod.Duration;

// std.time.Instant is the monotonic source, but this project exposes Instants as
// plain i128 nanosecond values. These globals translate monotonic samples into
// that project-local timeline.
var monoLast  : ?std.time.Instant = null;
var monoValue : ?i128             = null;


fn readFallbackTimestamp() i128
{
  // If monotonic time is unavailable, fall back to wall-clock nanoseconds while
  // clamping backward jumps. This is less precise semantically, but still avoids
  // negative elapsed time after system clock changes.
  const now = std.time.nanoTimestamp();

  if( monoValue )| value |
  {
    if( now > value ){ monoValue = now; }
  }
  else
  {
    monoValue = now;
  }

  return monoValue.?;
}

fn readMonotonicTimestamp() i128
{
  // This bridge is kept intentionally: existing code reads Instant.value for
  // logs/seeds, while elapsed math still needs monotonic deltas.
  const now = std.time.Instant.now() catch return readFallbackTimestamp();

  if( monoValue == null ){ monoValue = std.time.nanoTimestamp(); }

  if( monoLast )| last |
  {
    if( now.order( last ) == .gt )
    {
      // std.time.Instant.since() assumes `now >= last`; the order check above
      // keeps that precondition true even on odd platform timer behavior.
      monoValue = durationMod.saturatingAdd( monoValue.?, @intCast( now.since( last )));
    }
  }

  monoLast = now;
  return monoValue.?;
}


// ================================ INSTANT STRUCT ================================

pub const Instant = struct
{
  value : i128 = 0,


  // ======== INITIALIZATION ========

  pub inline fn now() Instant
  {
    // Current project-local monotonic timestamp.
    return .{ .value = readMonotonicTimestamp() };
  }
  pub inline fn newNow() Instant
  {
    return .now();
  }

  pub inline fn new( value : anytype ) Instant
  {
    switch( @typeInfo( @TypeOf( value )))
    {
      .int, .comptime_int => return .{ .value = @intCast( value )},
      else => @compileError( "Instant.new() only supports Int values" ),
    }
  }


  // ======== CHECKERS ========

  pub inline fn isZero( self : *const Instant ) bool { return self.value == 0; }


  // ======== ELAPSED DELTAS ========

  pub inline fn since( self : Instant ) Duration
  {
    // Elapsed time from `self` to now. Can be negative for manually-created
    // future Instants, but normal `.now()` values are monotonic.
    return .{ .value = durationMod.saturatingSub( readMonotonicTimestamp(), self.value )};
  }
  pub inline fn until( self : Instant ) Duration
  {
    // Time from now to `self`; useful for deadlines or countdowns.
    return .{ .value = durationMod.saturatingSub( self.value, readMonotonicTimestamp() )};
  }

  /// Can return a negative value
  pub inline fn diff( self : Instant, other : Instant ) Duration
  {
    return .{ .value = durationMod.saturatingSub( self.value, other.value )};
  }
  /// Always returns a positive value
  pub inline fn span( self : Instant, other : Instant ) Duration
  {
    const delta = self.diff( other ).value;

    if( delta == std.math.minInt( i128 )){ return .{ .value = std.math.maxInt( i128 )}; }

    return .{ .value = if( delta < 0 ) -delta else delta };
  }
};


// ================================ SHORTHANDS ================================

pub inline fn getNow() Instant { return .now(); }


// ================================ TESTS ================================

test "Instant diff returns directional duration"
{
  const t1 : Instant = .new( 100 );
  const t2 : Instant = .new( 40  );

  try std.testing.expectEqual( @as( i128, 60 ), t1.diff( t2 ).value );
  try std.testing.expectEqual( @as( i128, -60 ), t2.diff( t1 ).value );
  try std.testing.expectEqual( @as( i128, 60 ), t1.span( t2 ).value );
}

test "Instant diff saturates extreme values"
{
  const low  : Instant = .new( std.math.minInt( i128 ));
  const high : Instant = .new( std.math.maxInt( i128 ));

  try std.testing.expectEqual( std.math.maxInt( i128 ), high.diff( low  ).value );
  try std.testing.expectEqual( std.math.minInt( i128 ), low.diff(  high ).value );
  try std.testing.expectEqual( std.math.maxInt( i128 ), low.span(  high ).value );
}
