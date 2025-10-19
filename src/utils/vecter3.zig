const std  = @import( "std" );
const def  = @import( "defs" );

const Vec2 = def.Vec2;
const VecA = def.VecA;

const RayVec2 = def.RayVec2;
const RayVec3 = def.RayVec3;
//const RayVec4 = def.RayVec4;

const Coords2 = def.Coords2;
const Coords3 = def.Coords3;


// ================================ VEC3 STRUCT ================================

pub const Vec3 = struct
{
  x : f32 = 0,
  y : f32 = 0,
  z : f32 = 0,


  // ================ GENERATION ================

  pub inline fn new( x : f32, y : f32, z : f32 ) Vec3 { return Vec3{ .x = x, .y = y, .z = z }; }

  //pub inline fn fromAngleDeg( a : Angle, b : f32 ) Vec3 { return fromAngle( def.DtR( a )); }
  //pub inline fn fromAngle(    a : Angle, b : f32 ) Vec3
  //{
  //  return Vec3{
  //    .x = @cos( a ),
  //    .y = @sin( a ),
  //  };
  //}

  //pub inline fn fromAngleDegScaled( a : Angle, b : f32, scale : Vec3 ) Vec3 { return fromAngleScaled( def.DtR( a ), scale ); }
  //pub inline fn fromAngleScaled(    a : Angle, b : f32, scale : Vec3 ) Vec3
  //{
  //  return Vec3{
  //    .x = @cos( a ) * scale.x,
  //    .y = @sin( a ) * scale.y,
  //  };
  //}

  // ================ CONVERSIONS ================

  pub inline fn toRayVec3( self : *const Vec3 ) RayVec3 { return RayVec3{ .x = self.x, .y = self.y, .z = self.z }; }
  pub inline fn toCoords3( self : *const Vec3 ) Coords3
  {
    return Coords3{
      .x = @intFromFloat( @trunc( self.x )),
      .y = @intFromFloat( @trunc( self.y )),
      .z = @intFromFloat( @trunc( self.z )),
    };
  }

  // ================ COMPARISONS ================

  pub inline fn isPosi( self : *const Vec3 ) bool { return self.x >= 0 and self.y >= 0 and self.z >= 0; }
  pub inline fn isZero( self : *const Vec3 ) bool { return self.x == 0 and self.y == 0 and self.z == 0; }
  pub inline fn isIso(  self : *const Vec3 ) bool { return self.x == self.y and self.y == self.z; }

  pub inline fn isEq(     self : *const Vec3, other : Vec3 ) bool { return self.x == other.x and self.y == other.y and self.z == other.z; }
  pub inline fn isDiff(   self : *const Vec3, other : Vec3 ) bool { return self.x != other.x or  self.y != other.y or  self.z != other.z; }
  pub inline fn isInfXYZ( self : *const Vec3, other : Vec3 ) bool { return self.x <  other.x or  self.y <  other.y or  self.z <  other.z; }
  pub inline fn isSupXYZ( self : *const Vec3, other : Vec3 ) bool { return self.x >  other.x or  self.y >  other.y or  self.z >  other.z; }


  // ================ BACIS MATHS ================

  pub inline fn abs( self : *const Vec3 ) Vec3 { return Vec3{ .x =  @abs( self.x ), .y =  @abs( self.y ), .z =  @abs( self.z ) }; }
  pub inline fn neg( self : *const Vec3 ) Vec3 { return Vec3{ .x = -@abs( self.x ), .y = -@abs( self.y ), .z = -@abs( self.z ) }; }

  pub inline fn add( self : *const Vec3, other : Vec3 ) Vec3 { return Vec3{ .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z }; }
  pub inline fn sub( self : *const Vec3, other : Vec3 ) Vec3 { return Vec3{ .x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z }; }
  pub inline fn mul( self : *const Vec3, other : Vec3 ) Vec3 { return Vec3{ .x = self.x * other.x, .y = self.y * other.y, .z = self.z * other.z }; }
  pub inline fn div( self : *const Vec3, other : Vec3 ) ?Vec3
  {
    if( other.x == 0.0 or other.y == 0.0 or other.z == 0.0 )
    {
      def.qlog( .ERROR, 0, @src(), "Division by zero in Vec3.div()" );
      return null;
    }
    return Vec3{ .x = self.x / other.x, .y = self.y / other.y, .z = self.z / other.z };
  }

  pub inline fn addVal( self : *const Vec3, val : f32 ) Vec3 { return Vec3{ .x = self.x + val, .y = self.y + val, .z = self.z + val }; }
  pub inline fn subVal( self : *const Vec3, val : f32 ) Vec3 { return Vec3{ .x = self.x - val, .y = self.y - val, .z = self.z - val }; }
  pub inline fn mulVal( self : *const Vec3, val : f32 ) Vec3 { return Vec3{ .x = self.x * val, .y = self.y * val, .z = self.z * val }; }
  pub inline fn divVal( self : *const Vec3, val : f32 ) ?Vec3
  {
    if( val == 0.0 )
    {
      def.qlog( .ERROR, 0, @src(), "Division by zero in Vec3.divVal()" );
      return null;
    }
    return Vec3{ .x = self.x / val, .y = self.y / val, .z = self.z / val };
  }

  pub inline fn getDist(    self : *const Vec3, other : Vec3 ) f32 { return @sqrt( self.getDistSqr( other )); }
  pub inline fn getDistSqr( self : *const Vec3, other : Vec3 ) f32
  {
    const dx = self.x - other.x;
    const dy = self.y - other.y;
    const dz = self.z - other.z;
    return ( dx * dx ) + ( dy * dy ) + ( dz * dz );
  }

  pub inline fn getDistM( self : *const Vec3, other : Vec3 ) f32 { return self.getDistX( other ) + self.getDistY( other ) + self.getDistZ( other ); }
  pub inline fn getDistX( self : *const Vec3, other : Vec3 ) f32 { return @abs( self.x - other.x ); }
  pub inline fn getDistY( self : *const Vec3, other : Vec3 ) f32 { return @abs( self.y - other.y ); }
  pub inline fn getDistZ( self : *const Vec3, other : Vec3 ) f32 { return @abs( self.z - other.z ); }

  pub inline fn getMaxLinDist( self : *const Vec3, other : Vec3 ) f32 { return @max(     self.getDistX( other ), self.getDistY( other ), self.getDistZ( other )); }
  pub inline fn getMedLinDist( self : *const Vec3, other : Vec3 ) f32 { return def.med3( self.getDistX( other ), self.getDistY( other ), self.getDistZ( other )); }
  pub inline fn getMinLinDist( self : *const Vec3, other : Vec3 ) f32 { return @min(     self.getDistX( other ), self.getDistY( other ), self.getDistZ( other )); }
  pub inline fn getAvgLinDist( self : *const Vec3, other : Vec3 ) f32 { return ( self.getDistX( other ) + self.getDistY( other ) + self.getDistZ( other )) / 3.0; }


  // ================ VECTOR MATHS ================

  pub inline fn normToUnit( self : *const Vec3 ) ?Vec3 { return self. normToLen( 1.0 ); }

  // Normalizes a vector to a new length, returns null if the vector is zero'd
  pub fn normToLen( self : *const Vec3, newLen : f32 ) ?Vec3
  {
    if( newLen == 0.0 )
    {
      def.qlog( .WARN, 0, @src(), "Normalizing a Vec3 to 0" );
      return .{};
    }

    const oldLenSqr = self.lenSqr();
    if( oldLenSqr  == 0.0 )
    {
      def.qlog( .ERROR, 0, @src(), "Normalizing a 0:0 Vec3" );
      return null;
    }

    if( oldLenSqr == newLen * newLen ){ return self; }
    const factor = newLen / @sqrt( oldLenSqr );

    return self.mulVal( factor );
  }

  pub inline fn len(    self : *const Vec3 ) f32 { return @sqrt( self.lenSqr() ); }
  pub inline fn lenSqr( self : *const Vec3 ) f32 { return ( self.x * self.x ) + ( self.y * self.y ) + ( self.z * self.z ); }

  //pub inline fn rotDeg( self : *const Vec3, a : Angle ) Vec3 { return self.rot( def.DtR( a )); }
  //pub inline fn rot(    self : *const Vec3, a : Angle ) Vec3
  //{
  //  if( angle == 0.0 ){ return *self; } // No rotation needed
  //  const cosA = @cos( a );
  //  const sinA = @sin( a );

  //  return Vec3{
  //    .x = ( self.x * cosA ) - ( self.y * sinA ),
  //    .y = ( self.x * sinA ) + ( self.y * cosA ),
  //  };
  //}

  //pub inline fn angleDeg( self : *const Vec3 ) f32 { return def.RtD( self.angle() ); }
  //pub inline fn angle(    self : *const Vec3 ) f32
  //{
  //  if( self.x == 0.0 and self.y == 0.0 )
  //  {
  //    def.qlog( .WARN, 0, @src(), "Angle of a zero vector in Vec3.angle()" );
  //    return 0.0;
  //  }
  //  return def.atan2( self.y, self.x );
  //}


};