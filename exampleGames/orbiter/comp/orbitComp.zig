const std = @import( "std" );
const def = @import( "defs" );

const Vec2 = def.Vec2;


const gbl = @import( "../gameGlobals.zig" );
const gdf = @import( "../gameDefs.zig" );

const ecn = gdf.econ;


pub const OrbitComp = struct
{
  pub inline fn getStoreType() type { return def.componentStoreFactory( @This() ); }

  const G : f64 = gdf.G_CONSTS.gravFactor;
  const N : u32 = 256; // number of segments used to render orbital path

  orbitedID : def.EntityId = 1, // 1 is the sun by default

  // Orbit's masses ( ought to be near-constant )
  orbitedMass : f64 = 100.0, // mass of whatever self orbits
  orbiterMass : f64 = 100.0, // mass of self

  // Min/Max radius approach
  minRadius : f64 = 200.0, // Periapsis (closest)
  maxRadius : f64 = 600.0, // Apoapsis  (farthest)

  // Eccentricity and Procession direction
  orientation : f32  = 0.0,   // Periapsis angle ( 0 to 2π, 0 => +X )
  retrograde  : bool = false, // If the orbit is counter-clockwise visually ( clockwise mathematically )

  // Current position
  angularPos : f32 = 0.0, // Current position along orbit ( 0 to 2π, 0 => +X )
  angularVel : f32 = 0.0,

  // Other metrics
  period : f32 = 0.0, // how many days to complete a full orbit around its path

  pub fn initFromParams(
    orbitedMass : f64,  orbiterMass : f64,
    minRadius   : f64,  maxRadius   : f64,
    orientation : f64,  periodOvrd  : ?f32, // If null, period is calculated from masses and orbit shape
  ) OrbitComp
  {
    var self = OrbitComp
    {
      .orbitedMass = orbitedMass,
      .orbiterMass = orbiterMass,
      .minRadius   = minRadius,
      .maxRadius   = maxRadius,
      .orientation = @floatCast( orientation ),
      .period      = 0.0,
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
    return def.clmp(( self.maxRadius - self.minRadius ) / ( self.maxRadius + self.minRadius ), 0.0, 0.999 );
  }

  pub inline fn setPeriodFromMass( self : *OrbitComp ) void
  {
    const semiMajor = self.getSemiMajor();

    if( semiMajor < 1.0 )
    {
      def.qlog( .WARN, 0, @src(), "Unable to calculate period : semi major axis too small" );
      return;
    }

    const semiMajor3 = semiMajor * semiMajor * semiMajor;
    const totalMass  = self.orbitedMass + self.orbiterMass;

    self.period = @floatCast( def.TAU * @sqrt( semiMajor3 / ( G * totalMass )));
  }

  pub inline fn getCurrentRadius( self : *const OrbitComp ) f64
  {
    return self.getRadiusAtAngle( self.angularPos );
  }
  pub inline fn getRadiusAtAngle( self : *const OrbitComp, angle : f32 ) f64
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
  pub inline fn getMeanAngularVel( self : *const OrbitComp ) f32 // AKA mean motion
  {
    // Prevent division by zero / very small values
    if( self.period < 1.0 ){ return 0.0; }

    // ω = 2π / T
    const meanAngVel = def.TAU / self.period;

    return switch( self.retrograde ) // negative angularVel == retrograde orbits
    {
      false => @floatCast(  meanAngVel ),
      true  => @floatCast( -meanAngVel ),
    };
  }

  // True angular velocity varies with angular position ( Kepler's 2nd Law )
  // ω_true = ω_mean * ( 1 + e·cos(θ) )² / ( 1 - e² )^( 3/2 )
  pub inline fn getAngularVel( self : *const OrbitComp ) f32
  {
    const meanAngVel = self.getMeanAngularVel();

    const ecc    = self.getEccentricity();
    const eccSqr = ecc * ecc;

    const numerRoot = 1.0 + ( ecc * @cos( self.angularPos ));
    const denom     = ( 1.0 - eccSqr ) * @sqrt( 1.0 - eccSqr );

    const ratio : f32 = @floatCast(( numerRoot * numerRoot ) / denom );

    return meanAngVel * ratio;
  }


  pub inline fn getPeriapsisRelPos( self : *const OrbitComp ) Vec2
  {
    return self.getRelPosAtAngle( 0 );
  }
  pub inline fn getApoapsisRelPos( self : *const OrbitComp  ) Vec2
  {
    return self.getRelPosAtAngle( def.PI );
  }

  // Orbital ellipse's orientation
  pub inline fn getApsidesVec( self : *const OrbitComp ) Vec2
  {
    return self.getRelPosAtAngle( def.PI ).sub( self.getRelPosAtAngle( 0 ));
  }

  pub inline fn getOrbitLen( self : *const OrbitComp ) f64
  {
    const a : f32 = @floatCast( self.getSemiMajor() );
    const b : f32 = @floatCast( self.getSemiMinor() );

    return def.Shape2D.ELLI.getPerim( .new( a, b ));
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
    const ecc = self.getEccentricity();

    // Radial velocity component
    // v_r = ( a * e * sin( θ ) * meanMotion ) / sqrt( 1 - e^2 )
    const velRad = self.getSemiMajor() * ecc * @sin( self.angularPos ) * self.getMeanAngularVel() / @sqrt( 1.0 - ecc * ecc );

    // Tangential velocity component
    const velTan = self.angularVel * self.getCurrentRadius();

    // Convert to Cartesian vectors
    const vecRad = Vec2.fromAngle(.{ .r = self.angularPos }).mulVal( velRad );
    const vecTan = Vec2.fromAngle(.{ .r = self.angularPos + def.PI / 2.0 }).mulVal( velTan );

    // Rotate by orbit orientation
    return vecRad.add( vecTan ).rot(.{ .r = self.orientation });
  }


  pub fn updateOrbit( self : *OrbitComp, selfTrans : *def.TransComp, otherTrans : *const def.TransComp, stepCount : u64 ) void
  {
    if( stepCount == 0 ){ return; }

    for( 0..stepCount )| _ |
    {
      self.angularPos += self.angularVel;

      // Wrap to 0-2π ( handles both positive and negative )
      self.angularPos = def.wrap( self.angularPos, 0.0, def.TAU );

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
    const zoomedWidth  = 1.0 / def.G_CAM.getZoom();


    def.drawLine( selfPos, selfPos.add( scaledAbsVel ), .blue, @floatCast( zoomedWidth * 2.0 )); // Velocity Vector ( absolute )
    def.drawLine( selfPos, selfPos.add( scaledRelVel ), .red,  @floatCast( zoomedWidth * 2.0 )); // Velocity Vector ( relative )

    const minRad = self.getHillRadius();
    const maxRad = self.getRocheLimit( selfRadius, moonDensity, 0.2 ); // Assumes a near-solid moon

    var vecMin1 : Vec2 = .new( minRad, 0 );
    var vecMax1 : Vec2 = .new( maxRad, 0 );

    var vecMin2 : Vec2 = vecMin1;
    var vecMax2 : Vec2 = vecMax1;

    const a = def.TAU / @as( f32, @floatFromInt( N ));

    for( 0..N )| _ | // Moon friendly region ( Disk )
    {
      vecMin2 = vecMin1;
      vecMax2 = vecMax1;

      vecMin1 = vecMin1.rot( .{ .r = a });
      vecMax1 = vecMax1.rot( .{ .r = a });

      def.drawLine( selfPos.add( vecMin2 ), selfPos.add( vecMin1 ), .red,    @floatCast( zoomedWidth ));
      def.drawLine( selfPos.add( vecMax2 ), selfPos.add( vecMax1 ), .yellow, @floatCast( zoomedWidth ));
    }

    def.drawHexa( orbitedPos.add( self.getPeriapsisRelPos() ), Vec2.new( 1, 1 ).mulVal( zoomedWidth * 4.0 ), .{}, .orange );
    def.drawHexa( orbitedPos.add( self.getApoapsisRelPos()  ), Vec2.new( 1, 1 ).mulVal( zoomedWidth * 4.0 ), .{}, .purple );
  }

  pub fn renderPath( self : *const OrbitComp, orbitedPos : Vec2 ) void
  {
    var p1 : Vec2 = self.getRelPosAtAngle( self.angularPos );
    var p2 : Vec2 = p1;

    const pathLenFactor : f64 = def.clmp( gdf.G_CONSTS.orbitPathLenFactor, 0.0, 1.0 );

    var doDraw : bool = ( pathLenFactor > def.EPS );

    if( !doDraw ){ return; }

    const zoomedWidth : f64 = 1.0 / def.G_CAM.getZoom();
    const ecc         : f64 = self.getEccentricity();
    const N_f         : f64 = @floatFromInt( N );
    const semiMajor   : f32 = @floatCast( self.getSemiMajor() );

    var  baseStep : f32 = @floatCast( def.TAU / N_f );

    var lineCol : def.Colour = .green;
    const maxStep : f32 = baseStep * 4.00; // Prevents huge jumps near periapsis
    const minStep : f32 = baseStep * 0.25; // Prevents tiny crawl near apoapsis

    // Checking for non-circular orbits
    if( ecc > 0.3 )
    {
      // Correction factor: the mean of ( r/a )² over a full orbit is ( 1-e² )^( 3/2 )
      // Multiplying by this ensures N adaptive steps still sum to ~TAU
      const ecc_f : f32 = @floatCast( ecc );
      const oneMinusE2  = 1.0 - ( ecc_f * ecc_f );

      baseStep *= oneMinusE2 * @sqrt( oneMinusE2 );
      lineCol   = .yellow;
    }

    const maxLen : f64 = self.getOrbitLen() * pathLenFactor;
    var   sumLen : f64 = 0.0;

    var drawAngle : f32 = self.angularPos;
    var sumAngle  : f32 = 0.0;

    var  step : f32 = baseStep;
    const dir : f32 = if( self.retrograde ) 1.0 else -1.0;

    while( doDraw )
    {
      // Checking for non-circular orbits
      if( ecc > 0.3 )
      {
        // Scales step by (r/a)² meaning :
        // larger  radius -> smaller steps
        // smaller radius -> larger  steps
        const r : f32 = @floatCast( self.getRadiusAtAngle( drawAngle ));
        const ratio   = r / semiMajor;

        step = baseStep / ( ratio * ratio );
        step = def.clmp( step, minStep, maxStep );
      }

      sumAngle += step;

      if( sumAngle >= def.TAU ) // Prevent doubling pathlines
      {
        drawAngle  = self.angularPos;
        doDraw     = false;
      }
      else
      {
        drawAngle += step * dir;
      }

      p2 = p1;
      p1 = self.getRelPosAtAngle( drawAngle );

      def.drawLine( orbitedPos.add( p1 ), orbitedPos.add( p2 ), lineCol, @floatCast( zoomedWidth ));

      lineCol = lineCol.subA( gdf.G_CONSTS.orbitFadeStrenght ); // Fading-out path's alpha

      if( lineCol.a == 0 ){ break; }

      if( pathLenFactor < 1.0 - def.EPS )
      {
        sumLen += p1.getDist( p2 );
        if( sumLen >= maxLen ){ break; }
      }
    }
  }

  pub fn renderLPs( self : *const OrbitComp, orbitedPos : Vec2, maxLP : usize ) void
  {
    const zoomedWidth = 1.0 / def.G_CAM.getZoom();

    const LPcount = @min( 5, maxLP ) + 1;

    if( LPcount != maxLP + 1 )
    {
      def.qlog( .WARN, 0, @src(), "Trying to render inexistant LP : ignoring" );
    }

    for( 1..LPcount )| i |
    {
      const pos = self.getAbsLpPos( orbitedPos, @intCast( i ));

      def.drawHexa( pos, Vec2.new( 1, 1 ).mulVal( zoomedWidth * 3.0 ), .{}, .red );
    }
  }


  // ================================ LAGRANGE & HILL MATHS ================================

  inline fn getHillFactor( self : *const OrbitComp ) f64 { return @floatCast( def.cbrt( self.orbiterMass / ( 3.0 * self.orbitedMass ))); }

  inline fn getL3Factor( self : *const OrbitComp ) f64
  {
    // Approx distance ~ r * ( 1 + ( 5μ / 12 ))
    const mu = self.orbiterMass / ( self.orbitedMass + self.orbiterMass );

    return -( 1.0 + ( 5.0 * mu / 12.0 ));
  }

  // TODO : make sure this works properly
  inline fn getTrojanLagPos( self: *const OrbitComp, sign : f64 ) Vec2
  {
    const e = self.getEccentricity();
    const t = self.angularPos;

    // First-order libration correction
    const dt = ( 2.0 / 3.0 ) * e * @as( f64, @floatCast( @sin( t )));
    const lagAngle : f32 = @floatCast( t + ( sign * def.PI / 3.0 ) + dt );

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
        def.qlog( .ERROR, 0, @src(), "Trying to access inexistant LP's position : returning 0:0" );
        return .{};
      },
    }

    return lagPos;
  }


  /// NOTE : radius at which the principal gravitational source swaps from this body to its parent body
  pub inline fn getHillRadius( self : *const OrbitComp ) f64 { return self.getSemiMajor() * self.getHillFactor(); }

  /// moonRigidity  : 1.0 = fluid, 0.0 = rigid
  /// selfRadius    = planet radius
  /// density ratio = planetDensity / moonDensity
  pub inline fn getRocheLimit( self: *const OrbitComp, selfRadius : f64, moonDensity : f64, moonRigidity : f32 ) f64
  {
    const volume = ( 4.0 / 3.0 ) * def.PI * ( selfRadius * selfRadius * selfRadius );
    const densityRatio = ( self.orbiterMass / volume ) / moonDensity;

    const FLUID: f32 = 2.44;
    const RIGID: f32 = 1.26;

    const rigidity : f64 = @floatCast( def.lerp( RIGID, FLUID, moonRigidity ));

    return selfRadius * rigidity * def.cbrt( densityRatio );
  }

  pub inline fn getMaxMoonOrbitRadius( self : *const OrbitComp ) f64 { return 0.5 * self.getHillRadius(); }
  pub inline fn getMinMoonOrbitRadius( self : *const OrbitComp ) f64 { return 1.1 * self.getRocheLimit(); }
};

