const std = @import( "std" );
const utl = @import( "utils" );
const rel = @import( "relation.zig" );
const ent = @import( "../entity.zig" );

const EntityId              = ent.EntityId;
const RelationCleanupResult = rel.RelationCleanupResult;
const RelationStoreFactory  = rel.RelationStoreFactory;


/// Owns typed relation stores registered for a World.
/// Game code normally uses the `World.*Relation` wrappers.
pub const RelationManager = struct
{
  const StoreEntry = struct
  {
    storePtr        : *anyopaque,
    deinitDestroyFn : *const fn ( std.mem.Allocator, *anyopaque ) void,
    removeEntityFn  : *const fn ( *anyopaque, EntityId ) RelationCleanupResult,
  };

  alloc  : std.mem.Allocator               = undefined,
  stores : std.StringHashMap( StoreEntry ) = undefined,

  isInit : bool = false,


  // ================================ LIFECYCLE FUNCTIONS ================================

  /// Initializes the relation-store registry.
  pub fn init( self : *RelationManager, alloc : std.mem.Allocator ) void
  {
    if( self.isInit )
    {
      utl.qlog( .WARN, 0, @src(), "RelationManager is already initialized : returning" );
      return;
    }

    self.alloc  = alloc;
    self.stores = .init( alloc );
    self.isInit = true;
  }

  /// Deinitializes and destroys every registered relation store.
  pub fn deinit( self : *RelationManager ) void
  {
    if( !self.isInit )
    {
      utl.qlog( .WARN, 0, @src(), "RelationManager is uninitialized : returning" );
      return;
    }

    var iter = self.stores.valueIterator();
    while( iter.next() )| entry |{ entry.deinitDestroyFn( self.alloc, entry.storePtr ); }

    self.stores.deinit();
    self.isInit = false;
  }


  // ================================ STORE FUNCTIONS ================================

  /// Registers storage for one relation fact type.
  pub fn register( self : *RelationManager, comptime RelType : type ) bool
  {
    const typeName = @typeName( RelType );

    if( !self.isInit )
    {
      utl.log( .WARN, 0, @src(), "Cannot register RelationStore for type {s} : RelationManager is uninitialized", .{ typeName });
      return false;
    }
    if( self.stores.contains( typeName ))
    {
      utl.log( .WARN, 0, @src(), "Cannot register RelationStore for type {s} : type already registered", .{ typeName });
      return false;
    }

    const StoreType = RelationStoreFactory( RelType );
    const store = self.alloc.create( StoreType ) catch
    {
      utl.log( .ERROR, 0, @src(), "Failed to allocate RelationStore for type {s}", .{ typeName });
      return false;
    };

    store.* = .{};
    store.init( self.alloc );

    self.stores.put( typeName,
    .{
      .storePtr        = store,
      .deinitDestroyFn = deinitDestroyStore( RelType ),
      .removeEntityFn  = removeEntityFromStore( RelType ),
    })
    catch
    {
      utl.log( .ERROR, 0, @src(), "Failed to register RelationStore for type {s}", .{ typeName });

      store.deinit();
      self.alloc.destroy( store );
      return false;
    };

    return true;
  }

  /// Removes storage for one relation type and drops all rows in that store.
  pub fn unregister( self : *RelationManager, comptime RelType : type ) bool
  {
    const typeName = @typeName( RelType );

    if( !self.isInit )
    {
      utl.log( .WARN, 0, @src(), "Cannot unregister RelationStore for type {s} : RelationManager is uninitialized", .{ typeName });
      return false;
    }

    const entry = self.stores.get( typeName ) orelse
    {
      utl.log( .DEBUG, 0, @src(), "Cannot unregister RelationStore for type {s} : type not registered", .{ typeName });
      return false;
    };

    if( !self.stores.remove( typeName )){ return false; }
    entry.deinitDestroyFn( self.alloc, entry.storePtr );
    return true;
  }

  /// Returns the typed store pointer for one relation type.
  pub fn getStore( self : *RelationManager, comptime RelType : type ) ?*RelationStoreFactory( RelType )
  {
    const typeName = @typeName( RelType );

    if( !self.isInit )
    {
      utl.log( .WARN, 0, @src(), "Cannot get RelationStore for type {s} : RelationManager is uninitialized", .{ typeName });
      return null;
    }

    const entry = self.stores.get( typeName ) orelse return null;
    return @ptrCast( @alignCast( entry.storePtr ));
  }

  /// Removes an entity id from every registered relation store.
  /// Used by `World.destroyEntity` before component cleanup.
  pub fn removeEntity( self : *RelationManager, entityId : EntityId ) RelationCleanupResult
  {
    var result : RelationCleanupResult = .{};

    if( !self.isInit )
    {
      utl.log( .WARN, 0, @src(), "Cannot remove Entity {d} from RelationStores : RelationManager is uninitialized", .{ entityId });
      result.failedCount = 1;
      return result;
    }

    var iter = self.stores.valueIterator();
    while( iter.next() )| entry |
    {
      const cleanup = entry.removeEntityFn( entry.storePtr, entityId );

      result.removedCount += cleanup.removedCount;
      result.missingCount += cleanup.missingCount;
      result.failedCount  += cleanup.failedCount;
    }

    return result;
  }


  // ================================ INTERNAL FUNCTIONS ================================

  fn deinitDestroyStore( comptime RelType : type ) *const fn ( std.mem.Allocator, *anyopaque ) void
  {
    return struct
    {
      fn call( alloc : std.mem.Allocator, storePtr : *anyopaque ) void
      {
        const store : *RelationStoreFactory( RelType ) = @ptrCast( @alignCast( storePtr ));

        store.deinit();
        alloc.destroy( store );
      }
    }.call;
  }

  fn removeEntityFromStore( comptime RelType : type ) *const fn ( *anyopaque, EntityId ) RelationCleanupResult
  {
    return struct
    {
      fn call( storePtr : *anyopaque, entityId : EntityId ) RelationCleanupResult
      {
        const store : *RelationStoreFactory( RelType ) = @ptrCast( @alignCast( storePtr ));
        return store.removeEntity( entityId );
      }
    }.call;
  }
};


