const eng     = @import( "engine"           );
const utl     = @import( "utils"            );
const station = @import( "stationFacts.zig" );

const Vec2 = utl.Vec2;


// ================================ HARVEST COMPONENT TYPES ================================

/// World-owned drifting harvest target.
/// `chunksRemaining` is the abstract size unit for this first slice: small
/// asteroids have one chunk, larger asteroids can release several over time.
pub const AsteroidFact = struct
{
  pub const compStorePolicy : eng.CompStorePolicy = .PACKED;

  pos             : Vec2,
  velocity        : Vec2,
  radius          : f64,
  chunkTotal      : u8,
  chunksRemaining : u8,
  chunksReleased  : u8 = 0,
  depleted         : bool = false,
};

/// Temporary harvestable unit created from an asteroid.
/// Cargo fields are abstract raw-resource units compatible with station storage.
pub const ChunkFact = struct
{
  pub const compStorePolicy : eng.CompStorePolicy = .PACKED;

  sourceAsteroidId : eng.EntityId,
  pos              : Vec2,
  velocity         : Vec2,
  radius           : f64,
  cargo            : station.RawCargo,
  reservedBy       : eng.EntityId = 0, // Future scheduler hooks can replace this direct assignment.
};

/// Visible autonomous station worker.
/// Timers are temporary game-local ticks until engine scheduler cadence owns
/// drone travel and work phases.
pub const DroneFact = struct
{
  pub const compStorePolicy : eng.CompStorePolicy = .PACKED;

  state         : DroneState   = .idle,
  pos           : Vec2         = STATION_POS,
  fromPos       : Vec2         = STATION_POS,
  targetPos     : Vec2         = STATION_POS,
  targetChunkId : eng.EntityId = 0,
  cargo         : station.RawCargo = .{},
  ticksLeft     : u16 = 0,
  ticksTotal    : u16 = 1,
};

/// First visible drone states. More work types can extend this without
/// changing asteroid/chunk ownership.
pub const DroneState = enum
{
  idle,
  outbound,
  harvesting,
  returning,
  unloading,
  disabled,
};

/// Latest autonomous harvest-loop status for overlay and logs.
pub const HarvestLoopStatus = enum
{
  idle,
  reset,
  running,
  assigned,
  chunkCreated,
  harvested,
  unloaded,
  noDrones,
  noIdleDrones,
  noTargets,
  noStorage,
  missingFacts,
  stationUnavailable,
};

/// Aggregated harvest-loop result for one tick.
pub const HarvestLoopResult = struct
{
  status          : HarvestLoopStatus = .idle,
  asteroidCount   : u16 = 0,
  chunkCount      : u16 = 0,
  droneCount      : u16 = 0,
  idleDrones      : u16 = 0,
  busyDrones      : u16 = 0,
  createdChunkId  : eng.EntityId = 0,
  targetChunkId   : eng.EntityId = 0,
  droneId         : eng.EntityId = 0,
  returned        : station.RawCargo = .{},
  storageUsed     : f64 = 0.0,
  storageCap      : f64 = 0.0,
};


// ================================ HARVEST STATE ================================

pub const STATION_POS    : Vec2  = .{};
pub const STATION_RADIUS : f64   = 96.0;

pub const ASTEROID_COUNT : usize = 16;
pub const DRONE_COUNT    : usize = 2;
pub const MAX_CHUNKS     : usize = 32;

const ASTEROID_WRAP_HEIGHT : f64 = 1024.0;
const ASTEROID_WRAP_WIDTH  : f64 = ASTEROID_WRAP_HEIGHT * 2.0;
const ASTEROID_SAFE_RADIUS : f64 = STATION_RADIUS + 160.0;
const ASTEROID_RADIUS_MIN  : f64 = 20.0;
const ASTEROID_RADIUS_MAX  : f64 = 80.0;
const ASTEROID_DRIFT_Y_MAX : f64 = 50.0;

