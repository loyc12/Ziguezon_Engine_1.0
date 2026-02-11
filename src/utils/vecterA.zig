const std  = @import( "std" );
const def  = @import( "defs" );

const Angle = def.Angle;

const Vec2 = def.Vec2;
const Vec3 = def.Vec3;

const RayVec2 = def.RayVec2;
const RayVec3 = def.RayVec3;
//const RayVec4 = def.RayVec4;

const Coords2 = def.Coords2;
const Coords3 = def.Coords3;


// ================================ VECR STRUCT ================================

pub const VecA = struct
{
  x : f32   = 0,
  y : f32   = 0,
  a : Angle = .{},


  // ================ GENERATION ================

  pub inline fn new( x : f32, y : f32, a : ?Angle ) VecA
  {
    if( a == null ){ return VecA{ .x = x, .y = y, .a = .{} }; }
    else           { return VecA{ .x = x, .y = y, .a = a.? }; }
  }

  pub inline fn fromAngleDeg( a : Angle ) VecA { return fromAngle( def.DtR( a )); }
  pub inline fn fromAngle(    a : Angle ) VecA
  {
    return VecA{
      .x = @cos( a ),
      .y = @sin( a ),
      .a = a,
    };
  }

  pub inline fn fromAngleDegScaled( a : Angle, scale : VecA ) VecA { return fromAngleScaled( def.DtR( a ), scale ); }
  pub inline fn fromAngleScaled(    a : Angle, scale : VecA ) VecA
  {
    return VecA{
      .x = @cos( a ) * scale.x,
      .y = @sin( a ) * scale.y,
      .a = a,
    };
  }

  // ================ CONVERSIONS ================

  pub inline fn toRayVec2( self : *const VecA ) RayVec2 { return RayVec2{ .x = self.x, .y = self.y }; }
  pub inline fn toVec2(    self : *const VecA ) Vec2    { return Vec2{    .x = self.x, .y = self.y }; }
  pub inline fn toCoords2( self : *const VecA ) Coords2
  {
    return Coords3{
      .x = @intFromFloat( @trunc( self.x )),
      .y = @intFromFloat( @trunc( self.y )),
    };
  }

  // ================ COMPARISONS ================

  pub inline fn isPosi( self : *const VecA ) bool { return self.x >= 0 and self.y >= 0; }
  pub inline fn isZero( self : *const VecA ) bool { return self.x == 0 and self.y == 0; }
  pub inline fn isIso(  self : *const VecA ) bool { return self.x == self.y; }

  pub inline fn isEq(    self : *const VecA, other : VecA ) bool { return self.x == other.x and self.y == other.y and self.a == other.a; }
  pub inline fn isDiff(  self : *const VecA, other : VecA ) bool { return self.x != other.x or  self.y != other.y or  self.a != other.a; }
  pub inline fn isInfXY( self : *const VecA, other : VecA ) bool { return self.x <  other.x or  self.y <  other.y; }
  pub inline fn isSupXY( self : *const VecA, other : VecA ) bool { return self.x >  other.x or  self.y >  other.y; }


  // ================ BACIS MATHS ================

  pub inline fn abs( self : *const VecA ) VecA { return VecA{ .x =  @abs( self.x ), .y =  @abs( self.y ), .a =   @abs( self.a )}; }
  pub inline fn neg( self : *const VecA ) VecA { return VecA{ .x = -@abs( self.x ), .y = -@abs( self.y ), .a =  -@abs( self.a )}; }

  pub inline fn add( self : *const VecA, other : VecA ) VecA { return VecA{ .x = self.x + other.x, .y = self.y + other.y, .a = self.a.add( other.a )}; }
  pub inline fn sub( self : *const VecA, other : VecA ) VecA { return VecA{ .x = self.x - other.x, .y = self.y - other.y, .a = self.a.sub( other.a )}; }
  pub inline fn mul( self : *const VecA, other : VecA ) VecA { return VecA{ .x = self.x * other.x, .y = self.y * other.y, .a = self.a.mul( other.a )}; }
  pub inline fn div( self : *const VecA, other : VecA ) ?VecA
  {
    if( other.x == 0.0 or other.y == 0.0 )
    {
      def.qlog( .ERROR, 0, @src(), "Division by zero in VecA.div()" );
      return null;
    }
    return VecA{ .x = self.x / other.x, .y = self.y / other.y, .a = self.a.div( other.a )};
  }

  pub inline fn addVal( self : *const VecA, val : f32 ) VecA { return VecA{ .x = self.x + val, .y = self.y + val, .a = self.a.addVal( val )}; }
  pub inline fn subVal( self : *const VecA, val : f32 ) VecA { return VecA{ .x = self.x - val, .y = self.y - val, .a = self.a.subVal( val )}; }
  pub inline fn mulVal( self : *const VecA, val : f32 ) VecA { return VecA{ .x = self.x * val, .y = self.y * val, .a = self.a.mulVal( val )}; }
  pub inline fn divVal( self : *const VecA, val : f32 ) ?VecA
  {
    if( val == 0.0 )
    {
      def.qlog( .ERROR, 0, @src(), "Division by zero in VecA.divVal()" );
      return null;
    }
    return VecA{ .x = self.x / val, .y = self.y / val, .a = self.a.divVal( val )};
  }

  pub inline fn getDist(    self : *const VecA, other : VecA ) f32 { return @sqrt( self.getDistSqr( other )); }
  pub inline fn getDistSqr( self : *const VecA, other : VecA ) f32
  {
    const dx = self.x - other.x;
    const dy = self.y - other.y;
    return ( dx * dx ) + ( dy * dy );
  }

  pub inline fn getDistM( self : *const VecA, other : VecA ) f32 { return self.getDistX( other ) + self.getDistY( other ); }
  pub inline fn getDistX( self : *const VecA, other : VecA ) f32 { return @abs( self.x - other.x ); }
  pub inline fn getDistY( self : *const VecA, other : VecA ) f32 { return @abs( self.y - other.y ); }
  pub inline fn getDistR( self : *const VecA, other : VecA ) f32 { return @abs( self.a - other.a ); }

  pub inline fn getMaxLinDist( self : *const VecA, other : VecA ) f32 { return @max( self.getDistX( other ), self.getDistY( other )); }
  pub inline fn getMinLinDist( self : *const VecA, other : VecA ) f32 { return @min( self.getDistX( other ), self.getDistY( other )); }
  pub inline fn getAvgLinDist( self : *const VecA, other : VecA ) f32 { return ( self.getDistX( other ) + self.getDistY( other )) / 2.0; }


  // ================ VECTOR MATHS ================

  pub inline fn normToUnit( self : *const VecA ) ?VecA { return self. normToLen( 1.0 ); }

  // Normalizes a vector to a new length, returns null if the vector is zero'd
  pub fn normToLen( self : *const VecA, newLen : f32 ) ?VecA
  {
    if( newLen == 0.0 )
    {
      def.qlog( .WARN, 0, @src(), "Normalizing a VecA to 0" );
      return .{};
    }

    const oldLenSqr = self.lenSqr();
    if( oldLenSqr  == 0.0 )
    {
      def.qlog( .ERROR, 0, @src(), "Normalizing a 0:0 VecA" );
      return null;
    }

    if( oldLenSqr == newLen * newLen ){ return self; }
    const factor = newLen / @sqrt( oldLenSqr );

    return self.mulVal( factor );
  }

  pub inline fn len(    self : *const VecA ) f32 { return @sqrt( self.lenSqr() ); }
  pub inline fn lenSqr( self : *const VecA ) f32 { return ( self.x * self.x ) + ( self.y * self.y ); }

  pub inline fn rotDeg( self : *const Vec2, d : f32   ) Vec2 { return self.rot( .{ .r = def.DtR( d )}); }
  pub inline fn rot(    self : *const VecA, a : Angle ) VecA
  {
    if( a.isZero() ){ return .{ .x = self.x, .y = self.y, .a = self.a }; }
    const cosA = a.cos();
    const sinA = a.sin();

    return VecA{
      .x = ( self.x * cosA ) - ( self.y * sinA ),
      .y = ( self.x * sinA ) + ( self.y * cosA ),
      .a = self.a.rot( a ), // Update the angle
    };
  }

  pub inline fn toAngle( self : *const VecA ) Angle { return Angle.atan2( self.y, self.x ); }
};