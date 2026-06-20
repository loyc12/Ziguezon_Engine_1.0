const std = @import( "std" );
const utl = @import( "utils" );

const durationMod = @import( "duration.zig" );
const instantMod  = @import( "instant.zig" );

const Duration = durationMod.Duration;
const Instant  = instantMod.Instant;


// ================================ TIMESPAN STRUCT ================================

/// Passive interval on the engine's `Instant` timeline. Stored as a start point
/// plus a non-negative duration so span math has one canonical form.
pub const Timespan = struct
{
  start    : Instant  = .{},
  duration : Duration = .{},


  // ======== INITIALIZATION ========

  pub inline fn fromStartDuration( start : Instant, duration : Duration ) Timespan
  {
    if( !isDurationValid( duration )){ return .{}; }

    return .{ .start = start, .duration = duration };
  }

  pub inline fn fromStartEnd( start : Instant, end : Instant ) Timespan
  {
    if( !isRangeValid( start, end )){ return .{}; }

    return .{
      .start    = start,
      .duration = .{ .value = durationMod.saturatingSub( end.value, start.value )},
    };
  }

  pub inline fn fromEndDuration( end : Instant, duration : Duration ) Timespan
  {
    if( !isDurationValid( duration )){ return .{}; }

    return .{
      .start    = .new( durationMod.saturatingSub( end.value, duration.value )),
      .duration = duration,
    };
  }


  // ======== RANGE QUERIES ========

  pub inline fn getEnd( self : *const Timespan ) Instant
  {
    return .new( durationMod.saturatingAdd( self.start.value, self.duration.value ));
  }

  pub inline fn getOffsetAt( self : *const Timespan, instant : Instant ) Duration
  {
    return .{ .value = durationMod.saturatingSub( instant.value, self.start.value )};
  }

  pub inline fn getElapsedAt( self : *const Timespan, instant : Instant ) Duration
  {
    const offset = self.getOffsetAt( instant );

    if( offset.value <= 0 ){ return .{}; }
    if( offset.value >= self.duration.value ){ return self.duration; }

    return offset;
  }

  pub inline fn getRemainingAt( self : *const Timespan, instant : Instant ) Duration
  {
    const elapsed = self.getElapsedAt( instant );

    return .{ .value = durationMod.saturatingSub( self.duration.value, elapsed.value )};
  }

  pub inline fn getProgressAt( self : *const Timespan, instant : Instant ) f64
  {
    if( self.duration.value == 0 )
    {
      return if( self.hasEndedAt( instant )) 1.0 else 0.0;
    }

    const elapsed : f64 = @floatFromInt( self.getElapsedAt( instant ).value );
    const total   : f64 = @floatFromInt( self.duration.value );

    return elapsed / total;
  }


  // ======== CHECKERS ========

  pub inline fn hasStartedAt( self : *const Timespan, instant : Instant ) bool
  {
    return instant.value >= self.start.value;
  }

  pub inline fn hasEndedAt( self : *const Timespan, instant : Instant ) bool
  {
    return instant.value >= self.getEnd().value;
  }

  pub inline fn containsInstant( self : *const Timespan, instant : Instant ) bool
  {
    // Timespans are half-open intervals: [start, end).
    return instant.value >= self.start.value and instant.value < self.getEnd().value;
  }

  pub inline fn containsSpan( self : *const Timespan, other : Timespan ) bool
  {
    if( other.duration.value == 0 ){ return self.containsInstant( other.start ); }

    return other.start.value >= self.start.value and other.getEnd().value <= self.getEnd().value;
  }

  pub inline fn overlaps( self : *const Timespan, other : Timespan ) bool
  {
    if( self.duration.value  == 0 ){ return other.containsInstant( self.start  ); }
    if( other.duration.value == 0 ){ return self.containsInstant(  other.start ); }

    return self.start.value < other.getEnd().value and other.start.value < self.getEnd().value;
  }

  pub inline fn isBefore( self : *const Timespan, other : Timespan ) bool
  {
    return self.getEnd().value <= other.start.value;
  }

  pub inline fn isAfter( self : *const Timespan, other : Timespan ) bool
  {
    return self.start.value >= other.getEnd().value;
  }


  // ======== HELPERS ========

  pub inline fn isDurationValid( duration : Duration ) bool
  {
    if( duration.value < 0 )
    {
      utl.log( .ERROR, @src(), "Timespan duration must be non-negative, got {d}", .{ duration.value });
      return false;
    }
    return true;
  }

  pub inline fn isRangeValid( start : Instant, end : Instant ) bool
  {
    if( end.value < start.value )
    {
      utl.log( .ERROR, @src(), "Timespan end ({d}) must not be before start ({d})", .{ end.value, start.value });
      return false;
    }
    return true;
  }
};


// ================================ TESTS ================================

test "Timespan constructs from start and end"
{
  const span : Timespan = .fromStartEnd( .new( 10 ), .new( 25 ));

  try std.testing.expectEqual( @as( i128, 10 ), span.start.value );
  try std.testing.expectEqual( @as( i128, 15 ), span.duration.value );
  try std.testing.expectEqual( @as( i128, 25 ), span.getEnd().value );
}

test "Timespan checks half-open instant containment"
{
  const span : Timespan = .fromStartDuration( .new( 10 ), .new( 15, .NS ));

  try std.testing.expect( !span.containsInstant( .new( 9  )));
  try std.testing.expect(  span.containsInstant( .new( 10 )));
  try std.testing.expect(  span.containsInstant( .new( 24 )));
  try std.testing.expect( !span.containsInstant( .new( 25 )));
}

test "Timespan reports clamped elapsed remaining and progress"
{
  const span : Timespan = .fromStartDuration( .new( 10 ), .new( 20, .NS ));

  try std.testing.expectEqual( @as( i128, 0  ), span.getElapsedAt(   .new( 5  )).value );
  try std.testing.expectEqual( @as( i128, 5  ), span.getElapsedAt(   .new( 15 )).value );
  try std.testing.expectEqual( @as( i128, 20 ), span.getElapsedAt(   .new( 40 )).value );
  try std.testing.expectEqual( @as( i128, 15 ), span.getRemainingAt( .new( 15 )).value );
  try std.testing.expectApproxEqAbs( @as( f64, 0.25 ), span.getProgressAt( .new( 15 )), 0.0001 );
}

test "Timespan detects contained and overlapping spans"
{
  const span       : Timespan = .fromStartEnd( .new( 10 ), .new( 30 ));
  const contained  : Timespan = .fromStartEnd( .new( 12 ), .new( 18 ));
  const overlapping: Timespan = .fromStartEnd( .new( 25 ), .new( 40 ));
  const adjacent   : Timespan = .fromStartEnd( .new( 30 ), .new( 40 ));

  try std.testing.expect(  span.containsSpan( contained   ));
  try std.testing.expect( !span.containsSpan( overlapping ));
  try std.testing.expect(  span.overlaps(     overlapping ));
  try std.testing.expect( !span.overlaps(     adjacent    ));
}

test "Timespan invalid constructors log and return empty spans"
{
  const negDuration : Timespan = .fromStartDuration( .new( 10 ), .{ .value = -1 });
  const backRange   : Timespan = .fromStartEnd( .new( 10 ), .new( 5 ));

  try std.testing.expectEqual( @as( i128, 0 ), negDuration.start.value );
  try std.testing.expectEqual( @as( i128, 0 ), negDuration.duration.value );
  try std.testing.expectEqual( @as( i128, 0 ), backRange.start.value );
  try std.testing.expectEqual( @as( i128, 0 ), backRange.duration.value );
}
