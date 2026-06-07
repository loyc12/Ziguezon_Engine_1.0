const std = @import( "std" );
const tpr = @import( "typer.zig" );

const MAX_ENUM_LEN : u32 = 800; // NOTE : Increase if too sever. Never decrease


pub fn GenDataLine( comptime DataType : type, comptime IdxEnum : type ) type
{
  comptime // Validate enum
  {
    tpr.assertIsEnumContiguousOfLenLessThan( IdxEnum, MAX_ENUM_LEN );
  }

  return struct
  {
    const SelfType = @This();

    const len = @typeInfo( IdxEnum ).@"enum".fields.len;

    data : [ len ]DataType = undefined,

    isInit : bool = false,


    pub fn initFrom( newData : [ len ]DataType ) SelfType
    {
      var array : SelfType = .{};

      for( 0..len )| idx |
      {
        array.data[ idx ] = newData[ idx ];
      }

      return array;
    }

    pub fn fillWith( self : *SelfType, value : DataType ) void
    {
      for( 0..len )| idx |
      {
        self.data[ idx ] = value;
      }
    }

    pub inline fn zero( self : *SelfType, idx : IdxEnum ) void
    {
      self.data[ @intFromEnum( idx )] = 0;
    }
    pub inline fn set( self : *SelfType, idx : IdxEnum, value : DataType ) void
    {
      self.data[ @intFromEnum( idx )] = value;
    }
    pub inline fn add( self : *SelfType, idx : IdxEnum, value : DataType ) void
    {
      self.data[ @intFromEnum( idx )] += value;
    }
    pub inline fn sub( self : *SelfType, idx : IdxEnum, value : DataType ) void
    {
      self.data[ @intFromEnum( idx )] -= value;
    }
    pub inline fn mul( self : *SelfType, idx : IdxEnum, value : DataType ) void
    {
      self.data[ @intFromEnum( idx )] *= value;
    }
    pub inline fn div( self : *SelfType, idx : IdxEnum, value : DataType ) void
    {
      switch( @typeInfo( @TypeOf( value )))
      {
        .float, .comptime_float =>
        {
          std.debug.assert( value != 0.0 );
          self.data[ @intFromEnum( idx )] /= value;
        },
        .int, .comptime_int =>
        {
          std.debug.assert( value != 0 );
          self.data[ @intFromEnum( idx )] /= value;
        },
        else => @compileError( "div() only supports Int and Float types" ),
      }
    }

    pub inline fn get( self : *const SelfType, idx : IdxEnum ) DataType
    {
      return self.data[ @intFromEnum( idx )];
    }

    pub inline fn ptr( self : *SelfType, idx : IdxEnum ) *DataType
    {
      return &self.data[ @intFromEnum( idx )];
    }
  };
}