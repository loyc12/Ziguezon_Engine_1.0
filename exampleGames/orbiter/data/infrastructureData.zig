const std = @import( "std" );
const def = @import( "defs" );

const gbl = @import( "../gameGlobals.zig" );
const gdf = @import( "../gameDefs.zig"    );

//const PowerSrc = @import( "powerData.zig"       ).PowerSrc;


pub const InfType = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  pub inline fn toIdx( self : @This() ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) @This()  { return @enumFromInt( i ); }

  ASSEMBLY,     // Increases max building rate in PARTs per tick
  HOUSING,      // Increases population cap
  HABITAT,      // Increases area of pressurized locations
  STORAGE,      // Grants cargo storage capacity
//BATTERY,      // Grants energy storage capacity

//AMENITIES,    // Services population needs
//EDUCATION,    // Generate research
//COMMERCE,     // Increase tax revenues ?

//ROAD_NETWORK, // Grants cargo  transport capacity locally
//POWER_GRID,   // Grants energy transport capacity locally

//ELEVATOR,     // Grants cargo  transport capacity to and from orbit
//POWER_BEAM,   // Grants energy transport capacity to and from orbit

//LAUNCHPAD,    // Grants docking capacity for vessels

//DATA_CENTER,  // ???


  pub inline fn canBeBuiltIn( self : InfType, loc : gdf.EconLoc, hasAtmo : bool ) bool
  {
    _ = hasAtmo;

    if( loc == .GROUND )
    {
      return switch( self )
      {
        .ASSEMBLY => true,
        .HOUSING  => true,
        .HABITAT  => true,

        .STORAGE  => true,
      //.BATTERY  => true,POLLUTION,

      //else      => false,
      };
    }
    else // .ORBIT or .L1-5
    {
      return switch( self )
      {
        .ASSEMBLY => true,
        .HOUSING  => true,
        .HABITAT  => true,

        .STORAGE  => true,
      //.BATTERY  => true,

      //else      => false,
      };
    }
  }

  pub fn getMetric_f32( self : InfType, metric : InfMetricEnum ) f32
  {
    return @floatCast( infMetricData.get( self, metric ));
  }
  pub fn getMetric_f64( self : InfType, metric : InfMetricEnum ) f64
  {
    return infMetricData.get( self, metric );
  }
  pub fn getMetric_u32( self : InfType, metric : InfMetricEnum ) u32
  {
    return @intFromFloat( infMetricData.get( self, metric ));
  }
  pub fn getMetric_u64( self : InfType, metric : InfMetricEnum ) u64
  {
    return @intFromFloat( infMetricData.get( self, metric ));
  }
};


// ================================ INFRASTRUCTURE METRICS GRID ================================

pub var infMetricData : def.GenDataGrid( f64, InfType, InfMetricEnum ) = .{};

pub const InfMetricEnum = enum( u8 )
{
  MASS,
  AREA_COST,
  PART_COST,
  MAINT_RATE,
  POLLUTION,
  CAPACITY,
};


pub fn loadInfrastructureData() void
{
  infMetricData.fillWith( 0.0 );


  // ================================ MASS ================================

  infMetricData.set( .ASSEMBLY, .MASS, 4.0 );
  infMetricData.set( .HOUSING,  .MASS, 1.0 );
  infMetricData.set( .HABITAT,  .MASS, 3.0 );
  infMetricData.set( .STORAGE,  .MASS, 5.0 );


  // ================================ AREA COST ================================

  infMetricData.set( .ASSEMBLY, .AREA_COST, 5.0 );
  infMetricData.set( .HOUSING,  .AREA_COST, 1.0 );
  infMetricData.set( .HABITAT,  .AREA_COST, 0.0 ); // Provides area via capacity
  infMetricData.set( .STORAGE,  .AREA_COST, 4.0 );


  // ================================ PART COST ================================

  infMetricData.set( .ASSEMBLY, .PART_COST,  5.0 );
  infMetricData.set( .HOUSING,  .PART_COST,  2.0 );
  infMetricData.set( .HABITAT,  .PART_COST, 10.0 );
  infMetricData.set( .STORAGE,  .PART_COST,  1.0 );

  infMetricData.set( .ASSEMBLY, .MAINT_RATE, 0.005 );
  infMetricData.set( .HOUSING,  .MAINT_RATE, 0.002 );
  infMetricData.set( .HABITAT,  .MAINT_RATE, 0.003 );
  infMetricData.set( .STORAGE,  .MAINT_RATE, 0.001 );


  // ================================ POLLUTION ================================

  infMetricData.set( .ASSEMBLY, .POLLUTION, 1.0 );
  infMetricData.set( .HOUSING,  .POLLUTION, 0.2 );
  infMetricData.set( .HABITAT,  .POLLUTION, 0.1 );
  infMetricData.set( .STORAGE,  .POLLUTION, 0.1 );


  // ================================ CAPACITY ================================

  infMetricData.set( .ASSEMBLY, .CAPACITY,  1.0 ); // PARTs processed per tick
  infMetricData.set( .HOUSING,  .CAPACITY, 32.0 ); // Pop housed / WORK "stored"
  infMetricData.set( .HABITAT,  .CAPACITY, 16.0 ); // Area generated
  infMetricData.set( .STORAGE,  .CAPACITY, 16.0 ); // Non-WORK resources stored
}


// ================================ INFRASTRUCTURE STATE ENUM ================================
// NOTE : used in Economy to store local quantities and metrics

pub const InfStateData = def.GenDataGrid( f64, InfStateEnum, InfType );

pub const InfStateEnum = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  COUNT,   // Current infrastructure count
  DELTA,   // Net total change last tick

  DECAY,   // Amount lost to building decay   last tick
  BUILT,   // Amount gained from construction last tick

  EXPENSE, // Amount of money used for maintaining the infrastructure last tick
  REVENUE, // Amount of money gained from running  the infrastructure last tick
  PROFIT,  // Income - expense
  SAVINGS, // Stored profits from previous ticks ( decays via inflation )

  USE_LVL, // How much of the available infrastructure was used last tick
};
