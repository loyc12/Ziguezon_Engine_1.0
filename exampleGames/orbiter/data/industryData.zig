const std = @import( "std"  );
const def = @import( "defs" );

const gbl = @import( "../gameGlobals.zig" );
const gdf = @import( "../gameDefs.zig"    );

const ResType  = @import( "resourceData.zig" ).ResType;
const PowerSrc = @import( "powerData.zig"    ).PowerSrc;


pub const IndType = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  pub inline fn toIdx( self : @This() ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) @This()  { return @enumFromInt( i ); }

  AGRONOMIC,    // Generates food   ( solar powered )
  HYDROPONIC,   // Generates food   ( grid powered )
  WATER_PLANT,  // Generates water  ( grid powered )
  SOLAR_PLANT,  // Generates energy ( solar powered )
  POWER_PLANT,  // Generates energy ( fusion powered )

  REFINERY,     // Refines fusion fuels / propellant
  PROBE_MINE,   // Extracts raw materials ( autonomous but restricted to asteroids )
  GROUND_MINE,  // Extracts raw materials
  FOUNDRY,      // Moulds ingots
  FACTORY,      // Create parts from refined materials


  pub inline fn canBeBuiltIn( self : IndType, loc : gdf.EconLoc, hasAtmo : bool ) bool
  {
    if( loc == .GROUND )
    {
      return switch( self )
      {
        .AGRONOMIC   => hasAtmo,
        .HYDROPONIC  => true,
        .WATER_PLANT => true,
        .SOLAR_PLANT => true,
        .POWER_PLANT => true,

        .REFINERY    => true,
        .PROBE_MINE  => !hasAtmo,
        .GROUND_MINE => true,
        .FOUNDRY     => true,
        .FACTORY     => true,
      };
    }
    else // .ORBIT or .L1-5
    {
      return switch( self )
      {
        .HYDROPONIC  => true,
        .SOLAR_PLANT => true,
        .POWER_PLANT => true,

        .REFINERY    => true,
        .FOUNDRY     => true,
        .FACTORY     => true,

        else => false,
      };
    }
  }

  pub inline fn getPowerSrc( self : IndType ) PowerSrc
  {
    return switch( self ) // TODO : move to data array
    {
      .AGRONOMIC   => .SOLAR,
      .SOLAR_PLANT => .SOLAR,
      .PROBE_MINE  => .SOLAR,

      else => .GRID,
    };
  }

  pub fn getMetric_f32( self : IndType, metric : IndMetricEnum ) f32
  {
    return @floatCast( indMetricData.get( self, metric ));
  }
  pub fn getMetric_f64( self : IndType, metric : IndMetricEnum ) f64
  {
    return indMetricData.get( self, metric );
  }
  pub fn getMetric_u32( self : IndType, metric : IndMetricEnum ) u32
  {
    return @intFromFloat( indMetricData.get( self, metric ));
  }
  pub fn getMetric_u64( self : IndType, metric : IndMetricEnum ) u64
  {
    return @intFromFloat( indMetricData.get( self, metric ));
  }

  pub fn getResCons_f32( self : IndType, resType : ResType ) f32
  {
    return @floatCast( indResDeltaTable.get( self, .CONS, resType ));
  }
  pub fn getResCons_f64( self : IndType, resType : ResType ) f64
  {
    return indResDeltaTable.get( self, .CONS, resType );
  }
  pub fn getResCons_u32( self : IndType, resType : ResType ) u32
  {
    return @intFromFloat( indResDeltaTable.get( self, .CONS, resType ));
  }
  pub fn getResCons_u64( self : IndType, resType : ResType ) u64
  {
    return @intFromFloat( indResDeltaTable.get( self, .CONS, resType ));
  }

  pub fn getResProd_f32( self : IndType, resType : ResType ) f32
  {
    return @floatCast( indResDeltaTable.get( self, .PROD, resType ));
  }
  pub fn getResProd_f64( self : IndType, resType : ResType ) f64
  {
    return indResDeltaTable.get( self, .PROD, resType );
  }
  pub fn getResProd_u32( self : IndType, resType : ResType ) u32
  {
    return @intFromFloat( indResDeltaTable.get( self, .PROD, resType ));
  }
  pub fn getResProd_u64( self : IndType, resType : ResType ) u64
  {
    return @intFromFloat( indResDeltaTable.get( self, .PROD, resType ));
  }
};


