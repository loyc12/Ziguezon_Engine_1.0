const utl = @import( "utils" );

const Coords2 = utl.Coords2;

/// Render-independent settled-cell values for Tetrom's fixed board.
pub const Cell = enum( u8 )
{
  Empty,

  Red,
  Orange,
  Yellow,
  Green,
  Blue,
  Purple,
};

/// Fixed-size board storage. Hex geometry and drawing remain in `legacy_tilemap`.
pub const Board = struct
{
  pub const width     : i32   = 10;
  pub const height    : i32   = 20;
  pub const cellCount : usize = width * height;

  cells : [ cellCount ]Cell = [_]Cell{ .Empty } ** cellCount,

  /// Clears all settled cells while retaining the board allocation and geometry.
  pub fn reset( self : *Board ) void
  {
    self.* = .{};
  }

  /// Returns null when `coords` is outside the fixed Tetrom board.
  pub fn getIndex( self : *const Board, coords : Coords2 ) ?usize
  {
    _ = self;

    if( coords.x < 0 or coords.y < 0 ){ return null; }
    if( coords.x >= width or coords.y >= height ){ return null; }

    return @intCast(( coords.y * width ) + coords.x );
  }

  pub fn getCell( self : *const Board, coords : Coords2 ) ?Cell
  {
    const index = self.getIndex( coords ) orelse return null;
    return self.cells[ index ];
  }

  /// Returns false when `coords` lies outside the board.
  pub fn setCell( self : *Board, coords : Coords2, cell : Cell ) bool
  {
    const index = self.getIndex( coords ) orelse return false;

    self.cells[ index ] = cell;
    return true;
  }
};

/// Owns the future falling-piece state independently of engine and render state.
pub const Game = struct
{
  board : Board = .{},

  pub fn init( self : *Game ) void
  {
    self.reset();
  }

  pub fn reset( self : *Game ) void
  {
    self.board.reset();
  }
};
