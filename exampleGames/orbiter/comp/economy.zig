const std = @import( "std" );
const def = @import( "defs" );

const inf = @import( "infrastructure.zig" );
const res = @import( "resource.zig" );
const slv = @import( "econSolver.zig" );


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
};


pub const Economy = struct
{
  pub inline fn getStoreType() type { return def.componentStoreFactory( @This() ); }

  location      : EconLoc,
  isActive      : bool = false,
  hasAtmosphere : bool = false,

  population : u64 = 0,
  sunshine   : f32 = 1.0,

  maxAvailArea : u64 = 0,

//assemblyQueue

  resArray : [ resTypeCount ]u64 = std.mem.zeroes([ resTypeCount ]u64 ),
  infArray : [ infTypeCount ]u64 = std.mem.zeroes([ infTypeCount ]u64 ),


  // ================================ RESSOURCES ================================

  pub inline fn getResCount( self : *const Economy, resType : ResType ) u64
  {
    return self.resArray[ resType.toIdx() ];
  }
  pub inline fn setResCount( self : *Economy, resType : ResType, value : u64 ) void
  {
    self.resArray[ resType.toIdx() ] = value;
  }
  pub inline fn addResCount( self : *Economy, resType : ResType, value : u64 ) void
  {
    self.resArray[ resType.toIdx() ] += value;
  }
  pub inline fn subResCount( self : *Economy, resType : ResType, value : u64 ) void
  {
    const count = @min( value, self.resArray[ resType.toIdx() ]);

    self.resArray[ resType.toIdx() ] -= count;

    if( value != count )
    {
      def.log( .WARN, 0, @src(), "Tried to remove {d} res of type {s} from economy, but only had {d} left", .{ value, @tagName( resType ), count });
    }
  }


  // ================================ INFRASTRUCTURE ================================

  pub inline fn getInfCount( self : *const Economy, infType : InfType ) u64
  {
    return self.infArray[ infType.toIdx() ];
  }
  pub inline fn setInfCount( self : *Economy, infType : InfType, value : u64 ) void
  {
    self.infArray[ infType.toIdx() ] = value;
  }
  pub inline fn addInfCount( self : *Economy, infType : InfType, value : u64 ) void
  {
    self.infArray[ infType.toIdx() ] += value;
  }
  pub inline fn subInfCount( self : *Economy, infType : InfType, value : u64 ) void
  {
    const count = @min( value, self.infArray[ infType.toIdx() ]);

    self.infArray[ infType.toIdx() ] -= count;

    if( value != count )
    {
      def.log( .WARN, 0, @src(), "Tried to remove {d} inf of type {s} from economy, but only had {d} left", .{ value, @tagName( infType ), count });
    }
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

  const FOOD_PER_POP   : f32 = 0.1; // How much food does a pop consume
  const WORK_PER_POP   : f32 = 1.0; // How much work does a pop generate
  const POP_PER_HOUSE  : u64 = 10;  // How many pop does a house support

  const WEEKLY_POP_GROWTH = 1.0002113; // x3 each century

  fn getPopCap( self : *const Economy ) u64
  {
    return self.getInfCount( .HOUSING ) * POP_PER_HOUSE;
  }

  fn getPopFoodCons( self : *const Economy ) u64
  {
    const pop : f32 = @floatFromInt( self.population );

    return @intFromFloat( @ceil( pop * FOOD_PER_POP ));
  }

  fn getPopWorkProd( self : *const Economy ) u64
  {
    const pop : f32 = @floatFromInt( self.population );

    return @intFromFloat( @floor( pop * WORK_PER_POP ));
  }

  fn updatePop( self : *Economy ) void
  {
    const foodAvailable = self.getResCount( .FOOD );
    const foodRequired  = self.getPopFoodCons();

    if( foodAvailable < foodRequired ) // Starvation
    {
      self.setResCount( .FOOD, 0 );

      const foodDeficit : f32 = @floatFromInt( foodRequired - foodAvailable );
      const popStarve   : f32 = foodDeficit / FOOD_PER_POP;

      self.population = self.population -| @as( u64, @intFromFloat( @ceil( popStarve / 12 ))); // losing 1/12 of starving pop at each update
    }
    else // Normal growth
    {
      self.subResCount( .FOOD, foodRequired );

      const popCap = self.getPopCap();

      if( self.population < popCap )
      {
        const pop : f32 = @floatFromInt( self.population );

        self.population = @intFromFloat( @ceil( pop * WEEKLY_POP_GROWTH ));

        if( self.population > popCap ){ self.population = popCap; }
      }
    }

    // Updating availalbe WORK amount for this cycle
    self.resArray[ ResType.WORK.toIdx() ] = self.getPopWorkProd();
  }


  // ================================ AREA ================================

  pub fn getUsedArea( self : *const Economy ) u64
  {
    var used : u64 = 0;

    inline for( 0..infTypeCount )| i |
    {
      const infType = InfType.fromIdx( i );

      used += self.getInfCount( infType ) * infType.getArea(); // TODO : rework for f32 area
    }

    return used;
  }

  pub fn getTotalArea( self : *const Economy ) u64
  {
    if( self.location == .GROUND and self.hasAtmosphere ) // If this is a planet with atmosphere
    {
      return self.maxAvailArea;
    }
    else // Else, area is grown via "area-extension" infra
    {
    //const infType = InfType.TBA.toIdx(); // TODO : implemnet area-extension infra

    //avail = self.getInfCount( infType ) * infType.getArea(); // TODO : rework for f32 area

      return  0;
    }
  }

  pub fn getAvailArea( self : *const Economy ) u64
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
      return 0;
    }
  }


  // ================================ UPDATING ================================

  pub fn tickEcon( self : *Economy ) void
  {
    self.updatePop();

    var solver: slv.EconSolver = .{};

    solver.solve( self );
  }
};