const CHUNK_RADIUS_MIN     : f64 = 8.0;
const CHUNK_RADIUS_MAX     : f64 = 16.0;
const DRONE_RADIUS         : f64 = 7.0;
const DRONE_CARGO_CAP      : f64 = 14.0;
const DRONE_OUTBOUND_TICKS : u16 = 72;
const DRONE_HARVEST_TICKS  : u16 = 48;
const DRONE_RETURN_TICKS   : u16 = 72;
const DRONE_UNLOAD_TICKS   : u16 = 12;

var ASTEROID_IDS : [ ASTEROID_COUNT ]eng.EntityId = .{ 0 } ** ASTEROID_COUNT;
var CHUNK_IDS    : [ MAX_CHUNKS     ]eng.EntityId = .{ 0 } ** MAX_CHUNKS;
var DRONE_IDS    : [ DRONE_COUNT    ]eng.EntityId = .{ 0 } ** DRONE_COUNT;


// ================================ STORE FUNCTIONS ================================

/// Registers Drifter's asteroid, chunk, and drone component stores.
pub fn registerHarvestStores( ng : *eng.Engine ) bool
{
  if( !ng.world.registerComp( AsteroidFact ))
  {
    utl.qlog( .ERROR, @src(), "Failed to register AsteroidFact" );
    return false;
  }
  if( !ng.world.registerComp( ChunkFact ))
  {
    _ = ng.world.unregisterComp( AsteroidFact );

    utl.qlog( .ERROR, @src(), "Failed to register ChunkFact" );
    return false;
  }
  if( !ng.world.registerComp( DroneFact ))
  {
    _ = ng.world.unregisterComp( ChunkFact    );
    _ = ng.world.unregisterComp( AsteroidFact );

    utl.qlog( .ERROR, @src(), "Failed to register DroneFact" );
    return false;
  }

  return true;
}

/// Destroys harvest entities and unregisters harvest component stores.
pub fn unregisterHarvestStores( ng : *eng.Engine ) void
{
  destroyHarvestFacts( ng );

  _ = ng.world.unregisterComp( DroneFact    );
  _ = ng.world.unregisterComp( ChunkFact    );
  _ = ng.world.unregisterComp( AsteroidFact );
}


// ================================ ENTITY LIFECYCLE ================================

/// Replaces all asteroid, chunk, and drone entities with a fresh deterministic field.
pub fn resetHarvestFacts( ng : *eng.Engine ) bool
{
  destroyHarvestFacts( ng );
  eng.G_ENG.rng.seedInit( utl.getNow().value );

  for( &ASTEROID_IDS, 0.. )| *slot, index |
  {
    slot.* = createAsteroid( ng, index ) orelse return false;
  }
  for( &DRONE_IDS, 0.. )| *slot, index |
  {
    slot.* = createDrone( ng, index ) orelse return false;
  }

  utl.qlog( .INFO, @src(), "Drifter harvest facts reset" );
  return true;
}

fn destroyHarvestFacts( ng : *eng.Engine ) void
{
  destroyEntitySlots( ng, &CHUNK_IDS    );
  destroyEntitySlots( ng, &DRONE_IDS    );
  destroyEntitySlots( ng, &ASTEROID_IDS );
}

fn destroyEntitySlots( ng : *eng.Engine, slots : []eng.EntityId ) void
{
  for( slots )| *slot |
  {
    if( slot.* == 0 ){ continue; }

    const id = slot.*;
    slot.* = 0;

    if( ng.world.isEntityAlive( id ))
    {
      if( !ng.world.destroyEntity( id ))
      {
        utl.log( .ERROR, @src(), "Failed to destroy Drifter harvest Entity {d}", .{ id });
      }
    }
  }
}

fn createAsteroid( ng : *eng.Engine, index : usize ) ?eng.EntityId
{
  const id = ng.world.createEntity().id;
  if( id == 0 )
  {
    utl.qlog( .ERROR, @src(), "Failed to create Drifter asteroid entity" );
    return null;
  }

  const fact = makeAsteroidFact( index );
  if( !ng.world.addComp( AsteroidFact, id, fact ))
  {
    cleanupFailedHarvestEntity( ng, id, "AsteroidFact" );
    return null;
  }

  return id;
}

