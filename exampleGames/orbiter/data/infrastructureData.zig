const std = @import( "std" );
const def = @import( "defs" );

const gbl = @import( "../gameGlobals.zig" );

//const PowerSrc = @import( "powerData.zig"       ).PowerSrc;


pub const InfType = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  pub inline fn toIdx( self : InfType ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) InfType  { return @enumFromInt( @as( u8, @intCast( i ))); }

  HOUSING,      // Increases population cap
  HABITAT,      // Increase area of pressurized locations
  STORAGE,      // Grants cargo storage capacity
//BATTERY,      // Grants energy storage capacity

//AMENITIES,    // Services population needs
//EDUCATION,    // Generate research ( efficiency multiplier )
//COMMERCE,     // Increase tax revenues ?

//ROAD_NETWORK, // Grants cargo  transport capacity locally
//POWER_GRID,   // Grants energy transport capacity locally

//ELEVATOR,     // Grants cargo  transport capacity to and from orbit
//POWER_BEAM,   // Grants energy transport capacity to and from orbit

//LAUNCHPAD,    // Grants docking capacity for vessels

//DATA_CENTER,  // ???


  pub inline fn canBeBuiltIn( self : InfType, loc : gbl.EconLoc, hasAtmo : bool ) bool
  {
    _ = hasAtmo;

    if( loc == .GROUND )
    {
      return switch( self )
      {
        .HOUSING => true,
        .HABITAT => true,

        .STORAGE => true,
      //.BATTERY => true,POLLUTION,

      //else     => false,
      };
    }
    else // .ORBIT or .L1-5
    {
      return switch( self )
      {
        .HOUSING => true,
        .HABITAT => true,

        .STORAGE => true,
      //.BATTERY => true,

      //else     => false,
      };
    }
  }

  pub fn getMetric_f32( self : InfType, metric : InfMetricEnum ) f32
  {
    return infMetricData.get( self, metric );
  }
  pub fn getMetric_f64( self : InfType, metric : InfMetricEnum ) f64
  {
    return @floatCast( infMetricData.get( self, metric ));
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

pub var infMetricData : def.NewDataGrid( f64, InfType, InfMetricEnum ) = .{};

pub const InfMetricEnum = enum( u8 )
{
  MASS,
  AREA_COST,
  PART_COST,
//CASH_COST,
  POLLUTION,
  CAPACITY,
//POWER_SRC,
};


pub fn loadInfrastructureData() void
{
  infMetricData.fillWith( 0.0 );


  // ================================ MASS ================================

  infMetricData.set( .HOUSING, .MASS, 1.0 );
  infMetricData.set( .HABITAT, .MASS, 3.0 );
  infMetricData.set( .STORAGE, .MASS, 5.0 );


  // ================================ AREA COST ================================

  infMetricData.set( .HOUSING, .AREA_COST,  1.0 );
  infMetricData.set( .HABITAT, .AREA_COST,  0.0 ); // Provides area
  infMetricData.set( .STORAGE, .AREA_COST,  4.0 );


  // ================================ PART COST ================================

  infMetricData.set( .HOUSING, .PART_COST, 1.0 );
  infMetricData.set( .HABITAT, .PART_COST, 3.0 );
  infMetricData.set( .STORAGE, .PART_COST, 2.0 );


  // ================================ POLLUTION ================================

  infMetricData.set( .HOUSING, .POLLUTION, 0.1 );
  infMetricData.set( .HABITAT, .POLLUTION, 0.1 );
  infMetricData.set( .STORAGE, .POLLUTION, 0.1 );


  // ================================ CAPACITY ================================

  infMetricData.set( .HOUSING, .CAPACITY, 32.0 ); // Pop
  infMetricData.set( .HABITAT, .CAPACITY, 8.0  ); // Area
  infMetricData.set( .STORAGE, .CAPACITY, 16.0 ); // Resources
}


// ================================ INFRASTRUCTURE STATE ENUM ================================
// NOTE : used in Economy to store local quantities and metrics

pub const InfStateData = def.NewDataGrid( f64, InfStateEnum, InfType );

pub const InfStateEnum = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  BANK,       // Current stockpile           ( u64, but stored as f64 for uniformity )

  DELTA,      // Net total change this tick  ( i64, but stored as f64 for uniformity )

  DECAY,      // Amount lost to building decay this tick
  BUILT,      // Amount gained from construction this tick

  USE_LVL,    // How much of the infrastructure was used this tick
};
