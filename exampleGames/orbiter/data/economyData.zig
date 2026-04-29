const std = @import( "std"  );
const def = @import( "defs" );

const gbl = @import( "../gameGlobals.zig" );
const gdf = @import( "../gameDefs.zig"    );


const ResType = gdf.ResType;
const PopType = gdf.PopType;
const InfType = gdf.InfType;
const IndType = gdf.IndType;


// ================================ ECONOMY LOCATION ENUM ================================
pub const EconLoc = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  pub inline fn toIdx( self : @This() ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) @This() {  return @enumFromInt( i    ); }

  GROUND, // Does not garantee breathable atmosphere
  ORBIT,
  L1,     // Lagrange Points
  L2,
  L3,
  L4,
  L5,

  pub inline fn toLagrangeIdx( self : EconLoc ) u4
  {
    return switch( self )
    {
      .L1  => 1,
      .L2  => 2,
      .L3  => 3,
      .L4  => 4,
      .L5  => 5,
      else => 0,
    };
  }
};


// ================================ RESOURCE FLOW MATRIX ================================
// NOTE : used in EconSolver ( aka temporary data storage )

pub const ResStockData      = def.GenDataLine( f64, ResType );
pub const ResFlowData       = def.GenDataCube( f64, EconAgentEnum, EconFlowPhaseEnum, ResType );

// NOTE : de-agregated version of ResFlowData[ POP ][ phase ][ res ]
pub const PopResFlowData    = def.GenDataCube( f64, PopType, EconFlowPhaseEnum, ResType );
pub const PopFulfilmentData = def.GenDataLine( f64, PopType );

// NOTE : de-agregated version of ResFlowData[ IND ][ phase ][ res ]
pub const IndResFlowData    = def.GenDataCube( f64, IndType, EconFlowPhaseEnum, ResType );
pub const IndActivityData   = def.GenDataLine( f64, IndType );



pub const EconAgentEnum = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  POP, // Population       ( all population prod/cons  )
  MNT, // Maintenance      ( building maintenance cons )
  IND, // Industry         ( all industrial prod/cons  )
  BLD, // Building         ( construction, selloffs    )
  COM, // Commerce / trade ( imports, exports          ) : stub for now

  GEN, // Sum of previous  ( avoid including NAT uses  )

  NAT, // Decay / Growth   ( decay, growth, disasters  )
  // NOTE : NAT IS NOT AN ECONOMIC ACTION ( NO CASH TRANSACTION & NO IMPACT ON PRICES )
};

pub const EconFlowPhaseEnum = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  MAX_PROD,  // Theoretical maximum production  ( before scarcity )
  MAX_CONS,  // Theoretical maximum consumption ( before scarcity )

  AVG_ACS,   // Demand satisfaction rate ( aka 1.0 - scarcity )

  REAL_PROD, // Realized production  ( after activity & scarcity applied )
  REAL_CONS, // Realized consumption ( after activity & scarcity applied )
};


// ================================ AREA METRIC ARRAY ================================
// NOTE : used in Economy

pub const EconAreaData = def.GenDataLine( f64, EconAreaEnum );

pub const EconAreaEnum = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  BODY,  // Total body's surface area         : if on GROUND
  INHAB, // Proportion of inhabitable surface : 0.0 to 1.0
  LAND,  // BODY * INHAB                      : Total useable land area
  CAP,   // LAND + HAB                        : Total buildable
  AVAIL, // MAX - USED                        : Total unused
  USED,  // sum of all area spent             : INF + IND
};
