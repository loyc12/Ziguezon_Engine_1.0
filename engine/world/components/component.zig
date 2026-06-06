// REWORK NOTE: Replace the string-keyed, anyopaque registry and single hash-map
// store with the generic component-table foundation used through World.
// User-defined components must support typed access and selectable dense/sparse
// storage policies while remaining data-first and lifecycle-aware.

const std = @import( "std" );
const utl = @import( "utils" );

const entity = @import( "../entity.zig" );

const EntityId = entity.EntityId;

// ================ COMPONENT STORE POLICY ================

pub const CompStorePolicy = enum
{
  SPARSE,
  DENSE,
};

pub fn getCompStorePolicy( comptime CompType : type ) CompStorePolicy
{
  if( !@hasDecl( CompType, "storeType" )){ return .SPARSE; }

  const policy : CompStorePolicy = CompType.storeType;
  return policy;
}


// ================ BORROWED COMPONENT REGISTRY ================

// NOTE: BorrowedCompRegistry does NOT own CompStore lifetimes
//       Stores must be initialized and deinitialized externally


pub const BorrowedCompRegistry = struct
{
  // Wrapper around the underlying compStoreType
  const RegistryEntry = struct
  {
    storePtr : *anyopaque, // Points to an anonymous CompStore instance
  };

  data   : std.StringHashMap( RegistryEntry ) = undefined,
  isInit : bool = false,


  pub fn init( self : *BorrowedCompRegistry, alloc : std.mem.Allocator ) void
  {
    utl.qlog( .TRACE, 0, @src(), "# Initializing component registry..." );

    if( self.isInit )
    {
      utl.qlog( .WARN, 0, @src(), "BorrowedCompRegistry is already initialized : returning" );
      return;
    }

    self.data = .init( alloc );
    self.isInit = true;

    utl.qlog( .INFO, 0, @src(), "& BorrowedCompRegistry initialized !" );
  }

  pub fn deinit( self : *BorrowedCompRegistry ) void
  {
    utl.qlog( .TRACE, 0, @src(), "# Deinitializing component registry..." );

    if( !self.isInit )
    {
      utl.qlog( .WARN, 0, @src(), "BorrowedCompRegistry is uninitialized : returning" );
      return;
    }

    self.data.deinit();
    self.isInit = false;

    utl.qlog( .INFO, 0, @src(), "$ BorrowedCompRegistry deinitialized !" );
  }

  pub fn register( self : *BorrowedCompRegistry, name : []const u8, storePtr : *anyopaque ) bool
  {
    // storePtr is a pointer to an instance of a CompStore
    // this ptr is then wrapped in a generic RegistryEntry
    // CompStore is user-managed, and of a type generated via CompStoreFactory()

    if( !self.isInit )
    {
      utl.qlog( .WARN, 0, @src(), "@ Cannot register in BorrowedCompRegistry : uninitialized" );
      return false;
    }

    const result = self.data.getOrPut( name ) catch { return false; }; // TODO : handle catch properly
    {
      if( !result.found_existing ) // Initialize RegistryEntry instance if a matching one does not exist
      {
        result.value_ptr.*.storePtr = storePtr;
        utl.log( .TRACE, 0, @src(), "Registered CompStore {s} in BorrowedCompRegistry", .{ name });
        return true;
      }
      else
      {
        utl.log( .WARN, 0, @src(), "@ Cannot register CompStore {s} in BorrowedCompRegistry : key already in use", .{ name } );
        return false;
      }
    }
  }

  pub fn unregister( self : *BorrowedCompRegistry, name : []const u8 ) bool
  {
    if( !self.isInit )
    {
      utl.qlog( .WARN, 0, @src(), "@ Cannot unregister from BorrowedCompRegistry : uninitialized" );
      return false;
    }

    if( self.data.remove( name ))
    {
      utl.log( .TRACE, 0, @src(), "Unregistered CompStore {s} from BorrowedCompRegistry", .{ name });
      return true;
    }
    else
    {
      utl.log( .DEBUG, 0, @src(), "Cannot unregister CompStore {s} from BorrowedCompRegistry : key not found", .{ name });
      return false;
    }
  }

  // NOTE : REQUIRES MANUAL ALLIGMENT OF RETURNED PTR VIA "@ptrCast( @alignCast( .get() ))""
  pub fn get( self : *BorrowedCompRegistry, name : []const u8 ) ?*anyopaque
  {
    if( !self.isInit )
    {
      utl.qlog( .WARN, 0, @src(), "Cannot obtain from BorrowedCompRegistry : uninitialized" );
      return null;
    }

    if ( self.data.getPtr( name )) | ptr |
    {
      return ptr.storePtr; // Accessing the Wrapped value
    }
    else
    {
      utl.log( .DEBUG, 0, @src(), "Cannot get CompStore {s} from BorrowedCompRegistry : key not found", .{ name } );
    }
    return null;
  }

  pub fn has( self : *BorrowedCompRegistry, name : []const u8 ) bool
  {
    if( !self.isInit )
    {
      utl.qlog( .WARN, 0, @src(), "Cannot peer into BorrowedCompRegistry : uninitialized" );
      return false;
    }

    if( self.data.getPtr( name ) != null ){ return true; }
    return false;
  }
};


