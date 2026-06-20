const std = @import( "std" );
const utl = @import( "utils" );

const arch = @import( "archetype.zig" );
const ent  = @import( "../entity.zig" );

const Entity   = ent.Entity;
const EntityId = ent.EntityId;


/// Builds the narrow World facade passed to data-only archetype spawn callbacks.
/// The concrete World type is supplied by `worldManager.zig` so this file can
/// live with archetype code without importing the World module directly.
pub fn ArchetypeSpawnContextFactory( comptime WorldType : type ) type
{
  return struct
  {
    const ArchetypeSpawnContext = @This();

    worldPtr             : *anyopaque,
    rollbackEntityIdsPtr : *anyopaque,
    result               : arch.ArchetypeSpawnResult = .{},

    didFail : bool = false,

    /// Creates an entity through World and tracks it for failed-spawn cleanup.
    pub fn createEntity( self : *ArchetypeSpawnContext ) Entity
    {
      const world = self.getWorld();
      const entityVal = world.createEntity();
      if( entityVal.id == 0 )
      {
        self.didFail = true;
        return .{};
      }

      self.getRollbackEntityIds().append( world.archetypeManager.alloc, entityVal.id ) catch
      {
        utl.log( .ERROR, @src(), "Failed to track Archetype-created Entity {d}", .{ entityVal.id });
        _ = world.destroyEntity( entityVal.id );
        self.didFail = true;
        return .{};
      };

      return entityVal;
    }

    /// Marks the primary entity id returned by the spawn result.
    pub inline fn setRootEntity( self : *ArchetypeSpawnContext, entityVal : Entity ) bool
    {
      return self.recordResultStatus( self.result.setRoot( entityVal.id ));
    }

    /// Adds a named entity id to the spawn result.
    pub inline fn reportEntity( self : *ArchetypeSpawnContext, name : []const u8, entityVal : Entity ) bool
    {
      return self.recordResultStatus( self.result.reportId( name, entityVal.id ));
    }

    /// Attaches one component payload to a live archetype-created entity.
    pub inline fn addComp( self : *ArchetypeSpawnContext, comptime CompType : type, entityVal : Entity, value : CompType ) bool
    {
      return self.recordFactStatus( self.getWorld().addComp( CompType, entityVal.id, value ));
    }

    /// Adds one source-target relation fact between live entities.
    pub inline fn addRelation( self : *ArchetypeSpawnContext, comptime RelType : type, sourceVal : Entity, targetVal : Entity, value : RelType ) bool
    {
      return self.recordFactStatus( self.getWorld().addRelation( RelType, sourceVal.id, targetVal.id, value ));
    }

    /// Applies one dataless trait to a live archetype-created entity.
    pub inline fn applyTrait( self : *ArchetypeSpawnContext, comptime TraitType : type, entityVal : Entity ) bool
    {
      return self.recordFactStatus( self.getWorld().applyTrait( TraitType, entityVal.id ));
    }

    inline fn getWorld( self : *ArchetypeSpawnContext ) *WorldType
    {
      return @ptrCast( @alignCast( self.worldPtr ));
    }

    inline fn getRollbackEntityIds( self : *ArchetypeSpawnContext ) *std.ArrayList( EntityId )
    {
      return @ptrCast( @alignCast( self.rollbackEntityIdsPtr ));
    }

    inline fn recordResultStatus( self : *ArchetypeSpawnContext, didSucceed : bool ) bool
    {
      if( didSucceed ){ return true; }

      self.didFail = true;
      return false;
    }

    inline fn recordFactStatus( self : *ArchetypeSpawnContext, didSucceed : bool ) bool
    {
      if( didSucceed ){ return true; }

      self.didFail = true;
      return false;
    }
  };
}
