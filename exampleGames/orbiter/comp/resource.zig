const std = @import( "std" );
const def = @import( "defs" );


pub const resTypeCount = @typeInfo( ResType ).@"enum".fields.len;

pub const ResType = enum( u8 )
{
  pub inline fn toIdx( self : ResType ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : u8 ) ResType { return @enumFromInt( @as( u8, @intCast( i ))); }

//CASH,

  FOOD,
  POWER,

  ORE,
  INGOT,
  PART,


//pub fn canBeStored( self : ResType ) bool
//{
//  return switch( self )
//  {
//  //.POP   => false,
//  //.CASH  => true,

//    .FOOD  => true,
//    .POWER => true,

//    .ORE   => true,
//    .INGOT => true,
//    .PART  => true,
//  };
//}
};

//pub const Cash = f32;

pub const ResInstance = struct
{
  resType    : ResType,
  resCount   : u32  = 0,
  massPerRes : u32  = 1,
//baseCost   : Cash = 1.0, // For market simulation
};