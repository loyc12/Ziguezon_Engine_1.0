const std = @import( "std" );


pub fn GenDataCube( comptime DataType : type, comptime RowEnum : type, comptime ColumnEnum : type, comptime LayerEnum : type ) type
{
  comptime // Validate enums
  {
    if( @typeInfo( RowEnum    ) != .@"enum" ){ @compileError( "RowEnum must be an enum"    ); }
    if( @typeInfo( ColumnEnum ) != .@"enum" ){ @compileError( "ColumnEnum must be an enum" ); }
    if( @typeInfo( LayerEnum  ) != .@"enum" ){ @compileError( "LayerEnum must be an enum"  ); }
  }

  return struct
  {
    const SelfType = @This();

    const rowLen = @typeInfo( RowEnum    ).@"enum".fields.len;
    const colLen = @typeInfo( ColumnEnum ).@"enum".fields.len;
    const layLen = @typeInfo( LayerEnum  ).@"enum".fields.len;

    // NOTE : Row can be easily sliced, Columns and Layers are harder to iterate over without original struct
    data : [ rowLen ][ colLen ][ layLen ]DataType = undefined,


    pub fn initFrom( newData : [ rowLen ][ colLen ][ layLen ]DataType ) SelfType
    {
      var matrix : SelfType = .{};

      inline for( 0..layLen )| lay |{ inline for( 0..colLen )| col |{ inline for( 0..rowLen )| row |
      {
        matrix.data[ row ][ col ][ lay ] = newData[ row ][ col ][ lay ];
      }}}

      return matrix;
    }

    pub fn fillWith( self : *SelfType, value : DataType ) void
    {
      inline for( 0..layLen )| lay |{ inline for( 0..colLen )| col |{ inline for( 0..rowLen )| row |
      {
        self.data[ row ][ col ][ lay ] = value;
      }}}
    }

    pub inline fn zero( self : *SelfType, row : RowEnum, col : ColumnEnum, lay : LayerEnum ) void
    {
      self.data[ @intFromEnum( row )][ @intFromEnum( col )][ @intFromEnum( lay )] = 0;
    }
    pub inline fn set( self : *SelfType, row : RowEnum, col : ColumnEnum, lay : LayerEnum, value : DataType ) void
    {
      self.data[ @intFromEnum( row )][ @intFromEnum( col )][ @intFromEnum( lay )] = value;
    }
    pub inline fn add( self : *SelfType, row : RowEnum, col : ColumnEnum, lay : LayerEnum, value : DataType ) void
    {
      self.data[ @intFromEnum( row )][ @intFromEnum( col )][ @intFromEnum( lay )] += value;
    }
    pub inline fn sub( self : *SelfType, row : RowEnum, col : ColumnEnum, lay : LayerEnum, value : DataType ) void
    {
      self.data[ @intFromEnum( row )][ @intFromEnum( col )][ @intFromEnum( lay )] -= value;
    }
    pub inline fn mul( self : *SelfType, row : RowEnum, col : ColumnEnum, lay : LayerEnum, value : DataType ) void
    {
      self.data[ @intFromEnum( row )][ @intFromEnum( col )][ @intFromEnum( lay )] *= value;
    }
    pub inline fn div( self : *SelfType, row : RowEnum, col : ColumnEnum, lay : LayerEnum, value : DataType ) void
    {
      switch( @typeInfo( @TypeOf( value )))
      {
        .float, .comptime_float =>
        {
          std.debug.assert( value != 0.0 );
          self.data[ @intFromEnum( row )][ @intFromEnum( col )][ @intFromEnum( lay )] /= value;
        },
        .int, .comptime_int =>
        {
          std.debug.assert( value != 0 );
          self.data[ @intFromEnum( row )][ @intFromEnum( col )][ @intFromEnum( lay )] /= value;
        },
        else => @compileError( "div() only supports Int and Float types" ),
      }
    }

    pub inline fn get( self : *const SelfType, row : RowEnum, col : ColumnEnum, lay : LayerEnum ) DataType
    {
      return self.data[ @intFromEnum( row )][ @intFromEnum( col )][ @intFromEnum( lay )];
    }

    pub inline fn ptr( self : *SelfType, row : RowEnum, col : ColumnEnum, lay : LayerEnum ) *DataType
    {
      return &self.data[ @intFromEnum( row )][ @intFromEnum( col )][ @intFromEnum( lay )];
    }

    // TODO : Add a way to convert any pair of axis to a dataMatrix
  };
}