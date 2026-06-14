const std = @import( "std" );
const utl = @import( "utils" );
const trt = @import( "trait.zig" );
const ent = @import( "../entity.zig" );

const EntityId           = ent.EntityId;
const TraitCleanupResult = trt.TraitCleanupResult;
const TraitSetFactory    = trt.TraitSetFactory;


/// Owns typed trait sets registered for a World.
/// Game code normally uses the `World.*Trait` wrappers.
pub const TraitManager = struct
{
  const SetEntry = struct
  {
    setPtr          : *anyopaque,
    deinitDestroyFn : *const fn ( std.mem.Allocator, *anyopaque ) void,
    removeEntityFn  : *const fn ( *anyopaque, EntityId ) TraitCleanupResult,
  };

  alloc : std.mem.Allocator             = undefined,
  sets  : std.StringHashMap( SetEntry ) = undefined,

  isInit : bool = false,


  // ================================ LIFECYCLE FUNCTIONS ================================

  /// Initializes the trait-set registry.
  pub fn init( self : *TraitManager, alloc : std.mem.Allocator ) void
  {
    if( self.isInit )
    {
      utl.qlog( .WARN, @src(), "TraitManager is already initialized : returning" );
      return;
    }

    self.alloc  = alloc;
    self.sets   = .init( alloc );
    self.isInit = true;
  }

  /// Deinitializes and destroys every registered trait set.
  pub fn deinit( self : *TraitManager ) void
  {
    if( !self.isInit )
    {
      utl.qlog( .WARN, @src(), "TraitManager is uninitialized : returning" );
      return;
    }

    var iter = self.sets.valueIterator();
    while( iter.next() )| entry |{ entry.deinitDestroyFn( self.alloc, entry.setPtr ); }

    self.sets.deinit();
    self.isInit = false;
  }


  // ================================ SET FUNCTIONS ================================

  /// Registers presence storage for one dataless trait type.
  pub fn register( self : *TraitManager, comptime TraitType : type ) bool
  {
    const typeName = @typeName( TraitType );

    if( !self.isInit )
    {
      utl.log( .WARN, @src(), "Cannot register TraitSet for type {s} : TraitManager is uninitialized", .{ typeName });
      return false;
    }
    if( self.sets.contains( typeName ))
    {
      utl.log( .WARN, @src(), "Cannot register TraitSet for type {s} : type already registered", .{ typeName });
      return false;
    }

    const SetType = TraitSetFactory( TraitType );
    const set = self.alloc.create( SetType ) catch
    {
      utl.log( .ERROR, @src(), "Failed to allocate TraitSet for type {s}", .{ typeName });
      return false;
    };

    set.* = .{};
    set.init( self.alloc );

    self.sets.put( typeName,
    .{
      .setPtr          = set,
      .deinitDestroyFn = deinitDestroySet( TraitType ),
      .removeEntityFn  = removeEntityFromSet( TraitType ),
    })
    catch
    {
      utl.log( .ERROR, @src(), "Failed to register TraitSet for type {s}", .{ typeName });

      set.deinit();
      self.alloc.destroy( set );
      return false;
    };

    return true;
  }

  /// Removes storage for one trait type and drops all rows in that set.
  pub fn unregister( self : *TraitManager, comptime TraitType : type ) bool
  {
    const typeName = @typeName( TraitType );

    if( !self.isInit )
    {
      utl.log( .WARN, @src(), "Cannot unregister TraitSet for type {s} : TraitManager is uninitialized", .{ typeName });
      return false;
    }

    const entry = self.sets.get( typeName ) orelse
    {
      utl.log( .DEBUG, @src(), "Cannot unregister TraitSet for type {s} : type not registered", .{ typeName });
      return false;
    };

    if( !self.sets.remove( typeName )){ return false; }
    entry.deinitDestroyFn( self.alloc, entry.setPtr );
    return true;
  }

  /// Returns the typed trait set pointer for one trait type.
  pub fn getSet( self : *TraitManager, comptime TraitType : type ) ?*TraitSetFactory( TraitType )
  {
    const typeName = @typeName( TraitType );

    if( !self.isInit )
    {
      utl.log( .WARN, @src(), "Cannot get TraitSet for type {s} : TraitManager is uninitialized", .{ typeName });
      return null;
    }

    const entry = self.sets.get( typeName ) orelse return null;
    return @ptrCast( @alignCast( entry.setPtr ));
  }

  /// Removes an entity id from every registered trait set.
  /// Used by `World.destroyEntity` before the entity id is invalidated.
  pub fn removeEntity( self : *TraitManager, entityId : EntityId ) TraitCleanupResult
  {
    var result : TraitCleanupResult = .{};

    if( !self.isInit )
    {
      utl.log( .WARN, @src(), "Cannot remove Entity {d} from TraitSets : TraitManager is uninitialized", .{ entityId });
      result.failedCount = 1;
      return result;
    }

    var iter = self.sets.valueIterator();
    while( iter.next() )| entry |
    {
      const cleanup = entry.removeEntityFn( entry.setPtr, entityId );

      result.removedCount += cleanup.removedCount;
      result.missingCount += cleanup.missingCount;
      result.failedCount  += cleanup.failedCount;
    }

    return result;
  }


  // ================================ INTERNAL FUNCTIONS ================================

  fn deinitDestroySet( comptime TraitType : type ) *const fn ( std.mem.Allocator, *anyopaque ) void
  {
    return struct
    {
      fn call( alloc : std.mem.Allocator, setPtr : *anyopaque ) void
      {
        const set : *TraitSetFactory( TraitType ) = @ptrCast( @alignCast( setPtr ));

        set.deinit();
        alloc.destroy( set );
      }
    }.call;
  }

  fn removeEntityFromSet( comptime TraitType : type ) *const fn ( *anyopaque, EntityId ) TraitCleanupResult
  {
    return struct
    {
      fn call( setPtr : *anyopaque, entityId : EntityId ) TraitCleanupResult
      {
        const set : *TraitSetFactory( TraitType ) = @ptrCast( @alignCast( setPtr ));
        return set.removeEntity( entityId );
      }
    }.call;
  }
};


