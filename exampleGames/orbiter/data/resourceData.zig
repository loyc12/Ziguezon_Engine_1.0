const std = @import( "std" );
const def = @import( "defs" );

const InfType = @import( "infrastructureData.zig" ).InfType;


pub const ResType = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  pub inline fn toIdx( self : @This() ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) @This()  { return @enumFromInt( i ); }

  WORK,
  FUEL,
//FLOP, // Computation

  FOOD,
  WATER,
  POWER,

  ORE,
  INGOT,
  PART,  // Complex industrial / consumer eletronics and machinery
//STRUC, // Simple structural material ( steel, concrete, etc ) // TODO : IMPLEMENT ME


  pub inline fn getInfStore( self : ResType ) InfType // TODO : move to data array ?
  {
    return switch( self )
    {
      .WORK => .HOUSING,
      else  => .STORAGE, // TODO : update once multiple storage types exist
    };
  }

  pub fn getMetric_f32( self : ResType, metric : ResMetricEnum ) f32
  {
    return resMetricData.get( self, metric );
  }
  pub fn getMetric_f64( self : ResType, metric : ResMetricEnum ) f64
  {
    return @floatCast( resMetricData.get( self, metric ));
  }
  pub fn getMetric_u32( self : ResType, metric : ResMetricEnum ) u32
  {
    return @intFromFloat( resMetricData.get( self, metric ));
  }
  pub fn getMetric_u64( self : ResType, metric : ResMetricEnum ) u64
  {
    return @intFromFloat( resMetricData.get( self, metric ));
  }
};


// ================================ RESOURCE METRICS GRID ================================

pub var resMetricData : def.GenDataGrid( f64, ResType, ResMetricEnum ) = .{};

pub const ResMetricEnum = enum( u8 )
{
  MASS,

  DECAY_RATE,  // Natural decay  ( peremption )
  GROWTH_RATE, // Natural growth ( natural bounty)
  STORE_RATE,  // Units of space taken per res in their respective InfStore

  PRICE_BASE,  // Base cost per unit
  PRICE_ELAS,  // Price variation elasticity exponent
  PRICE_DAMP,  // Price updating lerp factor
};


