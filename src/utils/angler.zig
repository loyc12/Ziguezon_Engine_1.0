const std = @import( "std" );
const def = @import( "defs" );

const Vec2 = def.Vec2;
const VecA = def.VecA;
//const Vec3 = def.Vec3;

const RayVec2 = def.RayVec2;
//const RayVec3 = def.RayVec3;
//const RayVec4 = def.RayVec4;

// ================================ ANGLE STRUCT ================================

pub const Angle = struct
{
  r : f32 = 0,


  // ================ GENERATION ================

  pub inline fn newDeg( d : f32 ) Angle { return Angle.newRad( def.DtR( d )); }
  pub inline fn newRad( r : f32 ) Angle
  {
    var tmp = Angle{ .r = r };
    return tmp.norm();
  }

  // ================ CONVERSIONS ================

  pub inline fn toRayVec2( self : *const Angle, scale : ?Vec2 ) RayVec2        { return self.toVec2( scale ).toRayVec2(); }
  pub inline fn toVecA(    self : *const Angle, scale : ?Vec2, r : ?f32 ) VecA { return self.toVec2( scale ).toVecA( r ); }
  pub inline fn toVec2(    self : *const Angle, scale : ?Vec2 ) Vec2
  {
    const r = @cos( self.r ) * if( scale )| s | s.r else 1.0;
    const y = @sin( self.r ) * if( scale )| s | s.y else 1.0;

    return Vec2{ .r = r, .y = y };
  }

  pub inline fn toRad( self : *const Angle ) f32 { return self.r; }
  pub inline fn toDeg( self : *const Angle ) f32 { return def.RtD( self.r ); }
  pub inline fn toOne( self : *const Angle ) f32 { return self.r / std.math.pi; }

  pub inline fn normSelf( self :   *Angle ) void  { self.r =           def.wrap( self.r, -std.math.pi, std.math.pi );  }
  pub inline fn norm( self : *const Angle ) Angle { return Angle{ .r = def.wrap( self.r, -std.math.pi, std.math.pi )}; }


  // ================ COMPARISONS ================

  pub inline fn isPosi(  self : *const Angle ) bool { return self.r > 0; }
  pub inline fn isNeg(  self : *const Angle ) bool { return self.r < 0; }
  pub inline fn isZero( self : *const Angle ) bool { return self.r == 0; }

  pub inline fn isEq(   self : *const Angle, other : Angle ) bool { return self.r == other.r; }
  pub inline fn isDiff( self : *const Angle, other : Angle ) bool { return self.r != other.r; }

  pub inline fn isLeftOf(  self : *const Angle, other : Angle ) bool { return self.sub( other ).isPosi(); }
  pub inline fn isRightOf( self : *const Angle, other : Angle ) bool { return self.sub( other ).isNeg(); }

  pub inline fn isAlignedTo(  self : *const Angle, other : Angle, threshold : f32 ) bool { return std.math.abs( self.sub( other ).r ) <= threshold; }
  pub inline fn isOppositeTo( self : *const Angle, other : Angle, threshold : f32 ) bool { return std.math.abs( std.math.abs( self.sub( other ).r ) - std.math.pi ) <= threshold; }
  pub inline fn isPerpTo(     self : *const Angle, other : Angle, threshold : f32 ) bool { return std.math.abs( std.math.abs( self.sub( other ).r ) - ( std.math.pi / 2 )) <= threshold; }


  // ================ BACIS MATHS ================

  pub inline fn neg( self : *const Angle ) Angle { return Angle.newRad( -self.r ).norm(); }
  pub inline fn inv( self : *const Angle ) Angle { return Angle.newRad( self.r + std.math.pi ).norm(); }

  //pub inline fn flipAlongTangent( self : *const Angle, tangA : Angle ) Angle { return tangA.mulVal( 2 ).sub( self ).norm(); } // TODO : test this shit, I do not truct copilot's explainations here
  //pub inline fn flipAlongNormal(  self : *const Angle, normA : Angle ) Angle { return normA.mulVal( 2 ).sub( self ).norm(); }

  pub inline fn rot( self : *const Angle, other : Angle ) Angle { return self.add( other ); }
  pub inline fn add( self : *const Angle, other : Angle ) Angle { return Angle.newRad( self.r + other.r ).norm(); }
  pub inline fn sub( self : *const Angle, other : Angle ) Angle { return Angle.newRad( self.r - other.r ).norm(); }

  pub inline fn rotRad( self : *const Angle, val : f32 ) Angle { return self.addRad( val ); }
  pub inline fn addRad( self : *const Angle, val : f32 ) Angle { return Angle.newRad( self.r + val ).norm(); }
  pub inline fn subRad( self : *const Angle, val : f32 ) Angle { return Angle.newRad( self.r - val ).norm(); }

  pub inline fn rotDeg( self : *const Angle, val : f32 ) Angle { return self.addDeg( val ); }
  pub inline fn addDeg( self : *const Angle, val : f32 ) Angle { return Angle.newRad( self.r + def.DtR( val )).norm(); }
  pub inline fn subDeg( self : *const Angle, val : f32 ) Angle { return Angle.newRad( self.r - def.DtR( val )).norm(); }

  pub inline fn mulVal( self : *const Angle, val : f32 ) Angle { return Angle.newRad( self.r * val ).norm(); }
  pub inline fn divVal( self : *const Angle, val : f32 ) Angle
  {
    if( val == 0 )
    {
      def.qlog( .ERROR, 0, @src(), "Division by zero in Angle.div()" );
      return self.*;
    }
    return Angle.newRad( self.r / val ).norm();
  }


  // ================ TRIGONOMETRY ================

  pub inline fn cos(   self : *const Angle ) f32 { return @cos( self.r ); }
  pub inline fn sin(   self : *const Angle ) f32 { return @sin( self.r ); }
  pub inline fn tan(   self : *const Angle ) f32 { return @tan( self.r ); }
  pub inline fn slerp( self : *const Angle, other : Angle, t : f32 ) Angle
  {
    const diff = other.sub( self );
    return self.add( diff.mul( def.clamp( t, 0.0, 1.0 )));
  }

  pub inline fn acos( val : f32 ) Angle { return Angle.newRad( std.math.acos( val ) ).norm(); }
  pub inline fn asin( val : f32 ) Angle { return Angle.newRad( std.math.asin( val ) ).norm(); }
  pub inline fn atan( val : f32 ) Angle { return Angle.newRad( std.math.atan( val ) ).norm(); }

  pub inline fn sec( val : f32 ) Angle { return Angle.newRad( std.math.acos( 1.0 / val ) ).norm(); }
  pub inline fn csc( val : f32 ) Angle { return Angle.newRad( std.math.asin( 1.0 / val ) ).norm(); }
  pub inline fn cot( val : f32 ) Angle { return Angle.newRad( std.math.atan( 1.0 / val ) ).norm(); }

  pub inline fn atan2( y : f32, x : f32 ) Angle { return Angle.newRad( std.math.atan2( y, x ) ).norm(); }

};