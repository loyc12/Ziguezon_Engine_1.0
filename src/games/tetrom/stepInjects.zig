const eng = @import( "engine" );
const std = @import( "std" );
const utl = @import( "utils" );

const stateInj = @import( "stateInjects.zig" );
const game = @import( "game.zig" );
const clear = @import( "clearEvent.zig" );
const feedback = @import( "clearFeedback.zig" );
const palette = @import( "palette.zig" );
const tlmp = utl.legacy_tilemap;

const Tilemap = tlmp.Tilemap;

// ================================ GAME TUNING ================================

/// Base seconds between automatic falling steps before any lines are cleared.
pub var MIN_FALLING_SPEED : f32 = 0.40;

/// Lowest tick interval, representing Tetrom's maximum automatic falling speed.
pub var MAX_FALLING_SPEED : f32 = 0.025;

/// Cumulative cleared-line total at which automatic falling reaches its maximum.
pub var SPEED_LINE_CAP : u32 = 100;

/// Seconds after spawning before gravity may begin falling the new piece.
pub var AIR_TIME : f32 = 0.40;

/// Seconds a grounded piece remains movable before gravity locks it.
pub var LOCK_DELAY : f32 = 0.40;

/// How fast do held movement inputs repeat, in seconds
const INPUT_REPEAT_DELAY : f32 = 0.10;

/// Multiplier for direct vertical repeat delay while either Shift key is held.
const SHIFT_REPEAT_FACTOR : f32 = 0.5;

/// Enables automatic falling while preserving the manual movement controls.
pub var GRAVITY_MODE : bool = true;

/// Enables development-only commands, controls, and diagnostics.
pub var DEBUG_MODE : bool = false;

const NEXT_PIECE_SCALE        : f64 = 1.0;
const NEXT_PIECE_RIGHT_OFFSET : f64 = 3.0;

// A small title-screen-only flourish; deliberately fixed rather than configurable.
const TITLE_FALL_DURATION  : f32 = 2.4;
const TITLE_FALL_STEPS     : u8  = 8;
const TITLE_FALL_HEIGHT    : f64 = 1.25;
const SECOND_TITLE_T_INDEX : usize = 2;

// ================================ RUNTIME STATE ================================

var fallingElapsed : f32 = 0.0;
var airElapsed     : f32 = 0.0;
var lockElapsed    : f32 = 0.0;

var moveHeldTimes  : [ 4 ]f32 = [_]f32{ 0.0 } ** 4;
var CLEAR_FEEDBACK : feedback.ClearFeedback = .{};
var cameraBase     : ?utl.VecA = null;
var titleElapsed   : f32 = 0.0;

// ================================ STEP INJECTION FUNCTIONS ================================

