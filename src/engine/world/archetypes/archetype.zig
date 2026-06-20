const std = @import( "std" );
const ent = @import( "../entity.zig" );

const EntityId = ent.EntityId;


/// Maximum number of named ids an archetype spawn can report directly.
/// Keep this small; larger domain-specific lookup tables belong in game state.
pub const MAX_REPORTED_SPAWN_IDS : usize = 16;


/// Named entity id returned by an archetype spawn.
/// Names are caller-facing labels such as "root", "child", or "socket".
pub const ArchetypeReportedId = struct
{
  name : []const u8 = "",
  id   : EntityId   = 0,
};


/// Result returned after a successful archetype spawn.
/// `rootId` is the primary entity; `reportedIds` are optional extra stable ids.
pub const ArchetypeSpawnResult = struct
{
  rootId      : EntityId = 0,
  reportedIds : [ MAX_REPORTED_SPAWN_IDS ]ArchetypeReportedId = undefined,
  idCount     : usize    = 0,

  /// Stores the primary entity id for this spawn.
  pub inline fn setRoot( self : *ArchetypeSpawnResult, entityId : EntityId ) bool
  {
    if( entityId == 0 ){ return false; }

    self.rootId = entityId;
    return true;
  }

  /// Adds a named id to the bounded result list.
  pub inline fn reportId( self : *ArchetypeSpawnResult, name : []const u8, entityId : EntityId ) bool
  {
    if( name.len == 0 or entityId == 0 ){ return false; }
    if( self.idCount >= self.reportedIds.len ){ return false; }

    self.reportedIds[ self.idCount ] = .{ .name = name, .id = entityId };
    self.idCount += 1;
    return true;
  }

  /// Returns a reported id by label, or null when the archetype did not expose it.
  pub inline fn getReportedId( self : *const ArchetypeSpawnResult, name : []const u8 ) ?EntityId
  {
    for( self.reportedIds[ 0..self.idCount ] )| entry |
    {
      if( std.mem.eql( u8, entry.name, name )){ return entry.id; }
    }

    return null;
  }
};


/// Builds the concrete archetype declaration type for a World spawn context.
/// Archetypes are data-only initial fact declarations: callbacks may create
/// entities, attach components, add relations, and apply traits through the
/// supplied context, but must not enqueue commands or register executable logic.
pub fn ArchetypeFactory( comptime SpawnContextType : type ) type
{
  return struct
  {
    /// Stable registration key. Use namespaced names for game archetypes.
    name    : []const u8,
    spawnFn : *const fn ( *SpawnContextType ) bool,
  };
}
