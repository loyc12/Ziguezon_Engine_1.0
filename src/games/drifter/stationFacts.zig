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

/// Fixed manual-harvest bundle for the station starter reserves.
/// Units are abstract cargo units. This stays local until drones and asteroid
/// chunks define their own extraction rates.
pub const ManualHarvestBundle = struct
{
  regolith : f64 = 18.0,
  ice      : f64 = 8.0,
  ore      : f64 = 6.0,
};

/// Raw cargo bundle returned by manual harvesting or drones.
/// Amounts are abstract cargo units and are clamped by station storage.
pub const RawCargo = struct
{
  regolith : f64 = 0.0,
  ice      : f64 = 0.0,
  ore      : f64 = 0.0,
};

/// Result state for a raw-resource storage attempt.
pub const RawStoreStatus = enum
{
  emptyCargo,
  stored,
  stationUnavailable,
  missingFacts,
  storageFull,
};

/// Summary of a station storage mutation. `stored` may be less than `requested`
/// when the shared station storage cap clamps the transfer.
pub const RawStoreResult = struct
{
  status      : RawStoreStatus = .emptyCargo,
  stationId   : eng.EntityId   = 0,
  requested   : RawCargo       = .{},
  stored      : RawCargo       = .{},
  total       : f64            = 0.0,
  storageUsed : f64            = 0.0,
  storageCap  : f64            = 0.0,
};

/// Result state for a manual harvest attempt.
pub const ManualHarvestStatus = enum
{
  idle,
  reset,
  harvested,
  stationUnavailable,
  missingFacts,
  reservesEmpty,
  storageFull,
};

/// Summary of the latest manual harvest attempt for overlay and logs.
pub const ManualHarvestResult = struct
{
  status      : ManualHarvestStatus = .idle,
  stationId   : eng.EntityId        = 0,
  regolith    : f64                 = 0.0,
  ice         : f64                 = 0.0,
  ore         : f64                 = 0.0,
  total       : f64                 = 0.0,
  storageUsed : f64                 = 0.0,
  storageCap  : f64                 = 0.0,
};

/// Result state for the latest deterministic station processing pass.
pub const ProcessingStatus = enum
{
  idle,
  reset,
  processed,
  stationUnavailable,
  missingFacts,
  invalidStorage,
  storageFull,
  shortage,
};

/// Aggregated processing output for overlay and log inspection.
pub const ProcessingResult = struct
{
  status         : ProcessingStatus = .idle,
  stationId      : eng.EntityId     = 0,
  recipeCount    : u8               = 0,
  rawConsumed    : f64              = 0.0,
  waterConsumed  : f64              = 0.0,
  oxygenConsumed : f64              = 0.0,
  powerConsumed  : f64              = 0.0,
  waterProduced  : f64              = 0.0,
  oxygenProduced : f64              = 0.0,
  fuelProduced   : f64              = 0.0,
  foodProduced   : f64              = 0.0,
  concrete       : f64              = 0.0,
  metals         : f64              = 0.0,
  electronics    : f64              = 0.0,
  storageUsed    : f64              = 0.0,
  storageCap     : f64              = 0.0,
  blockedRecipe  : [ :0 ] const u8  = "",
  blockedNeed    : [ :0 ] const u8  = "",
};

const MANUAL_HARVEST : ManualHarvestBundle = .{};

/// Local station recipe amounts. Units are deliberately abstract: one unit is
/// only meaningful relative to nearby stockpile, capacity, and throughput
/// values until later systems define real extraction or production rates.
const ResourceAmounts = struct
{
  regolith    : f64 = 0.0,
  ice         : f64 = 0.0,
  ore         : f64 = 0.0,
  oxygen      : f64 = 0.0,
  fuel        : f64 = 0.0,
  water       : f64 = 0.0,
  food        : f64 = 0.0,
  power       : f64 = 0.0,
  concrete    : f64 = 0.0,
  metals      : f64 = 0.0,
  electronics : f64 = 0.0,
};

const ProcessingRecipe = struct
{
  name    : [ :0 ] const u8,
  inputs  : ResourceAmounts,
  outputs : ResourceAmounts,
};

