const std = @import( "std" );
const def = @import( "defs" );

const EntityId = def.EntityId;



// NOTE: ComponentRegistry does NOT own ComponentStore lifetimes
//       Stores must be initialized and deinitialized externally

pub const ComponentRegistry = struct
{
  // Wrapper around the underlying componentStoreType
  const RegistryEntry = struct
  {
    storePtr : *anyopaque, // Points to an anonymous ComponentStore instance
  };

  data   : std.StringHashMap( RegistryEntry ),
  isInit : bool = false,


  pub fn init( alloc : std.mem.Allocator ) ComponentRegistry
  {
    def.qlog( .INFO, 0, @src(), "Initializing component registry" );
    return .{ .data = std.StringHashMap( RegistryEntry ).init( alloc ), .isInit = true };
  }

  pub fn deinit( self : *ComponentRegistry ) void
  {
    def.qlog( .INFO, 0, @src(), "Deinitializing component registry" );
    self.data.deinit();
    self.isInit = false;
  }

  pub fn register( self : *ComponentRegistry, name : []const u8, storePtr : *anyopaque ) void
  {
    // storePtr is a pointer to an instance of a ComponentStore
    // this ptr is then wrapped in a generic RegistryEntry

    if( self.data.getOrPut( name ) catch unreachable )| res | // TODO : handle unreachable
    {
      if( !res.found_existing ) // Initialize RegistryEntry instance if a matching one does not exist
      {
        res.value = .{ .storePtr = storePtr };
        def.log( .TRACE, 0, @src(), "Registered ComponentStore {s} in ComponentRegistry", .{ name });
      }
      else
      {
        def.log( .WARN, 0, @src(), "Cannot register ComponentStore {s} in ComponentRegistry : key already in use", .{ name } );
      }
    }
  }

  pub fn unregister( self : *ComponentRegistry, name : []const u8 ) void
  {
    if( self.data.remove( name ))
    {
      def.log( .TRACE, 0, @src(), "Unregistered ComponentStore {s} from ComponentRegistry", .{ name });
    }
    else
    {
      def.log( .DEBUG, 0, @src(), "Cannot unregister ComponentStore {s} from ComponentRegistry : key not found", .{ name });
    }
  }

  // NOTE : REQUIRES MANUAL ALLIGMENT OF RETURNED PTR
  pub fn get( self : *ComponentRegistry, name : []const u8 ) ?*anyopaque
  {
    if ( self.data.getPtr( name )) | ptr |
    {
      return ptr.storePtr; // Accessing the Wrapped value
    }
    else
    {
      def.log( .DEBUG, 0, @src(), "Cannot get ComponentStore {s} from ComponentRegistry : key not found", .{ name } );
    }
    return null;
  }

  pub fn has( self : *ComponentRegistry, name : []const u8 ) bool
  {
    if( self.data.getPtr( name ) != null ){ return true; }
    return false;
  }
};


pub fn componentStoreFactory( comptime ComponentType : type ) type
{
  return struct
  {
    const TypeName = @typeName( ComponentType ); // NOTE : FOR LOGGING ONLY
    const ComponentStore = @This();


    data : std.AutoHashMap( EntityId, ComponentType ),


    pub fn init( alloc : std.mem.Allocator ) ComponentStore
    {
      def.log( .INFO, 0, @src(), "Initializing ComponentStore of type {s}", .{ TypeName });
      return .{ .data = std.AutoHashMap( EntityId, ComponentType ).init( alloc )};
    }

    pub fn deinit( self : *ComponentStore ) void
    {
      def.log( .INFO, 0, @src(), "Deinitializing ComponentStore of type {s}", .{ TypeName });
      self.data.deinit();
    }

    pub fn add( self : *ComponentStore, id : EntityId, value : ComponentType ) void
    {
      if( self.data.getOrPut( id ) catch unreachable )| res | // TODO : handle unreachable
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

    pub fn remove( self : *ComponentStore, id: EntityId ) void
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

    pub fn get( self : *ComponentStore, id: EntityId ) ?*ComponentType
    {
      if( self.data.getPtr( id )) | ptr |
      {
        return ptr;
      }
      else
      {
        def.log( .TRACE, 0, @src(), "Cannot find Entity {d} in ComponentStore of type {s}", .{ id, TypeName });
      }
      return null;
    }

    pub fn has( self : *ComponentStore, id: EntityId ) bool
    {
      if( self.data.getPtr( id ) != null ){ return true; }
      return false;
    }

    pub fn iterator( self : *ComponentStore ) @TypeOf( self.data.iterator() ){ return self.data.iterator(); }
  };
}