fn createDrone( ng : *eng.Engine, index : usize ) ?eng.EntityId
{
  const id = ng.world.createEntity().id;
  if( id == 0 )
  {
    utl.qlog( .ERROR, @src(), "Failed to create Drifter drone entity" );
    return null;
  }

  const homeOffset = Vec2.new( -18.0 + ( @as( f64, @floatFromInt( index )) * 36.0 ), -( STATION_RADIUS + 24.0 ));
  if( !ng.world.addComp( DroneFact, id, .{ .pos = STATION_POS.add( homeOffset ), .fromPos = STATION_POS.add( homeOffset )}))
  {
    cleanupFailedHarvestEntity( ng, id, "DroneFact" );
    return null;
  }

  return id;
}

fn createChunkFromAsteroid( ng : *eng.Engine, asteroidId : eng.EntityId, result : *HarvestLoopResult ) ?eng.EntityId
{
  const slot = findFreeChunkSlot() orelse return null;
  const asteroid = ng.world.getComp( AsteroidFact, asteroidId ) orelse return null;
  if( asteroid.chunksRemaining == 0 ){ return null; }

  const id = ng.world.createEntity().id;
  if( id == 0 )
  {
    utl.qlog( .ERROR, @src(), "Failed to create Drifter chunk entity" );
    return null;
  }

  const chunkOrdinal = asteroid.chunksReleased;
  asteroid.chunksRemaining -= 1;
  asteroid.chunksReleased  += 1;
  asteroid.depleted = asteroid.chunksRemaining == 0;

  if( !ng.world.addComp( ChunkFact, id, makeChunkFact( asteroidId, asteroid.*, chunkOrdinal )))
  {
    cleanupFailedHarvestEntity( ng, id, "ChunkFact" );
    return null;
  }

  CHUNK_IDS[ slot ] = id;
  result.status = .chunkCreated;
  result.createdChunkId = id;

  utl.log( .INFO, @src(), "Asteroid Entity {d} released Chunk Entity {d} ({d}/{d})", .{
    asteroidId,
    id,
    asteroid.chunksReleased,
    asteroid.chunkTotal,
  });

  return id;
}

fn cleanupFailedHarvestEntity( ng : *eng.Engine, entityId : eng.EntityId, comptime failedFact : []const u8 ) void
{
  utl.log( .ERROR, @src(), "Failed to add {s} to Drifter harvest Entity {d}", .{ failedFact, entityId });

  if( ng.world.isEntityAlive( entityId ))
  {
    if( !ng.world.destroyEntity( entityId ))
    {
      utl.log( .ERROR, @src(), "Failed to clean up partial Drifter harvest Entity {d}", .{ entityId });
    }
  }
}


// ================================ TICK FUNCTIONS ================================

/// Advances asteroid drift, chunk harvesting, and visible drone state machines.
pub fn tickHarvestLoop( ng : *eng.Engine, deltaTime : f64 ) HarvestLoopResult
{
  var result : HarvestLoopResult = .{ .status = .running };

  tickAsteroidDrift( ng, deltaTime );
  tickChunkDrift( ng, deltaTime );

  for( DRONE_IDS )| droneId |
  {
    if( droneId == 0 ){ continue; }

    const drone = ng.world.getComp( DroneFact, droneId ) orelse
    {
      result.status = .missingFacts;
      continue;
    };

    tickDroneState( ng, droneId, drone, &result );
  }

  var sawIdle = false;
  for( DRONE_IDS )| droneId |
  {
    if( droneId == 0 ){ continue; }

    const drone = ng.world.getComp( DroneFact, droneId ) orelse continue;
    if( drone.state != .idle ){ continue; }

    sawIdle = true;
    if( tryAssignDrone( ng, droneId, drone, &result ))
    {
      sawIdle = false;
    }
  }

  fillHarvestCounts( ng, &result );

  if( result.status == .running )
  {
    if( result.droneCount == 0 )                 { result.status = .noDrones;     }
    else if( result.busyDrones == result.droneCount and !sawIdle ){ result.status = .noIdleDrones; }
    else if( sawIdle )                           { result.status = .noTargets;    }
  }

  return result;
}

