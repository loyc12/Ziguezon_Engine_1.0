const std = @import( "std" );
const def = @import( "defs" );


pub const VesType = enum( u8 )
{
 pub const count = @typeInfo( @This() ).@"enum".fields.len;

  pub inline fn toIdx( self : @This() ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) @This()  { return @enumFromInt( @as( u8, @intCast( i ))); }

  PROBE,
  SHUTTLE,
  STARSHIP, // Freighter
  STATION,

  pub fn getMetric_f32( self : VesType, metric : VesMetricEnum ) f32
  {
    return vesMetricData.get( self, metric );
  }
  pub fn getMetric_f64( self : VesType, metric : VesMetricEnum ) f64
  {
    return @floatCast( vesMetricData.get( self, metric ));
  }
  pub fn getMetric_u32( self : VesType, metric : VesMetricEnum ) u32
  {
    return @intFromFloat( vesMetricData.get( self, metric ));
  }
  pub fn getMetric_u64( self : VesType, metric : VesMetricEnum ) u64
  {
    return @intFromFloat( vesMetricData.get( self, metric ));
  }
};


pub var vesMetricData : def.GenDataGrid( f64, VesType, VesMetricEnum ) = .{};

pub const VesMetricEnum = enum( u8 )
{
  MASS,
  PART_COST,
//CASH_COST,
  CAPACITY,
  CREW_COUNT,
//POWER_SRC,
};


pub fn loadVesselData() void
{
  vesMetricData.fillWith( 0.0 );


  // ================================ MASS ================================

  vesMetricData.set( .PROBE,    .MASS,   1.0 );
  vesMetricData.set( .SHUTTLE,  .MASS,   5.0 );
  vesMetricData.set( .STARSHIP, .MASS,  25.0 );
  vesMetricData.set( .STATION,  .MASS, 100.0 );


  // ================================ PART COST ================================

  vesMetricData.set( .PROBE,    .PART_COST,   1.0 );
  vesMetricData.set( .SHUTTLE,  .PART_COST,   8.0 );
  vesMetricData.set( .STARSHIP, .PART_COST,  64.0 );
  vesMetricData.set( .STATION,  .PART_COST, 512.0 );


  // ================================ CAPACITY ================================

  vesMetricData.set( .PROBE,    .CAPACITY,   5.0 );
  vesMetricData.set( .SHUTTLE,  .CAPACITY,  25.0 );
  vesMetricData.set( .STARSHIP, .CAPACITY, 125.0 );
  vesMetricData.set( .STATION,  .CAPACITY, 625.0 );


  // ================================ CREW COUNT ================================

  vesMetricData.set( .PROBE,    .CREW_COUNT,   0.0 );
  vesMetricData.set( .SHUTTLE,  .CREW_COUNT,   2.0 );
  vesMetricData.set( .STARSHIP, .CREW_COUNT,  20.0 );
  vesMetricData.set( .STATION,  .CREW_COUNT, 200.0 );
}