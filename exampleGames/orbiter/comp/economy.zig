const std = @import( "std" );
const def = @import( "defs" );

const inf = @import( "infrastructure.zig" );
const ind = @import( "industry.zig" );
const res = @import( "resource.zig" );

const ecnSlvr = @import( "econSolver.zig" );


const resTypeCount = res.resTypeCount;
const infTypeCount = inf.infTypeCount;
const indTypeCount = ind.indTypeCount;

const ResType = res.ResType;
const IndType = ind.IndType;
const InfType = inf.InfType;

const ResInstance = res.ResInstance;
const IndInstance = ind.IndInstance;
const InfInstance = inf.InfInstance;


const MIN_RES_CAP = 9999;



pub const econLocCount = @typeInfo( EconLoc ).@"enum".fields.len;

pub const EconLoc = enum( u8 )
{
  pub inline fn toIdx( self : EconLoc ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) EconLoc {  return @enumFromInt( @as( u8, @intCast( i ))); }

  GROUND, // Does not garantee breathable atmosphere
  ORBIT,
  L1,     // Lagrange Points
  L2,
  L3,
  L4,
  L5,

  pub inline fn toLagrange( self : EconLoc ) u4
  {
    return switch( self )
    {
      .L1  => 1,
      .L2  => 2,
      .L3  => 3,
      .L4  => 4,
      .L5  => 5,
      else => 0,
    };
  }
};


pub const Economy = struct
{
  pub inline fn getStoreType() type { return def.componentStoreFactory( @This() ); }

  location     : EconLoc,
  maxAvailArea : u64 = 0,

  hasAtmo  : bool = false,
  isActive : bool = false,

  sunshine : f32  = 0.0,

//assemblyQueue

  popCount  : u64 = 0,   // OK
  popDelta  : i64 = 0,   // OK
  popAccess : f32 = 0.0, // OK


  prevResProd  : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ), // OK
  prevResCons  : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ), // OK