/// Handles frame-driven input, clear progression, and active-piece movement.
pub fn OnUpdateInputs( ng : *eng.Engine ) void
{
  // OnUpdateInputs() runs once per rendered frame, before `consumeFrame()`.
  // The previous measured frame duration therefore matches this hook's cadence.
  const deltaTime = ng.time.getMeasuredFrameDeltaFlt();
  tickTitleAnimation( deltaTime );

  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.enter ) and ( !stateInj.GAME.isInitialized or stateInj.GAME.isGameOver or DEBUG_MODE ))
  {
    resetGame( ng, stateInj.GAME.isInitialized );
  }

  if( !stateInj.GAME.isInitialized )
  {
    if( utl.ray.isWindowResized() ){ stateInj.updateGridScale(); }
    return;
  }

  if( stateInj.GAME.isGameOver )
  {
    if( utl.ray.isWindowResized() ){ stateInj.updateGridScale(); }
    return;
  }

  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.p ))
  {
    if( stateInj.GAME.isPaused )
    {
      stateInj.GAME.resumePausedGame( &ng.rng );
      resetInputTimers();
      if( DEBUG_MODE ){ utl.log( .DEBUG, @src(), "Game resumed", .{} ); }
    }
    else
    {
      stateInj.GAME.togglePauseQueue();
      if( DEBUG_MODE ){ utl.log( .DEBUG, @src(), "Pause queue {s}", .{ if( stateInj.GAME.isPauseQueued ) "enabled" else "cancelled" }); }
    }
  }

  if( stateInj.GAME.isPaused )
  {
    if( utl.ray.isWindowResized() ){ stateInj.updateGridScale(); }
    return;
  }

  stateInj.GAME.tickTime( deltaTime );

  const clearTick = stateInj.GAME.tickClearEvent( &ng.rng, deltaTime );

  if( clearTick.newWave )| wave |{ startClearFeedback( wave ); }

  if( clearTick.completedScore )| completedScore |
  {
    CLEAR_FEEDBACK.finishEvent();
    utl.log( .INFO, @src(), "Clear event completed: +{d} total score", .{ completedScore });
    if( clearTick.gameOver ){ utl.log( .INFO, @src(), "Game over: spawned piece collided with the board", .{} ); }
    resetInputTimers();
  }

  CLEAR_FEEDBACK.tick( deltaTime );
  applyCameraShake( ng );

  if( stateInj.GAME.isClearEventActive() or stateInj.GAME.isPaused or stateInj.GAME.isGameOver )
  {
    if( utl.ray.isWindowResized() ){ stateInj.updateGridScale(); }
    return;
  }

  if( DEBUG_MODE and utl.ray.isKeyPressed( utl.ray.KeyboardKey.g ))
  {
    GRAVITY_MODE = !GRAVITY_MODE;
    resetInputTimers();
    utl.log( .DEBUG, @src(), "Gravity mode {s}", .{ if( GRAVITY_MODE ) "enabled" else "disabled" });
  }

  if( DEBUG_MODE and !GRAVITY_MODE and ( utl.ray.isKeyPressed( utl.ray.KeyboardKey.equal ) or utl.ray.isKeyPressed( utl.ray.KeyboardKey.kp_add      ))){ stateInj.GAME.changePieceBy(  1 ); }
  if( DEBUG_MODE and !GRAVITY_MODE and ( utl.ray.isKeyPressed( utl.ray.KeyboardKey.minus ) or utl.ray.isKeyPressed( utl.ray.KeyboardKey.kp_subtract ))){ stateInj.GAME.changePieceBy( -1 ); }

  if( !GRAVITY_MODE )
  {
    tryRepeatMove( 0, .w, .new(  0, -1 ), "up",  false, getVerticalRepeatDelay(), deltaTime );
  }
  else { moveHeldTimes[ 0 ] = 0.0; }

  tryRepeatMove( 1, .s, .new(  0,  1 ), "down",  true,  getVerticalRepeatDelay(), deltaTime );
  tryRepeatMove( 2, .a, .new( -1,  1 ), "left",  false, INPUT_REPEAT_DELAY,       deltaTime );
  tryRepeatMove( 3, .d, .new(  1,  0 ), "right", false, INPUT_REPEAT_DELAY,       deltaTime );

  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.q     )){ tryRotatePiece( -1 ); }
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.e     )){ tryRotatePiece(  1 ); }
  if( DEBUG_MODE and utl.ray.isKeyPressed( utl.ray.KeyboardKey.space )){ lockActivePiece( &ng.rng ); resetInputTimers(); }

  if( GRAVITY_MODE and !stateInj.GAME.isClearEventActive() and !stateInj.GAME.isPaused ){ tickGravity( &ng.rng, deltaTime ); }

  // The engine refreshes the camera before calling this hook.
  if( utl.ray.isWindowResized() ){ stateInj.updateGridScale(); }
}

// ================================ GAME LIFECYCLE ================================

/// Resets a game from its current fixed seed or a newly generated automatic seed.
fn resetGame( ng : *eng.Engine, refreshAutomaticSeed : bool ) void
{
  resetClearFeedback( ng );
  ng.resetRandomiser( refreshAutomaticSeed );
  stateInj.GAME.reset( &ng.rng );
  resetInputTimers();
  stateInj.syncGridDisplay();
}

