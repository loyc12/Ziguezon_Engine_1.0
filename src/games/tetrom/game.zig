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
  kind     : PieceKind = .P05,
  rotation : Rotation  = .R0,
  anchor   : HexCoord  = .{},

  pub inline fn getLayout( self : *const ActivePiece ) *const pcs.PieceLayout
  {
    const def = pcs.getDef( self.kind );
    return &def.layouts[ @intCast( self.rotation.getIndex() ) ];
  }

  pub inline fn getCellHex( self : *const ActivePiece, index : usize ) HexCoord
  {
    return self.anchor.add( self.getLayout().cells[ index ] );
  }

  pub inline fn isAnchorCell( self : *const ActivePiece, index : usize ) bool
  {
    const cell = self.getLayout().cells[ index ];
    return cell.q == 0 and cell.r == 0;
  }
};

/// A render-ready cell from the active piece; it never mutates the settled board.
pub const PreviewCell = struct
{
  coords   : Coords2,
  cell     : Cell,
  isAnchor : bool,
};

/// Separates failed debug movement into the gameplay-relevant collision causes.
pub const Collision = struct
{
  wall  : bool = false,
  floor : bool = false,
  cell  : bool = false,

  pub inline fn isClear( self : Collision ) bool { return !self.wall and !self.floor and !self.cell; }
};