fn tickAsteroidDrift( ng : *eng.Engine, deltaTime : f64 ) void
{
  for( ASTEROID_IDS )| asteroidId |
  {
    if( asteroidId == 0 ){ continue; }

    const asteroid = ng.world.getComp( AsteroidFact, asteroidId ) orelse continue;
    asteroid.pos = asteroid.pos.add( asteroid.velocity.mulVal( deltaTime ));
    wrapFieldPos( &asteroid.pos );
  }
}

fn tickChunkDrift( ng : *eng.Engine, deltaTime : f64 ) void
{
  for( CHUNK_IDS )| chunkId |
  {
    if( chunkId == 0 ){ continue; }

    const chunk = ng.world.getComp( ChunkFact, chunkId ) orelse continue;
    chunk.pos = chunk.pos.add( chunk.velocity.mulVal( deltaTime ));
    wrapFieldPos( &chunk.pos );
  }
}

fn tickDroneState( ng : *eng.Engine, droneId : eng.EntityId, drone : *DroneFact, result : *HarvestLoopResult ) void
{
  switch( drone.state )
  {
    .idle, .disabled => return,

    .outbound =>
    {
      if( ng.world.getCompConst( ChunkFact, drone.targetChunkId ))| chunk |
      {
        drone.targetPos = chunk.pos;
      }

      tickTimedDroneMotion( drone );
      if( drone.ticksLeft == 0 )
      {
        beginDroneState( drone, .harvesting, drone.pos, drone.pos, DRONE_HARVEST_TICKS );
      }
    },

    .harvesting =>
    {
      if( ng.world.getCompConst( ChunkFact, drone.targetChunkId ))| chunk |
      {
        drone.pos = chunk.pos;
      }

      tickDroneTimer( drone );
      if( drone.ticksLeft == 0 )
      {
        finishDroneHarvest( ng, droneId, drone, result );
      }
    },

    .returning =>
    {
      tickTimedDroneMotion( drone );
      if( drone.ticksLeft == 0 )
      {
        beginDroneState( drone, .unloading, STATION_POS, STATION_POS, DRONE_UNLOAD_TICKS );
      }
    },

    .unloading =>
    {
      drone.pos = STATION_POS;
      tickDroneTimer( drone );
      if( drone.ticksLeft == 0 )
      {
        finishDroneUnload( ng, droneId, drone, result );
      }
    },
  }
}

fn tryAssignDrone( ng : *eng.Engine, droneId : eng.EntityId, drone : *DroneFact, result : *HarvestLoopResult ) bool
{
  var chunkId = findAvailableChunk( ng );
  if( chunkId == null )
  {
    if( findAsteroidWithChunks( ng ))| asteroidId |
    {
      chunkId = createChunkFromAsteroid( ng, asteroidId, result );
    }
  }
  if( chunkId == null ){ return false; }

  const chunk = ng.world.getComp( ChunkFact, chunkId.? ) orelse return false;
  chunk.reservedBy = droneId;

  drone.targetChunkId = chunkId.?;
  beginDroneState( drone, .outbound, drone.pos, chunk.pos, DRONE_OUTBOUND_TICKS );

  result.status        = .assigned;
  result.droneId       = droneId;
  result.targetChunkId = chunkId.?;

  utl.log( .INFO, @src(), "Drone Entity {d} assigned to Chunk Entity {d}", .{ droneId, chunkId.? });
  return true;
}

