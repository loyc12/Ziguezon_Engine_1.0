const std = @import( "std"  );
const def = @import( "defs" );

const gbl = @import( "../gameGlobals.zig" );
const gdf = @import( "../gameDefs.zig"    );

const ResType  = @import( "resourceData.zig"       ).ResType;
const InfType  = @import( "infrastructureData.zig" ).InfType;


pub const PopType = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  pub inline fn toIdx( self : @This() ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) @This()  { return @enumFromInt( i ); }

  HUMAN,

  // TODO : add other pop types here eventually

  pub inline fn getInfStore( self : PopType ) InfType // TODO : move to data array ?
  {
    _ = self;
    return .HOUSING; // TODO : update once multiple pop types exist

  //return switch( self )
  //{
  //  .HUMAN => .HOUSING,
  //  else   => .HOUSING,
  //};
  }


  pub fn getMetric_f32( self : PopType, metric : PopMetricEnum ) f32
  {
    return @floatCast( popMetricData.get( self, metric ));
  }
  pub fn getMetric_f64( self : PopType, metric : PopMetricEnum ) f64
  {
    return popMetricData.get( self, metric );
  }
  pub fn getMetric_u32( self : PopType, metric : PopMetricEnum ) u32
  {
    return @intFromFloat( popMetricData.get( self, metric ));
  }
  pub fn getMetric_u64( self : PopType, metric : PopMetricEnum ) u64
  {
    return @intFromFloat( popMetricData.get( self, metric ));
  }

  pub fn getResCons_f32( self : PopType, resType : ResType ) f32
  {
    return @floatCast( popResDeltaTable.get( self, .CONS, resType ));
  }
  pub fn getResCons_f64( self : PopType, resType : ResType ) f64
  {
    return popResDeltaTable.get( self, .CONS, resType );
  }
  pub fn getResCons_u32( self : PopType, resType : ResType ) u32
  {
    return @intFromFloat( popResDeltaTable.get( self, .CONS, resType ));
  }
  pub fn getResCons_u64( self : PopType, resType : ResType ) u64
  {
    return @intFromFloat( popResDeltaTable.get( self, .CONS, resType ));
  }

  pub fn getResProd_f32( self : PopType, resType : ResType ) f32
  {
    return @floatCast( popResDeltaTable.get( self, .PROD, resType ));
  }
  pub fn getResProd_f64( self : PopType, resType : ResType ) f64
  {
    return popResDeltaTable.get( self, .PROD, resType );
  }
  pub fn getResProd_u32( self : PopType, resType : ResType ) u32
  {
    return @intFromFloat( popResDeltaTable.get( self, .PROD, resType ));
  }
  pub fn getResProd_u64( self : PopType, resType : ResType ) u64
  {
    return @intFromFloat( popResDeltaTable.get( self, .PROD, resType ));
  }
};


// ================================ POPULATION METRICS GRID ================================

pub var popMetricData : def.GenDataGrid( f64, PopType, PopMetricEnum ) = .{};

pub const PopMetricEnum = enum( u8 )
{
  MASS,
  HSNG_COST, // Housing cost
  POLLUTION,
};


// ================================ POPULATION CONS / PROD GRID ================================

// Resource consumption / production per population ( u64 )
pub var popResDeltaTable : def.GenDataCube( f64, PopType, ResActionEnum, ResType ) = .{};

pub const ResActionEnum = enum( u8 )
{
  CONS,
  PROD,
};


pub fn loadPopulationData() void
{
  popMetricData.fillWith(    0.0 );
  popResDeltaTable.fillWith( 0.0 );


  // ================================ METRICS ================================

  popMetricData.set( .HUMAN, .MASS,      0.0001 );
  popMetricData.set( .HUMAN, .HSNG_COST, 1.0000 ); // Housing "space" neede for each pop
  popMetricData.set( .HUMAN, .POLLUTION, 0.0500 ); // ~2.6 tCO2e/yr first-world all-electric


  // ================================ RESOURCES ================================
  // NOTE : Per week. Units in gameDefs.zig

  popResDeltaTable.set( .HUMAN, .PROD, .WORK,  0.200 ); // 0.45 prod - 0.25 cons

//popResDeltaTable.set( .HUMAN, .CONS, .FUEL,  0.000 ); // All transport is electric
  popResDeltaTable.set( .HUMAN, .CONS, .FOOD,  0.015 );
  popResDeltaTable.set( .HUMAN, .CONS, .WATER, 0.800 ); // 0.7 base + 0.1 for electric transport
  popResDeltaTable.set( .HUMAN, .CONS, .POWER, 0.600 );
  popResDeltaTable.set( .HUMAN, .CONS, .PART,  0.003 );

  // NOTE : Temp replacement for all tertiary industries, to serve as WORK sink
  // TODO : Remove WORK consumption once ammenities and co. are a thing
//popResDeltaTable.set( .HUMAN, .CONS, .WORK,  0.300 );  // Each person "consumes" 0.3 ww of services
}


// ================================ POPULATION STATE GRID ================================
// NOTE : used in Economy to store local quantities and metrics

pub const PopStateData = def.GenDataGrid( f64, PopStateEnum, PopType );

pub const PopStateEnum = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  COUNT,    // Current population count
  LIMIT,    // Current housing capacity
  DELTA,    // Net total change last tick

  DEATH,    // Amount lost from resource shortages last tick
  BIRTH,    // Amount gained from birthrates last tick

  EXPENSE,  // Amount of money spent to fulfill their needs
  REVENUE,  // Amount of money gained by via WORK production
  PROFIT,   // Revenue - Expense
  MARGIN,   // Profits / Expense
  SAVINGS,  // Stored profits from previous ticks ( decays via inflation )

  FLM_LVL,  // How fulfilled their needs ended up being last tick
};

