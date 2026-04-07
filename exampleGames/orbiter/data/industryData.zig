const std = @import( "std"  );
const def = @import( "defs" );

const gbl = @import( "../gameGlobals.zig" );
const gdf = @import( "../gameDefs.zig"    );

const ResType  = @import( "resourceData.zig" ).ResType;
const PowerSrc = @import( "powerData.zig"    ).PowerSrc;


pub const CAPITAL_DECAY_RATE = 0.02;

pub const IndType = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  pub inline fn toIdx( self : @This() ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) @This()  { return @enumFromInt( i ); }

  AGRONOMIC,    // Generate food   ( solar powered )
  HYDROPONIC,   // Generate food   ( grid powered )
  WATER_PLANT,  // Generate water  ( grid powered )
  SOLAR_PLANT,  // Generate energy ( solar powered )
//POWER_PLANT,  // Generate energy ( fission / fusion )

  PROBE_MINE,   // Extracts raw materials ( autonomous but restricted to asteroids )
  GROUND_MINE,  // Extracts raw materials
  REFINERY,     // Refines  raw materials
  FACTORY,      // Create parts from refined materials
  ASSEMBLY,     // Assembles parts into industry, infrastructure & vehicles


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

        .GROUND_MINE => true,
        .REFINERY    => true,
        .FACTORY     => true,
        .ASSEMBLY    => true,

        else => false,
      };
    }
    else // .ORBIT or .L1-5
    {
      return switch( self )
      {
        .HYDROPONIC  => true,
        .SOLAR_PLANT => true,

        .REFINERY    => true,
        .FACTORY     => true,
        .ASSEMBLY    => true,

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
    return indMetricData.get( self, metric );
  }
  pub fn getMetric_f64( self : IndType, metric : IndMetricEnum ) f64
  {
    return @floatCast( indMetricData.get( self, metric ));
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
    return @floatFromInt( indResDeltaTable.get( self, .CONS, resType  ));
  }
  pub fn getResCons_f64( self : IndType, resType : ResType ) f64
  {
    return @floatFromInt( indResDeltaTable.get( self, .CONS, resType  ));
  }
  pub fn getResCons_u32( self : IndType, resType : ResType ) u32
  {
    return @intCast( indResDeltaTable.get( self, .CONS, resType  ));
  }
  pub fn getResCons_u64( self : IndType, resType : ResType ) u64
  {
    return indResDeltaTable.get( self, .CONS, resType  );
  }

  pub fn getResProd_f32( self : IndType, resType : ResType ) f32
  {
    return @floatFromInt( indResDeltaTable.get( self, .PROD, resType ));
  }
  pub fn getResProd_f64( self : IndType, resType : ResType ) f64
  {
    return @floatFromInt( indResDeltaTable.get( self, .PROD, resType ));
  }
  pub fn getResProd_u32( self : IndType, resType : ResType ) u32
  {
    return @intCast( indResDeltaTable.get( self, .PROD, resType ));
  }
  pub fn getResProd_u64( self : IndType, resType : ResType ) u64
  {
    return indResDeltaTable.get( self, .PROD, resType );
  }

};


// ================================ INDUSTRY METRICS GRID ================================

pub var indMetricData : def.GenDataGrid( f64, IndType, IndMetricEnum ) = .{};

pub const IndMetricEnum = enum( u8 )
{
  MASS,

  AREA_COST,
  PART_COST,
  POLLUTION,

//POWER_SRC,
};


// ================================ INDUSTRY CONS / PROD GRID ================================

// Resource consumption / production per industry ( u64 )
pub var indResDeltaTable : def.GenDataCube( u64, IndType, ResActionEnum, ResType ) = .{};

pub const ResActionEnum = enum( u8 )
{
  CONS,
  PROD,
};


