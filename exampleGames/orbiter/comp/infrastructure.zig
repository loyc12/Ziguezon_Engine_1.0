const std = @import( "std" );
const def = @import( "defs" );

const res = @import( "resource.zig" );


pub const infTypeCount = @typeInfo( InfType ).@"enum".fields.len;

pub const InfType = enum( u8 )
{
  HOUSING,     // Houses 10 people comfortably, 20 max
//AMENITIES,   // Services population needs
//EDUCATION,   // Generate research ( efficiency multiplier )

  AGRONOMIC,   // Generate food ( solar powered )
//HYDROPONIC,  // Generate food ( grid powered )
  SOLAR_PLANT, // Generate energy ( solar powered )
//POWER_PLANT, // Generate energy ( fission / fusion )

//TRANSPORT,   // Grants cargo transport capacity locally
//POWER_GRID,  // Grants energy transport capacity locally
//ELEVATOR,    // Transports things to and from orbit
//LAUNCHPAD,   // Grants docking capacity to transport vessels

//PROBE_MINE,  // Extracts raw materials ( autonomous but restricted to asteroids )
  GROUD_MINE,  // Extracts raw materials
  REFINERY,    // Refines raw materials
  FACTORY,     // Create parts from refined materials
  ASSEMBLY,    // Assembles parts into infrastructure & vehicles
};

pub const InfraInstance = struct
{
  infType    : InfType,
  infCount   : u32 = 0,
  massPerInf : u32 = 1,
  popPerInf  : u32 = 1,

  resProdPerInf : [ res.resTypeCount ]u32 = std.mem.zeroes([ res.resTypeCount ]u32 ),
  resConsPerInf : [ res.resTypeCount ]u32 = std.mem.zeroes([ res.resTypeCount ]u32 ),
};