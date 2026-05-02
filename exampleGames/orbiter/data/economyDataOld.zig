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
    return comptime switch( self )
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

pub const ResStockData = def.GenDataLine( f64, ResType );
pub const ResFlowData  = def.GenDataCube( f64, EconAgentGroupEnum, AgentResDeltaEnum, ResType );

// NOTE : de-agregated version of ResFlowData[ POP ][ ResDelta ][ res ]
pub const PopResFlowData    = def.GenDataCube( f64, PopType, AgentResDeltaEnum, ResType );
pub const PopFulfilmentData = def.GenDataLine( f64, PopType );

// NOTE : de-agregated version of ResFlowData[ POP ][ ResDelta ][ res ]
//pub const InfMaintData    = def.GenDataLine( f64, IndType, ResType ); // TODO : Activate once INF is a real agent


// NOTE : de-agregated version of ResFlowData[ IND ][ ResDelta ][ res ]
pub const IndResFlowData  = def.GenDataCube( f64, IndType, AgentResDeltaEnum, ResType );
pub const IndActivityData = def.GenDataLine( f64, IndType );
//pub const IndMaintData    = def.GenDataLine( f64, IndType, ResType );



pub const EconAgentGroupEnum = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  POP, // Population       ( all population prod/cons )
//INF, // Infrastructure   ( all infrastructure cons  )
  IND, // Industry         ( all industrial prod/cons )

  MNT, // Maintenance      ( maintenance costs        )
  BLD, // Building         ( construction, selloffs   )
  COM, // Commerce / trade ( imports & exports        )

  GEN, // Sum of previous  ( avoid including NAT data )
  NAT, // Decay / Growth   ( decay, growth, disasters )
  // NOTE : NAT HAS NO MONETARY IMPACT ( NO SUP/DEM, PRICE, NOR SAVINGS EFFECT )
};

pub const AgentResDeltaEnum = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  MAX_PROD, // Theoretical maximum production  ( before scarcity )
  MAX_CONS, // Theoretical maximum consumption ( before scarcity )

  AVG_ACS,  // Demand satisfaction rate ( aka 1.0 - scarcity )

//ACT_

  FIN_PROD, // Final, realized production  ( after activity & scarcity applied )
  FIN_CONS, // Final, realized consumption ( after activity & scarcity applied )

  BALANCE,  // TODO : USE ME
};


// ================================ AGENT METRICS SUMARY MATRIX ================================
// NOTE : used in Economy

pub const AgentStateData = def.GenDataGrid( f64, EconAgentGroupEnum, AgentStateEnum );

// NOTE : Data represent all "agents" of a given AgentGroup
//        GEN  represent all groups combined
pub const AgentStateEnum = enum( u8 )
{
  AVG_ACS, // Average resource access rate

  AVG_ACT, // Average "action" rate

  // RATE BREAKDOWN :
  //
  // POP : FULFILMENT
  // INF : USAGE
  // IND : ACTIVITY
  //
  // MNT : ?
  // BLD : ?
  // COM : ?
  //
  // GEN : ?
  // NAT : ?
};


// ================================ AREA METRIC ARRAY ================================
// NOTE : used in Economy

pub const EconAreaData = def.GenDataLine( f64, EconAreaEnum );

pub const EconAreaEnum = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;
//pub const maxPossibleArea : f64 = ...;

  BODY,  // Total body's surface area         : if on GROUND
  INHAB, // Proportion of inhabitable surface : 0.0 to 1.0
  LAND,  // BODY * INHAB                      : Total useable land area
  CAP,   // LAND + HAB                        : Total buildable
  AVAIL, // MAX - USED                        : Total unused
  USED,  // sum of all area spent             : INF + IND
};
