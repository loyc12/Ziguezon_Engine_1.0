const std = @import( "std" );
const def = @import( "defs" );

const EntityId   = def.EntityId;
const IdRegistry = def.IdRegistry;



// NOTE: ComponentRegistry does NOT own ComponentStore lifetimes
//       Stores must be initialized and deinitialized externally

pub const ComponentRegistry = struct
{
  // Wrapper around the underlying componentStoreType
  const RegistryEntry = struct
  {
    storePtr : *anyopaque, // Points to an anonymous ComponentStore instance
  };

  data   : std.StringHashMap( RegistryEntry ) = undefined,
  idReg  : IdRegistry = .{},
  isInit : bool = false,


  pub fn init( self : *ComponentRegistry, alloc : std.mem.Allocator ) void
  {
    def.qlog( .TRACE, 0, @src(), "# Initializing component registry..." );
    self.data = .init( alloc );
    self.isInit = true;
    def.qlog( .INFO, 0, @src(), "& Component registry initialized !" );
  }

  pub fn deinit( self : *ComponentRegistry ) void
  {
    def.qlog( .TRACE, 0, @src(), "# Deinitializing component registry..." );
    self.data.deinit();
    self.isInit = false;
    def.qlog( .INFO, 0, @src(), "& Component registry denitialized !" );
  }

  pub fn register( self : *ComponentRegistry, name : []const u8, storePtr : *anyopaque ) bool
  {
    // storePtr is a pointer to an instance of a ComponentStore
    // this ptr is then wrapped in a generic RegistryEntry
    // ComponentStore is user-managed, and of a type generated via componentStoreFactory()

    const res = self.data.getOrPut( name ) catch { return false; }; // TODO : handle catch properly
    {
      if( !res.found_existing ) // Initialize RegistryEntry instance if a matching one does not exist
      {
        res.value_ptr.*.storePtr = storePtr;
        def.log( .TRACE, 0, @src(), "Registered ComponentStore {s} in ComponentRegistry", .{ name });
        return true;
      }
      else
      {
        def.log( .WARN, 0, @src(), "Cannot register ComponentStore {s} in ComponentRegistry : key already in use", .{ name } );
        return false;
      }
    }
  }

  pub fn unregister( self : *ComponentRegistry, name : []const u8 ) bool
  {
    if( self.data.remove( name ))
    {
      def.log( .TRACE, 0, @src(), "Unregistered ComponentStore {s} from ComponentRegistry", .{ name });
      return true;
    }
    else
    {
      def.log( .DEBUG, 0, @src(), "Cannot unregister ComponentStore {s} from ComponentRegistry : key not found", .{ name });
      return false;
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


    data : std.AutoHashMap( EntityId, ComponentType ) = undefined,


    pub fn init( self : *ComponentStore, alloc : std.mem.Allocator ) void
    {
      def.log( .INFO, 0, @src(), "Initializing ComponentStore for type {s}", .{ TypeName });
      self.data = .init( alloc );
    }

    pub fn deinit( self : *ComponentStore ) void
    {
      def.log( .INFO, 0, @src(), "Deinitializing ComponentStore for type {s}", .{ TypeName });
      self.data.deinit();
    }

    pub fn add( self : *ComponentStore, id : EntityId, value : ComponentType ) bool
    {
      const res = self.data.getOrPut( id ) catch { return false; }; // TODO : handle catch properly
      {
        if( !res.found_existing ) // Initialize Component instance if one does not exist for this Entity
        {
          res.value_ptr.* = value;
          def.log( .TRACE, 0, @src(), "Added Entity {d} to ComponentStore for type {s}", .{ id, TypeName });
          return true;
        }
        else
        {
          def.log( .WARN, 0, @src(), "Cannot add Entity {d} to ComponentStore for type {s} : key already in use", .{ id, TypeName });
          return false;
        }
      }
    }

    pub fn remove( self : *ComponentStore, id: EntityId ) bool
    {
      if( self.data.remove( id ))
      {
        def.log( .TRACE, 0, @src(), "Removed Entity {d} from ComponentStore for type {s}", .{ id, TypeName });
        return true;
      }
      else
      {
        def.log( .DEBUG, 0, @src(), "Cannot removed Entity {d} from ComponentStore for type {s} : key not found", .{ id, TypeName });
        return false;
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
        def.log( .WARN, 0, @src(), "Cannot find entity with id {d} in ComponentStore for type {s}", .{ id, TypeName });
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