fn resetInputTimers() void
{
  fallingElapsed = 0.0;
  airElapsed     = 0.0;
  lockElapsed    = 0.0;
  moveHeldTimes  = [_]f32{ 0.0 } ** 4;
}

// ================================ INPUT MOVEMENT ================================

fn tryRepeatMove( index : usize, key : utl.ray.KeyboardKey, offset : game.HexCoord, direction : []const u8, resetsFallTimer : bool, repeatDelay : f32, deltaTime : f32 ) void
{
  if( utl.ray.isKeyPressed( key ))
  {
    moveHeldTimes[ index ] = 0.0;
    tryMovePiece( offset, direction, resetsFallTimer );
    return;
  }
  if( !utl.ray.isKeyDown( key ))
  {
    moveHeldTimes[ index ] = 0.0;
    return;
  }

  moveHeldTimes[ index ] += deltaTime;
  if( moveHeldTimes[ index ] < repeatDelay ){ return; }

  moveHeldTimes[ index ] = 0.0;
  tryMovePiece( offset, direction, resetsFallTimer );
}

/// Accelerates only forced vertical descent; diagonal and lateral movement stay stable.
fn getVerticalRepeatDelay() f32
{
  const isShiftHeld =
    utl.ray.isKeyDown( utl.ray.KeyboardKey.left_shift ) or
    utl.ray.isKeyDown( utl.ray.KeyboardKey.right_shift );

  return if( isShiftHeld ) INPUT_REPEAT_DELAY * SHIFT_REPEAT_FACTOR else INPUT_REPEAT_DELAY;
}

// ================================ GRAVITY AND LOCKING ================================

fn tickGravity( rng : *utl.Randomiser, deltaTime : f32 ) void
{
  if( airElapsed < AIR_TIME )
  {
    airElapsed += deltaTime;
    return;
  }

  var below = stateInj.GAME.activePiece;
      below.anchor = below.anchor.add( .new( 0, 1 ));

  const belowCollision = stateInj.GAME.checkPieceCollision( &below );
  if( belowCollision.floor or belowCollision.cell )
  {
    lockElapsed += deltaTime;
    if( lockElapsed < LOCK_DELAY ){ return; }

    const result = stateInj.GAME.lockActivePiece( rng );
    resetInputTimers();
    if( DEBUG_MODE ){ utl.log( .DEBUG, @src(), "Gravity locked {d} cells; ignored {d} outside the board", .{ result.locked, result.outsideBoard }); }
    if( result.clearStarted )| wave |{ startClearFeedback( wave ); }
    if( result.gameOver ){ utl.log( .INFO, @src(), "Game over: spawned piece collided with the board", .{} ); }
    return;
  }

  lockElapsed = 0.0;
  fallingElapsed += deltaTime;
  if( fallingElapsed < getCurrentFallingSpeed() ){ return; }

  fallingElapsed = 0.0;
  const collision = stateInj.GAME.tryMoveBy( .new( 0, 1 ));
  if( collision.isClear() ){ return; }

  logIllegalMove( "gravity", collision );
}

fn lockActivePiece( rng : *utl.Randomiser ) void
{
  const result = stateInj.GAME.lockActivePiece( rng );
  if( DEBUG_MODE ){ utl.log( .DEBUG, @src(), "Locked {d} piece cells; ignored {d} cells outside the board", .{ result.locked, result.outsideBoard }); }
  if( result.clearStarted )| wave |{ startClearFeedback( wave ); }
  if( result.gameOver ){ utl.log( .INFO, @src(), "Game over: spawned piece collided with the board", .{} ); }
}

fn startClearFeedback( wave : clear.WaveSummary ) void
{
  CLEAR_FEEDBACK.startWave( wave );
  utl.log( .INFO, @src(), "Cleared {d} diagonal lines, {d} crossings, wave +{d}, combo +{d}", .{ wave.lineCount, wave.crossings, wave.latestWaveScore, wave.comboBonus });
}

