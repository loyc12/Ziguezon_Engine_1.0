const std = @import( "std" );
const def = @import( "defs" );

const inf = @import( "infrastructure.zig" );
const res = @import( "resource.zig" );


pub const econLocCount = @typeInfo( EconLoc ).@"enum".fields.len;

pub const EconLoc = enum( u8 )
{
  pub inline fn toIdx( self : EconLoc ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : u8 ) EconLoc { return @enumFromInt( @as( u8, @intCast( i ))); }

  GROUND, // should not garantee breathable atmosphere
  ORBIT,
  L1,    // Lagrange Points
  L2,
  L3,
  L4,
  L5,
  COMET, // For microbodies only
};


pub const BuildOrder = struct
{
  infType  : inf.InfType,
  infCount : u32 = 0,
};


pub const EconComp = struct
{
  pub inline fn getStoreType() type { return def.componentStoreFactory( @This() ); }

  location : EconLoc,

  population : u32 = 0,
  efficiency : f32 = 1.0,

  unusedArea : u32 = 0,
  urbanArea  : u32 = 0,
  arableArea : u32 = 0,

//assemblyQueue

  resArray : [ res.resTypeCount ]u32 = std.mem.zeroes([ res.resTypeCount ]u32 ),
  infArray : [ inf.infTypeCount ]u32 = std.mem.zeroes([ inf.infTypeCount ]u32 ),


  // ================================ RESSOURCES ================================

  pub inline fn getResCount( self : *const EconComp, resType : .resType ) u32
  {
    return self.resArray[ resType.toIdx() ];
  }
  pub inline fn setResCount( self : *EconComp, resType : .resType, value : u32 ) void
  {
    self.resArray[ resType.toIdx() ] = value;
  }
  pub inline fn addResCount( self : *EconComp, resType : .resType, value : u32 ) void
  {
    self.resArray[ resType.toIdx() ] += value;
  }
  pub inline fn subResCount( self : *EconComp, resType : .resType, value : u32 ) void
  {
    const count = @min( value, self.resArray[ resType.toIdx() ]);

    self.resArray[ resType.toIdx() ] -= count;

    if( value != count )
    {
      def.log( .WARN, 0, @src(), "Tried to remove {d} res of type {s} from econComp, but only had {d} left", .{ value, @tagName( resType ), count });
    }
  }


  // ================================ INFRASTRUCTURE ================================

  pub inline fn getInfCount( self : *const EconComp, infType : .infType ) u32
  {
    return self.infArray[ infType.toIdx() ];
  }
  pub inline fn setInfCount( self : *EconComp, infType : .infType, value : u32 ) void
  {
    self.infArray[ infType.toIdx() ] = value;
  }
  pub inline fn addInfCount( self : *EconComp, infType : .infType, value : u32 ) void
  {
    self.infArray[ infType.toIdx() ] += value;
  }
  pub inline fn subInfCount( self : *EconComp, infType : .infType, value : u32 ) void
  {
    const count = @min( value, self.infArray[ infType.toIdx() ]);

    self.infArray[ infType.toIdx() ] -= count;

    if( value != count )
    {
      def.log( .WARN, 0, @src(), "Tried to remove {d} inf of type {s} from econComp, but only had {d} left", .{ value, @tagName( infType ), count });
    }
  }


  pub fn canBuildInf( self : *const EconComp, infType : inf.InfType, count : u32 ) bool
  {
    if( inf.InfType.canBeBuilt( infType, self.location ))
    {
      def.log( .INFO, 0, @src(), "You are not allowed to build infrastructure of type {} in location of type {}", .{ @tagName( infType ), @tagName( self.location ) });
      return false;
    }

    const  areaAvailable  = self.unusedArea;
    const  areaNeeded     = infType.getArea() * count;

    if( areaAvailable < areaNeeded )
    {
      def.log( .INFO, 0, @src(), "Not enough space to build infrastructure of type {} in location of type {}. Needed : {d}", .{ @tagName( infType ), @tagName( self.location ), areaNeeded });
      return true;
    }
    return true;
  }


  // ================================ POPULATION ================================

  const POP_PER_HOUSE = inf.InfType.HOUSING.getPop();
  const POP_PER_FOOD  = POP_PER_HOUSE; // How many pop can 1 unit of food sustain

  const WEEKLY_POP_GROWTH = 1.00022; // x ~PI each century

  pub fn getPopCap( self : *const EconComp ) u32
  {
    return self.getInfCount( .HOUSING ) * POP_PER_HOUSE;
  }

  pub fn getPopFoodCons( self : *const EconComp ) u32
  {
    const pop : f32 = @floatFromInt( self.population );

    return @intFromFloat( @ceil( pop / POP_PER_FOOD ));
  }

  pub fn updatePop( self : *EconComp ) void
  {
    const popCap        = self.getPopCap();
    const foodAvailable = self.getResCount( .FOOD );
    const foodRequired  = self.getPopFoodCons();

    if( foodAvailable < foodRequired )
    {
      // Starvation : lose population from food shortage

      const foodDeficit = foodRequired - foodAvailable;
      const popStarve   = @divTrunc( foodDeficit, POP_PER_FOOD * 12 );

      self.population = self.population -| popStarve;

      self.setResCount( .FOOD, 0 );
    }
    else
    {
      self.subResCount( .FOOD, foodRequired );

      if( self.population < popCap )
      {
        const pop : f32 = @floatFromInt( self.population );

        self.population = @intFromFloat( @ceil( pop * WEEKLY_POP_GROWTH ));

        if( self.population > popCap ){ self.population = popCap; }
      }
    }
  }


  // ================================ AREA ================================

  pub fn getUsedArea( self : *const EconComp ) u32
  {
    var used : u32 = 0;

    inline for( 0..inf.infTypeCount )| i |
    {
      const infType = inf.InfType.fromIdx( i );

      used += self.getInfCount( infType ) * infType.getArea();
    }

    return used;
  }

  pub fn getTotalArea( self : *const EconComp ) u32
  {
    return self.unusedArea + self.getUsedArea();
  }


  // ================================ CONSUMPTION & PRODUCTION ================================

  pub fn updateResources( self : *EconComp ) void
  {
    var infTypeEfficiency : [ inf.infTypeCount ]f32                     = std.mem.zeroes([ inf.infTypeCount ]f32 );
    var infTypeResProd    : [ inf.infTypeCount ][ res.resTypeCount ]u32 = std.mem.zeroes([ inf.infTypeCount ][ res.resTypeCount ]u32 );
    var infTypeResCons    : [ inf.infTypeCount ][ res.resTypeCount ]u32 = std.mem.zeroes([ inf.infTypeCount ][ res.resTypeCount ]u32 );

    var totalPowerProd : u32 = 0;
    var totalPowerCons : u32 = 0;

    // ================ PART 1: Calculate maximum resource deltas ================

    inline for( 0..inf.infTypeCount )| i |
    {
      const infType = inf.InfType.fromIdx( i );
      const count   = self.getInfCount( infType );

      if( count == 0 ) continue;

      const instance = inf.InfInstance.initByType( infType );

      inline for( 0..res.resTypeCount )| j |
      {
        const resType = res.ResType.fromIdx( j );

        infTypeResProd[ i ][ j ] = count * instance.getProdPerInf( resType );
        infTypeResCons[ i ][ j ] = count * instance.getConsPerInf( resType );

        if( resType == .POWER )
        {
          totalPowerProd += infTypeResProd[ i ][ j ];
          totalPowerCons += infTypeResCons[ i ][ j ];
        }
      }

      infTypeEfficiency[ i ] = 1.0;
    }

    // ================ PART 2: Update base efficiency ( power shortage ) ================

    self.addResCount( .POWER, totalPowerProd );

    const powerAvailable : f32 = @floatFromInt( self.getResCount( .POWER ));
    const powerRequired  : f32 = @floatFromInt( totalPowerCons );

    self.efficiency = if( powerRequired > 0 ) @min( 1.0, powerAvailable / powerRequired ) else 1.0;

    if( powerAvailable < powerRequired ){ self.setResCount( .POWER, 0 ); }
    else                                { self.subResCount( .POWER, totalPowerCons ); }

    // ================ PART 3: Update each infType's efficiency ( resource constraints ) ================

    inline for( 0..inf.infTypeCount )| i |
    {
      const infType = inf.InfType.fromIdx( i );
      const count   = self.getInfCount( infType );

      if( count == 0 ) continue;

      var resEfficiency : f32 = 1.0;

      inline for( 0..res.resTypeCount )| j |
      {
        const resType = res.ResType.fromIdx( j );

        // Skip POWER and FOOD ( consumed regardless of efficiency )
        if( resType == .POWER or resType == .FOOD ) continue;

        const resCons = infTypeResCons[ i ][ j ];

        if( resCons > 0 )
        {
          const resAvailable : f32 = @floatFromInt( self.getResCount( resType ));
          const resRequired  : f32 = @floatFromInt( resCons );

          const resEff  = @min( 1.0, resAvailable / resRequired );
          resEfficiency = @min( resEfficiency, resEff );
        }
      }

      infTypeEfficiency[ i ] = @min( self.efficiency, resEfficiency );
    }

    // TODO : lower efficiency based on pop shortage

    // ================ PART 4: Update resource counts based on individual efficiencies ================

    inline for( 0..inf.infTypeCount )| i |
    {
      const infType = inf.InfType.fromIdx( i );
      const count   = self.getInfCount( infType );

      if( count == 0 ) continue;

      const efficiency = infTypeEfficiency[ i ];

      inline for( 0..res.resTypeCount )| j |
      {
        const resType = res.ResType.fromIdx( j );

        const resProd : f32 = @floatFromInt( infTypeResProd[ i ][ j ] );
        const resCons : f32 = @floatFromInt( infTypeResCons[ i ][ j ] );

        // POWER and FOOD are fully consumed/produced regardless of efficiency
        if( resType == .POWER or resType == .FOOD )
        {
          continue; // Already handled elsewhere
        }

        // Apply efficiency multiplier to other resources
        const prodApplied : u32 = @intFromFloat( @floor( resProd * efficiency ));
        const consApplied : u32 = @intFromFloat( @ceil(  resCons * efficiency ));

        self.addResCount( resType, prodApplied );
        self.subResCount( resType, consApplied );
      }
    }
  }
};