// ================================ TESTS ================================

test "RelationManager owns typed store registration and lifecycle"
{
  const TestRel = struct
  {
    value : u32 = 0,
  };

  var manager : RelationManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  try std.testing.expect(  manager.register( TestRel ));
  try std.testing.expect( !manager.register( TestRel ));

  const store = manager.getStore( TestRel ).?;
  try std.testing.expect( store.add( 1, 2, .{ .value = 42 }));
  try std.testing.expect( store.get( 1, 2 ).?.value == 42 );

  try std.testing.expect(  manager.unregister( TestRel ));
  try std.testing.expect(  manager.getStore( TestRel ) == null );
  try std.testing.expect(  manager.register( TestRel ));
}

test "RelationManager deinit releases registered relation stores"
{
  const TestRel = struct
  {
    value : u32 = 0,
  };

  var manager : RelationManager = .{};
  manager.init( std.testing.allocator );

  try std.testing.expect( manager.register( TestRel ));
  try std.testing.expect( manager.getStore( TestRel ).?.add( 1, 2, .{ .value = 42 }));

  manager.deinit();
  try std.testing.expect( !manager.isInit );
}

test "RelationManager removes an entity from every registered store"
{
  const RelA = struct
  {
    value : u32 = 0,
  };
  const RelB = struct
  {
    value : u32 = 0,
  };

  var manager : RelationManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  try std.testing.expect( manager.register( RelA ));
  try std.testing.expect( manager.register( RelB ));

  const storeA = manager.getStore( RelA ).?;
  const storeB = manager.getStore( RelB ).?;

  try std.testing.expect( storeA.add( 1, 2, .{ .value = 10 }));
  try std.testing.expect( storeA.add( 3, 1, .{ .value = 20 }));
  try std.testing.expect( storeB.add( 1, 4, .{ .value = 30 }));
  try std.testing.expect( storeB.add( 5, 6, .{ .value = 40 }));

  const cleanup = manager.removeEntity( 1 );
  try std.testing.expect( cleanup.isSuccess() );
  try std.testing.expect( cleanup.removedCount == 3 );
  try std.testing.expect( cleanup.missingCount == 0 );

  try std.testing.expect( !storeA.has( 1, 2 ));
  try std.testing.expect( !storeA.has( 3, 1 ));
  try std.testing.expect( !storeB.has( 1, 4 ));
  try std.testing.expect(  storeB.has( 5, 6 ));
}

test "RelationManager entity cleanup tolerates missing relation rows"
{
  const RelA = struct
  {
    value : u32 = 0,
  };
  const RelB = struct
  {
    value : u32 = 0,
  };

  var manager : RelationManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  try std.testing.expect( manager.register( RelA ));
  try std.testing.expect( manager.register( RelB ));

  const cleanup = manager.removeEntity( 99 );
  try std.testing.expect( cleanup.isSuccess() );
  try std.testing.expect( cleanup.removedCount == 0 );
  try std.testing.expect( cleanup.missingCount == 2 );
}
