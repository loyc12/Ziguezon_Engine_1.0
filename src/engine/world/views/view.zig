const std = @import( "std" );
const utl = @import( "utils" );

const comp = @import( "../components/component.zig" );

const EntityId = @import( "../entity.zig" ).EntityId;


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


pub fn CompView( comptime CompTypes : anytype ) type
{
  validateCompTypes( CompTypes );

  return struct
  {
    const View = @This();

    pub const StoreTuple = StoreTupleType( CompTypes );

    stores     : StoreTuple,
    generation : u64,


    pub fn init( world : anytype ) ?View
    {
      const fields = std.meta.fields( @TypeOf( CompTypes ));

      var stores : StoreTuple = undefined;
      inline for( fields )| field |
      {
        const CompType = @field( CompTypes, field.name );
        @field( stores, field.name ) = world.getCompStore( CompType ) orelse
        {
          utl.log( .WARN, 0, @src(), "Cannot build ComponentView : CompStore for type {s} is not registered", .{ @typeName( CompType )});
          return null;
        };
      }

      return .{
        .stores     = stores,
        .generation = world.getCompViewGeneration(),
      };
    }

    /// Validates that the store pointers are still valid. Does not garrantee component pointers validity
    pub inline fn isStillValid( self : *const View, world : anytype ) bool
    {
      return self.generation == world.getCompViewGeneration();
    }

    pub fn store( self : *View, comptime CompType : type ) *comp.CompStoreFactory( CompType )
    {
      const fields = std.meta.fields( @TypeOf( CompTypes ));

      inline for( fields )| field |
      {
        const ViewCompType = @field( CompTypes, field.name );
        if( ViewCompType == CompType ){ return @field( self.stores, field.name ); }
      }

      @compileError( "ComponentView does not contain component type " ++ @typeName( CompType ));
    }

    pub inline fn get( self : *View, comptime CompType : type, id : EntityId ) ?*CompType
    {
      return self.store( CompType ).get( id );
    }

    pub inline fn has( self : *View, comptime CompType : type, id : EntityId ) bool
    {
      return self.store( CompType ).has( id );
    }

    pub inline fn iterator( self : *View, comptime CompType : type ) @TypeOf( self.store( CompType ).iterator() )
    {
      return self.store( CompType ).iterator();
    }
  };
}


test "CompView caches typed stores and exposes point lookup"
{
  const worldMgr = @import( "../worldManager.zig" );

  const TransComp = struct
  {
    pub const storeType : comp.CompStorePolicy = .DENSE;

    value : u32 = 0,
  };
  const FlagComp = struct
  {
    pub const storeType : comp.CompStorePolicy = .SPARSE;

    value : bool = true,
  };

  var world : worldMgr.World = .{};
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
  const worldMgr = @import( "../worldManager.zig" );

  const TransComp = struct
  {
    pub const storeType : comp.CompStorePolicy = .DENSE;

    value : u32 = 0,
  };
  const FlagComp = struct
  {
    pub const storeType : comp.CompStorePolicy = .SPARSE;

    value : bool = true,
  };

  var world : worldMgr.World = .{};
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
