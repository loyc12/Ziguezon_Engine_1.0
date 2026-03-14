const std = @import( "std" );
const def = @import( "defs" );


pub const ecnSlvr = @import( "econSolver.zig"  );
pub const ecnBldr = @import( "econBuilder.zig" );
pub const ecnLoc  = @import( "econLoc.zig"     );
pub const cst     = @import( "construct.zig"   );

pub const BuildQueue    = ecnBldr.BuildQueue;
pub const econLocCount  = ecnLoc.econLocCount;
pub const EconLoc       = ecnLoc.EconLoc;
pub const Construct     = cst.Construct;


const gbl     = @import( "../gameGlobals.zig" );

const PowerSrc      = gbl.PowerSrc;
const VesType       = gbl.VesType;
const ResType       = gbl.ResType;
const InfType       = gbl.InfType;
const IndType       = gbl.IndType;

const PowerSrcCount = gbl.PowerSrcCount;
const vesTypeCount  = gbl.vesTypeCount;
const resTypeCount  = gbl.resTypeCount;
const infTypeCount  = gbl.infTypeCount;
const indTypeCount  = gbl.indTypeCount;


const POLLUTION_PER_POP     = 1.0;
const MIN_RES_CAP           = 100;
const MAX_SUN_ACCESS_CAP    = 1.0;
const SUN_SHORTAGE_EXPONENT = 2.0;


