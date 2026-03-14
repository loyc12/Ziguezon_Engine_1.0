const std = @import( "std" );
const def = @import( "defs" );


pub const vesTypeCount = @typeInfo( VesType ).@"enum".fields.len;

pub const VesType = enum( u8 )
{
  pub inline fn toIdx( self : VesType ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) VesType  { return @enumFromInt( @as( u8, @intCast( i ))); }

  PROBE,
  SHUTTLE,
  STARSHIP, // Freighter
  STATION,

  pub fn getMetric( self : VesType, metric : VesMetricEnum ) f32
  {
    return vesMetricData.get( self, metric );
  }
};


// Scalar metrics ( f32 )
pub var vesMetricData : def.newDataGrid( f32, VesType, VesMetricEnum ) = .{};

pub const VesMetricEnum = enum
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

}