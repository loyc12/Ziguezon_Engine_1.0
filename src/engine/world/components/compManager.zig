const std  = @import( "std" );
const utl  = @import( "utils" );
const comp = @import( "component.zig" );
const ent  = @import( "../entity.zig" );

const CompStoreFactory = comp.CompStoreFactory;
const CompStorePolicy  = comp.CompStorePolicy;
const EntityId         = ent.EntityId;


/// Summary of removing one entity id from all registered component stores.
/// Missing rows are normal when an entity does not have every component type.
pub const EntityCleanupResult = struct
{
  removedCount : usize = 0,
  missingCount : usize = 0,
  failedCount  : usize = 0,

  pub inline fn isSuccess( self : EntityCleanupResult ) bool
  {
    return self.failedCount == 0;
  }
};


/// Owns the typed component stores registered for a World.
/// Game code usually reaches this through `World.registerComp` and friends.
pub const CompManager = struct
{
  const StoreEntityCleanupResult = enum
  {
    REMOVED,
    MISSING,
    FAILED,
  };

  const StoreEntry = struct
  {
    storePtr        : *anyopaque,
    deinitDestroyFn : *const fn ( std.mem.Allocator, *anyopaque ) void,
    removeEntityFn  : *const fn ( *anyopaque, EntityId ) StoreEntityCleanupResult,
  };

  alloc  : std.mem.Allocator                    = undefined,
  stores : std.StringHashMap( StoreEntry ) = undefined,

  isInit : bool = false,


  // ================================ LIFECYCLE FUNCTIONS ================================

  /// Initializes the component-store registry.
  pub fn init( self : *CompManager, alloc : std.mem.Allocator ) void
  {
    if( self.isInit )
    {
      utl.qlog( .WARN, @src(), "CompManager is already initialized : returning" );
      return;
    }

    self.alloc  = alloc;
    self.stores = .init( alloc );
    self.isInit = true;
  }

  /// Deinitializes and destroys every registered component store.
  pub fn deinit( self : *CompManager ) void
  {
    if( !self.isInit )
    {
      utl.qlog( .WARN, @src(), "CompManager is uninitialized : returning" );
      return;
    }

    var iter = self.stores.valueIterator();
    while( iter.next() )| entry |{ entry.deinitDestroyFn( self.alloc, entry.storePtr ); }

    self.stores.deinit();
    self.isInit = false;
  }


  // ================================ STORE FUNCTIONS ================================

  /// Registers storage for one component payload type.
  pub fn register( self : *CompManager, comptime CompType : type ) bool
  {
    const typeName = @typeName( CompType );

    if( !self.isInit )
    {
      utl.log( .WARN, @src(), "Cannot register CompStore for type {s} : CompManager is uninitialized", .{ typeName });
      return false;
    }
    if( self.stores.contains( typeName ))
    {
      utl.log( .WARN, @src(), "Cannot register CompStore for type {s} : type already registered", .{ typeName });
      return false;
    }

    const StoreType = CompStoreFactory( CompType );
    const store = self.alloc.create( StoreType ) catch
    {
      utl.log( .ERROR, @src(), "Failed to allocate CompStore for type {s}", .{ typeName });
      return false;
    };

    store.* = .{};
    store.init( self.alloc );

    self.stores.put( typeName,
    .{
      .storePtr        = store,
      .deinitDestroyFn = deinitDestroyStore( CompType ),
      .removeEntityFn  = removeEntityFromStore( CompType ),
    })
    catch
    {
      utl.log( .ERROR, @src(), "Failed to register CompStore for type {s}", .{ typeName });

      store.deinit();
      self.alloc.destroy( store );
      return false;
    };

    return true;
  }

  /// Removes storage for one component type and drops all rows in that store.
  pub fn unregister( self : *CompManager, comptime CompType : type ) bool
  {
    const typeName = @typeName( CompType );

    if( !self.isInit )
    {
      utl.log( .WARN, @src(), "Cannot unregister CompStore for type {s} : CompManager is uninitialized", .{ typeName });
      return false;
    }

    const entry = self.stores.get( typeName ) orelse
    {
      utl.log( .DEBUG, @src(), "Cannot unregister CompStore for type {s} : type not registered", .{ typeName });
      return false;
    };

    if( !self.stores.remove( typeName )){ return false; }
    entry.deinitDestroyFn( self.alloc, entry.storePtr );
    return true;
  }

  /// Returns the typed store pointer for one component type.
  pub fn getStore( self : *CompManager, comptime CompType : type ) ?*CompStoreFactory( CompType )
  {
    const typeName = @typeName( CompType );

    if( !self.isInit )
    {
      utl.log( .WARN, @src(), "Cannot get CompStore for type {s} : CompManager is uninitialized", .{ typeName });
      return null;
    }

    const entry = self.stores.get( typeName ) orelse return null;
    return @ptrCast( @alignCast( entry.storePtr ));
  }

  /// Removes an entity id from every registered component store.
  /// Used by `World.destroyEntity`.
  pub fn removeEntity( self : *CompManager, entityId : EntityId ) EntityCleanupResult
  {
    var result : EntityCleanupResult = .{};

    if( !self.isInit )
    {
      utl.log( .WARN, @src(), "Cannot remove Entity {d} from CompStores : CompManager is uninitialized", .{ entityId });
      result.failedCount = 1;
      return result;
    }

    var iter = self.stores.valueIterator();
    while( iter.next() )| entry |
    {
      switch( entry.removeEntityFn( entry.storePtr, entityId ))
      {
        .REMOVED => result.removedCount += 1,
        .MISSING => result.missingCount += 1,
        .FAILED  => result.failedCount  += 1,
      }
    }

    return result;
  }


  // ================================ INTERNAL FUNCTIONS ================================

  fn deinitDestroyStore( comptime CompType : type ) *const fn ( std.mem.Allocator, *anyopaque ) void
  {
    return struct
    {
      fn call( alloc : std.mem.Allocator, storePtr : *anyopaque ) void
      {
        const store : *CompStoreFactory( CompType ) = @ptrCast( @alignCast( storePtr ));

        store.deinit();
        alloc.destroy( store );
      }
    }.call;
  }

  fn removeEntityFromStore( comptime CompType : type ) *const fn ( *anyopaque, EntityId ) StoreEntityCleanupResult
  {
    return struct
    {
      fn call( storePtr : *anyopaque, entityId : EntityId ) StoreEntityCleanupResult
      {
        const store : *CompStoreFactory( CompType ) = @ptrCast( @alignCast( storePtr ));

        if( !store.isInit )
        {
          utl.log( .WARN, @src(), "Cannot remove Entity {d} from CompStore for type {s} : uninitialized", .{ entityId, @typeName( CompType )});
          return .FAILED;
        }
        if( !store.has( entityId )){ return .MISSING; }

        if( store.remove( entityId )){ return .REMOVED; }

        utl.log( .ERROR, @src(), "Failed to remove Entity {d} from CompStore for type {s}", .{ entityId, @typeName( CompType )});
        return .FAILED;
      }
    }.call;
  }
};