/// Returns the current automatic fall interval from the game's cumulative lines.
fn getCurrentFallingSpeed() f32
{
  return getFallingSpeedForLines( stateInj.GAME.clearedLines, MIN_FALLING_SPEED, MAX_FALLING_SPEED, SPEED_LINE_CAP );
}

/// Quadratic ease-out reaches the speed cap smoothly without exceeding it.
fn getFallingSpeedForLines( clearedLines : u32, baseSpeed : f32, maxSpeed : f32, lineCap : u32 ) f32
{
  const safeBase = @max( baseSpeed, 0.001 );
  const safeMax  = utl.clmp( maxSpeed, 0.001, safeBase );
  const safeCap  = @max( lineCap, 1 );
  const lines : f32 = @floatFromInt( @min( clearedLines, safeCap ));
  const progress = lines / @as( f32, @floatFromInt( safeCap ));
  const plateauProgress = 1.0 - (( 1.0 - progress ) * ( 1.0 - progress ));

  return utl.lerp( safeBase, safeMax, plateauProgress );
}

// ================================ CLEAR FEEDBACK AND CAMERA ================================

fn resetClearFeedback( ng : *eng.Engine ) void
{
  restoreCamera( ng );
  CLEAR_FEEDBACK.reset();
}

fn applyCameraShake( ng : *eng.Engine ) void
{
  if( !CLEAR_FEEDBACK.isShaking() )
  {
    restoreCamera( ng );
    return;
  }

  if( cameraBase == null ){ cameraBase = ng.camera.cam.pos; }

  const base = cameraBase.?;
  const offset = CLEAR_FEEDBACK.getCameraOffset();
  ng.camera.cam.pos = .{
    .x = base.x + offset.x,
    .y = base.y + offset.y,
    .a = .{ .r = base.a.r + offset.a.r },
  };
}

fn restoreCamera( ng : *eng.Engine ) void
{
  if( cameraBase )| base |{ ng.camera.cam.pos = base; }
  cameraBase = null;
}

// ================================ PIECE TRANSFORMS ================================

fn tryMovePiece( offset : game.HexCoord, direction : []const u8, resetsFallTimer : bool ) void
{
  const collision = stateInj.GAME.tryMoveBy( offset );
  if( collision.isClear() )
  {
    if( resetsFallTimer ){ fallingElapsed = 0.0; }
    lockElapsed = 0.0;
    if( DEBUG_MODE ){ utl.log( .DEBUG, @src(), "Debug piece moved {s}", .{ direction }); }
    return;
  }

  logIllegalMove( "move", collision );
}

fn tryRotatePiece( offset : i32 ) void
{
  const result = stateInj.GAME.tryRotateBy( offset );
  if( result.kicked )
  {
    lockElapsed = 0.0;
    if( DEBUG_MODE ){ utl.log( .DEBUG, @src(), "Debug rotation succeeded with kick", .{} ); }
    return;
  }
  if( result.collision.isClear() )
  {
    lockElapsed = 0.0;
    if( DEBUG_MODE ){ utl.log( .DEBUG, @src(), "Debug piece rotated", .{} ); }
    return;
  }

  logIllegalMove( "rotation", result.collision );
}

fn logIllegalMove( action : []const u8, collision : game.Collision ) void
{
  if( !DEBUG_MODE ){ return; }

  if( collision.wall  ){ utl.log( .DEBUG, @src(), "Illegal {s}: wall collision",  .{ action }); }
  if( collision.floor ){ utl.log( .DEBUG, @src(), "Illegal {s}: floor collision", .{ action }); }
  if( collision.cell  ){ utl.log( .DEBUG, @src(), "Illegal {s}: cell collision",  .{ action }); }
}

// ================================ WORLD RENDERING ================================

