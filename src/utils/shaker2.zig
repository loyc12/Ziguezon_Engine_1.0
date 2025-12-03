const std  = @import( "std" );
const def  = @import( "defs" );

const Vec2   = def.Vec2;
const VecA   = def.VecA;
const Angle  = def.Angle;

// ================================ SHAKER STRUCT ================================

pub const Shake2D = struct
{
  // Intensity of each phase's boundary ( b-m-m-e)
  beg_factor : VecA = .{ .x = 0.0, .y = 0.0, .a = .{} },
  mid_factor : VecA = .{ .x = 1.0, .y = 1.0, .a = .{} },
  end_factor : VecA = .{ .x = 0.0, .y = 0.0, .a = .{} },

  // Duration of each phase in seconds ( b-m-e)
  beg_lenght : f32 = 1.0,
  mid_lenght : f32 = 2.0,
  end_lenght : f32 = 1.0,

  // Noise scalers
  shake_speed   : f32 = 8.00, // 0.0 <      Global shake speed multiplier
  octave_freq_f : f32 = 2.00, // 1.0 <      Relative lenght of successive octaves
  octave_amp_f  : f32 = 0.50, // 0.0 - 1.0  Relative height of successive octaves
  octave_depth  : u32 = 4,    // 1 - ~8     Total number of octaves layered

  octave_offset : f32 = 1.618, // any       Relative offset of successive octave origins
  x_offset      : f32 = 0.000, // any       Relative offset of x values
  y_offset      : f32 = 1.917, // any       Relative offset of y values
  r_offset      : f32 = 2.269, // any       Relative offset of r values

  // ================ VERIFICATION ================

  pub fn isValid( self : *const Shake2D ) bool
  {
    if( self.beg_lenght < 0 or self.mid_lenght < 0 or self.end_lenght < 0 )
    {
      def.qlog( .WARN, 0, @src(), "Trying to use a Shake2D with negative duration(s)" );
      return false;
    }

    if( self.beg_lenght <= 0 and self.mid_lenght <= 0 and self.end_lenght <= 0 )
    {
      def.qlog( .WARN, 0, @src(), "Trying to use a Shake2D without any durations" );
      return false;
    }

    if( self.shake_speed <= 0 )
    {
      def.qlog( .WARN, 0, @src(), "Trying to use a Shake2D with a negative shake speed" );
      return false;
    }

    if( self.octave_depth <= 0 )
    {
      def.qlog( .WARN, 0, @src(), "Trying to use a Shake2D without octaves" );
      return false;
    }

    if( self.octave_amp_f >= 1.0 or self.octave_freq_f <= 1.0 )
    {
      def.qlog( .WARN, 0, @src(), "Trying to use a Shake2D with invalid amplitude / frequency" );
      return false;
    }

    return true;
  }

  pub inline fn getTotalLenght( self : *const Shake2D ) f32 { return self.beg_lenght + self.mid_lenght + self.end_lenght; }


  // ================ FACTOR ================

  // Progress is mesured between 0.0 and 1.0,
  pub fn getFactorAtProg( self : *const Shake2D, prog : f32 ) VecA { return self.getFactorAtTime( prog * self.getTotalLenght() ); }
  pub fn getFactorAtTime( self : *const Shake2D, time : f32 ) VecA
  {
    const tot_lenght = self.getTotalLenght();
    if( !self.isValid() or time < 0.0 or time > tot_lenght ){ return .{}; }

    if( time < self.beg_lenght )
    {
      const prog = time / self.beg_lenght;
      return .{ // In first phase
        .x =         def.lerp( self.beg_factor.x,   self.mid_factor.x,   prog ),
        .y =         def.lerp( self.beg_factor.y,   self.mid_factor.y,   prog ),
        .a = .{ .r = def.lerp( self.beg_factor.a.r, self.mid_factor.a.r, prog )},
      };
    }

    else if( time > tot_lenght - self.end_lenght )
    {
      const prog = ( time - self.beg_lenght - self.mid_lenght ) / self.end_lenght;
      return .{ // In third phase
        .x =         def.lerp( self.mid_factor.x,   self.end_factor.x,   prog ),
        .y =         def.lerp( self.mid_factor.y,   self.end_factor.y,   prog ),
        .a = .{ .r = def.lerp( self.mid_factor.a.r, self.end_factor.a.r, prog )},
      };
    }

    else{ return self.mid_factor; } // In the second phase ( constant factor )
  }


  // ================ NOISE ================

  pub fn getNoiseAtProg( self : *const Shake2D, prog : f32 ) VecA { return self.getNoiseValAtTime( prog * self.getTotalLenght()); }
  pub fn getNoiseAtTime( self : *const Shake2D, time : f32 ) VecA
  {
    const tot_lenght = self.getTotalLenght();

    if( !self.isValid() or time < 0.0 or time > tot_lenght ){ return .{}; }

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

  pub fn getOffsetAtProg( self : *const Shake2D, prog : f32 ) VecA { return self.getOffsetAtTime( prog * self.getTotalLenght()); }
  pub fn getOffsetAtTime( self : *const Shake2D, time : f32 ) VecA
  {
    const factor = self.getFactorAtTime( time );
    const noise  = self.getNoiseAtTime( time );

    return .{ .x = factor.x * noise.x, .y = factor.y * noise.y, .a = .{ .r = factor.a.r * noise.a.r }};
  }
};
