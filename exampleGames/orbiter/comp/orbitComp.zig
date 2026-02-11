const std = @import( "std" );
const def = @import( "defs" );

const Vec2 = def.Vec2;

pub const OrbitComp = struct
{
  pub inline fn getStoreType() type { return def.componentStoreFactory( @This() ); }

  const G = 1;   // Gravitational constant ( tweakable )
  const N = 256; // number of segments used to render orbital path

  // Orbitee's mass ( ought to be near-constant )
  orbitedMass : f32,

  // Min/Max radius approach
  minRadius : f32 = 200.0, // Periapsis (closest)
  maxRadius : f32 = 600.0, // Apoapsis (farthest)

  // Eccentricity and Procession direction
  orientation : f32  = 0.0,   // Periapsis angle ( 0 to 2π, 0 => +X )
  retrograde  : bool = false, // If the orbit is counter-clockwise visually ( clockwise mathematically )

  // Current position
  angularPos  : f32 = 0.0, // Current position along orbit ( 0 to 2π, 0 => +X )
  angularVel  : f32 = 0.0,


  pub inline fn getSemiMajor( self : *const OrbitComp ) f32
  {
    return ( self.maxRadius + self.minRadius ) / 2.0;
  }
  pub inline fn getEccentricity( self : *const OrbitComp ) f32
  {
    return ( self.maxRadius - self.minRadius ) / ( self.maxRadius + self.minRadius );
  }

  pub inline fn getCurrentRadius( self : *const OrbitComp ) f32
  {
    return self.getRadiusAtAngle( self.angularPos );
  }
  pub inline fn getRadiusAtAngle( self : *const OrbitComp, angle : f32 ) f32
  {
    const e = self.getEccentricity();
    const eSqr = e * e;

    // Orbital radius formula: r = a( 1 - e² ) / ( 1 + e·cos(θ) )
    const numer = self.getSemiMajor() * ( 1.0 - ( eSqr ));
    const denom = 1.0 + ( e * @cos( angle ));

    return numer / denom;
  }


  // Orbital period depends on semi-major axis and central mass ( Kepler's 3rd Law )
  // T² ∝ a³/M  →  ω = √(GM/a³)
  pub inline fn getMeanAngularVel( self : *const OrbitComp ) f32
  {
    const semiMajor = self.getSemiMajor();

    // Prevent division by zero / very small values
    if( semiMajor < 1.0 ){ return 0.0; }

    const semiMajorCub = semiMajor * semiMajor * semiMajor;

    const meanAngVel = @sqrt( G * self.orbitedMass / semiMajorCub );

    return switch( self.retrograde )
    {
      false =>  meanAngVel,
      true  => -meanAngVel,
    };
  }

  // True angular velocity varies with angular position ( Kepler's 2nd Law )
  // ω_true = ω_mean * ( 1 + e·cos(θ) )² / ( 1 - e² )^( 3/2 )
  pub inline fn getAngularVel( self : *const OrbitComp ) f32
  {
    const meanAngVel = self.getMeanAngularVel();

    const ecc = self.getEccentricity();
    const eccSqr = ecc * ecc;

    const numerRoot = 1.0 + ( ecc * @cos( self.angularPos ));
    const denom     = ( 1.0 - eccSqr ) * @sqrt( 1.0 - eccSqr );

    return meanAngVel * ( numerRoot * numerRoot ) / denom;
  }

  // Calculates the orbiter's position
  pub inline fn getAbsPos( self : *const OrbitComp, orbitedPos : Vec2 ) Vec2
  {
    return orbitedPos.add( self.getRelPos() );
  }
  pub inline fn getRelPos( self : *const OrbitComp ) Vec2
  {
    return self.getRelPosAtAngle( self.angularPos );
  }
  pub inline fn getRelPosAtAngle( self : *const OrbitComp, angle : f32 ) Vec2
  {
    const radius = self.getRadiusAtAngle( angle );

    // Position in orbit space ( 0° => along +X )
    const x = radius * @cos( angle );
    const y = radius * @sin( angle );

    // Return the position after rotating it appropriately
    return Vec2.new( x, y ).rot( .{ .r = self.orientation });
  }


  // Calculate the orbiter's velocity
  pub inline fn getAbsVel( self : *const OrbitComp, orbitedVel : Vec2 ) Vec2
  {
    return orbitedVel.add( self.getRelVel() );
  }
  pub inline fn getRelVel( self : *const OrbitComp ) Vec2
  {
    const speed = self.angularVel * self.getCurrentRadius();

    // Velocity direction is perpendicular to radius ( tangent to orbit )
    const velAngle = self.angularPos + ( def.PI / 2.0 );
    const velVect  = Vec2.fromAngle( .{ .r = velAngle }).mulVal( speed );

    return velVect.rot( .{ .r = self.orientation });
  }


  pub fn updateOrbit( self : *OrbitComp, selfTrans : *def.TransComp, otherTrans : *const def.TransComp, sdt : f32 ) void
  {
    self.angularPos += self.angularVel * sdt;

    // Wrap to 0-2π ( handles both positive and negative )
    self.angularPos = def.wrap( self.angularPos, 0.0, def.TAU );

    // NOTE : Be careful about update ordering, as angular vel is cached for reuse in getAbsVel()
    self.angularVel = self.getAngularVel();

    selfTrans.pos = self.getAbsPos( otherTrans.pos.toVec2() ).toVecA( selfTrans.pos.a );
    selfTrans.vel = self.getAbsVel( otherTrans.vel.toVec2() ).toVecA( selfTrans.vel.a );
    selfTrans.acc = .{}; // Acceleration is to be ignored for orbiting objetcs, as they have predefined paths anyways
  }

  pub fn renderPath( self : *const OrbitComp, orbiteePos : Vec2 ) void
  {
    var p1 : Vec2 = self.getRelPosAtAngle( 0 );
    var p2 : Vec2 = p1;

    const zoomedWidth = 1.0 / def.G_NG.camera.getZoom();

    for( 0..N )| i |
    {
      const angle = def.TAU * @as( f32, @floatFromInt( i + 1 )) / @as( f32, @floatFromInt( N ));

      p2 = p1;
      p1 = self.getRelPosAtAngle( angle );

      def.drawLine( orbiteePos.add( p1 ), orbiteePos.add( p2 ), .green, zoomedWidth );
    }
  }

  pub fn renderLPs( self : *const OrbitComp, orbiteePos : Vec2, orbiterMass : f32 ) void
  {
    const zoomedWidth = 1.0 / def.G_NG.camera.getZoom();

    for( 1..6 )| i |
    {
      const pos = self.getLagrangePos( orbiteePos, orbiterMass, @intCast( i ));

      def.drawPoly( pos, Vec2.new( 1, 1 ).mulVal( zoomedWidth * 4 ), .{}, .red, def.G_ST.Graphic_Ellipse_Facets );
    }
  }


  pub fn getLagrangePos( self : *const OrbitComp, orbiteePos : Vec2, orbiterMass : f32, L : u4 ) Vec2
  {
    const massRatio  = orbiterMass / ( self.orbitedMass + orbiterMass );

    // Radial vector from orbitee to orbiter
    const rel = self.getRelPos();

    var lagPos : Vec2 = .{};

    switch( L )
    {
      // ======== Collinear points ========
      1 => { lagPos = rel.mulVal( 1.0 - self.getHillFactor( massRatio )); }, // Between the orbitee and orbiter
      2 => { lagPos = rel.mulVal( 1.0 + self.getHillFactor( massRatio )); }, // Behind  the orbiter
      3 => { lagPos = rel.mulVal(       self.getL3Factor(   massRatio )); }, // Behind  the orbitee

      // ======== Triangular points with elliptic correction ========
      4 => { lagPos = self.getTrojanLagPos(  1.0 ); }, // ~60° +/- 25° ahead of orbiter
      5 => { lagPos = self.getTrojanLagPos( -1.0 ); }, // ~60° +/- 25° behind of orbiter

      else =>
      {
        def.qlog( .ERROR, 0, @src(), "Trying to access innexistant Lagrange's position" );
        return .{};
      },
    }

    return orbiteePos.add( lagPos );
  }

  inline fn getHillFactor( self : *const OrbitComp, massRatio : f32 ) f32
  {
    _ = self;
    return std.math.cbrt( massRatio / 3.0 ) ;
  }

  inline fn getL3Factor( self : *const OrbitComp, massRatio : f32 ) f32
  {
    // Approx distance ~ r * ( 1 + ( 5μ / 12 ))
    _ = self;
    return -( 1.0 + ( 5.0 * massRatio / 12.0 ));
  }

  inline fn getTrojanLagPos( self: *const OrbitComp, sign : f32 ) Vec2
  {
    const e = self.getEccentricity();
    const t = self.angularPos;

    // First-order libration correction
    const dt = ( 2.0 / 3.0 ) * e * @sin( t );
    const lagAngle = t + sign * ( def.PI / 3.0 ) + dt;

    return self.getRelPosAtAngle( lagAngle );
  }
};

