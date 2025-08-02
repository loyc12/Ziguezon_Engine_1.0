const std = @import( "std" );
const def = @import( "defs" );

pub const Vec2  = def.ray.Vector2;
pub const Vec3  = def.ray.Vector3;
pub const atan2 = def.atan2;
pub const DtR   = def.DtR;
pub const RtD   = def.RtD;

pub fn newVec3( x : f32, y : f32, z : f32 ) Vec3 { return Vec3{ .x = x, .y = y, .z = z }; }

// ================================ SCALAR MATH ================================

pub fn addValToVec3( v : Vec3, c : f32 ) Vec3 { return Vec3{ .x = v.x + c, .y = v.y + c, .z = v.z + c }; }
pub fn subValToVec3( v : Vec3, c : f32 ) Vec3 { return Vec3{ .x = v.x - c, .y = v.y - c, .z = v.z - c }; }
pub fn mulVec3ByVal( v : Vec3, c : f32 ) Vec3 { return Vec3{ .x = v.x * c, .y = v.y * c, .z = v.z * c }; }
pub fn divVec3ByVal( v : Vec3, c : f32 ) ?Vec3
{
  if( c == 0.0 )
  {
    @compileLog( "Warning: Division by zero in divVec3ByVal()" );
    return null;
  }
  return Vec3{ .x = v.x / c, .y = v.y / c, .z = v.z / c };
}

// Normalizes a vector back to a unit vector ( length of 1 ), returns null if the vector is zero'd
pub fn normVec3Unit( v : Vec3 ) ?Vec3 { return normVec3Len( v, 1.0 ); }

// Normalizes a vector to a new length, returns null if the vector is zero'd
pub fn normVec3Len( v : Vec3, newLen : f32 ) ?Vec3
{
  const oldLen = @sqrt(( v.x * v.x ) + ( v.y * v.y ) + ( v.z * v.z ));
  if( oldLen  == 0.0 )
  {
    @compileLog( "Warning: Normalizing a zero vector in normVec3()" );
    def.qlog( .ERROR, 0, @src(), "Normalizing a zero vector in normVec3()" );
    return null;
  }

  const factor = newLen / oldLen;
  if( factor == 1.0 ){ return v; }

  return Vec3{ .x = v.x * factor, .y = v.y * factor, .z = v.z * factor };
}

// =============================== VECTOR MATH ================================

pub fn addVec3( a : Vec3, b : Vec3 ) Vec3 { return Vec3{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z }; }
pub fn subVec3( a : Vec3, b : Vec3 ) Vec3 { return Vec3{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z }; }
pub fn mulVec3( a : Vec3, b : Vec3 ) Vec3 { return Vec3{ .x = a.x * b.x, .y = a.y * b.y, .z = a.z * b.z }; }
pub fn divVec3( a : Vec3, b : Vec3 ) ?Vec3
{
  if( b.x == 0.0 or b.y == 0.0 or b.z == 0.0 )
  {
    @compileLog( "Warning: Division by zero in divVec3()" );
    def.qlog( .ERROR, 0, @src(), "Division by zero in divVec3()" );
    return null;
  }
  return Vec3{ .x = a.x / b.x, .y = a.y / b.y, .z = a.z / b.z };
}


// ================================ DISTANCE MATH ================================
// NOTE : These functions are used to calculate UNSIGNED linear distances between vectors

// Returns the Euclidian ( Chebyshev ) distance between two vectors
pub fn getDist( p1 : Vec3, p2 : Vec3 ) f32 { return @sqrt( getSqrDist( p1, p2 ) ); }

// Returns the Cartesian ( Taxicab / Manhattan ) distance between two vectors
pub fn getCartDist( p1 : Vec3, p2 : Vec3 ) f32 { return @abs( p2.x - p1.x ) + @abs( p2.y - p1.y ) + @abs( p2.z - p1.z ); }

// Returns the square of the distance between two vectors ( helps to avoid unnecessary sqrt() calls )
pub fn getSqrDist(  p1 : Vec3, p2 : Vec3 ) f32
{
  const dist = def.Vec3{ .x = p2.x - p1.x, .y = p2.y - p1.y, .z = p2.z - p1.z, };
  return ( dist.x * dist.x ) + ( dist.y * dist.y ) + ( dist.z * dist.z );
}

