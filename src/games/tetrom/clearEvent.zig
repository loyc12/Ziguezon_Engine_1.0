const std   = @import( "std" );
const pcs   = @import( "pieces.zig" );
const board = @import( "board.zig" );
const score = @import( "score.zig" );

const Board    = board.Board;
const Cell     = board.Cell;
const HexCoord = pcs.HexCoord;

/// Seconds for marked cells to reach white. Tune freely during development.
pub var CLEAR_FLASH_DURATION  : f32 = 0.2;

/// Seconds for white marked cells to fade into the playfield colour.
pub var CLEAR_FADE_DURATION   : f32 = 0.4;

/// Seconds between each visible centre-out one-cell collapse pulse.
pub var COLLAPSE_PULSE_DELAY  : f32 = 0.2;

/// Seconds to display a completed collapse before testing its cascade result.
pub var POST_COLLAPSE_DELAY   : f32 = 1.0;

pub const ClearPhase = enum { None, FlashToWhite, FadeToField, Collapse, PostCollapse };

/// A detected line union, retained until its visual clear phase completes.
pub const PendingClear = struct
{
  cells        : [ Board.cellCount ]bool = [_]bool{ false } ** Board.cellCount,
  lineCount    : u8 = 0,
  clearedTiles : u8 = 0,
  crossings    : u8 = 0,
  waveScore    : score.WaveScore = .{ .lineCount = 0, .crossings = 0, .award = 0 },
};

/// The score data needed by clear feedback without exposing board ownership.
pub const WaveSummary = struct
{
  lineCount        : u8,
  clearedTiles     : u8,
  crossings        : u8,
  latestWaveScore  : u64,
  comboBonus       : u64,
  eventScore       : u64,
  waveCount        : u8,
};

/// Render instruction for one cell affected by the active clear phase.
pub const DisplayOverride = union( enum )
{
  FlashToWhite : f32,
  FadeToField  : f32,
};

/// Results emitted while advancing the clear-event state machine.
pub const AdvanceResult = struct
{
  newWave        : ?WaveSummary = null,
  completedScore : ?u64         = null,
};

/// Per-cell vertical movement derived only from the just-cleared cell mask.
pub const CollapsePlan = struct
{
  fallCounts : [ Board.cellCount ]u8,
};