// ================ COMPONENT STORE FUNCTIONS ================

pub fn CompStoreFactory( comptime CompType : type ) type
{
  return struct
  {
    const TypeName = @typeName( CompType ); // NOTE : FOR LOGGING ONLY
    const CompStore = @This();


    data : std.AutoHashMap( EntityId, CompType ) = undefined,
    isInit : bool = false,


    pub fn init( self : *CompStore, alloc : std.mem.Allocator ) void
    {
      utl.log( .INFO, 0, @src(), "Initializing CompStore for type {s}", .{ TypeName });

      if( self.isInit )
      {
        utl.log( .WARN, 0, @src(), "CompStore for type {s} is already initialized : returning", .{ TypeName } );
        return;
      }

      self.data = .init( alloc );
      self.isInit = true;
    }

    pub fn deinit( self : *CompStore ) void
    {
      utl.log( .INFO, 0, @src(), "Deinitializing CompStore for type {s}", .{ TypeName });

      if( !self.isInit )
      {
        utl.log( .WARN, 0, @src(), "CompStore for type {s} is unnitialized : returning", .{ TypeName } );
        return;
      }

      self.data.deinit();
      self.isInit = false;
    }

    pub fn add( self : *CompStore, id : EntityId, value : CompType ) bool
    {
      if( !self.isInit )
      {
        utl.log( .WARN, 0, @src(), "Cannot add to CompStore for type {s} : uninitialized", .{ TypeName } );
        return false;
      }

      const result = self.data.getOrPut( id ) catch { return false; }; // TODO : handle catch properly
      {
        if( !result.found_existing ) // Initialize Comp instance if one does not exist for this Entity
        {
          result.value_ptr.* = value;
          utl.log( .TRACE, 0, @src(), "Added Entity {d} to CompStore for type {s}", .{ id, TypeName });
          return true;
        }
        else
        {
          utl.log( .WARN, 0, @src(), "Cannot add Entity {d} to CompStore for type {s} : key already in use", .{ id, TypeName });
          return false;
        }
      }
    }

    pub fn remove( self : *CompStore, id: EntityId ) bool
    {
      if( !self.isInit )
      {
        utl.log( .WARN, 0, @src(), "Cannot remove from CompStore for type {s} : uninitialized", .{ TypeName } );
        return false;
      }
      if( self.data.remove( id ))
      {
        utl.log( .TRACE, 0, @src(), "Removed Entity {d} from CompStore for type {s}", .{ id, TypeName });
        return true;
      }
      else
      {
        utl.log( .DEBUG, 0, @src(), "Cannot removed Entity {d} from CompStore for type {s} : key not found", .{ id, TypeName });
        return false;
      }
    }

    pub fn get( self : *CompStore, id: EntityId ) ?*CompType
    {
      if( !self.isInit )
      {
        utl.log( .WARN, 0, @src(), "Cannot obtain from CompStore for type {s} : uninitialized", .{ TypeName } );
        return null;
      }
      if( self.data.getPtr( id )) | ptr |
      {
        return ptr;
      }
      else
      {
        utl.log( .WARN, 0, @src(), "Cannot find entity with id {d} in CompStore for type {s}", .{ id, TypeName });
      }
      return null;
    }

    pub fn has( self : *CompStore, id: EntityId ) bool
    {
      if( !self.isInit )
      {
        utl.log( .WARN, 0, @src(), "Cannot Cannot peer into CompStore for type {s} : uninitialized", .{ TypeName } );
        return false;
      }
      if( self.data.getPtr( id ) != null ){ return true; }
      return false;
    }

    pub fn iterator( self : *CompStore ) @TypeOf( self.data.iterator() ){ return self.data.iterator(); }
  };
}
