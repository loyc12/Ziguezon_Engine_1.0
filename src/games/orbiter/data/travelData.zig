const std = @import( "std"  );
const eng = @import( "engine" );
const utl = @import( "utils" );

const Vec2 = utl.Vec2;
const Angle = utl.Angle;


const gbl = @import( "../gameGlobals.zig" );
const gdf = @import( "../gameDef.zig"    );

const bdy = gdf.bdy;

const BodyName = gdf.BodyName;
const EconLoc  = gdf.EconLoc;


// ================================ COMPOSITE PAIR ENUM ================================
//  Generates a unique enum for every ( BodyName - EconLoc ) pair.

pub const BodyEconPair  = utl.GenPairedEnum( BodyName, EconLoc );
pub const BodyEconSplit = utl.GenSplitEnum(  BodyName, EconLoc );


//  Combine BodyName & EconLoc into the corresponding composite enum
pub fn toBodyEconPair( body : BodyName, econ : EconLoc ) BodyEconPair
{
  return utl.pairEnums( BodyName, body, EconLoc, econ );
}

//  Extract BodyName & EconLoc from the corresponding composite enum
pub fn fromBodyEconPair( pair : BodyEconPair ) BodyEconSplit
{
  return utl.splitEnums( BodyName, EconLoc, pair );
}

pub inline fn debugLogTravelCosts( departure : gdf.BodyEconPair, arrival : gdf.BodyEconPair ) void
{
  const tData1 = gdf.trvlSlvr.estimateTransferPair( departure, arrival );
  utl.log( .CONT, 0, @src(), "{s} > {s}\t: {d:.3} km/s\t| {d:.2} days\t| {d:.1} dE",  .{ @tagName( departure ), @tagName( arrival ), tData1.deltaV, tData1.deltaT, tData1.deltaE });

  const tData2 = gdf.trvlSlvr.estimateTransferPair( arrival, departure );
  utl.log( .CONT, 0, @src(), "{s} < {s}\t: {d:.3} km/s\t| {d:.2} days\t| {d:.1} dE\n", .{ @tagName( departure ), @tagName( arrival ), tData2.deltaV, tData2.deltaT, tData2.deltaE });
}

pub inline fn debugLogTravelCostsList( body : gdf.BodyName, loc : gdf.EconLoc ) void
{
  utl.qlog( .INFO, 0, @src(), "& Logging travel metrics :\n" );

  const departure = gdf.toBodyEconPair( body, loc );

  inline for( 0..EconLoc.count )| l |
  {
    const loc2 = EconLoc.fromIdx( l );

    if( loc2 != loc )
    {
      gdf.debugLogTravelCosts( departure, gdf.toBodyEconPair( body, loc2 ));
    }
  }
  utl.qlog( .CONT, 0, @src(), "----------------------------------------------------------------\n" );

  for( gdf.bodyOrder )| body2 |
  {
    if( body2 != body and body2 != gdf.G_CONSTS.starBody )
    {
      gdf.debugLogTravelCosts( departure, gdf.toBodyEconPair( body2, loc ));
    }
  }
}


// ================================ TRADE DATA SNAPSHOT ================================

pub const OrbitalData = struct // NOTE : invalid if orbitLvl < EPS
{
  orbitLvl : f64  = 0.0, // 1 / root( distFromSun )
  angPos   : Angle = .{}, // Current angle relative to the reference plane ( centered on sun )
  angVel   : f64  = 0.0, // Instantanious angular speed ( - == counter-clockwise )
  radVel   : f64  = 0.0, // Instantanious radial  speed ( - == towards the sun )
};

pub const TravelData = struct // NOTE : invalid if deltaV < EPS
{
  deltaE : f64 = 0.0, // Approximate specific energy cost in km^2 / min^2.
  deltaV : f64 = 0.0, // Approximate transfer cost in km/s.
  deltaT : f64 = 0.0, // Approximate travel time in days.
};


// Most recent positional data for any econ
pub var econOrbitalData : utl.GenDataLine( OrbitalData, BodyEconPair ) = .{};

/// Also updates econ's sunshine value
pub fn updateOrbitalDataEntry( bodyComp : *bdy.BodyComp, loc : gdf.EconLoc, bodyPos : Vec2, bodyVel : Vec2, starPos : Vec2 ) void
{
  // TODO : get precise pos and vel for L1-L5 points instead of using orbiter's
  const econPos = bodyPos;
  const econVel = bodyVel;

  const distSqr = econPos.getDistSqr( starPos );

  var data : gdf.OrbitalData = .{};

  // TODO : rework calculation to have more accurate values
  if( distSqr > utl.EPS )
  {
    const dist    = @sqrt( distSqr );
    data.orbitLvl = 1.0 / @sqrt( dist );

    // Angular position relative to star
    const delta = econPos.sub( starPos );
    data.angPos = delta.toAngle();

    // Angular velocity : v_tangential / r
    // Tangential component = perpendicular to radial direction
    const radDir = delta.mulVal( 1.0 / dist );
    const tanVel = ( econVel.y * radDir.x ) - ( econVel.x * radDir.y );
    data.angVel  = ( tanVel / dist );

    // Radial velocity
    data.radVel = econVel.dot( radDir );

    // Also updating sunshine for econ
    bodyComp.getEcon( loc ).sunshine = gbl.SUNSHINE.getShineAt( distSqr );
  }

  gbl.ECON_ORBIT_DATA.set( gdf.toBodyEconPair( bodyComp.name, loc ), data );
}
