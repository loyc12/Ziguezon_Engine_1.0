const std = @import( "std" );


pub fn GenDataMatrix4( comptime DataType : type, comptime Enum1 : type, comptime Enum2 : type, comptime Enum3 : type, comptime Enum4 : type ) type
{
  comptime // Validate enums
  {
    if( @typeInfo( Enum1 ) != .@"enum" ){ @compileError( "Enum1 must be an enum" ); }
    if( @typeInfo( Enum2 ) != .@"enum" ){ @compileError( "Enum2 must be an enum" ); }
    if( @typeInfo( Enum3 ) != .@"enum" ){ @compileError( "Enum3 must be an enum" ); }
    if( @typeInfo( Enum4 ) != .@"enum" ){ @compileError( "Enum4 must be an enum" ); }
  }

  return struct
  {
    const SelfType = @This();

    const len1 = @typeInfo( Enum1 ).@"enum".fields.len;
    const len2 = @typeInfo( Enum2 ).@"enum".fields.len;
    const len3 = @typeInfo( Enum3 ).@"enum".fields.len;
    const len4 = @typeInfo( Enum4 ).@"enum".fields.len;


    data : [ len1 ][ len2 ][ len3 ][ len4 ]DataType = undefined,


    pub fn initFrom( newData : [ len1 ][ len2 ][ len3 ][ len4 ]DataType ) SelfType
    {
      var matrix : SelfType = .{};

      inline for( 0..len4 )| e4 |{ inline for( 0..len3 )| e3 |{ inline for( 0..len2 )| e2 |{ inline for( 0..len1 )| e1 |
      {
        matrix.data[ e1 ][ e2 ][ e3 ][ e4 ] = newData[ e1 ][ e2 ][ e3 ][ e4 ];
      }}}}

      return matrix;
    }

    pub fn fillWith( self : *SelfType, value : DataType ) void
    {
      inline for( 0..len4 )| e4 |{ inline for( 0..len3 )| e3 |{ inline for( 0..len2 )| e2 |{ inline for( 0..len1 )| e1 |
      {
        self.data[ e1 ][ e2 ][ e3 ][ e4 ] = value;
      }}}}
    }

    pub inline fn zero( self : *SelfType, e1 : Enum1, e2 : Enum2, e3 : Enum3, e4 : Enum4 ) void
    {
      self.data[ @intFromEnum( e1 )][ @intFromEnum( e2 )][ @intFromEnum( e3 )][ @intFromEnum( e4 )] = 0;
    }
    pub inline fn set( self : *SelfType, e1 : Enum1, e2 : Enum2, e3 : Enum3, e4 : Enum4, value : DataType ) void
    {
      self.data[ @intFromEnum( e1 )][ @intFromEnum( e2 )][ @intFromEnum( e3 )][ @intFromEnum( e4 )] = value;
    }
    pub inline fn add( self : *SelfType, e1 : Enum1, e2 : Enum2, e3 : Enum3, e4 : Enum4, value : DataType ) void
    {
      self.data[ @intFromEnum( e1 )][ @intFromEnum( e2 )][ @intFromEnum( e3 )][ @intFromEnum( e4 )] += value;
    }
    pub inline fn sub( self : *SelfType, e1 : Enum1, e2 : Enum2, e3 : Enum3, e4 : Enum4, value : DataType ) void
    {
      self.data[ @intFromEnum( e1 )][ @intFromEnum( e2 )][ @intFromEnum( e3 )][ @intFromEnum( e4 )] -= value;
    }
    pub inline fn mul( self : *SelfType, e1 : Enum1, e2 : Enum2, e3 : Enum3, e4 : Enum4, value : DataType ) void
    {
      self.data[ @intFromEnum( e1 )][ @intFromEnum( e2 )][ @intFromEnum( e3 )][ @intFromEnum( e4 )] *= value;
    }
    pub inline fn div( self : *SelfType, e1 : Enum1, e2 : Enum2, e3 : Enum3, e4 : Enum4, value : DataType ) void
    {
      switch( @typeInfo( @TypeOf( value )))
      {
        .float, .comptime_float =>
        {
          std.debug.assert( value != 0.0 );
          self.data[ @intFromEnum( e1 )][ @intFromEnum( e2 )][ @intFromEnum( e3 )][ @intFromEnum( e4 )] /= value;
        },
        .int, .comptime_int =>
        {
          std.debug.assert( value != 0 );
          self.data[ @intFromEnum( e1 )][ @intFromEnum( e2 )][ @intFromEnum( e3 )][ @intFromEnum( e4 )] /= value;
        },
        else => @compileError( "div() only supports Int and Float types" ),
      }
    }

    pub inline fn get( self : *const SelfType, e1 : Enum1, e2 : Enum2, e3 : Enum3, e4 : Enum4 ) DataType
    {
      return self.data[ @intFromEnum( e1 )][ @intFromEnum( e2 )][ @intFromEnum( e3 )][ @intFromEnum( e4 )];
    }

    pub inline fn ptr( self : *SelfType, e1 : Enum1, e2 : Enum2, e3 : Enum3, e4 : Enum4 ) *DataType
    {
      return &self.data[ @intFromEnum( e1 )][ @intFromEnum( e2 )][ @intFromEnum( e3 )][ @intFromEnum( e4 )];
    }

    // TODO : Add a way to convert any pair of axis to a dataMatrix
  };
}