/// Owns clear timing, score chaining, and the replaceable column-collapse plan.
pub const ClearEvent = struct
{
  phase            : ClearPhase = .None,
  pending          : PendingClear = .{},
  phaseElapsed     : f32 = 0.0,
  collapseElapsed  : f32 = 0.0,
  collapsePulse    : i32 = 0,
  collapseFalls    : [ Board.cellCount ]u8 = [_]u8{ 0 } ** Board.cellCount,
  eventScore       : u64 = 0,
  latestWaveScore  : u64 = 0,
  comboBonus       : u64 = 0,
  waveCount        : u8 = 0,

  pub fn reset( self : *ClearEvent ) void
  {
    self.* = .{};
  }

  pub inline fn isActive( self : *const ClearEvent ) bool { return self.phase != .None; }

  /// Finds and starts the first clear wave after a piece locks.
  pub fn tryStart( self : *ClearEvent, gameBoard : *const Board ) ?WaveSummary
  {
    if( self.isActive() ){ return null; }

    const pending = detectClear( gameBoard ) orelse return null;
    self.startWave( pending );
    return self.getSummary();
  }

  /// Returns the visual colour transition for a marked board cell, if any.
  pub fn getDisplayOverride( self : *const ClearEvent, index : usize ) ?DisplayOverride
  {
    if( !self.isActive() or !self.pending.cells[ index ]){ return null; }

    return switch( self.phase )
    {
      .FlashToWhite => .{ .FlashToWhite = getPhaseProgress( self.phaseElapsed, CLEAR_FLASH_DURATION ) },
      .FadeToField  => .{ .FadeToField  = getPhaseProgress( self.phaseElapsed, CLEAR_FADE_DURATION  ) },
      else          => null,
    };
  }

  /// Advances one staged clear event. A completed event returns its final score.
  pub fn advance( self : *ClearEvent, gameBoard : *Board, deltaTime : f32 ) AdvanceResult
  {
    if( !self.isActive() ){ return .{}; }

    switch( self.phase )
    {
      .FlashToWhite =>
      {
        self.phaseElapsed += deltaTime;
        if( self.phaseElapsed < CLEAR_FLASH_DURATION ){ return .{}; }

        self.phase = .FadeToField;
        self.phaseElapsed = 0.0;
      },
      .FadeToField =>
      {
        self.phaseElapsed += deltaTime;
        if( self.phaseElapsed < CLEAR_FADE_DURATION ){ return .{}; }

        self.erasePendingCells( gameBoard );

        const collapsePlan = buildMarkedColumnCollapsePlan( gameBoard, &self.pending.cells );
        self.collapseFalls   = collapsePlan.fallCounts;
        self.phase           = .Collapse;
        self.phaseElapsed    = 0.0;
        self.collapseElapsed = 0.0;
        self.collapsePulse   = 0;
      },
      .Collapse =>
      {
        self.collapseElapsed += deltaTime;

        const pulseDelay : f32 = @max( COLLAPSE_PULSE_DELAY, 0.001 );
        while( self.collapseElapsed >= pulseDelay )
        {
          self.collapseElapsed -= pulseDelay;
          self.advanceCollapsePulse( gameBoard );

          if( !self.isCollapseComplete() ){ continue; }

          self.phase        = .PostCollapse;
          self.phaseElapsed = 0.0;
          return .{};
        }
      },
      .PostCollapse =>
      {
        self.phaseElapsed += deltaTime;
        if( self.phaseElapsed < POST_COLLAPSE_DELAY ){ return .{}; }

        const pending = detectClear( gameBoard ) orelse
        {
          const completedScore = self.eventScore;
          self.reset();
          return .{ .completedScore = completedScore };
        };

        self.startWave( pending );
        return .{ .newWave = self.getSummary() };
      },
      .None => unreachable,
    }

    return .{};
  }

  fn startWave( self : *ClearEvent, pending : PendingClear ) void
  {
    self.pending         = pending;
    self.phase           = .FlashToWhite;
    self.phaseElapsed    = 0.0;
    self.collapseElapsed = 0.0;
    self.collapsePulse   = 0;

    self.latestWaveScore = pending.waveScore.award;
    self.comboBonus      = if( self.waveCount == 0 ) 0 else score.getComboBonus( self.eventScore );
    self.eventScore     += self.comboBonus + self.latestWaveScore;
    self.waveCount      += 1;
  }

  fn getSummary( self : *const ClearEvent ) WaveSummary
  {
    return .{
      .lineCount       = self.pending.lineCount,
      .clearedTiles    = self.pending.clearedTiles,
      .crossings       = self.pending.crossings,
      .latestWaveScore = self.latestWaveScore,
      .comboBonus      = self.comboBonus,
      .eventScore      = self.eventScore,
      .waveCount       = self.waveCount,
    };
  }

  fn erasePendingCells( self : *const ClearEvent, gameBoard : *Board ) void
  {
    for( self.pending.cells, 0 .. )| isMarked, index |
    {
      if( isMarked ){ gameBoard.cells[ index ] = .Empty; }
    }
  }

  fn advanceCollapsePulse( self : *ClearEvent, gameBoard : *Board ) void
  {
    const center = @divFloor( Board.width, 2 );

    for( 0 .. @as( usize, @intCast( Board.width )))| column |
    {
      const x : i32 = @intCast( column );
      const distance = if( x > center ) x - center else center - x;
      if( distance > self.collapsePulse ){ continue; }

      stepColumnTowardTarget( gameBoard, x, &self.collapseFalls );
    }

    if( self.collapsePulse < center ){ self.collapsePulse += 1; }
  }

  fn isCollapseComplete( self : *const ClearEvent ) bool
  {
    for( self.collapseFalls )| fallCount |
    {
      if( fallCount != 0 ){ return false; }
    }
    return true;
  }
};

/// Finds full-width lines from both diagonal families without mutating the board.
pub fn detectClear( gameBoard : *const Board ) ?PendingClear
{
  var pending : PendingClear = .{};

  var r : i32 = -Board.width;
  while( r <= Board.height ) : ( r += 1 )
  {
    if( !isFullRLine( gameBoard, r )){ continue; }
    pending.lineCount += 1;
    markRLine( gameBoard, r, &pending );
  }

  var diagonal : i32 = 0;
  while( diagonal <= Board.width + Board.height ) : ( diagonal += 1 )
  {
    if( !isFullSumLine( gameBoard, diagonal )){ continue; }
    pending.lineCount += 1;
    markSumLine( gameBoard, diagonal, &pending );
  }

  if( pending.lineCount == 0 ){ return null; }

  pending.waveScore = score.getWaveScore( pending.lineCount, pending.crossings );
  return pending;
}

