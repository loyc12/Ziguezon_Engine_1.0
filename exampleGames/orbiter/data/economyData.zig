const std = @import( "std" );
const def = @import( "defs" );

const gbl = @import( "../gameGlobals.zig" );

const ResType = gbl.ResType;
const IndType = gbl.IndType;


// ================================ RESOURCE FLOW MATRIX ================================

pub const FlowAgent = enum
{
  NAT, // Natural processes     (decay, growth)
  POP, // Population            (work prod, food/water/power cons)
  IND, // Industry aggregate    (all industrial prod/cons)
  COM, // Commerce / trade      (imports/exports — stub for now)

  pub const count = @typeInfo( FlowAgent ).@"enum".fields.len;
};

pub const FlowPhase = enum
{
  MAX_PROD,  // Theoretical maximum production    ( before scarcity )
  MAX_CONS,  // Theoretical maximum consumption   ( before scarcity )

//PRED_PROD, // Predicted maximum production      ( after control levers applied ) ???
//PRED_CONS, // Predicted maximum consumption     ( after control levers applied ) ???

  REAL_PROD, // Realized production               ( after activity / access applied )
  REAL_CONS, // Realized consumption              ( after activity / access applied )

  pub const count = @typeInfo( FlowPhase ).@"enum".fields.len;
};

pub var resFlowData: def.newDataMatrix( u64, FlowAgent, FlowPhase, ResType ) = .{};


// ================================ INDUSTRY FLOW MATRIX ================================
// NOTE : de-agregated version of resFlowData[ IND ][ phase ][ res ] ( individualized to each industry independantly )

pub var indFlowData: def.newDataMatrix( u64, IndType, FlowPhase, ResType ) = .{};


// ================================ RESOURCE STATE GRID ================================

pub const ResStateMetric = enum
{
    BANK,       // Current stockpile           ( u64, but stored as f64 for uniformity )
    CAP,        // Storage capacity            ( u64, but stored as f64 for uniformity )

    DELTA,      // Net total change this tick

    DECAY,      // Amount lost to stock decay this tick
    GROWTH,     // Amount gained from nature  this tick

    MAX_DEM,    // Total maximal consumption this tick
    MAX_SUP,    // Total maximal produciton  this tick

    FIN_DEM,    // Total applied consumption this tick
    FIN_SUP,    // Total applied produciton  this tick

    SAT_LVL,    // How much of demand could be satisfied by supply this tick

    pub const count = @typeInfo( ResStateMetric ).@"enum".fields.len;
};

pub var resStateData: def.newDataGrid( f64, ResStateMetric, ResType ) = .{};


// ================================ RESOURCE ACCESS GRID ================================

pub const AccessAgent = enum
{
  POP, // Population access ratio for this resource
  IND, // Industry aggregate access ratio
  GEN, // General / combined access ratio

  pub const count = @typeInfo( AccessAgent ).@"enum".fields.len;
};

pub var resAccessData: def.newDataGrid( f32, AccessAgent, ResType ) = .{};


// ================================ INDUSTRY STATE ARRAY ================================

pub var indActivityData: def.newDataArray( f32, IndType ) = .{};


// ================================ AREA METRIC ARRAY ================================

pub const AreaMetric = enum
{
  BODY,  // SURFACE AREA ( if on GROUND )
  INHAB, // Inhabitable proportion of surface
  LAND,  // LAND AREAD
  CAP,   // LAND + HAB
  AVAIL, // MAX - USED
  USED,  // IND + INF costs

  pub const count = @typeInfo( AreaMetric ).@"enum".fields.len;
};

pub var areaMetricData: def.newDataArray( f64, AreaMetric ) = .{};
