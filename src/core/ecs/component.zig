const std = @import( "std" );
const def = @import( "defs" );

const EntityId = def.EntityId;


pub const ComponentStore = struct
{
  allocator : std.mem.Allocator,

  map : std.AutoHashMap( EntityId, anyopaque ),

  pub fn init( alloc : std.mem.Allocator) ComponentStore
  {

  }

  pub fn deinit( self : *ComponentStore) void
  {

  }
};


pub fn createTypedComponentStore( comptime T : type ) type
{
  return struct
  {
    data : std.AutoHashMap( EntityId, T ),

    pub fn add( self: *createTypedComponentStore, id: EntityId, value: T) void
    {

    }

    pub fn get( self: *createTypedComponentStore, id: EntityId) ?*T
    {

    }

    pub fn remove( self: *createTypedComponentStore, id: EntityId ) void
    {

    }
  };
}