// ================================ TESTS ================================

test "TraitManager owns typed set registration and lifecycle"
{
  const Selectable = struct {};

  var manager : TraitManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  try std.testing.expect(  manager.register( Selectable ));
  try std.testing.expect( !manager.register( Selectable ));

  const set = manager.getSet( Selectable ).?;
  try std.testing.expect( set.apply( 1 ));
  try std.testing.expect( set.has(   1 ));

  try std.testing.expect( manager.unregister( Selectable ));
  try std.testing.expect( manager.getSet( Selectable ) == null );
  try std.testing.expect( manager.register( Selectable ));
}

test "TraitManager deinit releases registered trait sets"
{
  const Selectable = struct {};

  var manager : TraitManager = .{};
  manager.init( std.testing.allocator );

  try std.testing.expect( manager.register( Selectable ));
  try std.testing.expect( manager.getSet( Selectable ).?.apply( 1 ));

  manager.deinit();
  try std.testing.expect( !manager.isInit );
}

test "TraitManager removes an entity from every registered set"
{
  const TraitA = struct {};
  const TraitB = struct {};

  var manager : TraitManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  try std.testing.expect( manager.register( TraitA ));
  try std.testing.expect( manager.register( TraitB ));

  const setA = manager.getSet( TraitA ).?;
  const setB = manager.getSet( TraitB ).?;

  try std.testing.expect( setA.apply( 1 ));
  try std.testing.expect( setB.apply( 1 ));
  try std.testing.expect( setB.apply( 2 ));

  const cleanup = manager.removeEntity( 1 );
  try std.testing.expect( cleanup.isSuccess() );
  try std.testing.expect( cleanup.removedCount == 2 );
  try std.testing.expect( cleanup.missingCount == 0 );

  try std.testing.expect( !setA.has( 1 ));
  try std.testing.expect( !setB.has( 1 ));
  try std.testing.expect(  setB.has( 2 ));
}

test "TraitManager entity cleanup tolerates missing trait rows"
{
  const TraitA = struct {};
  const TraitB = struct {};

  var manager : TraitManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  try std.testing.expect( manager.register( TraitA ));
  try std.testing.expect( manager.register( TraitB ));

  const cleanup = manager.removeEntity( 99 );
  try std.testing.expect( cleanup.isSuccess() );
  try std.testing.expect( cleanup.removedCount == 0 );
  try std.testing.expect( cleanup.missingCount == 2 );
}
