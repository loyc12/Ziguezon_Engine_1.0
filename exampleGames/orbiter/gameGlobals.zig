const std = @import( "std" );
const def = @import( "defs" );

pub const orb = @import( "comp/orbitComp.zig" );
pub const bdy = @import( "comp/bodyComp.zig"  );
pub const str = @import( "comp/starComp.zig"  );
pub const ecn = @import( "econ/economy.zig"  );

pub const trfSlvr = @import( "econ/transferSolver.zig"  );


// ================================ ENGINE & GAME SETTINGS ================================

pub const backColour : def.Colour = .dIndigo;
pub const foreColour : def.Colour = .dCrimson;
pub const textColour : def.Colour = .lGreen;

pub const zoomSpeed   : f32 =  1.2;
pub const scrollSpeed : f64 = 12.0;

pub const renderScale : f64 = 0.000_001;


pub const TransStore  = def.TransComp.getStoreType();
pub const ShapeStore  = def.ShapeComp.getStoreType();
pub const SpriteStore = def.SpriteComp.getStoreType();

pub const OrbitStore  = orb.OrbitComp.getStoreType();
pub const BodyStore   = bdy.BodyComp.getStoreType();


pub var transStore   : TransStore   = .{};
pub var shapeStore   : ShapeStore   = .{};
pub var spriteStore  : SpriteStore  = .{};

pub var orbitStore   : OrbitStore   = .{};
pub var bodyStore    : BodyStore    = .{};

pub var starCompInst : str.StarComp = .{};


pub const ENTITY_COUNT : usize = StellarBodyEnum.count - 1;

pub var   starId       : def.EntityId = 1; // SUN
pub var   homeworldId  : def.EntityId = 4; // EARTH

pub var   targetId     : def.EntityId = 0;
pub var   entityArray  : [ ENTITY_COUNT ]def.Entity = std.mem.zeroes([ ENTITY_COUNT ]def.Entity );

pub var   followTarget   : bool = false;
pub var   targetHasMoved : bool = false;



// ================ UNITS AND CONSTANTS ================

// Mass     : Gigaton   ( Gt ) = 1e12 kg ( 1_000_000_000_000 )
// Distance : Kilometer ( km ) = 1_000 m
// Time     : Day       ( Dy ) = 86_400 s
// Density  : Gt/km³           = g/cm³

/// Unit : km³/Gt¹Day²
pub const G_FACTOR : f64 = 498.163;



// ================ GENERAL GAME DATA ================

pub const stlr_d = @import( "data/stellarData.zig" );
pub const ecnm_d = @import( "data/economyData.zig" );
pub const trde_d = @import( "data/tradeData.zig"   );

pub const STLR_DATA         = &stlr_d.stellarData;
pub const ECON_ORBIT_DATA   = &trde_d.econOrbitalData;
pub const ECON_TRAVEL_TABLE = &trde_d.econTravelTable;

pub const EconLoc           = ecnm_d.EconLoc;
pub const StellarBodyEnum   = stlr_d.StellarBodyEnum;
pub const StellarMetrucEnum = stlr_d.StellarMetricEnum;

pub const BodyEconPair      = trde_d.BodyEconPair;
pub const toBodyEconPair    = trde_d.toBodyEconPair;
pub const fromBodyEconPair  = trde_d.fromBodyEconPair;
pub const OrbitalData       = trde_d.OrbitalData;
pub const TravelData        = trde_d.TravelData;


pub const powr_d = @import( "data/powerData.zig"          );
pub const vesl_d = @import( "data/vesselData.zig"         );
pub const rsrc_d = @import( "data/resourceData.zig"       );
pub const nfrs_d = @import( "data/infrastructureData.zig" );
pub const ndst_d = @import( "data/industryData.zig"       );

pub const POWR_DATA = &powr_d.powerData;
pub const VESL_DATA = &vesl_d.vesselData;
pub const RSRC_DATA = &rsrc_d.resourceData;
pub const NFRS_DATA = &nfrs_d.infrastructureData;
pub const NDST_DATA = &ndst_d.industryData;

pub const PowerSrc = powr_d.PowerSrc;
pub const VesType  = vesl_d.VesType;
pub const ResType  = rsrc_d.ResType;
pub const InfType  = nfrs_d.InfType;
pub const IndType  = ndst_d.IndType;


pub fn loadAllData() void
{
  stlr_d.loadStellarData();

  powr_d.loadPowerSrcData();
  vesl_d.loadVesselData();
  rsrc_d.loadResourceData();
  nfrs_d.loadInfrastructureData();
  ndst_d.loadIndustryData();
}