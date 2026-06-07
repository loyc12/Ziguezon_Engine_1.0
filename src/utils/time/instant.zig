const std = @import( "std" );

const Duration = @import( "duration.zig" ).Duration;


// ================================ INSTANT STRUCT ================================

pub const Instant = struct
{
  value : i128 = 0,


  // ======== INITIALIZATION ========

  pub inline fn now() Instant
  {
    return .{ .value = std.time.nanoTimestamp() };
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

  // Compatibility helper for old instant-as-maybe-time code. New code should
  // prefer optional Instant fields when "unset" is meaningful.
  pub inline fn isSet( self : *const Instant ) bool { return self.value != 0; }


  // ======== WALL-CLOCK DELTAS ========

  pub inline fn since( self : Instant ) Duration
  {
    return .{ .value = std.time.nanoTimestamp() - self.value };
  }
  pub inline fn until( self : Instant ) Duration
  {
    return .{ .value = self.value - std.time.nanoTimestamp() };
  }

  pub inline fn timeSince( self : Instant ) Duration
  {
    return self.since();
  }
  pub inline fn timeUntil( self : Instant ) Duration
  {
    return self.until();
  }

  pub inline fn diff( self : Instant, other : Instant ) Duration
  {
    const delta = if( self.value >= other.value ) self.value - other.value else other.value - self.value;

    return .{ .value = delta };
  }

  pub inline fn getDurationSince( self : Instant ) Duration
  {
    return self.since();
  }

  pub inline fn getDurationTo( self : Instant ) Duration
  {
    return self.until();
  }

  pub inline fn getDurationBetween( self : Instant, other : Instant ) Duration
  {
    return self.diff( other );
  }

  pub inline fn timeDiff( self : Instant, other : Instant ) Duration
  {
    return self.diff( other );
  }
};


// ================================ SHORTHANDS ================================

pub inline fn getNow() Instant { return .now(); }


// ================================ TESTS ================================

test "Instant diff returns absolute duration"
{
  const t1 : Instant = .new( 100 );
  const t2 : Instant = .new( 40  );

  try std.testing.expectEqual( @as( i128, 60 ), t1.diff( t2 ).value );
  try std.testing.expectEqual( @as( i128, 60 ), t2.diff( t1 ).value );
  try std.testing.expectEqual( @as( i128, 60 ), t1.getDurationBetween( t2 ).value );
}
