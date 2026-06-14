const std = @import( "std"  );
const eng = @import( "engine" );
const utl = @import( "utils" );

const gbl = @import( "../gameGlobals.zig" );
const gdf = @import( "../gameDef.zig"    );

const nfrs_d = @import( "infrastructureData.zig" );
const ndst_d = @import( "industryData.zig"       );
const rsrc_d = @import( "resourceData.zig"       );

const InfType = nfrs_d.InfType;
const IndType = ndst_d.IndType;
const ResType = rsrc_d.ResType;


// ================================ FACILITY TYPE ================================

/// Unified static facility identity for the Phase 1 economy rewrite.
/// This is a data/model mirror only; live economies still use `InfType` and
/// `IndType` until a later runtime migration slice.
pub const FacilityType = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  pub inline fn toIdx( self : @This() ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) @This()  { return @enumFromInt( i ); }

  // Capacity / service facilities
  HABITAT,      // Increases pressurized area
  DEPOT,        // Provides shared ordinary-resource storage
  HOUSING,      // Provides population housing capacity
  ASSEMBLY,     // Provides construction effort capacity

//BATTERY_BANK, // Future energy storage capacity
//DATA_CENTER,  // Future computation capacity
//MARKETPLACE,  // Future commerce / tax surface
//LAUNCHPAD,    // Future transport capacity
//MASSDRIVER,   // Future transport capacity
//ELEVATOR,     // Future surface-orbit transport capacity

  // Growth / extraction / manufacturing facilities
  AGRONOMIC,    // Generates food from land, water, labour, and solar access
  HYDROPONIC,   // Generates food from water, power, and labour
  WATER_PLANT,  // Generates water
  SOLAR_PLANT,  // Generates power from solar access
  POWER_PLANT,  // Generates power from fuel

  REFINERY,     // Refines fuel
  GROUND_MINE,  // Extracts ore from ground sites
  FOUNDRY,      // Converts ore into ingots
  FACTORY,      // Converts ingots into parts

  PROBE_MINE,   // Extracts ore through autonomous probes