fn finishDroneHarvest( ng : *eng.Engine, droneId : eng.EntityId, drone : *DroneFact, result : *HarvestLoopResult ) void
{
  const chunk = ng.world.getComp( ChunkFact, drone.targetChunkId ) orelse
  {
    drone.targetChunkId = 0;
    beginDroneState( drone, .idle, drone.pos, drone.pos, 1 );
    result.status = .missingFacts;
    return;
  };

  drone.cargo = takeChunkCargo( chunk, DRONE_CARGO_CAP );
  chunk.reservedBy = 0;

  if( station.getRawCargoTotal( chunk.cargo ) <= utl.EPS )
  {
    deleteChunk( ng, drone.targetChunkId );
  }

  result.status        = .harvested;
  result.droneId       = droneId;
  result.targetChunkId = drone.targetChunkId;
  result.returned      = drone.cargo;

  if( station.getRawCargoTotal( drone.cargo ) <= utl.EPS )
  {
    drone.targetChunkId = 0;
    beginDroneState( drone, .idle, drone.pos, drone.pos, 1 );
    return;
  }

  utl.log( .INFO, @src(), "Drone Entity {d} harvested Chunk Entity {d}: {d:.1} raw", .{
    droneId,
    drone.targetChunkId,
    station.getRawCargoTotal( drone.cargo ),
  });

  beginDroneState( drone, .returning, drone.pos, STATION_POS, DRONE_RETURN_TICKS );
}

fn finishDroneUnload( ng : *eng.Engine, droneId : eng.EntityId, drone : *DroneFact, result : *HarvestLoopResult ) void
{
  const stored = station.tryStoreRawCargo( ng, drone.cargo );

  result.droneId     = droneId;
  result.returned    = stored.stored;
  result.storageUsed = stored.storageUsed;
  result.storageCap  = stored.storageCap;

  switch( stored.status )
  {
    .stored =>
    {
      subtractRawCargo( &drone.cargo, stored.stored );

      utl.log( .INFO, @src(), "Drone Entity {d} unloaded: +{d:.1} regolith, +{d:.1} ice, +{d:.1} ore ({d:.1}/{d:.1} storage)", .{
        droneId,
        stored.stored.regolith,
        stored.stored.ice,
        stored.stored.ore,
        stored.storageUsed,
        stored.storageCap,
      });

      if( station.getRawCargoTotal( drone.cargo ) <= utl.EPS )
      {
        drone.cargo = .{};
        drone.targetChunkId = 0;
        beginDroneState( drone, .idle, STATION_POS, STATION_POS, 1 );
        result.status = .unloaded;
      }
      else
      {
        beginDroneState( drone, .unloading, STATION_POS, STATION_POS, DRONE_UNLOAD_TICKS );
        result.status = .noStorage;
      }
    },

    .storageFull =>
    {
      beginDroneState( drone, .unloading, STATION_POS, STATION_POS, DRONE_UNLOAD_TICKS );
      result.status = .noStorage;
    },

    .stationUnavailable =>
    {
      result.status = .stationUnavailable;
    },

    else =>
    {
      result.status = .missingFacts;
    },
  }
}


// ================================ RENDER FUNCTIONS ================================

/// Draws world-owned asteroid, chunk, and drone facts.
pub fn renderHarvestWorld( ng : *eng.Engine ) void
{
  renderAsteroids( ng );
  renderChunks(    ng );
  renderDrones(    ng );
}

fn renderAsteroids( ng : *eng.Engine ) void
{
  for( ASTEROID_IDS )| asteroidId |
  {
    if( asteroidId == 0 ){ continue; }

    const asteroid = ng.world.getCompConst( AsteroidFact, asteroidId ) orelse continue;
    if( asteroid.depleted )
    {
      eng.wDraw.basicCirclePerim( asteroid.pos, asteroid.radius + 2.0, utl.Colour.sGray );
    }
    else
    {
      eng.wDraw.basicCircle(      asteroid.pos, asteroid.radius,       utl.Colour.sGray );
      eng.wDraw.basicCirclePerim( asteroid.pos, asteroid.radius + 2.0, utl.Colour.dGray );
    }
  }
}

