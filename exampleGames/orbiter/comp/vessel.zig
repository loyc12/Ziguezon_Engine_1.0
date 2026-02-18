const std = @import( "std" );
const def = @import( "defs" );

const PowerSrc = @import( "powerSrc.zig" ).PowerSrc;


pub const vesTypeCount = @typeInfo( VesType ).@"enum".fields.len;

pub const VesType = enum( u8 )
{
  pub inline fn toIdx( self : VesType ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) VesType { return @enumFromInt( @as( u8, @intCast( i ))); }

  PROBE,
  SHUTTLE,
  STARSHIP, // Freighter
  STATION,

  pub inline fn getMass( self : VesType ) f32
  {
    return comptime switch( self )
    {
      .PROBE    => 1.0,
      .SHUTTLE  => 5.0,
      .STARSHIP => 25.0,
      .STATION  => 100.0,
    };
  }

  pub inline fn getPartCost( self : VesType ) u64 // Assembly cost in parts
  {
    return comptime switch( self )
    {
      .PROBE    => 1,
      .SHUTTLE  => 5,
      .STARSHIP => 25,
      .STATION  => 100,
    };
  }

  pub inline fn getJobCount( self : VesType ) u64
  {
    return switch( self )
    {
      .PROBE    => 0,
      .SHUTTLE  => 2,
      .STARSHIP => 20,
      .STATION  => 100,
    };
  }

};

//pub const Cash = f32;

pub const VehInstance = struct
{
  vesType    : VesType,
  powerSrc   : PowerSrc,
//baseCost   : Cash = 1.0, // For market simulation

  vehCount   : u64  = 0,
};