const std = @import( "std"  );
const def = @import( "defs" );

const gbl = @import( "../gameGlobals.zig" );
const gdf = @import( "../gameDefs.zig"    );


const ResType = gdf.ResType;
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
// NOTE : used in EconSolver

pub const ResStockData = def.GenDataLine( f64, ResType );
pub const ResFlowData  = def.GenDataCube( f64, FlowAgentEnum, FlowPhaseEnum, ResType );

// NOTE : de-agregated version of ResFlowData[ IND ][ phase ][ res ] ( individualized to each industry independantly )
pub const IndFlowData  = def.GenDataCube( f64, IndType, FlowPhaseEnum, ResType );

// NOTE : individual industry's max activity level
pub const IndActivityData = def.GenDataLine( f64, IndType );

pub const IndResAccessData = def.GenDataGrid( f64, IndType, ResType );


pub const FlowAgentEnum = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  POP, // Population       ( work prod, food/water/power cons )
  MNT, // Maintenance      ( building maintenance cons        ) : stub for now
  IND, // Industry         ( all industrial prod/cons         )
  BLD, // Building         ( construction, selloffs           )
//COM, // Commerce / trade ( imports, exports                 ) : stub for now

  GEN, // Sum of previous  ( to avoid counting decay as usage )
  NAT, // Decay / Growth   ( decay, growth, disasters         ) NOTE : NOT COUNTED AS ECONOMIC ACTION
};

pub const FlowPhaseEnum = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  MAX_PROD,  // Theoretical maximum production    ( before scarcity )
  MAX_CONS,  // Theoretical maximum consumption   ( before scarcity )

  REAL_PROD, // Realized production               ( after activity / access applied )
  REAL_CONS, // Realized consumption              ( after activity / access applied )

  ACCESS,    // Resource demand satisfaction rate
};


// ================================ AREA METRIC ARRAY ================================
// NOTE : used in Economy

pub const AreaMetricData = def.GenDataLine( f64, AreaMetricEnum );

pub const AreaMetricEnum = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  BODY,  // Total body's surface area         : if on GROUND
  INHAB, // Proportion of inhabitable surface : 0.0 to 1.0
  LAND,  // BODY * INHAB                      : Total useable land area
  CAP,   // LAND + HAB                        : Total buildable
  AVAIL, // MAX - USED                        : Total unused
  USED,  // sum of all area spent             : INF + IND
};


// ================================ POPULATION METRIC ARRAY ================================
// NOTE : used in Economy

pub const PopMetricData = def.GenDataLine( f64, PopMetricEnum );

pub const PopMetricEnum = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  COUNT,    // Total amount of population last tick
  DELTA,    // Changes in population last tick

  BIRTH,
  DEATH,

  ACTIVITY, // Population's access to demanded goods last tick
};