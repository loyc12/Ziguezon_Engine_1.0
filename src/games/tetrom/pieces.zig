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
  P00, P01, P02, P03, P04,
  P05, P06, P07, P08, P09,
  P10, P11, P12, P13, P14,

  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  pub inline fn getIndex( self : PieceKind ) i32 { return @intFromEnum( self ); }

  pub inline fn fromIndex( index : i32 ) PieceKind { return @enumFromInt( @mod( index, @as( i32, @intCast( count )))); }

  /// Returns the short human-facing name used by Tetrom's piece catalogue.
  pub fn getName( self : PieceKind ) []const u8
  {
    return switch( self )
    {
      .P00 => "1", .P01 => "2", .P02 => "3", .P03 => "R", .P04 => "A",
      .P05 => "4", .P06 => "L", .P07 => "J", .P08 => "P", .P09 => "B",
      .P10 => "Z", .P11 => "S", .P12 => "D", .P13 => "Y", .P14 => "C",
    };
  }
};

pub const Rotation = enum( u3 )
{
  R0, R1, R2, R3, R4, R5,

  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  pub inline fn getIndex( self : Rotation ) i32 { return @intFromEnum( self ); }

  pub inline fn fromIndex( index : i32 ) Rotation { return @enumFromInt( @mod( index, @as( i32, @intCast( count )))); }

  /// Returns this layout's clockwise angle in the six-direction hex rotation cycle.
  pub fn getName( self : Rotation ) []const u8
  {
    return switch( self )
    {
      .R0 => "0 degrees",   .R1 => "60 degrees",  .R2 => "120 degrees",
      .R3 => "180 degrees", .R4 => "240 degrees", .R5 => "300 degrees",
    };
  }
};

/// Four axial offsets relative to the layout placement anchor at `.new( 0, 0 )`.
/// The P14 / C anchor is intentionally empty: it sits in the centre of its shape.
pub const PieceLayout = struct
{
  cells     : [ 4 ]HexCoord,
  cellCount : u3 = 4,
};

pub const PieceDef = struct
{
  layouts : [ Rotation.count ]PieceLayout,
};

/// Returns all six directional cell layouts for one tetrahex kind.
pub fn getDef( kind : PieceKind ) *const PieceDef
{
  return switch( kind )
  {
    .P00 => &P00, .P01 => &P01, .P02 => &P02, .P03 => &P03, .P04 => &P04,
    .P05 => &P05, .P06 => &P06, .P07 => &P07, .P08 => &P08, .P09 => &P09,
    .P10 => &P10, .P11 => &P11, .P12 => &P12, .P13 => &P13, .P14 => &P14,
  };
}

//  CENTER        TOP             TOP RIGHT       BOT RIGHT       BOTTOM          BOTTOM LEFT     TOP LEFT
// .new( 0, 0 ), .new(  0, -1 ), .new(  1, -1 ), .new(  1,  0 ), .new(  0,  1 ), .new( -1,  1 ), .new( -1,  0 )
// .new( 0, 0 ), .new(  1, -1 ), .new(  1,  0 ), .new(  0,  1 ), .new( -1,  1 ), .new( -1,  0 ), .new(  0, -1 )
// .new( 0, 0 ), .new(  1,  0 ), .new(  0,  1 ), .new( -1,  1 ), .new( -1,  0 ), .new(  0, -1 ), .new(  1, -1 )
// .new( 0, 0 ), .new(  0,  1 ), .new( -1,  1 ), .new( -1,  0 ), .new(  0, -1 ), .new(  1, -1 ), .new(  1,  0 )
// .new( 0, 0 ), .new( -1,  1 ), .new( -1,  0 ), .new(  0, -1 ), .new(  1, -1 ), .new(  1,  0 ), .new(  0,  1 )
// .new( 0, 0 ), .new( -1,  0 ), .new(  0, -1 ), .new(  1, -1 ), .new(  1,  0 ), .new(  0,  1 ), .new( -1,  1 )

// .new( 0, 0 ), .new(  0, -1 ), .new(  1, -1 ), .new(  1,  0 ), .new(  0,  1 ), .new( -1,  1 ), .new( -1,  0 )
// .new( 0, 0 ), .new(  1, -1 ), .new(  1,  0 ), .new(  0,  1 ), .new( -1,  1 ), .new( -1,  0 ), .new(  0, -1 )
// .new( 0, 0 ), .new( -1,  0 ), .new(  0, -1 ), .new(  1, -1 ), .new(  1,  0 ), .new(  0,  1 ), .new( -1,  1 )

