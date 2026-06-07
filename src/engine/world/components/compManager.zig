const std  = @import( "std" );
const utl  = @import( "utils" );
const comp = @import( "component.zig" );

const CompStoreFactory = comp.CompStoreFactory;
const CompStorePolicy  = comp.CompStorePolicy;


pub const CompManager = struct
{
  const OwnedStoreEntry = struct
  {
    storePtr        : *anyopaque,
    deinitDestroyFn : *const fn ( std.mem.Allocator, *anyopaque ) void,
  };

  alloc  : std.mem.Allocator                    = undefined,
  stores : std.StringHashMap( OwnedStoreEntry ) = undefined,

  isInit : bool = false,


  // ================================ LIFECYCLE FUNCTIONS ================================

  pub fn init( self : *CompManager, alloc : std.mem.Allocator ) void
  {
    if( self.isInit )
    {
      utl.qlog( .WARN, 0, @src(), "CompManager is already initialized : returning" );
      return;
    }

    self.alloc  = alloc;
    self.stores = .init( alloc );
    self.isInit = true;
  }

  pub fn deinit( self : *CompManager ) void
  {
    if( !self.isInit )
    {
      utl.qlog( .WARN, 0, @src(), "CompManager is uninitialized : returning" );
      return;
    }

    var iter = self.stores.valueIterator();
    while( iter.next() )| entry |{ entry.deinitDestroyFn( self.alloc, entry.storePtr ); }

    self.stores.deinit();
    self.isInit = false;
  }


  // ================================ STORE FUNCTIONS ================================

  pub fn register( self : *CompManager, comptime CompType : type ) bool
  {
    const typeName = @typeName( CompType );

    if( !self.isInit )
    {
      utl.log( .WARN, 0, @src(), "Cannot register CompStore for type {s} : CompManager is uninitialized", .{ typeName });
      return false;
    }
    if( self.stores.contains( typeName ))
    {
      utl.log( .WARN, 0, @src(), "Cannot register CompStore for type {s} : type already registered", .{ typeName });
      return false;
    }

    const StoreType = CompStoreFactory( CompType );
    const store = self.alloc.create( StoreType ) catch
    {
      utl.log( .ERROR, 0, @src(), "Failed to allocate CompStore for type {s}", .{ typeName });
      return false;
    };

    store.* = .{};
    store.init( self.alloc );

    self.stores.put( typeName,
    .{
      .storePtr        = store,
      .deinitDestroyFn = deinitDestroyStore( CompType ),
    })
    catch
    {
      utl.log( .ERROR, 0, @src(), "Failed to register CompStore for type {s}", .{ typeName });

      store.deinit();
      self.alloc.destroy( store );
      return false;
    };

    return true;
  }

  pub fn unregister( self : *CompManager, comptime CompType : type ) bool
  {
    const typeName = @typeName( CompType );

    if( !self.isInit )
    {
      utl.log( .WARN, 0, @src(), "Cannot unregister CompStore for type {s} : CompManager is uninitialized", .{ typeName });
      return false;
    }

    const entry = self.stores.get( typeName ) orelse
    {
      utl.log( .DEBUG, 0, @src(), "Cannot unregister CompStore for type {s} : type not registered", .{ typeName });
      return false;
    };

    if( !self.stores.remove( typeName )){ return false; }
    entry.deinitDestroyFn( self.alloc, entry.storePtr );
    return true;
  }

  pub fn getStore( self : *CompManager, comptime CompType : type ) ?*CompStoreFactory( CompType )
  {
    const typeName = @typeName( CompType );

    if( !self.isInit )
    {
      utl.log( .WARN, 0, @src(), "Cannot get CompStore for type {s} : CompManager is uninitialized", .{ typeName });
      return null;
    }

    const entry = self.stores.get( typeName ) orelse return null;
    return @ptrCast( @alignCast( entry.storePtr ));
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
};


test "CompManager owns typed store registration and lifecycle"
{
  const TestComp = struct
  {
    pub const storeType : CompStorePolicy = .SPARSE;

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
    pub const storeType : CompStorePolicy = .SPARSE;

    value : u32 = 0,
  };
  const DenseComp = struct
  {
    pub const storeType : CompStorePolicy = .DENSE;

    value : u32 = 0,
  };

  try std.testing.expect( comp.getCompStorePolicy( SparseComp  ) == .SPARSE );
  try std.testing.expect( comp.getCompStorePolicy( DenseComp   ) == .DENSE  );
}

test "CompManager accepts sparse and dense policies"
{
  const SparseComp = struct
  {
    pub const storeType : CompStorePolicy = .SPARSE;

    value : u32 = 0,
  };
  const DenseComp = struct
  {
    pub const storeType : CompStorePolicy = .DENSE;

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

  try std.testing.expect( manager.register( DenseComp ));
  try std.testing.expect( !manager.register( DenseComp ));

  const denseStore = manager.getStore( DenseComp ).?;
  try std.testing.expect( denseStore.add( 1, .{ .value = 42 }));
  try std.testing.expect( denseStore.get( 1 ).?.value == 42 );
}