// Power is consumed by recipes as an energy buffer, but it does not use station
// storage. TODO: Replace these local fixed recipes with player-editable
// production rules after rule management exists.
const PROCESSING_RECIPES : []const ProcessingRecipe =
&.{
  .{ .name = "ice cracking",         .inputs = .{ .ice      = 1.0 },                              .outputs = .{ .water       = 1.0 }},
  .{ .name = "fuel synthesis",       .inputs = .{ .water    = 1.0, .power  = 0.2 },               .outputs = .{ .fuel        = 0.7, .oxygen = 0.3 }},
  .{ .name = "ore refining",         .inputs = .{ .ore      = 1.0, .power  = 0.2 },               .outputs = .{ .metals      = 0.8 }},
  .{ .name = "concrete sintering",   .inputs = .{ .regolith = 1.0, .power  = 0.1 },               .outputs = .{ .concrete    = 0.8 }},
  .{ .name = "electronics assembly", .inputs = .{ .metals   = 1.0, .power  = 0.1 },               .outputs = .{ .electronics = 0.8 }},
  .{ .name = "food cultivation",     .inputs = .{ .water    = 0.5, .oxygen = 0.3, .power = 0.1 }, .outputs = .{ .food        = 0.8 }},
};


// ================================ STATION STATE ================================

var STATION_ID : eng.EntityId = 0;


// ================================ STORE FUNCTIONS ================================

/// Registers only the Drifter station fact stores needed by the current slice.
pub fn registerStationStores( ng : *eng.Engine ) bool
{
  if( !ng.worldManager.registerComp( StationResources ))
  {
    utl.qlog( .ERROR, @src(), "Failed to register StationResources" );
    return false;
  }
  if( !ng.worldManager.registerComp( StarterReserves ))
  {
    _ = ng.worldManager.unregisterComp( StationResources );

    utl.qlog( .ERROR, @src(), "Failed to register StarterReserves" );
    return false;
  }
  if( !ng.worldManager.registerComp( StationCapacities ))
  {
    _ = ng.worldManager.unregisterComp( StarterReserves  );
    _ = ng.worldManager.unregisterComp( StationResources );

    utl.qlog( .ERROR, @src(), "Failed to register StationCapacities" );
    return false;
  }

  return true;
}

/// Destroys the current station entity and unregisters station fact stores.
pub fn unregisterStationStores( ng : *eng.Engine ) void
{
  destroyStation( ng );

  _ = ng.worldManager.unregisterComp( StationCapacities );
  _ = ng.worldManager.unregisterComp( StarterReserves  );
  _ = ng.worldManager.unregisterComp( StationResources );
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
  if( !ng.worldManager.isEntityAlive( STATION_ID )){ return null; }

  const resources  = ng.worldManager.getCompConst( StationResources,  STATION_ID ) orelse return null;
  const reserves   = ng.worldManager.getCompConst( StarterReserves,   STATION_ID ) orelse return null;
  const capacities = ng.worldManager.getCompConst( StationCapacities, STATION_ID ) orelse return null;

  return .{
    .stationId  = STATION_ID,
    .resources  = resources,
    .reserves   = reserves,
    .capacities = capacities,
  };
}

/// Returns storage cargo used by tangible resources covered by station storage.
/// Credits and population are accounting values, not cargo. Power is treated as
/// a capacity-like energy buffer for this slice, so it does not consume storage.
pub inline fn getStoredCargoUsed( resources : *const StationResources ) f64
{
  return resources.regolith
       + resources.ice
       + resources.ore
       + resources.oxygen
       + resources.fuel
       + resources.water
       + resources.food
       + resources.concrete
       + resources.metals
       + resources.electronics;
}

/// Returns total raw cargo for proportional storage clamping.
pub inline fn getRawCargoTotal( cargo : RawCargo ) f64
{
  return cargo.regolith + cargo.ice + cargo.ore;
}

