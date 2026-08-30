const std   = @import( "std" );
const utl   = @import( "utils" );
const pcs   = @import( "pieces.zig" );
const board = @import( "board.zig" );
const clear = @import( "clearEvent.zig" );
const bag   = @import( "pieceBag.zig" );
const score = @import( "score.zig" );

const Coords2 = utl.Coords2;

pub const HexCoord  = pcs.HexCoord;
pub const PieceKind = pcs.PieceKind;
pub const Rotation  = pcs.Rotation;
pub const Cell      = board.Cell;
pub const Board     = board.Board;

/// Mutable preview state for one piece before it becomes settled board cells.
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

  /// True when the anchor is intentionally between the piece's cells, as for C.
  pub fn hasEmptyAnchor( self : *const ActivePiece ) bool
  {
    for( 0 .. @as( usize, self.getLayout().cellCount ))| index |
    {
      const cell = self.getLayout().cells[ index ];
      if( cell.q == 0 and cell.r == 0 ){ return false; }
    }
    return true;
  }

  /// Returns whether this indexed cell occupies the layout's placement anchor.
  pub inline fn isAnchorCell( self : *const ActivePiece, index : usize ) bool
  {
    const cell = self.getLayout().cells[ index ];
    return cell.q == 0 and cell.r == 0;
  }
};

/// A render-ready cell from the active piece; it never mutates the settled board.
pub const PreviewCell = struct
{
  coords : Coords2,
  cell   : Cell,
};

/// Separates failed debug movement into the gameplay-relevant collision causes.
pub const Collision = struct
{
  wall  : bool = false,
  floor : bool = false,
  cell  : bool = false,

  pub inline fn isClear( self : Collision ) bool { return !self.wall and !self.floor and !self.cell; }
};

/// Result of locking a piece. Clear events defer replacement-piece spawning.
pub const LockResult = struct
{
  locked       : u8 = 0,
  outsideBoard : u8 = 0,
  gameOver     : bool = false,
  clearStarted : ?clear.WaveSummary = null,
};

/// Result of one clear-event timer update.
pub const ClearTickResult = struct
{
  newWave        : ?clear.WaveSummary = null,
  completedScore : ?u64 = null,
  gameOver       : bool = false,
};

