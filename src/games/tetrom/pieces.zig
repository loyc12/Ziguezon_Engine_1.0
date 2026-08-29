const utl = @import( "utils" );

const Coords2 = utl.Coords2;

/// Axial hex coordinate used for piece geometry and rotation layouts.
pub const HexCoord = struct
{
  q : i32 = 0,
  r : i32 = 0,

  pub inline fn new( q : i32, r : i32 ) HexCoord { return .{ .q = q, .r = r }; }

  pub inline fn add( self : HexCoord, other : HexCoord ) HexCoord { return .new( self.q + other.q, self.r + other.r ); }

  /// Converts axial coordinates into the legacy tilemap's `.HEX2` offset coordinates.
  pub fn toBoardCoords( self : HexCoord ) Coords2
  {
    const parity    = @mod( self.q, 2 );
    const rowOffset = @divFloor( self.q + parity, 2 );

    return .{ .x = self.q, .y = self.r + rowOffset };
  }

  pub fn fromBoardCoords( coords : Coords2 ) HexCoord
  {
    const parity    = @mod( coords.x, 2 );
    const rowOffset = @divFloor( coords.x + parity, 2 );

    return .new( coords.x, coords.y - rowOffset );
  }
};

/// The ten one-sided tetrahexes. Mirrors are distinct, rotations are not.
pub const PieceKind = enum( u4 )
{
  P01, P02, P03, P04, P05,
  P06, P07, P08, P09, P10,

  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  pub inline fn getIndex( self : PieceKind ) i32 { return @intFromEnum( self ); }

  pub inline fn fromIndex( index : i32 ) PieceKind { return @enumFromInt( @mod( index, @as( i32, @intCast( count )))); }
};

pub const Rotation = enum( u3 )
{
  R0, R1, R2, R3, R4, R5,

  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  pub inline fn getIndex( self : Rotation ) i32 { return @intFromEnum( self ); }

  pub inline fn fromIndex( index : i32 ) Rotation { return @enumFromInt( @mod( index, @as( i32, @intCast( count )))); }
};

/// Four axial offsets. The tables preserve each rotated shape; the central
/// placement anchor is selected from the cells, rather than being baked in.
pub const PieceLayout = struct
{
  cells       : [ 4 ]HexCoord,
  anchorIndex : ?usize = null,

  /// Prefer the most connected cell. When equally central cells exist, choose
  /// the lower one so rotation cannot make the piece appear to fall farther.
  pub fn getAnchorIndex( self : *const PieceLayout ) usize
  {
    if( self.anchorIndex )| index |{ return index; }

    var anchorIndex : usize = 0;
    var bestNeighbours : u8 = 0;

    for( self.cells, 0 .. )| cell, index |
    {
      var neighbours : u8 = 0;

      for( self.cells )| other |
      {
        if( isAdjacent( cell, other )){ neighbours += 1; }
      }

      const isLower = cell.toBoardCoords().y >  self.cells[ anchorIndex ].toBoardCoords().y;
      const isLeft  = cell.toBoardCoords().y == self.cells[ anchorIndex ].toBoardCoords().y and cell.q < self.cells[ anchorIndex ].q;

      if( neighbours > bestNeighbours or ( neighbours == bestNeighbours and ( isLower or isLeft )))
      {
        anchorIndex    = index;
        bestNeighbours = neighbours;
      }
    }

    return anchorIndex;
  }

  pub inline fn getAnchorCell( self : *const PieceLayout ) HexCoord
  {
    return self.cells[ self.getAnchorIndex() ];
  }
};

fn isAdjacent( first : HexCoord, second : HexCoord ) bool
{
  const deltaQ = second.q - first.q;
  const deltaR = second.r - first.r;

  return ( deltaQ ==  0 and deltaR == -1 ) or
         ( deltaQ ==  1 and deltaR == -1 ) or
         ( deltaQ ==  1 and deltaR ==  0 ) or
         ( deltaQ ==  0 and deltaR ==  1 ) or
         ( deltaQ == -1 and deltaR ==  1 ) or
         ( deltaQ == -1 and deltaR ==  0 );
}

pub const PieceDef = struct
{
  layouts : [ Rotation.count ]PieceLayout,
};

/// Returns all six explicitly-authored layouts for one tetrahex kind.
pub fn getDef( kind : PieceKind ) *const PieceDef
{
  return switch( kind )
  {
    .P01 => &P01, .P02 => &P02, .P03 => &P03, .P04 => &P04, .P05 => &P05,
    .P06 => &P06, .P07 => &P07, .P08 => &P08, .P09 => &P09, .P10 => &P10,
  };
}