// Returns the distance between two vectors in a given axis
pub fn getDistX( p1 : Vec3, p2 : Vec3 ) f32 { return @abs( p2.x - p1.x ); }
pub fn getDistY( p1 : Vec3, p2 : Vec3 ) f32 { return @abs( p2.y - p1.y ); }
pub fn getDistZ( p1 : Vec3, p2 : Vec3 ) f32 { return @abs( p2.z - p1.z ); }

// Returns the distance between two vectors in a given plane
pub fn getDistXY( p1 : Vec3, p2 : Vec3 ) f32 { return @sqrt( getSqrDistXY( p1, p2 )); }
pub fn getDistXZ( p1 : Vec3, p2 : Vec3 ) f32 { return @sqrt( getSqrDistXZ( p1, p2 )); }
pub fn getDistYZ( p1 : Vec3, p2 : Vec3 ) f32 { return @sqrt( getSqrDistYZ( p1, p2 )); }

// Returns the square of the distance between two vectors in a given plane ( helps to avoid unnecessary sqrt() calls )
pub fn getSqrDistXY( p1 : Vec3, p2 : Vec3 ) f32
{
  const dist = Vec2{ .x = p2.x - p1.x, .y = p2.y - p1.y};
  return ( dist.x * dist.x ) + ( dist.y * dist.y );
}
pub fn getSqrDistXZ( p1 : Vec3, p2 : Vec3 ) f32
{
  const dist = Vec2{ .x = p2.x - p1.x, .y = p2.z - p1.z, };
  return ( dist.x * dist.x ) + ( dist.y * dist.y );
}
pub fn getSqrDistYZ( p1 : Vec3, p2 : Vec3 ) f32
{
  const dist = Vec2{ .x = p2.y - p1.y, .y = p2.z - p1.z, };
  return ( dist.x * dist.x ) + ( dist.y * dist.y );
}

// Return the cylindrical distance between two vectors in a given plane
pub fn getCylnDistXY( p1 : Vec3, p2 : Vec3 ) f32 { return @sqrt( getSqrDistXY( p1, p2 )) + @abs( p2.z - p1.z ); }
pub fn getCylnDistXZ( p1 : Vec3, p2 : Vec3 ) f32 { return @sqrt( getSqrDistXZ( p1, p2 )) + @abs( p2.y - p1.y ); }
pub fn getCylnDistYZ( p1 : Vec3, p2 : Vec3 ) f32 { return @sqrt( getSqrDistYZ( p1, p2 )) + @abs( p2.x - p1.x ); }

// ================================ ANGULAR MATH ================================
//// NOTE : all returned angles are unsigned, in the range [ 0, 360 ] for degrees and [ 0, 2*PI ] for radians
//
//pub fn rotVec3Deg( a : Vec3, angleDeg : f32 ) Vec3 { return rotVec3Rad( a, DtR( angleDeg )); }
//pub fn rotVec3Rad( a : Vec3, angleRad : f32 ) Vec3
//{
//  if( angleRad == 0.0 ){ return a; }
//
//  const cosAngle = @cos( angleRad );
//  const sinAngle = @sin( angleRad );
//
//  return Vec3
//  {
//    .x = ( a.x * cosAngle ) - ( a.y * sinAngle ),
//    .y = ( a.x * sinAngle ) + ( a.y * cosAngle ),
//  };
//}
//
//pub fn getVec3AngleDeg( v : Vec3 ) f32 { return RtD( getVec3AngleRad( v )); }
//pub fn getVec3AngleRad( v : Vec3 ) f32
//{
//  if( v.x == 0.0 and v.y == 0.0 )
//  {
//    @compileLog( "Warning: Getting angle of a zero vector in getVec3Angle()" );
//    def.qlog( .ERROR, 0, @src(), "Getting angle of a zero vector in getVec3Angle()" );
//    return 0.0;
//  }
//  return atan2( v.y, v.x );
//}
//
//pub fn getAngDistDeg( p1 : Vec3, p2 : Vec3, origin : ?Vec3, ) f32 { return RtD( getAngDistRad( p1, p2, origin )); }
//pub fn getAngDistRad( p1 : Vec3, p2 : Vec3, origin : ?Vec3, ) f32
//{
//  if( origin )| p0 |
//  {
//    const a1 = atan2( p1.y - p0.y, p1.x - p0.x );
//    const a2 = atan2( p2.y - p0.y, p2.x - p0.x );
//    return @abs( a1 - a2 );
//  }
//  else { return @abs( atan2( p1.y, p1.x ) - atan2( p2.y, p2.x )); }
//}