/// Plans only falls caused by cleared cells, preserving all pre-existing gaps.
pub fn buildMarkedColumnCollapsePlan( gameBoard : *const Board, cleared : *const [ Board.cellCount ]bool ) CollapsePlan
{
  var plan : CollapsePlan = .{
    .fallCounts = [_]u8{ 0 } ** Board.cellCount,
  };

  for( 0 .. @as( usize, @intCast( Board.width )))| column |
  {
    const x : i32 = @intCast( column );
    var clearedBelow : u8 = 0;
    var y : i32 = Board.height - 1;

    while( y >= 0 ) : ( y -= 1 )
    {
      const index = getIndex( x, y );
      if( cleared[ index ])
      {
        clearedBelow += 1;
        continue;
      }

      const cell = gameBoard.cells[ index ];
      if( cell == .Empty ){ continue; }

      plan.fallCounts[ index ] = clearedBelow;
    }
  }

  return plan;
}

fn isFullRLine( gameBoard : *const Board, r : i32 ) bool
{
  for( 0 .. @as( usize, @intCast( Board.width )))| x |
  {
    const coords = HexCoord.new( @intCast( x ), r ).toBoardCoords();
    const cell = gameBoard.getCell( coords ) orelse return false;
    if( cell == .Empty ){ return false; }
  }
  return true;
}

fn isFullSumLine( gameBoard : *const Board, diagonal : i32 ) bool
{
  for( 0 .. @as( usize, @intCast( Board.width )))| x |
  {
    const q : i32 = @intCast( x );
    const coords = HexCoord.new( q, diagonal - q ).toBoardCoords();
    const cell = gameBoard.getCell( coords ) orelse return false;
    if( cell == .Empty ){ return false; }
  }
  return true;
}

fn markRLine( gameBoard : *const Board, r : i32, pending : *PendingClear ) void
{
  for( 0 .. @as( usize, @intCast( Board.width )))| x |
  {
    const index = gameBoard.getIndex( HexCoord.new( @intCast( x ), r ).toBoardCoords() ).?;
    markCell( pending, index );
  }
}

fn markSumLine( gameBoard : *const Board, diagonal : i32, pending : *PendingClear ) void
{
  for( 0 .. @as( usize, @intCast( Board.width )))| x |
  {
    const q : i32 = @intCast( x );
    const index = gameBoard.getIndex( HexCoord.new( q, diagonal - q ).toBoardCoords() ).?;
    markCell( pending, index );
  }
}

fn markCell( pending : *PendingClear, index : usize ) void
{
  if( pending.cells[ index ]){ pending.crossings += 1; }
  else
  {
    pending.cells[ index ] = true;
    pending.clearedTiles += 1;
  }
}

/// Moves every displaced cell in one selected column one row as a single pulse.
/// Bottom-up iteration makes a separated upper segment shift together, preserving
/// its empty spacing rather than treating its cells as independent falling bodies.
fn stepColumnTowardTarget( gameBoard : *Board, x : i32, fallCounts : *[ Board.cellCount ]u8 ) void
{
  var y : i32 = Board.height - 2;
  while( y >= 0 ) : ( y -= 1 )
  {
    const sourceIndex = getIndex( x, y );
    const targetIndex = getIndex( x, y + 1 );

    if( fallCounts[ sourceIndex ] == 0 ){ continue; }
    if( gameBoard.cells[ targetIndex ] != .Empty ){ continue; }

    gameBoard.cells[ targetIndex ] = gameBoard.cells[ sourceIndex ];
    gameBoard.cells[ sourceIndex ] = .Empty;
    fallCounts[ targetIndex ] = fallCounts[ sourceIndex ] - 1;
    fallCounts[ sourceIndex ] = 0;
  }
}

fn getPhaseProgress( elapsed : f32, duration : f32 ) f32
{
  return @min( elapsed / @max( duration, 0.001 ), 1.0 );
}

