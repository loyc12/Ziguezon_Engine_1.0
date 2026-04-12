const std = @import( "std" );


pub fn GenDataLine( comptime DataType : type, comptime IdxEnum : type ) type
{
  comptime // Validate enum
  {
    if( @typeInfo( IdxEnum ) != .@"enum" ){ @compileError( "IdxEnum must be an enum" ); }
  }

  return struct
  {
    const SelfType = @This();

    const len = @typeInfo( IdxEnum ).@"enum".fields.len;

    data : [ len ]DataType = undefined,


    pub fn initFrom( newData : [ len ]DataType ) SelfType
    {
      var array : SelfType = .{};

      inline for( 0..len )| idx |
      {
        array.data[ idx ] = newData[ idx ];
      }

      return array;
    }

    pub fn fillWith( self : *SelfType, value : DataType ) void
    {
      inline for( 0..len )| idx |
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


    pub inline fn getSliceC( self : *const SelfType, idx : IdxEnum ) []const DataType
    {
      return self.getSliceM( idx );
    }

    pub inline fn getSliceM( self : *SelfType, idx : IdxEnum ) []DataType
    {
      return self.data[ @intFromEnum( idx )][ 0..len ];
    }
  };
}