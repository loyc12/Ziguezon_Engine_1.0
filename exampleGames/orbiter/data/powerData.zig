const std = @import( "std" );
const def = @import( "defs" );


pub const powerSrcCount = @typeInfo( PowerSrc ).@"enum".fields.len;

pub const PowerSrc = enum( u8 )
{
  pub inline fn toIdx( self : PowerSrc ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) PowerSrc  { return @enumFromInt( @as( u8, @intCast( i ))); }

  GRID,
  SOLAR,   // Efficiency divided by two on GROUND due to nighttime
//NUCLEAR,
//BEAM,

  pub fn getMetric( self : PowerSrc, metric : PowerMetricEnum ) f32
  {
    return powerMetricData.get( self, metric );
  }
};


// Scalar metrics ( f32 )
pub var powerMetricData : def.newDataGrid( f32, PowerSrc, PowerMetricEnum ) = .{};

pub const PowerMetricEnum = enum
{
  DUMMY,
};


pub fn loadPowerSrcData() void
{
  powerMetricData.fillWith( 0.0 );
}