const P01 = PieceDef{ .layouts = .{
  .{ .cells = .{ .new(  0, -3 ), .new(  0, -2 ), .new(  0, -1 ), .new(  0,  0 ) } },
  .{ .cells = .{ .new(  3, -3 ), .new(  2, -2 ), .new(  1, -1 ), .new(  0,  0 ) } },
  .{ .cells = .{ .new(  0,  0 ), .new( -1,  0 ), .new( -2,  0 ), .new( -3,  0 ) } },
  .{ .cells = .{ .new(  0,  0 ), .new(  0, -1 ), .new(  0, -2 ), .new(  0, -3 ) } },
  .{ .cells = .{ .new(  0,  0 ), .new(  1, -1 ), .new(  2, -2 ), .new(  3, -3 ) } },
  .{ .cells = .{ .new( -3,  0 ), .new( -2,  0 ), .new( -1,  0 ), .new(  0,  0 ) } },
}};

const P02 = PieceDef{ .layouts = .{
  .{ .cells = .{ .new(  0, -2 ), .new(  0, -1 ), .new(  0,  0 ), .new(  1, -3 ) }, .anchorIndex = 0 },
  .{ .cells = .{ .new(  2, -2 ), .new(  1, -1 ), .new(  0,  0 ), .new(  3, -2 ) }, .anchorIndex = 0 },
  .{ .cells = .{ .new(  0, -1 ), .new( -1, -1 ), .new( -2, -1 ), .new(  0,  0 ) }, .anchorIndex = 0 },
  .{ .cells = .{ .new(  1, -1 ), .new(  1, -2 ), .new(  1, -3 ), .new(  0,  0 ) } },
  .{ .cells = .{ .new(  0,  0 ), .new(  1, -1 ), .new(  2, -2 ), .new( -1,  0 ) } },
  .{ .cells = .{ .new( -2,  0 ), .new( -1,  0 ), .new(  0,  0 ), .new( -2, -1 ) }, .anchorIndex = 0 },
}};

const P03 = PieceDef{ .layouts = .{
  .{ .cells = .{ .new(  0, -2 ), .new(  0, -1 ), .new(  0,  0 ), .new(  1, -2 ) } },
  .{ .cells = .{ .new(  0, -1 ), .new( -1,  0 ), .new( -2,  1 ), .new(  0,  0 ) } },
  .{ .cells = .{ .new(  1, -1 ), .new(  0, -1 ), .new( -1, -1 ), .new(  0,  0 ) } },
  .{ .cells = .{ .new(  0,  0 ), .new(  0, -1 ), .new(  0, -2 ), .new( -1,  0 ) } },
  .{ .cells = .{ .new(  0,  0 ), .new(  1, -1 ), .new(  2, -2 ), .new(  0, -1 ) } },
  .{ .cells = .{ .new( -2,  0 ), .new( -1,  0 ), .new(  0,  0 ), .new( -1, -1 ) } },
}};

const P04 = PieceDef{ .layouts = .{
  .{ .cells = .{ .new(  0, -2 ), .new(  0, -1 ), .new(  0,  0 ), .new(  1, -1 ) } },
  .{ .cells = .{ .new(  1, -2 ), .new(  0, -1 ), .new( -1,  0 ), .new(  0,  0 ) } },
  .{ .cells = .{ .new(  0,  0 ), .new( -1,  0 ), .new( -2,  0 ), .new( -2,  1 ) } },
  .{ .cells = .{ .new(  0,  0 ), .new(  0, -1 ), .new(  0, -2 ), .new( -1, -1 ) } },
  .{ .cells = .{ .new(  0,  0 ), .new(  1, -1 ), .new(  2, -2 ), .new(  1, -2 ) } },
  .{ .cells = .{ .new( -2,  0 ), .new( -1,  0 ), .new(  0,  0 ), .new(  0, -1 ) } },
}};

const P05 = PieceDef{ .layouts = .{
  .{ .cells = .{ .new( -1, -2 ), .new( -1, -1 ), .new( -1,  0 ), .new(  0,  0 ) } },
  .{ .cells = .{ .new(  2, -3 ), .new(  1, -2 ), .new(  0, -1 ), .new(  0,  0 ) } },
  .{ .cells = .{ .new(  0,  0 ), .new( -1,  0 ), .new( -2,  0 ), .new( -3,  1 ) }, .anchorIndex = 2 },
  .{ .cells = .{ .new(  0,  0 ), .new(  0, -1 ), .new(  0, -2 ), .new( -1, -2 ) }, .anchorIndex = 2 },
  .{ .cells = .{ .new(  0,  0 ), .new(  1, -1 ), .new(  2, -2 ), .new(  2, -3 ) }, .anchorIndex = 2 },
  .{ .cells = .{ .new( -2,  0 ), .new( -1,  0 ), .new(  0,  0 ), .new(  1, -1 ) }, .anchorIndex = 2 },
}};

