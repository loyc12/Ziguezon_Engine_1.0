// REWORK NOTE: Replace the string-keyed, anyopaque registry and single hash-map
// store with the generic component-table foundation used through World.
// User-defined components must support typed access and selectable dense/sparse
// storage policies while remaining data-first and lifecycle-aware.

const dense  = @import( "storeTypes/denseStore.zig"  );
const sparse = @import( "storeTypes/sparseStore.zig" );

// ================ COMPONENT STORE POLICY ================

pub const CompStorePolicy = enum
{
  SPARSE,
  DENSE,
};

pub fn getCompStorePolicy( comptime CompType : type ) CompStorePolicy
{
  if( !@hasDecl( CompType, "storeType" ))
  {
    @compileError( "Component type " ++ @typeName( CompType ) ++ " must declare : pub const storeType : eng.CompStorePolicy = .DENSE or .SPARSE" );
  }

  const policy : CompStorePolicy = CompType.storeType;
  return policy;
}


// ================ COMPONENT STORE FUNCTIONS ================

pub fn CompStoreFactory( comptime CompType : type ) type
{
  if( @sizeOf( CompType ) == 0 )
  {
    @compileError( "Component type " ++ @typeName( CompType ) ++ " has zero size. Empty marker components are not supported by component stores yet; use explicit game-owned id lists or wait for a tag store policy." );
  }

  return switch( getCompStorePolicy( CompType ))
  {
    .DENSE  => dense.DenseCompStoreFactory(   CompType ),
    .SPARSE => sparse.SparseCompStoreFactory( CompType ),
  };
}
