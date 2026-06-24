const eng = @import( "engine" );
const utl = @import( "utils"  );


// ================================ STATION COMPONENT TYPES ================================

/// Station-owned resource stockpiles for the first Drifter world-fact slice.
/// Amounts are abstract resource units unless a later system gives the field a
/// narrower meaning.
pub const StationResources = struct
{
  pub const compStorePolicy : eng.CompStorePolicy = .SPARSE;

  regolith    : f64 = 0.0,
  ice         : f64 = 0.0,
  ore         : f64 = 0.0,

  oxygen      : f64 = 20.0,
  fuel        : f64 = 0.0,
  water       : f64 = 25.0,
  food        : f64 = 18.0,
  power       : f64 = 40.0,
  concrete    : f64 = 0.0,
  metals      : f64 = 0.0,
  electronics : f64 = 0.0,

  credits     : f64 = 250.0,
  population  : f64 = 12.0, // Population is a resource-like stockpile for now.
};

/// Finite manual-harvest reserves embedded in the station's main asteroid.
pub const StarterReserves = struct
{
  pub const compStorePolicy : eng.CompStorePolicy = .SPARSE;

  regolith : f64 = 600.0,
  ice      : f64 = 280.0,
  ore      : f64 = 180.0,
};

/// Baseline station limits and throughput facts. Later systems should mutate
/// these values rather than replacing this component shape.
pub const StationCapacities = struct
{
  pub const compStorePolicy : eng.CompStorePolicy = .SPARSE;

  storage              : f64 = 320.0, // Total abstract storage shared by tangible resources.
  droneSlots           : u16 = 2,
  processingThroughput : f64 = 4.0,   // Resource units processable per future processing pass.
  powerOutput          : f64 = 12.0,
  hangarThroughput     : f64 = 1.0,   // Drone launch/return slots per future logistics pass.
  marketThroughput     : f64 = 20.0,
  constructionCapacity : f64 = 1.0,
};

/// Read-only station fact bundle for overlay and debug inspection.
pub const StationFactView = struct
{
  stationId  : eng.EntityId,
  resources  : *const StationResources,
  reserves   : *const StarterReserves,
  capacities : *const StationCapacities,
};


// ================================ STATION STATE ================================

var STATION_ID : eng.EntityId = 0;


// ================================ STORE FUNCTIONS ================================

/// Registers only the Drifter station fact stores needed by the current slice.
pub fn registerStationStores( ng : *eng.Engine ) bool
{
  if( !ng.world.registerComp( StationResources ))
  {
    utl.qlog( .ERROR, @src(), "Failed to register StationResources" );
    return false;
  }
  if( !ng.world.registerComp( StarterReserves ))
  {
    _ = ng.world.unregisterComp( StationResources );

    utl.qlog( .ERROR, @src(), "Failed to register StarterReserves" );
    return false;
  }
  if( !ng.world.registerComp( StationCapacities ))
  {
    _ = ng.world.unregisterComp( StarterReserves  );
    _ = ng.world.unregisterComp( StationResources );

    utl.qlog( .ERROR, @src(), "Failed to register StationCapacities" );
    return false;
  }

  return true;
}

/// Destroys the current station entity and unregisters station fact stores.
pub fn unregisterStationStores( ng : *eng.Engine ) void
{
  destroyStation( ng );

  _ = ng.world.unregisterComp( StationCapacities );
  _ = ng.world.unregisterComp( StarterReserves  );
  _ = ng.world.unregisterComp( StationResources );
}


// ================================ STATION ENTITY FUNCTIONS ================================

/// Replaces the current station entity with a fresh world-owned fact set.
pub fn resetStation( ng : *eng.Engine ) bool
{
  destroyStation( ng );
  return createStation( ng );
}

/// Returns the currently tracked station id, or 0 when station setup is unavailable.
pub inline fn getStationId() eng.EntityId
{
  return STATION_ID;
}

/// Returns the station's read-only fact rows when setup completed and rows exist.
pub fn getStationFactView( ng : *eng.Engine ) ?StationFactView
{
  if( STATION_ID == 0 ){ return null; }
  if( !ng.world.isEntityAlive( STATION_ID )){ return null; }

  const resources  = ng.world.getCompConst( StationResources,  STATION_ID ) orelse return null;
  const reserves   = ng.world.getCompConst( StarterReserves,   STATION_ID ) orelse return null;
  const capacities = ng.world.getCompConst( StationCapacities, STATION_ID ) orelse return null;

  return .{
    .stationId  = STATION_ID,
    .resources  = resources,
    .reserves   = reserves,
    .capacities = capacities,
  };
}

fn createStation( ng : *eng.Engine ) bool
{
  const id = ng.world.createEntity().id;
  if( id == 0 )
  {
    utl.qlog( .ERROR, @src(), "Failed to create Drifter station entity" );
    return false;
  }

  if( !ng.world.addComp( StationResources, id, .{} ))
  {
    cleanupFailedStation( ng, id, "StationResources" );
    return false;
  }
  if( !ng.world.addComp( StarterReserves, id, .{} ))
  {
    cleanupFailedStation( ng, id, "StarterReserves" );
    return false;
  }
  if( !ng.world.addComp( StationCapacities, id, .{} ))
  {
    cleanupFailedStation( ng, id, "StationCapacities" );
    return false;
  }

  STATION_ID = id;
  utl.log( .INFO, @src(), "Created Drifter station Entity {d}", .{ STATION_ID });
  return true;
}

fn destroyStation( ng : *eng.Engine ) void
{
  if( STATION_ID == 0 ){ return; }

  const oldId = STATION_ID;
  STATION_ID = 0;

  if( ng.world.isEntityAlive( oldId ))
  {
    if( !ng.world.destroyEntity( oldId ))
    {
      utl.log( .ERROR, @src(), "Failed to destroy Drifter station Entity {d}", .{ oldId });
      return;
    }
  }

  utl.log( .DEBUG, @src(), "Cleared Drifter station Entity {d}", .{ oldId });
}

fn cleanupFailedStation( ng : *eng.Engine, entityId : eng.EntityId, comptime failedFact : []const u8 ) void
{
  utl.log( .ERROR, @src(), "Failed to add {s} to Drifter station Entity {d}", .{ failedFact, entityId });

  if( ng.world.isEntityAlive( entityId ))
  {
    if( !ng.world.destroyEntity( entityId ))
    {
      utl.log( .ERROR, @src(), "Failed to clean up partial Drifter station Entity {d}", .{ entityId });
    }
  }

  STATION_ID = 0;
}
