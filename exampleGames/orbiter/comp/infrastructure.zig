const std = @import( "std" );
const def = @import( "defs" );

const res = @import( "resource.zig" );

const EconLoc  = @import( "economy.zig" ).EconLoc;
const PowerSrc = @import( "powerSrc.zig" ).PowerSrc;


pub const infTypeCount = @typeInfo( InfType ).@"enum".fields.len;

pub const InfType = enum( u8 )
{
  pub inline fn toIdx( self : InfType ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) InfType  { return @enumFromInt( @as( u8, @intCast( i ))); }

  HOUSING,      // Increases population cap
  HABITAT,      // Increase area of pressurized locations
  STORAGE,      // Grants cargo storage capacity
  BATTERY,      // Grants energy storage capacity

//AMENITIES,    // Services population needs
//EDUCATION,    // Generate research ( efficiency multiplier )
//COMMERCE,     // Increase tax revenues ?

//ROAD_NETWORK, // Grants cargo  transport capacity locally
//POWER_GRID,   // Grants energy transport capacity locally

//ELEVATOR,     // Grants cargo  transport capacity to and from orbit
//POWER_BEAM,   // Grants energy transport capacity to and from orbit

//LAUNCHPAD,    // Grants docking capacity for vessels

//DATA_CENTER,  // ???

  pub inline fn getMass( self : InfType ) f32
  {
    return switch( self )
    {
      .HOUSING => 1.0,
      .HABITAT => 3.0,

      .STORAGE => 5.0,
      .BATTERY => 2.0,
    };
  }

  pub inline fn getAreaCost( self : InfType ) f32
  {
    return switch( self )
    {
      .HOUSING =>  1.0,
      .HABITAT => -8.0,

      .STORAGE =>  4.0,
      .BATTERY =>  2.0,
    };
  }

  pub inline fn getPartCost( self : InfType ) u64 // Assembly cost in parts
  {
    return switch( self )
    {
      .HOUSING => 1,
      .HABITAT => 3,

      .STORAGE => 2,
      .BATTERY => 4,
    };
  }

  pub inline fn getCapacity( self : InfType ) u64
  {
    return switch( self )
    {
      .HOUSING => 16, // Pop
      .HABITAT => 16, // Square units

      .STORAGE => 16, // Resources
      .BATTERY => 16, // POWER resource
    };
  }

  pub inline fn canBeBuiltAt( self : InfType, loc : EconLoc, hasAtmosphere : bool ) bool
  {
    if( loc == .GROUND )
    {
      return switch( self )
      {
        .HOUSING => true,
        .HABITAT => !hasAtmosphere,

        .STORAGE => true,
        .BATTERY => true,

        else     => false,
      };
    }
    else // .ORBIT or .L1-5
    {
      return switch( self )
      {
        .HOUSING => true,
        .HABITAT => true,

        .STORAGE => true,
        .BATTERY => true,

        else     => false,
      };
    }
  }

  // TODO : Add maintenance costs ?
};



pub const InfInstance = struct
{
  infType  : InfType,
//powerSrc : PowerSrc,
//baseCost : Cash = 1.0, // For market simulation

  infCount : u64 = 0,
};