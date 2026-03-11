const std = @import( "std" );


pub fn newDataArray( comptime DataType : type, comptime IdxEnum : type ) type
{
  comptime // Validate enum
  {
    if( @typeInfo( IdxEnum ) != .@"enum" ){ @compileError( "IdxEnum must be an enum" ); }
  }

  const len = @typeInfo( IdxEnum ).@"enum".fields.len;


  return struct
  {
    const SelfType = @This();

    data : [ len ]DataType = undefined,


    pub fn initFrom( newData : [ len ]DataType ) SelfType
    {
      var array : SelfType = .{};

      inline for( 0..len )| idx |
      {
        const pos : usize = @intFromEnum( idx );

        array.data[ pos ] = newData[ pos ];
      }

      return array;
    }

    pub fn fillWith( self : *SelfType, value : DataType ) void
    {
      inline for( 0..len )| idx |
      {
        self.data[ @intFromEnum( idx )] = value;
      }
    }

    pub inline fn set( self : *SelfType, idx : IdxEnum, value : DataType ) void
    {
      self.data[ @intFromEnum( idx )] = value;
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