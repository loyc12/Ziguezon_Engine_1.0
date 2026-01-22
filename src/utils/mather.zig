const std = @import( "std" );
const def = @import( "defs" );

pub const atan2 = std.math.atan2;
pub const DtR   = std.math.degreesToRadians;
pub const RtD   = std.math.radiansToDegrees;

pub const E     = std.math.e;
pub const PI    = std.math.pi;
pub const TAU   = std.math.tau;
pub const PHI   = std.math.phi;
pub const EPS   = 0.0000001;

pub const R2  = @sqrt( 2.0 );
pub const HR2 = R2 / 2.0;
pub const IR2 = 1.0 / R2;

pub const R3  = @sqrt( 3.0 );
pub const HR3 = R3 / 2.0;
pub const IR3 = 1.0 / R3;

pub const lerp  = std.math.lerp;

pub fn sign( val : anytype ) @TypeOf( val )
{
  switch( @typeInfo( @TypeOf( val )))
  {
    .float, .comptime_float =>
    {
      if( val > 0.0 ){ return  1.0; }
      if( val < 0.0 ){ return -1.0; }
      return 0.0;
    },
    .int, .comptime_int =>
    {
      if( val > 0 ){ return  1; }
      if( val < 0 ){ return -1; }
      return 0;
    },
    else => @compileError( "sign() only supports Int and Float types" ),
  }
}

pub fn med3( a : anytype, b : @TypeOf( a ), c : @TypeOf( a )) @TypeOf( a )
{
  switch( @typeInfo( @TypeOf( a )))
  {
    .float, .comptime_float, .int, .comptime_int =>
    {
      if( a < b )
      {
        if(      b < c ){ return b; } // a <  b <  c
        else if( a < c ){ return c; } // a <  c <= b
        else            { return a; } // c <= a <  b
      }
      else
      {
        if(      a < c ){ return a; } // b <  a <  c
        else if( b < c ){ return c; } // b <  c <= a
        else            { return b; } // c <= b <  a
      }
    },
    else => @compileError( "med3() only supports Int and Float types" ),
  }
}

// Equivalent to successives calls to min() and max()
pub fn clmp( val : anytype, min : @TypeOf( val ), max : @TypeOf( val )) @TypeOf( val )
{
  return @min( @max( val, min ), max );
  //switch( @typeInfo( @TypeOf( val )))
  //{
  //  .float, .comptime_float, .int, .comptime_int => return if( val < min ) min else if( val > max ) max else val,
  //  else => @compileError( "clmp() only supports Int and Float types" ),
  //}
}

// Equivalent to modulo operation that wraps the value around the range [ min, max ]
pub fn wrap( val : anytype, min : @TypeOf( val ), max : @TypeOf( val )) @TypeOf( val )
{
  switch( @typeInfo( @TypeOf( val )))
  {
    .float, .comptime_float, .int, .comptime_int =>
    {
      if( max <= min )
      {
        def.qlog( .ERROR, 0, @src(), "wrap() called with max <= min" );
        return min; // or max, they are the same
      }
      const range = max - min;

      return @mod( val - min, range) + min;
    },
    else => @compileError( "wrap() only supports Int and Float types" ),
  }
}

pub fn norm( val : anytype, min : @TypeOf( val ), max : @TypeOf( val )) @TypeOf( val )
{
  switch( @typeInfo( @TypeOf( val ))) // Normalizes a value to the range ( 0.0, 1.0 )
  {
    .float, .comptime_float => return( val - min ) / ( max - min ),
    else => @compileError( "norm() only supports Float types" ),
  }
}
pub fn denorm( val : anytype, min : @TypeOf( val ), max : @TypeOf( val )) @TypeOf( val )
{
  switch( @typeInfo( @TypeOf( val ))) // Denormalizes a value from the range ( 0.0, 1.0 )
  {
    .float, .comptime_float => return( val * ( max - min )) + min,
    else => @compileError( "denorm() only supports Float types" ),
  }
}
pub fn renorm( val : anytype, srcMin : @TypeOf( val ), srcMax : @TypeOf( val ), dstMin : @TypeOf( val ), dstMax : @TypeOf( val )) @TypeOf( val )
{
  switch( @typeInfo( @TypeOf( val ))) // Renormalizes a value from a src range to a dst range
  {
    .float, .comptime_float => return norm( denorm( val, srcMin, srcMax ), dstMin, dstMax ),
    else => @compileError( "renorm() only supports Float types" ),
  }
}

pub fn getPolyArea( circumradius : f32, sideCount : u8 ) f32
{
  if( sideCount < 3 )
  {
    def.qlog( .ERROR, 0, @src(), "getPolyArea() called with sides < 3" );
    return 0.0;
  }

  if( sideCount == 255 )
  {
    def.qlog( .DEBUG, 0, @src(), "getPolyArea() called with sides = 255 ( treating as circle )" );
    return PI * circumradius * circumradius;
  }

  const n = @as( f32, @floatFromInt( sideCount ));

  const facetAngle = DtR( 360.0 / n );
  return ( 0.5 * n * circumradius * circumradius * std.math.sin( facetAngle ));
}

pub fn getPolyCircumRad( area : f32, sideCount : u8 ) f32
{
  if( sideCount < 3 )
  {
    def.qlog( .ERROR, 0, @src(), "getPolyCircumradius() called with sides < 3" );
    return 0.0;
  }

  if( sideCount == 255 )
  {
    def.qlog( .DEBUG, 0, @src(), "getPolyCircumradius() called with sides = 255 ( treating as circle )" );
    return std.math.sqrt( area / PI );
  }

  const n = @as( f32, @floatFromInt( sideCount ));

  const facetAngle = DtR( 360.0 / n );
  return std.math.sqrt( 2.0 * area / n * std.math.sin( facetAngle ));
}