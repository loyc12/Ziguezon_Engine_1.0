const std = @import( "std" );
const def = @import( "defs" );

const gbl = @import( "../gameGlobals.zig" );


const StellarBody = gbl.stlr_d.StellarBodyEnum;
const EconLoc     = gbl.EconLoc;


// ================================ COMPOSITE PAIR ENUM ================================
//  Generates a unique enum for every ( StellarBody - EconLoc ) pair.

pub const BodyEconPair  = def.GenPairedEnum( StellarBody, EconLoc );
pub const BodyEconSplit = def.GenSplitEnum(  StellarBody, EconLoc );


//  Combine StellarBody & EconLoc into the corresponding composite enum
pub fn toBodyEconPair( body : StellarBody, econ : EconLoc ) BodyEconPair
{
  if( body == .CUSTOM )
  {
    // TODO : Raise issue
  }
  return def.pairEnums( StellarBody, body, EconLoc, econ );
}

//  Extract StellarBody & EconLoc from the corresponding composite enum
pub fn fromBodyEconPair( pair : BodyEconPair ) BodyEconSplit
{
  return def.splitEnums( StellarBody, EconLoc, pair );
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
