const std = @import( "std" );
const def = @import( "defs" );

const gbl = @import( "../gameGlobals.zig" );

const ResType = gbl.ResType;
const InfType = gbl.IndType;
const IndType = gbl.IndType;


// ================================ RESOURCE FLOW MATRIX ================================
// NOTE : used in EconSolver

pub const FlowAgent = enum
{
  pub const count = @typeInfo( FlowAgent ).@"enum".fields.len;

  NAT, // Natural processes     (decay, growth)
  POP, // Population            (work prod, food/water/power cons)
  IND, // Industry aggregate    (all industrial prod/cons)
  COM, // Commerce / trade      (imports/exports — stub for now)
};

pub const FlowPhase = enum
{
  pub const count = @typeInfo( FlowPhase ).@"enum".fields.len;

  MAX_PROD,  // Theoretical maximum production    ( before scarcity )
  MAX_CONS,  // Theoretical maximum consumption   ( before scarcity )

//PRED_PROD, // Predicted maximum production      ( after control levers applied ) ???
//PRED_CONS, // Predicted maximum consumption     ( after control levers applied ) ???

  REAL_PROD, // Realized production               ( after activity / access applied )
  REAL_CONS, // Realized consumption              ( after activity / access applied )
};

// var resFlowData: def.newDataMatrix( u64, FlowAgent, FlowPhase, ResType ) = .{};


// NOTE : de-agregated version of resFlowData[ IND ][ phase ][ res ] ( individualized to each industry independantly )
// var indFlowData: def.newDataMatrix( u64, IndType, FlowPhase, ResType ) = .{};

// NOTE : equivalent of [ SAT_LVL ] for industries
// var indActivityData: def.newDataArray( f64, IndType ) = .{};



// ================================ RESOURCE ACCESS GRID ================================
// NOTE : used in EconSolver


pub const AccessAgent = enum
{
  pub const count = @typeInfo( AccessAgent ).@"enum".fields.len;

  POP, // Population access ratio for this resource
  IND, // Industry aggregate access ratio
  GEN, // General / combined access ratio
};

// var resAccessData: def.newDataGrid( f32, AccessAgent, ResType ) = .{};



// ================================ AREA METRIC ARRAY ================================
// NOTE : used in Economy

pub const AreaMetric = enum
{
  pub const count = @typeInfo( AreaMetric ).@"enum".fields.len;

  BODY,  // SURFACE AREA ( if on GROUND )
  INHAB, // Inhabitable proportion of surface
  LAND,  // LAND AREAD
  CAP,   // LAND + HAB
  AVAIL, // MAX - USED
  USED,  // IND + INF costs
};

// var areaMetricData: def.newDataArray( f64, AreaMetric ) = .{};
