const std    = @import( "std" );
const def    = @import( "defs" );

// Generates a new BitField of a given size from either an unsigned Int or Enum
fn newBitField( BitFieldType : type, value : anytype ) BitFieldType
{
  const info = @typeInfo( @TypeOf( value ));

  switch( info )
  {
    .int, .comptime_int =>
    {
      if( info.int.signedness == .signed ){ @compileError( "newBitField() only supports unsigned values, doofus" ); }
      return BitFieldType{ .bitField = @as( BitFieldType.getIntType(), @intCast( value ))};
    },
    .@"enum" =>
    {
      const subInfo = @typeInfo( info.@"enum".tag_type );
      if( subInfo.int.signedness == .signed ){ @compileError( "newBitField() only supports unsigned values, doofus" ); }
      return BitFieldType{ .bitField = @as( BitFieldType.getIntType(), @intFromEnum( value ))};
    },
    else => @compileError( "newBitField() only supports unsigned Ints and Enums" ),
  }
}

// Generates a filtered version of a given BitField via either an unsigned Int or Enum
fn filteredBitField( srcField : anytype, filter : anytype ) @TypeOf( srcField )
{
  const BitFieldType = @TypeOf( srcField );
  const info = @typeInfo( @TypeOf( filter ));

  switch( info )
  {
    .int, .comptime_int =>
    {
      if( info.int.signedness == .signed ){ @compileError( "filteredBitField() only supports unsigned filters, doofus" ); }
      return BitFieldType{ .bitField = srcField.bitField | @as( BitFieldType.getIntType(), @intCast( filter ))};
    },
    .@"enum" =>
    {
      const subInfo = @typeInfo( info.@"enum".tag_type );
      if( subInfo.int.signedness == .signed ){ @compileError( "filteredBitField() only supports unsigned filters, doofus" ); }
      return BitFieldType{ .bitField = srcField.bitField | @as( BitFieldType.getIntType(), @intFromEnum( filter ))};
    },
    else => @compileError( "filteredBitField() only supports unsigned Ints and Enums for filters" ),
  }
}


// TODO : check if using an uint & enum( uint ) union for bitflag parameters might be preferable

// ================================ BITFIELD STRUCT DEFS ================================

pub const BitField4 = struct
{
  bitField : u4 = 0b0000,

  pub inline fn getIntType() type { return u4; }
  pub inline fn indexToBitFlag( val : u2 ) u4 { return 1 << val ; }

  pub inline fn new( bitField : anytype ) BitField4 { return newBitField( BitField4, bitField ); }

  pub inline fn hasFlag( self : BitField4, bitFlag : u4 )  bool { return ( self.bitField & bitFlag ) != 0; }
  pub inline fn setFlag( self : BitField4, bitFlag : u4, value : bool ) BitField4
  {
    if( value ){ return self.addFlag( bitFlag ); }
    else {       return self.delFlag( bitFlag ); }
  }
  pub inline fn addFlag( self : BitField4, bitFlag : u4 ) BitField4 { return .{ .bitField = self.bitField |  bitFlag }; }
  pub inline fn delFlag( self : BitField4, bitFlag : u4 ) BitField4 { return .{ .bitField = self.bitField & ~bitFlag }; }

  pub inline fn filterField( self : BitField4, filter : anytype ) BitField4 { return filteredBitField( self, filter ); }
};


pub const BitField8 = struct
{
  bitField : u8 = 0b00000000,

  pub inline fn getIntType() type { return u8; }
  pub inline fn indexToBitFlag( val : u3 ) u8 { return 1 << val ; }

  pub inline fn new( bitField : anytype ) BitField8 { return newBitField( BitField8, bitField ); }

  pub inline fn hasFlag( self : BitField8, bitFlag : u8 )  bool { return ( self.bitField & bitFlag ) != 0; }
  pub inline fn setFlag( self : BitField8, bitFlag : u8, value : bool ) BitField8
  {
    if( value ){ return self.addFlag( bitFlag ); }
    else {       return self.delFlag( bitFlag ); }
  }
  pub inline fn addFlag( self : BitField8, bitFlag : u8 ) BitField8 { return .{ .bitField = self.bitField |  bitFlag }; }
  pub inline fn delFlag( self : BitField8, bitFlag : u8 ) BitField8 { return .{ .bitField = self.bitField & ~bitFlag }; }

  pub inline fn filterField( self : BitField8, filter : anytype ) BitField8 { return filteredBitField( self, filter ); }
};


pub const BitField16 = struct
{
  bitField : u16 = 0b00000000_00000000,

  pub inline fn getIntType() type { return u16; }
  pub inline fn indexToBitFlag( val : u4 ) u16 { return 1 << val ; }

  pub inline fn new( bitField : anytype ) BitField16 { return newBitField( BitField16, bitField ); }

  pub inline fn hasFlag( self : BitField16, bitFlag : u16 )  bool { return ( self.bitField & bitFlag ) != 0; }
  pub inline fn setFlag( self : BitField16, bitFlag : u16, value : bool ) BitField16
  {
    if( value ){ return self.addFlag( bitFlag ); }
    else {       return self.delFlag( bitFlag ); }
  }
  pub inline fn addFlag( self : BitField16, bitFlag : u16 ) BitField16 { return .{ .bitField = self.bitField |  bitFlag }; }
  pub inline fn delFlag( self : BitField16, bitFlag : u16 ) BitField16 { return .{ .bitField = self.bitField & ~bitFlag }; }

  pub inline fn filterField( self : BitField16, filter : anytype ) BitField16 { return filteredBitField( self, filter ); }
};


pub const BitField32 = struct
{
  bitField : u32 = 0b00000000_00000000_00000000_00000000,

  pub inline fn getIntType() type { return u32; }
  pub inline fn indexToBitFlag( val : u5 ) u32 { return 1 << val ; }

  pub inline fn new( bitField : anytype ) BitField32 { return newBitField( BitField32, bitField ); }

  pub inline fn hasFlag( self : BitField32, bitFlag : u32 )  bool { return ( self.bitField & bitFlag ) != 0; }
  pub inline fn setFlag( self : BitField32, bitFlag : u32, value : bool ) BitField32
  {
    if( value ){ return self.addFlag( bitFlag ); }
    else {       return self.delFlag( bitFlag ); }
  }
  pub inline fn addFlag( self : BitField32, bitFlag : u32 ) BitField32 { return .{ .bitField = self.bitField |  bitFlag }; }
  pub inline fn delFlag( self : BitField32, bitFlag : u32 ) BitField32 { return .{ .bitField = self.bitField & ~bitFlag }; }

  pub inline fn filterField( self : BitField32, filter : anytype ) BitField32 { return filteredBitField( self, filter ); }
};