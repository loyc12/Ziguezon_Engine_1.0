const std = @import( "std" );
const utl = @import( "utils" );

const entity = @import( "../../entity.zig" );

const EntityId = entity.EntityId;

// PACKED stores rows contiguously and maps EntityId to row index.
// A future DIRECT store may use raw EntityId-indexed array storage.


/// Dense component storage for components that are commonly iterated.
/// Removal uses swap-remove, so row order is not stable.
pub fn PackedCompStoreFactory( comptime CompType : type ) type
{
  return struct
  {
    const TypeName  = @typeName( CompType );
    const CompStore = @This();

    /// Iterator item containing both the entity id and component payload pointer.
    pub const Entry = struct
    {
      key_ptr   : *EntityId,
      value_ptr : *CompType,
    };

    /// Iterates current packed rows in storage order.
    /// Storage order may change after removals.
    pub const Iterator = struct
    {
      store : *CompStore,
      index : usize = 0,

      pub fn next( self : *Iterator ) ?Entry
      {
        if( self.index >= self.store.entityIds.items.len ){ return null; }

        const index = self.index;
        self.index += 1;

        return .{
          .key_ptr   = &self.store.entityIds.items[ index ],
          .value_ptr = &self.store.values.items[ index ],
        };
      }
    };

    alloc     : std.mem.Allocator                  = undefined,
    entityIds : std.ArrayList(   EntityId )        = .empty,
    values    : std.ArrayList(   CompType )        = .empty,
    indices   : std.AutoHashMap( EntityId, usize ) = undefined,

    isInit : bool = false,


    /// Initializes packed arrays and the entity-id to row-index map.
    pub fn init( self : *CompStore, alloc : std.mem.Allocator ) void
    {
      utl.log( .INFO, 0, @src(), "Initializing packed CompStore for type {s}", .{ TypeName });

      if( self.isInit )
      {
        utl.log( .WARN, 0, @src(), "Packed CompStore for type {s} is already initialized : returning", .{ TypeName } );
        return;
      }

      self.alloc     = alloc;
      self.entityIds = .empty;
      self.values    = .empty;
      self.indices   = .init( alloc );
      self.isInit    = true;
    }

    /// Releases packed storage.
    pub fn deinit( self : *CompStore ) void
    {
      utl.log( .INFO, 0, @src(), "Deinitializing packed CompStore for type {s}", .{ TypeName });

      if( !self.isInit )
      {
        utl.log( .WARN, 0, @src(), "Packed CompStore for type {s} is unnitialized : returning", .{ TypeName } );
        return;
      }

      self.indices.deinit();
      self.values.deinit(    self.alloc );
      self.entityIds.deinit( self.alloc );
      self.isInit = false;
    }

    /// Adds a component row for a nonzero entity id.
    /// Duplicate entity ids are rejected.
    pub fn add( self : *CompStore, id : EntityId, value : CompType ) bool
    {
      if( !self.isInit )
      {
        utl.log( .WARN, 0, @src(), "Cannot add to packed CompStore for type {s} : uninitialized", .{ TypeName } );
        return false;
      }
      if( id == 0 )
      {
        utl.log( .DEBUG, 0, @src(), "Cannot add Entity 0 to packed CompStore for type {s}", .{ TypeName });
        return false;
      }
      if( self.indices.contains( id ))
      {
        utl.log( .WARN, 0, @src(), "Cannot add Entity {d} to packed CompStore for type {s} : key already in use", .{ id, TypeName });
        return false;
      }

      const index = self.values.items.len;

      self.entityIds.append( self.alloc, id ) catch { return false; };
      self.values.append(    self.alloc, value ) catch
      {
        _ = self.entityIds.pop();
        return false;
      };
      self.indices.put( id, index ) catch
      {
        _ = self.values.pop();
        _ = self.entityIds.pop();
        return false;
      };

      utl.log( .TRACE, 0, @src(), "Added Entity {d} to packed CompStore for type {s}", .{ id, TypeName });
      return true;
    }

    /// Removes a component row by entity id using swap-remove.
    /// Existing pointers into this store may become stale after removal.
    pub fn remove( self : *CompStore, id : EntityId ) bool
    {
      if( !self.isInit )
      {
        utl.log( .WARN, 0, @src(), "Cannot remove from packed CompStore for type {s} : uninitialized", .{ TypeName } );
        return false;
      }

      const index = self.indices.get( id ) orelse
      {
        utl.log( .DEBUG, 0, @src(), "Cannot remove Entity {d} from packed CompStore for type {s} : key not found", .{ id, TypeName });
        return false;
      };

      const lastIndex = self.values.items.len - 1;

      if( index != lastIndex )
      {
        const movedId = self.entityIds.items[ lastIndex ];

        self.entityIds.items[ index ] = movedId;
        self.values.items[ index ] = self.values.items[ lastIndex ];
        self.indices.getPtr( movedId ).?.* = index;
      }

      _ = self.entityIds.pop();
      _ = self.values.pop();
      _ = self.indices.remove( id );

      utl.log( .TRACE, 0, @src(), "Removed Entity {d} from packed CompStore for type {s}", .{ id, TypeName });
      return true;
    }

    /// Returns a mutable payload pointer for an entity id, or null.
    pub fn get( self : *CompStore, id : EntityId ) ?*CompType
    {
      if( !self.isInit )
      {
        utl.log( .WARN, 0, @src(), "Cannot obtain from packed CompStore for type {s} : uninitialized", .{ TypeName } );
        return null;
      }

      const index = self.indices.get( id ) orelse
      {
        utl.log( .WARN, 0, @src(), "Cannot find entity with id {d} in packed CompStore for type {s}", .{ id, TypeName });
        return null;
      };

      return &self.values.items[ index ];
    }

    /// Returns true when the entity id has a row in this store.
    pub fn has( self : *CompStore, id : EntityId ) bool
    {
      if( !self.isInit )
      {
        utl.log( .WARN, 0, @src(), "Cannot peer into packed CompStore for type {s} : uninitialized", .{ TypeName } );
        return false;
      }
      return self.indices.contains( id );
    }

    /// Returns an iterator over packed rows.
    pub fn iterator( self : *CompStore ) Iterator
    {
      return .{ .store = self };
    }
  };
}