pub const ClearResult = struct
{
  lineCount  : u8  = 0,
  crossings  : u8  = 0,
  cleared    : u8  = 0,
  scoreAward : u64 = 0,
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
  isGameOver  : bool        = false,
  score       : u64         = 0,

  pub fn init( self : *Game, rng : *utl.Randomiser ) void
  {
    self.reset( rng );
  }

  /// Clears the settled board and spawns a random debug piece at top centre.
  pub fn reset( self : *Game, rng : *utl.Randomiser ) void
  {
    self.board.reset();
    self.isGameOver = false;
    self.score = 0;
    self.spawnRandomPiece( rng );
  }

  /// Replaces the active debug piece without changing settled board cells.
  pub fn spawnRandomPiece( self : *Game, rng : *utl.Randomiser ) void
  {
    self.activePiece = .{
      .kind   = rng.getVal( PieceKind ),
      .anchor = HexCoord.fromBoardCoords( .{ .x = Board.width / 2, .y = 1 } ),
    };

    self.isGameOver = !self.checkPieceCollision( &self.activePiece ).isClear();
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

  /// Writes every in-bounds active cell into the settled board, then spawns anew.
  pub fn lockActivePiece( self : *Game, rng : *utl.Randomiser ) struct { locked : u8, outsideBoard : u8, gameOver : bool, clear : ClearResult }
  {
    var locked       : u8 = 0;
    var outsideBoard : u8 = 0;
    const cell = getCellForPiece( self.activePiece.kind );

    for( 0 .. @as( usize, self.activePiece.getLayout().cellCount ))| index |
    {
      const coords = self.activePiece.getCellHex( index ).toBoardCoords();

      if( self.board.setCell( coords, cell )){ locked += 1; }
      else {                                 outsideBoard += 1; }
    }

    const clear = self.clearCompletedDiagonals();
    self.score += clear.scoreAward;

    self.spawnRandomPiece( rng );
    return .{ .locked = locked, .outsideBoard = outsideBoard, .gameOver = self.isGameOver, .clear = clear };
  }

  /// Clears full-width lines along both axial diagonal families after locking.
  fn clearCompletedDiagonals( self : *Game ) ClearResult
  {
    var marked : [ Board.cellCount ]bool = [_]bool{ false } ** Board.cellCount;
    var result : ClearResult = .{};

    var r : i32 = -Board.width;
    while( r <= Board.height ) : ( r += 1 )
    {
      if( !self.isFullRLine( r )){ continue; }
      result.lineCount += 1;
      self.markRLine( r, &marked, &result.crossings );
    }

    var diagonal : i32 = 0;
    while( diagonal <= Board.width + Board.height ) : ( diagonal += 1 )
    {
      if( !self.isFullSumLine( diagonal )){ continue; }
      result.lineCount += 1;
      self.markSumLine( diagonal, &marked, &result.crossings );
    }

    for( marked, 0 .. )| isMarked, index |
    {
      if( !isMarked ){ continue; }
      self.board.cells[ index ] = .Empty;
      result.cleared += 1;
    }

    if( result.lineCount == 0 ){ return result; }

    const lineCount : u64 = result.lineCount;
    const base = 100 * lineCount * ( lineCount + 1 ) / 2;
    result.scoreAward = @intFromFloat( @round( @as( f64, @floatFromInt( base )) * getCrossingFactor( result.crossings )));

    return result;
  }

  fn isFullRLine( self : *const Game, r : i32 ) bool
  {
    for( 0 .. @as( usize, @intCast( Board.width )))| x |
    {
      const coords = HexCoord.new( @intCast( x ), r ).toBoardCoords();
      const cell = self.board.getCell( coords ) orelse return false;
      if( cell == .Empty ){ return false; }
    }
    return true;
  }

  fn isFullSumLine( self : *const Game, diagonal : i32 ) bool
  {
    for( 0 .. @as( usize, @intCast( Board.width )))| x |
    {
      const q : i32 = @intCast( x );
      const coords = HexCoord.new( q, diagonal - q ).toBoardCoords();
      const cell = self.board.getCell( coords ) orelse return false;
      if( cell == .Empty ){ return false; }
    }
    return true;
  }

  fn markRLine( self : *const Game, r : i32, marked : *[ Board.cellCount ]bool, crossings : *u8 ) void
  {
    for( 0 .. @as( usize, @intCast( Board.width )))| x |
    {
      const index = self.board.getIndex( HexCoord.new( @intCast( x ), r ).toBoardCoords() ).?;
      markForClear( marked, index, crossings );
    }
  }

  fn markSumLine( self : *const Game, diagonal : i32, marked : *[ Board.cellCount ]bool, crossings : *u8 ) void
  {
    for( 0 .. @as( usize, @intCast( Board.width )))| x |
    {
      const q : i32 = @intCast( x );
      const index = self.board.getIndex( HexCoord.new( q, diagonal - q ).toBoardCoords() ).?;
      markForClear( marked, index, crossings );
    }
  }

  /// Checks a prospective piece location without mutating the board or active piece.
  pub fn checkPieceCollision( self : *const Game, piece : *const ActivePiece ) Collision
  {
    var collision : Collision = .{};

    // Cells may rise above the grid, but the placement anchor itself cannot.
    const anchorCoords = piece.anchor.toBoardCoords();
    if( anchorCoords.y < 0 or anchorCoords.x < 0 or anchorCoords.x >= Board.width ){ collision.wall = true; }
    if( anchorCoords.y >= Board.height ){ collision.floor = true; }

    for( 0 .. @as( usize, piece.getLayout().cellCount ))| index |
    {
      const coords = piece.getCellHex( index ).toBoardCoords();

      if( coords.y >= Board.height )
      {
        collision.floor = true;
        continue;
      }
      if( coords.x < 0 or coords.x >= Board.width )
      {
        collision.wall = true;
        continue;
      }
      if( coords.y < 0 ){ continue; }
      if( self.board.getCell( coords ).? != .Empty ){ collision.cell = true; }
    }

    return collision;
  }

  /// Moves the debug piece by one axial neighbour when the destination is clear.
  pub fn tryMoveBy( self : *Game, offset : HexCoord ) Collision
  {
    var candidate = self.activePiece;
    candidate.anchor = candidate.anchor.add( offset );

    const collision = self.checkPieceCollision( &candidate );
    if( collision.isClear() ){ self.activePiece = candidate; }

    return collision;
  }

  /// Rotates the debug piece, attempting one diagonal upward wall kick if needed.
  pub fn tryRotateBy( self : *Game, offset : i32 ) struct { collision : Collision, kicked : bool }
  {
    var candidate = self.activePiece;
    candidate.rotation = Rotation.fromIndex( candidate.rotation.getIndex() + offset );

    const collision = self.checkPieceCollision( &candidate );
    if( collision.isClear() )
    {
      self.activePiece = candidate;
      return .{ .collision = .{}, .kicked = false };
    }

    if( collision.wall )
    {
      const kicks = self.getWallKicks( &candidate );

      for( kicks )| kick |
      {
        candidate.anchor = self.activePiece.anchor.add( kick );

        const kickedCollision = self.checkPieceCollision( &candidate );
        if( kickedCollision.isClear() )
        {
          self.activePiece = candidate;
          return .{ .collision = .{}, .kicked = true };
        }
        if( !kickedCollision.wall ){ break; }
      }
    }

    return .{ .collision = collision, .kicked = false };
  }

  fn getWallKicks( self : *const Game, piece : *const ActivePiece ) [ 3 ]HexCoord
  {
    _ = self;

    var hitsLeftWall  : bool = false;
    var hitsRightWall : bool = false;

    for( 0 .. @as( usize, piece.getLayout().cellCount ))| index |
    {
      const coords = piece.getCellHex( index ).toBoardCoords();
      hitsLeftWall  = hitsLeftWall  or coords.x < 0;
      hitsRightWall = hitsRightWall or coords.x >= Board.width;
    }

    if( hitsLeftWall and !hitsRightWall )
    {
      return .{ .new( 1, -1 ), .new( 2, -2 ), .new( 2, -1 ) };
    }
    if( hitsRightWall and !hitsLeftWall )
    {
      return .{ .new( -1, 0 ), .new( -2, 0 ), .new( -2, 1 ) };
    }
    return .{ .{}, .{}, .{} };
  }
};

fn markForClear( marked : *[ Board.cellCount ]bool, index : usize, crossings : *u8 ) void
{
  if( marked[ index ]){ crossings.* += 1; }
  else {                marked[ index ] = true; }
}

/// Normalized sigmoid bonus: zero crossings yields 1x and high counts approach 2x.
fn getCrossingFactor( crossings : u8 ) f64
{
  const crossingCount : f64 = @floatFromInt( crossings );
  const baseline = utl.sigmoid( -1.0, 0.5 );
  const response = utl.sigmoid( crossingCount - 1.0, 0.5 );

  return 1.0 + ( response - baseline ) / ( 1.0 - baseline );
}

fn getCellForPiece( kind : PieceKind ) Cell
{
  return switch( kind )
  {
    .P00 => .Purple,  .P01 => .Cyan,   .P02 => .Rose,   .P03 => .Lime,    .P04 => .Magenta,
    .P05 => .Red,     .P06 => .Orange, .P07 => .Yellow, .P08 => .Green,   .P09 => .Blue,
    .P10 => .Purple,  .P11 => .Cyan,   .P12 => .Magenta,.P13 => .Lime,    .P14 => .Rose,
  };
}
