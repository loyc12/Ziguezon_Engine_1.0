const std = @import( "std" );
const def = @import( "defs" );


pub const ecnSlvr = @import( "econSolver.zig"  );
pub const ecnBldr = @import( "econBuilder.zig" );
pub const cst     = @import( "construct.zig"   );
pub const eco     = @import( "ecology.zig"     );

pub const BuildQueue = ecnBldr.BuildQueue;
pub const Construct  = @import( "construct.zig" ).Construct;
pub const Ecology    = eco.EcoState;


const gbl = @import( "../gameGlobals.zig" );
const gdf = @import( "../gameDefs.zig" );

const EconLoc  = gdf.EconLoc;

const PowerSrc = gdf.PowerSrc;
const VesType  = gdf.VesType;
const ResType  = gdf.ResType;
const InfType  = gdf.InfType;
const IndType  = gdf.IndType;

const powerSrcC = PowerSrc.count;
const vesTypeC  = VesType.count;
const resTypeC  = ResType.count;
const infTypeC  = InfType.count;
const indTypeC  = IndType.count;


const MIN_RES_CAP           = 100.0;
const MAX_SUN_ACCESS_CAP    =   1.0;
const SUN_SHORTAGE_EXPONENT =   2.0;


pub const Economy = struct
{
  pub inline fn getStoreType() type { return def.componentStoreFactory( @This() ); }

  location  : EconLoc,

  isValid   : bool = false,
  isActive  : bool = false,
  hasAtmo   : bool,

  stepCount : u64 = 0,
  sunshine  : f64 = 0.0,
  sunAccess : f32 = 1.0,

  ecology     : ?Ecology    = null,

  buildQueue  : ?BuildQueue = null,
  buildDemand : f64 = 0.0,  // PART demand from construction queue this tick
  buildBudget : f64 = 0.0,  // PART allocation granted by solver

  areaMetrics : gdf.ecnm_d.AreaMetricData = .{},
  popMetrics  : gdf.ecnm_d.PopMetricData  = .{},
  resState    : gdf.rsrc_d.ResStateData   = .{},
  infState    : gdf.nfrs_d.InfStateData   = .{},
  indState    : gdf.ndst_d.IndStateData   = .{},

  avgIndActivity : f64 = 0.0,
  avgResAccess   : f64 = 0.0,


  pub inline fn newDeadEcon( loc : EconLoc ) Economy
  {
    var econ : Economy = undefined;

    econ.softInit( loc );

    return econ;
  }

  pub inline fn softInit( self : *Economy, loc : EconLoc ) void
  {
    self.isValid  = true;
    self.isActive = false;
    self.location = loc;
  }


  pub inline fn newLiveEcon( loc : EconLoc, area : f64, landCover : f64, atmo : bool ) Economy
  {
    var econ : Economy = undefined;

    econ.hardInit( loc, area, landCover, atmo );

    return econ;
  }

  pub inline fn hardInit( self : *Economy, loc : EconLoc, area : f64, landCover : f64, atmo : bool ) void
  {
    if( !self.isValid ){ self.softInit( loc ); } // NOTE : check might pass if garbage data ( not softInit beforehand )

    self.hasAtmo  = atmo;

    self.areaMetrics.fillWith( 0.0 );
    self.popMetrics.fillWith(  0.0 );
    self.resState.fillWith(    0.0 );
    self.infState.fillWith(    0.0 );
    self.indState.fillWith(    0.0 );

    self.areaMetrics.set( .BODY,  area      );
    self.areaMetrics.set( .INHAB, landCover );

    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      self.resState.set( .LIMIT, resType, MIN_RES_CAP );
      self.resState.set( .PRICE, resType, resType.getMetric_f64( .PRICE_BASE ));
    }

    inline for( 0..indTypeC )| d |
    {
      const indType = IndType.fromIdx( d );

      self.indState.set( .ACT_TRGT, indType, 1.0 );
    }


    self.buildQueue = BuildQueue.init();
    self.updateAreas();

    if( self.hasEcology() )
    {
      self.ecology = .init( self );
    }
  }


  // ================================ RESSOURCES ================================

  pub fn updateResCaps( self : *Economy ) void
  {
    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );
      const infType = resType.getInfStore();

      const infCount = self.infState.get( .BANK, infType );
      const capacity = infType.getMetric_f64( .CAPACITY );

      self.resState.set( .LIMIT, resType, MIN_RES_CAP + ( infCount * capacity ));
    }
  }
  pub inline fn getResCap( self : *const Economy, resType : ResType ) u64
  {
    return @intFromFloat( self.resState.get( .LIMIT, resType ));
  }


  pub inline fn getResCount( self : *const Economy, resType : ResType ) u64
  {
    return @intFromFloat( self.resState.get( .BANK, resType ));
  }
  pub inline fn setResCount( self : *Economy, resType : ResType, value : u64 ) void
  {
    const cap = self.getResCap( resType );
    self.resState.set( .BANK, resType, @floatFromInt( @min( value, cap )));
  }
  pub inline fn addResCount( self : *Economy, resType : ResType, value : u64 ) void
  {
    const cap     = self.getResCap(   resType );
    const current = self.getResCount( resType );
    const new_val = @min( value + current, cap );
    self.resState.set( .BANK, resType, @floatFromInt( new_val ));
  }
  pub inline fn subResCount( self : *Economy, resType : ResType, value : u64 ) void
  {
    const current = self.getResCount( resType );
    const count   = @min( value, current );
    self.resState.set( .BANK, resType, @floatFromInt( current - count ));

    if( value != count )
    {
      def.log( .WARN, 0, @src(), "@ Tried to remove {d} res of type {s} from economy, but only had {d} left", .{ value, @tagName( resType ), count });
    }
  }


  pub inline fn debugSetResCounts(  self : *Economy, value : u64 ) void
  {
    inline for( 0..resTypeC )| r |
    {
      self.resState.set( .BANK, ResType.fromIdx( r ), @floatFromInt( value ));
    }
  }

  pub inline fn logResMetrics( self : *const Economy ) void
  {
    def.qlog( .INFO, 0, @src(), "$ Logging resources metrics :" );
    def.qlog( .CONT, 0, @src(), "RESOURCE\t: Bank\t ( Access )\t[ Delta\t| Prod\tCons\t| Grow\tDecay\t| Demand ]" );
    def.qlog( .CONT, 0, @src(), "====================================================================================================" );

    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      const resCount  : u64 = @intFromFloat( self.resState.get( .BANK,     resType ));
      const resDelta  : i64 = @intFromFloat( self.resState.get( .DELTA,    resType ));
      const resProd   : u64 = @intFromFloat( self.resState.get( .GEN_PROD, resType ));
      const resCons   : u64 = @intFromFloat( self.resState.get( .GEN_CONS, resType ));
      const resGrowth : u64 = @intFromFloat( self.resState.get( .GROWTH,   resType ));
      const resDecay  : u64 = @intFromFloat( self.resState.get( .DECAY,    resType ));
      const resReq    : u64 = @intFromFloat( self.resState.get( .MAX_DEM,  resType ));
      const resAccess : f32 = @floatCast(    self.resState.get( .GEN_ACS,  resType ));

      def.log( .CONT, 0, @src(), "{s}  \t: {d}\t ( {d:.4} )\t[ {d}\t| +{d}\t-{d}\t| +{d}\t-{d}\t| {d}\t ]",
        .{ @tagName( resType ), resCount, resAccess, resDelta, resProd, resCons, resGrowth, resDecay, resReq });
    }
  }


  // ================================ INFRASTRUCTURE ================================

  pub inline fn getInfCount( self : *const Economy, infType : InfType ) u64
  {
    return @intFromFloat( self.infState.get( .BANK, infType ));
  }
  pub inline fn setInfCount( self : *Economy, infType : InfType, value : u64 ) void
  {
    self.infState.set( .BANK, infType, @floatFromInt( value ));
  }
  pub inline fn addInfCount( self : *Economy, infType : InfType, value : u64 ) void
  {
    const current = self.getInfCount( infType );
    self.infState.set( .BANK, infType, @floatFromInt( value + current ));
  }
  pub inline fn subInfCount( self : *Economy, infType : InfType, value : u64 ) void
  {
    const current = self.getInfCount( infType );
    const count   = @min( value, current );
    self.infState.set( .BANK, infType, @floatFromInt( current - count ));

    if( value != count )
    {
      def.log( .WARN, 0, @src(), "@ Tried to remove {d} inf of type {s} from economy, but only had {d} left", .{ value, @tagName( infType ), count });
    }
  }


  pub fn canBuildInf( self : *const Economy, infType : InfType, count : u64 ) bool
  {
    if( !InfType.canBeBuiltIn( infType, self.location, self.hasAtmo ))
    {
      def.log( .WARN, 0, @src(), "@ You are not allowed to build infrastructure of type {s} in location of type {}", .{ @tagName( infType ), @tagName( self.location ) });
      return false;
    }

    if( infType == .HABITAT ){ return true; }

    const neededArea = infType.getAreaCost() * count;
    const areaAvail  = self.areaMetrics.get( .AVAIL );

    if( areaAvail < neededArea )
    {
      def.log( .WARN, 0, @src(), "@ Not enough space to build infrastructure of type {s} in location of type {}. Needed : {d}", .{ @tagName( infType ), @tagName( self.location ), neededArea });
      return false;
    }
    return true;
  }


  pub inline fn debugSetInfCounts(  self : *Economy, value : u64 ) void
  {
    self.infState.set( .BANK, .HOUSING,  @floatFromInt( value ));
    self.infState.set( .BANK, .HABITAT,                  0.0  );
    self.infState.set( .BANK, .STORAGE,  @floatFromInt( value ));
    self.infState.set( .BANK, .ASSEMBLY, @floatFromInt( value ));

    self.updateResCaps();
  }

  pub inline fn logInfMetrics( self : *const Economy ) void
  {
    def.qlog( .INFO, 0, @src(), "$ Logging infrastructure metrics :" );

    inline for( 0..infTypeC )| f |
    {
      const infType  = InfType.fromIdx( f );
      const infCount : u64 = @intFromFloat( self.infState.get( .BANK,  infType ));
      const infDelta : i64 = @intFromFloat( self.infState.get( .DELTA, infType ));
      const infBonus : u64 = infCount * infType.getMetric_u64( .CAPACITY );

      def.log( .CONT, 0, @src(), "{s}\t: {d}\t +{d}\t) [ {d} ]", .{ @tagName( infType ), infCount, infBonus, infDelta });
    }
  }


  // ================================ INDUSTRY ================================

  pub inline fn getIndCount( self : *const Economy, indType : IndType ) u64
  {
    return @intFromFloat( self.indState.get( .BANK, indType ));
  }
  pub inline fn setIndCount( self : *Economy, indType : IndType, value : u64 ) void
  {
    self.indState.set( .BANK, indType, @floatFromInt( value ));
  }
  pub inline fn addIndCount( self : *Economy, indType : IndType, value : u64 ) void
  {
    const current = self.getIndCount( indType );
    self.indState.set( .BANK, indType, @floatFromInt( current + value ));
  }
  pub inline fn subIndCount( self : *Economy, indType : IndType, value : u64 ) void
  {
    const current = self.getIndCount( indType );
    const count   = @min( value, current );
    self.indState.set( .BANK, indType, @floatFromInt( current - count ));

    if( value != count )
    {
      def.log( .WARN, 0, @src(), "@ Tried to remove {d} ind of type {s} from economy, but only had {d} left", .{ value, @tagName( indType ), count });
    }
  }


  pub fn canBuildInd( self : *const Economy, indType : IndType, count : u64 ) bool
  {
    if( !IndType.canBeBuiltIn( indType, self.location, self.hasAtmo ))
    {
      def.log( .INFO, 0, @src(), "You are not allowed to build industry of type {s} in location of type {}", .{ @tagName( indType ), @tagName( self.location ) });
      return false;
    }

    const neededArea = indType.getAreaCost() * count;
    const areaAvail  = self.areaMetrics.get( .AVAIL );

    if( areaAvail < neededArea )
    {
      def.log( .INFO, 0, @src(), "Not enough area : adjusting" );
      return false;
    }
    return true;
  }


  pub inline fn debugSetIndCounts( self : *Economy, value : u64 ) void
  {
    self.indState.set( .BANK, .AGRONOMIC,   @floatFromInt( value * 25  ));
    self.indState.set( .BANK, .HYDROPONIC,  @floatFromInt( value * 25  ));
    self.indState.set( .BANK, .WATER_PLANT, @floatFromInt( value * 50  ));
    self.indState.set( .BANK, .SOLAR_PLANT, @floatFromInt( value * 50  ));

    self.indState.set( .BANK, .PROBE_MINE,                         0    );
    self.indState.set( .BANK, .GROUND_MINE, @floatFromInt( value * 200 ));
    self.indState.set( .BANK, .REFINERY,    @floatFromInt( value * 100 ));
    self.indState.set( .BANK, .FACTORY,     @floatFromInt( value * 50  ));
  }

  pub inline fn logIndMetrics( self : *const Economy ) void
  {
    def.qlog( .INFO, 0, @src(), "$ Logging industrial metrics :" );

    inline for( 0..indTypeC )| d |
    {
      const indType  = IndType.fromIdx( d );
      const indCount : u64 = @intFromFloat( self.indState.get( .BANK,    indType ));
      const indDelta : i64 = @intFromFloat( self.indState.get( .DELTA,   indType ));
      const indRatio : f64 =                self.indState.get( .ACT_LVL, indType );

      def.log( .CONT, 0, @src(), "{s}\t: {d}\t( {d:.4} )\t[ {d} ]", .{ @tagName( indType ), indCount, indRatio, indDelta });
    }
  }


  // ================================ POPULATION ================================

  pub fn getPopCap( self : *const Economy ) u64
  {
    return self.getInfCount( .HOUSING ) * InfType.HOUSING.getMetric_u64( .CAPACITY );
  }


  pub inline fn getPopCount( self : *const Economy ) u64
  {
    return @intFromFloat( self.popMetrics.get( .COUNT ));
  }
  pub inline fn setPopCount( self : *Economy, value : u64 ) void
  {
    self.popMetrics.set( .COUNT, @floatFromInt( value ));
  }
  pub inline fn addPopCount( self : *Economy, value : u64 ) void
  {
    const cap     = self.getPopCap();
    const current = self.getPopCount();
    const new_val = @min( value + current, cap );

    if( new_val == cap )
    {
      def.log( .WARN, 0, @src(), "@ Tried to add {d} pops to economy, but only had space for {d}", .{ value, new_val - current });
    }
    self.popMetrics.set( .COUNT, @floatFromInt( new_val ));
  }
  pub inline fn subPopCount( self : *Economy, value : u64 ) void
  {
    const current = self.getPopCount();
    const count   = @min( value, current );
    self.popMetrics.set( .COUNT, @floatFromInt( current - count ));

    if( value != count )
    {
      def.log( .WARN, 0, @src(), "@ Tried to remove {d} pops from economy, but only had {d} left", .{ value, count });
    }
  }


  pub fn logPopMetrics( self : *const Economy ) void
  {
    const popCount  : u64 = @intFromFloat( self.popMetrics.get( .COUNT  ));
    const popDelta  : i64 = @intFromFloat( self.popMetrics.get( .DELTA  ));
    const popAccess : f64 =                self.popMetrics.get( .ACTIVITY );

    def.qlog( .INFO, 0, @src(), "$ Logging population metrics : " );
    def.log(  .CONT, 0, @src(), "Human\t: {d}\t/ {d}\t[ {d} ]\t( {d:.3} )", .{ popCount, self.getPopCap(), popDelta, popAccess });
  }


  // ================================ ENVIRONMENT ================================

  pub inline fn updateSunshine( self : *Economy, sunshine : f64 ) void
  {
    self.sunshine = sunshine;

    var tmp : f64 = 0;

    switch( self.location )
    {
      .GROUND =>
      {
        const developedArea = self.areaMetrics.get( .USED );
        const surfaceArea   = self.areaMetrics.get( .BODY );

        const overgroundRatio = surfaceArea / developedArea;

        if( developedArea < surfaceArea )
        {
          tmp = 0.5 * sunshine;
        }
        else
        {
          const sunlessRatio = def.pow( f64, 1.0 - overgroundRatio, SUN_SHORTAGE_EXPONENT );
          tmp = 0.5 * sunshine * ( 1.0 - sunlessRatio );
        }
      },

      .ORBIT => tmp = sunshine * 0.98,
      else   => tmp = sunshine,
    }

    self.sunAccess = @floatCast( def.clmp( tmp, 0.001, MAX_SUN_ACCESS_CAP ));
  }

  pub inline fn hasEcology( self : *const Economy ) bool
  {
    return( self.location == .GROUND and self.hasAtmo );
  }

  pub inline fn getEcoFactor( self : *const Economy ) f64
  {
    if( !self.hasEcology() ){ return 0.0; }

    if( self.ecology != null )
    {
      return self.ecology.?.ecoFactor;
    }
    else
    {
      def.qlog( .WARN, 0, @src(), "Cannot get ecology factor : uninitialized" );
      return 0.0;
    }
  }


  // ================================ AREA ================================

  pub inline fn getHabitatArea( self : *const Economy ) f64
  {
    const habCount : f64 = @floatFromInt( self.getInfCount( .HABITAT ));

    return habCount * InfType.HABITAT.getMetric_f64( .CAPACITY );
  }

  pub fn updateAreas( self : *Economy ) void
  {
    const habitatArea = self.getHabitatArea();
    const bodyArea    = self.areaMetrics.get( .BODY  );
    const inhabRatio  = self.areaMetrics.get( .INHAB );

    // Compute LAND
    const landArea = bodyArea * inhabRatio;
    self.areaMetrics.set( .LAND, landArea );

    // Compute CAP
    if( self.location == .GROUND and self.hasAtmo )
    {
      self.areaMetrics.set( .CAP, habitatArea + landArea );
    }
    else
    {
      self.areaMetrics.set( .CAP, habitatArea );
    }

    // Compute USED
    var areaUsed : f64 = 0.0;

    inline for( 0..infTypeC )| f |{ if( f != InfType.HABITAT.toIdx() )
    {
      const infType        = InfType.fromIdx( f );
      const infCount : f64 = @floatFromInt( self.getInfCount( infType ));

      areaUsed += infCount * infType.getMetric_f64( .AREA_COST );
    }}
    inline for( 0..indTypeC )| d |
    {
      const indType        = IndType.fromIdx( d );
      const indCount : f64 = @floatFromInt( self.getIndCount( indType ));

      areaUsed += indCount * indType.getMetric_f64( .AREA_COST );
    }

    self.areaMetrics.set( .USED, areaUsed );

    // Compute AVAIL
    const areaCap = self.areaMetrics.get( .CAP );

    if( areaCap > areaUsed )
    {
      self.areaMetrics.set( .AVAIL, areaCap - areaUsed );
    }
    else
    {
      def.log( .WARN, 0, @src(), "Negative available area in location of type {s} : using {d} / {d}", .{ @tagName( self.location ), areaUsed, areaCap });
      self.areaMetrics.set( .AVAIL, 0.0 );
    }
  }



  // ================================ CONSTRUCTION ================================

