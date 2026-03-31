const std = @import( "std" );
const def = @import( "defs" );


// ================================ ENUM ASSERTION FUNCTIONS ================================

fn assertIsEnum( comptime T : type ) void
{
  if( @typeInfo( T ) != .@"enum" ){ @compileError( "Expected an enum type, got " ++ @typeName( T )); }
}

fn assertIsExhaustiveEnum( comptime T : type ) void
{
  assertIsEnum( T );
  if( !@typeInfo( T ).@"enum".is_exhaustive ){ @compileError( "Expected an exhaustive enum, got " ++ @typeName( T )); }
}

fn assertIsEnumContiguousFromZero( comptime T : type ) void
{
  assertIsExhaustiveEnum( T );

  const fields = @typeInfo( T ).@"enum".fields;

  for( fields, 0.. )| f, i |{ if( f.value != i )
  {
    @compileError( "Enum " ++ @typeName( T ) ++ " is not contiguous from zero " ++ std.fmt.comptimePrint( "( field {s} == {} )", .{ f.name, f.value }) );
  }}
}

fn assertIsContiguousEnumWithLen( comptime T : type, comptime len : usize ) void
{
  assertIsEnumContiguousFromZero( T );

  if( @typeInfo( T ).@"enum".fields.len != len )
  {
    @compileError( "Enum " ++ @typeName( T ) ++ " has an invalid field count "  ++ std.fmt.comptimePrint( "( len != {} )", .{ len }) );
  }
}


// ================================ ENUM PAIRING AND UNPAIRING ================================

//  Generates a unique enum for every ( A, B ) combination
//  Field names follow the format "AFieldName_BFieldName"
pub fn GenPairedEnum( comptime A : type, comptime B : type ) type
{
  assertIsEnumContiguousFromZero( A );
  assertIsEnumContiguousFromZero( B );

  const a_fields = @typeInfo( A ).@"enum".fields;
  const b_fields = @typeInfo( B ).@"enum".fields;
  const total    = a_fields.len * b_fields.len;

  if( total == 0 ){ @compileError( "Cannot create paired enum from empty enums" ); }

  var fields : [ total ]std.builtin.Type.EnumField = undefined;

  var i: usize = 0;
  for( a_fields )| af |{ for( b_fields )| bf |
  {
    fields[ i ] = .{ .name = af.name ++ "_" ++ bf.name, .value = i };
    i += 1;
  }}

  const PairedEnum = @Type( .{ .@"enum" =
  .{
    .tag_type      = std.math.IntFittingRange( 0, total - 1 ),
    .fields        = &fields,
    .decls         = &.{},
    .is_exhaustive = true,
  }});

  assertIsContiguousEnumWithLen( PairedEnum, total );

  return PairedEnum;
}

pub fn GenSplitEnum( comptime A : type, comptime B : type ) type
{
  return struct { a : A, b : B };
}


//  Combine two enum values into their composite paired enum value
pub fn pairEnums( comptime A : type, a : A, comptime B : type, b : B ) GenPairedEnum( A, B )
{
  const bCount = @typeInfo( B ).@"enum".fields.len;

  const aIdx : usize = @intFromEnum( a );
  const bIdx : usize = @intFromEnum( b );

  return @enumFromInt(( aIdx * bCount ) + bIdx );
}


//  Extract the two original enum values from a composite paired enum value.
pub fn splitEnums( comptime A : type, comptime B : type, pair : GenPairedEnum( A, B )) GenSplitEnum( A, B )
{
  const pairIdx : usize = @intFromEnum( pair );
  const bCount = @typeInfo( B ).@"enum".fields.len;

  const aEnum : A = @enumFromInt( @divFloor( pairIdx, bCount ));
  const bEnum : B = @enumFromInt( @mod(      pairIdx, bCount ));

  return .{ .a = aEnum, .b = bEnum };
}