//SHIPYARD,
//COLLEGE,
//LABORATORY,
//WASTE_PLANT,
//GAS_REFINERY,
//POWER_NETWORK,
//WATER_NETWORK,
//TRANSIT_NETWORK,


  pub inline fn getCategory( self : FacilityType ) FacilityCategory
  {
    return switch( self )
    {
      .HABITAT,
      .HOUSING,
      .ASSEMBLY     => .CAPACITY,

      .DEPOT        => .SERVICE,

      .AGRONOMIC,
      .HYDROPONIC   => .GROWTH,

      .WATER_PLANT,
      .SOLAR_PLANT,
      .POWER_PLANT,
      .REFINERY,
      .GROUND_MINE,
      .PROBE_MINE   => .EXTRACTION,

      .FOUNDRY,
      .FACTORY      => .MANUFACTURING,
    };
  }

  pub inline fn fromInfType( infT : InfType ) FacilityType
  {
    return switch( infT )
    {
      .HABITAT  => .HABITAT,
      .DEPOT    => .DEPOT,
      .HOUSING  => .HOUSING,
      .ASSEMBLY => .ASSEMBLY,
    };
  }

  pub inline fn fromIndType( indT : IndType ) FacilityType
  {
    return switch( indT )
    {
      .AGRONOMIC   => .AGRONOMIC,
      .HYDROPONIC  => .HYDROPONIC,
      .WATER_PLANT => .WATER_PLANT,
      .SOLAR_PLANT => .SOLAR_PLANT,
      .POWER_PLANT => .POWER_PLANT,
      .REFINERY    => .REFINERY,
      .GROUND_MINE => .GROUND_MINE,
      .FOUNDRY     => .FOUNDRY,
      .FACTORY     => .FACTORY,
      .PROBE_MINE  => .PROBE_MINE,
    };
  }

  pub inline fn toLegacy( self : FacilityType ) LegacyFacility
  {
    return switch( self )
    {
      .HABITAT      => .{ .infT = .HABITAT  },
      .DEPOT        => .{ .infT = .DEPOT    },
      .HOUSING      => .{ .infT = .HOUSING  },
      .ASSEMBLY     => .{ .infT = .ASSEMBLY },

      .AGRONOMIC    => .{ .indT = .AGRONOMIC   },
      .HYDROPONIC   => .{ .indT = .HYDROPONIC  },
      .WATER_PLANT  => .{ .indT = .WATER_PLANT },
      .SOLAR_PLANT  => .{ .indT = .SOLAR_PLANT },
      .POWER_PLANT  => .{ .indT = .POWER_PLANT },
      .REFINERY     => .{ .indT = .REFINERY    },
      .GROUND_MINE  => .{ .indT = .GROUND_MINE },
      .FOUNDRY      => .{ .indT = .FOUNDRY     },
      .FACTORY      => .{ .indT = .FACTORY     },
      .PROBE_MINE   => .{ .indT = .PROBE_MINE  },
    };
  }

  /// Mirrors current location-gating behavior without moving live logic off
  /// `InfType` / `IndType` yet.
  pub inline fn canBeBuiltIn( self : FacilityType, loc : gdf.EconLoc, hasAtmo : bool ) bool
  {
    return switch( self.toLegacy() )
    {
      .infT => | infT | infT.canBeBuiltIn( loc, hasAtmo ),
      .indT => | indT | indT.canBeBuiltIn( loc, hasAtmo ),
    };
  }

  pub fn getMetric_f32( self : FacilityType, metric : FacilityMetricEnum ) f32
  {
    return @floatCast( facilityMetricData.get( self, metric ));
  }
  pub fn getMetric_f64( self : FacilityType, metric : FacilityMetricEnum ) f64
  {
    return facilityMetricData.get( self, metric );
  }
  pub fn getMetric_u32( self : FacilityType, metric : FacilityMetricEnum ) u32
  {
    return @intFromFloat( facilityMetricData.get( self, metric ));
  }
  pub fn getMetric_u64( self : FacilityType, metric : FacilityMetricEnum ) u64
  {
    return @intFromFloat( facilityMetricData.get( self, metric ));
  }

  pub fn getCapacity_f64( self : FacilityType, capacity : FacilityCapacityEnum ) f64
  {
    return facilityCapacityData.get( self, capacity );
  }
  pub fn getCapacity_u64( self : FacilityType, capacity : FacilityCapacityEnum ) u64
  {
    return @intFromFloat( facilityCapacityData.get( self, capacity ));
  }

  pub fn getResMetric_f32( self : FacilityType, metric : FacilityResMetricEnum, resT : ResType ) f32
  {
    return @floatCast( facilityResMetricTable.get( self, metric, resT ));
  }
  pub fn getResMetric_f64( self : FacilityType, metric : FacilityResMetricEnum, resT : ResType ) f64
  {
    return facilityResMetricTable.get( self, metric, resT );
  }
  pub fn getResMetric_u32( self : FacilityType, metric : FacilityResMetricEnum, resT : ResType ) u32
  {
    return @intFromFloat( facilityResMetricTable.get( self, metric, resT ));
  }
  pub fn getResMetric_u64( self : FacilityType, metric : FacilityResMetricEnum, resT : ResType ) u64
  {
    return @intFromFloat( facilityResMetricTable.get( self, metric, resT ));
  }
};

/// Back-reference to the live pre-facility type that a `FacilityType` mirrors.
pub const LegacyFacility = union( enum )
{
  infT : InfType,
  indT : IndType,
};

pub const FacilityCategory = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  pub inline fn toIdx( self : @This() ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) @This()  { return @enumFromInt( i ); }

  GROWTH,
  EXTRACTION,
  MANUFACTURING,
  SERVICE,
  TRANSPORTATION,
  CAPACITY,
};


// ================================ FACILITY BASE METRICS GRID ================================
// NOTE : Mostly-static per-facility values

pub var facilityMetricData : utl.GenDataGrid( f64, FacilityType, FacilityMetricEnum ) = .{};

pub const FacilityMetricEnum = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  MASS,      // Gt of facility mass; 1 Gt = 1e12 kg
  AREA_COST, // km2 of local area consumed by one facility
  CNST_COST, // Abstract construction effort required to complete one build
  POLLUTION, // Pollution generated per tick at full use/activity
};


