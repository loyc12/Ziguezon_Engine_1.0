const std = @import( "std" );
const def = @import( "defs" );

pub const vec2  = def.ray.Vector2;
pub const atan2 = std.math.atan2;
pub const DtR   = std.math.degreesToRadians;
pub const RtD   = std.math.radiansToDegrees;

// ================================ SCALAR MATH ================================

pub fn addValToVec2( v : vec2, c : f32 ) vec2 { return vec2{ .x = v.x + c, .y = v.y + c }; }
pub fn subValToVec2( v : vec2, c : f32 ) vec2 { return vec2{ .x = v.x - c, .y = v.y - c }; }
pub fn mulVec2ByVal( v : vec2, c : f32 ) vec2 { return vec2{ .x = v.x * c, .y = v.y * c }; }
pub fn divVec2ByVal( v : vec2, c : f32 ) ?vec2
{
  if( c == 0.0 )
  {
    @compileLog( "Warning: Division by zero in divVec2ByVal()" );
    return null;
  }
  return vec2{ .x = v.x / c, .y = v.y / c };
}

// Normalizes a vector back to a unit vector ( length of 1 ), returns null if the vector is zero'd
pub fn normVec2Unit( v : vec2 ) ?vec2 { return normVec2Len( v, 1.0 ); }

// Normalizes a vector to a new length, returns null if the vector is zero'd
pub fn normVec2Len( v : vec2, newLen : f32 ) ?vec2
{
  const oldLen = @sqrt(( v.x * v.x ) + ( v.y * v.y ));
  if( oldLen  == 0.0 )
  {
    @compileLog( "Warning: Normalizing a zero vector in normVec2()" );
    def.qlog( .ERROR, 0, @src(), "Normalizing a zero vector in normVec2()" );
    return null;
  }

  const factor = newLen / oldLen;
  if( factor == 1.0 ){ return v; }

  return vec2{ .x = v.x * factor, .y = v.y * factor };
}

// =============================== VECTOR MATH ================================

pub fn addVec2( a : vec2, b : vec2 ) vec2 { return vec2{ .x = a.x + b.x, .y = a.y + b.y }; }
pub fn subVec2( a : vec2, b : vec2 ) vec2 { return vec2{ .x = a.x - b.x, .y = a.y - b.y }; }
pub fn mulVec2( a : vec2, b : vec2 ) vec2 { return vec2{ .x = a.x * b.x, .y = a.y * b.y }; }
pub fn divVec2( a : vec2, b : vec2 ) ?vec2
{
  if( b.x == 0.0 or b.y == 0.0 )
  {
    @compileLog( "Warning: Division by zero in divVec2()" );
    def.qlog( .ERROR, 0, @src(), "Division by zero in divVec2()" );
    return null;
  }
  return vec2{ .x = a.x / b.x, .y = a.y / b.y };
}

// ================================ ANGULAR MATH ================================

pub fn rotVec2Deg( a : vec2, angleDeg : f32 ) vec2 { return rotVec2Rad( a, DtR( angleDeg )); }
pub fn rotVec2Rad( a : vec2, angleRad : f32 ) vec2
{
  if( angleRad == 0.0 ){ return a; }

  const cosAngle = @cos( angleRad );
  const sinAngle = @sin( angleRad );

  return vec2
  {
    .x = ( a.x * cosAngle ) - ( a.y * sinAngle ),
    .y = ( a.x * sinAngle ) + ( a.y * cosAngle ),
  };
}

pub fn getVec2AngleDeg( v : vec2 ) f32 { return RtD( getVec2AngleRad( v )); }
pub fn getVec2AngleRad( v : vec2 ) f32
{
  if( v.x == 0.0 and v.y == 0.0 )
  {
    @compileLog( "Warning: Getting angle of a zero vector in getVec2Angle()" );
    def.qlog( .ERROR, 0, @src(), "Getting angle of a zero vector in getVec2Angle()" );
    return 0.0;
  }
  return atan2( v.y, v.x );
}

