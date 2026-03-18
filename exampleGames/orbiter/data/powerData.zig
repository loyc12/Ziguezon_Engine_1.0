const std = @import( "std" );
const def = @import( "defs" );


//pub const powerSrcCount = @typeInfo( PowerSrc ).@"enum".fields.len;

pub const PowerSrc = enum( u8 )
{
  pub const count = @typeInfo( PowerSrc ).@"enum".fields.len;

  pub inline fn toIdx( self : PowerSrc ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) PowerSrc  { return @enumFromInt( @as( u8, @intCast( i ))); }

  GRID,
  SOLAR,   // Efficiency divided by two on GROUND due to nighttime
//NUCLEAR,
//BEAM,

  pub fn getMetric_f32( self : PowerSrc, metric : PowerMetricEnum ) f32
  {
    return powerMetricData.get( self, metric );
  }
  pub fn getMetric_f64( self : PowerSrc, metric : PowerMetricEnum ) f64
  {
    return @floatCast( powerMetricData.get( self, metric ));
  }
  pub fn getMetric_u32( self : PowerSrc, metric : PowerMetricEnum ) u32
  {
    return @intFromFloat( powerMetricData.get( self, metric ));
  }
  pub fn getMetric_u64( self : PowerSrc, metric : PowerMetricEnum ) u64
  {
    return @intFromFloat( powerMetricData.get( self, metric ));
  }
};


pub var powerMetricData : def.NewDataGrid( f64, PowerSrc, PowerMetricEnum ) = .{};

pub const PowerMetricEnum = enum
{
  DUMMY,
};


pub fn loadPowerSrcData() void
{
  powerMetricData.fillWith( 0.0 );
}