pub const Economy = struct
{
  pub inline fn getStoreType() type { return def.componentStoreFactory( @This() ); }

  location  : EconLoc,
  isActive  : bool = false,
  itrCount  : u64  = 0,

  hasAtmo   : bool,
  sunshine  : f64 = 0.0,
  sunAccess : f32 = 1.0,

  areaCap   : f64,
  areaMax   : f64 = 0.0,
  areaUsed  : f64 = 0.0,
  areaAvail : f64 = 0.0,
  landCover : f64 = 0.7,

  buildQueue : ?BuildQueue = null,

  popCount  : u64 = 0,
  popDelta  : i64 = 0,
  popAccess : f32 = 0.0,

  // TOOD : Consolidate some of these into a 2D array with enum for row ?

  resCap    : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),
  resBank   : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),
  resDelta  : [ resTypeCount ]i64 = std.mem.zeroes([ resTypeCount ]i64 ),
  resAccess : [ resTypeCount ]f32 = std.mem.zeroes([ resTypeCount ]f32 ),

  prevResCons   : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),
  prevResProd   : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),

  prevResDecay  : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),
  prevResGrowth : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),
  prevResReq    : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),

  infBank     : [ infTypeCount ]u64 = std.mem.zeroes([ infTypeCount ]u64 ),
  infDelta    : [ infTypeCount ]i64 = std.mem.zeroes([ infTypeCount ]i64 ),

  indBank     : [ indTypeCount ]u64 = std.mem.zeroes([ indTypeCount ]u64 ),
  indDelta    : [ indTypeCount ]i64 = std.mem.zeroes([ indTypeCount ]i64 ),
  indActivity : [ indTypeCount ]f32 = std.mem.zeroes([ indTypeCount ]f32 ),


  pub inline fn newEcon( loc : EconLoc, area : f64, atmo : bool ) Economy
  {
    var econ : Economy = .{ .location = loc, .areaCap = area, .hasAtmo = atmo, .isActive = true };

    inline for( 0..resTypeCount )| r |
    {
      econ.resCap[ r ] = MIN_RES_CAP;
    }

    econ.buildQueue = BuildQueue.init();

    return econ;
  }


  // ================================ RESSOURCES ================================

  pub fn updateResCaps( self : *Economy ) void
  {
    inline for( 0..resTypeCount )| r |
    {
      const resType = ResType.fromIdx( r );
      const infType = resType.getInfStore();

      self.resCap[ r ] = MIN_RES_CAP + self.infBank[ infType.toIdx() ] * infType.getMetric_u64( .CAPACITY );
    }
  }

  pub inline fn getResCap( self : *const Economy, resType : ResType ) u64
  {
    return self.resCap[ resType.toIdx() ];
  }
  pub inline fn setResCap( self : *Economy, resType : ResType, value : u64 ) void
  {
    self.resCap[ resType.toIdx() ] = value;
  }


  pub inline fn logResCounts(  self : *const Economy ) void
  {
    def.qlog( .INFO, 0, @src(), "Logging resources :" );
    def.qlog( .CONT, 0, @src(), "RESOURCE\t: Bank\t/ Cap\t ( Access )\t[ Delta\t| Prod\tCons\t| Grow\tDecay\t| Demand ]" );
    def.qlog( .CONT, 0, @src(), "====================================================================================================" );

    inline for( 0..resTypeCount )| r |
    {
      const resType   = ResType.fromIdx( r );

      const resCount  = self.resBank[ r ];
      const resCap    = self.resCap[  r ];

      const resDelta  = self.resDelta[ r ];

      const resProd   = self.prevResProd[ r ];
      const resCons   = self.prevResCons[ r ];

      const resGrowth = self.prevResGrowth[ r ];
      const resDecay  = self.prevResDecay[  r ];

      const resReq    = self.prevResReq[ r ];

      const resAccess = self.resAccess[ r ];

      def.log( .CONT, 0, @src(), "{s}  \t: {d}\t/ {d}\t ( {d:.4} )\t[ {d}\t| +{d}\t-{d}\t| +{d}\t-{d}\t| {d}\t ]",.{ @tagName( resType ), resCount, resCap, resAccess, resDelta, resProd, resCons, resGrowth, resDecay, resReq,  });
    }
  }
  pub inline fn getResCount( self : *const Economy, resType : ResType ) u64
  {
    return self.resBank[ resType.toIdx() ];
  }
  pub inline fn setResCount( self : *Economy, resType : ResType, value : u64 ) void
  {
    const cap = self.getResCap( resType );

    self.resBank[ resType.toIdx() ] = @min( value, cap );
  }
  pub inline fn addResCount( self : *Economy, resType : ResType, value : u64 ) void
  {
    const cap = self.getResCap( resType );
    const new = self.resBank[ resType.toIdx() ] + value;

    self.resBank[ resType.toIdx() ] = @min( new, cap );
  }
  pub inline fn subResCount( self : *Economy, resType : ResType, value : u64 ) void
  {
    const count = @min( value, self.resBank[ resType.toIdx() ]);

    self.resBank[ resType.toIdx() ] -= count;

    if( value != count )
    {
      def.log( .WARN, 0, @src(), "@ Tried to remove {d} res of type {s} from economy, but only had {d} left", .{ value, @tagName( resType ), count });
    }
  }

  pub inline fn debugSetResCounts(  self : *Economy, value : u64 ) void
  {
    inline for( 0..resTypeCount )| r |
    {
      self.resBank[ r ] = value;
    }
  }


  // ================================ INFRASTRUCTURE ================================

  pub inline fn logInfCounts(  self : *const Economy ) void
  {
    def.qlog( .INFO, 0, @src(), "Logging infrastructure :" );

    inline for( 0..infTypeCount )| f |
    {
      const infType  = InfType.fromIdx( f );
      const infCount = self.infBank[    f ];
      const infDelta = self.infDelta[   f ];
      const infBonus = self.infBank[    f ] * infType.getMetric_u64( .CAPACITY );

      def.log( .CONT, 0, @src(), "{s}\t: {d}\t +{d}\t) [ {d} ]", .{ @tagName( infType ), infCount, infBonus, infDelta });
    }
  }

  pub inline fn getInfCount( self : *const Economy, infType : InfType ) u64
  {
    return self.infBank[ infType.toIdx() ];
  }
  pub inline fn setInfCount( self : *Economy, infType : InfType, value : u64 ) void
  {
    self.infBank[ infType.toIdx() ] = value;
  }
  pub inline fn addInfCount( self : *Economy, infType : InfType, value : u64 ) void
  {
    self.infBank[ infType.toIdx() ] += value;
  }
  pub inline fn subInfCount( self : *Economy, infType : InfType, value : u64 ) void
  {
    const count = @min( value, self.infBank[ infType.toIdx() ]);

    self.infBank[ infType.toIdx() ] -= count;

    if( value != count )
    {
      def.log( .WARN, 0, @src(), "@ Tried to remove {d} inf of type {s} from economy, but only had {d} left", .{ value, @tagName( infType ), count });
    }
  }

  pub inline fn debugSetInfCounts(  self : *Economy, value : u64 ) void
  {
    self.infBank[ InfType.HOUSING.toIdx() ] = value * 100;
    self.infBank[ InfType.HABITAT.toIdx() ] = value * 0;
    self.infBank[ InfType.STORAGE.toIdx() ] = value * 100;
  //self.infBank[ InfType.BATTERY.toIdx() ] = value * 100;
  }


  pub fn canBuildInf( self : *const Economy, infType : InfType, count : u64 ) bool
  {
    if( !InfType.canBeBuiltIn( infType, self.location, self.hasAtmo ))
    {
      def.log( .WARN, 0, @src(), "@ You are not allowed to build infrastructure of type {s} in location of type {}", .{ @tagName( infType ), @tagName( self.location ) });
      return false;
    }

    if( infType == .HABITAT )
    {
      return true; // TODO : check against self.maxAvailableArea
    }

    const  neededArea = infType.getAreaCost() * count;

    if( self.areaAvail < neededArea )
    {
      def.log( .WARN, 0, @src(), "@ Not enough space to build infrastructure of type {s} in location of type {}. Needed : {d}", .{ @tagName( infType ), @tagName( self.location ), neededArea });
      return false;
    }
    return true;
  }


  // ================================ INDUSTRY ================================

  pub inline fn logIndCounts(  self : *const Economy ) void
  {
    def.qlog( .INFO, 0, @src(), "Logging industry :" );

    inline for( 0..indTypeCount )| d |
    {
      const indType  = IndType.fromIdx(  d );
      const indCount = self.indBank[     d ];
      const indDelta = self.indDelta[    d ];
      const indRatio = self.indActivity[ d ];

      def.log( .CONT, 0, @src(), "{s}\t: {d}\t( {d:.4} )\t[ {d} ]", .{ @tagName( indType ), indCount, indRatio, indDelta });
    }
  }

  pub inline fn getIndCount( self : *const Economy, indType : IndType ) u64
  {
    return self.indBank[ indType.toIdx() ];
  }
  pub inline fn setIndCount( self : *Economy, indType : IndType, value : u64 ) void
  {
    self.indBank[ indType.toIdx() ] = value;
  }
  pub inline fn addIndCount( self : *Economy, indType : IndType, value : u64 ) void
  {
    self.indBank[ indType.toIdx() ] += value;
  }
  pub inline fn subIndCount( self : *Economy, indType : IndType, value : u64 ) void
  {
    const count = @min( value, self.indBank[ indType.toIdx() ]);

    self.indBank[ indType.toIdx() ] -= count;

    if( value != count )
    {
      def.log( .WARN, 0, @src(), "@ Tried to remove {d} ind of type {s} from economy, but only had {d} left", .{ value, @tagName( indType ), count });
    }
  }

  pub inline fn debugSetIndCounts(  self : *Economy, value : u64 ) void
  {
    self.indBank[ IndType.AGRONOMIC.toIdx()   ] = value * 25;
    self.indBank[ IndType.HYDROPONIC.toIdx()  ] = value * 25;

    self.indBank[ IndType.WATER_PLANT.toIdx() ] = value * 50;
    self.indBank[ IndType.SOLAR_PLANT.toIdx() ] = value * 100;
    // TODO : add nuclear plant ( using ORE and WATER ? )

    self.indBank[ IndType.PROBE_MINE.toIdx()  ] = value * 0;
    self.indBank[ IndType.GROUND_MINE.toIdx() ] = value * 200;
    self.indBank[ IndType.REFINERY.toIdx()    ] = value * 100;
    self.indBank[ IndType.FACTORY.toIdx()     ] = value * 50;
    self.indBank[ IndType.ASSEMBLY.toIdx()    ] = value * 25;
  }


  pub fn canBuildInd( self : *const Economy, indType : IndType, count : u64 ) bool
  {
    if( !IndType.canBeBuiltIn( indType, self.location, self.hasAtmo ))
    {
      def.log( .INFO, 0, @src(), "You are not allowed to build industry of type {s} in location of type {}", .{ @tagName( indType ), @tagName( self.location ) });
      return false;
    }

    const  neededArea = indType.getAreaCost() * count;

    if( self.areaAvail < neededArea )
    {
      def.log( .INFO, 0, @src(), "Not enough space to build industry of type {s} in location of type {}. Needed : {d}", .{ @tagName( indType ), @tagName( self.location ), neededArea });
      return false;
    }
    return true;
  }


  // ================================ POPULATION ================================

  pub fn logPopCount( self : *const Economy ) void
  {
    def.log( .INFO, 0, @src(), "Population\t: {d}\t/ {d}\t[ {d} ]\t( {d:.3} )", .{ self.popCount, self.getPopCap(), self.popDelta, self.popAccess });
  }

  pub fn getPopCap( self : *const Economy ) u64
  {
    return self.getInfCount( .HOUSING ) * InfType.HOUSING.getMetric_u64( .CAPACITY );
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
        const developedArea = self.areaUsed;
        const surfaceArea   = self.areaCap;

        const overgroundRatio = surfaceArea / developedArea;

        if( developedArea < surfaceArea ) // If the planet is not fully developed
        {
          tmp = 0.5 * sunshine; // 50 % due to nighttime
        }
        else
        {
          const sunlessRatio = def.pow( f64, 1.0 - overgroundRatio, SUN_SHORTAGE_EXPONENT );
          tmp = 0.5 * sunshine * ( 1.0 - sunlessRatio );

        }
      },

      .ORBIT => tmp = sunshine * 0.98, // PLanetary shadow
      else   => tmp = sunshine,
    }

    self.sunAccess = @floatCast( def.clmp( tmp, 0.001, MAX_SUN_ACCESS_CAP ));
  }


  pub fn getEcologyFactor( self : *const Economy ) f32
  {
    if( self.location != .GROUND or !self.hasAtmo ){ return 0.0; }

    // Calculate total pollution
    var averageActivity : f64 = 0.0;
    var pollutionAmount : f64 = @floatFromInt( self.popCount );
        pollutionAmount      *= POLLUTION_PER_POP;

    for( 0..indTypeCount )| d |
    {
      const activity = self.indActivity[ d ];
      const indType  = IndType.fromIdx( d );

      var tmp  = indType.getMetric_f64( .POLLUTION );
          tmp *= @floatFromInt( self.indBank[ d ]);
          tmp *= activity;

      pollutionAmount += tmp;
      averageActivity += activity;
    }

    averageActivity /= indTypeCount;

    for( 0..infTypeCount )| f |
    {
      const infType  = InfType.fromIdx( f );

      var tmp  = infType.getMetric_f64( .POLLUTION );
          tmp *= @floatFromInt( self.infBank[ f ]);
          tmp *= averageActivity;

      pollutionAmount += tmp;
    }

    pollutionAmount *= 100.0;

    const groundArea    : f64 = self.areaCap * self.landCover;
    const developedArea : f64 = self.areaUsed;

    // Pollution ratio : 0 = pristine, 1 = polluted
    const pollutionRatio : f32 = @floatCast( def.clmp( pollutionAmount / @max( groundArea, 1.0 ), 0.0, 1.0 ));

    // Development ratio : 0 = untouched, 1 = industrialized
    const developmentRatio : f32 = @floatCast( def.clmp( developedArea / groundArea, 0.0, 1.0 ));

    // Ecology Ratio : 0 = desolate, 1 = wilderness
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
    // Updating maximum

    const habitatArea = self.getHabitatArea();

    if( self.location == .GROUND and self.hasAtmo )
    {
      const groundArea = self.areaCap * self.landCover;
      self.areaMax     = habitatArea + groundArea;
    }
    else
    {
      self.areaMax = habitatArea; // Underground / man-made structures only
    }

    // Updating usage

    self.areaUsed = 0.0;

    inline for( 0..infTypeCount )| f |{ if( f != InfType.HABITAT.toIdx() )
    {
      const infType = InfType.fromIdx( f );

      const infCount : f64 = @floatFromInt( self.getInfCount( infType ));

      self.areaUsed += infCount * infType.getMetric_f64( .AREA_COST );
    }}
    inline for( 0..indTypeCount )| d |
    {
      const indType = IndType.fromIdx( d );

      const indCount : f64 = @floatFromInt( self.getIndCount( indType ));

      self.areaUsed += indCount * indType.getMetric_f64( .AREA_COST );
    }


    // Updating availability

    if( self.areaMax > self.areaUsed )
    {
      self.areaAvail = self.areaMax - self.areaUsed;
    }
    else
    {
      def.log( .WARN, 0, @src(), "Negative available area in location of type {s} : using {d} / {d}", .{ @tagName( self.location ), self.areaUsed, self.areaMax });
      self.areaAvail = 0.0;
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
//  inline for( 0..indTypeCount )| d |{ if( self.indBank[ d ] != 0 ) // Skips absent industries
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
//  inline for( 0..indTypeCount )| d |{ if( self.indBank[ d ] != 0 ) // Skips absent industries
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

  pub inline fn tryBuild( self : *Economy, c : Construct, amount : u64 ) u64
  {

    if( !c.canBeBuiltIn( self.location, self.hasAtmo ))
    {
      def.qlog( .WARN, 0, @src(), "Invalid location conditions : aborting" );
      return 0;
    }

    const partIdx          = ResType.PART.toIdx();
    const availParts : f64 = @floatFromInt( self.resBank[ partIdx ]);
    const amount_f64 : f64 = @floatFromInt( amount );
    const partCost   : f64 = @floatCast( c.getPartCost() );
    const areaCost   : f64 = @floatCast( c.getAreaCost() );

    var maxAmount = amount_f64;

    if( availParts < partCost )
    {
      def.qlog( .WARN, 0, @src(), "Not enough parts for a single unit : aborting" );
      return 0;
    }
    if( availParts < amount_f64 * partCost  )
    {
      def.qlog( .WARN, 0, @src(), "Not enough parts : adjusting" );

      maxAmount = @divFloor( availParts, partCost );
    }

    if( !std.meta.eql( c, .{ .inf = .HABITAT })) // HABITATS can always be built
    {
      if( self.areaAvail < areaCost )
      {
        def.qlog( .WARN, 0, @src(), "Not enough area for a single unit : aborting" );
        return 0;
      }

      if( self.areaAvail < maxAmount * areaCost )
      {
        def.qlog( .WARN, 0, @src(), "Not enough area : adjusting" );

        maxAmount = @divFloor( self.areaAvail, areaCost );
      }
    }

    const finalAmount : u64 = @intFromFloat( maxAmount );
    const totalCost   : u64 = @intFromFloat( partCost * maxAmount );

    self.resBank[  partIdx ] -= totalCost;
    self.resDelta[ partIdx ] -= @intCast( totalCost );

    switch( c )
    {
    //.ves => | vesType | self.vesBank[ vesType.toIdx() ] += finalAmount,
      .inf => | infType |
      {
        self.infBank[  infType.toIdx() ] += finalAmount;
        self.infDelta[ infType.toIdx() ] += @intCast( finalAmount );
      },
      .ind => | indType |
      {
        self.indBank[  indType.toIdx() ] += finalAmount;
        self.indDelta[ indType.toIdx() ] += @intCast( finalAmount );
      },
    }

    return finalAmount;
  }


  // ================================ UPDATING ================================

  pub fn logMetrics( self : *Economy ) void
  {
    def.log( .INFO, 0, @src(), "Logging other metrics for day {d}:", .{ self.itrCount });
    def.log( .CONT, 0, @src(), "Sun access   : {d:.6}",              .{ self.sunAccess });
    def.log( .CONT, 0, @src(), "Eco factor   : {d:.6}",              .{ self.getEcologyFactor() });
    def.log( .CONT, 0, @src(), "Development  : {d:.0} / {d:.0}",     .{ self.areaUsed, self.areaMax });
    def.log( .CONT, 0, @src(), "Build queue  : {d}",                 .{ self.buildQueue.?.getEntryCount() });
  }

  pub fn resetCountMetrics( self : *Economy ) void // Zeroing out the previous metrics
  {
    self.popDelta = 0;

    inline for( 0..resTypeCount )| r |
    {
      self.resDelta[  r ] = 0;
      self.resAccess[ r ] = 0;

      self.prevResProd[ r ] = 0;
      self.prevResCons[ r ] = 0;

      self.prevResDecay[ r ] = 0;
      self.prevResGrowth[ r ] = 0;


      self.prevResReq[ r ] = 0;
    }
    inline for( 0..infTypeCount )| f |
    {
      self.infDelta[ f ] = 0;
    }
    inline for( 0..indTypeCount )| d |
    {
      self.indDelta[    d ] = 0;
      self.indActivity[ d ] = 0.0;
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
    self.itrCount += 1;

    if( @mod( self.itrCount, 7 ) != 1 ){ return; } // Only tick econ at start of week

    self.updateResCaps();
    self.updateAreas();
    self.updateSunshine( newSunshine );

    ecnSlvr.resolveEcon( self );
    self.tickBuildQueue();

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