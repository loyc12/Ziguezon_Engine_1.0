const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

pub const gdf = @import( "gameDef.zig" );

const bodyCount = gdf.G_CONSTS.bodyCount;


// ================ GAMEDATA STRUCTS ================

pub var G_DATA : GameData = .{};

pub const GameData = struct
{
  times  : GameTimes  = .{},
  stores : CompStores = .{},
  target : TargetInfo = .{},

  entityArray : [ bodyCount ]eng.Entity = std.mem.zeroes([ bodyCount ]eng.Entity ),
};


pub const GameTimes = struct
{
  speedSetting : SpeedFactor = .DAY,
  secsPerStep  : i128 = SpeedFactor.DAY.getStepLen(),

  bodyStepOffset : i128 = 0,
  econStepOffset : i128 = 0,


  pub inline fn changeSpeed( self : *GameTimes, delta : i8 )void
  {
    self.speedSetting = self.speedSetting.change( delta );
    self.secsPerStep  = self.speedSetting.getStepLen();
  }
  pub inline fn stepTime( self : *GameTimes ) void // Run every tick
  {
    if( eng.G_ENG.isPaused() ){ return; }

    const tickPerSec : i128 = @intCast( eng.CNFGS.Startup_Target_TickRate );

    self.bodyStepOffset += @divFloor( self.secsPerStep, tickPerSec );
    self.econStepOffset += @divFloor( self.secsPerStep, tickPerSec );
  }

  pub inline fn shouldBodyTick( self : *GameTimes ) bool
  {
    if( eng.G_ENG.isPaused() ){ return false; }

    return( self.bodyStepOffset >= gdf.G_CONSTS.bodyStepLen );
  }
  pub inline fn consumeBodyTick( self : *GameTimes ) void
  {
    self.bodyStepOffset -= gdf.G_CONSTS.bodyStepLen;
  }

  pub inline fn shouldEconTick( self : *GameTimes ) bool
  {
    if( eng.G_ENG.isPaused() ){ return false; }

    return( self.econStepOffset >= gdf.G_CONSTS.econStepLen );
  }
  pub inline fn consumeEconTick( self : *GameTimes ) void
  {
    self.econStepOffset -= gdf.G_CONSTS.econStepLen;
  }
};


pub const CompStores = struct
{
  trans  : gdf.TransStore  = .{},
  shape  : gdf.ShapeStore  = .{},
  sprite : gdf.SpriteStore = .{},
  orbit  : gdf.OrbitStore  = .{},
  body   : gdf.BodyStore   = .{},


  /// Returns true if the registry process failed somewhere
  pub inline fn registerAllStores( self : *CompStores, ng : *eng.Engine ) bool
  {
    const alloc = utl.getDefaultAlloc();

    var hasError : bool = false;

    self.trans.init(  alloc );
    self.shape.init(  alloc );
    self.sprite.init( alloc );

    self.orbit.init(  alloc );
    self.body.init(   alloc );


    // Registering componentStores
    if( !ng.componentRegistry.register( "transStore", &self.trans ))
    {
      utl.qlog( .ERROR, 0, @src(), "Failed to register transStore" );
      hasError = true;
    }
    if( !ng.componentRegistry.register( "shapeStore", &self.shape ))
    {
      utl.qlog( .ERROR, 0, @src(), "Failed to register shapeStore" );
      hasError = true;
    }
    if( !ng.componentRegistry.register( "spriteStore", &self.sprite ))
    {
      utl.qlog( .ERROR, 0, @src(), "Failed to register spriteStore" );
      hasError = true;
    }

    if( !ng.componentRegistry.register( "orbitStore", &self.orbit ))
    {
      utl.qlog( .ERROR, 0, @src(), "Failed to register orbitStore" );
      hasError = true;
    }
    if( !ng.componentRegistry.register( "bodyStore", &self.body ))
    {
      utl.qlog( .ERROR, 0, @src(), "Failed to register bodyStore" );
      hasError = true;
    }
    return hasError;
  }

  pub inline fn deinitAllStores( self : *CompStores ) void
  {
    self.trans.deinit();
    self.shape.deinit();
    self.sprite.deinit();
    self.orbit.deinit();
    self.body.deinit();
  }
};