// .new( 0, 0 ), .new(  0, -1 ), .new(  1, -1 ), .new(  1,  0 ), .new(  0,  1 ), .new( -1,  1 ), .new( -1,  0 )
// .new( 0, 0 ), .new(  0,  1 ), .new( -1,  1 ), .new( -1,  0 ), .new(  0, -1 ), .new(  1, -1 ), .new(  1,  0 )


const P00 = PieceDef{ .layouts = .{ // 1
  .{ .cells = .{ .new( 0, 0 ), .{}, .{}, .{} }, .cellCount = 1 },
  .{ .cells = .{ .new( 0, 0 ), .{}, .{}, .{} }, .cellCount = 1 },
  .{ .cells = .{ .new( 0, 0 ), .{}, .{}, .{} }, .cellCount = 1 },
  .{ .cells = .{ .new( 0, 0 ), .{}, .{}, .{} }, .cellCount = 1 },
  .{ .cells = .{ .new( 0, 0 ), .{}, .{}, .{} }, .cellCount = 1 },
  .{ .cells = .{ .new( 0, 0 ), .{}, .{}, .{} }, .cellCount = 1 },
}};

const P01 = PieceDef{ .layouts = .{ // 2
  .{ .cells = .{ .new( 0, 0 ), .new(  0, -1 ), .{}, .{} }, .cellCount = 2 },
  .{ .cells = .{ .new( 0, 0 ), .new(  1, -1 ), .{}, .{} }, .cellCount = 2 },
  .{ .cells = .{ .new( 0, 0 ), .new( -1,  0 ), .{}, .{} }, .cellCount = 2 },
  .{ .cells = .{ .new( 0, 0 ), .new(  0, -1 ), .{}, .{} }, .cellCount = 2 },
  .{ .cells = .{ .new( 0, 0 ), .new(  1, -1 ), .{}, .{} }, .cellCount = 2 },
  .{ .cells = .{ .new( 0, 0 ), .new( -1,  0 ), .{}, .{} }, .cellCount = 2 },
}};

const P02 = PieceDef{ .layouts = .{ // 3
  .{ .cells = .{ .new( 0, 0 ), .new(  0, -1 ), .new(  0,  1 ), .{} }, .cellCount = 3 },
  .{ .cells = .{ .new( 0, 0 ), .new(  1, -1 ), .new( -1,  1 ), .{} }, .cellCount = 3 },
  .{ .cells = .{ .new( 0, 0 ), .new(  1,  0 ), .new( -1,  0 ), .{} }, .cellCount = 3 },
  .{ .cells = .{ .new( 0, 0 ), .new(  0,  1 ), .new(  0, -1 ), .{} }, .cellCount = 3 },
  .{ .cells = .{ .new( 0, 0 ), .new( -1,  1 ), .new(  1, -1 ), .{} }, .cellCount = 3 },
  .{ .cells = .{ .new( 0, 0 ), .new( -1,  0 ), .new(  1,  0 ), .{} }, .cellCount = 3 },
}};

const P03 = PieceDef{ .layouts = .{ // R
  .{ .cells = .{ .new( 0, 0 ), .new(  1, -1 ), .new( -1,  0 ), .{} }, .cellCount = 3 },
  .{ .cells = .{ .new( 0, 0 ), .new(  1,  0 ), .new(  0, -1 ), .{} }, .cellCount = 3 },
  .{ .cells = .{ .new( 0, 0 ), .new(  0,  1 ), .new(  1, -1 ), .{} }, .cellCount = 3 },
  .{ .cells = .{ .new( 0, 0 ), .new( -1,  1 ), .new(  1,  0 ), .{} }, .cellCount = 3 },
  .{ .cells = .{ .new( 0, 0 ), .new( -1,  0 ), .new(  0,  1 ), .{} }, .cellCount = 3 },
  .{ .cells = .{ .new( 0, 0 ), .new(  0, -1 ), .new( -1,  1 ), .{} }, .cellCount = 3 },
}};

const P04 = PieceDef{ .layouts = .{ // A
  .{ .cells = .{ .new( 0, 0 ), .new(  1, -1 ), .new(  0, -1 ), .{} }, .cellCount = 3 },
  .{ .cells = .{ .new( 0, 0 ), .new( -1,  0 ), .new(  0, -1 ), .{} }, .cellCount = 3 },
  .{ .cells = .{ .new( 0, 0 ), .new(  1, -1 ), .new(  0, -1 ), .{} }, .cellCount = 3 },
  .{ .cells = .{ .new( 0, 0 ), .new( -1,  0 ), .new(  0, -1 ), .{} }, .cellCount = 3 },
  .{ .cells = .{ .new( 0, 0 ), .new(  1, -1 ), .new(  0, -1 ), .{} }, .cellCount = 3 },
  .{ .cells = .{ .new( 0, 0 ), .new( -1,  0 ), .new(  0, -1 ), .{} }, .cellCount = 3 },
}};

