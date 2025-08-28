const std = @import( "std" );
const def = @import( "defs" );

pub const Vec2  = def.ray.Vector2;
pub const VecA  = def.ray.Vector3;
pub const atan2 = def.atan2;
pub const DtR   = def.DtR;
pub const RtD   = def.RtD;

// NOTE : In this vector format, z represent the rotation angle R in radians, while x and y are the coordinates.

pub inline fn newVecA( x : f32, y : f32, r : ?f32 ) VecA
{
  if( r )| angle | { return VecA{ .x = x, .y = y, .z = angle }; }
  else             { return VecA{ .x = x, .y = y, .z = 0.0   }; }
}
pub inline fn zeroVecA() VecA { return VecA{ .x = 0.0, .y = 0.0, .z = 0.0 }; } // Returns a zero'd vector

// ================================ SCALAR MATH ================================

pub inline fn addValToVecA( v : VecA, c : f32 ) VecA { return VecA{ .x = v.x + c, .y = v.y + c, .z = v.z + 0.0 }; }
pub inline fn subValToVecA( v : VecA, c : f32 ) VecA { return VecA{ .x = v.x - c, .y = v.y - c, .z = v.z + 0.0 }; }
pub inline fn mulVecAByVal( v : VecA, c : f32 ) VecA { return VecA{ .x = v.x * c, .y = v.y * c, .z = v.z + 0.0 }; }
pub        fn divVecAByVal( v : VecA, c : f32 ) ?VecA
{
  if( c == 0.0 )
  {
    @compileLog( "Warning: Division by zero in divVecAByVal()" );
    return null;
  }
  return VecA{ .x = v.x / c, .y = v.y / c, .z = v.z };
}

// Normalizes a vector back to a unit vector ( length of 1 ), returns null if the vector is zero'd
pub inline fn normVecAUnit( v : VecA ) ?VecA { return normVecALen( v, 1.0 ); }

// Normalizes a vector to a new length, returns null if the vector is zero'd
pub fn normVecALen( v : VecA, newLen : f32 ) ?VecA
{
  const oldLen = @sqrt(( v.x * v.x ) + ( v.y * v.y ) + ( 0.0 * 0.0 ));
  if( oldLen  == 0.0 )
  {
    @compileLog( "Warning: Normalizing a zero vector in normVecA()" );
    def.qlog( .ERROR, 0, @src(), "Normalizing a zero vector in normVecA()" );
    return null;
  }

  const factor = newLen / oldLen;
  const r = def.wrap( v.z, 0, def.TAU );
  return VecA{ .x = v.x * factor, .y = v.y * factor, .z = r };
}

// =============================== VECTOR MATH ================================

pub inline fn addVecA( a : VecA, b : VecA ) VecA { return VecA{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z }; }
pub inline fn subVecA( a : VecA, b : VecA ) VecA { return VecA{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z }; }
pub inline fn mulVecA( a : VecA, b : VecA ) VecA { return VecA{ .x = a.x * b.x, .y = a.y * b.y, .z = a.z * b.z }; }
pub        fn divVecA( a : VecA, b : VecA ) ?VecA
{
  if( b.x == 0.0 or b.y == 0.0 or b.z == 0.0 )
  {
    @compileLog( "Warning: Division by zero in divVecA()" );
    def.qlog( .ERROR, 0, @src(), "Division by zero in divVecA()" );
    return null;
  }
  return VecA{ .x = a.x / b.x, .y = a.y / b.y, .z = a.z / b.z };
}


// ================================ DISTANCE MATH ================================
// NOTE : These functions are used to calculate UNSIGNED linear distances between vectors

// Returns the Euclidian ( Chebyshev ) distance between two vectors
pub inline fn getVecADist( p1 : VecA, p2 : VecA ) f32 { return @sqrt( getVecASqrDist( p1, p2 ) ); }

// Returns the Cartesian ( Taxicab / Manhattan ) distance between two vectors
pub inline fn getVecACartDist( p1 : VecA, p2 : VecA ) f32 { return @abs( p2.x - p1.x ) + @abs( p2.y - p1.y ); }

// Returns the square of the distance between two vectors ( helps to avoid unnecessary sqrt() calls )
pub inline fn getVecASqrDist(  p1 : VecA, p2 : VecA ) f32
{
  const dist = def.Vec2{ .x = p2.x - p1.x, .y = p2.y - p1.y };
  return( dist.x * dist.x ) + ( dist.y * dist.y );
}

// Returns the linear distance between two vectors along a given axis
pub inline fn getVecADistX( p1 : VecA, p2 : VecA ) f32 { return @abs( p2.x - p1.x ); }
pub inline fn getVecADistY( p1 : VecA, p2 : VecA ) f32 { return @abs( p2.y - p1.y ); }
pub inline fn getVecADistR( p1 : VecA, p2 : VecA ) f32 { return @abs( p2.z - p1.z ); }


// ================================ ANGULAR MATH ================================
// NOTE : all returned angles are unsigned, in the range [ 0, 360 ] for degrees and [ 0, 2*PI ] for radians

pub inline fn rotVecADeg( a : VecA, angleDeg : f32 ) VecA { return rotVecARad( a, DtR( angleDeg )); }
pub        fn rotVecARad( a : VecA, angleRad : f32 ) VecA
{
  if( angleRad == 0.0 ){ return a; }

  const cosAngle = @cos( angleRad );
  const sinAngle = @sin( angleRad );

  return VecA
  {
    .x = ( a.x * cosAngle ) - ( a.y * sinAngle ),
    .y = ( a.x * sinAngle ) + ( a.y * cosAngle ),
    .z = a.z + angleRad, // simply rotate the R angle by the given angle
  };
}

pub inline fn vecAToDeg( v : VecA ) f32 { return RtD( vecAAngularDistRad( v )); }
pub        fn vecAToRad( v : VecA ) f32
{
  if( v.x == 0.0 and v.y == 0.0 )
  {
    @compileLog( "Warning: Getting angle of a zero vector in getVecAAngle()" );
    def.qlog( .ERROR, 0, @src(), "Getting angle of a zero vector in getVecAAngle()" );
    return 0.0;
  }
  return atan2( v.y, v.x );
}

// Returns the unsinged angular distance between two vectors sharing the same origin
pub inline  fn vecAAngularDistDeg( p1 : VecA, p2 : VecA, origin : ?VecA, ) f32 { return RtD( vecAAngularDistRad( p1, p2, origin )); }
pub         fn vecAAngularDistRad( p1 : VecA, p2 : VecA, origin : ?VecA, ) f32
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

pub inline fn degToVecA( angleDeg : f32 ) VecA { return radToVecA( DtR( angleDeg )); }
pub inline fn radToVecA( angleRad : f32 ) VecA { return VecA{ .x = @cos( angleRad ), .y = @sin( angleRad ), .z = angleRad }; }

pub inline fn degToVecAScaled( angleDeg : f32, scale : VecA ) VecA { return radToVecAScaled( scale, DtR( angleDeg )); }
pub inline fn radToVecAScaled( angleRad : f32, scale : VecA ) VecA
{
  // NOTE : The Z ( R ) value is set to the angle, meaning it is always pointing outwards from the origin
  return Vec2{ .x = @cos( angleRad ) * scale.x, .y = @sin( angleRad ) * scale.y, .z = angleRad };
}
