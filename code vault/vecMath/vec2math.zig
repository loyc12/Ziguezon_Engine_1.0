const std = @import( "std" );
const def = @import( "defs" );

pub const Vec2  = def.ray.Vector2;
pub const atan2 = def.atan2;
pub const DtR   = def.DtR;
pub const RtD   = def.RtD;

pub inline fn newVec2( x : f32, y : f32 ) Vec2 { return Vec2{ .x = x, .y = y }; }
pub inline fn zeroVec2() Vec2 { return Vec2{ .x = 0.0, .y = 0.0 }; }

// ================================ SCALAR MATH ================================

pub inline fn addValToVec2( v : Vec2, c : f32 ) Vec2 { return Vec2{ .x = v.x + c, .y = v.y + c }; }
pub inline fn subValToVec2( v : Vec2, c : f32 ) Vec2 { return Vec2{ .x = v.x - c, .y = v.y - c }; }
pub inline fn mulVec2ByVal( v : Vec2, c : f32 ) Vec2 { return Vec2{ .x = v.x * c, .y = v.y * c }; }
pub        fn divVec2ByVal( v : Vec2, c : f32 ) ?Vec2
{
  if( c == 0.0 )
  {
    def.qlog( .ERROR, 0, @src(), "Division by zero in divVec2ByVal()" );
    return null;
  }
  return Vec2{ .x = v.x / c, .y = v.y / c };
}

// Normalizes a vector back to a unit vector ( length of 1 ), returns null if the vector is zero'd
pub inline fn normVec2Unit( v : Vec2 ) ?Vec2 { return normVec2Len( v, 1.0 ); }

// Normalizes a vector to a new length, returns null if the vector is zero'd
pub fn normVec2Len( v : Vec2, newLen : f32 ) ?Vec2
{
  const oldLen = @sqrt(( v.x * v.x ) + ( v.y * v.y ));
  if( oldLen  == 0.0 )
  {
    def.qlog( .ERROR, 0, @src(), "Normalizing a zero vector in normVec2()" );
    return null;
  }

  const factor = newLen / oldLen;
  if( factor == 1.0 ){ return v; }

  return Vec2{ .x = v.x * factor, .y = v.y * factor };
}


// =============================== VECTOR MATH ================================

pub inline fn addVec2( a : Vec2, b : Vec2 ) Vec2 { return Vec2{ .x = a.x + b.x, .y = a.y + b.y }; }
pub inline fn subVec2( a : Vec2, b : Vec2 ) Vec2 { return Vec2{ .x = a.x - b.x, .y = a.y - b.y }; }
pub inline fn mulVec2( a : Vec2, b : Vec2 ) Vec2 { return Vec2{ .x = a.x * b.x, .y = a.y * b.y }; }
pub        fn divVec2( a : Vec2, b : Vec2 ) ?Vec2
{
  if( b.x == 0.0 or b.y == 0.0 )
  {
    @compileLog( "Warning: Division by zero in divVec2()" );
    def.qlog( .ERROR, 0, @src(), "Division by zero in divVec2()" );
    return null;
  }
  return Vec2{ .x = a.x / b.x, .y = a.y / b.y };
}


// ================================ DISTANCE MATH ================================
// NOTE : These functions are used to calculate UNSIGNED linear distances between vectors

// Returns the Euclidian ( Chebyshev ) distance between two vectors
pub inline fn getVec2Dist( p1 : Vec2, p2 : Vec2 ) f32 { return @sqrt( getVec2SqrDist( p1, p2 ) ); }

// Returns the Cartesian ( Taxicab / Manhattan ) distance between two vectors
pub inline fn getVec2CartDist( p1 : Vec2, p2 : Vec2 ) f32 { return @abs( p2.x - p1.x ) + @abs( p2.y - p1.y ); }

// Returns the square of the distance between two vectors ( helps to avoid unnecessary sqrt() calls )
pub inline fn getVec2SqrDist(  p1 : Vec2, p2 : Vec2 ) f32
{
  const dist = def.Vec2{ .x = p2.x - p1.x, .y = p2.y - p1.y, };
  return( dist.x * dist.x ) + ( dist.y * dist.y );
}

// Returns the linear distance between two vectors along a given axis
pub inline fn getVec2DistX( p1 : Vec2, p2 : Vec2 ) f32 { return @abs( p2.x - p1.x ); }
pub inline fn getVec2DistY( p1 : Vec2, p2 : Vec2 ) f32 { return @abs( p2.y - p1.y ); }


// ================================ ANGULAR MATH ================================
// NOTE : all returned angles are unsigned, in the range [ 0, 360 ] for degrees and [ 0, 2*PI ] for radians

pub inline fn rotVec2Deg( a : Vec2, angleDeg : f32 ) Vec2 { return rotVec2Rad( a, DtR( angleDeg )); }
pub        fn rotVec2Rad( a : Vec2, angleRad : f32 ) Vec2
{
  if( angleRad == 0.0 ){ return a; }

  const cosAngle = @cos( angleRad );
  const sinAngle = @sin( angleRad );

  return Vec2
  {
    .x = ( a.x * cosAngle ) - ( a.y * sinAngle ),
    .y = ( a.x * sinAngle ) + ( a.y * cosAngle ),
  };
}

pub inline fn vec2ToDeg( v : Vec2 ) f32 { return RtD( vec2ToRad( v )); }
pub        fn vec2ToRad( v : Vec2 ) f32
{
  if( v.x == 0.0 and v.y == 0.0 )
  {
    @compileLog( "Warning: Getting angle of a zero vector in getVec2Angle()" );
    def.qlog( .ERROR, 0, @src(), "Getting angle of a zero vector in getVec2Angle()" );
    return 0.0;
  }
  return atan2( v.y, v.x );
}

// Returns the unsinged angular distance between two vectors sharing the same origin
pub inline fn vec2AngularDistDeg( p1 : Vec2, p2 : Vec2, origin : ?Vec2, ) f32 { return RtD( vec2AngularDistRad( p1, p2, origin )); }
pub        fn vec2AngularDistRad( p1 : Vec2, p2 : Vec2, origin : ?Vec2, ) f32
{
  if( origin )| p0 |
  {
    const a1 = atan2( p1.y - p0.y, p1.x - p0.x );
    const a2 = atan2( p2.y - p0.y, p2.x - p0.x );
    return @abs( a1 - a2 );
  }
  else { return @abs( atan2( p1.y, p1.x ) - atan2( p2.y, p2.x )); }
}


// ================================ VECTOR(S) GENERATORS ================================
// These functions are used to create scaled unit vectors from angles

pub inline fn degToVec2( angleDeg : f32 ) Vec2 { return radToVec2( DtR( angleDeg )); }
pub inline fn radToVec2( angleRad : f32 ) Vec2 { return Vec2{ .x = @cos( angleRad ), .y = @sin( angleRad ) }; }

pub inline fn degToVec2Scaled( angleDeg : f32, scale : Vec2 ) Vec2 { return radToVec2Scaled( scale, DtR( angleDeg )); }
pub inline fn radToVec2Scaled( angleRad : f32, scale : Vec2 ) Vec2 { return mulVec2( radToVec2( angleRad ), scale ); }