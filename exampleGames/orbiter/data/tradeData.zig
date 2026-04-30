const std = @import( "std"  );
const def = @import( "defs" );

const Vec2 = def.Vec2;


const gbl = @import( "../gameGlobals.zig" );
const gdf = @import( "../gameDefs.zig"    );

const bdy = gdf.bdy;

const BodyName = gdf.BodyName;
const EconLoc  = gdf.EconLoc;


// ================================ COMPOSITE PAIR ENUM ================================
//  Generates a unique enum for every ( BodyName - EconLoc ) pair.

pub const BodyEconPair  = def.GenPairedEnum( BodyName, EconLoc );
pub const BodyEconSplit = def.GenSplitEnum(  BodyName, EconLoc );


//  Combine BodyName & EconLoc into the corresponding composite enum
pub fn toBodyEconPair( body : BodyName, econ : EconLoc ) BodyEconPair
{
  if( body == .CUSTOM )
  {
    // TODO : Raise issue
  }
  return def.pairEnums( BodyName, body, EconLoc, econ );
}

//  Extract BodyName & EconLoc from the corresponding composite enum
pub fn fromBodyEconPair( pair : BodyEconPair ) BodyEconSplit
{
  return def.splitEnums( BodyName, EconLoc, pair );
}


// ================================ TRADE DATA SNAPSHOT ================================

pub const OrbitalData = struct // NOTE : invalid if orbitLvl < EPS
{
  orbitLvl : f64  = 0.0, // 1 / root( distFromSun )
  angPos   : f64  = 0.0, // Current angle relative to the reference plane ( centered on sun )
  angVel   : f64  = 0.0, // Instantanious angular speed ( - == counter-clockwise )
  radVel   : f64  = 0.0, // Instantanious radial  speed ( - == towards the sun )
};

pub const TravelData = struct // NOTE : invalid if deltaV < EPS
{
  deltaV   : f64  = 0.0,
  duration : f64  = 0.0,
};


// Most recent positional data for any econ
pub var econOrbitalData : def.GenDataLine( OrbitalData, BodyEconPair ) = .{};

// Most recent travel data betwix any two econs     | DEPARTURE   | ARRIVAL
pub var econTravelTable : def.GenDataGrid( TravelData, BodyEconPair, BodyEconPair ) = .{};


/// Also updates econ's sunshine value
pub fn updateOrbitalDataEntry( bodyComp : *bdy.BodyComp, loc : gdf.EconLoc, bodyPos : Vec2, bodyVel : Vec2, starPos : Vec2 ) void
{
  // TODO : get precise pos and vel for L1-L5 points instead of using orbiter's
  const econPos = bodyPos;
  const econVel = bodyVel;

  const distSqr = econPos.getDistSqr( starPos );

  var data : gdf.OrbitalData = .{};

  // TODO : rework calculation to have more accurate values
  if( distSqr > def.EPS )
  {
    const dist    = @sqrt( distSqr );
    data.orbitLvl = 1.0 / @sqrt( dist );

    // Angular position relative to star
    const delta = econPos.sub( starPos );
    data.angPos = delta.toAngle().r;

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
