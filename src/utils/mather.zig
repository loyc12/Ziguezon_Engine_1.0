const std = @import( "std" );
const def = @import( "defs" );

pub const lerp = std.math.lerp;

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

pub fn clmp( val : anytype, min : @TypeOf( val ), max : @TypeOf( val )) @TypeOf( val )
{
  switch( @typeInfo( @TypeOf( val )))
  {
    .float, .comptime_float, .int, .comptime_int =>
      return if ( val < min ) min else if ( val > max ) max else val,

    else => @compileError( "clmp() only supports Int and Float types" ),
  }
}
pub fn norm( val : anytype, min : @TypeOf( val ), max : @TypeOf( val )) @TypeOf( val )
{
  switch( @typeInfo( @TypeOf( val ))) // Normalizes a value to the range ( 0.0, 1.0 )
  {
    .float, .comptime_float => return ( val - min ) / ( max - min ),
    else => @compileError( "norm() only supports Float types" ),
  }
}
pub fn denorm( val : anytype, min : @TypeOf( val ), max : @TypeOf( val )) @TypeOf( val )
{
  switch( @typeInfo( @TypeOf( val ))) // Denormalizes a value from the range ( 0.0, 1.0 )
  {
    .float, .comptime_float => return ( val * ( max - min )) + min,
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