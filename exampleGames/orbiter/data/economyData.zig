const std = @import( "std" );
const def = @import( "defs" );

const gbl = @import( "../gameGlobals.zig" );

const ResType = gbl.ResType;
const InfType = gbl.InfType;
const IndType = gbl.IndType;


// ================================ ECONOMY LOCATION ENUM ================================
pub const EconLoc = enum( u8 )
{
  pub const count = @typeInfo( EconLoc ).@"enum".fields.len;

  pub inline fn toIdx( self : EconLoc ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) EconLoc {  return @enumFromInt( @as( u8, @intCast( i ))); }

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
// NOTE : used in EconSolver

pub const ResFlowData = def.NewDataMatrix( f64, FlowAgentEnum, FlowPhaseEnum, ResType );

// NOTE : de-agregated version of ResFlowData[ IND ][ phase ][ res ] ( individualized to each industry independantly )
pub const IndFlowData = def.NewDataMatrix( f64, IndType, FlowPhaseEnum, ResType );

// NOTE : individual industry's max activity level
pub const IndActivityData = def.NewDataArray( f64, IndType );


pub const FlowAgentEnum = enum
{
  pub const count = @typeInfo( FlowAgentEnum ).@"enum".fields.len;

  NAT, // Natural processes     (decay, growth)
  POP, // Population            (work prod, food/water/power cons)
  IND, // Industry aggregate    (all industrial prod/cons)
//COM, // Commerce / trade      (imports/exports — stub for now)
  GEN, // Sum of non-NAT values
};

pub const FlowPhaseEnum = enum
{
  pub const count = @typeInfo( FlowPhaseEnum ).@"enum".fields.len;

  MAX_PROD,  // Theoretical maximum production    ( before scarcity )
  MAX_CONS,  // Theoretical maximum consumption   ( before scarcity )

//PRED_PROD, // Predicted maximum production      ( after control levers applied ) ???
//PRED_CONS, // Predicted maximum consumption     ( after control levers applied ) ???

  REAL_PROD, // Realized production               ( after activity / access applied )
  REAL_CONS, // Realized consumption              ( after activity / access applied )
};


// ================================ RESOURCE ACCESS GRID ================================
// NOTE : used in EconSolver

pub const ResAccessData = def.NewDataGrid( f64, AccessAgentEnum, ResType );

pub const AccessAgentEnum = enum
{
  pub const count = @typeInfo( AccessAgentEnum ).@"enum".fields.len;

  POP, // Population access ratio for this resource
  IND, // Industry aggregate access ratio
  GEN, // General / combined access ratio
};


// ================================ AREA METRIC ARRAY ================================
// NOTE : used in Economy

pub const AreaMetricData = def.NewDataArray( f64, AreaMetricEnum );

pub const AreaMetricEnum = enum
{
  pub const count = @typeInfo( AreaMetricEnum ).@"enum".fields.len;

  BODY,  // Total body's surface area         : if on GROUND
  INHAB, // Proportion of inhabitable surface : 0 to 1
  LAND,  // BODY * INHAB                      : Total useable land area
  CAP,   // LAND + HAB                        : Total buildable
  AVAIL, // MAX - USED                        : Total unused
  USED,  // sum of all area spent             : INF + IND
};


// ================================ POPULATION METRIC ARRAY ================================
// NOTE : used in Economy

pub const PopMetricData = def.NewDataArray( f64, PopMetricEnum );

pub const PopMetricEnum = enum
{
  pub const count = @typeInfo( PopMetricEnum ).@"enum".fields.len;

  COUNT,  // Total amount of population last tick
  DELTA,  // Change sin population last tick
  ACCESS, // Population's access to demanded goods last tick
};