// ================================ FACILITY CAPACITY GRID ================================
// NOTE : Capacity resources are split by meaning instead of using one generic scalar.

pub var facilityCapacityData : utl.GenDataGrid( f64, FacilityType, FacilityCapacityEnum ) = .{};

pub const FacilityCapacityEnum = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  AREA,         // km2 of pressurized/buildable area provided
  STORAGE,      // t-equivalent shared ordinary-resource storage provided
  HOUSING,      // people housed
  CONSTRUCTION, // construction effort throughput per tick
};


// ================================ FACILITY RES METRICS GRID ================================
// NOTE : Mostly-static per-facility & resource values

pub var facilityResMetricTable : utl.GenDataCube( f64, FacilityType, FacilityResMetricEnum, ResType ) = .{};

pub const FacilityResMetricEnum = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  CONS,  // Resource units consumed per tick at full use/activity
  PROD,  // Resource units produced per tick at full use/activity

  BUILD, // One-time resource units consumed to build one facility
  MAINT, // Resource units consumed per tick for maintenance
};


// ================================ DATA INITIALIZATION ================================

pub fn loadFacilityData() void
{
  facilityMetricData.fillWith(    0.0 );
  facilityCapacityData.fillWith(  0.0 );
  facilityResMetricTable.fillWith( 0.0 );

  loadLegacyInfrastructureFacilities();
  loadLegacyIndustryFacilities();

  facilityMetricData.isInit    = true;
  facilityCapacityData.isInit  = true;
  facilityResMetricTable.isInit = true;
}

fn loadLegacyInfrastructureFacilities() void
{
  // ================================ BASE METRICS ================================
  // MASS is Gt, AREA_COST is km2, CNST_COST is abstract build effort,
  // and POLLUTION is abstract pollution points per facility per tick.

  facilityMetricData.set( .ASSEMBLY, .MASS, 0.000_000_040 );
  facilityMetricData.set( .HOUSING,  .MASS, 0.000_000_010 );
  facilityMetricData.set( .HABITAT,  .MASS, 0.000_000_050 );
  facilityMetricData.set( .DEPOT,    .MASS, 0.000_000_015 );

  facilityMetricData.set( .ASSEMBLY, .AREA_COST, 0.20 );
  facilityMetricData.set( .HOUSING,  .AREA_COST, 0.02 );
  facilityMetricData.set( .HABITAT,  .AREA_COST, 0.00 );
  facilityMetricData.set( .DEPOT,    .AREA_COST, 0.05 );

  facilityMetricData.set( .ASSEMBLY, .CNST_COST, 1.00 );
  facilityMetricData.set( .HOUSING,  .CNST_COST, 1.00 );
  facilityMetricData.set( .HABITAT,  .CNST_COST, 1.00 );
  facilityMetricData.set( .DEPOT,    .CNST_COST, 1.00 );

  facilityMetricData.set( .ASSEMBLY, .POLLUTION, 1.0 );
  facilityMetricData.set( .HOUSING,  .POLLUTION, 0.3 );
  facilityMetricData.set( .HABITAT,  .POLLUTION, 0.0 );
  facilityMetricData.set( .DEPOT,    .POLLUTION, 0.1 );


  // ================================ CAPACITY OUTPUTS ================================
  // ASSEMBLY gives construction throughput per tick, HOUSING gives people,
  // HABITAT gives km2 of pressurized area, and DEPOT gives t-equivalent storage.

  facilityCapacityData.set( .ASSEMBLY, .CONSTRUCTION,  100.0 );
  facilityCapacityData.set( .HOUSING,  .HOUSING,       100.0 );
  facilityCapacityData.set( .HABITAT,  .AREA,            1.0 );
  facilityCapacityData.set( .DEPOT,    .STORAGE,      5000.0 );


  // ================================ RESOURCE COSTS ================================
  // BUILD is t of PART needed to construct one facility.
  // MAINT is the weekly fraction of that PART cost consumed for upkeep.

  facilityResMetricTable.set( .ASSEMBLY, .BUILD, .PART, 10000.0 );
  facilityResMetricTable.set( .HOUSING,  .BUILD, .PART,  2000.0 );
  facilityResMetricTable.set( .HABITAT,  .BUILD, .PART, 50000.0 );
  facilityResMetricTable.set( .DEPOT,    .BUILD, .PART,  3000.0 );

  facilityResMetricTable.set( .ASSEMBLY, .MAINT, .PART, 10000.0 * 0.0006 );
  facilityResMetricTable.set( .HOUSING,  .MAINT, .PART,  2000.0 * 0.0003 );
  facilityResMetricTable.set( .HABITAT,  .MAINT, .PART, 50000.0 * 0.0008 );
  facilityResMetricTable.set( .DEPOT,    .MAINT, .PART,  3000.0 * 0.0004 );
}