pub inline fn tryBuild( self : *Economy, c : Construct, amount : f64, consumeParts : bool ) f64
  {
    if( !c.canBeBuiltIn( self.location, self.hasAtmo ))
    {
      def.qlog( .WARN, 0, @src(), "Invalid location conditions : aborting" );
      return 0;
    }

    const areaCost   = c.getAreaCost();
    var  builtAmount = @floor( amount );

    if( !std.meta.eql( c, .{ .inf = .HABITAT }))
    {
      const areaAvail = self.areaMetrics.get( .AVAIL );

      if( areaAvail < areaCost )
      {
      // def.qlog( .WARN, 0, @src(), "Not enough area for a single unit : aborting" );
        return 0;
      }
      if( areaAvail < builtAmount * areaCost )
      {
      //def.qlog( .WARN, 0, @src(), "Not enough area : adjusting amount" );
        builtAmount = areaAvail / areaCost;
      }
    }

    if( consumeParts )
    {
      const availParts  = self.resState.get( .BANK, .PART );
      const partCost    = c.getPartCost();

      if( availParts < partCost )
      {
      //def.qlog( .WARN, 0, @src(), "Not enough parts for a single unit : aborting" );
        return 0;
      }
      if( availParts < builtAmount * partCost )
      {
      //def.qlog( .WARN, 0, @src(), "Not enough parts : adjusting amount" );
        builtAmount = availParts / partCost;
      }

      builtAmount     = @floor( builtAmount            );
      const totalCost = @ceil(  builtAmount * partCost );

      // Deduct parts
      self.resState.sub( .BANK,     .PART, totalCost );
      self.resState.add( .GEN_CONS, .PART, totalCost );
    }

    builtAmount = @floor( builtAmount );

    switch( c )
    {
      .inf => | infType |
      {
        self.infState.add( .BANK,  infType, builtAmount );
        self.infState.add( .BUILT, infType, builtAmount );
        self.infState.add( .DELTA, infType, builtAmount );
      },
      .ind => | indType |
      {
        self.indState.add( .BANK,  indType, builtAmount );
        self.indState.add( .BUILT, indType, builtAmount );
        self.indState.add( .DELTA, indType, builtAmount );
      },
    //else =>
    //{
    //  // TODO : build vessels
    //},
    }

    return builtAmount;
  }


  // ================================ UPDATING ================================

  pub inline fn logAllMetrics( self : *const Economy ) void
  {

    self.logResMetrics();
    self.logInfMetrics();
    self.logIndMetrics();
  //self.logTravelMetrics_TERRA();
    self.logPopMetrics();

    def.qlog( .INFO, 0, @src(), "$ Logging general metrics" );
    def.log(  .CONT, 0, @src(), "Steps done   : {d:.6}",          .{ self.stepCount });
    def.log(  .CONT, 0, @src(), "Sun access   : {d:.6}",          .{ self.sunAccess });
    def.log(  .CONT, 0, @src(), "Eco factor   : {d:.6}",          .{ self.getEcoFactor() });
    def.log(  .CONT, 0, @src(), "Development  : {d:.0} / {d:.0}", .{ self.areaMetrics.get( .USED ), self.areaMetrics.get( .CAP ) });
    def.log(  .CONT, 0, @src(), "Build queue  : {d}",             .{ self.buildQueue.?.getEntryCount() });
  }

  // TODO : generalise this code
  pub inline fn logTravelMetrics_TERRA( self : *const Economy ) void
  {
    def.qlog( .INFO, 0, @src(), "& Logging travel metrics ( from Earth to X ) :" );

    inline for( 0..gdf.BodyName.count )| b |
    {
      const body  = gdf.BodyName.fromIdx( b );
      const table = gbl.ECON_TRAVEL_TABLE.get( gdf.toBodyEconPair( .TERRA, self.location ), gdf.toBodyEconPair( body, self.location ) );

      def.log( .CONT, 0, @src(), "{s}   \t: {d:.3}\t/ {d:.3}", .{ @tagName( body ), table.deltaV, table.duration });
    }
    inline for( 0..EconLoc.count )| l |
    {
      const loc   = EconLoc.fromIdx( l );
      const table = gbl.ECON_TRAVEL_TABLE.get( gdf.toBodyEconPair( .TERRA, self.location ), gdf.toBodyEconPair( .TERRA, loc ) );

      def.log( .CONT, 0, @src(), "{s}   \t: {d:.3}\t/ {d:.3}", .{ @tagName( loc ), table.deltaV, table.duration });
    }
  }

  pub inline fn resetCountMetrics( self : *Economy ) void
  {
    self.popMetrics.set( .DELTA,    0.0 );
    self.popMetrics.set( .ACTIVITY, 0.0 );

    self.avgIndActivity = 0.0;
    self.avgResAccess   = 0.0;


    inline for( 0..resTypeC )| r |
    {
      const res = ResType.fromIdx( r );

      self.resState.set( .DELTA,    res, 0.0 );

      self.resState.set( .DECAY,    res, 0.0 );
      self.resState.set( .GROWTH,   res, 0.0 );

      self.resState.set( .MAX_SUP,  res, 0.0 );
      self.resState.set( .MAX_DEM,  res, 0.0 );

      self.resState.set( .GEN_PROD, res, 0.0 );
      self.resState.set( .GEN_CONS, res, 0.0 );

      self.resState.set( .GEN_ACS,  res, 0.0 );
      self.resState.set( .POP_ACS,  res, 0.0 );
      self.resState.set( .IND_ACS,  res, 0.0 );
    }
    inline for( 0..infTypeC )| f |
    {
      const inf = InfType.fromIdx( f );

      self.infState.set( .DELTA,   inf, 0.0 );

      self.infState.set( .DECAY,   inf, 0.0 );
      self.infState.set( .BUILT,   inf, 0.0 );

      self.infState.set( .EXPENSE, inf, 0.0 );
      self.infState.set( .REVENUE, inf, 0.0 );

      self.infState.set( .USE_LVL, inf, 0.0 );
    }
    inline for( 0..indTypeC )| d |
    {
      const ind = IndType.fromIdx( d );

      self.indState.set( .DELTA,    ind, 0.0 );

      self.indState.set( .DECAY,    ind, 0.0 );
      self.indState.set( .BUILT,    ind, 0.0 );

      self.indState.set( .EXPENSE,  ind, 0.0 );
      self.indState.set( .REVENUE,  ind, 0.0 );
      self.indState.set( .PROFIT,   ind, 0.0 );

    //self.indState.set( .ACT_TRGT, ind, 0.0 ); // NOTE : DO NOT ZERO OUT : Cross-tick signal
      self.indState.set( .ACT_LVL,  ind, 0.0 );
    }
  }


  inline fn tickEcology( self : *Economy ) void
  {
    if( !self.hasEcology() ){ return; }

    if( self.ecology != null )
    {
      self.ecology.?.update( self );
    }
    else
    {
      def.qlog( .WARN, 0, @src(), "Cannot tick ecology : uninitialized" );
    }
  }

  inline fn calcBuildDemand( self : *Economy ) void
  {
    if( self.buildQueue != null )
    {
      const assemblyCount = self.infState.get( .BANK, .ASSEMBLY );
      const assemblyRate  = InfType.ASSEMBLY.getMetric_f64( .CAPACITY );
      const assemblyCap   = @ceil( assemblyCount * assemblyRate );

      // Demand is what the queue needs, but capped by what assemblies can process
      self.buildDemand = @min( self.buildQueue.?.getTotalPartCost(), assemblyCap );
    }
    else
    {
      self.buildDemand = 0.0;
    }
  }

  inline fn tickBuildQueue( self : *Economy ) void
  {
    if( self.buildQueue != null )
    {
      self.buildQueue.?.update( self );
    }
    else
    {
      def.qlog( .WARN, 0, @src(), "Cannot tick build queue : uninitialized" );
    }
  }

  inline fn updateInfUsage( self : *Economy ) void
  {
    // ASSEMBLY
    // NOTE : updated by econBuilder

    // HOUSING
    const popCount : f64 = @floatFromInt( self.getPopCount() );
    const popCap   : f64 = @floatFromInt( self.getPopCap()   );

    self.infState.set( .USE_LVL, .HOUSING, popCount / popCap );


    // HABITAT
    const areaUsed : f64 = self.areaMetrics.get( .USED );
    const areaCap  : f64 = self.areaMetrics.get( .CAP  );

    self.infState.set( .USE_LVL, .HABITAT, areaUsed / areaCap );


    // STORAGE
    var maxStorageUsage : f64 = 0.0;

    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      const resCount : f64 = @floatFromInt( self.getResCount( resType ));
      const resCap   : f64 = @floatFromInt( self.getResCap(   resType ));

      maxStorageUsage = @max( maxStorageUsage, resCount / resCap );
    }

    self.infState.set( .USE_LVL, .STORAGE, maxStorageUsage );
  }

  pub fn debugAutoBuild( self : *Economy ) void
  {

    if( self.buildQueue.?.getEntryCount() < 32 )
    {
      if( self.infState.get( .USE_LVL, .ASSEMBLY ) > 0.95 )
      {
        _ = self.buildQueue.?.addEntry( .{ .inf = .ASSEMBLY }, 2 );
      }
      if( self.infState.get( .USE_LVL, .HOUSING ) > 0.95 )
      {
        _ = self.buildQueue.?.addEntry( .{ .inf = .HOUSING }, 2 );
      }

      if( self.infState.get( .USE_LVL, .HABITAT ) > 0.95 )
      {
        _ = self.buildQueue.?.addEntry( .{ .inf = .HABITAT }, 2 );
      }

      if( self.infState.get( .USE_LVL, .STORAGE ) > 0.95 )
      {
        _ = self.buildQueue.?.addEntry( .{ .inf = .STORAGE }, 2 );
      }

      if( self.resState.get( .GEN_ACS, .FOOD ) < 1.2 )
      {
        if( self.resState.get( .GEN_ACS, .POWER ) < 1.6 and self.resState.get( .GEN_ACS, .WATER ) > 1.2 )
        {
          _ = self.buildQueue.?.addEntry( .{ .ind = .AGRONOMIC   }, 2 );
        }
        else
        {
          _ = self.buildQueue.?.addEntry( .{ .ind = .HYDROPONIC  }, 2 );
        }
      }

      if( self.resState.get( .GEN_ACS, .WATER ) < 1.2 )
      {
        _ = self.buildQueue.?.addEntry( .{ .ind = .WATER_PLANT }, 2 );
      }

      if( self.resState.get( .GEN_ACS, .POWER ) < 1.5 )
      {
        _ = self.buildQueue.?.addEntry( .{ .ind = .SOLAR_PLANT }, 4 );
      }

      if( self.resState.get( .GEN_ACS, .WORK ) > 0.98 )
      {
        if( self.resState.get( .GEN_ACS, .ORE ) < 1.0 )
        {
          _ = self.buildQueue.?.addEntry( .{ .ind = .GROUND_MINE }, 8 );
        }
        else
        {
          _ = self.buildQueue.?.addEntry( .{ .ind = .REFINERY }, 6 );
        }
        if( self.resState.get( .GEN_ACS, .INGOT ) > 1.0 )
        {
          _ = self.buildQueue.?.addEntry( .{ .ind = .FACTORY }, 4 );
        }
      }
    }
  }

  pub fn tryTick( self : *Economy, sunshine : f64 ) bool
  {
    if( !self.isValid ){  return false; }
    if( !self.isActive ){ return false; }

    self.stepCount += 1;

    self.updateSunshine( sunshine );
    self.tickEcon();

    return true;
  }

  pub fn tickEcon( self : *Economy ) void
  {
    self.updateResCaps();
    self.updateAreas();

    self.tickEcology();
    self.calcBuildDemand();
    ecnSlvr.resolveEcon( self );
    self.tickBuildQueue();

    self.updateInfUsage();

    // NOTE : DEBUG SECTION
    self.debugAutoBuild();

    self.logAllMetrics();
  }
};