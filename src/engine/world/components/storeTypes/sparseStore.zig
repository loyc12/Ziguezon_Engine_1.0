const std = @import( "std" );
const utl = @import( "utils" );

const entity = @import( "../../entity.zig" );

const EntityId = entity.EntityId;


/// Hash-map component storage for optional or sparsely used components.
/// Lookup is direct by entity id; iteration order is hash-map order.
pub fn SparseCompStoreFactory( comptime CompType : type ) type
{
  return struct
  {
    const TypeName  = @typeName( CompType );
    const CompStore = @This();

    data : std.AutoHashMap( EntityId, CompType ) = undefined,
    isInit : bool = false,


    /// Initializes sparse hash-map storage.
    pub fn init( self : *CompStore, alloc : std.mem.Allocator ) void
    {
      utl.log( .INFO, @src(), "Initializing sparse CompStore for type {s}", .{ TypeName });

      if( self.isInit )
      {
        utl.log( .WARN, @src(), "Sparse CompStore for type {s} is already initialized : returning", .{ TypeName } );
        return;
      }

      self.data = .init( alloc );
      self.isInit = true;
    }

    /// Releases sparse storage.
    pub fn deinit( self : *CompStore ) void
    {
      utl.log( .INFO, @src(), "Deinitializing sparse CompStore for type {s}", .{ TypeName });

      if( !self.isInit )
      {
        utl.log( .WARN, @src(), "Sparse CompStore for type {s} is unnitialized : returning", .{ TypeName } );
        return;
      }

      self.data.deinit();
      self.isInit = false;
    }

    /// Adds a component row for a nonzero entity id.
    /// Duplicate entity ids are rejected.
    pub fn add( self : *CompStore, id : EntityId, value : CompType ) bool
    {
      if( !self.isInit )
      {
        utl.log( .WARN, @src(), "Cannot add to sparse CompStore for type {s} : uninitialized", .{ TypeName } );
        return false;
      }
      if( id == 0 )
      {
        utl.log( .DEBUG, @src(), "Cannot add Entity 0 to sparse CompStore for type {s}", .{ TypeName });
        return false;
      }

      const result = self.data.getOrPut( id ) catch { return false; };
      {
        if( !result.found_existing )
        {
          result.value_ptr.* = value;
          utl.log( .TRACE, @src(), "Added Entity {d} to sparse CompStore for type {s}", .{ id, TypeName });
          return true;
        }
        else
        {
          utl.log( .WARN, @src(), "Cannot add Entity {d} to sparse CompStore for type {s} : key already in use", .{ id, TypeName });
          return false;
        }
      }
    }

    /// Removes a component row by entity id.
    pub fn remove( self : *CompStore, id : EntityId ) bool
    {
      if( !self.isInit )
      {
        utl.log( .WARN, @src(), "Cannot remove from sparse CompStore for type {s} : uninitialized", .{ TypeName } );
        return false;
      }
      if( self.data.remove( id ))
      {
        utl.log( .TRACE, @src(), "Removed Entity {d} from sparse CompStore for type {s}", .{ id, TypeName });
        return true;
      }
      else
      {
        utl.log( .DEBUG, @src(), "Cannot remove Entity {d} from sparse CompStore for type {s} : key not found", .{ id, TypeName });
        return false;
      }
    }

    /// Returns a mutable payload pointer for an entity id, or null.
    pub fn get( self : *CompStore, id : EntityId ) ?*CompType
    {
      if( !self.isInit )
      {
        utl.log( .WARN, @src(), "Cannot obtain from sparse CompStore for type {s} : uninitialized", .{ TypeName } );
        return null;
      }
      if( self.data.getPtr( id ))| ptr |
      {
        return ptr;
      }
      else
      {
        utl.log( .WARN, @src(), "Cannot find entity with id {d} in sparse CompStore for type {s}", .{ id, TypeName });
      }
      return null;
    }

    /// Returns a read-only payload pointer for an entity id, or null.
    pub fn getConst( self : *const CompStore, id : EntityId ) ?*const CompType
    {
      if( !self.isInit )
      {
        utl.log( .WARN, @src(), "Cannot inspect sparse CompStore for type {s} : uninitialized", .{ TypeName } );
        return null;
      }

      return self.data.getPtr( id );
    }

    /// Returns true when the entity id has a row in this store.
    pub fn has( self : *const CompStore, id : EntityId ) bool
    {
      if( !self.isInit )
      {
        utl.log( .WARN, @src(), "Cannot peer into sparse CompStore for type {s} : uninitialized", .{ TypeName } );
        return false;
      }
      return self.data.getPtr( id ) != null;
    }

    /// Returns the underlying hash-map iterator over rows.
    pub fn iterator( self : *CompStore ) @TypeOf( self.data.iterator() )
    {
      return self.data.iterator();
    }

    /// Returns the underlying hash-map iterator without exposing mutable rows.
    pub fn iteratorConst( self : *const CompStore ) @TypeOf( self.data.iterator() )
    {
      return self.data.iterator();
    }
  };
}


test "SparseCompStore preserves hash map CRUD behavior"
{
  const TestComp = struct
  {
    value : u32 = 0,
  };

  var store : SparseCompStoreFactory( TestComp ) = .{};
  store.init( std.testing.allocator );
  defer store.deinit();

  try std.testing.expect(  store.add( 1, .{ .value = 42 }));
  try std.testing.expect( !store.add( 1, .{ .value = 99 }));
  try std.testing.expect(  store.has( 1 ));
  try std.testing.expect(  store.get( 1 ).?.value == 42 );
  try std.testing.expect(  store.remove( 1 ));
  try std.testing.expect( !store.has( 1 ));
  try std.testing.expect(  store.get( 1 ) == null );
  try std.testing.expect( !store.remove( 1 ));
}

test "SparseCompStore iterates hash map entries"
{
  const TestComp = struct
  {
    value : u32 = 0,
  };

  var store : SparseCompStoreFactory( TestComp ) = .{};
  store.init( std.testing.allocator );
  defer store.deinit();

  try std.testing.expect( store.add( 1, .{ .value = 10 }));
  try std.testing.expect( store.add( 2, .{ .value = 20 }));

  var count : usize = 0;
  var sum   : u32   = 0;

  var iter = store.iterator();
  while( iter.next() )| entry |
  {
    count += 1;
    sum   += entry.value_ptr.value;
  }

  try std.testing.expect( count == 2 );
  try std.testing.expect( sum   == 30 );
}