const P05 = PieceDef{ .layouts = .{ // 4
  .{ .cells = .{ .new( 0, 0 ), .new(  0, -1 ), .new(  0,  1 ), .new(  0, -2 )}},
  .{ .cells = .{ .new( 0, 0 ), .new(  1, -1 ), .new( -1,  1 ), .new(  2, -2 )}},
  .{ .cells = .{ .new( 0, 0 ), .new(  1,  0 ), .new( -1,  0 ), .new( -2,  0 )}},
  .{ .cells = .{ .new( 0, 0 ), .new(  0,  1 ), .new(  0, -1 ), .new(  0, -2 )}},
  .{ .cells = .{ .new( 0, 0 ), .new( -1,  1 ), .new(  1, -1 ), .new(  2, -2 )}},
  .{ .cells = .{ .new( 0, 0 ), .new( -1,  0 ), .new(  1,  0 ), .new( -2,  0 )}},
}};

const P06 = PieceDef{ .layouts = .{ // L
  .{ .cells = .{ .new( 0, 0 ), .new(  0, -1 ), .new(  1,  0 ), .new(  0, -2 )}},
  .{ .cells = .{ .new( 0, 0 ), .new(  1, -1 ), .new(  0,  1 ), .new(  2, -2 )}},
  .{ .cells = .{ .new( 0, 0 ), .new(  1,  0 ), .new( -1,  1 ), .new(  2,  0 )}},
  .{ .cells = .{ .new( 0, 0 ), .new(  0,  1 ), .new( -1,  0 ), .new(  0,  2 )}},
  .{ .cells = .{ .new( 0, 0 ), .new( -1,  1 ), .new(  0, -1 ), .new( -2,  2 )}},
  .{ .cells = .{ .new( 0, 0 ), .new( -1,  0 ), .new(  1, -1 ), .new( -2,  0 )}},
}};
const P07 = PieceDef{ .layouts = .{ // J
  .{ .cells = .{ .new( 0, 0 ), .new(  0, -1 ), .new( -1,  1 ), .new(  0, -2 )}},
  .{ .cells = .{ .new( 0, 0 ), .new(  1, -1 ), .new( -1,  0 ), .new(  2, -2 )}},
  .{ .cells = .{ .new( 0, 0 ), .new(  1,  0 ), .new(  0, -1 ), .new(  2,  0 )}},
  .{ .cells = .{ .new( 0, 0 ), .new(  0,  1 ), .new(  1, -1 ), .new(  0,  2 )}},
  .{ .cells = .{ .new( 0, 0 ), .new( -1,  1 ), .new(  1,  0 ), .new( -2,  2 )}},
  .{ .cells = .{ .new( 0, 0 ), .new( -1,  0 ), .new(  0,  1 ), .new( -2,  0 )}},
}};


const P08 = PieceDef{ .layouts = .{ // P
  .{ .cells = .{ .new( 0, 0 ), .new(  0, -1 ), .new(  0,  1 ), .new(  1, -1 )}},
  .{ .cells = .{ .new( 0, 0 ), .new(  1, -1 ), .new( -1,  1 ), .new(  1,  0 )}},
  .{ .cells = .{ .new( 0, 0 ), .new(  1,  0 ), .new( -1,  0 ), .new(  0,  1 )}},
  .{ .cells = .{ .new( 0, 0 ), .new(  0,  1 ), .new(  0, -1 ), .new( -1,  1 )}},
  .{ .cells = .{ .new( 0, 0 ), .new( -1,  1 ), .new(  1, -1 ), .new( -1,  0 )}},
  .{ .cells = .{ .new( 0, 0 ), .new( -1,  0 ), .new(  1,  0 ), .new(  0, -1 )}},
}};
const P09 = PieceDef{ .layouts = .{ // B
  .{ .cells = .{ .new( 0, 0 ), .new(  0, -1 ), .new(  0,  1 ), .new(  1,  0 )}},
  .{ .cells = .{ .new( 0, 0 ), .new(  1, -1 ), .new( -1,  1 ), .new(  0,  1 )}},
  .{ .cells = .{ .new( 0, 0 ), .new(  1,  0 ), .new( -1,  0 ), .new( -1,  1 )}},
  .{ .cells = .{ .new( 0, 0 ), .new(  0,  1 ), .new(  0, -1 ), .new( -1,  0 )}},
  .{ .cells = .{ .new( 0, 0 ), .new( -1,  1 ), .new(  1, -1 ), .new(  0, -1 )}},
  .{ .cells = .{ .new( 0, 0 ), .new( -1,  0 ), .new(  1,  0 ), .new(  1, -1 )}},
}};

