const std  = @import( "std" );
const def  = @import( "defs" );

const RayVec2 = def.ray.Vector2;
const RayVec3 = def.ray.Vector3;
const RayVec4 = def.ray.Vector4;

const Coords2 = def.Coords2;
const Coords3 = def.Coords3;


// ================================ VEC2 STRUCT ================================

pub const Vec2 = struct
{
  x : f32 = 0,
  y : f32 = 0,


  // ================ GENERATION ================

  pub inline fn fromVals( x : f32, y : f32 ) Vec2 { return Vec2{ .x = x, .y = y }; }

  pub inline fn fromAngleDeg( a : f32 ) Vec2 { return fromAngle( def.DtR( a )); }
  pub inline fn fromAngle(    a : f32 ) Vec2
  {
    return Vec2{
      .x = @cos( a ),
      .y = @sin( a ),
    };
  }

  pub inline fn fromAngleDegScaled( a : f32, scale : Vec2 ) Vec2 { return fromAngleScaled( def.DtR( a ), scale ); }
  pub inline fn fromAngleScaled(    a : f32, scale : Vec2 ) Vec2
  {
    return Vec2{
      .x = @cos( a ) * scale.x,
      .y = @sin( a ) * scale.y,
    };
  }

  // ================ CONVERSIONS ================

  pub inline fn toRayVec2( self : *const Vec2 ) RayVec2 { return RayVec2{ .x = self.x, .y = self.y }; }
  pub inline fn toVecR(    self : *const Vec2, r : ?f32 ) RayVec3
  {
    if( r == null ){ return RayVec3{ .x = self.x, .y = self.y, .z = self.angle() }; }
    else           { return RayVec3{ .x = self.x, .y = self.y, .z = r.? }; }
  }
  pub inline fn toCoords2( self : *const Vec2 ) Coords2
  {
    return Coords2{
      .x = @intFromFloat( @trunc( self.x )),
      .y = @intFromFloat( @trunc( self.y )),
    };
  }

  // ================ COMPARISONS ================

  pub inline fn isPos(  self : *const Vec2 ) bool { return self.x >= 0 and self.y >= 0; }
  pub inline fn isZero( self : *const Vec2 ) bool { return self.x == 0 and self.y == 0; }

  pub inline fn isEq(    self : *const Vec2, other : Vec2 ) bool { return self.x == other.x and self.y == other.y; }
  pub inline fn isDiff(  self : *const Vec2, other : Vec2 ) bool { return self.x != other.x or  self.y != other.y; }
  pub inline fn isInfXY( self : *const Vec2, other : Vec2 ) bool { return self.x <  other.x or  self.y <  other.y; }
  pub inline fn isSupXY( self : *const Vec2, other : Vec2 ) bool { return self.x >  other.x or  self.y >  other.y; }


  // ================ BACIS MATHS ================

  pub inline fn add( self : *const Vec2, other : Vec2 ) Vec2 { return Vec2{ .x = self.x + other.x, .y = self.y + other.y }; }
  pub inline fn sub( self : *const Vec2, other : Vec2 ) Vec2 { return Vec2{ .x = self.x - other.x, .y = self.y - other.y }; }
  pub inline fn mul( self : *const Vec2, other : Vec2 ) Vec2 { return Vec2{ .x = self.x * other.x, .y = self.y * other.y }; }
  pub inline fn div( self : *const Vec2, other : Vec2 ) ?Vec2
  {
    if( other.x == 0.0 or other.y == 0.0 )
    {
      def.qlog( .ERROR, 0, @src(), "Division by zero in Vec2.div()" );
      return null;
    }
    return Vec2{ .x = self.x / other.x, .y = self.y / other.y };
  }

  pub inline fn addVal( self : *const Vec2, val : f32 ) Vec2 { return Vec2{ .x = self.x + val, .y = self.y + val }; }
  pub inline fn subVal( self : *const Vec2, val : f32 ) Vec2 { return Vec2{ .x = self.x - val, .y = self.y - val }; }
  pub inline fn mulVal( self : *const Vec2, val : f32 ) Vec2 { return Vec2{ .x = self.x * val, .y = self.y * val }; }
  pub inline fn divVal( self : *const Vec2, val : f32 ) ?Vec2
  {
    if( val == 0.0 )
    {
      def.qlog( .ERROR, 0, @src(), "Division by zero in Vec2.divVal()" );
      return null;
    }
    return Vec2{ .x = self.x / val, .y = self.y / val };
  }

  pub inline fn dist(    self : *const Vec2, other : Vec2 ) f32 { return @sqrt( self.eucliDistSqr( other )); }
  pub inline fn distSqr( self : *const Vec2, other : Vec2 ) f32
  {
    const dx = self.x - other.x;
    const dy = self.y - other.y;
    return ( dx * dx ) + ( dy * dy );
  }

  pub inline fn manhattanDist( self : *const Vec2, other : Vec2 ) f32 { return self.xDist( other ) + self.yDist( other ); }
  pub inline fn xDist(         self : *const Vec2, other : Vec2 ) f32 { return @abs( self.x - other.x ); }
  pub inline fn yDist(         self : *const Vec2, other : Vec2 ) f32 { return @abs( self.y - other.y ); }

  pub inline fn maxLinDist( self : *const Vec2, other : Vec2 ) f32 { return @max( self.xDist( other ), self.yDist( other )); }
  pub inline fn minLinDist( self : *const Vec2, other : Vec2 ) f32 { return @min( self.xDist( other ), self.yDist( other )); }
  pub inline fn avgLinDist( self : *const Vec2, other : Vec2 ) f32 { return ( self.xDist( other ) + self.yDist( other )) / 2.0; }


  // ================ VECTOR MATHS ================

  pub inline fn normToUnit( self : *const Vec2 ) ?Vec2 { return self. normVec2Len( 1.0 ); }

  // Normalizes a vector to a new length, returns null if the vector is zero'd
  pub fn normToLen( self : *const Vec2, newLen : f32 ) ?Vec2
  {
    if( newLen == 0.0 )
    {
      def.qlog( .WARN, 0, @src(), "Normalizing a Vec2 to 0" );
      return .{};
    }

    const oldLenSqr = self.lenSqr();
    if( oldLenSqr  == 0.0 )
    {
      def.qlog( .ERROR, 0, @src(), "Normalizing a 0:0 Vec2" );
      return null;
    }

    if( oldLenSqr == newLen * newLen ){ return self; }
    const factor = newLen / @sqrt( oldLenSqr );

    return self.mulVal( factor );
  }

  pub inline fn len(    self : *const Vec2 ) f32 { return @sqrt( self.lenSqr() ); }
  pub inline fn lenSqr( self : *const Vec2 ) f32 { return ( self.x * self.x ) + ( self.y * self.y ); }

  pub inline fn rotateDeg( self : *const Vec2, a : f32 ) Vec2 { return self.rotate( def.DtR( a )); }
  pub inline fn rotate(    self : *const Vec2, a : f32 ) Vec2
  {
    if( angle == 0.0 ){ return *self; } // No rotation needed
    const cosA = @cos( a );
    const sinA = @sin( a );

    return Vec2{
      .x = ( self.x * cosA ) - ( self.y * sinA ),
      .y = ( self.x * sinA ) + ( self.y * cosA ),
    };
  }

  pub inline fn angleDeg( self : *const Vec2 ) f32 { return def.RtD( self.angle() ); }
  pub inline fn angle(    self : *const Vec2 ) f32
  {
    if( self.x == 0.0 and self.y == 0.0 )
    {
      def.qlog( .WARN, 0, @src(), "Angle of a zero vector in Vec2.angle()" );
      return 0.0;
    }
    return def.atan2( self.y, self.x );
  }
};


