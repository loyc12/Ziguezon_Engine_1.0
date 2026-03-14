const std = @import( "std" );
const def = @import( "defs" );

const inf = @import( "infrastructure.zig" );


pub const resTypeCount = @typeInfo( ResType ).@"enum".fields.len;

pub const ResType = enum( u8 )
{
  pub inline fn toIdx( self : ResType ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) ResType  { return @enumFromInt( @as( u8, @intCast( i ))); }

  WORK, // Each pop generate N work per cycle
//FLOP, // Computation

  FOOD,
  WATER,
  POWER,
//CASH,

  ORE,
  INGOT,
  PART,


//pub inline fn getMass( self : ResType ) f32
//{
//  return switch( self )
//  {
//    .WORK  => 0.0,
//
//    .FOOD  => 1.0,
//    .WATER => 2.0,
//    .POWER => 0.0,
//
//    .ORE   => 5.0,
//    .INGOT => 4.0,
//    .PART  => 3.0,
//  };
//}
//
//pub inline fn getDecayRate( self : ResType ) f32
//{
//  return switch( self )
//  {
//    .WORK  => 1.00, // NOTE : DO NOT CONFUSE WITH getPerPopDelta() VALUE
//                    //        Imagine wasting time on that bug... couldn't be me frfrf
//    .FOOD  => 0.05,
//    .WATER => 0.02,
//    .POWER => 0.01,
//
//    .ORE   => 0.01,
//    .INGOT => 0.02,
//    .PART  => 0.05,
//  };
//}
//
//pub inline fn getGrowthRate( self : ResType ) f32
//{
//  // NOTE : Changes might require modifications to EconSolver.applyWorkWeek(), .calcWorkAccess(), or .applyPopDelta()
//
//  return switch( self )
//  {
//    .FOOD  => 150.0,
//    .WATER => 200.0,
//    .POWER => 100.0,
//
//    else   => 0.0,
//  };
//}
//
//pub inline fn getPerPopDelta( self : ResType ) f32
//{
//  // NOTE : Changes might require modifications to EconSolver.applyWorkWeek(), .calcWorkAccess(), or .applyPopDelta()
//
//  return switch( self )
//  {
//    .WORK  =>  1.00, // Needs to stay positive ( EconSolver.calcWorkAccess() )
//
//    .FOOD  => -0.40,
//    .WATER => -0.20,
//    .POWER => -0.10,
//
//    else   => -0.0,
//  };
//}

  pub inline fn getInfStore( self : ResType ) inf.InfType
  {
    _ = self;

    return inf.InfType.STORAGE; // TODO : update once multiple storage types exist
  }

  pub fn getMetric( self : ResType, metric : ResMetricEnum ) f32
  {
    return resMetricData.get( self, metric );
  }
};


// Scalar metrics ( f32 )
pub var resMetricData : def.newDataGrid( f32, ResType, ResMetricEnum ) = .{};

pub const ResMetricEnum = enum
{
  MASS,
  DECAY_RATE,
  GROWTH_RATE,
  POP_CONS,
  POP_PROD,
};
