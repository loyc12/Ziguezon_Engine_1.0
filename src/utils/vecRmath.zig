const std = @import( "std" );
const def = @import( "defs" );

pub const Vec2  = def.ray.Vector2;
pub const VecR  = def.ray.Vector3;
pub const atan2 = def.atan2;
pub const DtR   = def.DtR;
pub const RtD   = def.RtD;

// NOTE : In this vector format, z represent the rotation angle R in radians, while x and y are the coordinates.

pub inline fn newVecR( x : f32, y : f32, r : ?f32 ) VecR
{
  if( r )| angle | { return VecR{ .x = x, .y = y, .z = angle }; }
  else             { return VecR{ .x = x, .y = y, .z = 0.0   }; }
}
pub inline fn zeroVecR() VecR { return VecR{ .x = 0.0, .y = 0.0, .z = 0.0 }; } // Returns a zero'd vector

// ================================ SCALAR MATH ================================

pub inline fn addValToVecR( v : VecR, c : f32 ) VecR { return VecR{ .x = v.x + c, .y = v.y + c, .z = v.z + 0.0 }; }
pub inline fn subValToVecR( v : VecR, c : f32 ) VecR { return VecR{ .x = v.x - c, .y = v.y - c, .z = v.z + 0.0 }; }
pub inline fn mulVecRByVal( v : VecR, c : f32 ) VecR { return VecR{ .x = v.x * c, .y = v.y * c, .z = v.z + 0.0 }; }
pub        fn divVecRByVal( v : VecR, c : f32 ) ?VecR
{
  if( c == 0.0 )
  {
    @compileLog( "Warning: Division by zero in divVecRByVal()" );
    return null;
  }
  return VecR{ .x = v.x / c, .y = v.y / c, .z = v.z };
}

// Normalizes a vector back to a unit vector ( length of 1 ), returns null if the vector is zero'd
pub inline fn normVecRUnit( v : VecR ) ?VecR { return normVecRLen( v, 1.0 ); }

// Normalizes a vector to a new length, returns null if the vector is zero'd
pub fn normVecRLen( v : VecR, newLen : f32 ) ?VecR
{
  const oldLen = @sqrt(( v.x * v.x ) + ( v.y * v.y ) + ( 0.0 * 0.0 ));
  if( oldLen  == 0.0 )
  {
    @compileLog( "Warning: Normalizing a zero vector in normVecR()" );
    def.qlog( .ERROR, 0, @src(), "Normalizing a zero vector in normVecR()" );
    return null;
  }

  const factor = newLen / oldLen;
  const r = def.wrap( v.z, 0, std.math.tau );
  return VecR{ .x = v.x * factor, .y = v.y * factor, .z = r };
}

// =============================== VECTOR MATH ================================

pub inline fn addVecR( a : VecR, b : VecR ) VecR { return VecR{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z }; }
pub inline fn subVecR( a : VecR, b : VecR ) VecR { return VecR{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z }; }
pub inline fn mulVecR( a : VecR, b : VecR ) VecR { return VecR{ .x = a.x * b.x, .y = a.y * b.y, .z = a.z * b.z }; }
pub        fn divVecR( a : VecR, b : VecR ) ?VecR
{
  if( b.x == 0.0 or b.y == 0.0 or b.z == 0.0 )
  {
    @compileLog( "Warning: Division by zero in divVecR()" );
    def.qlog( .ERROR, 0, @src(), "Division by zero in divVecR()" );
    return null;
  }
  return VecR{ .x = a.x / b.x, .y = a.y / b.y, .z = a.z / b.z };
}


// ================================ DISTANCE MATH ================================
// NOTE : These functions are used to calculate UNSIGNED linear distances between vectors

// Returns the Euclidian ( Chebyshev ) distance between two vectors
pub inline fn getVecRDist( p1 : VecR, p2 : VecR ) f32 { return @sqrt( getVecRSqrDist( p1, p2 ) ); }

// Returns the Cartesian ( Taxicab / Manhattan ) distance between two vectors
pub inline fn getVecRCartDist( p1 : VecR, p2 : VecR ) f32 { return @abs( p2.x - p1.x ) + @abs( p2.y - p1.y ); }

// Returns the square of the distance between two vectors ( helps to avoid unnecessary sqrt() calls )
pub inline fn getVecRSqrDist(  p1 : VecR, p2 : VecR ) f32
{
  const dist = def.Vec2{ .x = p2.x - p1.x, .y = p2.y - p1.y };
  return( dist.x * dist.x ) + ( dist.y * dist.y );
}

// Returns the linear distance between two vectors along a given axis
pub inline fn getVecRDistX( p1 : VecR, p2 : VecR ) f32 { return @abs( p2.x - p1.x ); }
pub inline fn getVecRDistY( p1 : VecR, p2 : VecR ) f32 { return @abs( p2.y - p1.y ); }
pub inline fn getVecRDistR( p1 : VecR, p2 : VecR ) f32 { return @abs( p2.z - p1.z ); }


// ================================ ANGULAR MATH ================================
// NOTE : all returned angles are unsigned, in the range [ 0, 360 ] for degrees and [ 0, 2*PI ] for radians

pub inline fn rotVecRDeg( a : VecR, angleDeg : f32 ) VecR { return rotVecRRad( a, DtR( angleDeg )); }
pub        fn rotVecRRad( a : VecR, angleRad : f32 ) VecR
{
  if( angleRad == 0.0 ){ return a; }

  const cosAngle = @cos( angleRad );
  const sinAngle = @sin( angleRad );

  return VecR
  {
    .x = ( a.x * cosAngle ) - ( a.y * sinAngle ),
    .y = ( a.x * sinAngle ) + ( a.y * cosAngle ),
    .z = a.z + angleRad, // simply rotate the R angle by the given angle
  };
}

pub inline fn vecRToDeg( v : VecR ) f32 { return RtD( vecRAngularDistRad( v )); }
pub        fn vecRToRad( v : VecR ) f32
{
  if( v.x == 0.0 and v.y == 0.0 )
  {
    @compileLog( "Warning: Getting angle of a zero vector in getVecRAngle()" );
    def.qlog( .ERROR, 0, @src(), "Getting angle of a zero vector in getVecRAngle()" );
    return 0.0;
  }
  return atan2( v.y, v.x );
}

// Returns the unsinged angular distance between two vectors sharing the same origin
pub inline  fn vecRAngularDistDeg( p1 : VecR, p2 : VecR, origin : ?VecR, ) f32 { return RtD( vecRAngularDistRad( p1, p2, origin )); }
pub         fn vecRAngularDistRad( p1 : VecR, p2 : VecR, origin : ?VecR, ) f32
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

pub inline fn degToVecR( angleDeg : f32 ) VecR { return radToVecR( DtR( angleDeg )); }
pub inline fn radToVecR( angleRad : f32 ) VecR { return VecR{ .x = @cos( angleRad ), .y = @sin( angleRad ), .z = angleRad }; }

pub inline fn degToVecRScaled( angleDeg : f32, scale : VecR ) VecR { return radToVecRScaled( scale, DtR( angleDeg )); }
pub inline fn radToVecRScaled( angleRad : f32, scale : VecR ) VecR
{
  // NOTE : The Z ( R ) value is set to the angle, meaning it is always pointing outwards from the origin
  return Vec2{ .x = @cos( angleRad ) * scale.x, .y = @sin( angleRad ) * scale.y, .z = angleRad };
}