// ================================ VECR STRUCT ================================

pub const VecR = struct
{
  x : f32 = 0,
  y : f32 = 0,
  r : f32 = 0,


  // ================ GENERATION ================

  pub inline fn fromVals( x : f32, y : f32, r : f32 ) VecR { return VecR{ .x = x, .y = y, .r = r }; }

  pub inline fn fromAngleDeg( a : f32 ) VecR { return fromAngle( def.DtR( a )); }
  pub inline fn fromAngle(    a : f32 ) VecR
  {
    return VecR{
      .x = @cos( a ),
      .y = @sin( a ),
      .r = a,
    };
  }

  pub inline fn fromAngleDegScaled( a : f32, scale : VecR ) VecR { return fromAngleScaled( def.DtR( a ), scale ); }
  pub inline fn fromAngleScaled(    a : f32, scale : VecR ) VecR
  {
    return VecR{
      .x = @cos( a ) * scale.x,
      .y = @sin( a ) * scale.y,
      .r = a,
    };
  }

  // ================ CONVERSIONS ================

  pub inline fn toRayVec2( self : *const VecR ) RayVec3 { return RayVec3{ .x = self.x, .y = self.y }; }
  pub inline fn toVec2(    self : *const VecR ) RayVec2 { return RayVec3{ .x = self.x, .y = self.y }; }
  pub inline fn toCoords2( self : *const VecR ) Coords2
  {
    return Coords3{
      .x = @intFromFloat( @trunc( self.x )),
      .y = @intFromFloat( @trunc( self.y )),
    };
  }

  // ================ COMPARISONS ================

  pub inline fn isPos(  self : *const VecR ) bool { return self.x >= 0 and self.y >= 0; }
  pub inline fn isZero( self : *const VecR ) bool { return self.x == 0 and self.y == 0; }

  pub inline fn isEq(    self : *const VecR, other : VecR ) bool { return self.x == other.x and self.y == other.y and self.r == other.r; }
  pub inline fn isDiff(  self : *const VecR, other : VecR ) bool { return self.x != other.x or  self.y != other.y or  self.r != other.r; }
  pub inline fn isInfXY( self : *const VecR, other : VecR ) bool { return self.x <  other.x or  self.y <  other.y; }
  pub inline fn isSupXY( self : *const VecR, other : VecR ) bool { return self.x >  other.x or  self.y >  other.y; }


  // ================ BACIS MATHS ================

  pub inline fn add( self : *const VecR, other : VecR ) VecR { return VecR{ .x = self.x + other.x, .y = self.y + other.y, .r = self.r + other.r }; }
  pub inline fn sub( self : *const VecR, other : VecR ) VecR { return VecR{ .x = self.x - other.x, .y = self.y - other.y, .r = self.r - other.r }; }
  pub inline fn mul( self : *const VecR, other : VecR ) VecR { return VecR{ .x = self.x * other.x, .y = self.y * other.y, .r = self.r * other.r }; }
  pub inline fn div( self : *const VecR, other : VecR ) ?VecR
  {
    if( other.x == 0.0 or other.y == 0.0 or other.r == 0.0 )
    {
      def.qlog( .ERROR, 0, @src(), "Division by zero in VecR.div()" );
      return null;
    }
    return VecR{ .x = self.x / other.x, .y = self.y / other.y, .r = self.r / other.r };
  }

  pub inline fn addVal( self : *const VecR, val : f32 ) VecR { return VecR{ .x = self.x + val, .y = self.y + val, .r = self.r }; }
  pub inline fn subVal( self : *const VecR, val : f32 ) VecR { return VecR{ .x = self.x - val, .y = self.y - val, .r = self.r }; }
  pub inline fn mulVal( self : *const VecR, val : f32 ) VecR { return VecR{ .x = self.x * val, .y = self.y * val, .r = self.r }; }
  pub inline fn divVal( self : *const VecR, val : f32 ) ?VecR
  {
    if( val == 0.0 )
    {
      def.qlog( .ERROR, 0, @src(), "Division by zero in VecR.divVal()" );
      return null;
    }
    return VecR{ .x = self.x / val, .y = self.y / val, .r = self.r };
  }

  pub inline fn dist(    self : *const VecR, other : VecR ) f32 { return @sqrt( self.eucliDistSqr( other )); }
  pub inline fn distSqr( self : *const VecR, other : VecR ) f32
  {
    const dx = self.x - other.x;
    const dy = self.y - other.y;
    return ( dx * dx ) + ( dy * dy );
  }

  pub inline fn manhattanDist( self : *const VecR, other : VecR ) f32 { return self.xDist( other ) + self.yDist( other ); }
  pub inline fn xDist(         self : *const VecR, other : VecR ) f32 { return @abs( self.x - other.x ); }
  pub inline fn yDist(         self : *const VecR, other : VecR ) f32 { return @abs( self.y - other.y ); }
  pub inline fn rDist(         self : *const VecR, other : VecR ) f32 { return @abs( self.r - other.r ); }

  pub inline fn maxLinDist( self : *const VecR, other : VecR ) f32 { return @max(     self.xDist( other ), self.yDist( other )); }
  pub inline fn minLinDist( self : *const VecR, other : VecR ) f32 { return @min(     self.xDist( other ), self.yDist( other )); }
  pub inline fn avgLinDist( self : *const VecR, other : VecR ) f32 { return ( self.xDist( other ) + self.yDist( other )) / 2.0; }


  // ================ VECTOR MATHS ================

  pub inline fn normToUnit( self : *const VecR ) ?VecR { return self. normToLen( 1.0 ); }

  // Normalizes a vector to a new length, returns null if the vector is zero'd
  pub fn normToLen( self : *const VecR, newLen : f32 ) ?VecR
  {
    if( newLen == 0.0 )
    {
      def.qlog( .WARN, 0, @src(), "Normalizing a VecR to 0" );
      return .{};
    }

    const oldLenSqr = self.lenSqr();
    if( oldLenSqr  == 0.0 )
    {
      def.qlog( .ERROR, 0, @src(), "Normalizing a 0:0 VecR" );
      return null;
    }

    if( oldLenSqr == newLen * newLen ){ return self; }
    const factor = newLen / @sqrt( oldLenSqr );

    return self.mulVal( factor );
  }

  pub inline fn len(    self : *const VecR ) f32 { return @sqrt( self.lenSqr() ); }
  pub inline fn lenSqr( self : *const VecR ) f32 { return ( self.x * self.x ) + ( self.y * self.y ); }

  pub inline fn rotateDeg( self : *const VecR, a : f32 ) VecR { return self.rotate( def.DtR( a )); }
  pub inline fn rotate(    self : *const VecR, a : f32 ) VecR
  {
    if( angle == 0.0 ){ return *self; } // No rotation needed
    const cosA = @cos( a );
    const sinA = @sin( a );

    return VecR{
      .x = ( self.x * cosA ) - ( self.y * sinA ),
      .y = ( self.x * sinA ) + ( self.y * cosA ),
      .r = self.r + a, // Update the angle
    };
  }

  pub inline fn angleDeg( self : *const VecR ) f32 { return def.RtD( self.angle() ); }
  pub inline fn angle(    self : *const VecR ) f32
  {
    if( self.x == 0.0 and self.y == 0.0 )
    {
      def.qlog( .WARN, 0, @src(), "Angle of a zero vector in VecR.angle()" );
      return 0.0;
    }
    return def.atan2( self.y, self.x );
  }
};


