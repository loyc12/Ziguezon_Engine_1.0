const std = @import( "std" );
const utl = @import( "utils" );

const comp     = @import( "../components/component.zig" );
const EntityId = @import( "../entity.zig" ).EntityId;

// `CompView` stays intentionally component-only. Broad World inspection belongs
// in `queries/query.zig`, while this file remains the narrow fast path for
// repeated access to a known set of component stores.

fn StoreTupleType( comptime CompTypes : anytype ) type
{
  const fields = std.meta.fields( @TypeOf( CompTypes ));

  comptime var storeTypes : [ fields.len ]type = undefined;
  inline for( fields, 0.. )| field, index |
  {
    const CompType = @field( CompTypes, field.name );
    storeTypes[ index ] = *comp.CompStoreFactory( CompType );
  }

  return std.meta.Tuple( &storeTypes );
}

fn validateCompTypes( comptime CompTypes : anytype ) void
{
  const fields = std.meta.fields( @TypeOf( CompTypes ));

  inline for( fields, 0.. )| fieldA, indexA |
  {
    const CompTypeA = @field( CompTypes, fieldA.name );

    inline for( fields, 0.. )| fieldB, indexB |
    {
      if( indexB <= indexA ){ continue; }

      const CompTypeB = @field( CompTypes, fieldB.name );
      if( CompTypeA == CompTypeB )
      {
        @compileError( "ComponentView cannot contain duplicate component type " ++ @typeName( CompTypeA ));
      }
    }
  }
}


/// Typed helper that caches several component stores for repeated access.
/// Use `World.getCompView(.{ CompA, CompB })` to construct it from games.
pub fn CompView( comptime CompTypes : anytype ) type
{
  validateCompTypes( CompTypes );

  return struct
  {
    const View = @This();

    /// Tuple of typed store pointers matching the requested component types.
    pub const StoreTuple = StoreTupleType( CompTypes );

    stores     : StoreTuple,
    generation : u64,


    /// Builds a view if every requested component store is registered.
    /// Returns null when any store is missing.
    pub fn init( world : anytype ) ?View
    {
      const fields = std.meta.fields( @TypeOf( CompTypes ));

      var stores : StoreTuple = undefined;
      inline for( fields )| field |
      {
        const CompType = @field( CompTypes, field.name );
        @field( stores, field.name ) = world.getCompStore( CompType ) orelse
        {
          utl.log( .WARN, @src(), "Cannot build ComponentView : CompStore for type {s} is not registered", .{ @typeName( CompType )});
          return null;
        };
      }

      return .{
        .stores     = stores,
        .generation = world.getCompViewGeneration(),
      };
    }

    /// Validates that cached store pointers are still valid.
    /// Does not guarantee previously fetched component pointers are still valid.
    pub inline fn isStillValid( self : *const View, world : anytype ) bool
    {
      return self.generation == world.getCompViewGeneration();
    }

    /// Returns the cached store for one component type included in this view.
    pub fn getStore( self : *View, comptime CompType : type ) *comp.CompStoreFactory( CompType )
    {
      const fields = std.meta.fields( @TypeOf( CompTypes ));

      inline for( fields )| field |
      {
        const ViewCompType = @field( CompTypes, field.name );
        if( ViewCompType == CompType ){ return @field( self.stores, field.name ); }
      }

      @compileError( "ComponentView does not contain component type " ++ @typeName( CompType ));
    }

    /// Returns the cached store as read-only for one component type in this view.
    pub fn getConstStore( self : *const View, comptime CompType : type ) *const comp.CompStoreFactory( CompType )
    {
      const fields = std.meta.fields( @TypeOf( CompTypes ));

      inline for( fields )| field |
      {
        const ViewCompType = @field( CompTypes, field.name );
        if( ViewCompType == CompType ){ return @field( self.stores, field.name ); }
      }

      @compileError( "ComponentView does not contain component type " ++ @typeName( CompType ));
    }

    /// Looks up a component row through the cached store.
    pub inline fn get( self : *View, comptime CompType : type, id : EntityId ) ?*CompType
    {
      return self.getStore( CompType ).get( id );
    }

    /// Looks up a read-only component row through the cached store.
    pub inline fn getConst( self : *const View, comptime CompType : type, id : EntityId ) ?*const CompType
    {
      return self.getConstStore( CompType ).getConst( id );
    }

    /// Tests whether an entity has the component row in the cached store.
    pub inline fn has( self : *const View, comptime CompType : type, id : EntityId ) bool
    {
      return self.getConstStore( CompType ).has( id );
    }

    /// Returns the iterator for one cached component store.
    pub inline fn getIterator( self : *View, comptime CompType : type ) @TypeOf( self.getStore( CompType ).iterator() )
    {
      return self.getStore( CompType ).iterator();
    }

    /// Returns the read-only iterator for one cached component store.
    pub inline fn getConstIterator( self : *const View, comptime CompType : type ) @TypeOf( self.getConstStore( CompType ).iteratorConst() )
    {
      return self.getConstStore( CompType ).iteratorConst();
    }
  };
}


test "CompView caches typed stores and exposes point lookup"
{
  const worldCore = @import( "../core/world.zig" );

  const TransComp = struct
  {
    pub const compStorePolicy : comp.CompStorePolicy = .PACKED;

    value : u32 = 0,
  };
  const FlagComp = struct
  {
    pub const compStorePolicy : comp.CompStorePolicy = .SPARSE;

    value : bool = true,
  };

  var world : worldCore.World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect( world.registerComp( TransComp ));
  try std.testing.expect( world.registerComp( FlagComp  ));

  const entityId = world.createEntity().id;
  try std.testing.expect( world.addComp( TransComp, entityId, .{ .value = 42 }));
  try std.testing.expect( world.addComp( FlagComp,  entityId, .{} ));

  var view = CompView( .{ TransComp, FlagComp }).init( &world ).?;

  try std.testing.expect( view.isStillValid( &world ));
  try std.testing.expect( view.get( TransComp, entityId ).?.value == 42 );
  try std.testing.expect( view.has( FlagComp,  entityId ));
}

test "CompView validity tracks world store generation"
{
  const worldCore = @import( "../core/world.zig" );

  const TransComp = struct
  {
    pub const compStorePolicy : comp.CompStorePolicy = .PACKED;

    value : u32 = 0,
  };
  const FlagComp = struct
  {
    pub const compStorePolicy : comp.CompStorePolicy = .SPARSE;

    value : bool = true,
  };

  var world : worldCore.World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect( world.registerComp( TransComp ));
  try std.testing.expect( world.registerComp( FlagComp  ));

  const entityId = world.createEntity().id;
  try std.testing.expect( world.addComp( TransComp, entityId, .{ .value = 42 }));

  var view = CompView( .{ TransComp, FlagComp }).init( &world ).?;
  try std.testing.expect( view.isStillValid( &world ));

  try std.testing.expect( world.addComp( FlagComp, entityId, .{} ));
  try std.testing.expect( view.isStillValid( &world ));

  try std.testing.expect( world.unregisterComp( FlagComp ));
  try std.testing.expect( !view.isStillValid( &world ));

  try std.testing.expect( world.registerComp( FlagComp ));
  var freshView = CompView( .{ TransComp, FlagComp }).init( &world ).?;
  try std.testing.expect( freshView.isStillValid( &world ));
}
