const std = @import( "std" );
const def = @import( "defs" );

const ves = @import( "vessel.zig" );
const res = @import( "resource.zig" );
const inf = @import( "infrastructure.zig" );
const ind = @import( "industry.zig" );
const cst = @import( "construct.zig" );

const ecnSlvr = @import( "econSolver.zig" );
const ecnBldr = @import( "econBuilder.zig" );

const BuildQueue = ecnBldr.BuildQueue;

const ecnLoc  = @import( "econLoc.zig" );

pub const econLocCount = ecnLoc.econLocCount;
pub const EconLoc      = ecnLoc.EconLoc;

pub const vesTypeCount = ves.vesTypeCount;
pub const resTypeCount = res.resTypeCount;
pub const infTypeCount = inf.infTypeCount;
pub const indTypeCount = ind.indTypeCount;

pub const VesType = ves.VesType;
pub const ResType = res.ResType;
pub const InfType = inf.InfType;
pub const IndType = ind.IndType;

pub const VesInstance = ves.VesInstance;
pub const ResInstance = res.ResInstance;
pub const InfInstance = inf.InfInstance;
pub const IndInstance = ind.IndInstance;

pub const Construct = cst.Construct;


pub const MIN_RES_CAP = 9999;


pub const Economy = struct
{
  pub inline fn getStoreType() type { return def.componentStoreFactory( @This() ); }

  location     : EconLoc,
  maxAvailArea : f32 = 0,

  hasAtmo  : bool = false,
  isActive : bool = false,

  sunshine : f32  = 0.0,

  buildQueue : ?BuildQueue = null,

  popCount  : u64 = 0,
  popDelta  : i64 = 0,
  popAccess : f32 = 0.0,

  resCap       : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),
  resBank      : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),
  resDelta     : [ resTypeCount ]i64 = std.mem.zeroes([ resTypeCount ]i64 ),
  resAccess    : [ resTypeCount ]f32 = std.mem.zeroes([ resTypeCount ]f32 ),

  prevResCons  : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),
  prevResProd  : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),

  prevResDecay : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),
  prevResReq   : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),

  infBank      : [ infTypeCount ]u64 = std.mem.zeroes([ infTypeCount ]u64 ),
  infDelta     : [ infTypeCount ]i64 = std.mem.zeroes([ infTypeCount ]i64 ),

  indBank      : [ indTypeCount ]u64 = std.mem.zeroes([ indTypeCount ]u64 ),
  indDelta     : [ indTypeCount ]i64 = std.mem.zeroes([ indTypeCount ]i64 ),
  indActivity  : [ indTypeCount ]f32 = std.mem.zeroes([ indTypeCount ]f32 ),


  pub inline fn newEcon( loc : EconLoc, area : f32, atmo : bool ) Economy
  {
    var econ : Economy = .{ .location = loc, .maxAvailArea = area, .hasAtmo = atmo, .isActive = true };

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
      const infStoreType = resType.getInfStore();

      self.resCap[ r ] = MIN_RES_CAP + ( self.infBank[ infStoreType.toIdx() ] * infStoreType.getCapacity() );
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
  // TODO : add updateResCap(), which updates it based on infra


  pub inline fn logResCounts(  self : *const Economy ) void
  {
    def.qlog( .INFO, 0, @src(), "Logging resource counts and access ratios :" );
    def.qlog( .CONT, 0, @src(), "RESOURCE\t: Bank\t/ Cap\t[ Delta\t: Prod\t. Cons\t. Decay\t| Demand ] ( Access )" );
  //def.log( .CONT, 0, @src(), "{s}      \t: {d} \t/ {d}\t[ {d}  \t: +{d}\t/ -{d}\t| {d}  \t| {d}   \t] ( {d:.3} )",.{ @tagName( resType ), resCount, resCap, resDelta, resProd, resCons, resDecay, resReq, resAccess });


    inline for( 0..resTypeCount )| r |
    {
      const resType = ResType.fromIdx( r );

      const resCount = self.resBank[ r ];
      const resCap   = self.resCap[  r ];

      const resDelta = self.resDelta[  r ];
      const resProd  = self.prevResProd[  r ];
      const resCons  = self.prevResCons[  r ];
      const resDecay = self.prevResDecay[ r ];
      const resReq   = self.prevResReq[   r ];

      const resAccess    = self.resAccess[ r ];

      def.log( .CONT, 0, @src(), "{s}  \t: {d}\t/ {d}\t[ {d}\t: +{d}\t. -{d}\t. -{d}\t| {d}\t ] ( {d:.3} )",.{ @tagName( resType ), resCount, resCap, resDelta, resProd, resCons, resDecay, resReq, resAccess });
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
    def.qlog( .INFO, 0, @src(), "Logging infrastructure counts and bonuses :" );

    inline for( 0..infTypeCount )| f |
    {
      const infType  = InfType.fromIdx(  f );
      const infCount = self.infBank[     f ];
      const infDelta = self.infDelta[    f ];
      const infBonus = infCount * infType.getCapacity();

      def.log( .CONT, 0, @src(), "{s}\t: {d}\t[ {d} ]\t( {d} )", .{ @tagName( infType ), infCount, infDelta, infBonus });
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
    if( !InfType.canBeBuiltAt( infType, self.location, self.hasAtmosphere ))
    {
      def.log( .WARN, 0, @src(), "@ You are not allowed to build infrastructure of type {s} in location of type {}", .{ @tagName( infType ), @tagName( self.location ) });
      return false;
    }

    if( infType == .HABITAT )
    {
      return true; // TODO : check against self.maxAvailableArea
    }

    const  availArea  = self.getUnusedArea();
    const  neededArea = infType.getAreaCost() * count;

    if( availArea < neededArea )
    {
      def.log( .WARN, 0, @src(), "@ Not enough space to build infrastructure of type {s} in location of type {}. Needed : {d}", .{ @tagName( infType ), @tagName( self.location ), neededArea });
      return false;
    }
    return true;
  }


  // ================================ INDUSTRY ================================

  pub inline fn logIndCounts(  self : *const Economy ) void
  {
    def.qlog( .INFO, 0, @src(), "Logging industry counts and activity ratios :" );

    inline for( 0..indTypeCount )| d |
    {
      const indType  = IndType.fromIdx(  d );
      const indCount = self.indBank[     d ];
      const indDelta = self.indDelta[    d ];
      const indRatio = self.indActivity[ d ];

      def.log( .CONT, 0, @src(), "{s}\t: {d}\t[ {d} ]\t( {d:.3} )", .{ @tagName( indType ), indCount, indDelta, indRatio });
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
  }


  pub fn canBuildInd( self : *const Economy, indType : IndType, count : u64 ) bool
  {
    if( !IndType.canBeBuiltAt( indType, self.location, self.hasAtmosphere ))
    {
      def.log( .INFO, 0, @src(), "You are not allowed to build industry of type {s} in location of type {}", .{ @tagName( indType ), @tagName( self.location ) });
      return false;
    }

    const  availArea  = self.getUnusedArea();
    const  neededArea = indType.getAreaCost() * count;

    if( availArea < neededArea )
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
    return self.getInfCount( .HOUSING ) * InfType.HOUSING.getCapacity();
  }



  // ================================ AREA ================================

  pub fn getUsedArea( self : *const Economy ) f32
  {
    var used : f32 = 0;

    inline for( 0..infTypeCount )| f |
    {
      const infType  = InfType.fromIdx( f );

      var area : f32 = @floatFromInt( self.getInfCount( infType ));
          area      *= infType.getAreaCost();

      used += area;
    }
    inline for( 0..indTypeCount )| d |
    {
      const indType = IndType.fromIdx( d );

      var area : f32 = @floatFromInt( self.getIndCount( indType ));
          area      *= indType.getAreaCost();

      used += area;
    }

    return used;
  }

  pub fn getUnusedArea( self : *const Economy ) f32
  {
    const used  = self.getUsedArea();
    const total = self.getAreaCapacity();

    if( used <= total )
    {
      return total - used;
    }
    else
    {
      def.log( .WARN, 0, @src(), "Negative available area in location of type {s}", .{ @tagName( self.location )});
      return 0.0;
    }
  }

  pub fn getAreaCapacity( self : *const Economy ) f32
  {
    if( self.location == .GROUND and self.hasAtmo ) // If this is a planet with atmosphere
    {
      return self.maxAvailArea;
    }
    else // Else, area is grown via habitat infrastructure
    {
      const total = self.getInfCount( .HABITAT ) * InfType.HABITAT.getCapacity();
      return @floatFromInt( total );
    }
  }


  // ================================ ECONOMY ================================

  pub inline fn getMaxTotResCons( self : *const Economy, resType : ResType ) u64
  {
    var maxCons : u64 = 0;

    maxCons += self.getMaxPopResCons( resType );
    maxCons += self.getMaxIndResCons( resType );

    return maxCons;
  }

  pub inline fn getMaxPopResCons( self : *const Economy, resType : ResType ) u64
  {
    var maxCons : u64 = 0;

    const popResDelta = self.popCount * resType.getPerPopDelta();

    if( popResDelta < -def.EPS ) // If res consumed by pop
    {
      maxCons += @intFromFloat( @floor( -popResDelta ));
    }

    return maxCons;
  }

  pub inline fn getMaxIndResCons( self : *const Economy, resType : ResType ) u64
  {
    var maxCons : u64 = 0;

    inline for( 0..indTypeCount )| d |{ if( self.indBank[ d ] != 0 ) // Skips absent industries
    {
      const indType = IndType.fromIdx( d );
      const inst    = IndInstance.initByType( indType );

      maxCons += self.indBank[ d ] * inst.getResProdPerInd( resType );

      if( inst.powerSrc == .SOLAR ) // Limits activity based on available sunshine
      {
        const factor = @min( self.sunshine, 1.0 );

        const maxCons_f32 : f32 = @floatFromInt( maxCons );
        maxCons = @intFromFloat( @floor( maxCons_f32 * factor ));
      }
    }}

    return maxCons;
  }


  pub inline fn getMaxTotResProd( self : *const Economy, resType : ResType ) u64
  {
    var maxProd : u64 = 0;

    maxProd += self.getMaxPopResProd( resType );
    maxProd += self.getMaxIndResProd( resType );

    return maxProd;
  }

  pub inline fn getMaxPopResProd( self : *const Economy, resType : ResType ) u64
  {
    var maxProd : u64 = 0;

    const popResDelta = self.popCount * resType.getPerPopDelta();

    if( popResDelta > def.EPS ) // If res produced by pop
    {
      maxProd += @intFromFloat( @floor( popResDelta ));
    }

    return maxProd;
  }

  pub inline fn getMaxIndResProd( self : *const Economy, resType : ResType ) u64
  {
    var maxProd : u64 = 0;

    inline for( 0..indTypeCount )| d |{ if( self.indBank[ d ] != 0 ) // Skips absent industries
    {
      const indType = IndType.fromIdx( d );
      const inst    = IndInstance.initByType( indType );

      maxProd += self.indBank[ d ] * inst.getResProdPerInd( resType );

      if( inst.powerSrc == .SOLAR ) // Limits activity based on available sunshine
      {
        const factor = @min( self.sunshine, 1.0 );

        const maxProd_f32 : f32 = @floatFromInt( maxProd );
        maxProd = @intFromFloat( @floor( maxProd_f32 * factor ));
      }
    }}

    return maxProd;
  }


  // ================================ CONSTRUCTION ================================

  pub inline fn tryBuild( self : *Economy, c : Construct, amount : u64 ) u64
  {

    if( !c.canBeBuiltIn( self.location, self.hasAtmo ))
    {
      def.qlog( .WARN, 0, @src(), "Invalid location conditions : aborting" );
      return 0;
    }

    const partIdx    = ResType.PART.toIdx();
    const availParts = self.resBank[ partIdx ];
    var   maxAmount  = amount;

    if( availParts < c.getPartCost())
    {
      def.qlog( .WARN, 0, @src(), "Not enough parts for a single unit : aborting" );
      return 0;
    }
    if( availParts < amount * c.getPartCost() )
    {
      def.qlog( .WARN, 0, @src(), "Not enough parts : adjusting" );

      maxAmount = @divFloor( availParts, c.getPartCost() );
    }

    const availArea = self.getUnusedArea();
    const amout_f32 : f32 = @floatFromInt( amount );

    if( availArea < amout_f32 * c.getAreaCost())
    {
      def.qlog( .WARN, 0, @src(), "Not enough area : adjusting" );

      maxAmount = @intFromFloat( @divFloor( availArea, c.getAreaCost()));
    }

    self.resBank[ partIdx ] -= maxAmount * c.getPartCost();

    switch( c )
    {
    //.ves => | vesType | self.vesBank[ vesType.toIdx() ] += maxAmount,
      .inf => | infType | self.infBank[ infType.toIdx() ] += maxAmount,
      .ind => | indType | self.indBank[ indType.toIdx() ] += maxAmount,
    }

    return maxAmount;
  }


  // ================================ UPDATING ================================

  pub fn resetDebugMetrics( self : *Economy ) void // Zeroing out the previous metrics
  {
    self.popDelta = 0;

    inline for( 0..resTypeCount )| r |
    {
      self.resDelta[  r ] = 0;
      self.resAccess[ r ] = 0;

      self.prevResProd[ r ] = 0;
      self.prevResCons[ r ] = 0;

      self.prevResDecay[ r ] = 0;
      self.prevResReq[   r ] = 0;
    }
    inline for( 0..infTypeCount )| f |
    {
      self.infDelta[ f ] = 0;
    }
    inline for( 0..indTypeCount )| d |
    {
      self.indDelta[ d ] = 0;
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

  pub fn tickEcon( self : *Economy, sunshine : f32 ) void
  {
    self.sunshine = sunshine;
    self.updateResCaps();


    ecnSlvr.resolveEcon( self );
    self.tickBuildQueue();


    // NOTE : DEBUG
    _ = self.buildQueue.?.addEntry( .{ .inf = .HOUSING }, 2 );
    _ = self.buildQueue.?.addEntry( .{ .inf = .STORAGE }, 15 );

    self.logPopCount();
    self.logResCounts();
  //self.logInfCounts();
  //self.logIndCounts();
  }
};