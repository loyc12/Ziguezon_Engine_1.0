const std  = @import( "std" );
const utl = @import( "utils" );

const Vec2   = utl.Vec2;
const VecA   = utl.VecA;
const Angle  = utl.Angle;

// ================================ SHAKER STRUCT ================================

pub const Shake2D = struct
{
  // Intensity of each phase's boundary ( b-m-m-e)
  beg_factor : VecA = .{ .x = 0.0, .y = 0.0, .a = .{} },
  mid_factor : VecA = .{ .x = 1.0, .y = 1.0, .a = .{ .r = 1.0 }},
  end_factor : VecA = .{ .x = 0.0, .y = 0.0, .a = .{} },

  // Duration of each phase in seconds ( b-m-e)
  beg_length : f32 = 0.25,
  mid_length : f32 = 0.50,
  end_length : f32 = 0.25,

  // Noise scalers
  shake_speed   : f32 = 32.0, // 0.0 <      Global shake speed multiplier
  octave_freq_f : f32 = 2.00, // 1.0 <      Relative length of successive octaves
  octave_amp_f  : f32 = 0.80, // 0.0 - 1.0  Relative height of successive octaves
  octave_depth  : u32 = 8,    // 1 - ~16    Total number of octaves layered

  octave_offset : f32 = 1.618, // any       Relative offset of successive octave origins
  x_offset      : f32 = 0.793, // any       Relative offset of x values
  y_offset      : f32 = 1.917, // any       Relative offset of y values
  r_offset      : f32 = 2.269, // any       Relative offset of r values

  // ================ VERIFICATION ================

  pub fn isValid( self : *const Shake2D ) bool
  {
    if( self.beg_length < 0 or self.mid_length < 0 or self.end_length < 0 )
    {
      utl.qlog( .WARN, 0, @src(), "Trying to use a Shake2D with negative duration(s)" );
      return false;
    }

    if( self.beg_length <= 0 and self.mid_length <= 0 and self.end_length <= 0 )
    {
      utl.qlog( .WARN, 0, @src(), "Trying to use a Shake2D without any durations" );
      return false;
    }

    if( self.shake_speed <= 0 )
    {
      utl.qlog( .WARN, 0, @src(), "Trying to use a Shake2D with a negative shake speed" );
      return false;
    }

    if( self.octave_depth <= 0 )
    {
      utl.qlog( .WARN, 0, @src(), "Trying to use a Shake2D without octaves" );
      return false;
    }

    if( self.octave_amp_f >= 1.0 or self.octave_freq_f <= 1.0 )
    {
      utl.qlog( .WARN, 0, @src(), "Trying to use a Shake2D with invalid amplitude / frequency" );
      return false;
    }

    return true;
  }

  pub inline fn getTotalLength( self : *const Shake2D ) f32 { return self.beg_length + self.mid_length + self.end_length; }


  // ================ FACTOR ================

  // Progress is mesured between 0.0 and 1.0,
  pub fn getFactorAtProg( self : *const Shake2D, prog : f32 ) VecA { return self.getFactorAtTime( prog * self.getTotalLength() ); }
  pub fn getFactorAtTime( self : *const Shake2D, time : f32 ) VecA
  {
    const tot_length = self.getTotalLength();
    if( !self.isValid() or time < 0.0 or time > tot_length ){ return .{}; }

    if( time < self.beg_length )
    {
      const prog = time / self.beg_length;
      return .{ // In first phase
        .x =         utl.lerp( self.beg_factor.x,   self.mid_factor.x,   prog ),
        .y =         utl.lerp( self.beg_factor.y,   self.mid_factor.y,   prog ),
        .a = .{ .r = utl.lerp( self.beg_factor.a.r, self.mid_factor.a.r, prog )},
      };
    }

    else if( time > tot_length - self.end_length )
    {
      const prog = ( time - self.beg_length - self.mid_length ) / self.end_length;
      return .{ // In third phase
        .x =         utl.lerp( self.mid_factor.x,   self.end_factor.x,   prog ),
        .y =         utl.lerp( self.mid_factor.y,   self.end_factor.y,   prog ),
        .a = .{ .r = utl.lerp( self.mid_factor.a.r, self.end_factor.a.r, prog )},
      };
    }

    else{ return self.mid_factor; } // In the second phase ( constant factor )
  }


  // ================ NOISE ================

  pub fn getNoiseAtProg( self : *const Shake2D, prog : f32 ) VecA { return self.getNoiseValAtTime( prog * self.getTotalLength()); }
  pub fn getNoiseAtTime( self : *const Shake2D, time : f32 ) VecA
  {
    const tot_length = self.getTotalLength();

    if( !self.isValid() or time < 0.0 or time > tot_length ){ return .{}; }

    var nx : f32 = 0.0;
    var ny : f32 = 0.0;
    var nr : f32 = 0.0;

    var amp  : f32 = 1.0;
    var freq : f32 = 1.0;

    for ( 0 .. self.octave_depth )| i |
    {
      const iter : f32 = @floatFromInt( i );

      const oct_off  = iter * self.octave_offset;
      const oct_freq = time * self.shake_speed * freq;

      nx += ( @sin(( oct_freq * 1.00 ) + self.x_offset + ( 2 * oct_off )) + @cos(( oct_freq * 1.63 ) + self.x_offset - ( 5 * oct_off ))) * amp;
      ny += ( @sin(( oct_freq * 1.37 ) + self.y_offset + ( 3 * oct_off )) + @cos(( oct_freq * 1.17 ) + self.y_offset - ( 2 * oct_off ))) * amp;
      nr += ( @sin(( oct_freq * 2.53 ) + self.r_offset + ( 5 * oct_off )) + @cos(( oct_freq * 0.77 ) + self.r_offset - ( 3 * oct_off ))) * amp;

      // Move to the next octave
      freq *= self.octave_freq_f;
      amp  *= self.octave_amp_f;
    }

    // Normalize: max possible amplitude = 2 * sum(amplitudes)
    const norm = 2.0 * ( 1.0 - std.math.pow( f32, self.octave_amp_f, @floatFromInt( self.octave_depth ))) / ( 1.0 - self.octave_amp_f );

    return .{ .x = nx / norm, .y = ny / norm, .a = .{ .r = nr / norm } };
  }

  // ================ Offset ================

  pub fn getOffsetAtProg( self : *const Shake2D, prog : f32 ) VecA { return self.getOffsetAtTime( prog * self.getTotalLength()); }
  pub fn getOffsetAtTime( self : *const Shake2D, time : f32 ) VecA
  {
    const factor = self.getFactorAtTime( time );
    const noise  = self.getNoiseAtTime( time );

    return .{ .x = factor.x * noise.x, .y = factor.y * noise.y, .a = .{ .r = factor.a.r * noise.a.r }};
  }
};
