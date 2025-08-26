const std  = @import( "std" );
const def  = @import( "defs" );

const Angle = def.Angle;

const VecR = def.VecR;
const Vec3 = def.Vec3;

const RayVec2 = def.RayVec2;
const RayVec3 = def.RayVec3;
//const RayVec4 = def.RayVec4;

const Coords2 = def.Coords2;
const Coords3 = def.Coords3;


// ================================ VEC2 STRUCT ================================

pub const Vec2 = struct
{
  x : f32 = 0,
  y : f32 = 0,


  // ================ GENERATION ================

  pub inline fn zero() Vec2 { return .{}; }

  pub inline fn new( x : f32, y : f32 ) Vec2 { return Vec2{ .x = x, .y = y }; }

  pub inline fn fromAngleDeg( a : Angle ) Vec2 { return fromAngle( def.DtR( a )); }
  pub inline fn fromAngle(    a : Angle ) Vec2
  {
    return Vec2{
      .x = a.cos(),
      .y = a.sin(),
    };
  }

  pub inline fn fromAngleDegScaled( a : Angle, scale : Vec2 ) Vec2 { return fromAngleScaled( def.DtR( a ), scale ); }
  pub inline fn fromAngleScaled(    a : Angle, scale : Vec2 ) Vec2
  {
    return Vec2{
      .x = a.cos() * scale.x,
      .y = a.sin() * scale.y,
    };
  }

  // ================ CONVERSIONS ================

  pub inline fn toRayVec2( self : *const Vec2 ) RayVec2 { return RayVec2{ .x = self.x, .y = self.y }; }
  pub inline fn toVecR(    self : *const Vec2, r : ?Angle ) VecR
  {
    if( r == null ){ return VecR{ .x = self.x, .y = self.y, .r = self.toAngle() }; }
    else           { return VecR{ .x = self.x, .y = self.y, .r = r.? }; }
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
    const factor  =  newLen / @sqrt( oldLenSqr );

    return self.mulVal( factor );
  }

  pub inline fn len(    self : *const Vec2 ) f32 { return @sqrt( self.lenSqr() ); }
  pub inline fn lenSqr( self : *const Vec2 ) f32 { return ( self.x * self.x ) + ( self.y * self.y ); }

  pub inline fn rotDeg( self : *const Vec2, a : Angle ) Vec2 { return self.rot( def.DtR( a )); }
  pub inline fn rot(    self : *const Vec2, a : Angle ) Vec2
  {
    if( a.isZero() ){ return .{ .x = self.x, .y = self.y }; }
    const cosA = a.cos();
    const sinA = a.sin();

    return Vec2{
      .x = ( self.x * cosA ) - ( self.y * sinA ),
      .y = ( self.x * sinA ) + ( self.y * cosA ),
    };
  }

  pub inline fn toAngle( self : *const Vec2 ) Angle { return Angle.atan2( self.y, self.x ); }
};