fn loadLegacyIndustryFacilities() void
{
  // ================================ BASE METRICS ================================
  // MASS is Gt, AREA_COST is km2, CNST_COST is abstract build effort,
  // and POLLUTION mirrors the legacy tCO2e-ish per-week industry values.

  facilityMetricData.set( .AGRONOMIC,   .MASS, 0.000_000_002 );
  facilityMetricData.set( .HYDROPONIC,  .MASS, 0.000_000_015 );
  facilityMetricData.set( .WATER_PLANT, .MASS, 0.000_000_020 );
  facilityMetricData.set( .SOLAR_PLANT, .MASS, 0.000_000_010 );
  facilityMetricData.set( .POWER_PLANT, .MASS, 0.000_000_080 );

  facilityMetricData.set( .REFINERY,    .MASS, 0.000_000_050 );
  facilityMetricData.set( .GROUND_MINE, .MASS, 0.000_000_100 );
  facilityMetricData.set( .FOUNDRY,     .MASS, 0.000_000_060 );
  facilityMetricData.set( .FACTORY,     .MASS, 0.000_000_040 );

  facilityMetricData.set( .PROBE_MINE,  .MASS, 0.000_000_001 );


  facilityMetricData.set( .AGRONOMIC,   .AREA_COST, 0.50 );
  facilityMetricData.set( .HYDROPONIC,  .AREA_COST, 0.05 );
  facilityMetricData.set( .WATER_PLANT, .AREA_COST, 0.05 );
  facilityMetricData.set( .SOLAR_PLANT, .AREA_COST, 0.50 );
  facilityMetricData.set( .POWER_PLANT, .AREA_COST, 0.03 );

  facilityMetricData.set( .REFINERY,    .AREA_COST, 0.10 );
  facilityMetricData.set( .GROUND_MINE, .AREA_COST, 0.50 );
  facilityMetricData.set( .FOUNDRY,     .AREA_COST, 0.20 );
  facilityMetricData.set( .FACTORY,     .AREA_COST, 0.15 );

  facilityMetricData.set( .PROBE_MINE,  .AREA_COST, 0.01 );


  facilityMetricData.set( .AGRONOMIC,   .CNST_COST, 1.00 );
  facilityMetricData.set( .HYDROPONIC,  .CNST_COST, 1.00 );
  facilityMetricData.set( .WATER_PLANT, .CNST_COST, 1.00 );
  facilityMetricData.set( .SOLAR_PLANT, .CNST_COST, 1.00 );
  facilityMetricData.set( .POWER_PLANT, .CNST_COST, 1.00 );

  facilityMetricData.set( .REFINERY,    .CNST_COST, 1.00 );
  facilityMetricData.set( .GROUND_MINE, .CNST_COST, 1.00 );
  facilityMetricData.set( .FOUNDRY,     .CNST_COST, 1.00 );
  facilityMetricData.set( .FACTORY,     .CNST_COST, 1.00 );

  facilityMetricData.set( .PROBE_MINE,  .CNST_COST, 0.00 );


  facilityMetricData.set( .AGRONOMIC,   .POLLUTION,  8.0 );
  facilityMetricData.set( .HYDROPONIC,  .POLLUTION,  1.0 );
  facilityMetricData.set( .WATER_PLANT, .POLLUTION,  2.0 );
  facilityMetricData.set( .SOLAR_PLANT, .POLLUTION,  0.0 );
  facilityMetricData.set( .POWER_PLANT, .POLLUTION,  4.0 );

  facilityMetricData.set( .REFINERY,    .POLLUTION, 20.0 );
  facilityMetricData.set( .GROUND_MINE, .POLLUTION, 40.0 );
  facilityMetricData.set( .FOUNDRY,     .POLLUTION, 30.0 );
  facilityMetricData.set( .FACTORY,     .POLLUTION, 20.0 );

  facilityMetricData.set( .PROBE_MINE,  .POLLUTION,  0.0 );


  // ================================ OPERATIONAL RESOURCE FLOWS ================================
  // All values are per facility per tick (week) at full activity.
  // LABOUR is person-weeks, POWER is MWh, and stockpiled materials are metric tons.
  // TODO: Redesign power-source behavior before moving solar/grid scaling into
  // facility metadata. The live path still uses `IndType.getPowerSrc()`.

  facilityResMetricTable.set( .AGRONOMIC, .CONS, .LABOUR,    55.0 );
  facilityResMetricTable.set( .AGRONOMIC, .CONS, .WATER,   5000.0 );
  facilityResMetricTable.set( .AGRONOMIC, .PROD, .FOOD,     500.0 );

  facilityResMetricTable.set( .HYDROPONIC, .CONS, .LABOUR,   90.0 );
  facilityResMetricTable.set( .HYDROPONIC, .CONS, .WATER,   200.0 );
  facilityResMetricTable.set( .HYDROPONIC, .CONS, .POWER,   500.0 );
  facilityResMetricTable.set( .HYDROPONIC, .PROD, .FOOD,    300.0 );

  facilityResMetricTable.set( .WATER_PLANT, .CONS, .LABOUR,   180.0 );
  facilityResMetricTable.set( .WATER_PLANT, .CONS, .POWER,    200.0 );
  facilityResMetricTable.set( .WATER_PLANT, .PROD, .WATER,  40000.0 );

  facilityResMetricTable.set( .SOLAR_PLANT, .CONS, .LABOUR,   40.0 );
  facilityResMetricTable.set( .SOLAR_PLANT, .CONS, .WATER,    50.0 );
  facilityResMetricTable.set( .SOLAR_PLANT, .PROD, .POWER,  3000.0 );

  facilityResMetricTable.set( .POWER_PLANT, .CONS, .LABOUR,   200.0 );
  facilityResMetricTable.set( .POWER_PLANT, .CONS, .WATER,    500.0 );
  facilityResMetricTable.set( .POWER_PLANT, .CONS, .FUEL,      10.0 );
  facilityResMetricTable.set( .POWER_PLANT, .PROD, .POWER,  20000.0 );

  facilityResMetricTable.set( .REFINERY, .CONS, .LABOUR, 150.0 );
  facilityResMetricTable.set( .REFINERY, .CONS, .WATER,  200.0 );
  facilityResMetricTable.set( .REFINERY, .CONS, .POWER,  500.0 );
  facilityResMetricTable.set( .REFINERY, .PROD, .FUEL,    50.0 );

  facilityResMetricTable.set( .GROUND_MINE, .CONS, .LABOUR,  300.0 );
  facilityResMetricTable.set( .GROUND_MINE, .CONS, .POWER,  1000.0 );
  facilityResMetricTable.set( .GROUND_MINE, .CONS, .WATER,  2500.0 );
  facilityResMetricTable.set( .GROUND_MINE, .PROD, .ORE,    5000.0 );

  facilityResMetricTable.set( .FOUNDRY, .CONS, .LABOUR,  300.0 );
  facilityResMetricTable.set( .FOUNDRY, .CONS, .POWER,   500.0 );
  facilityResMetricTable.set( .FOUNDRY, .CONS, .ORE,    5000.0 );
  facilityResMetricTable.set( .FOUNDRY, .PROD, .INGOT,  4000.0 );

  facilityResMetricTable.set( .FACTORY, .CONS, .LABOUR,  300.0 );
  facilityResMetricTable.set( .FACTORY, .CONS, .POWER,   200.0 );
  facilityResMetricTable.set( .FACTORY, .CONS, .INGOT,  2000.0 );
  facilityResMetricTable.set( .FACTORY, .PROD, .PART,   1500.0 );

  facilityResMetricTable.set( .PROBE_MINE, .PROD, .ORE, 10.0 );


  // ================================ RESOURCE COSTS ================================
  // BUILD is t of PART needed to construct one facility.
  // MAINT is the weekly fraction of that PART cost consumed for upkeep.

  facilityResMetricTable.set( .AGRONOMIC,   .BUILD, .PART,   500.0 );
  facilityResMetricTable.set( .HYDROPONIC,  .BUILD, .PART,  8000.0 );
  facilityResMetricTable.set( .WATER_PLANT, .BUILD, .PART, 10000.0 );
  facilityResMetricTable.set( .SOLAR_PLANT, .BUILD, .PART,  5000.0 );
  facilityResMetricTable.set( .POWER_PLANT, .BUILD, .PART, 80000.0 );

  facilityResMetricTable.set( .REFINERY,    .BUILD, .PART, 20000.0 );
  facilityResMetricTable.set( .GROUND_MINE, .BUILD, .PART, 15000.0 );
  facilityResMetricTable.set( .FOUNDRY,     .BUILD, .PART, 25000.0 );
  facilityResMetricTable.set( .FACTORY,     .BUILD, .PART, 20000.0 );

  facilityResMetricTable.set( .PROBE_MINE,  .BUILD, .PART,  1000.0 );


  facilityResMetricTable.set( .AGRONOMIC,   .MAINT, .PART,   500.0 * 0.0004 );
  facilityResMetricTable.set( .HYDROPONIC,  .MAINT, .PART,  8000.0 * 0.0006 );
  facilityResMetricTable.set( .WATER_PLANT, .MAINT, .PART, 10000.0 * 0.0006 );
  facilityResMetricTable.set( .SOLAR_PLANT, .MAINT, .PART,  5000.0 * 0.0004 );
  facilityResMetricTable.set( .POWER_PLANT, .MAINT, .PART, 80000.0 * 0.0008 );

  facilityResMetricTable.set( .REFINERY,    .MAINT, .PART, 20000.0 * 0.0008 );
  facilityResMetricTable.set( .GROUND_MINE, .MAINT, .PART, 15000.0 * 0.0010 );
  facilityResMetricTable.set( .FOUNDRY,     .MAINT, .PART, 25000.0 * 0.0010 );
  facilityResMetricTable.set( .FACTORY,     .MAINT, .PART, 20000.0 * 0.0008 );

  facilityResMetricTable.set( .PROBE_MINE,  .MAINT, .PART, 0.0 );
}