/// Renders the fixed board through the engine's world draw pass.
pub fn OnRenderWorld( ng : *eng.Engine ) void
{
  if( !stateInj.GAME.isInitialized ){ return; }

  const grid = stateInj.getGrid() orelse return;

  // The grid is a display cache; keep it derived from the game-owned board.
  stateInj.syncGridDisplay();
  grid.drawSelf( ng.camera.toViewBox(), eng.wDraw );

  if( !stateInj.GAME.isClearEventActive() and !stateInj.GAME.isPaused ){ renderActivePiece( grid ); }
  if( !stateInj.GAME.isPaused ){ renderNextPiece( grid ); }
}

fn renderActivePiece( grid : *const Tilemap ) void
{
  const gridFactor : f64 = @floatCast( grid.tileShape.getTileScaleFactor() );
  const radii = grid.tileScale.mulVal( gridFactor * 0.88 );

  renderEmptyAnchor( grid, &stateInj.GAME.activePiece, &stateInj.GAME.board, radii );

  for( 0 .. @as( usize, stateInj.GAME.activePiece.getLayout().cellCount ))| index |
  {
    const preview = stateInj.GAME.getPreviewCell( index );
    if( !grid.isCoordsValid( preview.coords )){ continue; }

    const pos = grid.getAbsTilePos( preview.coords );
    var col = stateInj.getCellColour( preview.cell );
    if( stateInj.GAME.activePiece.isAnchorCell( index )){ col = col.subRGB( palette.INTERNAL_ANCHOR_DARKEN ); }

    eng.wDraw.hexa( pos.toVec2(), radii, pos.a, col );
  }
}

/// Marks C's empty centre anchor only when it does not cover a settled board cell.
fn renderEmptyAnchor( grid : *const Tilemap, piece : *const game.ActivePiece, settledBoard : *const game.Board, radii : utl.Vec2 ) void
{
  if( !piece.hasEmptyAnchor() ){ return; }

  const coords = piece.anchor.toBoardCoords();
  if( !grid.isCoordsValid( coords )){ return; }

  const cell = settledBoard.getCell( coords ) orelse return;
  if( cell != .Empty ){ return; }

  const pos = grid.getAbsTilePos( coords );
  eng.wDraw.hexa( pos.toVec2(), radii, pos.a, palette.PLAYFIELD.addRGB( palette.EMPTY_ANCHOR_LIGHTEN ));
}

/// Renders the queued next piece beside the board without consuming its bag entry.
fn renderNextPiece( grid : *const Tilemap ) void
{
  const nextPiece = game.ActivePiece{
    .kind   = stateInj.GAME.getNextPiece(),
    .anchor = game.HexCoord.fromBoardCoords( .{ .x = game.Board.width / 2, .y = game.Board.height / 2 } ),
  };
  const anchorCoords = nextPiece.anchor.toBoardCoords();
  const anchorPos    = grid.getAbsTilePos( anchorCoords );
  const boardBox     = grid.getMapBoundingBox();
  const gridFactor   : f64 = @floatCast( grid.tileShape.getTileScaleFactor() );
  const radii        = grid.tileScale.mulVal( gridFactor * 0.88 * NEXT_PIECE_SCALE );
  const previewPos   = utl.Vec2.new( boardBox.getRightX() + ( radii.x * NEXT_PIECE_RIGHT_OFFSET ), boardBox.center.y );

  if( nextPiece.hasEmptyAnchor() )
  {
    eng.wDraw.hexa( previewPos, radii, anchorPos.a, palette.PLAYFIELD.addRGB( palette.EMPTY_ANCHOR_LIGHTEN ));
  }

  for( 0 .. @as( usize, nextPiece.getLayout().cellCount ))| index |
  {
    const cellCoords = nextPiece.getCellHex( index ).toBoardCoords();
    const cellPos    = grid.getAbsTilePos( cellCoords );
    const offset     = cellPos.toVec2().sub( anchorPos.toVec2() ).mulVal( NEXT_PIECE_SCALE );
    const pos        = previewPos.add( offset );
    var col = stateInj.getCellColour( game.getCellForPiece( nextPiece.kind ));
    if( nextPiece.isAnchorCell( index )){ col = col.subRGB( palette.INTERNAL_ANCHOR_DARKEN ); }

    eng.wDraw.hexa( pos, radii, anchorPos.a, col );
  }
}