pub fn getAngleDeg( orig : vec2, dest : vec2 ) f32 { return RtD( getAngleRad( orig, dest ) ); }
pub fn getAngleRad( orig : vec2, dest : vec2 ) f32
{
  const dx = dest.x - orig.x;
  const dy = dest.y - orig.y;

  if( dx == 0.0 and dy == 0.0 )
  {
    @compileLog( "Warning: Getting angle between two identical vectors in getAngleBetweenVec2Rad()" );
    def.qlog( .ERROR, 0, @src(), "Getting angle between two identical vectors in getAngleBetweenVec2Rad()" );
    return 0.0;
  }

  return atan2( dy, dx );
}

// Returns the UNSIGNED angle in radian between two vectors, from the origin, in the range [ 0, 360 ]
pub fn getAngDistDeg( p1 : vec2, p2 : vec2, origin : ?vec2, ) f32 { return RtD( getAngDistRad( p1, p2, origin )); }

// Returns the UNSIGNED angle in radian between two vectors, from the origin, in the range [ 0, 2*PI ]
pub fn getAngDistRad( p1 : vec2, p2 : vec2, origin : ?vec2, ) f32
{
  if( origin )| p0 |
  {
    const a1 = atan2( p1.y - p0.y, p1.x - p0.x );
    const a2 = atan2( p2.y - p0.y, p2.x - p0.x );
    return @abs( a1 - a2 );
  }
  else { return @abs( atan2( p1.y, p1.x ) - atan2( p2.y, p2.x )); }
}

// ================================ DISTANCE MATH ================================
// NOTE : These functions are used to calculate UNSIGNED linear distances between vectors

pub fn getDistX( p1 : vec2, p2 : vec2 ) f32 { return @abs( p2.x - p1.x ); }
pub fn getDistY( p1 : vec2, p2 : vec2 ) f32 { return @abs( p2.y - p1.y ); }

// Returns the Cartesian ( Taxicab / Manhattan ) distance between two vectors
pub fn getCartDist( p1 : vec2, p2 : vec2 ) f32 { return @abs( p2.x - p1.x ) + @abs( p2.y - p1.y ); }

// Returns the Euclidian ( Chebyshev ) distance between two vectors
pub fn getDistance( p1 : vec2, p2 : vec2 ) f32 { return @sqrt( getSqrDist( p1, p2 ) ); }

// Returns the square of the distance between two vectors ( helps to avoid unnecessary sqrt() calls )
pub fn getSqrDist(  p1 : vec2, p2 : vec2 ) f32
{
  const dist = def.vec2{ .x = p2.x - p1.x, .y = p2.y - p1.y, };
  return ( dist.x * dist.x ) + ( dist.y * dist.y );
}

// ================================ VECTOR(S) GENERATORS ================================
// These functions are used to create scaled unit vectors from angles

pub fn getScaledVec2FromDeg( scale : vec2, angleDeg : f32 ) vec2 { return getScaledVec2FromRad( scale, DtR( angleDeg )); }
pub fn getScaledVec2FromRad( scale : vec2, angleRad : f32 ) vec2 { return vec2{ .x = @cos( angleRad ) * scale.x, .y = @sin( angleRad ) * scale.y }; }

// Returns an allocated arrayList of vec2 points representing the vertexs of a regular polygon with the given scale and side count.
// NOTE : Do not forget to dealloc the returned array !
pub fn getScaledPolyVerts( scale : vec2, sideCount : u32 ) ?[]vec2
{
  if( sideCount < 3 )
  {
    def.log( .ERROR, 0, @src(), "getScaledPolyVerts() requires at least 3 sides, got {d}", .{ sideCount } );
    return null;
  }
  var points = std.ArrayList( vec2 ).init( def.alloc );

  for( 0..sideCount )| i |
  {
    const angle = @as( f32, @floatFromInt( i )) * ( std.math.tau / @as( f32, @floatFromInt( sideCount ))); // 2*PI / sides
    points.append( vec2{ .x = @cos( angle ) * scale.x, .y = @sin( angle ) * scale.y }) catch | err |
    {
      def.log( .ERROR, 0, @src(), "Failed to append polygon vertex {d} : {}", .{ i, err } );
    };
  }
  if( points.items.len < sideCount )
  {
    def.log( .ERROR, 0, @src(), "Failed to generate polygon vertexs, got only {d} out of {d}", .{ points.items.len, sideCount } );
    def.alloc.free( points.items );
    return null;
  }
  return points.items;
}