const std = @import( "std" );
const utl = @import( "utils" );

const entity = @import( "../../entity.zig" );

const EntityId = entity.EntityId;


pub fn SparseCompStoreFactory( comptime CompType : type ) type
{
  return struct
  {
    const TypeName  = @typeName( CompType );
    const CompStore = @This();

    data : std.AutoHashMap( EntityId, CompType ) = undefined,
    isInit : bool = false,


    pub fn init( self : *CompStore, alloc : std.mem.Allocator ) void
    {
      utl.log( .INFO, 0, @src(), "Initializing sparse CompStore for type {s}", .{ TypeName });

      if( self.isInit )
      {
        utl.log( .WARN, 0, @src(), "Sparse CompStore for type {s} is already initialized : returning", .{ TypeName } );
        return;
      }

      self.data = .init( alloc );
      self.isInit = true;
    }

    pub fn deinit( self : *CompStore ) void
    {
      utl.log( .INFO, 0, @src(), "Deinitializing sparse CompStore for type {s}", .{ TypeName });

      if( !self.isInit )
      {
        utl.log( .WARN, 0, @src(), "Sparse CompStore for type {s} is unnitialized : returning", .{ TypeName } );
        return;
      }

      self.data.deinit();
      self.isInit = false;
    }

    pub fn add( self : *CompStore, id : EntityId, value : CompType ) bool
    {
      if( !self.isInit )
      {
        utl.log( .WARN, 0, @src(), "Cannot add to sparse CompStore for type {s} : uninitialized", .{ TypeName } );
        return false;
      }
      if( id == 0 )
      {
        utl.log( .DEBUG, 0, @src(), "Cannot add Entity 0 to sparse CompStore for type {s}", .{ TypeName });
        return false;
      }

      const result = self.data.getOrPut( id ) catch { return false; };
      {
        if( !result.found_existing )
        {
          result.value_ptr.* = value;
          utl.log( .TRACE, 0, @src(), "Added Entity {d} to sparse CompStore for type {s}", .{ id, TypeName });
          return true;
        }
        else
        {
          utl.log( .WARN, 0, @src(), "Cannot add Entity {d} to sparse CompStore for type {s} : key already in use", .{ id, TypeName });
          return false;
        }
      }
    }

    pub fn remove( self : *CompStore, id : EntityId ) bool
    {
      if( !self.isInit )
      {
        utl.log( .WARN, 0, @src(), "Cannot remove from sparse CompStore for type {s} : uninitialized", .{ TypeName } );
        return false;
      }
      if( self.data.remove( id ))
      {
        utl.log( .TRACE, 0, @src(), "Removed Entity {d} from sparse CompStore for type {s}", .{ id, TypeName });
        return true;
      }
      else
      {
        utl.log( .DEBUG, 0, @src(), "Cannot remove Entity {d} from sparse CompStore for type {s} : key not found", .{ id, TypeName });
        return false;
      }
    }

    pub fn get( self : *CompStore, id : EntityId ) ?*CompType
    {
      if( !self.isInit )
      {
        utl.log( .WARN, 0, @src(), "Cannot obtain from sparse CompStore for type {s} : uninitialized", .{ TypeName } );
        return null;
      }
      if( self.data.getPtr( id ))| ptr |
      {
        return ptr;
      }
      else
      {
        utl.log( .WARN, 0, @src(), "Cannot find entity with id {d} in sparse CompStore for type {s}", .{ id, TypeName });
      }
      return null;
    }

    pub fn has( self : *CompStore, id : EntityId ) bool
    {
      if( !self.isInit )
      {
        utl.log( .WARN, 0, @src(), "Cannot peer into sparse CompStore for type {s} : uninitialized", .{ TypeName } );
        return false;
      }
      return self.data.getPtr( id ) != null;
    }

    pub fn iterator( self : *CompStore ) @TypeOf( self.data.iterator() )
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
