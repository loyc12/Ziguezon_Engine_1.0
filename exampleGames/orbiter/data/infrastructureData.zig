const std = @import( "std" );
const def = @import( "defs" );

const gbl = @import( "../gameGlobals.zig" );
const gdf = @import( "../gameDefs.zig"    );

//const PowerSrc = @import( "powerData.zig"       ).PowerSrc;


pub const InfType = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  pub inline fn toIdx( self : @This() ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) @This()  { return @enumFromInt( i ); }

  HABITAT,      // Increases area of pressurized locations

//BATTERY,      // Grants energy storage capacity
//TANKS,        // Grants fluid storage capacity
  STORAGE,      // Grants cargo storage capacity
  HOUSING,      // Increases population cap

//AMENITIES,    // Services population needs
//EDUCATION,    // Generate research
//COMMERCE,     // Increase tax revenues ?

//POWER_GRID,   // Grants energy transport capacity locally
//PIPE_NETWORK, // Grants fluid  transport capacity locally
//ROAD_NETWORK, // Grants cargo  transport capacity locally

//POWER_BEAM,   // Grants energy transport capacity to and from orbit
//ELEVATOR,     // Grants cargo  transport capacity to and from orbit

//LAUNCHPAD,    // Grants docking capacity for vessels

//DATA_CENTER,  // Creates Flops ?

  ASSEMBLY,     // Increases max building rate in PARTs per tick


  pub inline fn canBeBuiltIn( self : InfType, loc : gdf.EconLoc, hasAtmo : bool ) bool
  {
    _ = hasAtmo;

    if( loc == .GROUND )
    {
      return switch( self )
      {
        .ASSEMBLY => true,
        .HOUSING  => true,
        .HABITAT  => true,

        .STORAGE  => true,
      //.BATTERY  => true,

      //else      => false,
      };
    }
    else // .ORBIT or .L1-5
    {
      return switch( self )
      {
        .ASSEMBLY => true,
        .HOUSING  => true,
        .HABITAT  => true,

        .STORAGE  => true,
      //.BATTERY  => true,

      //else      => false,
      };
    }
  }

  pub fn getMetric_f32( self : InfType, metric : InfMetricEnum ) f32
  {
    return @floatCast( infMetricData.get( self, metric ));
  }
  pub fn getMetric_f64( self : InfType, metric : InfMetricEnum ) f64
  {
    return infMetricData.get( self, metric );
  }
  pub fn getMetric_u32( self : InfType, metric : InfMetricEnum ) u32
  {
    return @intFromFloat( infMetricData.get( self, metric ));
  }
  pub fn getMetric_u64( self : InfType, metric : InfMetricEnum ) u64
  {
    return @intFromFloat( infMetricData.get( self, metric ));
  }
};


// ================================ INFRASTRUCTURE METRICS GRID ================================

pub var infMetricData : def.GenDataGrid( f64, InfType, InfMetricEnum ) = .{};

pub const InfMetricEnum = enum( u8 )
{
  MASS,
  AREA_COST,
  PART_COST,
  MAINT_RATE,
  POLLUTION,
  CAPACITY,
};