/// Attempts one player/debug manual harvest against finite starter reserves.
/// All required station rows are fetched before mutation, so missing facts
/// reject the operation without partially changing station state.
pub fn tryManualHarvest( ng : *eng.Engine ) ManualHarvestResult
{
  if( STATION_ID == 0 or !ng.worldManager.isEntityAlive( STATION_ID ))
  {
    utl.log( .WARN, @src(), "Manual harvest blocked: station Entity {d} is unavailable", .{ STATION_ID });
    return .{ .status = .stationUnavailable, .stationId = STATION_ID };
  }

  const reserves = ng.worldManager.getComp( StarterReserves, STATION_ID ) orelse
  {
    utl.log( .WARN, @src(), "Manual harvest blocked: StarterReserves missing for Entity {d}", .{ STATION_ID });
    return .{ .status = .missingFacts, .stationId = STATION_ID };
  };

  const regolithWant = @min( MANUAL_HARVEST.regolith, reserves.regolith );
  const iceWant      = @min( MANUAL_HARVEST.ice,      reserves.ice      );
  const oreWant      = @min( MANUAL_HARVEST.ore,      reserves.ore      );
  const wantedTotal  = regolithWant + iceWant + oreWant;

  if( wantedTotal <= utl.EPS )
  {
    utl.log( .INFO, @src(), "Manual harvest blocked: starter reserves empty for Entity {d}", .{ STATION_ID });
    return .{ .status = .reservesEmpty, .stationId = STATION_ID };
  }

  const storage = tryStoreRawCargo( ng, .{
    .regolith = regolithWant,
    .ice      = iceWant,
    .ore      = oreWant,
  });

  if( storage.status == .storageFull )
  {
    utl.log( .INFO, @src(), "Manual harvest blocked: storage full ({d:.1}/{d:.1})", .{ storage.storageUsed, storage.storageCap });
    return .{ .status = .storageFull, .stationId = STATION_ID, .storageUsed = storage.storageUsed, .storageCap = storage.storageCap };
  }
  if( storage.status != .stored )
  {
    utl.log( .WARN, @src(), "Manual harvest blocked: raw storage status {s}", .{ @tagName( storage.status )});
    return .{ .status = .missingFacts, .stationId = STATION_ID, .storageUsed = storage.storageUsed, .storageCap = storage.storageCap };
  }

  reserves.regolith -= storage.stored.regolith;
  reserves.ice      -= storage.stored.ice;
  reserves.ore      -= storage.stored.ore;

  utl.log( .INFO, @src(), "Manual harvest Entity {d}: +{d:.1} regolith, +{d:.1} ice, +{d:.1} ore ({d:.1}/{d:.1} storage)", .{
    STATION_ID,
    storage.stored.regolith,
    storage.stored.ice,
    storage.stored.ore,
    storage.storageUsed,
    storage.storageCap,
  });

  return .{
    .status      = .harvested,
    .stationId   = STATION_ID,
    .regolith    = storage.stored.regolith,
    .ice         = storage.stored.ice,
    .ore         = storage.stored.ore,
    .total       = storage.total,
    .storageUsed = storage.storageUsed,
    .storageCap  = storage.storageCap,
  };
}

/// Adds raw resources to station storage after clamping to shared capacity.
/// This is intentionally narrow: drones and manual reserve harvesting should
/// enter the same station stockpile, while production rules stay separate.
pub fn tryStoreRawCargo( ng : *eng.Engine, cargo : RawCargo ) RawStoreResult
{
  const requestedTotal = getRawCargoTotal( cargo );
  if( requestedTotal <= utl.EPS )
  {
    return .{ .status = .emptyCargo, .stationId = STATION_ID, .requested = cargo };
  }

  if( STATION_ID == 0 or !ng.worldManager.isEntityAlive( STATION_ID ))
  {
    return .{ .status = .stationUnavailable, .stationId = STATION_ID, .requested = cargo };
  }

  const resources = ng.worldManager.getComp( StationResources, STATION_ID ) orelse
  {
    return .{ .status = .missingFacts, .stationId = STATION_ID, .requested = cargo };
  };
  const capacities = ng.worldManager.getComp( StationCapacities, STATION_ID ) orelse
  {
    return .{ .status = .missingFacts, .stationId = STATION_ID, .requested = cargo };
  };

  const storageUsed = getStoredCargoUsed( resources );
  const storageCap  = capacities.storage;
  const storageOpen = @max( 0.0, storageCap - storageUsed );

  if( storageOpen <= utl.EPS )
  {
    return .{
      .status      = .storageFull,
      .stationId   = STATION_ID,
      .requested   = cargo,
      .storageUsed = storageUsed,
      .storageCap  = storageCap,
    };
  }

  // TODO: Replace proportional clamping with resource-priority rules once
  // player-editable production and dumping priorities exist.
  const storageRatio = @min( 1.0, storageOpen / requestedTotal );
  const stored : RawCargo =
  .{
    .regolith = cargo.regolith * storageRatio,
    .ice      = cargo.ice      * storageRatio,
    .ore      = cargo.ore      * storageRatio,
  };
  const storedTotal = getRawCargoTotal( stored );

  resources.regolith += stored.regolith;
  resources.ice      += stored.ice;
  resources.ore      += stored.ore;

  return .{
    .status      = .stored,
    .stationId   = STATION_ID,
    .requested   = cargo,
    .stored      = stored,
    .total       = storedTotal,
    .storageUsed = storageUsed + storedTotal,
    .storageCap  = storageCap,
  };
}

