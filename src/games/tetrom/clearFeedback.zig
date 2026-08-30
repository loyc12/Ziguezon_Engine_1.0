const utl   = @import( "utils" );
const clear = @import( "clearEvent.zig" );

/// World-space shake translation at full clear intensity.
pub var SHAKE_TRANSLATION       : f64 = 8.0;

/// World-camera rotation in radians at full clear intensity.
pub var SHAKE_ROTATION          : f64 = 0.003;

/// Additional shake force per cleared diagonal line.
pub var SHAKE_LINE_FACTOR       : f64 = 0.10;

/// Additional shake force per unique line crossing.
pub var SHAKE_CROSSING_FACTOR   : f64 = 0.05;

/// Upper bound for clear-event shake force.
pub var SHAKE_MAX_FORCE         : f64 = 2.00;

/// Minimum screen font size for the centre clear-event award.
pub var SCORE_TEXT_MIN_SIZE     : f64 = 32.0;

/// Maximum screen font size for the centre clear-event award.
pub var SCORE_TEXT_MAX_SIZE     : f64 = 128.0;

/// Score at which the centre award reaches its maximum font size.
pub var SCORE_TEXT_FULL_SCALE   : f64 = 8_000.0;

/// Render and camera state derived from the current game-owned clear event.
pub const ClearFeedback = struct
{
  isVisible       : bool = false,
  eventScore      : u64  = 0,
  latestWaveScore : u64  = 0,
  comboBonus      : u64  = 0,
  shakeElapsed    : f32  = 0.0,
  shakeForce      : f64  = 0.0,

  pub fn reset( self : *ClearFeedback ) void
  {
    self.* = .{};
  }

  /// Starts feedback for the first wave or refreshes it for a cascade wave.
  pub fn startWave( self : *ClearFeedback, wave : clear.WaveSummary ) void
  {
    self.isVisible       = true;
    self.eventScore      = wave.eventScore;
    self.latestWaveScore = wave.latestWaveScore;
    self.comboBonus      = wave.comboBonus;
    self.shakeElapsed    = 0.0;
    self.shakeForce      = getShakeForce( wave );
  }

  pub fn finishEvent( self : *ClearFeedback ) void
  {
    self.isVisible = false;
  }

  pub fn tick( self : *ClearFeedback, deltaTime : f32 ) void
  {
    if( !self.isVisible ){ return; }
    self.shakeElapsed += deltaTime;
  }

  /// Returns a small world-camera offset that peaks when tiles become white.
  pub fn getCameraOffset( self : *const ClearFeedback ) utl.VecA
  {
    if( !self.isVisible ){ return .{}; }

    const offset = getShaker().getOffsetAtTime( self.shakeElapsed );
    return .{
      .x = offset.x * self.shakeForce * SHAKE_TRANSLATION,
      .y = offset.y * self.shakeForce * SHAKE_TRANSLATION,
      .a = .{ .r = offset.a.r * self.shakeForce * SHAKE_ROTATION },
    };
  }

  pub fn isShaking( self : *const ClearFeedback ) bool
  {
    return self.isVisible and self.shakeElapsed < getShaker().getTotalLength();
  }

  pub fn getEventTextSize( self : *const ClearFeedback ) f64
  {
    const scoreValue : f64 = @floatFromInt( self.eventScore );
    const progress = utl.clmp( scoreValue / @max( SCORE_TEXT_FULL_SCALE, 1.0 ), 0.0, 1.0 );
    return utl.lerp( SCORE_TEXT_MIN_SIZE, SCORE_TEXT_MAX_SIZE, progress );
  }
};

fn getShakeForce( wave : clear.WaveSummary ) f64
{
  const lines : f64 = @floatFromInt( wave.lineCount );
  const crossings : f64 = @floatFromInt( wave.crossings );
  return @min( 1.0 + ( lines * SHAKE_LINE_FACTOR ) + ( crossings * SHAKE_CROSSING_FACTOR ), SHAKE_MAX_FORCE );
}

fn getShaker() utl.Shake2D
{
  return .{
    .beg_length = clear.CLEAR_FLASH_DURATION,
    .mid_length = 0.0,
    .end_length = clear.CLEAR_FADE_DURATION,
    .shake_speed = 32.0,
    .octave_depth = 6,
  };
}
