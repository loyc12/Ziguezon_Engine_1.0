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


// ================================ ECONOMIC AGENT ENUM ================================
// Agent classification grouping - what kind of agent is this

pub const AgentGroupEnum = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  pub inline fn toIdx( self : @This() ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) @This()  { return @enumFromInt( i ); }

  POP, // Population     ( PopType )
  INF, // Infrastructure ( InfType )
  IND, // Industrial     ( IndType )
//COM, // Commercial     ( import, export, )
//GOV, // Government     ( aka the player )
//NAT, // Non-agent      ( disaster, decay, etc )
};


// ================================ FLOW ACTION ENUM ================================
// Action verbs - what kind of flow lane this is

pub const AgentFlowEnum = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  OPR_PROD, OPR_CONS, // Maximum operational  res flow ( before clamping )
  OPR_ACS,            // Resource demand satisfaction rate

  MNT_CONS,           // Maximum maintenance  res cons ( before clamping )
  MNT_ACS,            // Resource demand satisfaction rate

  BLD_PROD, BLD_CONS, // Maximum construciton res flow ( before clamping )
  BLD_ACS,            // Resource demand satisfaction rate

  TOT_PROD, TOT_CONS, // Applied, final res flow ( clamped by ACCESS & ACTION rates )
};




// ================================ FLOW MATRICES ================================

pub const ResStockData = def.GenDataLine( f64, ResType );

// Per-action, per-resource
pub const GenResFlowData = def.GenDataGrid( f64, AgentFlowEnum, ResType );

// Per-agent, per-action, per-resource
pub const GrpResFlowData = def.GenDataCube( f64, AgentGroupEnum, AgentFlowEnum, ResType );

// Per-agent-subtype, per-resource ( disaggregation )
pub const PopResFlowData = def.GenDataCube( f64, PopType, AgentFlowEnum, ResType );
pub const InfResFlowData = def.GenDataCube( f64, InfType, AgentFlowEnum, ResType );
pub const IndResFlowData = def.GenDataCube( f64, IndType, AgentFlowEnum, ResType );


// ================================ AGENT AVERAGE METRIC ENUM ================================
// NOTE : Used in economy to store only some of the solver's computed values

// Long term storage for per-agent calculated info
pub const AgentStateData = def.GenDataGrid( f64, AgentGroupEnum, AgentAveragesEnum );

pub const AgentAveragesEnum = enum( u8 )
{
  ACCESS, // Stores AVG_ACS from solver

  ACTION, // Stores AVG_ACT from solver

  // RATE BREAKDOWN :
  //
  // POP : FULFILMENT
  // INF : USAGE
  // IND : ACTIVITY
  // ...
};


// ================================ AREA METRIC ARRAY ================================
// NOTE : Used in economy to store area metrics

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
