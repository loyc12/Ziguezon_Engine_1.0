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
   return switch( self )
    {
      .PROBE    => 1.0,
      .SHUTTLE  => 5.0,
      .STARSHIP => 25.0,
      .STATION  => 100.0,
    };
  }

  pub inline fn getPartCost( self : VesType ) u64 // Assembly cost in parts
  {
   return switch( self )
    {
      .PROBE    => 1,
      .SHUTTLE  => 8,
      .STARSHIP => 64,
      .STATION  => 512,
    };
  }

  pub inline fn getCapacity( self : VesType ) u64
  {
    return switch( self )
    {
      .PROBE    => 5,
      .SHUTTLE  => 25,
      .STARSHIP => 125,
      .STATION  => 625,
    };
  }

  pub inline fn getCrewCount( self : VesType ) u64
  {
    return switch( self )
    {
      .PROBE    => 0,
      .SHUTTLE  => 2,
      .STARSHIP => 20,
      .STATION  => 200,
    };
  }

};

//pub const Cash = f32;

pub const VesInstance = struct
{
  vesType    : VesType,
  powerSrc   : PowerSrc,
//baseCost   : Cash = 1.0, // For market simulation

  vesCount   : u64  = 0,
};