/// Applies one deterministic station processing pass.
/// The function gathers every required station row before mutating anything, so
/// missing world facts cannot leave a half-applied recipe.
pub fn tryProcessStation( ng : *eng.Engine ) ProcessingResult
{
  if( STATION_ID == 0 or !ng.worldManager.isEntityAlive( STATION_ID ))
  {
    utl.log( .WARN, @src(), "Processing blocked: station Entity {d} is unavailable", .{ STATION_ID });
    return .{ .status = .stationUnavailable, .stationId = STATION_ID };
  }

  const resources = ng.worldManager.getComp( StationResources, STATION_ID ) orelse
  {
    utl.log( .WARN, @src(), "Processing blocked: StationResources missing for Entity {d}", .{ STATION_ID });
    return .{ .status = .missingFacts, .stationId = STATION_ID };
  };
  const capacities = ng.worldManager.getComp( StationCapacities, STATION_ID ) orelse
  {
    utl.log( .WARN, @src(), "Processing blocked: StationCapacities missing for Entity {d}", .{ STATION_ID });
    return .{ .status = .missingFacts, .stationId = STATION_ID };
  };

  var result : ProcessingResult =
  .{
    .status      = .idle,
    .stationId   = STATION_ID,
    .storageUsed = getStoredCargoUsed( resources ),
    .storageCap  = capacities.storage,
  };

  if( result.storageCap < 0.0 or result.storageUsed > result.storageCap + utl.EPS )
  {
    utl.log( .WARN, @src(), "Processing blocked: invalid storage state ({d:.1}/{d:.1})", .{ result.storageUsed, result.storageCap });
    result.status = .invalidStorage;
    return result;
  }

  for( PROCESSING_RECIPES )| recipe |
  {
    _ = tryRunRecipe( resources, capacities, recipe, &result );
  }

  result.storageUsed = getStoredCargoUsed( resources );

  if( result.recipeCount > 0 )
  {
    result.status = .processed;

    if( result.blockedRecipe.len > 0 )
    {
      utl.log( .INFO, @src(), "Processed Entity {d}: {d} recipe(s), +{d:.1} water, +{d:.1} oxygen, +{d:.1} fuel, +{d:.1} food, +{d:.1} concrete, +{d:.1} metals, +{d:.1} electronics; blocked {s} on {s} ({d:.1}/{d:.1} storage)", .{
        STATION_ID,
        result.recipeCount,
        result.waterProduced,
        result.oxygenProduced,
        result.fuelProduced,
        result.foodProduced,
        result.concrete,
        result.metals,
        result.electronics,
        result.blockedRecipe,
        result.blockedNeed,
        result.storageUsed,
        result.storageCap,
      });
    }
    else
    {
      utl.log( .INFO, @src(), "Processed Entity {d}: {d} recipe(s), +{d:.1} water, +{d:.1} oxygen, +{d:.1} fuel, +{d:.1} food, +{d:.1} concrete, +{d:.1} metals, +{d:.1} electronics ({d:.1}/{d:.1} storage)", .{
        STATION_ID,
        result.recipeCount,
        result.waterProduced,
        result.oxygenProduced,
        result.fuelProduced,
        result.foodProduced,
        result.concrete,
        result.metals,
        result.electronics,
        result.storageUsed,
        result.storageCap,
      });
    }

    return result;
  }

  if( result.status == .idle )
  {
    result.status = .shortage;
    result.blockedRecipe = "processing";
    result.blockedNeed   = "inputs";
  }

  if( result.status == .storageFull )
  {
    utl.log( .INFO, @src(), "Processing blocked: storage full for {s} ({d:.1}/{d:.1})", .{ result.blockedRecipe, result.storageUsed, result.storageCap });
  }
  else
  {
    utl.log( .INFO, @src(), "Processing blocked: {s} needs {s}", .{ result.blockedRecipe, result.blockedNeed });
  }

  return result;
}

