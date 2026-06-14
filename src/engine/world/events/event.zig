const std = @import( "std" );

const entity = @import( "../entity.zig" );

pub const EntityId = entity.EntityId;


/// Metadata attached by the event queue/manager when an event is recorded.
/// Game event payloads stay plain structs; this wrapper records ordering and tick context.
pub const EventMeta = struct
{
  /// Monotonic order across all events emitted through one EventManager.
  sequence      : u64       = 0,
  /// Order within the current World tick; reset by `World.tick`.
  tickOrder     : u64       = 0,
  /// Engine base tick active when the event was emitted, if known.
  baseTickIndex : ?u128     = null,
  /// Best-effort entity id for quick inspection/filtering.
  primaryEntity : ?EntityId = null,
};

/// Typed event record stored in queues.
/// `EventType` is a user-defined plain Zig struct, not an engine enum value.
pub fn EventRecord( comptime EventType : type ) type
{
  assertEventPayloadType( EventType );

  return struct
  {
    meta  : EventMeta = .{},
    value : EventType,
  };
}

/// Rejects event payload shapes that cannot act as plain queued facts.
/// Dataless structs are valid so presence-style event facts remain possible.
pub fn assertEventPayloadType( comptime EventType : type ) void
{
  switch( @typeInfo( EventType ))
  {
    .@"struct" => {},
    else       => @compileError( "Event type " ++ @typeName( EventType ) ++ " must be a plain struct payload. Dataless structs are valid event facts." ),
  }
}

/// Generic engine event emitted after an entity id becomes live.
pub const EntityCreated = struct
{
  entityId : EntityId = 0,
};

/// Generic engine event emitted after an entity has been removed from World.
pub const EntityDestroyed = struct
{
  entityId : EntityId = 0,
};

/// Generic engine event emitted after a component row is added.
pub const ComponentAdded = struct
{
  entityId     : EntityId   = 0,
  compTypeName : []const u8 = "",
};

/// Generic engine event emitted after a component row is removed.
pub const ComponentRemoved = struct
{
  entityId     : EntityId   = 0,
  compTypeName : []const u8 = "",
};

/// Generic engine event emitted after a relation row is added.
pub const RelationAdded = struct
{
  sourceId         : EntityId   = 0,
  targetId         : EntityId   = 0,
  relationTypeName : []const u8 = "",
};

/// Generic engine event emitted after a relation row is removed.
pub const RelationRemoved = struct
{
  sourceId         : EntityId   = 0,
  targetId         : EntityId   = 0,
  relationTypeName : []const u8 = "",
};

/// Generic engine event emitted after a trait is applied.
pub const TraitApplied = struct
{
  entityId      : EntityId   = 0,
  traitTypeName : []const u8 = "",
};

/// Generic engine event emitted after a trait is removed.
pub const TraitRemoved = struct
{
  entityId      : EntityId   = 0,
  traitTypeName : []const u8 = "",
};

/// Infers a primary entity id from common field names in plain event structs.
/// Events without `entityId`, `sourceId`, or `targetId` simply return null.
pub fn inferPrimaryEntity( comptime EventType : type, value : EventType ) ?EntityId
{
  assertEventPayloadType( EventType );

  if( @hasField( EventType, "entityId" )){ return value.entityId; }
  if( @hasField( EventType, "sourceId" )){ return value.sourceId; }
  if( @hasField( EventType, "targetId" )){ return value.targetId; }

  return null;
}


// ================================ TESTS ================================

test "EventRecord stores metadata and plain event payload"
{
  const record = EventRecord( EntityCreated )
  {
    .meta  = .{ .sequence = 7, .tickOrder = 2, .baseTickIndex = 11, .primaryEntity = 42 },
    .value = .{ .entityId = 42 },
  };

  try std.testing.expect( record.meta.sequence      == 7  );
  try std.testing.expect( record.meta.tickOrder     == 2  );
  try std.testing.expect( record.meta.baseTickIndex.? == 11 );
  try std.testing.expect( record.meta.primaryEntity.? == 42 );
  try std.testing.expect( record.value.entityId     == 42 );
}

test "Event concepts allow dataless event facts"
{
  const Dataless = struct {};
  const record = EventRecord( Dataless )
  {
    .meta  = .{ .sequence = 1 },
    .value = .{},
  };

  try std.testing.expect( record.meta.sequence == 1 );
}

test "inferPrimaryEntity reads generic entity fields"
{
  try std.testing.expect( inferPrimaryEntity( EntityCreated,   .{ .entityId = 4 }) == 4 );
  try std.testing.expect( inferPrimaryEntity( RelationAdded,   .{ .sourceId = 5, .targetId = 6 }) == 5 );
  try std.testing.expect( inferPrimaryEntity( struct {},       .{} ) == null );
}