test "PackedCompStore add get has remove"
{
  const TestComp = struct
  {
    value : u32 = 0,
  };

  var store : PackedCompStoreFactory( TestComp ) = .{};
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

test "PackedCompStore swap remove repairs moved index"
{
  const TestComp = struct
  {
    value : u32 = 0,
  };

  var store : PackedCompStoreFactory( TestComp ) = .{};
  store.init( std.testing.allocator );
  defer store.deinit();

  try std.testing.expect( store.add( 1, .{ .value = 10 }));
  try std.testing.expect( store.add( 2, .{ .value = 20 }));
  try std.testing.expect( store.add( 3, .{ .value = 30 }));

  try std.testing.expect( store.remove( 2 ));
  try std.testing.expect( store.get( 3 ).?.value == 30 );
  try std.testing.expect( store.indices.get( 3 ).? == 1 );
}

test "PackedCompStore iterates packed rows"
{
  const TestComp = struct
  {
    value : u32 = 0,
  };

  var store : PackedCompStoreFactory( TestComp ) = .{};
  store.init( std.testing.allocator );
  defer store.deinit();

  try std.testing.expect( store.add( 1, .{ .value = 10 }));
  try std.testing.expect( store.add( 2, .{ .value = 20 }));
  try std.testing.expect( store.add( 3, .{ .value = 30 }));
  try std.testing.expect( store.remove( 2 ));

  var count : usize = 0;
  var sum   : u32   = 0;

  var iter = store.iterator();
  while( iter.next() )| entry |
  {
    count += 1;
    sum   += entry.value_ptr.value;
  }

  try std.testing.expect( count == 2 );
  try std.testing.expect( sum   == 40 );
}
