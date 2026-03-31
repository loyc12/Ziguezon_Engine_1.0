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


// ================================ LATEST INTRA-STELLAR TRADE DATA ================================

// Root of the current distance from the sun's center
pub var econRootRadiusData : def.GenDataLine( f64, BodyEconPair ) = .{};

// Most recent travel data between any two econs | DEPARTURE   | ARRIVAL
pub var econDeltaTimeTable : def.GenDataGrid( f64, BodyEconPair, BodyEconPair ) = .{};
pub var econDeltaVelTable  : def.GenDataGrid( f64, BodyEconPair, BodyEconPair ) = .{};