// ================================ OVERLAY RENDERING ================================

/// Renders the small shell HUD without taking on a general UI dependency.
pub fn OnRenderOverlay( ng : *eng.Engine ) void
{
  const screenSize   = utl.getScreenSize();
  const screenCenter = screenSize.mulVal( 0.5 );

  if( !stateInj.GAME.isInitialized )
  {
    renderTitle( screenCenter.x, screenCenter.y - 56.0, 96.0, true );
    utl.sDraw.textCenterFmt( "Seed : {d}", .{ ng.randomSeed }, .new( screenCenter.x, screenCenter.y + 20.0 ), 22.0, palette.TEXT_MUTED );
    utl.sDraw.textCenter( "Press ENTER to start the game", .new( screenCenter.x, screenCenter.y + 60.0 ), 28.0, palette.TEXT );
    return;
  }

  const leftX          : f64 = 24.0;
  const rightX         : f64 = screenSize.x - 20.0;
  const bottomY        : f64 = screenSize.y - 30.0;
  const elapsedSeconds : u64 = @intFromFloat( stateInj.GAME.elapsedTime );
  const elapsedMinutes       = @divFloor( elapsedSeconds, 60 );
  const elapsedRemainder     = @mod(      elapsedSeconds, 60 );

  renderTitle( screenCenter.x, 48.0, 48.0, false );

  if( DEBUG_MODE )
  {
    utl.sDraw.textLeft( "G  : toggle gravity",  .new( leftX, bottomY - 200.0 ), 20.0, palette.CONTROLS );
    utl.sDraw.textLeft( "= / - : change piece", .new( leftX, bottomY - 170.0 ), 20.0, palette.CONTROLS );
    utl.sDraw.textLeft( "Space : lock piece",   .new( leftX, bottomY - 140.0 ), 20.0, palette.CONTROLS );
    utl.sDraw.textLeft( "Enter : reset game",   .new( leftX, bottomY - 110.0 ), 20.0, palette.CONTROLS );
    utl.sDraw.textRightFmt( "Gravity : {s}   Air : {d:.2}s   Lock : {d:.2}s", .{ if( GRAVITY_MODE ) "on" else "manual", AIR_TIME, LOCK_DELAY }, .new( rightX, bottomY - 40.0 ), 20.0, palette.TEXT_MUTED );
  }

  // NOTES : Always show these controls.
  utl.sDraw.textLeft( "P : queue pause",  .new( leftX, bottomY - 60.0 ), 20.0, palette.CONTROLS );
  utl.sDraw.textLeft( "A / S / D : move", .new( leftX, bottomY - 30.0 ), 20.0, palette.CONTROLS );
  utl.sDraw.textLeft( "Q / E : rotate",   .new( leftX, bottomY -  0.0 ), 20.0, palette.CONTROLS );

  utl.sDraw.textRightFmt( "Score : {d}", .{ stateInj.GAME.score        }, .new( rightX, 30.0  ), 30.0, palette.SCORE );
  utl.sDraw.textRightFmt( "Lines : {d}", .{ stateInj.GAME.clearedLines }, .new( rightX, 70.0  ), 20.0, getLineCountColour() );
  utl.sDraw.textRightFmt( "Tiles : {d}", .{ stateInj.GAME.clearedTiles }, .new( rightX, 100.0 ), 20.0, palette.TEXT );
  utl.sDraw.textRightFmt( "Time : {d}:{d:0>2}", .{ elapsedMinutes, elapsedRemainder }, .new( rightX, 130.0 ), 20.0, palette.TEXT );

  utl.sDraw.textRightFmt( "Piece : {s}   Angle : {s}   Fall Speed : {d:.2}", .{ stateInj.GAME.activePiece.kind.getName(), stateInj.GAME.activePiece.rotation.getName(), getCurrentFallingSpeed() }, .new( rightX, bottomY - 0.0 ), 20.0, palette.TEXT );

  if( stateInj.GAME.isPauseQueued )
  {
    utl.sDraw.textRight( "Pause : queued", .new( rightX, bottomY - 84.0 ), 20.0, palette.CONTROLS );
  }

  if( CLEAR_FEEDBACK.isVisible )
  {
    const scorePos  : utl.Vec2 = .new( screenCenter.x, screenCenter.y - 28.0 );
    const detailPos : utl.Vec2 = .new( screenCenter.x, screenCenter.y + 28.0 );

    utl.sDraw.textCenterFmt( "+{d}", .{ CLEAR_FEEDBACK.eventScore }, scorePos, CLEAR_FEEDBACK.getEventTextSize(), palette.SCORE );
    utl.sDraw.textCenterFmt( "Wave +{d}    Combo +{d}", .{ CLEAR_FEEDBACK.latestWaveScore, CLEAR_FEEDBACK.comboBonus }, detailPos, 22.0, palette.CONTROLS );
  }

  if( stateInj.GAME.isPaused )
  {
    utl.sDraw.coverScreenWithCol( palette.GAME_OVER_VEIL );
    utl.sDraw.textCenter(    "GAME PAUSED", screenCenter, 64.0, palette.TEXT );
  }
  else if( stateInj.GAME.isGameOver )
  {
    utl.sDraw.coverScreenWithCol( palette.GAME_OVER_VEIL );
    utl.sDraw.textCenter(    "GAME OVER", screenCenter, 64.0, palette.RED );
    utl.sDraw.textCenterFmt( "Score : {d}", .{ stateInj.GAME.score }, .new( screenCenter.x, screenCenter.y + 64.0 ), 32.0, palette.SCORE );
    utl.sDraw.textCenterFmt( "Seed : {d}", .{ ng.randomSeed }, .new( screenCenter.x, screenCenter.y + 102.0 ), 24.0, palette.TEXT );
    utl.sDraw.textCenter(    "Press ENTER to restart the game", .new( screenCenter.x, screenCenter.y + 142.0 ), 28.0, palette.CONTROLS );
  }
}

