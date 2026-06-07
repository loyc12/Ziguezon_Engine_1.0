const std = @import( "std" );


// ================================ VALUE CASTING ================================

// Keeps public functions flexible while centralizing range and signedness checks.
fn castFieldValue( comptime FieldType : type, value : anytype ) FieldType
{
  const ValueType = @TypeOf( value );

  switch( @typeInfo( ValueType ))
  {
    .int =>
    {
      if( @typeInfo( ValueType ).int.signedness == .signed )
      {
        @compileError( "BitField only supports unsigned integer values" );
      }
      return @as( FieldType, @intCast( value ));
    },
    .comptime_int =>
    {
      if( value < 0 ){ @compileError( "BitField only supports unsigned integer values" ); }
      return @as( FieldType, @intCast( value ));
    },
    .@"enum" =>
    {
      const TagType = @typeInfo( ValueType ).@"enum".tag_type;
      if( @typeInfo( TagType ).int.signedness == .signed )
      {
        @compileError( "BitField only supports enums with unsigned tag types" );
      }
      return @as( FieldType, @intCast( @intFromEnum( value )));
    },
    else => @compileError( "BitField only supports unsigned integers and enums" ),
  }
}


// ================================ BITFIELD FACTORY ================================

pub fn BitFieldFactory( comptime fieldBitCount : comptime_int ) type
{
  if( fieldBitCount <= 0 )
  {
    @compileError( "BitFieldFactory requires a positive non-zero integer bit count" );
  }
  if( fieldBitCount > 256 )
  {
    @compileError( "BitFieldFactory bit count cannot be above 256" );
  }

  // Builds the backing integer as uN, where N is the requested bit count.
  const GenFieldType = @Type( .{ .int = .{ .signedness = .unsigned, .bits = @intCast( fieldBitCount )}});

  // IndexType is only wide enough to address valid bit positions in FieldType.
  const GenIndexType = std.math.IntFittingRange( 0, fieldBitCount - 1 );

  return struct
  {
    pub const FieldType : type = GenFieldType;
    pub const IndexType : type = GenIndexType;

    const Self = @This();

    bitField : FieldType = 0,


    // ================ TYPE HELPERS ================

    pub inline fn getIntType() type { return FieldType; }
    pub inline fn getIdxType() type { return IndexType; }

    // Converts a zero-based bit index into a one-bit mask.
    pub inline fn indexToBitFlag( index : IndexType ) FieldType
    {
      return @as( FieldType, 1 ) << index;
    }

    // Returns null when the mask is zero or contains more than one bit.
    pub inline fn bitFlagToIndex( bitFlag : FieldType ) ?IndexType
    {
      if( bitFlag == 0 or ( bitFlag & ( bitFlag - 1 )) != 0 ){ return null; }
      return @intCast( @ctz( bitFlag ));
    }


    // ================ INITIALIZATION ================

    // Accepts unsigned integers or unsigned-tag enums, then narrows to FieldType.
    pub inline fn new( bitField : anytype ) Self
    {
      return .{ .bitField = castFieldValue( FieldType, bitField ) };
    }


    // ================ QUERIES ================

    pub inline fn hasBitFlag( self : *const Self, bitFlag : FieldType ) bool
    {
      return bitFlagToIndex( bitFlag ) != null and self.hasAllFlags( bitFlag );
    }

    pub inline fn hasFlag( self : *const Self, bitFlag : FieldType ) bool
    {
      return self.hasBitFlag( bitFlag );
    }

    pub inline fn hasAnyFlags( self : *const Self, bitFlags : FieldType ) bool
    {
      return ( self.bitField & bitFlags ) != 0;
    }
    pub inline fn hasAllFlags( self : *const Self, bitFlags : FieldType ) bool
    {
      return ( self.bitField & bitFlags ) == bitFlags;
    }


    // ================ MUTATORS ================

    // Singular methods are for one-bit flags; plural methods accept masks.
    pub inline fn setBitFlag( self : *Self, bitFlag : FieldType, value : bool ) void
    {
      if( value ){ self.addFlag( bitFlag ); }
      else {       self.delFlag( bitFlag ); }
    }
    pub inline fn setAllFlags( self : *Self, bitFlags : FieldType ) void
    {
      self.bitField = bitFlags;
    }


    pub inline fn addFlag( self : *Self, bitFlag : FieldType ) void
    {
      self.addFlags( bitFlag );
    }
    pub inline fn addFlags( self : *Self, bitFlags : FieldType ) void
    {
      self.bitField |= bitFlags;
    }

    pub inline fn delFlag( self : *Self, bitFlag : FieldType ) void
    {
      self.delFlags( bitFlag );
    }
    pub inline fn delFlags( self : *Self, bitFlags : FieldType ) void
    {
      self.bitField &= ~bitFlags;
    }

    pub inline fn filterField( self : *Self, filter : anytype ) void
    {
      self.bitField &= castFieldValue( FieldType, filter );
    }
  };
}


// ================================ COMMON BITFIELD TYPES ================================

pub const Bfd4   = BitFieldFactory( 4  );
pub const Bfd8   = BitFieldFactory( 8  );
pub const Bfd16  = BitFieldFactory( 16 );
pub const Bfd32  = BitFieldFactory( 32 );
pub const Bfd64  = BitFieldFactory( 64 );
pub const Bfd128 = BitFieldFactory( 128 );
pub const Bfd256 = BitFieldFactory( 256 );


// ================================ TESTS ================================

test "BitFieldFactory creates mutating bitfields"
{
  var flags = Bfd8.new( 0 );

  flags.addFlag( Bfd8.indexToBitFlag( 1 ));
  try std.testing.expect( flags.hasFlag(     0b00000010 ));
  try std.testing.expect( flags.hasBitFlag(  0b00000010 ));
  try std.testing.expect( !flags.hasBitFlag( 0b00000011 ));

  flags.addFlags( 0b00001100 );
  try std.testing.expect( flags.hasAnyFlags( 0b00000100 ));
  try std.testing.expect( flags.hasAllFlags( 0b00001110 ));

  flags.delFlag( 0b00000010 );
  try std.testing.expect( !flags.hasAnyFlags( 0b00000010 ));

  flags.filterField( 0b00001000 );
  try std.testing.expectEqual( @as( u8, 0b00001000 ), flags.bitField );
}

test "BitFieldFactory sizes index type from bit count"
{
  try std.testing.expectEqual( @as( usize, 8  ), @bitSizeOf( Bfd8.FieldType ));
  try std.testing.expectEqual( @as( usize, 3  ), @bitSizeOf( Bfd8.IndexType ));
  try std.testing.expectEqual( @as( usize, 64 ), @bitSizeOf( Bfd64.FieldType ));
  try std.testing.expectEqual( @as( usize, 6  ), @bitSizeOf( Bfd64.IndexType ));
  try std.testing.expectEqual( @as( usize, 128 ), @bitSizeOf( Bfd128.FieldType ));
  try std.testing.expectEqual( @as( usize, 7   ), @bitSizeOf( Bfd128.IndexType ));
  try std.testing.expectEqual( @as( usize, 256 ), @bitSizeOf( Bfd256.FieldType ));
  try std.testing.expectEqual( @as( usize, 8   ), @bitSizeOf( Bfd256.IndexType ));
}