// ================================ VEC3 STRUCT ================================

pub const Vec3 = struct
{
  x : f32 = 0,
  y : f32 = 0,
  z : f32 = 0,


  // ================ GENERATION ================

  pub inline fn fromVals( x : f32, y : f32, z : f32 ) Vec3 { return Vec3{ .x = x, .y = y, .z = z }; }

  //pub inline fn fromAngleDeg( a : f32, b : f32 ) Vec3 { return fromAngle( def.DtR( a )); }
  //pub inline fn fromAngle(    a : f32, b : f32 ) Vec3
  //{
  //  return Vec3{
  //    .x = @cos( a ),
  //    .y = @sin( a ),
  //  };
  //}

  //pub inline fn fromAngleDegScaled( a : f32, b : f32, scale : Vec3 ) Vec3 { return fromAngleScaled( def.DtR( a ), scale ); }
  //pub inline fn fromAngleScaled(    a : f32, b : f32, scale : Vec3 ) Vec3
  //{
  //  return Vec3{
  //    .x = @cos( a ) * scale.x,
  //    .y = @sin( a ) * scale.y,
  //  };
  //}

  // ================ CONVERSIONS ================

  pub inline fn toRayVec3( self : *const Vec3 ) RayVec3 { return RayVec3{ .x = self.x, .y = self.y, .z = self.z }; }
  pub inline fn toVecR(    self : *const Vec3 ) RayVec3
  {
    return RayVec3{ .x = self.x, .y = self.y, .z = @mod( self.z, std.math.TAU ) }; // Ensure z is within 0..2PI range
  }
  pub inline fn toCoords3( self : *const Vec3 ) Coords2
  {
    return Coords3{
      .x = @intFromFloat( @trunc( self.x )),
      .y = @intFromFloat( @trunc( self.y )),
      .z = @intFromFloat( @trunc( self.z )),
    };
  }

  // ================ COMPARISONS ================

  pub inline fn isPos(  self : *const Vec3 ) bool { return self.x >= 0 and self.y >= 0 and self.z >= 0; }
  pub inline fn isZero( self : *const Vec3 ) bool { return self.x == 0 and self.y == 0 and self.z == 0; }

  pub inline fn isEq(    self : *const Vec3, other : Vec3 ) bool { return self.x == other.x and self.y == other.y and self.z == other.z; }
  pub inline fn isDiff(  self : *const Vec3, other : Vec3 ) bool { return self.x != other.x or  self.y != other.y or  self.z != other.z; }
  pub inline fn isInfXY( self : *const Vec3, other : Vec3 ) bool { return self.x <  other.x or  self.y <  other.y or  self.z <  other.z; }
  pub inline fn isSupXY( self : *const Vec3, other : Vec3 ) bool { return self.x >  other.x or  self.y >  other.y or  self.z >  other.z; }


  // ================ BACIS MATHS ================

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

  pub inline fn dist(    self : *const Vec3, other : Vec3 ) f32 { return @sqrt( self.eucliDistSqr( other )); }
  pub inline fn distSqr( self : *const Vec3, other : Vec3 ) f32
  {
    const dx = self.x - other.x;
    const dy = self.y - other.y;
    const dz = self.z - other.z;
    return ( dx * dx ) + ( dy * dy ) + ( dz * dz );
  }

  pub inline fn manhattanDist( self : *const Vec3, other : Vec3 ) f32 { return self.xDist( other ) + self.yDist( other ) + self.zDist( other ); }
  pub inline fn xDist(         self : *const Vec3, other : Vec3 ) f32 { return @abs( self.x - other.x ); }
  pub inline fn yDist(         self : *const Vec3, other : Vec3 ) f32 { return @abs( self.y - other.y ); }
  pub inline fn zDist(         self : *const Vec3, other : Vec3 ) f32 { return @abs( self.z - other.z ); }

  pub inline fn maxLinDist( self : *const Vec3, other : Vec3 ) f32 { return @max(     self.xDist( other ), self.yDist( other ), self.zDist( other )); }
  pub inline fn medLinDist( self : *const Vec3, other : Vec3 ) f32 { return def.med3( self.xDist( other ), self.yDist( other ), self.zDist( other )); }
  pub inline fn minLinDist( self : *const Vec3, other : Vec3 ) f32 { return @min(     self.xDist( other ), self.yDist( other ), self.zDist( other )); }
  pub inline fn avgLinDist( self : *const Vec3, other : Vec3 ) f32 { return ( self.xDist( other ) + self.yDist( other ) + self.zDist( other )) / 3.0; }


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

  //pub inline fn rotateDeg( self : *const Vec3, a : f32 ) Vec3 { return self.rotate( def.DtR( a )); }
  //pub inline fn rotate(    self : *const Vec3, a : f32 ) Vec3
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