test "CompManager owns typed store registration and lifecycle"
{
  const TestComp = struct
  {
    pub const compStorePolicy : CompStorePolicy = .SPARSE;

    value : u32 = 0,
  };

  var manager : CompManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  try std.testing.expect( manager.register( TestComp ));
  try std.testing.expect( !manager.register( TestComp ));

  const store = manager.getStore( TestComp ).?;
  try std.testing.expect( store.add( 1, .{ .value = 42 }));
  try std.testing.expect( store.get( 1 ).?.value == 42 );

  try std.testing.expect( manager.unregister( TestComp ));
  try std.testing.expect( manager.getStore( TestComp ) == null );
  try std.testing.expect( manager.register( TestComp ));
}

test "CompManager resolves component store policies"
{
  const SparseComp = struct
  {
    pub const compStorePolicy : CompStorePolicy = .SPARSE;

    value : u32 = 0,
  };
  const PackedComp = struct
  {
    pub const compStorePolicy : CompStorePolicy = .PACKED;

    value : u32 = 0,
  };

  try std.testing.expect( comp.getCompStorePolicy( SparseComp  ) == .SPARSE );
  try std.testing.expect( comp.getCompStorePolicy( PackedComp   ) == .PACKED  );
}

test "CompManager accepts sparse and packed policies"
{
  const SparseComp = struct
  {
    pub const compStorePolicy : CompStorePolicy = .SPARSE;

    value : u32 = 0,
  };
  const PackedComp = struct
  {
    pub const compStorePolicy : CompStorePolicy = .PACKED;

    value : u32 = 0,
  };

  var manager : CompManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  try std.testing.expect( manager.register( SparseComp ));
  try std.testing.expect( !manager.register( SparseComp ));

  const sparseStore = manager.getStore( SparseComp ).?;
  try std.testing.expect( sparseStore.add( 1, .{ .value = 42 }));
  try std.testing.expect( sparseStore.get( 1 ).?.value == 42 );

  try std.testing.expect( manager.register( PackedComp ));
  try std.testing.expect( !manager.register( PackedComp ));

  const packedStore = manager.getStore( PackedComp ).?;
  try std.testing.expect( packedStore.add( 1, .{ .value = 42 }));
  try std.testing.expect( packedStore.get( 1 ).?.value == 42 );
}

test "CompManager removes an entity from every registered store"
{
  const SparseComp = struct
  {
    pub const compStorePolicy : CompStorePolicy = .SPARSE;

    value : u32 = 0,
  };
  const PackedComp = struct
  {
    pub const compStorePolicy : CompStorePolicy = .PACKED;

    value : u32 = 0,
  };

  var manager : CompManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  try std.testing.expect( manager.register( SparseComp ));
  try std.testing.expect( manager.register( PackedComp  ));

  const sparseStore = manager.getStore( SparseComp ).?;
  const packedStore  = manager.getStore( PackedComp  ).?;

  try std.testing.expect( sparseStore.add( 1, .{ .value = 10 }));
  try std.testing.expect( packedStore.add(  1, .{ .value = 20 }));
  try std.testing.expect( packedStore.add(  2, .{ .value = 30 }));

  const cleanup = manager.removeEntity( 1 );
  try std.testing.expect( cleanup.isSuccess() );
  try std.testing.expect( cleanup.removedCount == 2 );
  try std.testing.expect( cleanup.missingCount == 0 );

  try std.testing.expect( !sparseStore.has( 1 ));
  try std.testing.expect( !packedStore.has(  1 ));
  try std.testing.expect(  packedStore.has(  2 ));
}

test "CompManager entity cleanup tolerates missing component rows"
{
  const SparseComp = struct
  {
    pub const compStorePolicy : CompStorePolicy = .SPARSE;

    value : u32 = 0,
  };
  const PackedComp = struct
  {
    pub const compStorePolicy : CompStorePolicy = .PACKED;

    value : u32 = 0,
  };

  var manager : CompManager = .{};
  manager.init( std.testing.allocator );
  defer manager.deinit();

  try std.testing.expect( manager.register( SparseComp ));
  try std.testing.expect( manager.register( PackedComp  ));

  const cleanup = manager.removeEntity( 99 );
  try std.testing.expect( cleanup.isSuccess() );
  try std.testing.expect( cleanup.removedCount == 0 );
  try std.testing.expect( cleanup.missingCount == 2 );
}
