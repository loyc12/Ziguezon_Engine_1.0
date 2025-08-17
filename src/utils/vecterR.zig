const std  = @import( "std" );
const def  = @import( "defs" );

const Vec2 = def.Vec2;
const Vec3 = def.Vec3;

const RayVec2 = def.RayVec2;
const RayVec3 = def.RayVec3;
//const RayVec4 = def.RayVec4;

const Coords2 = def.Coords2;
const Coords3 = def.Coords3;


// ================================ VECR STRUCT ================================

pub const VecR = struct
{
  x : f32 = 0,
  y : f32 = 0,
  r : f32 = 0,


  // ================ GENERATION ================

  pub inline fn zero() VecR { return VecR{ .x = 0, .y = 0, .r = 0 }; }

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
  pub inline fn toVec2(    self : *const VecR ) Vec2    { return Vec2{    .x = self.x, .y = self.y }; }
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
    if( angle == 0.0 ){ return .{ .x = self.x, .y = self.y, .r = self.r }; }
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