const std = @import( "std" );
const def = @import( "defs" );


pub const ecnSlvr = @import( "econSolver.zig"  );
pub const ecnBldr = @import( "econBuilder.zig" );
pub const cst     = @import( "construct.zig"   );

pub const BuildQueue    = ecnBldr.BuildQueue;
pub const Construct     = @import( "construct.zig" ).Construct;


const gbl = @import( "../gameGlobals.zig" );

const EconLoc  = gbl.EconLoc;

const PowerSrc = gbl.PowerSrc;
const VesType  = gbl.VesType;
const ResType  = gbl.ResType;
const InfType  = gbl.InfType;
const IndType  = gbl.IndType;

const powerSrcC = PowerSrc.count;
const vesTypeC  = VesType.count;
const resTypeC  = ResType.count;
const infTypeC  = InfType.count;
const indTypeC  = IndType.count;



const POLLUTION_PER_POP     =   1.0;
const MIN_RES_CAP           = 100.0;
const MAX_SUN_ACCESS_CAP    =   1.0;
const SUN_SHORTAGE_EXPONENT =   2.0;


pub const Economy = struct
{
  pub inline fn getStoreType() type { return def.componentStoreFactory( @This() ); }

  location  : EconLoc,
  isActive  : bool = false,
  dayCount  : u64  = 0,

  hasAtmo   : bool,
  sunshine  : f64 = 0.0,
  sunAccess : f32 = 1.0,

  buildQueue  : ?BuildQueue = null,

  areaMetrics : gbl.ecnm_d.AreaMetricData = .{},
  popMetrics  : gbl.ecnm_d.PopMetricData  = .{},
  resState    : gbl.rsrc_d.ResStateData   = .{},
  infState    : gbl.nfrs_d.InfStateData   = .{},
  indState    : gbl.ndst_d.IndStateData   = .{},

  avgIndActivity : f64 = 0.0,
  avgResAccess   : f64 = 0.0,

  pub inline fn newEcon( loc : EconLoc, area : f64, landCover : f64, atmo : bool ) Economy
  {
    var econ : Economy = .{ .location = loc, .hasAtmo = atmo, .isActive = true };

    econ.areaMetrics.set( .BODY,  area      );
    econ.areaMetrics.set( .INHAB, landCover );

    inline for( 0..resTypeC )| r |
    {
      econ.resState.set( .CAP, ResType.fromIdx( r ), MIN_RES_CAP );
    }

    econ.buildQueue = BuildQueue.init();

    return econ;
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

      self.resState.set( .CAP, resType, MIN_RES_CAP + ( infCount * capacity ));
    }
  }
  pub inline fn getResCap( self : *const Economy, resType : ResType ) u64
  {
    return @intFromFloat( self.resState.get( .CAP, resType ));
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

  pub inline fn logResCounts( self : *const Economy ) void
  {
    def.qlog( .INFO, 0, @src(), "Logging resources :" );
    def.qlog( .CONT, 0, @src(), "RESOURCE\t: Bank\t/ Cap\t ( Access )\t[ Delta\t| Prod\tCons\t| Grow\tDecay\t| Demand ]" );
    def.qlog( .CONT, 0, @src(), "====================================================================================================" );

    inline for( 0..resTypeC )| r |
    {
      const resType = ResType.fromIdx( r );

      const resCount  : u64 = @intFromFloat( self.resState.get( .BANK,     resType ));
      const resCap    : u64 = @intFromFloat( self.resState.get( .CAP,      resType ));
      const resDelta  : i64 = @intFromFloat( self.resState.get( .DELTA,    resType ));
      const resProd   : u64 = @intFromFloat( self.resState.get( .FIN_PROD, resType ));
      const resCons   : u64 = @intFromFloat( self.resState.get( .FIN_CONS, resType ));
      const resGrowth : u64 = @intFromFloat( self.resState.get( .GROWTH,   resType ));
      const resDecay  : u64 = @intFromFloat( self.resState.get( .DECAY,    resType ));
      const resReq    : u64 = @intFromFloat( self.resState.get( .MAX_DEM,  resType ));
      const resAccess : f32 = @floatCast(    self.resState.get( .SAT_LVL,  resType ));

      def.log( .CONT, 0, @src(), "{s}  \t: {d}\t/ {d}\t ( {d:.4} )\t[ {d}\t| +{d}\t-{d}\t| +{d}\t-{d}\t| {d}\t ]",
        .{ @tagName( resType ), resCount, resCap, resAccess, resDelta, resProd, resCons, resGrowth, resDecay, resReq });
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
    self.infState.set( .BANK, .HOUSING, @floatFromInt( value * 100 ));
    self.infState.set( .BANK, .HABITAT,                        0.0  );
    self.infState.set( .BANK, .STORAGE, @floatFromInt( value * 100 ));
  }

  pub inline fn logInfCounts( self : *const Economy ) void
  {
    def.qlog( .INFO, 0, @src(), "Logging infrastructure :" );

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
    self.indState.set( .BANK, .SOLAR_PLANT, @floatFromInt( value * 100 ));

    self.indState.set( .BANK, .PROBE_MINE,                         0.0  );
    self.indState.set( .BANK, .GROUND_MINE, @floatFromInt( value * 200 ));
    self.indState.set( .BANK, .REFINERY,    @floatFromInt( value * 100 ));
    self.indState.set( .BANK, .FACTORY,     @floatFromInt( value * 50  ));
    self.indState.set( .BANK, .ASSEMBLY,    @floatFromInt( value * 25  ));
  }

  pub inline fn logIndCounts( self : *const Economy ) void
  {
    def.qlog( .INFO, 0, @src(), "Logging industry :" );

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
    self.popMetrics.set( .COUNT, @floatFromInt( new_val ));
  }
  pub inline fn subPopCount( self : *Economy, value : u64 ) void
  {
    const current = self.getPopCount();
    const count   = @min( value, current );
    self.popMetrics.set( .COUNT, @floatFromInt( current - count ));

    if( value != count )
    {
      def.log( .WARN, 0, @src(), "@ Tried to remove {d} pops of from economy, but only had {d} left", .{ value, count });
    }
  }


  pub fn logPopCount( self : *const Economy ) void
  {
    const popCount  : u64 = @intFromFloat( self.popMetrics.get( .COUNT  ));
    const popDelta  : i64 = @intFromFloat( self.popMetrics.get( .DELTA  ));
    const popAccess : f64 =                self.popMetrics.get( .ACCESS );

    def.log( .INFO, 0, @src(), "Population\t: {d}\t/ {d}\t[ {d} ]\t( {d:.3} )", .{ popCount, self.getPopCap(), popDelta, popAccess });
  }


  // ================================ SUNSHINE ================================

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


  pub fn getEcologyFactor( self : *const Economy ) f32
  {
    if( self.location != .GROUND or !self.hasAtmo ){ return 0.0; }

    const popCount : u64 = @intFromFloat( self.popMetrics.get( .COUNT ));

    var averageActivity : f64 = 0.0;
    var pollutionAmount : f64 = @floatFromInt( popCount );
        pollutionAmount      *= POLLUTION_PER_POP;

    for( 0..indTypeC )| d |
    {
      const activity = self.indState.get( .ACT_LVL, IndType.fromIdx( d ));
      const indType  = IndType.fromIdx( d );

      var tmp  = indType.getMetric_f64( .POLLUTION );
          tmp *= self.indState.get( .BANK, indType );
          tmp *= activity;

      pollutionAmount += tmp;
      averageActivity += activity;
    }

    averageActivity /= indTypeC;

    for( 0..infTypeC )| f |
    {
      const infType = InfType.fromIdx( f );

      var tmp  = infType.getMetric_f64( .POLLUTION );
          tmp *= self.infState.get( .BANK, infType );
          tmp *= averageActivity;

      pollutionAmount += tmp;
    }

    pollutionAmount *= 100.0;

    const landArea      : f64 = self.areaMetrics.get( .LAND );
    const developedArea : f64 = self.areaMetrics.get( .USED );

    const pollutionRatio   : f32 = @floatCast( def.clmp( pollutionAmount / @max( landArea, 1.0 ), 0.0, 1.0 ));
    const developmentRatio : f32 = @floatCast( def.clmp( developedArea   / landArea,              0.0, 1.0 ));

    const ecologyRatio = ( 1.0 - developmentRatio ) * ( 1.0 - pollutionRatio );

  //def.qlog( .INFO, 0, @src(), "Loggin ecology :" );
  //def.log(  .CONT, 0, @src(), "Pollution  amount\t: {d}",    .{ pollutionAmount  });
  //def.log(  .CONT, 0, @src(), "Pollution   ratio\t: {d:.6}", .{ pollutionRatio   });
  //def.log(  .CONT, 0, @src(), "Development ratio\t: {d:.6}", .{ developmentRatio });
  //def.log(  .CONT, 0, @src(), "Ecology    factor\t: {d:.6}", .{ ecoFactor        });

    return def.clmp( ecologyRatio, 0.000001, 1.0 );
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



  // ================================ ECONOMY ================================

//pub inline fn getMaxTotResCons( self : *const Economy, resType : ResType ) u64
//{
//  var maxCons : u64 = 0;
//
//  maxCons += self.getMaxPopResCons( resType );
//  maxCons += self.getMaxIndResCons( resType );
//
//  return maxCons;
//}
//
//pub inline fn getMaxPopResCons( self : *const Economy, resType : ResType ) u64
//{
//  return @intFromFloat( self.popCount * resType.getMetric_f32( .POP_CONS ));
//}
//
//pub inline fn getMaxIndResCons( self : *const Economy, resType : ResType ) u64
//{
//  var maxCons : u64 = 0;
//
//  inline for( 0..indTypeC )| d |{ if( self.indBank[ d ] != 0 ) // Skips absent industries
//  {
//    const indType = IndType.fromIdx( d );
//
//    maxCons += self.indBank[ d ] * indType.getResProd( resType );
//
//    if( indType.getPowerSrc() == .SOLAR ) // Limits activity based on available sunshine
//    {
//      const factor = self.sunAccess;
//
//      const maxCons_f32 : f64 = @floatFromInt( maxCons );
//      maxCons = @intFromFloat( @floor( maxCons_f32 * factor ));
//    }
//  }}
//
//  return maxCons;
//}
//
//
//pub inline fn getMaxTotResProd( self : *const Economy, resType : ResType ) u64
//{
//  var maxProd : u64 = 0;
//
//  maxProd += self.getMaxPopResProd( resType );
//  maxProd += self.getMaxIndResProd( resType );
//
//  return maxProd;
//}
//
//pub inline fn getMaxPopResProd( self : *const Economy, resType : ResType ) u64
//{
//  return @intFromFloat( self.popCount * resType.getMetric_f32( .POP_PROD ));
//}
//
//pub inline fn getMaxIndResProd( self : *const Economy, resType : ResType ) u64
//{
//  var maxProd : u64 = 0;
//
//  inline for( 0..indTypeC )| d |{ if( self.indBank[ d ] != 0 ) // Skips absent industries
//  {
//    const indType = IndType.fromIdx( d );
//
//    maxProd += self.indBank[ d ] * indType.getResProd( resType );
//
//    if( indType.getPowerSrc() == .SOLAR ) // Limits activity based on available sunshine
//    {
//      const factor = @min( self.getSunshineAccess(), 1.0 );
//
//      const maxProd_f32 : f64 = @floatFromInt( maxProd );
//      maxProd = @intFromFloat( @floor( maxProd_f32 * factor ));
//    }
//  }}
//
//  return maxProd;
//}


  // ================================ CONSTRUCTION ================================

pub inline fn tryBuild( self : *Economy, c : Construct, amount : f64 ) f64
  {
    if( !c.canBeBuiltIn( self.location, self.hasAtmo ))
    {
      def.qlog( .WARN, 0, @src(), "Invalid location conditions : aborting" );
      return 0;
    }

    const availParts  = self.resState.get( .BANK, .PART );
    const partCost    = c.getPartCost();
    const areaCost    = c.getAreaCost();

    var builtAmount = amount;

    if( availParts < partCost )
    {
      def.qlog( .WARN, 0, @src(), "Not enough parts for a single unit : aborting" );
      return 0;
    }
    if( availParts < builtAmount * partCost )
    {
      def.qlog( .WARN, 0, @src(), "Not enough parts : adjusting amount" );
      builtAmount = availParts / partCost;
    }

    if( !std.meta.eql( c, .{ .inf = .HABITAT }))
    {
      const areaAvail = self.areaMetrics.get( .AVAIL );

      if( areaAvail < areaCost )
      {
        def.qlog( .WARN, 0, @src(), "Not enough area for a single unit : aborting" );
        return 0;
      }
      if( areaAvail < builtAmount * areaCost )
      {
        def.qlog( .WARN, 0, @src(), "Not enough area : adjusting amount" );
        builtAmount = areaAvail / areaCost;
      }
    }

    builtAmount = @floor( builtAmount );

    const totalCost   = @ceil( builtAmount * partCost );

    // Deduct parts
    self.resState.sub( .BANK,     .PART, totalCost );
    self.resState.add( .FIN_CONS, .PART, totalCost );

    switch( c )
    {
      .inf => | infType |
      {
        self.infState.add( .BANK,  infType, builtAmount );
        self.infState.add( .BUILT, infType, builtAmount );
      },
      .ind => | indType |
      {
        self.indState.add( .BANK,  indType, builtAmount );
        self.indState.add( .BUILT, indType, builtAmount );
      },
    //else =>
    //{
    //  // TODO : build vessels
    //},
    }

    return builtAmount;
  }


  // ================================ UPDATING ================================

  pub fn logMetrics( self : *const Economy ) void
  {
    def.qlog( .INFO, 0, @src(), "Logging general metrics");
    def.log(  .CONT, 0, @src(), "Day since settled : {d:.6}",     .{ self.dayCount });
    def.log(  .CONT, 0, @src(), "Sun access   : {d:.6}",          .{ self.sunAccess });
    def.log(  .CONT, 0, @src(), "Eco factor   : {d:.6}",          .{ self.getEcologyFactor() });
    def.log(  .CONT, 0, @src(), "Development  : {d:.0} / {d:.0}", .{ self.areaMetrics.get( .USED ), self.areaMetrics.get( .CAP ) });
    def.log(  .CONT, 0, @src(), "Build queue  : {d}",             .{ self.buildQueue.?.getEntryCount() });
  }

  pub fn calcDeltas( self : *const Economy ) void
  {
    _ = self;
    // TODO : sum all cons and prod into deltas for res, inf, and ind
  }

  pub fn resetCountMetrics( self : *Economy ) void
  {
    self.popMetrics.set( .DELTA, 0.0 );

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

      self.resState.set( .FIN_PROD, res, 0.0 );
      self.resState.set( .FIN_CONS, res, 0.0 );

      self.resState.set( .SAT_LVL,  res, 0.0 );
    }
    inline for( 0..infTypeC )| f |
    {
      const inf = InfType.fromIdx( f );

      self.infState.set( .DELTA,   inf, 0.0 );

      self.infState.set( .BUILT,   inf, 0.0 );
      self.infState.set( .DECAY,   inf, 0.0 );

      self.infState.set( .USE_LVL, inf, 0.0 );
    }
    inline for( 0..indTypeC )| d |
    {
      const ind = IndType.fromIdx( d );

      self.indState.set( .DELTA,   ind, 0.0 );

      self.indState.set( .BUILT,   ind, 0.0 );
      self.indState.set( .DECAY,   ind, 0.0 );

      self.indState.set( .ACT_LVL, ind, 0.0 );
    }
  }

  pub fn tickBuildQueue( self : *Economy ) void
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

  pub fn tickEcon( self : *Economy, newSunshine : f64 ) void
  {
    self.dayCount += 1;

    if( @mod( self.dayCount, 7 ) != 1 ){ return; } // Only tick econ at start of week

    self.updateResCaps();
    self.updateAreas();
    self.updateSunshine( newSunshine );

    ecnSlvr.resolveEcon( self );
    self.tickBuildQueue();

    self.calcDeltas();

    // NOTE : DEBUG SECTION
    self.logPopCount();
    self.logResCounts();
    self.logInfCounts();
    self.logIndCounts();
    self.logMetrics();


    if( self.buildQueue.?.getEntryCount() < 32 )
    {
      _ = self.buildQueue.?.addEntry( .{ .inf = .HOUSING     }, 2 );
      _ = self.buildQueue.?.addEntry( .{ .inf = .HABITAT     }, 4 );
      _ = self.buildQueue.?.addEntry( .{ .inf = .STORAGE     }, 4 );

      _ = self.buildQueue.?.addEntry( .{ .ind = .AGRONOMIC   }, 1 );
      _ = self.buildQueue.?.addEntry( .{ .ind = .HYDROPONIC  }, 1 );
      _ = self.buildQueue.?.addEntry( .{ .ind = .WATER_PLANT }, 2 );
      _ = self.buildQueue.?.addEntry( .{ .ind = .SOLAR_PLANT }, 4 );

      _ = self.buildQueue.?.addEntry( .{ .ind = .GROUND_MINE }, 8 );
      _ = self.buildQueue.?.addEntry( .{ .ind = .REFINERY    }, 4 );
      _ = self.buildQueue.?.addEntry( .{ .ind = .FACTORY     }, 2 );
      _ = self.buildQueue.?.addEntry( .{ .ind = .ASSEMBLY    }, 1 );

    }
  }
};