pub fn loadIndustryData() void
{
  indMetricData.fillWith(   0.0 );
  indResDeltaTable.fillWith( 0.0 );

  // ================================ METRICS ================================

  indMetricData.set( .AGRONOMIC,   .MASS,       1.0 );
  indMetricData.set( .HYDROPONIC,  .MASS,       3.0 );
  indMetricData.set( .WATER_PLANT, .MASS,       5.0 );
  indMetricData.set( .SOLAR_PLANT, .MASS,       2.0 );
  indMetricData.set( .PROBE_MINE,  .MASS,       3.0 );
  indMetricData.set( .GROUND_MINE, .MASS,      15.0 );
  indMetricData.set( .REFINERY,    .MASS,      10.0 );
  indMetricData.set( .FACTORY,     .MASS,       5.0 );
  indMetricData.set( .ASSEMBLY,    .MASS,       4.0 );

  indMetricData.set( .AGRONOMIC,   .AREA_COST, 25.0 );
  indMetricData.set( .HYDROPONIC,  .AREA_COST,  5.0 );
  indMetricData.set( .WATER_PLANT, .AREA_COST,  3.0 );
  indMetricData.set( .SOLAR_PLANT, .AREA_COST, 15.0 );
  indMetricData.set( .PROBE_MINE,  .AREA_COST,  1.0 );
  indMetricData.set( .GROUND_MINE, .AREA_COST, 10.0 );
  indMetricData.set( .REFINERY,    .AREA_COST,  5.0 );
  indMetricData.set( .FACTORY,     .AREA_COST,  5.0 );
  indMetricData.set( .ASSEMBLY,    .AREA_COST,  5.0 );

  indMetricData.set( .AGRONOMIC,   .PART_COST, 1.0  );
  indMetricData.set( .HYDROPONIC,  .PART_COST, 2.0  );
  indMetricData.set( .WATER_PLANT, .PART_COST, 2.0  );
  indMetricData.set( .SOLAR_PLANT, .PART_COST, 3.0  );
  indMetricData.set( .PROBE_MINE,  .PART_COST, 1.0  );
  indMetricData.set( .GROUND_MINE, .PART_COST, 2.0  );
  indMetricData.set( .REFINERY,    .PART_COST, 3.0  );
  indMetricData.set( .FACTORY,     .PART_COST, 4.0  );
  indMetricData.set( .ASSEMBLY,    .PART_COST, 5.0  );

  indMetricData.set( .AGRONOMIC,   .POLLUTION, 1.0  );
  indMetricData.set( .HYDROPONIC,  .POLLUTION, 0.0  );
  indMetricData.set( .WATER_PLANT, .POLLUTION, 0.5  );
  indMetricData.set( .SOLAR_PLANT, .POLLUTION, 0.0  );
  indMetricData.set( .PROBE_MINE,  .POLLUTION, 1.0  );
  indMetricData.set( .GROUND_MINE, .POLLUTION, 8.0  );
  indMetricData.set( .REFINERY,    .POLLUTION, 8.0  );
  indMetricData.set( .FACTORY,     .POLLUTION, 4.0  );
  indMetricData.set( .ASSEMBLY,    .POLLUTION, 2.0  );


  // ================================ RESOURCES ================================

  indResDeltaTable.set( .AGRONOMIC,   .CONS, .WORK,  20 );
  indResDeltaTable.set( .AGRONOMIC,   .CONS, .WATER, 8  );
  indResDeltaTable.set( .AGRONOMIC,   .PROD, .FOOD,  20 );

  indResDeltaTable.set( .HYDROPONIC,  .CONS, .WORK,  40 );
  indResDeltaTable.set( .HYDROPONIC,  .CONS, .WATER, 4  );
  indResDeltaTable.set( .HYDROPONIC,  .CONS, .POWER, 4  );
  indResDeltaTable.set( .HYDROPONIC,  .PROD, .FOOD,  20 );

  indResDeltaTable.set( .WATER_PLANT, .CONS, .WORK,  20 );
  indResDeltaTable.set( .WATER_PLANT, .CONS, .POWER, 4  );
  indResDeltaTable.set( .WATER_PLANT, .PROD, .WATER, 16 );

  indResDeltaTable.set( .SOLAR_PLANT, .CONS, .WORK,  10 );
  indResDeltaTable.set( .SOLAR_PLANT, .PROD, .POWER, 50 ); // NOTE : take into acount day/night effciciency loss on GROUND

  indResDeltaTable.set( .PROBE_MINE,  .PROD, .ORE,   1  );

  indResDeltaTable.set( .GROUND_MINE, .CONS, .WORK,  50 );
  indResDeltaTable.set( .GROUND_MINE, .CONS, .WATER, 5  );
  indResDeltaTable.set( .GROUND_MINE, .CONS, .POWER, 4  );
  indResDeltaTable.set( .GROUND_MINE, .PROD, .ORE,   3  );

  indResDeltaTable.set( .REFINERY,    .CONS, .WORK,  40 );
  indResDeltaTable.set( .REFINERY,    .CONS, .POWER, 4  );
  indResDeltaTable.set( .REFINERY,    .CONS, .ORE,   4  );
  indResDeltaTable.set( .REFINERY,    .PROD, .INGOT, 3  );

  indResDeltaTable.set( .FACTORY,     .CONS, .WORK,  30 );
  indResDeltaTable.set( .FACTORY,     .CONS, .POWER, 3  );
  indResDeltaTable.set( .FACTORY,     .CONS, .INGOT, 4  );
  indResDeltaTable.set( .FACTORY,     .PROD, .PART,  3  );

  indResDeltaTable.set( .ASSEMBLY,    .CONS, .WORK,  20 );
  indResDeltaTable.set( .ASSEMBLY,    .CONS, .POWER, 2  );
}


// ================================ INDUSTRY STATE GRID ================================
// NOTE : used in Economy to store local quantities and metrics

pub const IndStateData = def.GenDataGrid( f64, IndStateEnum, IndType );

pub const IndStateEnum = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  BANK,     // Current industry count
  DELTA,    // Net total change last tick

  DECAY,    // Amount lost to building decay   last tick
  BUILT,    // Amount gained from construction last tick

  EXPENSE,  // Amount of money spent by the owners to maintain and fuel the industry last tick
  REVENUE,  // Amount of money gained by the owners from selling the output products last tick

  PROFIT,   // Revenues - Costs
  CAPITAL,  // Stored profits from previous ticks ( decays )

  ACT_TRGT, // How active this industry wanted to be   last tick
  ACT_LVL,  // How active this industry ended up being last tick
};

