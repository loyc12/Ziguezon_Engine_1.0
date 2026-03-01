const std = @import( "std" );
const def = @import( "defs" );


pub const resTypeCount = @typeInfo( ResType ).@"enum".fields.len;

pub const ResType = enum( u8 )
{
  pub inline fn toIdx( self : ResType ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) ResType  { return @enumFromInt( @as( u8, @intCast( i ))); }

//CASH,
  WORK, // Each pop generate 1 work per cycle

  FOOD,
  WATER,
  POWER,

  ORE,
  INGOT,
  PART,

  pub inline fn getMass( self : ResType ) f32
  {
    return switch( self )
    {
      .WORK  => 0.0,

      .FOOD  => 1.0,
      .WATER => 1.0,
      .POWER => 0.0,

      .ORE   => 3.0,
      .INGOT => 3.0,
      .PART  => 3.0,
    };
  }

  pub inline fn getDecayRate( self : ResType ) f32
  {
    return switch( self )
    {
      .WORK  => 1.00, // NOTE : DO NOT CONFUSE WITH getPerPopDelta() VALUE
                      //        Imagine wasting time on that bug... couldn't be me frfrf
      .FOOD  => 0.03,
      .WATER => 0.02,
      .POWER => 0.01,

      .ORE   => 0.01,
      .INGOT => 0.02,
      .PART  => 0.03,
    };
  }

  pub inline fn getPerPopDelta( self : ResType ) f32
  {
    // NOTE : Changes might require modifications to EconSolver.applyWorkWeek(), .calcWorkAccess(), or .applyPopDelta()

    return switch( self )
    {
      .WORK  =>  1.00, // Needs to stay positive ( EconSolver.calcWorkAccess() )

      //
      .FOOD  => -0.30,
      .WATER => -0.20,
      .POWER => -0.10,

      .ORE   => -0.00,
      .INGOT => -0.00,
      .PART  => -0.00,
    };
  }
};

pub const ResInstance = struct
{
  resType    : ResType,
  resCount   : u64  = 0,

//baseCost   : Cash = 1.0, // For market simulation
};