fn renderChunks( ng : *eng.Engine ) void
{
  for( CHUNK_IDS )| chunkId |
  {
    if( chunkId == 0 ){ continue; }

    const chunk = ng.world.getCompConst( ChunkFact, chunkId ) orelse continue;
    const col = if( chunk.reservedBy == 0 ) utl.Colour.yellow else utl.Colour.orange;

    eng.wDraw.basicCircle(      chunk.pos, chunk.radius,       col );
    eng.wDraw.basicCirclePerim( chunk.pos, chunk.radius + 1.5, utl.Colour.nWhite );
  }
}

fn renderDrones( ng : *eng.Engine ) void
{
  for( DRONE_IDS )| droneId |
  {
    if( droneId == 0 ){ continue; }

    const drone = ng.world.getCompConst( DroneFact, droneId ) orelse continue;
    const col = getDroneColour( drone.state );

    if( drone.targetChunkId != 0 )
    {
      eng.wDraw.basicLine( drone.pos, drone.targetPos, utl.Colour.lGray, 1.0 );
    }

    eng.wDraw.basicCircle(      drone.pos, DRONE_RADIUS,       col );
    eng.wDraw.basicCirclePerim( drone.pos, DRONE_RADIUS + 1.5, utl.Colour.nWhite );
  }
}


// ================================ INSPECTION HELPERS ================================

/// Counts live harvest facts through stable Drifter entity-id lists.
pub fn getHarvestSummary( ng : *eng.Engine ) HarvestLoopResult
{
  var result : HarvestLoopResult = .{};
  fillHarvestCounts( ng, &result );
  return result;
}

pub inline fn getDroneStateText( state : DroneState ) [ :0 ] const u8
{
  return switch( state )
  {
    .idle       => "idle",
    .outbound   => "outbound",
    .harvesting => "harvesting",
    .returning  => "returning",
    .unloading  => "unloading",
    .disabled   => "disabled",
  };
}

pub inline fn getHarvestStatusText( status : HarvestLoopStatus ) [ :0 ] const u8
{
  return switch( status )
  {
    .idle               => "idle",
    .reset              => "reset restored defaults",
    .running            => "running",
    .assigned           => "drone assigned",
    .chunkCreated       => "chunk created",
    .harvested          => "chunk harvested",
    .unloaded           => "resources returned",
    .noDrones           => "blocked - no drones",
    .noIdleDrones       => "blocked - drones busy",
    .noTargets          => "blocked - no targets",
    .noStorage          => "blocked - storage full",
    .missingFacts       => "blocked - missing harvest facts",
    .stationUnavailable => "blocked - station unavailable",
  };
}

pub inline fn getHarvestStatusColour( status : HarvestLoopStatus ) utl.Colour
{
  return switch( status )
  {
    .idle, .reset, .running, .noIdleDrones => utl.Colour.lGray,
    .assigned, .chunkCreated, .harvested, .unloaded => utl.Colour.pGreen,
    else => utl.Colour.red,
  };
}


// ================================ FACT HELPERS ================================

fn makeAsteroidFact( index : usize ) AsteroidFact
{
  var pos = Vec2.new(
    randF64( @floatCast( ASTEROID_WRAP_WIDTH  ), 0.0 ),
    randF64( @floatCast( ASTEROID_WRAP_HEIGHT ), 0.0 ),
  );

  // Keep the first visual field readable around the station.
  if( pos.sub( STATION_POS ).len() < ASTEROID_SAFE_RADIUS )
  {
    pos.x += if( pos.x >= STATION_POS.x ) ASTEROID_SAFE_RADIUS else -ASTEROID_SAFE_RADIUS;
  }

  const chunkCount : u8 = switch( index % 4 )
  {
    0, 1 => 1,
    2    => 2,
    else => 3,
  };

  return .{
    .pos             = pos,
    .radius          = ASTEROID_RADIUS_MIN + (( ASTEROID_RADIUS_MAX - ASTEROID_RADIUS_MIN ) * @as( f64, @floatFromInt( chunkCount )) / 3.0 ),
    .velocity        = .new( randF64( 25.0, 125.0 ), randSignedLowBiasedF64( ASTEROID_DRIFT_Y_MAX )),
    .chunkTotal      = chunkCount,
    .chunksRemaining = chunkCount,
  };
}