// ================================ TESTS ================================

test "FacilityType maps current infrastructure and industry types"
{
  try std.testing.expectEqual( FacilityType.HOUSING,     FacilityType.fromInfType( .HOUSING    ));
  try std.testing.expectEqual( FacilityType.GROUND_MINE, FacilityType.fromIndType( .GROUND_MINE ));

  try std.testing.expect( FacilityType.HOUSING.toLegacy().infT == .HOUSING );
  try std.testing.expect( FacilityType.GROUND_MINE.toLegacy().indT == .GROUND_MINE );
}

test "facility data separates capacity outputs from base metrics"
{
  loadFacilityData();

  try std.testing.expectApproxEqAbs( @as( f64, 100.0 ), FacilityType.HOUSING.getCapacity_f64( .HOUSING ), 0.0001 );
  try std.testing.expectApproxEqAbs( @as( f64, 5000.0 ), FacilityType.DEPOT.getCapacity_f64( .STORAGE ), 0.0001 );
  try std.testing.expectApproxEqAbs( @as( f64, 0.50 ), FacilityType.GROUND_MINE.getMetric_f64( .AREA_COST ), 0.0001 );
  try std.testing.expectApproxEqAbs( @as( f64, 1.00 ), FacilityType.GROUND_MINE.getMetric_f64( .CNST_COST ), 0.0001 );
}