fn getIndex( x : i32, y : i32 ) usize
{
  return @intCast(( y * Board.width ) + x );
}

test "one full axial line is detected without mutating the board"
{
  var gameBoard : Board = .{};

  for( 0 .. @as( usize, @intCast( Board.width )))| x |
  {
    const coords = HexCoord.new( @intCast( x ), 2 ).toBoardCoords();
    try std.testing.expect( gameBoard.setCell( coords, .Red ));
  }

  const pending = detectClear( &gameBoard ).?;
  try std.testing.expectEqual( @as( u8, 1 ), pending.lineCount );
  try std.testing.expectEqual( @as( u8, @intCast( Board.width )), pending.clearedTiles );
  try std.testing.expectEqual( @as( u8, 0 ), pending.crossings );
}

test "crossing diagonal lines count their shared cell once"
{
  var gameBoard : Board = .{};

  for( 0 .. @as( usize, @intCast( Board.width )))| x |
  {
    const q : i32 = @intCast( x );
    try std.testing.expect( gameBoard.setCell( HexCoord.new( q, 5 ).toBoardCoords(), .Red ));
    try std.testing.expect( gameBoard.setCell( HexCoord.new( q, 7 - q ).toBoardCoords(), .Blue ));
  }

  const pending = detectClear( &gameBoard ).?;
  try std.testing.expectEqual( @as( u8, 2 ), pending.lineCount );
  try std.testing.expectEqual( @as( u8, @intCast(( Board.width * 2 ) - 1 )), pending.clearedTiles );
  try std.testing.expectEqual( @as( u8, 1 ), pending.crossings );
}

test "marked collapse plan preserves ordinary gaps"
{
  var gameBoard : Board = .{};
  var cleared : [ Board.cellCount ]bool = [_]bool{ false } ** Board.cellCount;

  try std.testing.expect( gameBoard.setCell( .{ .x = 4, .y = 2 }, .Red ));
  try std.testing.expect( gameBoard.setCell( .{ .x = 4, .y = 8 }, .Blue ));
  try std.testing.expect( gameBoard.setCell( .{ .x = 4, .y = 14 }, .Green ));
  cleared[ getIndex( 4, 10 ) ] = true;

  const plan = buildMarkedColumnCollapsePlan( &gameBoard, &cleared );
  var fallCounts = plan.fallCounts;
  stepColumnTowardTarget( &gameBoard, 4, &fallCounts );

  try std.testing.expectEqual( Cell.Red,   gameBoard.cells[ getIndex( 4, 3 ) ] );
  try std.testing.expectEqual( Cell.Blue,  gameBoard.cells[ getIndex( 4, 9 ) ] );
  try std.testing.expectEqual( Cell.Green, gameBoard.cells[ getIndex( 4, 14 ) ] );
}

test "collapse pulse moves a whole displaced column segment together"
{
  var gameBoard : Board = .{};
  var cleared : [ Board.cellCount ]bool = [_]bool{ false } ** Board.cellCount;
  const x : i32 = 4;

  gameBoard.cells[ getIndex( x, 0 ) ] = .Red;
  gameBoard.cells[ getIndex( x, 2 ) ] = .Red;
  gameBoard.cells[ getIndex( x, 4 ) ] = .Blue;
  cleared[ getIndex( x, 5 ) ] = true;
  cleared[ getIndex( x, 10 ) ] = true;

  const plan = buildMarkedColumnCollapsePlan( &gameBoard, &cleared );
  var fallCounts = plan.fallCounts;

  stepColumnTowardTarget( &gameBoard, x, &fallCounts );
  try std.testing.expectEqual( Cell.Red,  gameBoard.cells[ getIndex( x, 1 ) ] );
  try std.testing.expectEqual( Cell.Red,  gameBoard.cells[ getIndex( x, 3 ) ] );
  try std.testing.expectEqual( Cell.Blue, gameBoard.cells[ getIndex( x, 5 ) ] );

  stepColumnTowardTarget( &gameBoard, x, &fallCounts );

  try std.testing.expectEqual( Cell.Red,  gameBoard.cells[ getIndex( x, 2 ) ] );
  try std.testing.expectEqual( Cell.Red,  gameBoard.cells[ getIndex( x, 4 ) ] );
  try std.testing.expectEqual( Cell.Blue, gameBoard.cells[ getIndex( x, 6 ) ] );
}
