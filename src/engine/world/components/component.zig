// REWORK NOTE: Replace the string-keyed, anyopaque registry and single hash-map
// store with the generic component-table foundation used through World.
// User-defined components must support typed access and selectable packed/sparse
// storage policies while remaining data-first and lifecycle-aware.

const pckdStore = @import( "storeTypes/packedStore.zig"  );
const sprsStore = @import( "storeTypes/sparseStore.zig" );

// ================ COMPONENT STORE POLICY ================

pub const CompStorePolicy = enum
{
//DIRECT, // future raw EntityId-indexed array storage
  PACKED, // arrayList storage with EntityId-to-row index
  SPARSE, // hashmap storage
};

// Use a config struct when component stores need multiple independent policies.
// pub const CompStoreConfig = struct
// {
//   storePolicy : CompStorePolicy = .PACKED,
// };

pub fn getCompStorePolicy( comptime CompType : type ) CompStorePolicy
{
  if( !@hasDecl( CompType, "compStorePolicy" ))
  {
    @compileError( "Component type " ++ @typeName( CompType ) ++ " must declare : pub const compStorePolicy : eng.CompStorePolicy = <ENUM>" );
  }

  const  policy : CompStorePolicy = CompType.compStorePolicy;
  return policy;
}


// ================ COMPONENT STORE FUNCTIONS ================

pub fn CompStoreFactory( comptime CompType : type ) type
{
  if( @sizeOf( CompType ) == 0 )
  {
    @compileError( "Component type " ++ @typeName( CompType ) ++ " has zero size. Empty marker components are not supported by component stores; use trait system or an explicit game-owned id lists ." );
  }

  return switch( getCompStorePolicy( CompType ))
  {
  //.DIRECT => direct.DirectCompStoreFactory( CompType ),
    .PACKED => pckdStore.PackedCompStoreFactory( CompType ),
    .SPARSE => sprsStore.SparseCompStoreFactory( CompType ),
  };
}