fn makeChunkFact( asteroidId : eng.EntityId, asteroid : AsteroidFact, ordinal : u8 ) ChunkFact
{
  const offsetAngle = utl.Angle.newDeg( @as( f64, @floatFromInt( ordinal )) * 137.5 );
  const offset      = Vec2.fromAngle( offsetAngle ).mulVal( asteroid.radius + 20.0 );
  const sizeFactor  = @as( f64, @floatFromInt( asteroid.chunkTotal ));
  const ordinalVal  = @as( f64, @floatFromInt( ordinal ));

  return .{
    .sourceAsteroidId = asteroidId,
    .pos              = asteroid.pos.add( offset ),
    .velocity         = asteroid.velocity.mulVal( 0.7 ),
    .radius           = CHUNK_RADIUS_MIN + (( CHUNK_RADIUS_MAX - CHUNK_RADIUS_MIN ) * sizeFactor / 3.0 ),
    .cargo            =
    .{
      .regolith = 12.0 + ( sizeFactor * 3.0 ),
      .ice      = 5.0  + @mod( ordinalVal + sizeFactor, 3.0 ),
      .ore      = 4.0  + @mod( ordinalVal, 2.0 ),
    },
  };
}

fn findFreeChunkSlot() ?usize
{
  for( CHUNK_IDS, 0.. )| chunkId, index |
  {
    if( chunkId == 0 ){ return index; }
  }

  return null;
}

fn findAvailableChunk( ng : *eng.Engine ) ?eng.EntityId
{
  for( CHUNK_IDS )| chunkId |
  {
    if( chunkId == 0 ){ continue; }

    const chunk = ng.world.getCompConst( ChunkFact, chunkId ) orelse continue;
    if( chunk.reservedBy != 0 ){ continue; }
    if( station.getRawCargoTotal( chunk.cargo ) <= utl.EPS ){ continue; }

    return chunkId;
  }

  return null;
}

fn findAsteroidWithChunks( ng : *eng.Engine ) ?eng.EntityId
{
  for( ASTEROID_IDS )| asteroidId |
  {
    if( asteroidId == 0 ){ continue; }

    const asteroid = ng.world.getCompConst( AsteroidFact, asteroidId ) orelse continue;
    if( asteroid.chunksRemaining > 0 ){ return asteroidId; }
  }

  return null;
}

fn deleteChunk( ng : *eng.Engine, chunkId : eng.EntityId ) void
{
  for( &CHUNK_IDS )| *slot |
  {
    if( slot.* != chunkId ){ continue; }

    slot.* = 0;
    break;
  }

  if( ng.world.isEntityAlive( chunkId ))
  {
    if( !ng.world.destroyEntity( chunkId ))
    {
      utl.log( .ERROR, @src(), "Failed to destroy depleted Chunk Entity {d}", .{ chunkId });
    }
  }

  utl.log( .INFO, @src(), "Chunk Entity {d} depleted", .{ chunkId });
}

fn fillHarvestCounts( ng : *eng.Engine, result : *HarvestLoopResult ) void
{
  result.asteroidCount = 0;
  result.chunkCount    = 0;
  result.droneCount    = 0;
  result.idleDrones    = 0;
  result.busyDrones    = 0;

  for( ASTEROID_IDS )| asteroidId |
  {
    if( asteroidId != 0 and ng.world.hasComp( AsteroidFact, asteroidId )){ result.asteroidCount += 1; }
  }
  for( CHUNK_IDS )| chunkId |
  {
    if( chunkId != 0 and ng.world.hasComp( ChunkFact, chunkId )){ result.chunkCount += 1; }
  }
  for( DRONE_IDS )| droneId |
  {
    if( droneId == 0 ){ continue; }

    const drone = ng.world.getCompConst( DroneFact, droneId ) orelse continue;
    result.droneCount += 1;

    switch( drone.state )
    {
      .idle       => result.idleDrones += 1,
      .disabled   => {},
      else        => result.busyDrones += 1,
    }
  }
}