fn createStation( ng : *eng.Engine ) bool
{
  const id = ng.worldManager.createEntity().id;
  if( id == 0 )
  {
    utl.qlog( .ERROR, @src(), "Failed to create Drifter station entity" );
    return false;
  }

  if( !ng.worldManager.addComp( StationResources, id, .{} ))
  {
    cleanupFailedStation( ng, id, "StationResources" );
    return false;
  }
  if( !ng.worldManager.addComp( StarterReserves, id, .{} ))
  {
    cleanupFailedStation( ng, id, "StarterReserves" );
    return false;
  }
  if( !ng.worldManager.addComp( StationCapacities, id, .{} ))
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

  if( ng.worldManager.isEntityAlive( oldId ))
  {
    if( !ng.worldManager.destroyEntity( oldId ))
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

  if( ng.worldManager.isEntityAlive( entityId ))
  {
    if( !ng.worldManager.destroyEntity( entityId ))
    {
      utl.log( .ERROR, @src(), "Failed to clean up partial Drifter station Entity {d}", .{ entityId });
    }
  }

  STATION_ID = 0;
}


// ================================ PROCESSING HELPERS ================================

fn tryRunRecipe( resources : *StationResources, capacities : *const StationCapacities, recipe : ProcessingRecipe, result : *ProcessingResult ) bool
{
  const workUnits = getProcessingWorkUnits( recipe.inputs );
  if( workUnits <= utl.EPS ){ return false; }

  var scale = @max( 0.0, capacities.processingThroughput ) / workUnits;
  scale = clampRecipeScaleToInputs( resources, recipe, scale, result );
  if( scale <= utl.EPS ){ return false; }

  const storageUsed  = getStoredCargoUsed( resources );
  const storageDelta = getStoredCargoUsedForAmounts( recipe.outputs ) - getStoredCargoUsedForAmounts( recipe.inputs );
  if( storageDelta > utl.EPS )
  {
    const storageOpen = @max( 0.0, capacities.storage - storageUsed );
    const storageScale = storageOpen / storageDelta;
    if( storageScale + utl.EPS < scale )
    {
      noteBlockedRecipe( result, .storageFull, recipe.name, "storage" );
    }
    scale = @min( scale, storageScale );
    if( scale <= utl.EPS )
    {
      return false;
    }
  }

  applyResourceAmounts( resources, recipe.inputs,  -scale );
  applyResourceAmounts( resources, recipe.outputs,  scale );
  noteRecipeRun( result, recipe, scale );

  return true;
}

fn clampRecipeScaleToInputs( resources : *const StationResources, recipe : ProcessingRecipe, scale : f64, result : *ProcessingResult ) f64
{
  var clampedScale = scale;

  clampedScale = clampScaleForInput( clampedScale, recipe.inputs.regolith,    resources.regolith,    recipe.name, "regolith",    result );
  clampedScale = clampScaleForInput( clampedScale, recipe.inputs.ice,         resources.ice,         recipe.name, "ice",         result );
  clampedScale = clampScaleForInput( clampedScale, recipe.inputs.ore,         resources.ore,         recipe.name, "ore",         result );
  clampedScale = clampScaleForInput( clampedScale, recipe.inputs.oxygen,      resources.oxygen,      recipe.name, "oxygen",      result );
  clampedScale = clampScaleForInput( clampedScale, recipe.inputs.fuel,        resources.fuel,        recipe.name, "fuel",        result );
  clampedScale = clampScaleForInput( clampedScale, recipe.inputs.water,       resources.water,       recipe.name, "water",       result );
  clampedScale = clampScaleForInput( clampedScale, recipe.inputs.food,        resources.food,        recipe.name, "food",        result );
  clampedScale = clampScaleForInput( clampedScale, recipe.inputs.power,       resources.power,       recipe.name, "power",       result );
  clampedScale = clampScaleForInput( clampedScale, recipe.inputs.concrete,    resources.concrete,    recipe.name, "concrete",    result );
  clampedScale = clampScaleForInput( clampedScale, recipe.inputs.metals,      resources.metals,      recipe.name, "metals",      result );
  clampedScale = clampScaleForInput( clampedScale, recipe.inputs.electronics, resources.electronics, recipe.name, "electronics", result );

  return clampedScale;
}

fn clampScaleForInput( scale : f64, requiredPerScale : f64, available : f64, recipeName : [ :0 ] const u8, resourceName : [ :0 ] const u8, result : *ProcessingResult ) f64
{
  if( requiredPerScale <= utl.EPS ){ return scale; }

  const availableScale = @max( 0.0, available ) / requiredPerScale;
  if( availableScale + utl.EPS < scale )
  {
    noteBlockedRecipe( result, .shortage, recipeName, resourceName );
  }

  return @min( scale, availableScale );
}

fn noteBlockedRecipe( result : *ProcessingResult, status : ProcessingStatus, recipeName : [ :0 ] const u8, need : [ :0 ] const u8 ) void
{
  if( result.blockedRecipe.len > 0 ){ return; }

  result.status        = status;
  result.blockedRecipe = recipeName;
  result.blockedNeed   = need;
}

fn noteRecipeRun( result : *ProcessingResult, recipe : ProcessingRecipe, scale : f64 ) void
{
  result.recipeCount +|= 1;

  result.rawConsumed    += ( recipe.inputs.regolith + recipe.inputs.ice + recipe.inputs.ore ) * scale;
  result.waterConsumed  += recipe.inputs.water  * scale;
  result.oxygenConsumed += recipe.inputs.oxygen * scale;
  result.powerConsumed  += recipe.inputs.power  * scale;

  result.waterProduced  += recipe.outputs.water       * scale;
  result.oxygenProduced += recipe.outputs.oxygen      * scale;
  result.fuelProduced   += recipe.outputs.fuel        * scale;
  result.foodProduced   += recipe.outputs.food        * scale;
  result.concrete       += recipe.outputs.concrete    * scale;
  result.metals         += recipe.outputs.metals      * scale;
  result.electronics    += recipe.outputs.electronics * scale;
}

inline fn getProcessingWorkUnits( amounts : ResourceAmounts ) f64
{
  return amounts.regolith
       + amounts.ice
       + amounts.ore
       + amounts.oxygen
       + amounts.fuel
       + amounts.water
       + amounts.food
       + amounts.concrete
       + amounts.metals
       + amounts.electronics;
}

inline fn getStoredCargoUsedForAmounts( amounts : ResourceAmounts ) f64
{
  return amounts.regolith
       + amounts.ice
       + amounts.ore
       + amounts.oxygen
       + amounts.fuel
       + amounts.water
       + amounts.food
       + amounts.concrete
       + amounts.metals
       + amounts.electronics;
}

fn applyResourceAmounts( resources : *StationResources, amounts : ResourceAmounts, scale : f64 ) void
{
  resources.regolith    += amounts.regolith    * scale;
  resources.ice         += amounts.ice         * scale;
  resources.ore         += amounts.ore         * scale;
  resources.oxygen      += amounts.oxygen      * scale;
  resources.fuel        += amounts.fuel        * scale;
  resources.water       += amounts.water       * scale;
  resources.food        += amounts.food        * scale;
  resources.power       += amounts.power       * scale;
  resources.concrete    += amounts.concrete    * scale;
  resources.metals      += amounts.metals      * scale;
  resources.electronics += amounts.electronics * scale;
}