const P10 = PieceDef{ .layouts = .{ // Z
  .{ .cells = .{ .new( 0, 0 ), .new(  0, -1 ), .new(  1,  0 ), .new( -1, -1 )}},
  .{ .cells = .{ .new( 0, 0 ), .new(  1, -1 ), .new(  0,  1 ), .new(  1, -2 )}},
  .{ .cells = .{ .new( 0, 0 ), .new( -1,  0 ), .new(  1, -1 ), .new( -2,  1 )}},
  .{ .cells = .{ .new( 0, 0 ), .new(  0, -1 ), .new(  1,  0 ), .new( -1, -1 )}},
  .{ .cells = .{ .new( 0, 0 ), .new(  1, -1 ), .new(  0,  1 ), .new(  1, -2 )}},
  .{ .cells = .{ .new( 0, 0 ), .new( -1,  0 ), .new(  1, -1 ), .new( -2,  1 )}},
}};
const P11 = PieceDef{ .layouts = .{ // S
  .{ .cells = .{ .new( 0, 0 ), .new(  0, -1 ), .new( -1,  1 ), .new(  1, -2 )}},
  .{ .cells = .{ .new( 0, 0 ), .new(  1, -1 ), .new( -1,  0 ), .new(  2, -1 )}},
  .{ .cells = .{ .new( 0, 0 ), .new( -1,  0 ), .new(  0,  1 ), .new( -1, -1 )}},
  .{ .cells = .{ .new( 0, 0 ), .new(  0, -1 ), .new( -1,  1 ), .new(  1, -2 )}},
  .{ .cells = .{ .new( 0, 0 ), .new(  1, -1 ), .new( -1,  0 ), .new(  2, -1 )}},
  .{ .cells = .{ .new( 0, 0 ), .new( -1,  0 ), .new(  0,  1 ), .new( -1, -1 )}},
}};

const P12 = PieceDef{ .layouts = .{ // D
  .{ .cells = .{ .new( 0, 0 ), .new(  0, -1 ), .new(  1, -1 ), .new( -1,  0 )}},
  .{ .cells = .{ .new( 0, 0 ), .new(  1, -1 ), .new(  1,  0 ), .new(  0, -1 )}},
  .{ .cells = .{ .new( 0, 0 ), .new( -1,  0 ), .new(  0, -1 ), .new( -1,  1 )}},
  .{ .cells = .{ .new( 0, 0 ), .new(  0, -1 ), .new(  1, -1 ), .new( -1,  0 )}},
  .{ .cells = .{ .new( 0, 0 ), .new(  1, -1 ), .new(  1,  0 ), .new(  0, -1 )}},
  .{ .cells = .{ .new( 0, 0 ), .new( -1,  0 ), .new(  0, -1 ), .new( -1,  1 )}},
}};

const P13 = PieceDef{ .layouts = .{ // Y
  .{ .cells = .{  .new( 0, 0 ), .new(  1, -1 ), .new(  0,  1 ), .new( -1,  0 )}},
  .{ .cells = .{  .new( 0, 0 ), .new(  1,  0 ), .new( -1,  1 ), .new(  0, -1 )}},
  .{ .cells = .{  .new( 0, 0 ), .new(  0,  1 ), .new( -1,  0 ), .new(  1, -1 )}},
  .{ .cells = .{  .new( 0, 0 ), .new( -1,  1 ), .new(  0, -1 ), .new(  1,  0 )}},
  .{ .cells = .{  .new( 0, 0 ), .new( -1,  0 ), .new(  1, -1 ), .new(  0,  1 )}},
  .{ .cells = .{  .new( 0, 0 ), .new(  0, -1 ), .new(  1,  0 ), .new( -1,  1 )}},
}};

const P14 = PieceDef{ .layouts = .{ // C
  .{ .cells = .{ .new(  0,  1 ), .new( -1,  1 ), .new( -1,  0 ), .new(  0, -1 )}},
  .{ .cells = .{ .new( -1,  1 ), .new( -1,  0 ), .new(  0, -1 ), .new(  1, -1 )}},
  .{ .cells = .{ .new( -1,  0 ), .new(  0, -1 ), .new(  1, -1 ), .new(  1,  0 )}},
  .{ .cells = .{ .new(  0, -1 ), .new(  1, -1 ), .new(  1,  0 ), .new(  0,  1 )}},
  .{ .cells = .{ .new(  1, -1 ), .new(  1,  0 ), .new(  0,  1 ), .new( -1,  1 )}},
  .{ .cells = .{ .new(  1,  0 ), .new(  0,  1 ), .new( -1,  1 ), .new( -1,  0 )}},
}};
