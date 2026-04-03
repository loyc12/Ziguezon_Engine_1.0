const std = @import( "std" );
const def = @import( "defs" );

pub const gbl = @import( "gameGlobals.zig" );

pub const orb = @import( "comp/orbitComp.zig" );
pub const bdy = @import( "comp/bodyComp.zig"  );
pub const ecn = @import( "econ/economy.zig"   );

pub const trfSlvr = @import( "econ/transferSolver.zig"  );


pub const TransStore  = def.TransComp.getStoreType();
pub const ShapeStore  = def.ShapeComp.getStoreType();
pub const SpriteStore = def.SpriteComp.getStoreType();
pub const OrbitStore  = orb.OrbitComp.getStoreType();
pub const BodyStore   = bdy.BodyComp.getStoreType();



// ================ UNITS AND CONSTANTS ================

// Mass     : Gigaton   ( Gt ) = 1e12 kg ( 1_000_000_000_000 )
// Distance : Kilometer ( km ) = 1_000 m
// Time     : Day       ( Dy ) = 86_400 s
// Density  : Gt/km³           = g/cm³


pub const GAME_CONSTS : GameConsts = .{};

pub const GameConsts = struct
{
  gravFactor  : f64 = 498.163, // Unit : km³/Gt¹Day² // TODO : adjust based on bodyTickLen

  bodyTickLen : i128 = def.TimeVal.secPerDay(),
  econTickLen : i128 = def.TimeVal.secPerWeek(),
};



// ================ GAMEDATA MATRICES ================

pub const stlr_d = @import( "data/stellarData.zig" );
pub const ecnm_d = @import( "data/economyData.zig" );
pub const trde_d = @import( "data/tradeData.zig"   );

pub const EconLoc           = ecnm_d.EconLoc;
pub const BodyType          = stlr_d.StellarBodyType;
pub const BodyName          = stlr_d.StellarBodyName;
pub const StellarMetricEnum = stlr_d.StellarMetricEnum;

pub const BodyEconPair      = trde_d.BodyEconPair;
pub const toBodyEconPair    = trde_d.toBodyEconPair;
pub const fromBodyEconPair  = trde_d.fromBodyEconPair;
pub const OrbitalData       = trde_d.OrbitalData;
pub const TravelData        = trde_d.TravelData;

pub const updateOrbitalDataEntry = trde_d.updateOrbitalDataEntry;


pub const powr_d = @import( "data/powerData.zig"          );
pub const vesl_d = @import( "data/vesselData.zig"         );
pub const rsrc_d = @import( "data/resourceData.zig"       );
pub const nfrs_d = @import( "data/infrastructureData.zig" );
pub const ndst_d = @import( "data/industryData.zig"       );

pub const PowerSrc = powr_d.PowerSrc;
pub const VesType  = vesl_d.VesType;
pub const ResType  = rsrc_d.ResType;
pub const InfType  = nfrs_d.InfType;
pub const IndType  = ndst_d.IndType;


