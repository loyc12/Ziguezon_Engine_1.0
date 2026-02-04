const std = @import( "std" );
const def = @import( "defs" );

const EntityId   = def.EntityId;

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
  isInit : bool = false,


  pub fn init( self : *ComponentRegistry, alloc : std.mem.Allocator ) void
  {
    def.qlog( .TRACE, 0, @src(), "# Initializing component registry..." );

    if( self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "ComponentRegistry is already initialized : returning" );
      return;
    }

    self.data = .init( alloc );
    self.isInit = true;

    def.qlog( .INFO, 0, @src(), "& ComponentRegistry initialized !" );
  }

  pub fn deinit( self : *ComponentRegistry ) void
  {
    def.qlog( .TRACE, 0, @src(), "# Deinitializing component registry..." );

    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "ComponentRegistry is uninitialized : returning" );
      return;
    }

    self.data.deinit();
    self.isInit = false;

    def.qlog( .INFO, 0, @src(), "& ComponentRegistry denitialized !" );
  }

  pub fn register( self : *ComponentRegistry, name : []const u8, storePtr : *anyopaque ) bool
  {
    // storePtr is a pointer to an instance of a ComponentStore
    // this ptr is then wrapped in a generic RegistryEntry
    // ComponentStore is user-managed, and of a type generated via componentStoreFactory()

    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "Cannot register in ComponentRegistry : uninitialized" );
      return false;
    }

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
    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "Cannot unregister from ComponentRegistry : uninitialized" );
      return false;
    }

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

  // NOTE : REQUIRES MANUAL ALLIGMENT OF RETURNED PTR VIA "@ptrCast( @alignCast( .get() ))""
  pub fn get( self : *ComponentRegistry, name : []const u8 ) ?*anyopaque
  {
    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "Cannot obtain from ComponentRegistry : uninitialized" );
      return null;
    }

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
    if( !self.isInit )
    {
      def.qlog( .WARN, 0, @src(), "Cannot peer into ComponentRegistry : uninitialized" );
      return false;
    }

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
    isInit : bool = false,


    pub fn init( self : *ComponentStore, alloc : std.mem.Allocator ) void
    {
      def.log( .INFO, 0, @src(), "Initializing ComponentStore for type {s}", .{ TypeName });

      if( self.isInit )
      {
        def.log( .WARN, 0, @src(), "ComponentStore for type {s} is already initialized : returning", .{ TypeName } );
        return;
      }

      self.data = .init( alloc );
      self.isInit = true;
    }

    pub fn deinit( self : *ComponentStore ) void
    {
      def.log( .INFO, 0, @src(), "Deinitializing ComponentStore for type {s}", .{ TypeName });

      if( self.isInit )
      {
        def.log( .WARN, 0, @src(), "ComponentStore for type {s} is unnitialized : returning", .{ TypeName } );
        return;
      }

      self.data.deinit();
      self.isInit = false;
    }

    pub fn add( self : *ComponentStore, id : EntityId, value : ComponentType ) bool
    {
      if( !self.isInit )
      {
        def.log( .WARN, 0, @src(), "Cannot add to ComponentStore for type {s} : uninitialized", .{ TypeName } );
        return false;
      }

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
      if( !self.isInit )
      {
        def.log( .WARN, 0, @src(), "Cannot remove from ComponentStore for type {s} : uninitialized", .{ TypeName } );
        return false;
      }
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
      if( !self.isInit )
      {
        def.log( .WARN, 0, @src(), "Cannot obtain from ComponentStore for type {s} : uninitialized", .{ TypeName } );
        return null;
      }
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
      if( !self.isInit )
      {
        def.log( .WARN, 0, @src(), "Cannot Cannot peer into ComponentStore for type {s} : uninitialized", .{ TypeName } );
        return false;
      }
      if( self.data.getPtr( id ) != null ){ return true; }
      return false;
    }

    pub fn iterator( self : *ComponentStore ) @TypeOf( self.data.iterator() ){ return self.data.iterator(); }
  };
}