/// Advances the single-run title animation while Tetrom receives frame input.
fn tickTitleAnimation( deltaTime : f32 ) void
{
  const totalDuration = TITLE_FALL_DURATION + clear.CLEAR_FLASH_DURATION + clear.CLEAR_FADE_DURATION;
  if( titleElapsed < totalDuration ){ titleElapsed += deltaTime; }
}

/// Draws the title in tile-palette rainbow order, with an optional title-screen flourish.
fn renderTitle( centerX : f64, y : f64, fontSize : f64, isAnimated : bool ) void
{
  const letters = [ _ ][ :0 ]const u8{ "T", "E", "T", "R", "O", "M" };
  const colours = [ _ ]utl.Colour{ palette.RED, palette.ORANGE, palette.YELLOW, palette.CYAN, palette.BLUE, palette.PURPLE };
  const spacing = fontSize * 0.75;
  const firstX = centerX - (( @as( f64, @floatFromInt( letters.len - 1 )) * spacing ) / 2.0 );

  for( letters, colours, 0 .. )| letter, col, index |
  {
    const x = firstX + ( @as( f64, @floatFromInt( index )) * spacing );
    const letterY = if( isAnimated and index == SECOND_TITLE_T_INDEX ) y + getSecondTitleTOffset( fontSize ) else y;
    const letterCol = if( isAnimated ) getTitleColour( col ) else col;
    utl.sDraw.textCenter( letter, .new( x, letterY ), fontSize, letterCol );
  }
}

