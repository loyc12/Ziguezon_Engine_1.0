// REWORK NOTE : Expand this into the World-owned entity identity and lifecycle
// foundation. Entities should remain lightweight identifiers while World tracks
// creation, validity, destruction, and the cleanup/invalidation of associated
// components, relations, events, and other simulation facts.

const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );


/// Stable runtime identifier for a World entity.
/// `0` is reserved as "no entity" / invalid and is never assigned by World.
pub const EntityId  = u64;
pub const EntityGen = u32;

/// Lightweight entity handle returned by `World.createEntity`.
/// Store this id in game data when you need to refer back to World-owned facts.
pub const Entity = struct
{
  id   : EntityId  = 0, // uuid of this entity
//gen  : EntityGen = 0, // generation this entity was querried form
//mask : utl.Bfd64 = NA, // TODO : use this to store multiple booleans compactly ( is alive, isActive, etc )
};



// ================ ENTITY ID REGISTRY ================

pub const EntityIdRegistry = struct
{
  maxId : EntityId = 0, // NOTE : Id 0 is never attributed

//var freedIds : std.ArrayList( EntityId ) = undefined;

  /// Resets id allocation back to the first valid id.
  /// Called when a World is initialized or deinitialized.
  pub inline fn reinit( self : *EntityIdRegistry ) void
  {
    self.maxId = 0;
    // Clear freedIds here
  }

  pub inline fn getMaxId( self : *const EntityIdRegistry ) EntityId
  {
    return self.maxId;
  }

  inline fn getNewId( self : *EntityIdRegistry ) EntityId
  {
    self.maxId += 1;
    return self.maxId;
  }

  /// Allocates a new entity handle without attaching any components or facts.
  /// Use `World.createEntity` instead of calling this directly from games.
  pub inline fn getNewEntity( self : *EntityIdRegistry ) Entity
  {
    return .{ .id = self.getNewId() };
  }
};
