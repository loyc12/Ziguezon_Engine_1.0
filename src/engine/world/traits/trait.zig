const std = @import( "std" );
const utl = @import( "utils" );

const entity = @import( "../entity.zig" );

const EntityId = entity.EntityId;


/// Summary of removing one entity id from one or more trait sets.
/// Missing rows are normal when an entity does not have every registered trait.
pub const TraitCleanupResult = struct
{
  removedCount : usize = 0,
  missingCount : usize = 0,
  failedCount  : usize = 0,

  pub inline fn isSuccess( self : TraitCleanupResult ) bool
  {
    return self.failedCount == 0;
  }
};

/// Generic dataless trait for future save/load-relevant entities and their facts.
pub const Persistent = struct {};


/// Enforces the current trait declaration shape.
/// Traits are zero-sized struct declarations; per-entity data belongs in components.
pub fn assertTraitDecl( comptime TraitType : type ) void
{
  const info = switch( @typeInfo( TraitType ))
  {
    .@"struct" => | structInfo | structInfo,
    else       => @compileError( "Trait type " ++ @typeName( TraitType ) ++ " must be a zero-sized struct declaration." ),
  };

  if( info.fields.len != 0 or @sizeOf( TraitType ) != 0 )
  {
    @compileError( "Trait type " ++ @typeName( TraitType ) ++ " carries fields or payload data. Use components for per-entity data and traits for dataless classification." );
  }
}

/// Returns true when a type is usable as a dataless trait declaration.
pub inline fn isDatalessTrait( comptime TraitType : type ) bool
{
  assertTraitDecl( TraitType );
  return true;
}


// ================================ TRAIT SET FUNCTIONS ================================

/// Builds presence-only storage for one trait type.
/// Rows are keyed by entity id and carry no per-entity payload.
pub fn TraitSetFactory( comptime TraitType : type ) type
{
  assertTraitDecl( TraitType );

  return struct
  {
    const TypeName = @typeName( TraitType );
    const Set      = @This();

    alloc    : std.mem.Allocator              = undefined,
    entities : std.AutoHashMap( EntityId, void ) = undefined,

    isInit : bool = false,


    // ================================ LIFECYCLE FUNCTIONS ================================

    /// Initializes trait presence storage.
    pub fn init( self : *Set, alloc : std.mem.Allocator ) void
    {
      if( self.isInit )
      {
        utl.log( .WARN, @src(), "TraitSet for type {s} is already initialized : returning", .{ TypeName });
        return;
      }

      self.alloc    = alloc;
      self.entities = .init( alloc );
      self.isInit   = true;
    }

    /// Releases all trait rows.
    pub fn deinit( self : *Set ) void
    {
      if( !self.isInit )
      {
        utl.log( .WARN, @src(), "TraitSet for type {s} is uninitialized : returning", .{ TypeName });
        return;
      }

      self.entities.deinit();
      self.isInit = false;
    }


    // ================================ ROW FUNCTIONS ================================

    /// Applies this trait to one entity id.
    /// `World.applyTrait` should be preferred because it checks entity liveness first.
    pub fn apply( self : *Set, entityId : EntityId ) bool
    {
      if( !self.isInit )
      {
        utl.log( .WARN, @src(), "Cannot apply trait type {s} to Entity {d} : uninitialized", .{ TypeName, entityId });
        return false;
      }
      if( entityId == 0 )
      {
        utl.log( .DEBUG, @src(), "Cannot apply trait type {s} to Entity 0", .{ TypeName });
        return false;
      }
      if( self.entities.contains( entityId ))
      {
        utl.log( .WARN, @src(), "Cannot apply trait type {s} to Entity {d} : trait already present", .{ TypeName, entityId });
        return false;
      }

      self.entities.put( entityId, {} ) catch
      {
        utl.log( .ERROR, @src(), "Failed to apply trait type {s} to Entity {d}", .{ TypeName, entityId });
        return false;
      };

      return true;
    }

    /// Removes this trait from one entity id.
    pub fn remove( self : *Set, entityId : EntityId ) bool
    {
      if( !self.isInit )
      {
        utl.log( .WARN, @src(), "Cannot remove trait type {s} from Entity {d} : uninitialized", .{ TypeName, entityId });
        return false;
      }
      if( !self.entities.remove( entityId ))
      {
        utl.log( .DEBUG, @src(), "Cannot remove trait type {s} from Entity {d} : trait not present", .{ TypeName, entityId });
        return false;
      }

      return true;
    }

    /// Returns true when this entity id has the trait.
    pub fn has( self : *Set, entityId : EntityId ) bool
    {
      if( !self.isInit )
      {
        utl.log( .WARN, @src(), "Cannot inspect TraitSet for type {s} : uninitialized", .{ TypeName });
        return false;
      }

      return self.entities.contains( entityId );
    }

    /// Removes this trait from one entity during World destruction cleanup.
    pub fn removeEntity( self : *Set, entityId : EntityId ) TraitCleanupResult
    {
      var result : TraitCleanupResult = .{};

      if( !self.isInit )
      {
        utl.log( .WARN, @src(), "Cannot remove Entity {d} from TraitSet for type {s} : uninitialized", .{ entityId, TypeName });
        result.failedCount = 1;
        return result;
      }

      if( !self.entities.contains( entityId ))
      {
        result.missingCount = 1;
        return result;
      }
      if( self.remove( entityId )){ result.removedCount = 1; }
      else
      {
        utl.log( .ERROR, @src(), "Failed to remove Entity {d} from TraitSet for type {s}", .{ entityId, TypeName });
        result.failedCount = 1;
      }

      return result;
    }
  };
}


// ================================ TESTS ================================

test "TraitSet applies removes and queries dataless traits"
{
  const Selectable = struct {};

  var set : TraitSetFactory( Selectable ) = .{};
  set.init( std.testing.allocator );
  defer set.deinit();

  try std.testing.expect(  set.apply( 1 ));
  try std.testing.expect( !set.apply( 1 ));
  try std.testing.expect(  set.has(   1 ));
  try std.testing.expect( !set.has(   2 ));
  try std.testing.expect(  set.remove( 1 ));
  try std.testing.expect( !set.has(   1 ));
  try std.testing.expect( !set.remove( 1 ));
}

test "TraitSet cleanup removes one entity and tolerates missing rows"
{
  const Selectable = struct {};

  var set : TraitSetFactory( Selectable ) = .{};
  set.init( std.testing.allocator );
  defer set.deinit();

  try std.testing.expect( set.apply( 1 ));
  try std.testing.expect( set.apply( 2 ));

  const removed = set.removeEntity( 1 );
  try std.testing.expect( removed.isSuccess() );
  try std.testing.expect( removed.removedCount == 1 );
  try std.testing.expect( removed.missingCount == 0 );
  try std.testing.expect( !set.has( 1 ));
  try std.testing.expect(  set.has( 2 ));

  const missing = set.removeEntity( 99 );
  try std.testing.expect( missing.isSuccess() );
  try std.testing.expect( missing.removedCount == 0 );
  try std.testing.expect( missing.missingCount == 1 );
}

test "Persistent is a valid generic dataless trait"
{
  try std.testing.expect( isDatalessTrait( Persistent ));
}
