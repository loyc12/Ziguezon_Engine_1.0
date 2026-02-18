const std = @import( "std" );
const def = @import( "defs" );


pub const resTypeCount = @typeInfo( ResType ).@"enum".fields.len;

pub const ResType = enum( u8 )
{
  pub inline fn toIdx( self : ResType ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) ResType { return @enumFromInt( @as( u8, @intCast( i ))); }

//CASH,
  WORK, // Each pop generate 1 work per cycle

  FOOD,
  POWER,
  WATER,

  ORE,
  INGOT,
  PART,

  pub inline fn getMass( self : ResType ) f32
  {
    return comptime switch( self )
    {
      .WORK  => 0.0,

      .FOOD  => 1.0,
      .POWER => 0.0,
      .WATER => 2.0,

      .ORE   => 3.0,
      .INGOT => 3.0,
      .PART  => 3.0,
    };
  }

  pub inline fn canBeAccumulated( self : ResType ) bool // If this resource can be stored for more than one cycle
  {
    return comptime switch( self )
    {
      .WORK  => false,
    //.FOOD  => false,
    //.POWER => false,

      else   => true,
    };
  }

};

//pub const Cash = f64;

pub const ResInstance = struct
{
  resType    : ResType,
  resCount   : u64  = 0,

//baseCost   : Cash = 1.0, // For market simulation
};