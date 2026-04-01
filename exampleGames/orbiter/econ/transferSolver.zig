const std = @import( "std" );
const def = @import( "defs" );
const gbl = @import( "../gameGlobals.zig" );

const trde  = gbl.trde_d;
const OData = gbl.OrbitalData;
const TData = gbl.TravelData;

const BodyEconPair = gbl.BodyEconPair;

const PI  = def.PI;
const TAU = def.TAU;
const EPS = def.EPS;



// ================================ CONFIGURATION ================================

/// Fractional semi-major axis offset for phasing drift orbit.
/// Higher values = faster phase correction but more delta-V.
/// Typical range: 0.01 to 0.10
pub const DEFAULT_EPSILON : f64 = 0.0625;


// ================================ UTILITY ================================

/// Normalize angle to [-π, π]
fn normalizeAngle( angle : f64 ) f64
{
  var a = @mod( angle + PI, TAU );
  if( a < 0.0 ){ a += TAU; }
  return a - PI;
}

/// Clamp a value to a minimum absolute magnitude, preserving sign
fn clampAbs( val : f64, minAbs : f64 ) f64
{
  if( @abs( val ) < minAbs )
  {
    return if( val >= 0.0 ) minAbs else -minAbs;
  }
  return val;
}


// ================================ RADIAL TRANSFER ================================

/// Hohmann-like radial transfer estimate between two orbital radii.
fn computeRadialTransfer( r1 : f64, r2 : f64, mu : f64 ) TData
{
  if( r1 < EPS or r2 < EPS ) return .{};

  // Transfer semi-major axis
  const a_t = 0.5 * ( r1 + r2 );

  // Circular orbital velocities
  const v1 = @sqrt( mu / r1 );
  const v2 = @sqrt( mu / r2 );

  // Transfer orbit velocities at departure and arrival radii   ( 2 x kinetic energy, aka vis-viva )
  const v_t1 = @sqrt( mu * (( 2.0 / r1 ) - ( 1.0 / a_t )));
  const v_t2 = @sqrt( mu * (( 2.0 / r2 ) - ( 1.0 / a_t )));

  // Total delta-V for two burns
  const dv = @abs( v_t1 - v1 ) + @abs( v2 - v_t2 );

  // Transfer time: half the period of the transfer ellipse
  const duration = PI * @sqrt( a_t * a_t * a_t / mu );

  return .{ .deltaV = dv, .duration = duration };
}


// ================================ PHASE TRANSFER ================================

/// Phase alignment estimate via a drift orbit offset.
fn computePhaseTransfer( r : f64, angVel : f64, dTheta : f64, epsilon : f64, mu : f64 ) TData
{
  if( r < EPS ) return .{};

  const absDTheta = @abs( normalizeAngle( dTheta ));

  // If angular separation is negligible, no phase correction needed
  if( absDTheta < 1.0e-6 ) return .{};

  // Drift orbit semi-major axis
  const a_drift = r * ( 1.0 + epsilon );

  // Drift orbit period
  const T_drift = TAU * @sqrt( a_drift * a_drift * a_drift / mu );

  // Angular velocity on drift orbit ( mean motion )
  const omega_drift = TAU / T_drift;

  // Relative drift rate
  const dOmega = omega_drift - @abs( angVel );

  // Guard against near-zero drift rate ( co-orbital case )
  const safeDOmega = clampAbs( dOmega, 1.0e-8 );

  // Phase alignment time
  const t_theta = absDTheta / @abs( safeDOmega );

  // Circular velocity at r
  const v_c = @sqrt( mu / r );

  // Velocity on drift orbit at radius r ( vis-viva )
  const v_d = @sqrt( mu * ( 2.0 / r - 1.0 / a_drift ));

  // Two burns: enter and exit drift orbit
  const dv = 2.0 * @abs( v_d - v_c );

  return .{ .deltaV = dv, .duration = t_theta };
}


// ================================ COMBINED TRANSFER ================================

/// Combine radial and phase estimates via Euclidean norm
fn combineTransfers( radial : TData, phase : TData ) TData
{
  const dv = @sqrt(( radial.deltaV   * radial.deltaV   ) + ( phase.deltaV   * phase.deltaV   ));
  const dt = @sqrt(( radial.duration * radial.duration ) + ( phase.duration * phase.duration ));

  return .{ .deltaV = dv, .duration = dt };
}

/// Compute the full transfer estimate between two orbital snapshots
pub fn estimateTransfer( a : OData, b : OData, epsilon : f64 ) TData
{
  // Gravitational parameter μ = G * M_star ( km³ / Day² )
  const mu = gbl.G_FACTOR * gbl.starCompInst.mass;

  // Recover radii from orbitLvl = 1 / sqrt(r)  =>  r = 1 / orbitLvl²
  const r_a = if( @abs( a.orbitLvl ) > EPS ) 1.0 / ( a.orbitLvl * a.orbitLvl ) else 0.0;
  const r_b = if( @abs( b.orbitLvl ) > EPS ) 1.0 / ( b.orbitLvl * b.orbitLvl ) else 0.0;

  if( r_a < EPS or r_b < EPS ) return .{};

  // Radial component ( moving away / towards the star )
  const radial = computeRadialTransfer( r_a, r_b, mu );

  // Phase component ( moving around the star faster/slower than the orbit suggests )
  // evaluated at the mean radius, using departure angVel
  const r_mean  = 0.5 * ( r_a + r_b );
  const dTheta  = b.angPos - a.angPos;
  const angVelA = if( @abs( a.angVel ) > EPS ) a.angVel else b.angVel; // NOTE : Why this fallback exactly ?
  const phase   = computePhaseTransfer( r_mean, angVelA, dTheta, epsilon, mu );

  return combineTransfers( radial, phase );
}


// ================================ TABLE UPDATE ================================

pub fn isOrbitalDataValid( data : OData ) bool
{
  // orbitLvl == 0 means no data for that node
  return( @abs( data.orbitLvl ) >= EPS ); // NOTE : Is the absolute even needed ?
}

/// Update the entire econTravelTable from the current econOrbitalData.
pub fn updateTravelTable() void
{
  const pairCount = @typeInfo( BodyEconPair ).@"enum".fields.len;

  for( 0..pairCount )| i |
  {
    const pairA : BodyEconPair = @enumFromInt( i );
    const dataA = gbl.ECON_ORBIT_DATA.get( pairA );


    if( !isOrbitalDataValid( dataA )) continue;

    for( 0..pairCount )| j |
    {
      if( i == j )
      {
        gbl.ECON_TRAVEL_TABLE.set( pairA, pairA, .{} );
        continue;
      }

      const pairB : BodyEconPair = @enumFromInt( j );
      const dataB = gbl.ECON_ORBIT_DATA.get( pairB );

      if( !isOrbitalDataValid( dataB ))
      {
        gbl.ECON_TRAVEL_TABLE.set( pairA, pairB, .{} );
        continue;
      }

      const result = estimateTransfer( dataA, dataB, DEFAULT_EPSILON );
      gbl.ECON_TRAVEL_TABLE.set( pairA, pairB, result );
    }
  }
}