const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

const Vec2     = utl.Vec2;
const Angle    = utl.Angle;
const EntityId = eng.EntityId;


const gbl = @import( "../gameGlobals.zig" );
const gdf = @import( "../gameDef.zig" );

const ecn = gdf.econ;


pub const OrbitComp = struct
{
  pub const compStorePolicy : eng.CompStorePolicy = .PACKED;

  pub inline fn StoreType() type { return eng.CompStoreFactory( @This() ); }

  const G : f64 = gdf.G_CONSTS.gravFactor;
  const N : u32 = 256; // number of segments used to render orbital path

  // Orbit's masses ( ought to be near-constant )
  orbitedMass : f64 = 100.0, // mass of whatever self orbits
  orbiterMass : f64 = 100.0, // mass of self

  // Min/Max radius approach
  minRadius   : f64 = 200.0, // Periapsis (closest)
  maxRadius   : f64 = 600.0, // Apoapsis  (farthest)

  // Eccentricity and Procession direction
  orientation : Angle = .{},   // Periapsis angle ( 0 => +X )
  retrograde  : bool  = false, // If the orbit is counter-clockwise visually ( clockwise mathematically )

  // Current position
  angularPos : Angle = .{}, // Current position along orbit ( 0 => +X )
  angularVel : f64   = 0.0,

  // Other metrics
  period  : f64        = 0.0, // how many days to complete a full orbit around its path
  pathCol : utl.Colour = gdf.G_CONSTS.textColour,

  pub fn initFromParams(
    orbitedMass : f64,  orbiterMass : f64,
    minRadius   : f64,  maxRadius   : f64,
    orientation : f64,  periodOvrd  : ?f64, // If null, period is calculated from masses and orbit shape
    pathColour : utl.Colour
  ) OrbitComp
  {
    var self = OrbitComp
    {
      .orbitedMass = orbitedMass,
      .orbiterMass = orbiterMass,
      .minRadius   = minRadius,
      .maxRadius   = maxRadius,
      .orientation = .newRad( orientation ),
      .period      = 0.0,
      .pathCol     = pathColour
    };

    if( periodOvrd )| p |
    {
      self.period = p; // Use provided period
    }
    else
    {
      self.setPeriodFromMass();
    }

    self.angularVel = self.getAngularVel();

    return self;
  }


  /// Calculates mu ( standard gravitational parameter )
  pub inline fn getGravParam( self : *const OrbitComp ) f64
  {
    return G * ( self.orbitedMass + self.orbiterMass );
  }
  pub inline fn getOrbitalEnergy( self : *const OrbitComp ) f64
  {
    const mu = self.getGravParam();
    const a  = self.getSemiMajor();

    return -mu / ( 2.0 * a );
  }
  pub inline fn getGravWellEnergy( self : *const OrbitComp ) f64
  {
    const mu = self.getGravParam();
    const hr = self.getHillRadius();

    return -mu / ( 2.0 * hr );
  }


  pub inline fn getSemiMajor( self : *const OrbitComp ) f64
  {
    return ( self.maxRadius + self.minRadius ) / 2.0;
  }
  pub inline fn getSemiMinor( self : *const OrbitComp ) f64
  {
    const  a = self.getSemiMajor();
    const  e = self.getEccentricity();
    return a * @sqrt( 1.0 - ( e * e ));
  }
  pub inline fn getEccentricity( self : *const OrbitComp ) f64
  {
    // Clamping avoids some high eccentricity math issues
    return utl.clmp(( self.maxRadius - self.minRadius ) / ( self.maxRadius + self.minRadius ), 0.0, 0.999 );
  }


  pub inline fn setPeriodFromMass( self : *OrbitComp ) void
  {
    const semiMajor = self.getSemiMajor();

    if( semiMajor < 1.0 )
    {
      utl.qlog( .WARN, @src(), "Unable to calculate period : semi major axis too small" );
      return;
    }

    const semiMajor3 = semiMajor * semiMajor * semiMajor;

    self.period = @floatCast( utl.TAU * @sqrt( semiMajor3 / self.getGravParam() ));
  }

  pub inline fn getCurrentRadius( self : *const OrbitComp ) f64
  {
    return self.getRadiusAtAngle( self.angularPos );
  }
  pub inline fn getRadiusAtAngle( self : *const OrbitComp, angle : Angle ) f64
  {
    const e = self.getEccentricity();
    const eSqr = e * e;

    // Orbital radius formula: r = a( 1 - e² ) / ( 1 + e·cos(θ) )
    const numer = self.getSemiMajor() * ( 1.0 - ( eSqr ));
    const denom = 1.0 + ( e * angle.cos() );

    return numer / denom;
  }


  // Orbital period depends on semi-major axis and central mass ( Kepler's 3rd Law )
  // T² ∝ a³/M  →  ω = √(GM/a³)
  pub inline fn getMeanAngularVel( self : *const OrbitComp ) f64 // AKA mean motion
  {
    // Prevent division by zero / very small values
    if( self.period < 1.0 ){ return 0.0; }

    // ω = 2π / T
    const meanAngVel = utl.TAU / self.period;

    return switch( self.retrograde ) // negative angularVel == retrograde orbits
    {
      false => @floatCast(  meanAngVel ),
      true  => @floatCast( -meanAngVel ),
    };
  }

  // True angular velocity varies with angular position ( Kepler's 2nd Law )
  // ω_true = ω_mean * ( 1 + e·cos(θ) )² / ( 1 - e² )^( 3/2 )
  pub inline fn getAngularVel( self : *const OrbitComp ) f64
  {
    const meanAngVel = self.getMeanAngularVel();

    const ecc    = self.getEccentricity();
    const eccSqr = ecc * ecc;

    const numerRoot = 1.0 + ( ecc * self.angularPos.cos() );
    const denom     = ( 1.0 - eccSqr ) * @sqrt( 1.0 - eccSqr );

    const ratio : f64 = @floatCast(( numerRoot * numerRoot ) / denom );

    return meanAngVel * ratio;
  }


  pub inline fn getPeriapsisRelPos( self : *const OrbitComp ) Vec2
  {
    return self.getRelPosAtAngle( .{} );
  }
  pub inline fn getApoapsisRelPos( self : *const OrbitComp  ) Vec2
  {
    return self.getRelPosAtAngle( .newRad( utl.PI ) );
  }

  // Orbital ellipse's orientation
  pub inline fn getApsidesVec( self : *const OrbitComp ) Vec2
  {
    return self.getRelPosAtAngle( .newRad( utl.PI ) ).sub( self.getRelPosAtAngle( .{} ));
  }

  pub inline fn getOrbitLen( self : *const OrbitComp ) f64
  {
    const a = self.getSemiMajor(); // TODO : check if these need doubling
    const b = self.getSemiMinor();

    return utl.Shape2D.ELLI.getPerim( .new( a, b ));
  }

  // Calculates the position of a given economy
  pub inline fn getEconAbsPos( self : *const OrbitComp, orbitedPos : Vec2, econLoc : ecn.EconLoc ) Vec2
  {
    switch( econLoc )
    {
      .GROUND, .ORBIT => return self.getAbsPos(   orbitedPos ),
      else            => return self.getAbsLpPos( orbitedPos, econLoc.toLagrange() ),
    }
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
  pub inline fn getRelPosAtAngle( self : *const OrbitComp, angle : Angle ) Vec2
  {
    const radius = self.getRadiusAtAngle( angle );

    // Position in orbit space ( 0° => along +X )
    const x = radius * angle.cos();
    const y = radius * angle.sin();

    // Return the position after rotating it appropriately
    return Vec2.new( x, y ).rot( self.orientation );
  }


  // Calculate the orbiter's velocity
  pub inline fn getAbsVel( self : *const OrbitComp, orbitedVel : Vec2 ) Vec2
  {
    return orbitedVel.add( self.getRelVel() );
  }
  pub inline fn getRelVel( self : *const OrbitComp ) Vec2
  {
    const ecc = self.getEccentricity();

    // Radial velocity component
    // v_r = ( a * e * sin( θ ) * meanMotion ) / sqrt( 1 - e^2 )
    const velRad = self.getSemiMajor() * ecc * self.angularPos.sin() * self.getMeanAngularVel() / @sqrt( 1.0 - ecc * ecc );

    // Tangential velocity component
    const velTan = self.angularVel * self.getCurrentRadius();

    // Convert to Cartesian vectors
    const vecRad = Vec2.fromAngle( self.angularPos ).mulVal( velRad );
    const vecTan = Vec2.fromAngle( self.angularPos.addRad( utl.PI / 2.0 )).mulVal( velTan );

    // Rotate by orbit orientation
    return vecRad.add( vecTan ).rot( self.orientation );
  }


  pub fn updateOrbit( self : *OrbitComp, selfTrans : *eng.TransComp, otherTrans : *const eng.TransComp, stepCount : u64 ) void
  {
    if( stepCount == 0 ){ return; }

    for( 0..stepCount )| _ |
    {
      self.angularPos = self.angularPos.addRad( self.angularVel );

      // NOTE : Be careful about update ordering, as angular vel is cached for reuse in getAbsVel()
      self.angularVel = self.getAngularVel(); // negative angularVel == retrograde orbits
    }

    selfTrans.pos = self.getAbsPos( otherTrans.pos.toVec2() ).toVecA( selfTrans.pos.a );
    selfTrans.vel = self.getAbsVel( otherTrans.vel.toVec2() ).toVecA( selfTrans.vel.a );
    selfTrans.acc = .{}; // Acceleration is to be ignored for orbiting objetcs, as they have predefined paths anyways

    // TODO : output desired pos and vel instead, so that it can be further modified afterhand
  }


  // ================================ RENDERING ================================

  pub fn renderDebug( self : *const OrbitComp, orbitedVel : Vec2, orbitedPos : Vec2, selfPos : Vec2, selfRadius : f64, moonDensity : f64 ) void
  {
    const scaledAbsVel = self.getAbsVel( orbitedVel ).normToLen( selfRadius * 3.0 );
    const scaledRelVel = self.getRelVel(            ).normToLen( selfRadius * 3.0 );
    const zoomedWidth  = 1.0 / eng.G_ENG.camera.getZoom();


    eng.wDraw.basicLine( selfPos, selfPos.add( scaledAbsVel ), .blue, zoomedWidth * 2.0 ); // Velocity Vector ( absolute )
    eng.wDraw.basicLine( selfPos, selfPos.add( scaledRelVel ), .red,  zoomedWidth * 2.0 ); // Velocity Vector ( relative )

    const minRad = self.getHillRadius();
    const maxRad = self.getRocheLimit( selfRadius, moonDensity, 0.25 ); // Assumes a near-solid moon

    if( minRad > maxRad ) // Do not draw these if the space the bound is inverted ( stable moon orbit possible )
    {
      var vecMin1 : Vec2 = .new( minRad, 0 );
      var vecMax1 : Vec2 = .new( maxRad, 0 );

      var vecMin2 : Vec2 = vecMin1;
      var vecMax2 : Vec2 = vecMax1;

      const a = Angle.newRad( utl.TAU / @as( f64, @floatFromInt( N )));

      for( 0..N )| _ | // Moon friendly region ( Disk )
      {
        vecMin2 = vecMin1;
        vecMax2 = vecMax1;

        vecMin1 = vecMin1.rot( a );
        vecMax1 = vecMax1.rot( a );

        eng.wDraw.basicLine( selfPos.add( vecMin2 ), selfPos.add( vecMin1 ), .red,    zoomedWidth );
        eng.wDraw.basicLine( selfPos.add( vecMax2 ), selfPos.add( vecMax1 ), .yellow, zoomedWidth );
      }
    }

    eng.wDraw.hexa( orbitedPos.add( self.getPeriapsisRelPos() ), Vec2.new( 1, 1 ).mulVal( zoomedWidth * 4.0 ), .{}, .orange );
    eng.wDraw.hexa( orbitedPos.add( self.getApoapsisRelPos()  ), Vec2.new( 1, 1 ).mulVal( zoomedWidth * 4.0 ), .{}, .purple );
  }

  pub fn renderPath( self : *const OrbitComp, orbitedPos : Vec2 ) void
  {
    var p1 : Vec2 = self.getRelPosAtAngle( self.angularPos );
    var p2 : Vec2 = p1;

    const pathLenFactor : f64 = utl.clmp( gdf.G_CONSTS.orbitPathLenFactor, 0.0, 1.0 );

    var doDraw : bool = ( pathLenFactor > utl.EPS );

    if( !doDraw ){ return; }

    const zoomedWidth : f64 = 1.0 / eng.G_ENG.camera.getZoom();
    const N_f         : f64 = @floatFromInt( N );
    const ecc         : f64 = self.getEccentricity();
    const semiMajor   : f64 = self.getSemiMajor();

    var  baseStep : f64 = @floatCast( utl.TAU / N_f );
    const maxStep : f64 = baseStep * 4.00; // Prevents huge jumps near periapsis
    const minStep : f64 = baseStep * 0.25; // Prevents tiny crawl near apoapsis

    var pathCol = self.pathCol;

    // Checking for non-circular orbits
    if( ecc > 0.3 )
    {
      // Correction factor: the mean of ( r/a )² over a full orbit is ( 1-e² )^( 3/2 )
      // Multiplying by this ensures N adaptive steps still sum to ~TAU;
      const oneMinusE2  = 1.0 - ( ecc * ecc );

      baseStep *= oneMinusE2 * @sqrt( oneMinusE2 );
    }

    const maxLen : f64 = self.getOrbitLen() * pathLenFactor;
    var   sumLen : f64 = 0.0;

    var drawAngle : Angle = self.angularPos;
    var sumAngle  : f64 = 0.0;

    var  step : f64 = baseStep;
    const dir : f64 = if( self.retrograde ) 1.0 else -1.0;

    while( doDraw )
    {
      // Checking for non-circular orbits
      if( ecc > 0.3 )
      {
        // Scales step by (r/a)² meaning :
        // larger  radius -> smaller steps
        // smaller radius -> larger  steps
        const ratio = self.getRadiusAtAngle( drawAngle ) / semiMajor;

        step = baseStep / ( ratio * ratio );
        step = utl.clmp( step, minStep, maxStep );
      }

      sumAngle += step;

      if( sumAngle >= utl.TAU ) // Prevent doubling pathlines
      {
        drawAngle  = self.angularPos;
        doDraw     = false;
      }
      else
      {
        drawAngle = drawAngle.addRad( step * dir );
      }

      p2 = p1;
      p1 = self.getRelPosAtAngle( drawAngle );

      eng.wDraw.basicLine( orbitedPos.add( p1 ), orbitedPos.add( p2 ), pathCol, zoomedWidth );

      pathCol = pathCol.subA( gdf.G_CONSTS.orbitFadeStrength ); // Fading-out path's alpha

      if( pathCol.a == 0 ){ break; }

      if( pathLenFactor < 1.0 - utl.EPS )
      {
        sumLen += p1.getDist( p2 );
        if( sumLen >= maxLen ){ break; }
      }
    }
  }

  pub fn renderLPs( self : *const OrbitComp, orbitedPos : Vec2, maxLP : usize ) void
  {
    const zoomedWidth = 1.0 / eng.G_ENG.camera.getZoom();

    const LPcount = @min( 5, maxLP ) + 1;

    if( LPcount != maxLP + 1 )
    {
      utl.qlog( .WARN, @src(), "Trying to render inexistant LP : ignoring" );
    }

    for( 1..LPcount )| i |
    {
      const pos = self.getAbsLpPos( orbitedPos, @intCast( i ));

      eng.wDraw.hexa( pos, Vec2.new( 1, 1 ).mulVal( zoomedWidth * 3.0 ), .{}, .red );
    }
  }


  // ================================ LAGRANGE & HILL MATHS ================================

  inline fn getHillFactor( self : *const OrbitComp ) f64 { return @floatCast( utl.cbrt( self.orbiterMass / ( 3.0 * self.orbitedMass ))); }

  inline fn getL3Factor( self : *const OrbitComp ) f64
  {
    // Approx distance ~ r * ( 1 + ( 5μ / 12 ))
    const mu = self.getGravParam();

    return -( 1.0 + ( 5.0 * mu / 12.0 ));
  }

  // TODO : make sure this works properly
  inline fn getTrojanLagPos( self: *const OrbitComp, sign : f64 ) Vec2
  {
    const e = self.getEccentricity();
    const t = self.angularPos;

    // First-order libration correction
    const dt = ( 2.0 / 3.0 ) * e * t.sin();
    const lagAngle = t.addRad(( sign * utl.PI / 3.0 ) + dt );

    return self.getRelPosAtAngle( lagAngle );
  }

  pub inline fn getAbsLpPos( self : *const OrbitComp, orbitedPos : Vec2, L : u4 ) Vec2
  {
    return orbitedPos.add( self.getRelLpPos( L ));
  }

  pub fn getRelLpPos( self : *const OrbitComp, L : u4 ) Vec2
  {
    // Radial vector from orbited to orbiter
    const rel = self.getRelPos();

    var lagPos : Vec2 = .{};

    switch( L )
    {
      // ======== Collinear points ========
      1 => { lagPos = rel.mulVal( 1.0 - self.getHillFactor()); }, // Between the orbited and orbiter
      2 => { lagPos = rel.mulVal( 1.0 + self.getHillFactor()); }, // Behind  the orbiter
      3 => { lagPos = rel.mulVal(       self.getL3Factor());   }, // Behind  the orbited

      // ======== Triangular points with elliptic correction ========
      4 => { lagPos = self.getTrojanLagPos(  1.0 ); }, // ~60° +/- 25° ahead of orbiter
      5 => { lagPos = self.getTrojanLagPos( -1.0 ); }, // ~60° +/- 25° behind of orbiter

      else =>
      {
        utl.qlog( .ERROR, @src(), "Trying to access inexistant LP's position : returning 0:0" );
        return .{};
      },
    }

    return lagPos;
  }


  // NOTE : rough radius at which the principal gravitational source swaps from this body to its parent body
  pub inline fn getHillRadius( self : *const OrbitComp ) f64 { return self.getSemiMajor() * self.getHillFactor(); }

  /// moonRigidity  : 1.0 = fluid, 0.0 = rigid
  /// selfRadius    = planet radius
  /// density ratio = planetDensity / moonDensity
  pub inline fn getRocheLimit( self: *const OrbitComp, selfRadius : f64, moonDensity : f64, moonRigidity : f64 ) f64
  {
    const volume = ( 4.0 / 3.0 ) * utl.PI * ( selfRadius * selfRadius * selfRadius );
    const densityRatio = ( self.orbiterMass / volume ) / moonDensity;

    const FLUID: f64 = 2.44;
    const RIGID: f64 = 1.26;

    const rigidity = utl.lerp( RIGID, FLUID, moonRigidity );

    return selfRadius * rigidity * utl.cbrt( densityRatio );
  }

  pub inline fn getMaxMoonOrbitRadius( self : *const OrbitComp ) f64 { return 0.5 * self.getHillRadius(); } // Larger is unstable

  /// arghs : planetRadius, moon density, moonRigidity
  pub inline fn getMinMoonOrbitRadius( self : *const OrbitComp, p_r : f64, den : f64, rig : f64 ) f64 { return 1.2 * self.getRocheLimit( p_r, den, rig ); } // Smaller is unstable
};