// ================================ INDUSTRY METRICS GRID ================================

pub var indMetricData : def.GenDataGrid( f64, IndType, IndMetricEnum ) = .{};

pub const IndMetricEnum = enum( u8 )
{
  MASS,
  AREA_COST,
  PART_COST,
  MAINT_RATE,
  POLLUTION,
};


// ================================ INDUSTRY CONS / PROD GRID ================================

// Resource consumption / production per industry ( u64 )
pub var indResDeltaTable : def.GenDataCube( f64, IndType, ResActionEnum, ResType ) = .{};

pub const ResActionEnum = enum( u8 )
{
  CONS,
  PROD,
};


pub fn loadIndustryData() void
{
  indMetricData.fillWith(    0.0 );
  indResDeltaTable.fillWith( 0.0 );


  // ================================ MASS ================================
  // Unit : Gt. These represent single large facilities
  // These are intentionally tiny in Gt - they represent single facilities

  indMetricData.set( .AGRONOMIC,   .MASS, 0.000_000_002 ); //    ~2,000 t — equipment, barns, irrigation
  indMetricData.set( .HYDROPONIC,  .MASS, 0.000_000_015 ); //   ~15,000 t — multi-storey grow facility
  indMetricData.set( .WATER_PLANT, .MASS, 0.000_000_020 ); //   ~20,000 t — treatment/desalination plant
  indMetricData.set( .SOLAR_PLANT, .MASS, 0.000_000_010 ); //   ~10,000 t — 100 MW of panels + inverters
  indMetricData.set( .POWER_PLANT, .MASS, 0.000_000_080 ); //   ~80,000 t — fusion reactor + containment

  indMetricData.set( .REFINERY,    .MASS, 0.000_000_050 ); //   ~50,000 t — processing columns, tanks
  indMetricData.set( .PROBE_MINE,  .MASS, 0.000_000_001 ); //    ~1,000 t — autonomous spacecraft
  indMetricData.set( .GROUND_MINE, .MASS, 0.000_000_100 ); //  ~100,000 t — excavators, conveyors, processing
  indMetricData.set( .FOUNDRY,     .MASS, 0.000_000_060 ); //   ~60,000 t — furnaces, casting equipment
  indMetricData.set( .FACTORY,     .MASS, 0.000_000_040 ); //   ~40,000 t — assembly lines, tooling


  // ================================ AREA COST ================================
  // Unit : km². Constrained to 0.01–1.00 km² (1–100 ha)

  indMetricData.set( .AGRONOMIC,   .AREA_COST, 0.50 ); // 50 ha — large mechanized farm
  indMetricData.set( .HYDROPONIC,  .AREA_COST, 0.05 ); //  5 ha — vertical, compact footprint
  indMetricData.set( .WATER_PLANT, .AREA_COST, 0.05 ); //  5 ha — treatment plant + settling basins
  indMetricData.set( .SOLAR_PLANT, .AREA_COST, 0.50 ); // 50 ha — 100 MW solar farm (~2 ha/MW)
  indMetricData.set( .POWER_PLANT, .AREA_COST, 0.03 ); //  3 ha — fusion plant, very compact per MW

  indMetricData.set( .REFINERY,    .AREA_COST, 0.10 ); // 10 ha — processing plant + tank farm
  indMetricData.set( .PROBE_MINE,  .AREA_COST, 0.01 ); //  1 ha — launch pad / control station
  indMetricData.set( .GROUND_MINE, .AREA_COST, 0.50 ); // 50 ha — open pit + tailings + processing
  indMetricData.set( .FOUNDRY,     .AREA_COST, 0.20 ); // 20 ha — smelter + slag yards + cooling
  indMetricData.set( .FACTORY,     .AREA_COST, 0.15 ); // 15 ha — assembly halls + logistics yard


  // ================================ PART COST ================================
  // Unit : t of manufactured parts to construct one facility
  // Real-world: a large factory costs ~$500M–2B; at ~$2000/t for manufactured goods ≈ 250k–1M t
  // We use the lower end since PART represents high-value components

  indMetricData.set( .AGRONOMIC,   .PART_COST,   500.0 );  // Tractors, irrigation, barns — relatively cheap
  indMetricData.set( .HYDROPONIC,  .PART_COST,  8000.0 );  // LED arrays, climate systems, grow racks
  indMetricData.set( .WATER_PLANT, .PART_COST, 10000.0 );  // Membranes, pumps, piping
  indMetricData.set( .SOLAR_PLANT, .PART_COST,  5000.0 );  // Panels, inverters, mounting — mass-produced
  indMetricData.set( .POWER_PLANT, .PART_COST, 80000.0 );  // Fusion containment, superconductors, turbines

  indMetricData.set( .REFINERY,    .PART_COST, 20000.0 );  // Distillation columns, centrifuges, tanks
  indMetricData.set( .PROBE_MINE,  .PART_COST,  1000.0 );  // Small autonomous spacecraft
  indMetricData.set( .GROUND_MINE, .PART_COST, 15000.0 );  // Excavators, conveyors, crushers
  indMetricData.set( .FOUNDRY,     .PART_COST, 25000.0 );  // Blast furnaces, rolling mills
  indMetricData.set( .FACTORY,     .PART_COST, 20000.0 );  // Assembly lines, CNC machines, robotics


  // ================================ MAINT RATE ================================
  // Fraction of PART_COST consumed as PART per week
  // annual_rate / 52. Farms ~2%, heavy industry ~4-6%, high-tech ~3%

  indMetricData.set( .AGRONOMIC,   .MAINT_RATE, 0.0004 ); // ~2% annual — simple equipment
  indMetricData.set( .HYDROPONIC,  .MAINT_RATE, 0.0006 ); // ~3% annual — LEDs, pumps wear out
  indMetricData.set( .WATER_PLANT, .MAINT_RATE, 0.0006 ); // ~3% annual — membrane replacement
  indMetricData.set( .SOLAR_PLANT, .MAINT_RATE, 0.0004 ); // ~2% annual — panels are low-maintenance
  indMetricData.set( .POWER_PLANT, .MAINT_RATE, 0.0008 ); // ~4% annual — high-tech, critical systems

  indMetricData.set( .REFINERY,    .MAINT_RATE, 0.0008 ); // ~4% annual — corrosive environment
  indMetricData.set( .PROBE_MINE,  .MAINT_RATE, 0.0000 ); // Needs to be fully autonomous
  indMetricData.set( .GROUND_MINE, .MAINT_RATE, 0.0010 ); // ~5% annual — extreme wear on equipment
  indMetricData.set( .FOUNDRY,     .MAINT_RATE, 0.0010 ); // ~5% annual — thermal cycling, slag damage
  indMetricData.set( .FACTORY,     .MAINT_RATE, 0.0008 ); // ~4% annual — tooling wear, robotics upkeep


  // ================================ POLLUTION ================================
  // Units: tCO2e per facility per tick (week) at full activity
  // Calibrated with NATURAL_CAPACITY=0.2, POLLUTION_MIDPOINT=2.0, pop=0.05/person
  // Target: 1B pop → pollution ~0.08, 10B pop → pollution ~0.65

  indMetricData.set( .AGRONOMIC,   .POLLUTION, 12.0 ); // Methane, fertiliser runoff
  indMetricData.set( .HYDROPONIC,  .POLLUTION,  3.0 ); // Contained system, minor waste
  indMetricData.set( .WATER_PLANT, .POLLUTION,  4.0 ); // Brine discharge, chemical treatment
  indMetricData.set( .SOLAR_PLANT, .POLLUTION,  1.5 ); // Manufacturing waste (amortised)
  indMetricData.set( .POWER_PLANT, .POLLUTION,  8.0 ); // Thermal pollution, tritium traces

  indMetricData.set( .REFINERY,    .POLLUTION, 25.0 ); // VOCs, chemical waste, thermal
  indMetricData.set( .PROBE_MINE,  .POLLUTION,  0.0 ); // Off-planet
  indMetricData.set( .GROUND_MINE, .POLLUTION, 50.0 ); // Tailings, acid drainage, dust
  indMetricData.set( .FOUNDRY,     .POLLUTION, 40.0 ); // Slag, thermal, heavy metal emissions
  indMetricData.set( .FACTORY,     .POLLUTION, 20.0 ); // Chemical waste, minor emissions


  // ================================ RESOURCES ================================
  // All values per facility per tick (week) at full activity
  // WORK unit: person-weeks. A worker producing 0.45 pw means each WORK unit ≈ 2.22 people


  // ---- AGRONOMIC ----
  // 50-hectare mechanized farm, ~120 total staff (field + logistics + processing)
  // Produces ~500 t of grain/produce per week (50 ha × 10 t/ha harvest, amortised weekly)
  // Consumes significant water for irrigation: ~2,500 t/week (50mm/week over 50 ha)

  indResDeltaTable.set( .AGRONOMIC, .CONS, .WORK,    55.0 );
  indResDeltaTable.set( .AGRONOMIC, .CONS, .WATER, 2500.0 );
  indResDeltaTable.set( .AGRONOMIC, .PROD, .FOOD,   500.0 ); // NOTE: reduced by sunAccess and ecoFactor


  // ---- HYDROPONIC ----
  // Large vertical farm, ~200 total staff
  // Very water-efficient (~90% recirculation), but power-hungry (LEDs)
  // Higher yield per area but lower total output than a 50ha farm

  indResDeltaTable.set( .HYDROPONIC, .CONS, .WORK,   90.0 );
  indResDeltaTable.set( .HYDROPONIC, .CONS, .WATER, 200.0 );
  indResDeltaTable.set( .HYDROPONIC, .CONS, .POWER, 500.0 );
  indResDeltaTable.set( .HYDROPONIC, .PROD, .FOOD,  300.0 ); // NOTE : Less total output but no sunAccess/ecoFactor dependency


  // ---- WATER_PLANT ----
  // Municipal desalination/treatment plant, ~120 total staff
  // Produces ~50,000 m³/week (serves ~70,000 people at 0.7 t/person/week)
  // Very power-intensive (3-4 kWh per m³ for desalination)

  indResDeltaTable.set( .WATER_PLANT, .CONS, .WORK,     55.0 );
  indResDeltaTable.set( .WATER_PLANT, .CONS, .POWER,   200.0 );
  indResDeltaTable.set( .WATER_PLANT, .PROD, .WATER, 50000.0 );


  // ---- SOLAR_PLANT ----
  // 100 MW peak solar farm, ~45 total staff (technicians + grid management)
  // Produces ~100 MW × 168 h × 0.20 capacity factor = ~3,360 MWh/week
  // Needs water for panel washing: ~50 t/week

  indResDeltaTable.set( .SOLAR_PLANT, .CONS, .WORK,    20.0 );
  indResDeltaTable.set( .SOLAR_PLANT, .CONS, .WATER,   50.0 );
  indResDeltaTable.set( .SOLAR_PLANT, .PROD, .POWER, 3400.0 ); // NOTE: reduced by sunAccess


  // ---- POWER_PLANT ----
  // 500 MW fusion reactor, ~450 total staff
  // Produces 500 MW × 168 h × 0.85 capacity factor = ~71,400 MWh/week
  // Consumes deuterium/tritium (FUEL) and cooling water

  indResDeltaTable.set( .POWER_PLANT, .CONS, .WORK,    200.0 );
  indResDeltaTable.set( .POWER_PLANT, .CONS, .WATER,   500.0 );
  indResDeltaTable.set( .POWER_PLANT, .CONS, .FUEL,      5.0 );
  indResDeltaTable.set( .POWER_PLANT, .PROD, .POWER, 71500.0 );


  // ---- REFINERY ----
  // Fuel processing / isotope separation plant, ~300 total staff
  // Produces fusion fuel from raw feedstock
  // Very power and water hungry

  indResDeltaTable.set( .REFINERY, .CONS, .WORK,  135.0 );
  indResDeltaTable.set( .REFINERY, .CONS, .WATER, 400.0 );
  indResDeltaTable.set( .REFINERY, .CONS, .POWER, 500.0 );
  indResDeltaTable.set( .REFINERY, .PROD, .FUEL,   50.0 );


  // ---- PROBE_MINE ----
  // Autonomous asteroid mining probe, 0 workers

  indResDeltaTable.set( .PROBE_MINE, .PROD, .ORE, 10.0 );


  // ---- GROUND_MINE ----
  // Large open-pit mine, ~650 total staff
  // Extracts ~5,000 t/week of usable ore from ~50,000 t of overburden
  // Consumes water for dust suppression and ore washing

  indResDeltaTable.set( .GROUND_MINE, .CONS, .WORK,   290.0 );
  indResDeltaTable.set( .GROUND_MINE, .CONS, .POWER,  300.0 );
  indResDeltaTable.set( .GROUND_MINE, .CONS, .WATER, 1500.0 );
  indResDeltaTable.set( .GROUND_MINE, .PROD, .ORE,   5000.0 );


  // ---- FOUNDRY ----
  // Steel/aluminium smelter, ~450 total staff
  // Converts ore to ingot at roughly 4:3 by mass (ore contains ~50-80% metal)
  // Very power-intensive (electric arc furnaces)

  indResDeltaTable.set( .FOUNDRY, .CONS, .WORK,   200.0 );
  indResDeltaTable.set( .FOUNDRY, .CONS, .POWER,  500.0 );
  indResDeltaTable.set( .FOUNDRY, .CONS, .ORE,   4000.0 );
  indResDeltaTable.set( .FOUNDRY, .PROD, .INGOT, 3000.0 );


  // ---- FACTORY ----
  // Large manufacturing plant, ~450 total staff
  // Converts ingots to finished parts ( 75% yield, rest is scrap/waste )
  // Moderate power, high skill labor

  indResDeltaTable.set( .FACTORY, .CONS, .WORK,   200.0 );
  indResDeltaTable.set( .FACTORY, .CONS, .POWER,  200.0 );
  indResDeltaTable.set( .FACTORY, .CONS, .INGOT, 2000.0 );
  indResDeltaTable.set( .FACTORY, .PROD, .PART,  1500.0 );
}


// ================================ INDUSTRY STATE GRID ================================
// NOTE : used in Economy to store local quantities and metrics

pub const IndStateData = def.GenDataGrid( f64, IndStateEnum, IndType );

pub const IndStateEnum = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  COUNT,    // Current industry count
  DELTA,    // Net total change last tick

  DECAY,    // Amount lost to building decay   last tick
  BUILT,    // Amount gained from construction last tick

  EXPENSE,  // Amount of money spent by the owners to maintain and fuel the industry last tick
  REVENUE,  // Amount of money gained by the owners from selling the output products last tick
  PROFIT,   // Revenues - Expenses
  MARGIN,   // Profits / Expense
  CAPITAL,  // Stored profits from previous ticks ( decays via inflation )

  ACT_TRGT, // How active this industry wanted to be   last tick
  ACT_LVL,  // How active this industry ended up being last tick
};