//prevResReq   : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ), // TODO : use me
//prevResDecay : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ), // TODO : use me

  resCap      : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ), // OK
  resBank     : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ), // OK

  resAccess   : [ resTypeCount ]f32 = std.mem.zeroes([ resTypeCount ]f32 ),

  infBank     : [ infTypeCount ]u64 = std.mem.zeroes([ infTypeCount ]u64 ),
  infDelta    : [ infTypeCount ]i64 = std.mem.zeroes([ infTypeCount ]i64 ),

  indBank     : [ indTypeCount ]u64 = std.mem.zeroes([ indTypeCount ]u64 ), // OK
  indDelta    : [ indTypeCount ]i64 = std.mem.zeroes([ indTypeCount ]i64 ), // OK
  indActivity : [ indTypeCount ]f32 = std.mem.zeroes([ indTypeCount ]f32 ), // OK


  // ================================ RESSOURCES ================================

  pub inline fn newEcon( loc : EconLoc, area : u64, atmo : bool ) Economy
  {
    var econ : Economy = .{ .location = loc, .maxAvailArea = area, .hasAtmo = atmo, .isActive = true };

    inline for( 0..resTypeCount )| r |
    {
      econ.resCap[ r ] = MIN_RES_CAP;
    }

    return econ;
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

    inline for( 0..resTypeCount )| r |
    {
      const resType     = ResType.fromIdx( r );

      const resCount    = self.resBank[ r ];
      const resCap      = self.resCap[  r ];

      const prevResProd = self.prevResProd[ r ];
      const prevResCons = self.prevResCons[ r ];

      const resAccess   = self.resAccess[ r ];

      def.log( .CONT, 0, @src(), "{s}  \t: {d}\t/ {d}\t[ +{d}\t/ -{d}\t] ( {d:.3} )", .{ @tagName( resType ), resCount, resCap, prevResProd, prevResCons, resAccess });
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

    inline for( 0..infTypeCount )| i |
    {
      const infType  = InfType.fromIdx(  i );
      const infCount = self.infBank[     i ];
      const infDelta = self.infDelta[    i ];
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
    self.infBank[ InfType.BATTERY.toIdx() ] = value * 100;
  }


  pub fn canBuildInf( self : *const Economy, infType : InfType, count : u64 ) bool
  {
    if( !InfType.canBeBuiltAt( infType, self.location, self.hasAtmosphere ))
    {
      def.log( .WARN, 0, @src(), "@ You are not allowed to build infrastructure of type {} in location of type {}", .{ @tagName( infType ), @tagName( self.location ) });
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
      def.log( .WARN, 0, @src(), "@ Not enough space to build infrastructure of type {} in location of type {}. Needed : {d}", .{ @tagName( infType ), @tagName( self.location ), neededArea });
      return false;
    }
    return true;
  }


  // ================================ INDUSTRY ================================

  pub inline fn logIndCounts(  self : *const Economy ) void
  {
    def.qlog( .INFO, 0, @src(), "Logging industry counts and activity ratios :" );

    inline for( 0..indTypeCount )| i |
    {
      const indType  = IndType.fromIdx(  i );
      const indCount = self.indBank[     i ];
      const indDelta = self.indDelta[    i ];
      const indRatio = self.indActivity[ i ];

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
    self.indBank[ IndType.ASSEMBLY.toIdx()    ] = value * 25;
  }


  pub fn canBuildInd( self : *const Economy, indType : IndType, count : u64 ) bool
  {
    if( !IndType.canBeBuiltAt( indType, self.location, self.hasAtmosphere ))
    {
      def.log( .INFO, 0, @src(), "You are not allowed to build industry of type {} in location of type {}", .{ @tagName( indType ), @tagName( self.location ) });
      return false;
    }

    const  availArea  = self.getUnusedArea();
    const  neededArea = indType.getAreaCost() * count;

    if( availArea < neededArea )
    {
      def.log( .INFO, 0, @src(), "Not enough space to build industry of type {} in location of type {}. Needed : {d}", .{ @tagName( indType ), @tagName( self.location ), neededArea });
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

    inline for( 0..infTypeCount )| i |
    {
      const infType = InfType.fromIdx( i );
      const tmp = self.getIndCount( .infType ) * infType.getCapacity();

      used += @floatFromInt( tmp );
    }
    inline for( 0..indTypeCount )| i |
    {
      const indType = IndType.fromIdx( i );
      const tmp = self.getIndCount( .indType ) * indType.getCapacity();

      used += @floatFromInt( tmp );
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
      def.log( .WARN, 0, @src(), "Negative available area in location of type {}", .{ @tagName( self.location )});
      return 0.0;
    }
  }

  pub fn getAreaCapacity( self : *const Economy ) f32
  {
    if( self.location == .GROUND and self.hasAtmosphere ) // If this is a planet with atmosphere
    {
      return self.maxAvailArea;
    }
    else // Else, area is grown via habitat infrastructure
    {
      const total = self.getInfCount( .HABITAT ) * InfType.HABITAT.getCapacity();
      return @floatFromInt( total );
    }
  }


  // ================================ UPDATING ================================

  fn resetDeltas( self : *Economy ) void
  {
    self.popDelta = 0;

    inline for( 0..resTypeCount )| r |
    {
      self.prevResProd[ r ] = 0;
      self.prevResCons[ r ] = 0;
    }
    inline for( 0..infTypeCount )| i |
    {
      self.infDelta[ i ] = 0;
    }
    inline for( 0..indTypeCount )| i |
    {
      self.indDelta[ i ] = 0;
    }
  }

  pub fn tickEcon( self : *Economy, sunshine : f32 ) void
  {
    self.sunshine = sunshine;
    self.resetDeltas();
  //self.updateResCaps(); // TODO : add me

    ecnSlvr.resolveEcon( self );

    // NOTE : DEBUG
    self.logPopCount();
    self.logResCounts();
  //self.logInfCounts();
  //self.logIndCounts();
  }
};