const P06 = PieceDef{ .layouts = .{
  .{ .cells = .{ .new(  0, -1 ), .new(  0,  0 ), .new(  1, -3 ), .new(  1, -2 ) } },
  .{ .cells = .{ .new( -1,  0 ), .new( -2,  1 ), .new(  1, -1 ), .new(  0,  0 ) }, .anchorIndex = 3 },
  .{ .cells = .{ .new( -1, -1 ), .new( -2, -1 ), .new(  0,  0 ), .new( -1,  0 ) } },
  .{ .cells = .{ .new(  1, -2 ), .new(  1, -3 ), .new(  0,  0 ), .new(  0, -1 ) } },
  .{ .cells = .{ .new(  0,  0 ), .new(  1, -1 ), .new( -2,  1 ), .new( -1,  0 ) }, .anchorIndex = 0 },
  .{ .cells = .{ .new( -1,  0 ), .new(  0,  0 ), .new( -2, -1 ), .new( -1, -1 ) } },
}};

const P07 = PieceDef{ .layouts = .{
  .{ .cells = .{ .new(  0, -1 ), .new(  0,  0 ), .new(  1, -2 ), .new(  1, -1 ) } },
  .{ .cells = .{ .new(  0, -1 ), .new( -1,  0 ), .new(  1, -1 ), .new(  0,  0 ) } },
  .{ .cells = .{ .new(  0, -1 ), .new( -1, -1 ), .new(  0,  0 ), .new( -1,  0 ) } },
  .{ .cells = .{ .new(  1, -1 ), .new(  1, -2 ), .new(  0,  0 ), .new(  0, -1 ) } },
  .{ .cells = .{ .new(  0,  0 ), .new(  1, -1 ), .new( -1,  0 ), .new(  0, -1 ) } },
  .{ .cells = .{ .new( -1,  0 ), .new(  0,  0 ), .new( -1, -1 ), .new(  0, -1 ) } },
}};

const P08 = PieceDef{ .layouts = .{
  .{ .cells = .{ .new( -1, -1 ), .new( -1,  0 ), .new(  0, -2 ), .new(  0,  0 ) } },
  .{ .cells = .{ .new(  1, -2 ), .new(  0, -1 ), .new(  2, -2 ), .new(  0,  0 ) } },
  .{ .cells = .{ .new(  0, -1 ), .new( -1, -1 ), .new(  0,  0 ), .new( -2,  0 ) }, .anchorIndex = 0 },
  .{ .cells = .{ .new(  1, -1 ), .new(  1, -2 ), .new(  0,  0 ), .new(  0, -2 ) } },
  .{ .cells = .{ .new(  0,  0 ), .new(  1, -1 ), .new( -1,  0 ), .new(  1, -2 ) } },
  .{ .cells = .{ .new( -1,  0 ), .new(  0,  0 ), .new( -1, -1 ), .new(  1, -1 ) }, .anchorIndex = 1 },
}};

const P09 = PieceDef{ .layouts = .{
  .{ .cells = .{ .new( -1, -2 ), .new( -1, -1 ), .new(  0, -1 ), .new(  0,  0 ) }, .anchorIndex = 2 },
  .{ .cells = .{ .new(  2, -3 ), .new(  1, -2 ), .new(  1, -1 ), .new(  0,  0 ) } },
  .{ .cells = .{ .new(  0,  0 ), .new( -1,  0 ), .new( -2,  1 ), .new( -3,  1 ) } },
  .{ .cells = .{ .new(  0,  0 ), .new(  0, -1 ), .new( -1, -1 ), .new( -1, -2 ) }, .anchorIndex = 1 },
  .{ .cells = .{ .new(  0,  0 ), .new(  1, -1 ), .new(  1, -2 ), .new(  2, -3 ) } },
  .{ .cells = .{ .new( -3,  1 ), .new( -2,  1 ), .new( -1,  0 ), .new(  0,  0 ) } },
}};

const P10 = PieceDef{ .layouts = .{
  .{ .cells = .{ .new( -2,  1 ), .new( -1, -1 ), .new( -1,  0 ), .new(  0,  0 ) } },
  .{ .cells = .{ .new( -1, -1 ), .new(  1, -2 ), .new(  0, -1 ), .new(  0,  0 ) } },
  .{ .cells = .{ .new( -1, -1 ), .new(  0,  0 ), .new( -1,  0 ), .new( -2,  1 ) } },
  .{ .cells = .{ .new(  1, -2 ), .new(  0,  0 ), .new(  0, -1 ), .new( -1, -1 ) } },
  .{ .cells = .{ .new(  0,  0 ), .new( -2,  1 ), .new( -1,  0 ), .new( -1, -1 ) } },
  .{ .cells = .{ .new(  0,  0 ), .new( -1, -1 ), .new(  0, -1 ), .new(  1, -2 ) } },
}};