pub const TargetInfo = struct
{
  camFollow : bool = false,
  hasMoved  : bool = false,

  targetId : eng.EntityId = 0,


  pub fn changeTargetTo( self : *TargetInfo, targetId : eng.EntityId ) void
  {
    if( targetId >= 0 and targetId < bodyCount )
    {
      self.targetId = targetId;
      self.hasMoved = true;
    }
    else
    {
      utl.qlog( .WARN, 0, @src(), "Target does not exist : defaulting to Id 0 ( none )" );
      self.targetId = 0;
    }
  }

  pub fn changeTargetBy( self : *TargetInfo, delta : i64 ) void
  {
    const current : i64 = @intCast( self.targetId );
    var next = current + delta;

    if( next < 0 ){ next = 0; }
    if( next > bodyCount ){ next = bodyCount; }

    self.targetId = @intCast( next );
    self.hasMoved = true;
  }

  pub fn moveCamOver( self : *TargetInfo ) void
  {
    if( self.targetId == 0 )
    {
      utl.qlog( .TRACE, 0, @src(), "targetId is 0 : returning" );
      return;
    }

    // Centers the camera on current valid target
    if( self.camFollow and self.hasMoved )
    {
      self.hasMoved = false;

      const targetTrans = G_DATA.stores.trans.get( self.targetId );

      if( targetTrans )| trans |
      {
        eng.G_ENG.camera.cam.pos = trans.pos;
        utl.qlog( .TRACE, 0, @src(), "View centered on target" );
      }
      else
      {
        utl.qlog( .WARN, 0, @src(), "Target does not exist : cannot center view" );
        self.camFollow = false;
      }
    }
  }
};


// ================ GAMEDATA SUB-STRUCTS ================

pub const SpeedFactor = enum( i8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  PAUSED = 0,
  SECOND,
  MINUTE,
  HOUR,
  DAY,
  WEEK,
  MONTH,
  YEAR,


  pub inline fn getStepLen( self : SpeedFactor ) i128
  {
    return switch( self )
    {
      .PAUSED => 0,
      .SECOND => 1,
      .MINUTE => utl.TimeVal.secPerMin(),
      .HOUR   => utl.TimeVal.secPerHour(),
      .DAY    => utl.TimeVal.secPerDay(),
      .WEEK   => utl.TimeVal.secPerDay() * 7,
      .MONTH  => utl.TimeVal.secPerDay() * 30,
      .YEAR   => utl.TimeVal.secPerDay() * 365,
    };
  }

  pub inline fn change( self : SpeedFactor, delta : i8 ) SpeedFactor
  {
    const current : i8 = @intFromEnum( self );
    var   next    : i8 = current + delta;

    if( next < 0      ){ next = 0;         }
    if( next >= count ){ next = count - 1; }

    return @enumFromInt( next );
  }
};


// ================ GAMEDATA MATRICES ================

    const stlr_d = @import( "data/stellarData.zig" );
    const trde_d = @import( "data/travelData.zig"   );
    const ecnm_d = @import( "data/economyData.zig" );

pub const STLR_DATA         = &stlr_d.stellarData;
pub const ECON_ORBIT_DATA   = &trde_d.econOrbitalData;


    const powr_d = @import( "data/powerData.zig"          );
    const vesl_d = @import( "data/vesselData.zig"         );
    const rsrc_d = @import( "data/resourceData.zig"       );
    const popl_d = @import( "data/populationData.zig"     );
    const nfrs_d = @import( "data/infrastructureData.zig" );
    const ndst_d = @import( "data/industryData.zig"       );

pub const POWR_DATA = &powr_d.powerData;
pub const VESL_DATA = &vesl_d.vesselData;
pub const RSRC_DATA = &rsrc_d.resourceData;
pub const POPL_DATA = &popl_d.populationData;
pub const NFRS_DATA = &nfrs_d.infrastructureData;
pub const NDST_DATA = &ndst_d.industryData;


    const rbtc_d = @import( "data/orbitanceData.zig" );
    const sshn_d = @import( "data/sunshineData.zig"   );

pub const ORBITANCE = &rbtc_d.orbitTree;
pub const SUNSHINE  = &sshn_d.solShine;


pub fn loadStaticDataMatrices() void
{
  stlr_d.loadStellarData();
  rbtc_d.loadOrbitanceTree();

  powr_d.loadPowerSrcData();
  vesl_d.loadVesselData();
  rsrc_d.loadResourceData();
  popl_d.loadPopulationData();
  nfrs_d.loadInfrastructureData();
  ndst_d.loadIndustryData();

  if( !debugCheckDataInit() )
  {
    utl.qlog( .ERROR, 0, @src(), "One or more dataMatrices were left uninitialized" );
  }

  _ = SUNSHINE.initFromData();
}


pub fn debugCheckDataInit() bool
{
  if( !stlr_d.stellarData.isInit ){ return false; }

  if( !powr_d.powerMetricData.isInit ){ return false; }
  if( !vesl_d.vesMetricData.isInit   ){ return false; }

  if( !rsrc_d.resMetricData.isInit     ){ return false; }
  if( !popl_d.popResMetricTable.isInit ){ return false; }
  if( !nfrs_d.infResMetricTable.isInit ){ return false; }
  if( !ndst_d.indResMetricTable.isInit ){ return false; }

  if( !popl_d.popMetricData.isInit ){ return false; }
  if( !nfrs_d.infMetricData.isInit ){ return false; }
  if( !ndst_d.indMetricData.isInit ){ return false; }

  return true;
}

