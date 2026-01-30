const std = @import( "std" );
const def = @import( "defs" );

const EntityId = def.EntityId;


pub const ComponentRegistry = struct
{
  // Wrapper around the underlying componentStoreType
  const ComponentStoreEntry = struct
  {
    ptr : *anyopaque, // Points to an anonymous ComponentStore instance
  };

//isInit     : bool = false,
//allocator  : std.mem.Allocator = undefined, // NOTE : would this be useful in any way ?
  map        : std.StringHashMap( ComponentStoreEntry ),


  pub fn init( alloc : std.mem.Allocator ) ComponentRegistry
  {
    def.qlog( .INFO, 0, @src(), "Initializing component registry" );
    return .{ .map = std.StringHashMap( ComponentStoreEntry ).init( alloc ) };
  }

  pub fn deinit( self : *ComponentRegistry ) void
  {
    def.qlog( .INFO, 0, @src(), "Deinitializing component registry" );
    self.map.deinit();
  }

  pub fn register( self : *ComponentRegistry, name : []const u8, store_ptr : *anyopaque ) void
  {
    // store_ptr is a pointer to an instance of a ComponentStore
    // this ptr is then wrapped in a generic ComponentStoreEntry

    if( self.map.getOrPut( name ) catch unreachable )| res | // TODO : handle unreachable
    {
      if( !res.found_existing ) // Initialize ComponentStoreEntry instance if a matching one does not exist
      {
        res.value = .{ .ptr = store_ptr };
        def.log( .TRACE, 0, @src(), "Registered ComponentStore {s} in ComponentRegistry", .{ name });
      }
      else
      {
        def.log( .DEBUG, 0, @src(), "Cannot register ComponentStore {s} in ComponentRegistry : key already in use", .{ name } );
      }
    }
  }

  pub fn unregister( self : *ComponentRegistry, name : []const u8 ) void
  {
    if( self.map.remove( name ))
    {
      def.log( .TRACE, 0, @src(), "Unregistered ComponentStore {s} from ComponentRegistry", .{ name });
    }
    else
    {
      def.log( .DEBUG, 0, @src(), "Cannot unregister ComponentStore {s} from ComponentRegistry : key not found", .{ name });
    }
  }

  pub fn get( self : *ComponentRegistry, name : []const u8 ) ?*anyopaque
  {
    if ( self.map.get( name )) | e |
    {
      return e.ptr;
    }
    else
    {
      def.log( .DEBUG, 0, @src(), "Cannot get ComponentStore {s} from ComponentRegistry : key not found", .{ name } );
    }
    return null;
  }
};


pub fn initComponentStore( comptime ComponentType : type ) type
{
  return struct
  {
    const TypeName = @typeName( ComponentType );
    const ComponentStoreType = @This();


    data : std.AutoHashMap( EntityId, ComponentType ),


    pub fn init( alloc : std.mem.Allocator ) ComponentStoreType
    {
      def.log( .INFO, 0, @src(), "Initializing ComponentStore of type {s}", .{ TypeName });
      return .{ .data = std.AutoHashMap( EntityId, ComponentType ).init( alloc )};
    }

    pub fn deinit( self : *ComponentStoreType ) void
    {
      def.log( .INFO, 0, @src(), "Deinitializing ComponentStore of type {s}", .{ TypeName });
      self.data.deinit();
    }

    pub fn add( self : *ComponentStoreType, id : EntityId, value : ComponentType ) void
    {
      if( self.map.getOrPut( id ) catch unreachable )| res | // TODO : handle unreachable
      {
        if( !res.found_existing ) // Initialize Component instance if one does not exist for this Entity
        {
          res.value = value;
          def.log( .TRACE, 0, @src(), "Added Entity {d} to ComponentStore of type {s}", .{ id, TypeName });
        }
        else
        {
          def.log( .DEBUG, 0, @src(), "Cannot add Entity {d} to ComponentStore of type {s} : key already in use", .{ id, TypeName });
        }
      }
    }

    pub fn remove( self : *ComponentStoreType, id: EntityId ) void
    {
      if( self.data.remove( id ))
      {
        def.log( .TRACE, 0, @src(), "Removed Entity {d} from ComponentStore of type {s}", .{ id, TypeName });
      }
      else
      {
        def.log( .DEBUG, 0, @src(), "Cannot removed Entity {d} from ComponentStore of type {s} : key not found", .{ id, TypeName });
      }
    }

    pub fn get( self : *ComponentStoreType, id: EntityId ) ?*ComponentType
    {
      if( self.map.get( id )) | *c |
      {
        return c;
      }
      else
      {
        def.log( .TRACE, 0, @src(), "Cannot find Entity {d} in ComponentStore of type {s}", .{ id, TypeName });
      }
      return null;
    }

    pub fn iterator( self : *ComponentStoreType ) @TypeOf( self.data.iterator() )
    {
      def.log( .TRACE, 0, @src(), "generating Iterator for ComponentStore of type {s}", .{ TypeName });
      return self.data.iterator();
    }
  };
}