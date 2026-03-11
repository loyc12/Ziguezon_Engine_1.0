const std = @import( "std" );


pub fn newDataMatrix( comptime DataType : type, comptime RowEnum : type, comptime ColumnEnum : type, comptime LayerEnum : type ) type
{
  comptime // Validate enums
  {
    if( @typeInfo( RowEnum    ) != .@"enum" ){ @compileError( "RowEnum must be an enum"    ); }
    if( @typeInfo( ColumnEnum ) != .@"enum" ){ @compileError( "ColumnEnum must be an enum" ); }
    if( @typeInfo( LayerEnum  ) != .@"enum" ){ @compileError( "LayerEnum must be an enum"  ); }
  }

  const rowLen = @typeInfo( RowEnum    ).@"enum".fields.len;
  const colLen = @typeInfo( ColumnEnum ).@"enum".fields.len;
  const layLen = @typeInfo( LayerEnum  ).@"enum".fields.len;


  return struct
  {

    const SelfType = @This();

    // NOTE : Row can be easily sliced, Columns and Layers are harder to iterate over without original struct
    data : [ rowLen ][ colLen ][ layLen ]DataType = undefined,


    pub fn initFrom( newData : [ rowLen ][ colLen ][ layLen ]DataType ) SelfType
    {
      var matrix : SelfType = .{};

      inline for( 0..layLen )| lay |{ inline for( 0..colLen )| col |{ inline for( 0..colLen )| row |
      {
        const rowPos : usize = @intFromEnum( row );
        const colPos : usize = @intFromEnum( col );
        const layPos : usize = @intFromEnum( lay );

        matrix.data[ rowPos ][ colPos ][ layPos ] = newData[ rowPos ][ colPos ][ layPos ];
      }}}

      return matrix;
    }

    pub fn fillWith( self : *SelfType, value : DataType ) void
    {
      inline for( 0..layLen )| lay |{ inline for( 0..colLen )| col |{ inline for( 0..colLen )| row |
      {
        self.data[ @intFromEnum( row )][ @intFromEnum( col )][ @intFromEnum( lay )] = value;
      }}}
    }

    pub inline fn set( self : *SelfType, row : RowEnum, col : ColumnEnum, lay : LayerEnum, value : DataType ) void
    {
      self.data[ @intFromEnum( row )][ @intFromEnum( col )][ @intFromEnum( lay )] = value;
    }

    pub inline fn get( self : *const SelfType, row : RowEnum, col : ColumnEnum, lay : LayerEnum ) DataType
    {
      return self.data[ @intFromEnum( row )][ @intFromEnum( col )][ @intFromEnum( lay )];
    }

    pub inline fn ptr( self : *SelfType, row : RowEnum, col : ColumnEnum, lay : LayerEnum ) *DataType
    {
      return &self.data[ @intFromEnum( row )][ @intFromEnum( col )][ @intFromEnum( lay )];
    }

    // TODO : Add a way to convert any pair of axis to a dataGrid
  };
}