/// Owns active-piece state, settled board state, and staged clear-event lifecycle.
pub const Game = struct
{
  board         : Board            = .{},
  activePiece   : ActivePiece      = .{},
  clearEvent    : clear.ClearEvent = .{},
  pieceBag      : bag.PieceBag     = .{},
  isInitialized : bool             = false,
  isGameOver    : bool             = false,
  isPauseQueued : bool             = false,
  isPaused      : bool             = false,
  score         : u64              = 0,
  clearedLines  : u32              = 0,
  clearedTiles  : u32              = 0,
  elapsedTime   : f64              = 0.0,

  /// Enters Tetrom's title state without creating a piece or consuming randomness.
  pub fn init( self : *Game ) void
  {
    self.* = .{ .isPaused = true };
  }

  /// Starts or restarts a seeded game with a random piece at top centre.
  pub fn reset( self : *Game, rng : *utl.Randomiser ) void
  {
    self.board.reset();
    self.clearEvent.reset();
    self.pieceBag.reset();
    self.isInitialized = true;
    self.isGameOver = false;
    self.isPauseQueued = false;
    self.isPaused     = false;
    self.score        = 0;
    self.clearedLines = 0;
    self.clearedTiles = 0;
    self.elapsedTime  = 0.0;
    self.spawnRandomPiece( rng );
  }

  pub inline fn isClearEventActive( self : *const Game ) bool { return self.clearEvent.isActive(); }

  /// Advances the displayed game timer while the game is actively progressing.
  pub inline fn tickTime( self : *Game, deltaTime : f32 ) void
  {
    if( !self.isPaused and !self.isGameOver ){ self.elapsedTime += @as( f64, deltaTime ); }
  }

  /// Queues or cancels a pause request; the request resolves only at a spawn boundary.
  pub fn togglePauseQueue( self : *Game ) void
  {
    if( !self.isPaused ){ self.isPauseQueued = !self.isPauseQueued; }
  }

  /// Leaves the spawn-boundary pause by spawning the already-determined next piece.
  pub fn resumePausedGame( self : *Game, rng : *utl.Randomiser ) void
  {
    if( !self.isPaused ){ return; }

    self.isPaused = false;
    self.spawnRandomPiece( rng );
  }

  /// Returns the bag's already queued next piece without consuming it.
  pub fn getNextPiece( self : *const Game ) PieceKind
  {
    return self.pieceBag.peek();
  }

  /// Replaces the active piece without changing settled board cells.
  pub fn spawnRandomPiece( self : *Game, rng : *utl.Randomiser ) void
  {
    self.activePiece = .{
      .kind   = self.pieceBag.draw( rng ),
      .anchor = HexCoord.fromBoardCoords( .{ .x = Board.width / 2, .y = 1 } ),
    };

    self.isGameOver = !self.checkPieceCollision( &self.activePiece ).isClear();
  }

  /// Returns a floating-piece cell suitable for overlaying onto the board render.
  pub fn getPreviewCell( self : *const Game, index : usize ) PreviewCell
  {
    return .{
      .coords = self.activePiece.getCellHex( index ).toBoardCoords(),
      .cell   = getCellForPiece( self.activePiece.kind ),
    };
  }

  pub fn getClearDisplayOverride( self : *const Game, index : usize ) ?clear.DisplayOverride
  {
    return self.clearEvent.getDisplayOverride( index );
  }

  pub fn changePieceBy( self : *Game, offset : i32 ) void
  {
    self.activePiece.kind = PieceKind.fromIndex( self.activePiece.kind.getIndex() + offset );
  }

  /// Writes active cells and either starts a staged clear or spawns immediately.
  pub fn lockActivePiece( self : *Game, rng : *utl.Randomiser ) LockResult
  {
    // A spawn-obstructed piece is never placed and must not award tile score.
    if( !self.isInitialized or self.isGameOver or self.isClearEventActive() ){ return .{}; }

    var result : LockResult = .{};
    const cell = getCellForPiece( self.activePiece.kind );

    for( 0 .. @as( usize, self.activePiece.getLayout().cellCount ))| index |
    {
      const coords = self.activePiece.getCellHex( index ).toBoardCoords();

      if( self.board.setCell( coords, cell )){ result.locked += 1; }
      else {                                 result.outsideBoard += 1; }
    }

    self.score += @as( u64, result.locked ) * score.LOCKED_TILE_SCORE;

    result.clearStarted = self.clearEvent.tryStart( &self.board );
    if( result.clearStarted )| wave |{ self.addClearTotals( wave ); }
    if( result.clearStarted == null )
    {
      self.pauseOrSpawn( rng );
      result.gameOver = self.isGameOver;
    }

    return result;
  }

  /// Advances a staged clear. Only a completed event may spawn and trigger game over.
  pub fn tickClearEvent( self : *Game, rng : *utl.Randomiser, deltaTime : f32 ) ClearTickResult
  {
    const eventResult = self.clearEvent.advance( &self.board, deltaTime );
    var result : ClearTickResult = .{ .newWave = eventResult.newWave };

    if( eventResult.newWave )| wave |{ self.addClearTotals( wave ); }

    if( eventResult.completedScore )| completedScore |
    {
      self.score += completedScore;
      result.completedScore = completedScore;
      self.pauseOrSpawn( rng );
      result.gameOver = self.isGameOver;
    }

    return result;
  }

  /// Applies one clear wave's unique line and tile totals to game statistics.
  fn addClearTotals( self : *Game, wave : clear.WaveSummary ) void
  {
    self.clearedLines += @as( u32, wave.lineCount );
    self.clearedTiles += @as( u32, wave.clearedTiles );
  }

  /// Resolves a queued pause after all clear waves, otherwise spawns normally.
  fn pauseOrSpawn( self : *Game, rng : *utl.Randomiser ) void
  {
    if( self.isPauseQueued )
    {
      self.isPauseQueued = false;
      self.isPaused = true;
      return;
    }

    self.spawnRandomPiece( rng );
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

  /// Moves the active piece by one axial neighbour when the destination is clear.
  pub fn tryMoveBy( self : *Game, offset : HexCoord ) Collision
  {
    var candidate = self.activePiece;
        candidate.anchor = candidate.anchor.add( offset );

    const collision = self.checkPieceCollision( &candidate );
    if( collision.isClear() ){ self.activePiece = candidate; }

    return collision;
  }

  /// Rotates the active piece, attempting upward/sideward wall kicks if needed.
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

    if( collision.cell and !collision.wall and !collision.floor )
    {
      // Future block kicks may also try `.new( -1, 1 )` and `.new( 1, 0 )`.
      candidate.anchor = self.activePiece.anchor.add( .new( 0, 1 ));

      const kickedCollision = self.checkPieceCollision( &candidate );
      if( kickedCollision.isClear() )
      {
        self.activePiece = candidate;
        return .{ .collision = .{}, .kicked = true };
      }
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

/// Returns the settled/render colour category associated with a piece kind.
pub fn getCellForPiece( kind : PieceKind ) Cell
{
  return switch( kind )
  {
    .P00 => .Purple,  .P01 => .Cyan,   .P02 => .Rose,   .P03 => .Lime,    .P04 => .Magenta,
    .P05 => .Red,     .P06 => .Orange, .P07 => .Yellow, .P08 => .Green,   .P09 => .Blue,
    .P10 => .Coral,   .P11 => .Teal,   .P12 => .Bronze, .P13 => .Silver,  .P14 => .Brown,
  };
}

test "spawn-obstructed pieces cannot award tile score"
{
  var rng : utl.Randomiser = .{};
  rng.seedInit( 1 );

  var gameState : Game = .{};
  gameState.reset( &rng );
  gameState.board.cells = [_]Cell{ .Red } ** Board.cellCount;
  gameState.score = 0;
  gameState.spawnRandomPiece( &rng );

  try std.testing.expect( gameState.isGameOver );
  const result = gameState.lockActivePiece( &rng );
  try std.testing.expectEqual( @as( u8, 0 ), result.locked );
  try std.testing.expectEqual( @as( u64, 0 ), gameState.score );
}

test "resetting with the same seed repeats the opening piece sequence"
{
  var firstRng : utl.Randomiser = .{};
  firstRng.seedInit( 42 );
  var firstGame : Game = .{};
  firstGame.reset( &firstRng );

  var secondRng : utl.Randomiser = .{};
  secondRng.seedInit( 42 );
  var secondGame : Game = .{};
  secondGame.reset( &secondRng );

  try std.testing.expectEqual( firstGame.activePiece.kind, secondGame.activePiece.kind );
  try std.testing.expectEqual( firstGame.getNextPiece(), secondGame.getNextPiece() );
}
