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
pub fn toPair( body : StellarBody, econ : EconLoc ) BodyEconPair
{
  return def.pairEnums( StellarBody, body, EconLoc, econ );
}

//  Extract StellarBody & EconLoc from the corresponding composite enum
pub fn fromPair( pair : BodyEconPair ) BodyEconSplit
{
  return def.splitEnums( StellarBody, EconLoc, pair );
}


// ================================ LATEST INTRA-STELLAR TRADE DATA ================================

// Root of the current distance from the sun's center
pub const EconRootRadiusData = def.GenDataLine( f64, BodyEconPair );

// char of latest travel data between any two econs  DEPARTURE,    ARRIVAL
pub const EconDeltaTimeTable = def.GenDataGrid( f64, BodyEconPair, BodyEconPair );
pub const EconDeltaVelTable  = def.GenDataGrid( f64, BodyEconPair, BodyEconPair );
