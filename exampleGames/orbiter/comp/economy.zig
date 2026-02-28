const std = @import( "std" );
const def = @import( "defs" );

const inf = @import( "infrastructure.zig" );
const res = @import( "resource.zig" );

const ecnSlvr = @import( "econSolver.zig" );
const popSlvr = @import( "popSolver.zig" );



pub const resTypeCount = res.resTypeCount;
pub const infTypeCount = inf.infTypeCount;

pub const ResType = res.ResType;
pub const InfType = inf.InfType;

pub const ResInstance = res.ResInstance;
pub const InfInstance = inf.InfInstance;


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



const RES_CAP : u64 = 99_999; // TODO : change for warehouse system via infra



pub const Economy = struct
{
  pub inline fn getStoreType() type { return def.componentStoreFactory( @This() ); }

  location      : EconLoc,
  isActive      : bool = false,
  hasAtmosphere : bool = false,

  sunshine   : f32 = 1.0,

  maxAvailArea : u64 = 0,

//assemblyQueue

  popCount : u64 = 0,
  resBank  : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),
  infBank  : [ infTypeCount ]u64 = std.mem.zeroes([ infTypeCount ]u64 ),

  popDelta : i64 = 0,

  resProd  : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),
  resCons  : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),

  infDelta : [ infTypeCount ]i64 = std.mem.zeroes([ infTypeCount ]i64 ),

  popResAccess : f32 = 0.0,
  resAccess    : [ resTypeCount ]f32 = std.mem.zeroes([ resTypeCount ]f32 ),
  infActivity  : [ infTypeCount ]f32 = std.mem.zeroes([ infTypeCount ]f32 ),


  // ================================ RESSOURCES ================================

  pub inline fn logResCounts(  self : *const Economy ) void
  {
    def.qlog( .INFO, 0, @src(), "Logging resource counts and access ratios :" );

    inline for( 0..resTypeCount )| r |
    {
      const resType  = ResType.fromIdx( r );
      const resCount = self.resBank[    r ];
      const resProd  = self.resProd[    r ];
      const resCons  = self.resCons[    r ];
      const resRatio = self.resAccess[  r ];

      def.log( .CONT, 0, @src(), "{s}  \t: {d}\t[ +{d}\t/ -{d}\t] ( {d:.3} )", .{ @tagName( resType ), resCount, resProd, resCons, resRatio });
    }
  }

  pub inline fn getResCount( self : *const Economy, resType : ResType ) u64
  {
    return self.resBank[ resType.toIdx() ];
  }
  pub inline fn setResCount( self : *Economy, resType : ResType, value : u64 ) void
  {
    const tmp = value;

    if( tmp > RES_CAP ){ tmp = RES_CAP; }

    self.resBank[ resType.toIdx() ] = tmp;
  }
  pub inline fn addResCount( self : *Economy, resType : ResType, value : u64 ) void
  {
    var tmp = self.resBank[ resType.toIdx() ] + value;

    if( tmp > RES_CAP ){ tmp = RES_CAP; }

    self.resBank[ resType.toIdx() ] = tmp;
  }
  pub inline fn subResCount( self : *Economy, resType : ResType, value : u64 ) void
  {
    const count = @min( value, self.resBank[ resType.toIdx() ]);

    self.resBank[ resType.toIdx() ] -= count;

    if( value != count )
    {
      def.log( .WARN, 0, @src(), "Tried to remove {d} res of type {s} from economy, but only had {d} left", .{ value, @tagName( resType ), count });
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
    def.qlog( .INFO, 0, @src(), "Logging infrastructure counts and activity ratios :" );

    inline for( 0..infTypeCount )| i |
    {
      const infType  = InfType.fromIdx(  i );
      const infCount = self.infBank[     i ];
      const infDelta = self.infDelta[    i ];
      const infRatio = self.infActivity[ i ];

      def.log( .CONT, 0, @src(), "{s}\t: {d}\t[ {d} ]\t( {d:.3} )", .{ @tagName( infType ), infCount, infDelta, infRatio });
    }
  }

  pub inline fn getInfCount( self : *const Economy, infType : InfType ) u64
  {
    return self.infBank[ infType.toIdx() ];
  }
  pub inline fn setInfCount( self : *Economy, infType : InfType, value : u64 ) void
  {
    const tmp = value;

 //if( tmp > RES_CAP ){ tmp = RES_CAP; }

    self.infBank[ infType.toIdx() ] = tmp;
  }
  pub inline fn addInfCount( self : *Economy, infType : InfType, value : u64 ) void
  {
    const tmp = self.infBank[ infType.toIdx() ] + value;

 //if( tmp > RES_CAP ){ tmp = RES_CAP; }

    self.infBank[ infType.toIdx() ] = tmp;
  }
  pub inline fn subInfCount( self : *Economy, infType : InfType, value : u64 ) void
  {
    const count = @min( value, self.infBank[ infType.toIdx() ]);

    self.infBank[ infType.toIdx() ] -= count;

    if( value != count )
    {
      def.log( .WARN, 0, @src(), "Tried to remove {d} inf of type {s} from economy, but only had {d} left", .{ value, @tagName( infType ), count });
    }
  }

  pub inline fn debugSetInfCounts(  self : *Economy, value : u64 ) void
  {
    self.infBank[ InfType.HOUSING.toIdx()     ] = value * 100;

    self.infBank[ InfType.AGRONOMIC.toIdx()   ] = value * 35;
    self.infBank[ InfType.HYDROPONIC.toIdx()  ] = value * 35;

    self.infBank[ InfType.WATER_PLANT.toIdx() ] = value * 50;
    self.infBank[ InfType.SOLAR_PLANT.toIdx() ] = value * 50;

    self.infBank[ InfType.PROBE_MINE.toIdx()  ] = value * 0;
    self.infBank[ InfType.GROUND_MINE.toIdx() ] = value * 80;
    self.infBank[ InfType.REFINERY.toIdx()    ] = value * 40;
    self.infBank[ InfType.FACTORY.toIdx()     ] = value * 20;
    self.infBank[ InfType.ASSEMBLY.toIdx()    ] = value * 10;
  }


  pub fn canBuildInf( self : *const Economy, infType : InfType, count : u64 ) bool
  {
    if( !InfType.canBeBuiltAt( infType, self.location, self.hasAtmosphere ))
    {
      def.log( .INFO, 0, @src(), "You are not allowed to build infrastructure of type {} in location of type {}", .{ @tagName( infType ), @tagName( self.location ) });
      return false;
    }

    const  availArea  = self.getAvailArea();
    const  neededArea = infType.getArea() * count; // TODO : rework for f32 area

    if( availArea < neededArea )
    {
      def.log( .INFO, 0, @src(), "Not enough space to build infrastructure of type {} in location of type {}. Needed : {d}", .{ @tagName( infType ), @tagName( self.location ), neededArea });
      return false;
    }
    return true;
  }


  // ================================ POPULATION ================================

  pub fn logPopCount( self : *const Economy ) void
  {
    def.log( .INFO, 0, @src(), "Population\t: {d} / {d}\t[ {d} ]\t( {d:.3} )", .{ self.popCount, self.getPopCap(), self.popDelta, self.popResAccess });
  }

  pub fn getPopCap( self : *const Economy ) u64
  {
    return self.getInfCount( .HOUSING ) * InfType.POP_PER_HOUSE;
  }



  // ================================ AREA ================================

  pub fn getUsedArea( self : *const Economy ) f32
  {
    var used : f32 = 0;

    inline for( 0..infTypeCount )| i |
    {
      const infType = InfType.fromIdx( i );
      const infCount : f32 = @floatFromInt( self.getInfCount( infType ));

      used += infCount * infType.getArea();
    }

    return used;
  }

  pub fn getTotalArea( self : *const Economy ) f32
  {
    if( self.location == .GROUND and self.hasAtmosphere ) // If this is a planet with atmosphere
    {
      return self.maxAvailArea;
    }
    else // Else, area is grown via "area-extension" infra
    {
    //const infType = InfType.TBA.toIdx();                                // TODO : implement area-extension infra
    //const infCount : f32 = @floatFromInt( self.getInfCount( infType ));


    //return infCount * infType.getArea();
      return 0.0;
    }
  }

  pub fn getAvailArea( self : *const Economy ) f32
  {
    const used  = self.getUsedArea();
    const total = self.getTotalArea();

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


  // ================================ UPDATING ================================

  fn resetDeltas( self : *Economy ) void
  {
    self.popDelta = 0;

    inline for( 0..resTypeCount )| r |
    {
      self.resProd[ r ] = 0;
      self.resCons[ r ] = 0;
    }
    inline for( 0..infTypeCount )| i |
    {
      self.infDelta[ i ] = 0;
    }
  }

  pub fn tickEcon( self : *Economy, sunshine : f32 ) void
  {
    self.sunshine = sunshine;
    self.resetDeltas();

    popSlvr.resolvePop(  self ); // Updates pop WORK, FOOD and WATER consequently
    ecnSlvr.resolveEcon( self ); // Updates all non WORK

    // NOTE : DEBUG
    self.logPopCount();
    self.logResCounts();
    self.logInfCounts();
  }
};