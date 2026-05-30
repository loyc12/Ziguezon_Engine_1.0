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
  x : f64   = 0,
  y : f64   = 0,
  a : Angle = .{},


  // ================ GENERATION ================

  pub inline fn new( x : f64, y : f64, a : ?Angle ) VecA
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

  pub inline fn toRayVec2( self : VecA ) RayVec2 { return RayVec2{ .x = @floatCast( self.x ), .y = @floatCast( self.y )}; }
  pub inline fn toVec2(    self : VecA ) Vec2    { return Vec2{    .x = self.x, .y = self.y }; }
  pub inline fn toCoords2( self : VecA ) Coords2
  {
    return Coords3{
      .x = @intFromFloat( @trunc( self.x )),
      .y = @intFromFloat( @trunc( self.y )),
    };
  }

  // ================ COMPARISONS ================

  pub inline fn isPosi( self : VecA ) bool { return self.x > 0 and self.y > 0; }
  pub inline fn isZero( self : VecA ) bool { return def.isFltZr( self.x ) and def.isFltZr( self.y ); }
  pub inline fn isIso(  self : VecA ) bool { return def.isFltEq( self.x, self.y ); }

  pub inline fn isEq(   self : VecA, other : VecA ) bool { return def.isFltEq( self.x, other.x ) and def.isFltEq( self.y, other.y ) and self.a.isEq( other.a ); }
  pub inline fn isDiff( self : VecA, other : VecA ) bool { return !self.isEq( other ); }


  // ================ BACIS MATHS ================

  pub inline fn abs( self : VecA ) VecA { return VecA{ .x =  @abs( self.x ), .y =  @abs( self.y ), .a =   @abs( self.a )}; }
  pub inline fn neg( self : VecA ) VecA { return VecA{ .x = -@abs( self.x ), .y = -@abs( self.y ), .a =  -@abs( self.a )}; }

  pub inline fn add( self : VecA, other : VecA ) VecA { return VecA{ .x = self.x + other.x, .y = self.y + other.y, .a = self.a.add( other.a )}; }
  pub inline fn sub( self : VecA, other : VecA ) VecA { return VecA{ .x = self.x - other.x, .y = self.y - other.y, .a = self.a.sub( other.a )}; }
  pub inline fn mul( self : VecA, other : VecA ) VecA { return VecA{ .x = self.x * other.x, .y = self.y * other.y, .a = self.a.mul( other.a )}; }
  pub inline fn div( self : VecA, other : VecA ) ?VecA
  {
    if( def.isFltZr( other.x ) or def.isFltZr( other.y ) )
    {
      def.qlog( .ERROR, 0, @src(), "Division by zero in VecA.div()" );
      return null;
    }
    return VecA{ .x = self.x / other.x, .y = self.y / other.y, .a = self.a.div( other.a )};
  }

  pub inline fn addVal( self : VecA, val : f64 ) VecA { return VecA{ .x = self.x + val, .y = self.y + val, .a = self.a.addVal( @floatCast( val ))}; }
  pub inline fn subVal( self : VecA, val : f64 ) VecA { return VecA{ .x = self.x - val, .y = self.y - val, .a = self.a.subVal( @floatCast( val ))}; }
  pub inline fn mulVal( self : VecA, val : f64 ) VecA { return VecA{ .x = self.x * val, .y = self.y * val, .a = self.a.mulVal( @floatCast( val ))}; }
  pub inline fn divVal( self : VecA, val : f64 ) ?VecA
  {
    if( def.isFltZr( val ))
    {
      def.qlog( .ERROR, 0, @src(), "Division by zero in VecA.divVal()" );
      return null;
    }
    return VecA{ .x = self.x / val, .y = self.y / val, .a = self.a.mulVal( 1.0 / val )};
  }

  pub inline fn getDist(    self : VecA, other : VecA ) f64 { return @sqrt( self.getDistSqr( other )); }
  pub inline fn getDistSqr( self : VecA, other : VecA ) f64
  {
    const dx = self.x - other.x;
    const dy = self.y - other.y;
    return ( dx * dx ) + ( dy * dy );
  }

  pub inline fn getDistM( self : VecA, other : VecA ) f64 { return self.getDistX( other ) + self.getDistY( other ); }
  pub inline fn getDistX( self : VecA, other : VecA ) f64 { return @abs( self.x - other.x ); }
  pub inline fn getDistY( self : VecA, other : VecA ) f64 { return @abs( self.y - other.y ); }
  pub inline fn getDistR( self : VecA, other : VecA ) f64 { return @abs( self.a - other.a ); }

  pub inline fn getMaxLinDist( self : VecA, other : VecA ) f64 { return @max( self.getDistX( other ), self.getDistY( other )); }
  pub inline fn getMinLinDist( self : VecA, other : VecA ) f64 { return @min( self.getDistX( other ), self.getDistY( other )); }
  pub inline fn getAvgLinDist( self : VecA, other : VecA ) f64 { return ( self.getDistX( other ) + self.getDistY( other )) / 2.0; }


  // ================ VECTOR MATHS ================
  pub inline fn lerp(  self : VecA, other : VecA, t : f64 ) VecA
  {
    const x : f64 = def.lerp( self.x,   other.x,   t );
    const y : f64 = def.lerp( self.y,   other.y,   t );
    const r : f64 = def.lerp( self.a.r, other.a.r, t );

    return .new( x, y, .newRad( r ));
  }
  pub inline fn norm(  self : VecA               ) VecA { return self.normToLen( 1.0 ); }
  pub inline fn dot(   self : VecA, other : VecA ) f64  { return ( self.x * other.x ) + ( self.y * other.y ); }
  pub inline fn cross( self : VecA, other : VecA ) f64  { return ( self.x * other.y ) - ( self.y * other.x ); }

  // Normalizes a vector to a new length, returns null if the vector is zero'd
  pub fn normToLen( self : VecA, newLen : f64 ) VecA
  {
    if( def.isFltZr( newLen ))
    {
      def.qlog( .WARN, 0, @src(), "Normalizing a VecA to 0" );
      return .{};
    }

    const oldLenSqr = self.lenSqr();
    if( def.isFltZr( oldLenSqr ))
    {
      def.qlog( .WARN, 0, @src(), "Normalizing a 0:0 VecA" );
      return .{};
    }

    if( def.isFltEq( oldLenSqr, newLen * newLen )){ return self; }
    const factor = newLen / @sqrt( oldLenSqr );

    return self.mulVal( factor );
  }

  pub inline fn len(    self : VecA ) f64 { return @sqrt( self.lenSqr() ); }
  pub inline fn lenSqr( self : VecA ) f64 { return ( self.x * self.x ) + ( self.y * self.y ); }

  pub inline fn rotDeg( self : VecA, d : f64   ) VecA { return self.rot( .{ .r = def.DtR( d )}); }
  pub inline fn rot(    self : VecA, a : Angle ) VecA
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

  pub inline fn toAngle( self : VecA ) Angle { return Angle.atan2( self.y, self.x ); }
};