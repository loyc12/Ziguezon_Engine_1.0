const std = @import( "std" );
const utl = @import( "utils" );

const entity = @import( "../../entity.zig" );

const EntityId = entity.EntityId;

// NOTE : Not the densest possible store. Check if implementing an id-indexed array alternative would be worth it


pub fn DenseCompStoreFactory( comptime CompType : type ) type
{
  return struct
  {
    const TypeName  = @typeName( CompType ); // NOTE : FOR LOGGING ONLY
    const CompStore = @This();

    pub const Entry = struct
    {
      key_ptr   : *EntityId,
      value_ptr : *CompType,
    };

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


    pub fn init( self : *CompStore, alloc : std.mem.Allocator ) void
    {
      utl.log( .INFO, 0, @src(), "Initializing dense CompStore for type {s}", .{ TypeName });

      if( self.isInit )
      {
        utl.log( .WARN, 0, @src(), "Dense CompStore for type {s} is already initialized : returning", .{ TypeName } );
        return;
      }

      self.alloc     = alloc;
      self.entityIds = .empty;
      self.values    = .empty;
      self.indices   = .init( alloc );
      self.isInit    = true;
    }

    pub fn deinit( self : *CompStore ) void
    {
      utl.log( .INFO, 0, @src(), "Deinitializing dense CompStore for type {s}", .{ TypeName });

      if( !self.isInit )
      {
        utl.log( .WARN, 0, @src(), "Dense CompStore for type {s} is unnitialized : returning", .{ TypeName } );
        return;
      }

      self.indices.deinit();
      self.values.deinit(    self.alloc );
      self.entityIds.deinit( self.alloc );
      self.isInit = false;
    }

    pub fn add( self : *CompStore, id : EntityId, value : CompType ) bool
    {
      if( !self.isInit )
      {
        utl.log( .WARN, 0, @src(), "Cannot add to dense CompStore for type {s} : uninitialized", .{ TypeName } );
        return false;
      }
      if( id == 0 )
      {
        utl.log( .DEBUG, 0, @src(), "Cannot add Entity 0 to dense CompStore for type {s}", .{ TypeName });
        return false;
      }
      if( self.indices.contains( id ))
      {
        utl.log( .WARN, 0, @src(), "Cannot add Entity {d} to dense CompStore for type {s} : key already in use", .{ id, TypeName });
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

      utl.log( .TRACE, 0, @src(), "Added Entity {d} to dense CompStore for type {s}", .{ id, TypeName });
      return true;
    }

    pub fn remove( self : *CompStore, id : EntityId ) bool
    {
      if( !self.isInit )
      {
        utl.log( .WARN, 0, @src(), "Cannot remove from dense CompStore for type {s} : uninitialized", .{ TypeName } );
        return false;
      }

      const index = self.indices.get( id ) orelse
      {
        utl.log( .DEBUG, 0, @src(), "Cannot remove Entity {d} from dense CompStore for type {s} : key not found", .{ id, TypeName });
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

      utl.log( .TRACE, 0, @src(), "Removed Entity {d} from dense CompStore for type {s}", .{ id, TypeName });
      return true;
    }

    pub fn get( self : *CompStore, id : EntityId ) ?*CompType
    {
      if( !self.isInit )
      {
        utl.log( .WARN, 0, @src(), "Cannot obtain from dense CompStore for type {s} : uninitialized", .{ TypeName } );
        return null;
      }

      const index = self.indices.get( id ) orelse
      {
        utl.log( .WARN, 0, @src(), "Cannot find entity with id {d} in dense CompStore for type {s}", .{ id, TypeName });
        return null;
      };

      return &self.values.items[ index ];
    }

    pub fn has( self : *CompStore, id : EntityId ) bool
    {
      if( !self.isInit )
      {
        utl.log( .WARN, 0, @src(), "Cannot peer into dense CompStore for type {s} : uninitialized", .{ TypeName } );
        return false;
      }
      return self.indices.contains( id );
    }

    pub fn iterator( self : *CompStore ) Iterator
    {
      return .{ .store = self };
    }
  };
}


test "DenseCompStore add get has remove"
{
  const TestComp = struct
  {
    value : u32 = 0,
  };

  var store : DenseCompStoreFactory( TestComp ) = .{};
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

test "DenseCompStore swap remove repairs moved index"
{
  const TestComp = struct
  {
    value : u32 = 0,
  };

  var store : DenseCompStoreFactory( TestComp ) = .{};
  store.init( std.testing.allocator );
  defer store.deinit();

  try std.testing.expect( store.add( 1, .{ .value = 10 }));
  try std.testing.expect( store.add( 2, .{ .value = 20 }));
  try std.testing.expect( store.add( 3, .{ .value = 30 }));

  try std.testing.expect( store.remove( 2 ));
  try std.testing.expect( store.get( 3 ).?.value == 30 );
  try std.testing.expect( store.indices.get( 3 ).? == 1 );
}

test "DenseCompStore iterates packed rows"
{
  const TestComp = struct
  {
    value : u32 = 0,
  };

  var store : DenseCompStoreFactory( TestComp ) = .{};
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