// ================================ DRONE HELPERS ================================

fn beginDroneState( drone : *DroneFact, state : DroneState, fromPos : Vec2, targetPos : Vec2, ticks : u16 ) void
{
  drone.state      = state;
  drone.fromPos    = fromPos;
  drone.targetPos  = targetPos;
  drone.ticksLeft  = ticks;
  drone.ticksTotal = @max( 1, ticks );

  if( state == .idle )
  {
    drone.targetChunkId = 0;
  }
}

fn tickTimedDroneMotion( drone : *DroneFact ) void
{
  tickDroneTimer( drone );

  const elapsed = drone.ticksTotal - drone.ticksLeft;
  const t = @as( f64, @floatFromInt( elapsed )) / @as( f64, @floatFromInt( drone.ticksTotal ));
  drone.pos = drone.fromPos.lerp( drone.targetPos, t );
}

fn tickDroneTimer( drone : *DroneFact ) void
{
  if( drone.ticksLeft > 0 ){ drone.ticksLeft -= 1; }
}

fn takeChunkCargo( chunk : *ChunkFact, maxCargo : f64 ) station.RawCargo
{
  const total = station.getRawCargoTotal( chunk.cargo );
  if( total <= utl.EPS ){ return .{}; }

  const ratio = @min( 1.0, maxCargo / total );
  const cargo : station.RawCargo =
  .{
    .regolith = chunk.cargo.regolith * ratio,
    .ice      = chunk.cargo.ice      * ratio,
    .ore      = chunk.cargo.ore      * ratio,
  };

  subtractRawCargo( &chunk.cargo, cargo );
  return cargo;
}

fn subtractRawCargo( target : *station.RawCargo, delta : station.RawCargo ) void
{
  target.regolith = @max( 0.0, target.regolith - delta.regolith );
  target.ice      = @max( 0.0, target.ice      - delta.ice      );
  target.ore      = @max( 0.0, target.ore      - delta.ore      );
}

fn getDroneColour( state : DroneState ) utl.Colour
{
  return switch( state )
  {
    .idle       => utl.Colour.cyan,
    .outbound   => utl.Colour.pGreen,
    .harvesting => utl.Colour.yellow,
    .returning  => utl.Colour.orange,
    .unloading  => utl.Colour.blue,
    .disabled   => utl.Colour.red,
  };
}


// ================================ RANDOM AND WRAP HELPERS ================================

fn wrapFieldPos( pos : *Vec2 ) void
{
  if( pos.x >  ASTEROID_WRAP_WIDTH  ){ pos.x = -ASTEROID_WRAP_WIDTH;  }
  if( pos.x < -ASTEROID_WRAP_WIDTH  ){ pos.x =  ASTEROID_WRAP_WIDTH;  }
  if( pos.y >  ASTEROID_WRAP_HEIGHT ){ pos.y = -ASTEROID_WRAP_HEIGHT; }
  if( pos.y < -ASTEROID_WRAP_HEIGHT ){ pos.y =  ASTEROID_WRAP_HEIGHT; }
}

inline fn randF64( scale : f32, offset : f32 ) f64
{
  return @floatCast( eng.G_ENG.rng.getScaledFloat( scale, offset ));
}

/// Returns a value in [min, max) biased toward min.
inline fn randLowBiasedF64( min : f64, max : f64 ) f64
{
  const unit = randUnitF64();
  return min + (( max - min ) * unit * unit );
}

/// Returns a signed value whose magnitude is biased toward zero.
inline fn randSignedLowBiasedF64( maxMagnitude : f64 ) f64
{
  const sign : f64 = if( eng.G_ENG.rng.getBool() ) 1.0 else -1.0;
  return sign * randLowBiasedF64( 0.0, maxMagnitude );
}

inline fn randUnitF64() f64
{
  return @floatCast( eng.G_ENG.rng.getFloat( f32 ));
}

