const std = @import( "std" );


pub fn newDataGrid( comptime DataType : type, comptime RowEnum : type, comptime ColumnEnum : type ) type
{
  comptime // Validate enums
  {
    if( @typeInfo( RowEnum    ) != .@"enum" ){ @compileError( "RowEnum must be an enum" ); }
    if( @typeInfo( ColumnEnum ) != .@"enum" ){ @compileError( "ColumnEnum must be an enum" ); }
  }

  const rowLen = @typeInfo( RowEnum    ).@"enum".fields.len;
  const colLen = @typeInfo( ColumnEnum ).@"enum".fields.len;


  return struct
  {

    const SelfType = @This();

    // NOTE : Row can be easily sliced, Columns are harder to iterate over without original struct
    data : [ rowLen ][ colLen ]DataType = undefined,


    pub fn initFrom( newData : [ rowLen ][ colLen ]DataType ) SelfType
    {
      var grid : SelfType = .{};

      inline for( 0..colLen )| col |{ inline for( 0..colLen )| row |
      {
        const rowPos : usize = @intFromEnum( row );
        const colPos : usize = @intFromEnum( col );

        grid.data[ rowPos ][ colPos ] = newData[ rowPos ][ colPos ];
      }}

      return grid;
    }

    pub fn fillWith( self : *SelfType, value : DataType ) void
    {
      inline for( 0..colLen )| col |{ inline for( 0..colLen )| row |
      {
        self.data[ @intFromEnum( row )][ @intFromEnum( col )] = value;
      }}
    }

    pub inline fn set( self : *SelfType, row : RowEnum, col : ColumnEnum, value : DataType ) void
    {
      self.data[ @intFromEnum( row )][ @intFromEnum( col )] = value;
    }

    pub inline fn get( self : *const SelfType, row : RowEnum, col : ColumnEnum ) DataType
    {
      return self.data[ @intFromEnum( row )][ @intFromEnum( col )];
    }

    pub inline fn ptr( self : *SelfType, row : RowEnum, col : ColumnEnum ) *DataType
    {
      return &self.data[ @intFromEnum( row )][ @intFromEnum( col )];
    }


    pub inline fn getRowSliceC( self : *const SelfType, row : RowEnum ) []const DataType
    {
      return self.getRowSliceM( row );
    }

    pub inline fn getRowSliceM( self : *SelfType, row : RowEnum ) []DataType
    {
      return self.data[ @intFromEnum( row )][ 0..rowLen ];
    }
  };
}