/// Returns the stepped downward offset for TETROM's second T until it lodges in place.
fn getSecondTitleTOffset( fontSize : f64 ) f64
{
  const elapsed = @min( titleElapsed, TITLE_FALL_DURATION );
  const stepCount : f32 = @floatFromInt( TITLE_FALL_STEPS );
  const completedSteps = @floor(( elapsed / TITLE_FALL_DURATION ) * stepCount );
  const progress : f64 = @floatCast( completedSteps / stepCount );

  return -fontSize * TITLE_FALL_HEIGHT * ( 1.0 - progress );
}

/// Recreates a clear-style white flash before restoring each title letter's colour.
fn getTitleColour( base : utl.Colour ) utl.Colour
{
  if( titleElapsed < TITLE_FALL_DURATION ){ return base; }

  const flashElapsed = titleElapsed - TITLE_FALL_DURATION;
  if( flashElapsed < clear.CLEAR_FLASH_DURATION )
  {
    return lerpTitleColour( base, palette.WHITE, flashElapsed / clear.CLEAR_FLASH_DURATION );
  }
  if( flashElapsed < clear.CLEAR_FLASH_DURATION + clear.CLEAR_FADE_DURATION )
  {
    const fadeElapsed = flashElapsed - clear.CLEAR_FLASH_DURATION;
    return lerpTitleColour( palette.WHITE, base, fadeElapsed / clear.CLEAR_FADE_DURATION );
  }

  return base;
}

fn lerpTitleColour( from : utl.Colour, to : utl.Colour, progress : f32 ) utl.Colour
{
  const p : f64 = progress;

  return .{
    .r = @intFromFloat( @round( utl.lerp( @as( f64, @floatFromInt( from.r )), @as( f64, @floatFromInt( to.r )), p ))),
    .g = @intFromFloat( @round( utl.lerp( @as( f64, @floatFromInt( from.g )), @as( f64, @floatFromInt( to.g )), p ))),
    .b = @intFromFloat( @round( utl.lerp( @as( f64, @floatFromInt( from.b )), @as( f64, @floatFromInt( to.b )), p ))),
    .a = @intFromFloat( @round( utl.lerp( @as( f64, @floatFromInt( from.a )), @as( f64, @floatFromInt( to.a )), p ))),
  };
}

/// Tints the line counter from HUD white to red across the configured speed cap.
fn getLineCountColour() utl.Colour
{
  const safeCap = @max( SPEED_LINE_CAP, 1 );
  const lines : f64 = @floatFromInt( @min( stateInj.GAME.clearedLines, safeCap ));
  const cap : f64 = @floatFromInt( safeCap );
  const progress = lines / cap;

  return .{
    .r = @intFromFloat( @round( utl.lerp( @as( f64, @floatFromInt( palette.TEXT.r )), @as( f64, @floatFromInt( palette.RED.r )), progress ))),
    .g = @intFromFloat( @round( utl.lerp( @as( f64, @floatFromInt( palette.TEXT.g )), @as( f64, @floatFromInt( palette.RED.g )), progress ))),
    .b = @intFromFloat( @round( utl.lerp( @as( f64, @floatFromInt( palette.TEXT.b )), @as( f64, @floatFromInt( palette.RED.b )), progress ))),
    .a = palette.TEXT.a,
  };
}

// ================================ TESTS ================================

test "falling speed plateaus at the configured line cap"
{
  const base : f32 = 0.40;
  const max  : f32 = 0.025;

  const half   = getFallingSpeedForLines( 50,  base, max, 100 );
  const capped = getFallingSpeedForLines( 100, base, max, 100 );
  const beyond = getFallingSpeedForLines( 200, base, max, 100 );

  try std.testing.expectApproxEqAbs( base, getFallingSpeedForLines( 0, base, max, 100 ), 0.0001 );
  try std.testing.expect( half < base and half > max );
  try std.testing.expectApproxEqAbs( max,   capped,  0.0001 );
  try std.testing.expectApproxEqAbs( capped, beyond, 0.0001 );
}
