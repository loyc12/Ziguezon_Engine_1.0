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
const PopType  = gdf.PopType;
const InfType  = gdf.InfType;
const IndType  = gdf.IndType;

const powerSrcC = PowerSrc.count;
const vesTypeC  = VesType.count;
const resTypeC  = ResType.count;
const popTypeC  = PopType.count;
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

  ecology   : ?Ecology  = null,

  buildQueue  : ?BuildQueue = null,
  buildDemand : f64 = 0.0,  // PART demand from construction queue this tick
  buildBudget : f64 = 0.0,  // PART allocation granted by solver

  areaMetrics : gdf.ecnm_d.AreaMetricData = .{},
  resState    : gdf.rsrc_d.ResStateData   = .{},
  popState    : gdf.popl_d.PopStateData   = .{},
  infState    : gdf.nfrs_d.InfStateData   = .{},
  indState    : gdf.ndst_d.IndStateData   = .{},

  inflationRate : f64 = 1.0, // TODO : update this bse on growth/decay of economy

  avgPopFulfilment : f64 = 0.0,
  avgInfUsage      : f64 = 0.0,
  avgIndActivity   : f64 = 0.0,
  avgResAccess     : f64 = 0.0,


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
    self.resState.fillWith(    0.0 );
    self.popState.fillWith(    0.0 );
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

  // Setups the economy needed to support value * 10k pop
  pub inline fn debugSetEconState( self : *Economy, value : u64 ) void
  {
    self.setPopCount( .HUMAN, value * 10_000 );
    self.debugSetIndCounts( value );
    self.debugSetInfCounts( value );
    self.debugSetResCounts( value );
  }


  // ================================ RESSOURCES ================================

  pub fn updateResCaps( self : *Economy ) void
  {
    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );
      const infType = resType.getInfStore();

      const infCount = self.infState.get( .COUNT, infType );
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
    return @intFromFloat( self.resState.get( .COUNT, resType ));
  }

  pub inline fn setResCount( self : *Economy, resType : ResType, value : u64 ) void
  {
    const cap = self.getResCap( resType );
    self.resState.set( .COUNT, resType, @floatFromInt( @min( value, cap )));
  }
  pub inline fn addResCount( self : *Economy, resType : ResType, value : u64 ) void
  {
    const cap     = self.getResCap(   resType );
    const current = self.getResCount( resType );
    const new_val = @min( value + current, cap );
    self.resState.set( .COUNT, resType, @floatFromInt( new_val ));
  }
  pub inline fn subResCount( self : *Economy, resType : ResType, value : u64 ) void
  {
    const current = self.getResCount( resType );
    const count   = @min( value, current );
    self.resState.set( .COUNT, resType, @floatFromInt( current - count ));

    if( value != count )
    {
      def.log( .WARN, 0, @src(), "@ Tried to remove {d} res of type {s} from economy, but only had {d} left", .{ value, @tagName( resType ), count });
    }
  }


  pub inline fn debugSetResCounts(  self : *Economy, value : u64 ) void
  {
    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      var amount : u64 = 1_000;
      if( resType == .WORK ){ amount *= 10; }

      self.resState.set( .COUNT, resType, @floatFromInt( value * amount ));
    }
  }

  pub inline fn logResMetrics( self : *const Economy ) void
  {
    def.qlog( .INFO, 0, @src(), "$ Logging resources metrics :" );
    def.qlog( .CONT, 0, @src(), "RESOURCE\t: Count\t ( Access )\t[ Delta\t| Prod\tCons\t| Decay\t| Demand ]" );
    def.qlog( .CONT, 0, @src(), "====================================================================================================" );

    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      const resCount  : f64 = self.resState.get( .COUNT,    resType );
      const resDelta  : f64 = self.resState.get( .DELTA,    resType );
      const resProd   : f64 = self.resState.get( .GEN_PROD, resType );
      const resCons   : f64 = self.resState.get( .GEN_CONS, resType );
    //const resGrowth : f64 = self.resState.get( .GROWTH,   resType );
      const resDecay  : f64 = self.resState.get( .DECAY,    resType );
      const resReq    : f64 = self.resState.get( .MAX_DEM,  resType );
      const resAccess : f64 = self.resState.get( .GEN_ACS,  resType );

      def.log( .CONT, 0, @src(), "{s}  \t: {d:.0}\t ( {d:.6} )\t[ {d:.0}\t| +{d:.0}\t-{d:.0}\t| -{d:.0}\t| {d:.0}\t ]",
        .{ @tagName( resType ), resCount, resAccess, resDelta, resProd, resCons, resDecay, resReq });
    }
  }


  // ================================ INFRASTRUCTURE ================================

  pub inline fn getInfCount( self : *const Economy, infType : InfType ) u64
  {
    return @intFromFloat( self.infState.get( .COUNT, infType ));
  }
  pub inline fn setInfCount( self : *Economy, infType : InfType, value : u64 ) void
  {
    self.infState.set( .COUNT, infType, @floatFromInt( value ));
  }
  pub inline fn addInfCount( self : *Economy, infType : InfType, value : u64 ) void
  {
    const current = self.getInfCount( infType );
    self.infState.set( .COUNT, infType, @floatFromInt( value + current ));
  }
  pub inline fn subInfCount( self : *Economy, infType : InfType, value : u64 ) void
  {
    const current = self.getInfCount( infType );
    const count   = @min( value, current );
    self.infState.set( .COUNT, infType, @floatFromInt( current - count ));

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
    self.infState.set( .COUNT, .HOUSING,  @floatFromInt( value * 320 ));
    self.infState.set( .COUNT, .HABITAT,                           0  );
    self.infState.set( .COUNT, .STORAGE,  @floatFromInt( value *  40 ));
    self.infState.set( .COUNT, .ASSEMBLY, @floatFromInt( value *  40 ));

    self.updateResCaps();
    self.updatePopCaps();
  }

  pub inline fn logInfMetrics( self : *const Economy ) void
  {
    def.qlog( .INFO, 0, @src(), "$ Logging infrastructure metrics :" );

    inline for( 0..infTypeC )| f |
    {
      const infType = InfType.fromIdx( f );

      const infCount : f64 = self.infState.get( .COUNT,   infType );
      const infDelta : f64 = self.infState.get( .DELTA,   infType );
      const infUse   : f64 = self.infState.get( .USE_LVL, infType ) * 100.0;
      const infBonus : f64 = infCount * infType.getMetric_f64( .CAPACITY );

      def.log( .CONT, 0, @src(), "{s}\t: {d:.0}\t( +{d:.0}\t) [ {d:.0} ] \t{d:.1}%", .{ @tagName( infType ), infCount, infBonus, infDelta, infUse });
    }
  }


  // ================================ INDUSTRY ================================

  pub inline fn getIndCount( self : *const Economy, indType : IndType ) u64
  {
    return @intFromFloat( self.indState.get( .COUNT, indType ));
  }
  pub inline fn setIndCount( self : *Economy, indType : IndType, value : u64 ) void
  {
    self.indState.set( .COUNT, indType, @floatFromInt( value ));
  }
  pub inline fn addIndCount( self : *Economy, indType : IndType, value : u64 ) void
  {
    const current = self.getIndCount( indType );
    self.indState.set( .COUNT, indType, @floatFromInt( current + value ));
  }
  pub inline fn subIndCount( self : *Economy, indType : IndType, value : u64 ) void
  {
    const current = self.getIndCount( indType );
    const count   = @min( value, current );
    self.indState.set( .COUNT, indType, @floatFromInt( current - count ));

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
    self.indState.set( .COUNT, .AGRONOMIC,   @floatFromInt( value * 10 ));
    self.indState.set( .COUNT, .HYDROPONIC,  @floatFromInt( value * 10 ));
    self.indState.set( .COUNT, .WATER_PLANT, @floatFromInt( value * 10 ));
    self.indState.set( .COUNT, .SOLAR_PLANT, @floatFromInt( value * 10 ));
    self.indState.set( .COUNT, .POWER_PLANT, @floatFromInt( value * 10 ));

    self.indState.set( .COUNT, .REFINERY,    @floatFromInt( value *  5 ));
    self.indState.set( .COUNT, .PROBE_MINE,                          0  );
    self.indState.set( .COUNT, .GROUND_MINE, @floatFromInt( value * 10 ));
    self.indState.set( .COUNT, .FOUNDRY,     @floatFromInt( value * 10 ));
    self.indState.set( .COUNT, .FACTORY,     @floatFromInt( value * 10 ));
  }

  pub inline fn logIndMetrics( self : *const Economy ) void
  {
    def.qlog( .INFO, 0, @src(), "$ Logging industrial metrics :" );

    inline for( 0..indTypeC )| d |
    {
      const indType = IndType.fromIdx( d );

      const indCount : f64 = self.indState.get( .COUNT,   indType );
      const indDelta : f64 = self.indState.get( .DELTA,   indType );
      const indRatio : f64 = self.indState.get( .ACT_LVL, indType );

      def.log( .CONT, 0, @src(), "{s}\t: {d:.0}\t( {d:.4} )\t[ {d:.0} ]", .{ @tagName( indType ), indCount, indRatio, indDelta });
    }
  }


  // ================================ POPULATION ================================

  pub fn getTotalPopCap( self : *const Economy ) u64
  {
    var totalCap : u64 = 0;

    inline for( 0..popTypeC )| p |
    {
      const popType = PopType.fromIdx( p );

      totalCap += self.getPopCap( popType );
    }

    return totalCap;
  }
  pub inline fn getTotalPopCount( self : *const Economy ) u64
  {
    var totalCount : u64 = 0;

    inline for( 0..popTypeC )| p |
    {
      const popType = PopType.fromIdx( p );

      totalCount += self.getPopCount( popType );
    }

    return totalCount;
  }

  pub fn updatePopCaps( self : *Economy ) void
  {
    inline for( 0..popTypeC )| r |
    {
      const popType = PopType.fromIdx( r );
      const popCost = popType.getMetric_f64( .HSNG_COST );

      const infType  = popType.getInfStore();
      const capacity = infType.getMetric_f64( .CAPACITY );
      const infCount = self.infState.get( .COUNT, infType );

      self.popState.set( .LIMIT, popType, infCount * capacity / popCost );
    }
  }
  pub inline fn getPopCap( self : *const Economy, popType : PopType ) u64
  {
    return @intFromFloat( self.popState.get( .LIMIT, popType ));
  }
  pub inline fn getPopCount( self : *const Economy, popType : PopType ) u64
  {
    return @intFromFloat( self.popState.get( .COUNT, popType ));
  }

  /// Ignores popCap
  pub inline fn setPopCount( self : *Economy, popType : PopType, value : u64 ) void
  {
    self.popState.set( .COUNT, popType, @floatFromInt( value ));
  }
  pub inline fn addPopCount( self : *Economy, popType : PopType, value : u64 ) void
  {
    const cap      = self.getPopCap(   popType );
    const oldCount = self.getPopCount( popType );
    const newCount = @min( value +| oldCount, cap );

    if( newCount - oldCount != value )
    {
      def.log( .WARN, 0, @src(), "@ Tried to add {d} pops to economy, but only had space for {d}", .{ value, newCount - oldCount });
    }
    self.setPopCount( popType, newCount );
  }
  pub inline fn subPopCount( self : *Economy, popType : PopType, value : u64 ) void
  {
    const oldCount = self.getPopCount( popType );
    const newCount = @max( oldCount -| value, 0 ); // Writen like this for clarity

    if( oldCount - newCount != value )
    {
      def.log( .WARN, 0, @src(), "@ Tried to remove {d} pops from economy, but only had {d} left", .{ value, oldCount - newCount });
    }
    self.setPopCount( popType, newCount );
  }


  pub fn logPopMetrics( self : *const Economy ) void
  {
    def.qlog( .INFO, 0, @src(), "$ Logging population metrics : " );

    inline for( 0..popTypeC )| p |
    {
      const popType  = PopType.fromIdx( p );

      const popCount  : f64 = self.popState.get( .COUNT,   popType );
      const popCap    : f64 = self.popState.get( .LIMIT,   popType );
      const popDelta  : f64 = self.popState.get( .DELTA,   popType );
      const popAccess : f64 = self.popState.get( .FLM_LVL, popType );

      def.log(  .CONT, 0, @src(), "{s}\t: {d:.0}\t/ {d:.0}\t[ {d:.0} ]\t( {d:.3} )", .{ @tagName( popType ), popCount, popCap, popDelta, popAccess });
    }

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
      def.log( .WARN, 0, @src(), "Negative available area in location of type {s} : using {d:.2} / {d:.2}", .{ @tagName( self.location ), areaUsed, areaCap });
      self.areaMetrics.zero( .AVAIL );
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
      const availParts  = self.resState.get( .COUNT, .PART );
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
      self.resState.sub( .COUNT,     .PART, totalCost );
      self.resState.add( .GEN_CONS, .PART, totalCost );
    }

    builtAmount = @floor( builtAmount );

    switch( c )
    {
      .inf => | infType |
      {
        self.infState.add( .COUNT,  infType, builtAmount );
        self.infState.add( .BUILT, infType, builtAmount );
        self.infState.add( .DELTA, infType, builtAmount );
      },
      .ind => | indType |
      {
        self.indState.add( .COUNT,  indType, builtAmount );
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

  //self.logResMetrics();
    self.logInfMetrics();
  //self.logIndMetrics();
  //self.logTravelMetrics_TERRA();
    self.logPopMetrics();

    const areaUsed = self.areaMetrics.get( .USED );
    const areaCap  = self.areaMetrics.get( .CAP  );

    def.qlog( .INFO, 0, @src(), "$ Logging general metrics" );
    def.log(  .CONT, 0, @src(), "Steps done   : {d:.6}", .{ self.stepCount });
    def.log(  .CONT, 0, @src(), "Sun access   : {d:.6}", .{ self.sunAccess });
    def.log(  .CONT, 0, @src(), "Eco factor   : {d:.6}", .{ self.getEcoFactor() });

    def.log(  .CONT, 0, @src(), "Development  : {d:.0} / {d:.0} ( {d:.2}% )", .{ areaUsed, areaCap, ( areaUsed / areaCap) * 100.0 });

    if( self.buildQueue != null )
    {
      def.log(  .CONT, 0, @src(), "Build queue  : {d} ( {d} )", .{ self.buildQueue.?.getEntryCount(), self.buildQueue.?.getTotalBuildCount() });
    }
  }

  // TODO : generalize this function
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

  inline fn updateEcology( self : *Economy ) void
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

  inline fn applyInflation( self : *Economy ) void
  {
    inline for( 0..indTypeC )| d |
    {
      const indType = IndType.fromIdx( d );
      const baseCapital = self.indState.get( .CAPITAL, indType );

      if( baseCapital > def.EPS )
      {
        self.indState.sub( .CAPITAL, indType, baseCapital * self.inflationRate );
      }

      // TODO : also apply inflation to inf, pop and gov
    }
  }

  inline fn calcBuildDemand( self : *Economy ) void
  {
    if( self.buildQueue != null )
    {
      const assemblyCount = self.infState.get( .COUNT, .ASSEMBLY );
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
    inline for( 0..infTypeC )| f |
    {
      const infType = InfType.fromIdx( f );

      self.infState.zero( .DELTA, infType );
      self.infState.zero( .BUILT, infType );
      self.infState.zero( .DECAY, infType );
    }
    inline for( 0..indTypeC )| d |
    {
      const indType = IndType.fromIdx( d );

      self.indState.zero( .DELTA, indType );
      self.indState.zero( .BUILT, indType );
      self.indState.zero( .DECAY, indType );
    }

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
    const popCount : f64 = @floatFromInt( self.getTotalPopCount() );
    const popCap   : f64 = @floatFromInt( self.getTotalPopCap()   );

    self.infState.set( .USE_LVL, .HOUSING, popCount / popCap );


    // HABITAT
    const areaUsed : f64 = self.areaMetrics.get( .USED );
    var   habUse   : f64 = 0.0;


    if( self.location != .GROUND or !self.hasAtmo )
    {
      // Non-ground or no-atmo : all area IS habitat area, use areaCap as fallback
      const areaCap : f64 = self.areaMetrics.get( .CAP  );

      if( areaCap > def.EPS )
      {
        habUse = @min( 1.0, areaUsed / areaCap );
      }
    }
    else
    {
      // Ground with Atmo : account for non-habitat area
      const habitatArea : f64 = self.getHabitatArea();

      if( habitatArea > def.EPS )
      {
        const landArea : f64 = self.areaMetrics.get( .LAND );

        // How much of the used area exceeds what free land provides?
        const areaOnHabitat = @max( 0.0, areaUsed - landArea );

        habUse = areaOnHabitat / habitatArea;
      }
    }
    self.infState.set( .USE_LVL, .HABITAT, habUse );

    // STORAGE
    var maxStoreUse : f64 = 0.0;

    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      if( resType != .WORK ) // TODO : update once multiple storage types exist
      {
        const resCount : f64 = @floatFromInt( self.getResCount( resType ));
        const resCap   : f64 = @floatFromInt( self.getResCap(   resType ));

        maxStoreUse = @max( maxStoreUse, resCount / resCap );
      }
    }
    self.infState.set( .USE_LVL, .STORAGE, maxStoreUse );


    // AVERAGING RATES
    self.avgInfUsage = 0.0;

    inline for( 0..infTypeC )| f |
    {
      const infType = InfType.fromIdx( f );

      // Accumulates average infrastructure usage rate
      self.avgInfUsage += self.infState.get( .USE_LVL, infType );
    }

    self.avgInfUsage /= @floatFromInt( infTypeC );
  }


  const AUTO_BUILD_SUPPLY_LIMIT : f64 = 42.0;

  pub fn debugAutoBuild( self : *Economy ) void
  {
    const popCount : f64 = self.popState.get( .COUNT, .HUMAN );

    if( self.buildQueue.?.getEntryCount() < 32 )
    {
      for( 0..infTypeC )| f |
      {
        const infType       = InfType.fromIdx( f );
        const useLvl  : f64 = self.infState.get( .USE_LVL, infType );
        const useTrsh : f64 = 0.75; // 0.0 - 1.0

        // Scale build amount: at ACT_TRGT 0.75 build 0, at 1.0 build full amount
        if( useLvl > useTrsh )
        {
          const scale  : f64 = @min( 2.0, ( useLvl - useTrsh) / ( 1.0 - useTrsh )); // 0.0 to 1.0
          const amount : f64 = scale * popCount / 10_000;

          _ = self.buildQueue.?.addEntry( .{ .inf = infType }, @intFromFloat( @ceil( amount )));
        }
      }

      for( 0..indTypeC )| d |
      {
        const indType = IndType.fromIdx( d );

        if( indType.canBeBuiltIn( self.location, self.hasAtmo ))
        {
          const actTrgt : f64 = self.indState.get( .ACT_TRGT, indType );
          const actTrsh : f64 = 0.75; // 0.0 - 1.0

          // Check if this industry's output is already oversupplied
          var outputOversupplied = false; // NOTE : this feels very artificial as a limit

          inline for( 0..resTypeC )| r |
          {
            const resType = ResType.fromIdx( r );
            const prod    = indType.getResProd_f64( resType );

            if( prod > def.EPS )
            {
              const access = self.resState.get( .GEN_ACS, resType );
              if( access > AUTO_BUILD_SUPPLY_LIMIT ) outputOversupplied = true;
            }
          }

          // Scale build amount: at ACT_TRGT 0.75 build 0, at 1.0 build full amount
          if( actTrgt > actTrsh and !outputOversupplied )
          {
            const scale  : f64 = @min( 2.0, ( actTrgt - actTrsh ) / ( 1.0 - actTrsh )); // 0.0 to 1.0
            const amount : f64 = scale * popCount / 10_000;

            _ = self.buildQueue.?.addEntry( .{ .ind = indType }, @intFromFloat( @ceil( amount )));
          }
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
    // Metric updating
    self.updateResCaps();
    self.updatePopCaps();
    self.updateAreas();
    self.updateInfUsage(); // Depends on Area, tickBuildQueue()
    self.updateEcology();  // Depends on infUsage

    // Economic tick
    self.applyInflation();
    self.calcBuildDemand();
    ecnSlvr.resolveEcon( self );
    self.tickBuildQueue();

    // Debug Actions
    self.debugAutoBuild();
    self.logAllMetrics();
  }
};