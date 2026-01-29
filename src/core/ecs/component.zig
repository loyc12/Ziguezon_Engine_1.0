const std = @import( "std" );
const def = @import( "defs" );

const EntityId = def.EntityId;


pub fn newComponentStore( comptime T: type ) type
{
  return struct
  {
    const Self = @This();

    data : std.AutoHashMap( EntityId, T ),

    pub fn init( alloc : std.mem.Allocator ) Self
    {
      return .{ .data = std.AutoHashMap( EntityId, T ).init( alloc )};
    }

    pub fn deinit( self : *Self ) void { self.data.deinit(); }


    pub fn add( self : *Self, id : EntityId, value : T ) void
    {
      self.data.put( id, value ) catch unreachable; // TODO : handle me
    }

    pub fn get( self : *Self, id: EntityId ) ?*T { return self.data.getPtr( id ); }

    pub fn remove( self : *Self, id: EntityId ) void { _ = self.data.remove( id ); }

    pub fn iterator( self : *Self ) @TypeOf( self.data.iterator() )
    {
      return self.data.iterator();
    }
  };
}


const Entry = struct
{
  ptr : *anyopaque,
};

pub const ComponentRegistry = struct
{
  map : std.StringHashMap( Entry ),

  pub fn init( alloc : std.mem.Allocator ) ComponentRegistry
  {
    return .{ .map = std.StringHashMap( Entry ).init( alloc ) };
  }

  pub fn deinit( self : *ComponentRegistry ) void { self.map.deinit(); }


  pub fn register( self : *ComponentRegistry, name : []const u8, store_ptr : *anyopaque ) void
  {
    self.map.put( name, .{ .ptr = store_ptr }) catch unreachable; // TODO : handle me
  }

  pub fn get( self : *ComponentRegistry, name : []const u8 ) ?*anyopaque
  {
    return if ( self.map.get( name )) | e | e.ptr else null;
  }
};