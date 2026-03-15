const std = @import( "std" );
const def = @import( "defs" );

const InfType = @import( "infrastructureData.zig" ).InfType;


pub const ResType = enum( u8 )
{
  pub const count = @typeInfo( ResType ).@"enum".fields.len;

  pub inline fn toIdx( self : ResType ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) ResType  { return @enumFromInt( @as( u8, @intCast( i ))); }

  WORK, // Each pop generate N work per cycle
//CASH, // Money
//FLOP, // Computation

  FOOD,
  WATER,
  POWER,

  ORE,
  INGOT,
  PART,


  pub inline fn getInfStore( self : ResType ) InfType // TODO : move to data array
  {
    _ = self;

    return .STORAGE; // TODO : update once multiple storage types exist
  }

  pub fn getMetric_f32( self : ResType, metric : ResMetricEnum ) f32
  {
    return resMetricData.get( self, metric );
  }
  pub fn getMetric_f64( self : ResType, metric : ResMetricEnum ) f64
  {
    return @floatCast( resMetricData.get( self, metric ));
  }
  pub fn getMetric_u32( self : ResType, metric : ResMetricEnum ) u32
  {
    return @intFromFloat( resMetricData.get( self, metric ));
  }
  pub fn getMetric_u64( self : ResType, metric : ResMetricEnum ) u64
  {
    return @intFromFloat( resMetricData.get( self, metric ));
  }
};


// ================================ RESOURCE METRICS GRID ================================

pub var resMetricData : def.NewDataGrid( f32, ResType, ResMetricEnum ) = .{};

pub const ResMetricEnum = enum
{
  MASS,
//CASH_COST,
  DECAY_RATE,
  GROWTH_RATE,
  POP_CONS,    // Resource consumed per pop per cycle
  POP_PROD,    // Resource produced per pop per cycle
};


pub fn loadResourceData() void
{
  resMetricData.fillWith( 0.0 );


  // ================================ MASS ================================

  resMetricData.set( .FOOD,  .MASS, 1.0 );
  resMetricData.set( .WATER, .MASS, 2.0 );
  resMetricData.set( .POWER, .MASS, 0.0 );

  resMetricData.set( .ORE,   .MASS, 5.0 );
  resMetricData.set( .INGOT, .MASS, 4.0 );
  resMetricData.set( .PART,  .MASS, 3.0 );


  // ================================ DECAY RATE ================================

  resMetricData.set( .WORK,  .DECAY_RATE, 1.00 ); // NOTE : DO NOT CONFUSE WITH getPerPopDelta() VALUE
                                                  //        Imagine wasting time on that bug... couldn't be me frfrf
  resMetricData.set( .FOOD,  .DECAY_RATE, 0.05 );
  resMetricData.set( .WATER, .DECAY_RATE, 0.02 );
  resMetricData.set( .POWER, .DECAY_RATE, 0.01 );

  resMetricData.set( .ORE,   .DECAY_RATE, 0.01 );
  resMetricData.set( .INGOT, .DECAY_RATE, 0.02 );
  resMetricData.set( .PART,  .DECAY_RATE, 0.03 );


  // ================================ GROWTH RATE ================================

  resMetricData.set( .FOOD,  .GROWTH_RATE, 150.0 );
  resMetricData.set( .WATER, .GROWTH_RATE, 200.0 );
  resMetricData.set( .POWER, .GROWTH_RATE, 100.0 );


  // ================================ POP CONS / PROD ================================

  resMetricData.set( .WORK,  .POP_PROD, 1.00 );

  resMetricData.set( .FOOD,  .POP_CONS, 0.40 );
  resMetricData.set( .WATER, .POP_CONS, 0.20 );
  resMetricData.set( .POWER, .POP_CONS, 0.10 );
}


// ================================ RESOURCE STATE GRID ================================
// NOTE : used in Economy to store local quantities and metrics

pub const ResStateData = def.NewDataGrid( f64, ResStateEnum, ResType );

pub const ResStateEnum = enum
{
  pub const count = @typeInfo( ResStateEnum ).@"enum".fields.len;

  BANK,       // Current stockpile           ( u64, but stored as f64 for uniformity )
  CAP,        // Storage capacity            ( u64, but stored as f64 for uniformity )

  DELTA,      // Net total change this tick  ( i64, but stored as f64 for uniformity )

  DECAY,      // Amount lost to stock decay this tick
  GROWTH,     // Amount gained from nature  this tick

  MAX_DEM,    // Total maximal consumption this tick
  MAX_SUP,    // Total maximal produciton  this tick

  FIN_DEM,    // Total applied consumption this tick
  FIN_SUP,    // Total applied produciton  this tick

  SAT_LVL,    // How much of demand could be satisfied by supply this tick
};

