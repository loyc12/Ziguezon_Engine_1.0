const std  = @import( "std" );
const utl = @import( "utils" );

const Vec2 = utl.Vec2;
const VecA = utl.VecA;

const RayVec2 = utl.RayVec2;
const RayVec3 = utl.RayVec3;
//const RayVec4 = utl.RayVec4;

const Coords2 = utl.Coords2;
const Coords3 = utl.Coords3;


// ================================ VEC3 STRUCT ================================

pub const Vec3 = struct
{
  x : f64 = 0,
  y : f64 = 0,
  z : f64 = 0,


  // ================ GENERATION ================

  pub inline fn new( x : f64, y : f64, z : f64 ) Vec3 { return Vec3{ .x = x, .y = y, .z = z }; }

  //pub inline fn fromAngleDeg( a : Angle, b : f64 ) Vec3 { return fromAngle( utl.DtR( a )); }
  //pub inline fn fromAngle(    a : Angle, b : f64 ) Vec3
  //{
  //  return Vec3{
  //    .x = @cos( a ),
  //    .y = @sin( a ),
  //  };
  //}

  //pub inline fn fromAngleDegScaled( a : Angle, b : f64, scale : Vec3 ) Vec3 { return fromAngleScaled( utl.DtR( a ), scale ); }
  //pub inline fn fromAngleScaled(    a : Angle, b : f64, scale : Vec3 ) Vec3
  //{
  //  return Vec3{
  //    .x = @cos( a ) * scale.x,
  //    .y = @sin( a ) * scale.y,
  //  };
  //}

  // ================ CONVERSIONS ================

  pub inline fn toRayVec3( self : Vec3 ) RayVec3 { return RayVec3{ .x = @floatCast( self.x ), .y = @floatCast( self.y ), .z = @floatCast( self.z )}; }
  pub inline fn toCoords3( self : Vec3 ) Coords3
  {
    return Coords3{
      .x = @intFromFloat( @trunc( self.x )),
      .y = @intFromFloat( @trunc( self.y )),
      .z = @intFromFloat( @trunc( self.z )),
    };
  }

  // ================ COMPARISONS ================

  pub inline fn isPosi( self : Vec3 ) bool { return self.x >= 0 and self.y >= 0 and self.z >= 0; }
  pub inline fn isZero( self : Vec3 ) bool { return utl.isFltZr( self.x ) and utl.isFltZr( self.y ) and utl.isFltZr( self.z ); }
  pub inline fn isIso(  self : Vec3 ) bool { return utl.isFltEq( self.x, self.y ) and utl.isFltEq( self.x, self.z ); }

  pub inline fn isEq(   self : Vec3, other : Vec3 ) bool { return utl.isFltEq( self.x, other.x ) and utl.isFltEq( self.y, other.y ) and utl.isFltEq( self.z, other.z ); }
  pub inline fn isDiff( self : Vec3, other : Vec3 ) bool { return !self.isEq( other ); }


  // ================ BACIS MATHS ================

  pub inline fn abs( self : Vec3 ) Vec3 { return Vec3{ .x =  @abs( self.x ), .y =  @abs( self.y ), .z =  @abs( self.z ) }; }
  pub inline fn neg( self : Vec3 ) Vec3 { return Vec3{ .x = -@abs( self.x ), .y = -@abs( self.y ), .z = -@abs( self.z ) }; }

  pub inline fn add( self : Vec3, other : Vec3 ) Vec3 { return Vec3{ .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z }; }
  pub inline fn sub( self : Vec3, other : Vec3 ) Vec3 { return Vec3{ .x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z }; }
  pub inline fn mul( self : Vec3, other : Vec3 ) Vec3 { return Vec3{ .x = self.x * other.x, .y = self.y * other.y, .z = self.z * other.z }; }
  pub inline fn div( self : Vec3, other : Vec3 ) ?Vec3
  {
    if( utl.isFltZr( other.x ) or utl.isFltZr( other.y ) or utl.isFltZr( other.z ) )
    {
      utl.qlog( .ERROR, 0, @src(), "Division by zero in Vec3.div()" );
      return null;
    }
    return Vec3{ .x = self.x / other.x, .y = self.y / other.y, .z = self.z / other.z };
  }

  pub inline fn addVal( self : Vec3, val : f64 ) Vec3 { return Vec3{ .x = self.x + val, .y = self.y + val, .z = self.z + val }; }
  pub inline fn subVal( self : Vec3, val : f64 ) Vec3 { return Vec3{ .x = self.x - val, .y = self.y - val, .z = self.z - val }; }
  pub inline fn mulVal( self : Vec3, val : f64 ) Vec3 { return Vec3{ .x = self.x * val, .y = self.y * val, .z = self.z * val }; }
  pub inline fn divVal( self : Vec3, val : f64 ) ?Vec3
  {
    if( utl.isFltZr( val ))
    {
      utl.qlog( .ERROR, 0, @src(), "Division by zero in Vec3.divVal()" );
      return null;
    }
    return Vec3{ .x = self.x / val, .y = self.y / val, .z = self.z / val };
  }

  pub inline fn getDist(    self : Vec3, other : Vec3 ) f64 { return @sqrt( self.getDistSqr( other )); }
  pub inline fn getDistSqr( self : Vec3, other : Vec3 ) f64
  {
    const dx = self.x - other.x;
    const dy = self.y - other.y;
    const dz = self.z - other.z;
    return ( dx * dx ) + ( dy * dy ) + ( dz * dz );
  }

  pub inline fn getDistM( self : Vec3, other : Vec3 ) f64 { return self.getDistX( other ) + self.getDistY( other ) + self.getDistZ( other ); }
  pub inline fn getDistX( self : Vec3, other : Vec3 ) f64 { return @abs( self.x - other.x ); }
  pub inline fn getDistY( self : Vec3, other : Vec3 ) f64 { return @abs( self.y - other.y ); }
  pub inline fn getDistZ( self : Vec3, other : Vec3 ) f64 { return @abs( self.z - other.z ); }

  pub inline fn getMaxLinDist( self : Vec3, other : Vec3 ) f64 { return @max(     self.getDistX( other ), self.getDistY( other ), self.getDistZ( other )); }
  pub inline fn getMedLinDist( self : Vec3, other : Vec3 ) f64 { return utl.med3( self.getDistX( other ), self.getDistY( other ), self.getDistZ( other )); }
  pub inline fn getMinLinDist( self : Vec3, other : Vec3 ) f64 { return @min(     self.getDistX( other ), self.getDistY( other ), self.getDistZ( other )); }
  pub inline fn getAvgLinDist( self : Vec3, other : Vec3 ) f64 { return ( self.getDistX( other ) + self.getDistY( other ) + self.getDistZ( other )) / 3.0; }


  // ================ VECTOR MATHS ================

  pub inline fn lerp(  self : Vec2, other : Vec2, t : f64 ) Vec2
  {
    const x : f64 = utl.lerp( self.x, other.x, t );
    const y : f64 = utl.lerp( self.y, other.y, t );
    const z : f64 = utl.lerp( self.z, other.z, t );

    return .new( x, y, z );
  }
  pub inline fn norm(  self : Vec3               ) Vec3 { return self.normToLen( 1.0 ); }
  pub inline fn dot(   self : Vec3, other : Vec3 ) f64  { return ( self.x * other.x ) + ( self.y * other.y ) + ( self.z * other.z ); }
  pub inline fn cross( self : Vec3, other : Vec3 ) Vec3
  {
    return Vec3{
      .x = ( self.y * other.z ) - ( self.z * other.y ),
      .y = ( self.z * other.x ) - ( self.x * other.z ),
      .z = ( self.x * other.y ) - ( self.y * other.x ),
    };
  }
  // Normalizes a vector to a new length, returns null if the vector is zero'd
  pub fn normToLen( self : Vec3, newLen : f64 ) Vec3
  {
    if( utl.isFltZr( newLen ))
    {
      utl.qlog( .WARN, 0, @src(), "Normalizing a Vec3 to 0" );
      return .{};
    }

    const oldLenSqr = self.lenSqr();
    if( utl.isFltZr( oldLenSqr ))
    {
      utl.qlog( .WARN, 0, @src(), "Normalizing a 0:0 Vec3" );
      return .{};
    }

    if( utl.isFltEq( oldLenSqr, newLen * newLen )){ return self; }
    const factor = newLen / @sqrt( oldLenSqr );

    return self.mulVal( factor );
  }

  pub inline fn len(    self : Vec3 ) f64 { return @sqrt( self.lenSqr() ); }
  pub inline fn lenSqr( self : Vec3 ) f64 { return ( self.x * self.x ) + ( self.y * self.y ) + ( self.z * self.z ); }

  //pub inline fn rotDeg( self : Vec3, a : Angle ) Vec3 { return self.rot( utl.DtR( a )); }
  //pub inline fn rot(    self : Vec3, a : Angle ) Vec3
  //{
  //  if( a.isZero() ){ return *self; } // No rotation needed
  //  const cosA = @cos( a );
  //  const sinA = @sin( a );

  //  return Vec3{
  //    .x = ( self.x * cosA ) - ( self.y * sinA ),
  //    .y = ( self.x * sinA ) + ( self.y * cosA ),
  //  };
  //}

  //pub inline fn angleDeg( self : Vec3 ) f64 { return utl.RtD( self.angle() ); }
  //pub inline fn angle(    self : Vec3 ) f64
  //{
  //  if( utl.isFltZr( self.x ) and utl.isFltZr( self.y ))
  //  {
  //    utl.qlog( .WARN, 0, @src(), "Angle of a zero vector in Vec3.angle()" );
  //    return 0.0;
  //  }
  //  return utl.atan2( self.y, self.x );
  //}


};