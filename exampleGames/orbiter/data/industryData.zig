const std = @import( "std" );
const def = @import( "defs" );

const gbl = @import( "../gameGlobals.zig" );

const ResType  = @import( "resourceData.zig"    ).ResType;
const PowerSrc = @import( "powerData.zig"       ).PowerSrc;


pub const IndType = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  pub inline fn toIdx( self : @This() ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) @This()  { return @enumFromInt( @as( u8, @intCast( i ))); }

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


  pub inline fn canBeBuiltIn( self : IndType, loc : gbl.EconLoc, hasAtmo : bool ) bool
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
    return @floatFromInt( indResValData.get( self, IndResValEnum.consTypeFromResType( resType )));
  }
  pub fn getResCons_f64( self : IndType, resType : ResType ) f64
  {
    return @floatFromInt( indResValData.get( self, IndResValEnum.consTypeFromResType( resType )));
  }
  pub fn getResCons_u32( self : IndType, resType : ResType ) u32
  {
    return @intCast( indResValData.get( self, IndResValEnum.consTypeFromResType( resType )));
  }
  pub fn getResCons_u64( self : IndType, resType : ResType ) u64
  {
    return indResValData.get( self, IndResValEnum.consTypeFromResType( resType ));
  }

  pub fn getResProd_f32( self : IndType, resType : ResType ) f32
  {
    return @floatFromInt( indResValData.get( self, IndResValEnum.prodTypeFromResType( resType )));
  }
  pub fn getResProd_f64( self : IndType, resType : ResType ) f64
  {
    return @floatFromInt( indResValData.get( self, IndResValEnum.prodTypeFromResType( resType )));
  }
  pub fn getResProd_u32( self : IndType, resType : ResType ) u32
  {
    return @intCast( indResValData.get( self, IndResValEnum.prodTypeFromResType( resType )));
  }
  pub fn getResProd_u64( self : IndType, resType : ResType ) u64
  {
    return indResValData.get( self, IndResValEnum.prodTypeFromResType( resType ));
  }

};


// ================================ INDUSTRY METRICS GRID ================================

pub var indMetricData : def.GenDataGrid( f64, IndType, IndMetricEnum ) = .{};

pub const IndMetricEnum = enum( u8 )
{
  MASS,
  AREA_COST,
  PART_COST,
//CASH_COST,
  POLLUTION,
//POWER_SRC,
};


// ================================ INDUSTRY CONS / PROD GRID ================================

// Resource consumption / production per industry ( u64 )
pub var indResValData : def.GenDataGrid( u64, IndType, IndResValEnum ) = .{};

pub const IndResValEnum = enum( u8 )
{
  CONS_WORK,
  PROD_WORK,

  CONS_FOOD,
  PROD_FOOD,

  CONS_WATER,
  PROD_WATER,

  CONS_POWER,
  PROD_POWER,

  CONS_ORE,
  PROD_ORE,

  CONS_INGOT,
  PROD_INGOT,

  CONS_PART,
  PROD_PART,

  pub inline fn consTypeFromResType( resType : ResType ) IndResValEnum
  {
    return switch( resType )
    {
      .WORK  => return .CONS_WORK,
      .FOOD  => return .CONS_FOOD,
      .WATER => return .CONS_WATER,
      .POWER => return .CONS_POWER,
      .ORE   => return .CONS_ORE,
      .INGOT => return .CONS_INGOT,
      .PART  => return .CONS_PART,
    };
  }

  pub inline fn prodTypeFromResType( resType : ResType ) IndResValEnum
  {
    return switch( resType )
    {
      .WORK  => return .PROD_WORK,
      .FOOD  => return .PROD_FOOD,
      .WATER => return .PROD_WATER,
      .POWER => return .PROD_POWER,
      .ORE   => return .PROD_ORE,
      .INGOT => return .PROD_INGOT,
      .PART  => return .PROD_PART,
    };
  }
};


pub fn loadIndustryData() void
{
  indMetricData.fillWith( 0.0 );
  indResValData.fillWith( 0   );

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

  indResValData.set( .AGRONOMIC,   .CONS_WORK,  2  );
  indResValData.set( .AGRONOMIC,   .CONS_WATER, 6  );
  indResValData.set( .AGRONOMIC,   .PROD_FOOD,  16 );

  indResValData.set( .HYDROPONIC,  .CONS_WORK,  4  );
  indResValData.set( .HYDROPONIC,  .CONS_WATER, 4  );
  indResValData.set( .HYDROPONIC,  .CONS_POWER, 4  );
  indResValData.set( .HYDROPONIC,  .PROD_FOOD,  16 );

  indResValData.set( .WATER_PLANT, .CONS_WORK,  2  );
  indResValData.set( .WATER_PLANT, .CONS_POWER, 4  );
  indResValData.set( .WATER_PLANT, .PROD_WATER, 16 );

  indResValData.set( .SOLAR_PLANT, .CONS_WORK,  1  );
  indResValData.set( .SOLAR_PLANT, .PROD_POWER, 32 );

  indResValData.set( .PROBE_MINE,  .PROD_ORE,   1  );

  indResValData.set( .GROUND_MINE, .CONS_WORK,  3  );
  indResValData.set( .GROUND_MINE, .CONS_WATER, 1  );
  indResValData.set( .GROUND_MINE, .CONS_POWER, 3  );
  indResValData.set( .GROUND_MINE, .PROD_ORE,   1  );

  indResValData.set( .REFINERY,    .CONS_WORK,  3  );
  indResValData.set( .REFINERY,    .CONS_POWER, 3  );
  indResValData.set( .REFINERY,    .CONS_ORE,   2  );
  indResValData.set( .REFINERY,    .PROD_INGOT, 1  );

  indResValData.set( .FACTORY,     .CONS_WORK,  3  );
  indResValData.set( .FACTORY,     .CONS_POWER, 3  );
  indResValData.set( .FACTORY,     .CONS_INGOT, 2  );
  indResValData.set( .FACTORY,     .PROD_PART,  1  );

  indResValData.set( .ASSEMBLY,    .CONS_WORK,  2  );
  indResValData.set( .ASSEMBLY,    .CONS_POWER, 2  );
}


// ================================ INDUSTRY STATE GRID ================================
// NOTE : used in Economy to store local quantities and metrics

pub const IndStateData = def.GenDataGrid( f64, IndStateEnum, IndType );

pub const IndStateEnum = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  BANK,       // Current stockpile           ( u64, but stored as f64 for uniformity )

  DELTA,      // Net total change this tick  ( i64, but stored as f64 for uniformity )

  DECAY,      // Amount lost to building decay this tick
  BUILT,      // Amount gained from construction this tick

  ACT_LVL,    // How active this industry was this tick
};

