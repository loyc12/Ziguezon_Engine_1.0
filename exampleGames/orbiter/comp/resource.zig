const std = @import( "std" );
const def = @import( "defs" );


pub const resTypeCount = @typeInfo( ResourceType ).@"enum".fields.len;

pub const ResourceType = enum( u8 )
{
  CASH,
  POP,
  FOOD,
  ENERGY,
  ORE,
  INGOT,
  PART,
};

//pub const Cash = f32;

pub const ResourceInstance = struct
{
  resType    : ResourceType,
  resCount   : u32  = 0,
  massPerRes : u32  = 1,
//baseCost   : Cash = 1.0, // For market simulation
};