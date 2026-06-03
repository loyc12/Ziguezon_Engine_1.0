const std = @import( "std"   );
const utl = @import( "utils" );
const eng = @import( "engine" );

pub const gbl = @import( "gameGlobals.zig" );

pub const orb = @import( "comp/orbitComp.zig" );
pub const bdy = @import( "comp/bodyComp.zig"  );
pub const ecn = @import( "econ/economy.zig"   );

pub const trvlSlvr = @import( "econ/travelSolver.zig"  );


pub const TransStore  = eng.TransComp.getStoreType();
pub const ShapeStore  = eng.ShapeComp.getStoreType();
pub const SpriteStore = eng.SpriteComp.getStoreType();
pub const OrbitStore  = orb.OrbitComp.getStoreType();
pub const BodyStore   = bdy.BodyComp.getStoreType();


// ================ UNITS AND CONSTANTS ================

// ======== Astronomical / geological units ========

// Mass      : Gigaton      ( Gt  ) = 1e12 kg ( 1_000_000_000_000 )
// Distance  : Kilometer    ( km  ) = 1_000 m
// Area      : Squared km   ( km2 ) = 1_000_000 m2
// Time      : Day          ( Dy  ) = 86_400 s
// Density   : Gt/km³               = g/cm³
// Pollution : tons of CO@ ( tCO2 ) ( equivalence of effect )


// ======== Resource units ========

// DEFAULT   : Metric Ton     ( t   ) = 1_000 kg
// WORK      : Workweek       ( Ww  ) = 40 h
// POWER     : Megawatt-hour  ( MWh ) = 1_000_000 Wh

// NOTE : 1 kg of FOOD  represents about 1 kcal
// NOTE : 1 kg of WATER represents exactly 1_000 L


// ================================ ENGINE & GAME SETTINGS ================================

pub const G_CONSTS : GameConsts = .{};
pub const G_FLAGS  : GameFlags  = .{};

pub const GameConsts = struct
{
  zoomSpeed   : f32  =  1.2,
  scrollSpeed : f64  = 12.0,

  gravFactor  : f64  = 0.000240241, // 498.163, // Unit : km³/Gt¹Min² // TODO : adjust based on bodyTickLen

  bodyStepLen : i128 = utl.TimeVal.secPerMin(),
  econStepLen : i128 = utl.TimeVal.secPerWeek(),

  renderScale : f64  = 0.000_001,

  orbitPathLenFactor : f32 = 1.0, // 0.0 - 1.0 // Controls orbital path lenght
  orbitFadeStrenght  : u8  = 1,   // 0 - 255   // Controls orbital path fading

  backColour : utl.Colour = .dIndigo,
  foreColour : utl.Colour = .dCrimson,
  textColour : utl.Colour = .lGreen,

  bodyCount   : usize        = BodyName.count,
  maxEntityId : eng.EntityId = BodyName.count,

  starId : eng.EntityId = idFromName( .SOL   ), // SUN
  homeId : eng.EntityId = idFromName( .TERRA ), // EARTH
};

pub const GameFlags = struct
{
  STRESS_TEST : bool = false,
  DEFAULT_POP : u64  = 100_000,
};



// ================ GAMEDATA MATRICES ================

pub const stlr_d = @import( "data/stellarData.zig"    );
pub const ecnm_d = @import( "data/economyData.zig"    );
pub const bldr_d = @import( "data/builderData.zig"    );
pub const gvmt_d = @import( "data/governmentData.zig" );

pub const EconLoc           = ecnm_d.EconLoc;
pub const BodyType          = stlr_d.StellarBodyType;
pub const BodyName          = stlr_d.StellarBodyName;
pub const StellarMetricEnum = stlr_d.StellarMetricEnum;

pub const Construct         = bldr_d.Construct;
pub const Requester         = bldr_d.Requester;

pub const rbtc_d = @import( "data/orbitanceData.zig"  );
pub const trvl_d = @import( "data/travelData.zig"      );

pub const idFromName        = rbtc_d.idFromName;
pub const nameFromId        = rbtc_d.nameFromId;

pub const BodyEconPair      = trvl_d.BodyEconPair;
pub const toBodyEconPair    = trvl_d.toBodyEconPair;
pub const fromBodyEconPair  = trvl_d.fromBodyEconPair;

pub const OrbitalData       = trvl_d.OrbitalData;
pub const TravelData        = trvl_d.TravelData;

pub const updateOrbitalDataEntry  = trvl_d.updateOrbitalDataEntry;
pub const debugLogTravelCosts     = trvl_d.debugLogTravelCosts;
pub const debugLogTravelCostsList = trvl_d.debugLogTravelCostsList;



pub const powr_d = @import( "data/powerData.zig"          );
pub const vesl_d = @import( "data/vesselData.zig"         );
pub const rsrc_d = @import( "data/resourceData.zig"       );
pub const popl_d = @import( "data/populationData.zig"     );
pub const nfrs_d = @import( "data/infrastructureData.zig" );
pub const ndst_d = @import( "data/industryData.zig"       );

pub const PowerSrc = powr_d.PowerSrc;
pub const VesType  = vesl_d.VesType;
pub const ResType  = rsrc_d.ResType;
pub const PopType  = popl_d.PopType;
pub const InfType  = nfrs_d.InfType;
pub const IndType  = ndst_d.IndType;