pub fn loadResourceData() void
{
  resMetricData.fillWith( 0.0 );


  // ================================ MASS ================================

  resMetricData.set( .WORK,  .MASS, 0.0 );
  resMetricData.set( .FUEL,  .MASS, 2.0 );

  resMetricData.set( .FOOD,  .MASS, 2.0 );
  resMetricData.set( .WATER, .MASS, 2.0 );
  resMetricData.set( .POWER, .MASS, 0.0 );

  resMetricData.set( .ORE,   .MASS, 5.0 );
  resMetricData.set( .INGOT, .MASS, 4.0 );
  resMetricData.set( .PART,  .MASS, 3.0 );


  // ================================ DECAY RATE ================================

  resMetricData.set( .WORK,  .DECAY_RATE, 1.00 );
  resMetricData.set( .FUEL,  .DECAY_RATE, 0.03 );

  resMetricData.set( .FOOD,  .DECAY_RATE, 0.05 );
  resMetricData.set( .WATER, .DECAY_RATE, 0.03 );
  resMetricData.set( .POWER, .DECAY_RATE, 0.05 );

  resMetricData.set( .ORE,   .DECAY_RATE, 0.01 );
  resMetricData.set( .INGOT, .DECAY_RATE, 0.01 );
  resMetricData.set( .PART,  .DECAY_RATE, 0.01 );


  // ================================ GROWTH RATE ================================

  // TODO : deprecate ? ( kinda pointless with the current economy scale and more stable implementation )
  resMetricData.set( .FOOD,  .GROWTH_RATE, 150.0 );
  resMetricData.set( .WATER, .GROWTH_RATE, 200.0 );
  resMetricData.set( .POWER, .GROWTH_RATE, 100.0 );


  // ================================ STORE RATE ================================
  // Units of storage space consumed per unit of resource
  // Lower values = more of that resource fits per STORAGE unit
  // WATER and POWER have high flow but compact storage (tanks, grid buffers)

  resMetricData.set( .WORK,  .STORE_RATE, 1.00 ); // Has its own "storage" ( housing ) // NOTE : Should be more than enough in every situation
  resMetricData.set( .FUEL,  .STORE_RATE, 1.00 ); // Dense liquid, standard containers

  resMetricData.set( .FOOD,  .STORE_RATE, 1.00 ); // Standard bulk storage
  resMetricData.set( .WATER, .STORE_RATE, 0.05 ); // 1t water = 1m³, tanks hold 20× more per unit // NOTE : Temp fix until WATER gets its own storage
  resMetricData.set( .POWER, .STORE_RATE, 0.05 ); // Grid buffers, 1 MWh takes minimal space      // NOTE : Temp fix until POWER gets its own storage

  resMetricData.set( .ORE,   .STORE_RATE, 1.00 ); // Bulk piles, standard
  resMetricData.set( .INGOT, .STORE_RATE, 1.00 ); // Stacked,    standard
  resMetricData.set( .PART,  .STORE_RATE, 1.00 ); // Palletized, standard

  // ================================ PRICES ================================

  resMetricData.set( .WORK,  .PRICE_BASE, 0.0050 );
  resMetricData.set( .FUEL,  .PRICE_BASE, 0.1000 );

  resMetricData.set( .FOOD,  .PRICE_BASE, 0.0200 );
  resMetricData.set( .WATER, .PRICE_BASE, 0.0005 );
  resMetricData.set( .POWER, .PRICE_BASE, 0.0010 );

  resMetricData.set( .ORE,   .PRICE_BASE, 0.0100 );
  resMetricData.set( .INGOT, .PRICE_BASE, 0.0300 );
  resMetricData.set( .PART,  .PRICE_BASE, 0.0900 );


  resMetricData.set( .WORK,  .PRICE_ELAS, 0.50 ); // Stable - labor market shouldn't oscillate wildly
  resMetricData.set( .FUEL,  .PRICE_ELAS, 0.60 ); // Moderate - industrial commodity

  resMetricData.set( .FOOD,  .PRICE_ELAS, 0.80 ); // High - essential, price must spike during shortage
  resMetricData.set( .WATER, .PRICE_ELAS, 0.80 ); // High - essential
  resMetricData.set( .POWER, .PRICE_ELAS, 0.70 ); // High-moderate - essential but more substitutable

  resMetricData.set( .ORE,   .PRICE_ELAS, 0.50 ); // Low - bulk commodity, stable
  resMetricData.set( .INGOT, .PRICE_ELAS, 0.60 ); // Low-moderate - processed commodity
  resMetricData.set( .PART,  .PRICE_ELAS, 0.70 ); // Moderate - high-value, competed over by many consumers


  resMetricData.set( .WORK,  .PRICE_DAMP, 0.15 ); // Slow - labor market has inertia
  resMetricData.set( .FUEL,  .PRICE_DAMP, 0.20 ); // Moderate

  resMetricData.set( .FOOD,  .PRICE_DAMP, 0.25 ); // Fast - perishable, must react quickly
  resMetricData.set( .WATER, .PRICE_DAMP, 0.25 ); // Fast - essential
  resMetricData.set( .POWER, .PRICE_DAMP, 0.20 ); // Moderate - grid has some buffer

  resMetricData.set( .ORE,   .PRICE_DAMP, 0.10 ); // Slow - stockpiles buffer shocks
  resMetricData.set( .INGOT, .PRICE_DAMP, 0.15 ); // Slow
  resMetricData.set( .PART,  .PRICE_DAMP, 0.20 ); // Moderate - high demand from multiple sectors
}


// ================================ RESOURCE STATE GRID ================================
// NOTE : used in Economy to store local quantities and metrics

pub const ResStateData = def.GenDataGrid( f64, ResStateEnum, ResType );

pub const ResStateEnum = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  COUNT,    // Current stockpile
  LIMIT,    // Current storage capacity
  DELTA,    // Net total change last tick

  PRICE,    // Market price last tick
  PRICE_D,  // Price change last tick

  MAX_DEM,  // Maximum possible consumption last tick
  MAX_SUP,  // Maximum possible production  last tick

  GEN_CONS, // Total applied consumption last tick
  GEN_PROD, // Total applied production  last tick

  DECAY,    // Amount lost to stock decay last tick
  GROWTH,   // Amount gained from nature  last tick

  TRD_EXP,  // Total exports last tick
  TRD_IMP,  // Total imports last tick

  GEN_ACS,  // Aggregated resource access rates from last tick
  POP_ACS,  // Population resource access rates from last tick
  IND_ACS,  // Industrial resource access rates from last tick
};

