const utl = @import( "utils" );
const pcs = @import( "pieces.zig" );

const Coords2 = utl.Coords2;

pub const HexCoord  = pcs.HexCoord;
pub const PieceKind = pcs.PieceKind;
pub const Rotation  = pcs.Rotation;

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
  Cyan,
  Magenta,
  Lime,
  Rose,
};

/// Mutable preview state for one tetrahex before it becomes settled board cells.
pub const ActivePiece = struct
{
  kind     : PieceKind = .P01,
  rotation : Rotation  = .R0,
  anchor   : HexCoord  = .{},

  pub inline fn getLayout( self : *const ActivePiece ) *const pcs.PieceLayout
  {
    const def = pcs.getDef( self.kind );
    return &def.layouts[ @intCast( self.rotation.getIndex() ) ];
  }

  pub inline fn getCellHex( self : *const ActivePiece, index : usize ) HexCoord
  {
    const layout = self.getLayout();
    const cell = layout.cells[ index ];
    const anchorCell = layout.getAnchorCell();

    return self.anchor.add( .new( cell.q - anchorCell.q, cell.r - anchorCell.r ));
  }

  pub inline fn isAnchorCell( self : *const ActivePiece, index : usize ) bool
  {
    return index == self.getLayout().getAnchorIndex();
  }
};

/// A render-ready cell from the active piece; it never mutates the settled board.
pub const PreviewCell = struct
{
  coords   : Coords2,
  cell     : Cell,
  isAnchor : bool,
};

/// Fixed-size board storage. Hex geometry and drawing remain in `legacy_tilemap`.
pub const Board = struct
{
  pub const width     : i32   = 9;
  pub const height    : i32   = 23;
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
  board       : Board       = .{},
  activePiece : ActivePiece = .{},

  pub fn init( self : *Game ) void
  {
    self.reset();
  }

  pub fn reset( self : *Game ) void
  {
    self.board.reset();
    self.activePiece = .{ .anchor = HexCoord.fromBoardCoords( .{ .x = Board.width / 2, .y = Board.height / 2 } ) };
  }

  /// Returns a floating-piece cell suitable for overlaying onto the board render.
  pub fn getPreviewCell( self : *const Game, index : usize ) PreviewCell
  {
    return .{
      .coords   = self.activePiece.getCellHex( index ).toBoardCoords(),
      .cell     = getCellForPiece( self.activePiece.kind ),
      .isAnchor = self.activePiece.isAnchorCell( index ),
    };
  }

  pub fn changePieceBy( self : *Game, offset : i32 ) void
  {
    self.activePiece.kind = PieceKind.fromIndex( self.activePiece.kind.getIndex() + offset );
  }

  pub fn changeRotationBy( self : *Game, offset : i32 ) void
  {
    self.activePiece.rotation = Rotation.fromIndex( self.activePiece.rotation.getIndex() + offset );
  }
};

fn getCellForPiece( kind : PieceKind ) Cell
{
  return switch( kind )
  {
    .P01 => .Red,     .P02 => .Orange, .P03 => .Yellow, .P04 => .Green,   .P05 => .Blue,
    .P06 => .Purple,  .P07 => .Cyan,   .P08 => .Magenta,.P09 => .Lime,    .P10 => .Rose,
  };
}