pub fn loadInfrastructureData() void
{
  infMetricData.fillWith( 0.0 );


  // ================================ MASS ================================
  // Unit : Gt ( 1e12 kg ). A housing block ~10,000 t = 1e-8 Gt
  // These are intentionally tiny in Gt - they represent single facilities

  infMetricData.set( .ASSEMBLY, .MASS, 0.000_000_040 ); // ~40,000 t - heavy industrial yard
  infMetricData.set( .HOUSING,  .MASS, 0.000_000_010 ); // ~10,000 t - concrete residential bloc
  infMetricData.set( .HABITAT,  .MASS, 0.000_000_050 ); // ~50,000 t - pressurized dome structur
  infMetricData.set( .STORAGE,  .MASS, 0.000_000_015 ); // ~15,000 t - warehouse complex


  // ================================ AREA COST ================================
  // Unit : km². 1 hectare = 0.01 km²

  infMetricData.set( .ASSEMBLY, .AREA_COST, 0.20 ); // 20 ha - Construction yard / fabrication workshop
  infMetricData.set( .HOUSING,  .AREA_COST, 0.02 ); //  2 ha - Residential block ( 100 pop → 5000/km² )
  infMetricData.set( .HABITAT,  .AREA_COST, 0.00 ); //  0 ha - Pressurized dome (provides area, not uses it)
  infMetricData.set( .STORAGE,  .AREA_COST, 0.05 ); //  5 ha - Warehouse/depot complex


  // ================================ PART COST ================================
  // Unit : t of manufactured parts needed to construct one unit
  // A residential block: ~2,000 t of steel/concrete/components
  // An assembly yard: ~5,000 t of heavy machinery + structures

  infMetricData.set( .ASSEMBLY, .PART_COST, 10000.0 ); // Heavy machinery, cranes, fabrication tools
  infMetricData.set( .HOUSING,  .PART_COST,  2000.0 ); // Concrete, steel, wiring, plumbing
  infMetricData.set( .HABITAT,  .PART_COST, 50000.0 ); // Massive pressurized structure
  infMetricData.set( .STORAGE,  .PART_COST,  3000.0 ); // Shelving, climate control, structures


  // ================================ MAINT RATE ================================
  // Fraction of PART_COST consumed as PART per week for upkeep
  // Real buildings: ~1-3% of construction cost per YEAR for maintenance

  infMetricData.set( .ASSEMBLY, .MAINT_RATE, 0.0006 );  // ~3% annual — heavy wear on equipment
  infMetricData.set( .HOUSING,  .MAINT_RATE, 0.0003 );  // ~1.5% annual — residential is low-maintenance
  infMetricData.set( .HABITAT,  .MAINT_RATE, 0.0008 );  // ~4% annual — pressure vessels need constant upkee
  infMetricData.set( .STORAGE,  .MAINT_RATE, 0.0004 );  // ~2% annual


  // ================================ POLLUTION ================================
  // Units: abstract pollution points per unit per tick at full usage
  // Will be recalibrated after industry pollution is set

  infMetricData.set( .ASSEMBLY, .POLLUTION, 16.0 );  // Dust, material waste
  infMetricData.set( .HOUSING,  .POLLUTION,  0.5 );  // Sewage, waste, minor emissions
  infMetricData.set( .HABITAT,  .POLLUTION,  0.0 );  // Sealed system
  infMetricData.set( .STORAGE,  .POLLUTION,  0.2 );  // Minimal — some runoff


  // ================================ CAPACITY ================================

  infMetricData.set( .ASSEMBLY, .CAPACITY,  100.0 ); // 100 t of PARTs processed per week
  infMetricData.set( .HOUSING,  .CAPACITY,  100.0 ); // 100 people housed per unit
  infMetricData.set( .HABITAT,  .CAPACITY,    1.0 ); // 1 km2 of pressurized area per unit
  infMetricData.set( .STORAGE,  .CAPACITY, 5000.0 ); // 5,000 t of resources stored per unit
}


// ================================ INFRASTRUCTURE STATE ENUM ================================
// NOTE : used in Economy to store local quantities and metrics

pub const InfStateData = def.GenDataGrid( f64, InfStateEnum, InfType );

pub const InfStateEnum = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  COUNT,   // Current infrastructure count
  DELTA,   // Net total change last tick

  DECAY,   // Amount lost to building decay   last tick
  BUILT,   // Amount gained from construction last tick

  EXPENSE, // Amount of money used for maintaining the infrastructure last tick
  REVENUE, // Amount of money gained from running  the infrastructure last tick
  PROFIT,  // Income - expense
  SAVINGS, // Stored profits from previous ticks ( decays via inflation )

  USE_LVL, // How much of the available infrastructure was used last tick
};
