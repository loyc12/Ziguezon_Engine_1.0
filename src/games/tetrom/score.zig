const std = @import( "std" );
const utl = @import( "utils" );

/// Minor score awarded for every piece cell that successfully locks into the board.
pub var LOCKED_TILE_SCORE : u64 = 5;

/// The score contributed by one resolved diagonal-clear wave.
pub const WaveScore = struct
{
  lineCount : u8,
  crossings : u8,
  award     : u64,
};

/// Scores a clear with a triangular line award and normalized crossing bonus.
pub fn getWaveScore( lineCount : u8, crossings : u8 ) WaveScore
{
  const lines : u64 = lineCount;
  const base = 100 * lines * ( lines + 1 ) / 2;
  const award : u64 = @intFromFloat( @round( @as( f64, @floatFromInt( base )) * getCrossingFactor( crossings )));

  return .{ .lineCount = lineCount, .crossings = crossings, .award = award };
}

/// Returns the extra score carried from a preceding wave in the same event.
pub fn getComboBonus( eventScore : u64 ) u64
{
  const multiplied : u64 = @intFromFloat( @floor( @as( f64, @floatFromInt( eventScore )) * 1.5 ));
  return multiplied - eventScore;
}

/// Normalized sigmoid bonus: zero crossings yields 1x and high counts approach 2x.
pub fn getCrossingFactor( crossings : u8 ) f64
{
  const crossingCount : f64 = @floatFromInt( crossings );
  const baseline = utl.sigmoid( -1.0, 0.5 );
  const response = utl.sigmoid( crossingCount - 1.0, 0.5 );

  return 1.0 + ( response - baseline ) / ( 1.0 - baseline );
}

test "crossing bonus starts at one and grows toward two"
{
  try std.testing.expectApproxEqAbs( @as( f64, 1.0 ), getCrossingFactor( 0 ), 0.000001 );
  try std.testing.expect( getCrossingFactor( 1 ) > 1.0 );
  try std.testing.expect( getCrossingFactor( 32 ) < 2.0 );
}

test "combo bonus keeps the event score's integer half"
{
  try std.testing.expectEqual( @as( u64, 50 ), getComboBonus( 100 ));
  try std.testing.expectEqual( @as( u64, 1 ),  getComboBonus( 3 ));
}
