const std = @import( "std" );
const utl = @import( "utils" );

const Vec2 = utl.Vec2;
const VecA = utl.VecA;
//const Vec3 = utl.Vec3;

const RayVec2 = utl.RayVec2;
//const RayVec3 = utl.RayVec3;
//const RayVec4 = utl.RayVec4;

// ================================ ANGLE STRUCT ================================

pub const Angle = struct
{
  r : f64 = 0,


  // ================ GENERATION ================

  pub inline fn newDeg( d : f64 ) Angle { return Angle.newRad( utl.DtR( d )); }
  pub inline fn newRad( r : f64 ) Angle
  {
    var tmp = Angle{ .r = r };
    return tmp.norm();
  }

  // ================ CONVERSIONS ================

  pub inline fn toRayVec2( self : Angle, scale : ?Vec2 ) RayVec2 { return self.toVec2( scale ).toRayVec2(); }

  pub inline fn toVec2( self : Angle, scale : ?Vec2 ) Vec2
  {
    const x = @cos( self.r ) * if( scale )| s | s.x else 1.0;
    const y = @sin( self.r ) * if( scale )| s | s.y else 1.0;

    return Vec2{ .x = x, .y = y };
  }
  pub inline fn toVecA( self : Angle, scale : ?Vec2, a : ?Angle ) VecA // NOTE : uses self for vecA.a if a is null
  {
    return self.toVec2( scale ).toVecA( a orelse self );
  }

  inline fn getPosR( self : Angle ) f64 { return if( self.r < 0.0 ) self.r + utl.TAU else self.r; }

  pub inline fn toRad(     self : Angle ) f64 { return self.r; }
  pub inline fn toPosRad(  self : Angle ) f64 { return self.getPosR(); }

  pub inline fn toDeg(     self : Angle ) f64 { return utl.RtD( self.r ); }
  pub inline fn toPosDeg(  self : Angle ) f64 { return utl.RtD( self.getPosR() ); }

  pub inline fn toCenUnit( self : Angle ) f64 { return self.r / utl.PI; }
  pub inline fn toPosUnit( self : Angle ) f64 { return self.getPosR() / utl.TAU; }

  pub inline fn norm(     self : Angle ) Angle { return Angle{ .r = utl.wrap( self.r, -utl.PI, utl.PI )}; }
  pub inline fn normSelf( self :*Angle ) void  {           self.r = utl.wrap( self.r, -utl.PI, utl.PI );  }


  // ================ COMPARISONS ================

  pub inline fn isPosi( self : Angle ) bool { return self.r >  utl.EPS; }
  pub inline fn isNeg(  self : Angle ) bool { return self.r < -utl.EPS; }
  pub inline fn isZero( self : Angle ) bool { return utl.isFltZr( self.r ); }

  pub inline fn isEq(   self : Angle, other : Angle ) bool { return  utl.isFltEq( self.r, other.r ); }
  pub inline fn isDiff( self : Angle, other : Angle ) bool { return !utl.isFltEq( self.r, other.r ); }

  pub inline fn isLeftOf(  self : Angle, other : Angle ) bool { return self.sub( other ).isPosi(); }
  pub inline fn isRightOf( self : Angle, other : Angle ) bool { return self.sub( other ).isNeg(); }

  pub inline fn isAlignedTo(  self : Angle, other : Angle, threshold : f64 ) bool { return std.math.abs( self.sub( other ).r ) <= threshold; }
  pub inline fn isOppositeTo( self : Angle, other : Angle, threshold : f64 ) bool { return std.math.abs( std.math.abs( self.sub( other ).r ) - utl.PI ) <= threshold; }
  pub inline fn isPerpTo(     self : Angle, other : Angle, threshold : f64 ) bool { return std.math.abs( std.math.abs( self.sub( other ).r ) - ( utl.PI / 2 )) <= threshold; }


  // ================ BACIS MATHS ================

  pub inline fn neg( self : Angle ) Angle { return Angle.newRad( -self.r ).norm(); }
  pub inline fn inv( self : Angle ) Angle { return Angle.newRad( self.r + utl.PI ).norm(); }

// TODO : review these 2 functions for issues, as I do not trust copilote ( why are they the same ?? )
  pub inline fn flipAlongTangent( self : Angle, tangA : Angle ) Angle { return tangA.mulVal( 2 ).sub( self ).norm(); }
  pub inline fn flipAlongNormal(  self : Angle, normA : Angle ) Angle { return normA.mulVal( 2 ).sub( self ).norm(); }

  pub inline fn rot( self : Angle, other : Angle ) Angle { return self.add( other ); }
  pub inline fn add( self : Angle, other : Angle ) Angle { return Angle.newRad( self.r + other.r ).norm(); }
  pub inline fn sub( self : Angle, other : Angle ) Angle { return Angle.newRad( self.r - other.r ).norm(); }

  pub inline fn rotRad( self : Angle, val : f64 ) Angle { return self.addRad(  val ); }
  pub inline fn addRad( self : Angle, val : f64 ) Angle { return Angle.newRad( self.r + val ).norm(); }
  pub inline fn subRad( self : Angle, val : f64 ) Angle { return Angle.newRad( self.r - val ).norm(); }

  pub inline fn rotDeg( self : Angle, val : f64 ) Angle { return self.addDeg(  val ); }
  pub inline fn addDeg( self : Angle, val : f64 ) Angle { return Angle.newRad( self.r + utl.DtR( val )).norm(); }
  pub inline fn subDeg( self : Angle, val : f64 ) Angle { return Angle.newRad( self.r - utl.DtR( val )).norm(); }

  pub inline fn mulVal( self : Angle, val : f64 ) Angle { return Angle.newRad( self.r * val ).norm(); }
  pub inline fn divVal( self : Angle, val : f64 ) Angle
  {
    if( utl.isFltZr( val ) )
    {
      utl.qlog( .ERROR, 0, @src(), "Division by zero in Angle.div()" );
      return self;
    }
    return Angle.newRad( self.r / val ).norm();
  }


  // ================ TRIGONOMETRY ================

  pub inline fn cos(   self : Angle ) f64 { return @cos( self.r ); }
  pub inline fn sin(   self : Angle ) f64 { return @sin( self.r ); }
  pub inline fn tan(   self : Angle ) f64 { return @tan( self.r ); }
  pub inline fn slerp( self : Angle, other : Angle, t : f64 ) Angle
  {
    const diff = other.sub( self );
    return self.add( diff.mulVal( utl.clmp( t, 0.0, 1.0 )));
  }

  pub inline fn acos( val : f64 ) Angle { return Angle.newRad( std.math.acos( val ) ).norm(); }
  pub inline fn asin( val : f64 ) Angle { return Angle.newRad( std.math.asin( val ) ).norm(); }
  pub inline fn atan( val : f64 ) Angle { return Angle.newRad( std.math.atan( val ) ).norm(); }

  pub inline fn sec( val : f64 ) Angle { return Angle.newRad( std.math.acos( 1.0 / val ) ).norm(); }
  pub inline fn csc( val : f64 ) Angle { return Angle.newRad( std.math.asin( 1.0 / val ) ).norm(); }
  pub inline fn cot( val : f64 ) Angle { return Angle.newRad( std.math.atan( 1.0 / val ) ).norm(); }

  pub inline fn atan2( y : f64, x : f64 ) Angle { return Angle.newRad( std.math.atan2( y, x ) ).norm(); }

};
