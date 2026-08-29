const eng = @import( "engine" );
const utl = @import( "utils" );

const stateInj = @import( "stateInjects.zig" );
const game = @import( "game.zig" );
const clear = @import( "clearEvent.zig" );
const feedback = @import( "clearFeedback.zig" );
const palette = @import( "palette.zig" );
const tlmp = utl.legacy_tilemap;

const Tilemap = tlmp.Tilemap;

/// Seconds between automatic falling steps. Tune freely while debugging.
pub var FALLING_SPEED : f32 = 0.75;

/// Seconds after spawning before gravity may begin falling the new piece.
pub var AIR_TIME : f32 = 0.5;

/// Seconds a grounded piece remains movable before gravity locks it.
pub var LOCK_DELAY : f32 = 0.75;

/// Enables automatic falling while preserving the manual movement controls.
pub var GRAVITY_MODE : bool = false;

const INPUT_REPEAT_DELAY : f32 = 0.20;
const NEXT_PIECE_SCALE        : f64 = 1.25;
const NEXT_PIECE_RIGHT_OFFSET : f64 = 3.0;

var fallingElapsed : f32 = 0.0;
var airElapsed     : f32 = 0.0;
var lockElapsed    : f32 = 0.0;
var moveHeldTimes  : [ 4 ]f32 = [_]f32{ 0.0 } ** 4;
var CLEAR_FEEDBACK : feedback.ClearFeedback = .{};
var cameraBase     : ?utl.VecA = null;

// ================================ STEP INJECTION FUNCTIONS ================================

/// Handles shell controls and manual preview selection during piece development.
pub fn OnUpdateInputs( ng : *eng.Engine ) void
{
  const deltaTime = ng.time.measuredTickDelta.toRayDeltaTime();

  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.enter ))
  {
    resetClearFeedback( ng );
    stateInj.GAME.reset( &ng.rng );
    resetInputTimers();
    stateInj.syncGridDisplay();
  }

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

  if( stateInj.GAME.isClearEventActive() )
  {
    if( utl.ray.isWindowResized() ){ stateInj.updateGridScale(); }
    return;
  }

  if( stateInj.GAME.isGameOver )
  {
    if( utl.ray.isWindowResized() ){ stateInj.updateGridScale(); }
    return;
  }

  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.g ))
  {
    GRAVITY_MODE = !GRAVITY_MODE;
    resetInputTimers();
    utl.log( .DEBUG, @src(), "Gravity mode {s}", .{ if( GRAVITY_MODE ) "enabled" else "disabled" });
  }

  if( !GRAVITY_MODE and ( utl.ray.isKeyPressed( utl.ray.KeyboardKey.equal ) or utl.ray.isKeyPressed( utl.ray.KeyboardKey.kp_add      ))){ stateInj.GAME.changePieceBy(  1 ); }
  if( !GRAVITY_MODE and ( utl.ray.isKeyPressed( utl.ray.KeyboardKey.minus ) or utl.ray.isKeyPressed( utl.ray.KeyboardKey.kp_subtract ))){ stateInj.GAME.changePieceBy( -1 ); }

  if( !GRAVITY_MODE ){ tryRepeatMove( 0, .w, .new(  0, -1 ), "up",         false, deltaTime ); }
  else { moveHeldTimes[ 0 ] = 0.0; }

  tryRepeatMove( 1, .s, .new(  0,  1 ), "down",       true,  deltaTime );
  tryRepeatMove( 2, .a, .new( -1,  1 ), "down-left",  false, deltaTime );
  tryRepeatMove( 3, .d, .new(  1,  0 ), "down-right", false, deltaTime );

  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.q     )){ tryRotatePiece( -1 ); }
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.e     )){ tryRotatePiece(  1 ); }
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.space )){ lockActivePiece( &ng.rng ); resetInputTimers(); }

  if( GRAVITY_MODE and !stateInj.GAME.isClearEventActive() ){ tickGravity( &ng.rng, deltaTime ); }

  // The engine refreshes the camera before calling this hook.
  if( utl.ray.isWindowResized() ){ stateInj.updateGridScale(); }
}

fn resetInputTimers() void
{
  fallingElapsed = 0.0;
  airElapsed     = 0.0;
  lockElapsed    = 0.0;
  moveHeldTimes  = [_]f32{ 0.0 } ** 4;
}

fn tryRepeatMove( index : usize, key : utl.ray.KeyboardKey, offset : game.HexCoord, direction : []const u8, resetsFallTimer : bool, deltaTime : f32 ) void
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
  if( moveHeldTimes[ index ] < INPUT_REPEAT_DELAY ){ return; }

  moveHeldTimes[ index ] = 0.0;
  tryMovePiece( offset, direction, resetsFallTimer );
}

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
    utl.log( .DEBUG, @src(), "Gravity locked {d} cells; ignored {d} outside the board", .{ result.locked, result.outsideBoard });
    if( result.clearStarted )| wave |{ startClearFeedback( wave ); }
    if( result.gameOver ){ utl.log( .INFO, @src(), "Game over: spawned piece collided with the board", .{} ); }
    return;
  }

  lockElapsed = 0.0;
  fallingElapsed += deltaTime;
  if( fallingElapsed < FALLING_SPEED ){ return; }

  fallingElapsed = 0.0;
  const collision = stateInj.GAME.tryMoveBy( .new( 0, 1 ));
  if( collision.isClear() ){ return; }

  logIllegalMove( "gravity", collision );
}

fn lockActivePiece( rng : *utl.Randomiser ) void
{
  const result = stateInj.GAME.lockActivePiece( rng );
  utl.log( .DEBUG, @src(), "Locked {d} piece cells; ignored {d} cells outside the board", .{ result.locked, result.outsideBoard });
  if( result.clearStarted )| wave |{ startClearFeedback( wave ); }
  if( result.gameOver ){ utl.log( .INFO, @src(), "Game over: spawned piece collided with the board", .{} ); }
}

fn startClearFeedback( wave : clear.WaveSummary ) void
{
  CLEAR_FEEDBACK.startWave( wave );
  utl.log( .INFO, @src(), "Cleared {d} diagonal lines, {d} crossings, wave +{d}, combo +{d}", .{ wave.lineCount, wave.crossings, wave.latestWaveScore, wave.comboBonus });
}

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

fn tryMovePiece( offset : game.HexCoord, direction : []const u8, resetsFallTimer : bool ) void
{
  const collision = stateInj.GAME.tryMoveBy( offset );
  if( collision.isClear() )
  {
    if( resetsFallTimer ){ fallingElapsed = 0.0; }
    lockElapsed = 0.0;
    utl.log( .DEBUG, @src(), "Debug piece moved {s}", .{ direction });
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
    utl.log( .DEBUG, @src(), "Debug rotation succeeded with kick", .{} );
    return;
  }
  if( result.collision.isClear() )
  {
    lockElapsed = 0.0;
    utl.log( .DEBUG, @src(), "Debug piece rotated", .{} );
    return;
  }

  logIllegalMove( "rotation", result.collision );
}

fn logIllegalMove( action : []const u8, collision : game.Collision ) void
{
  if( collision.wall  ){ utl.log( .DEBUG, @src(), "Illegal {s}: wall collision",  .{ action }); }
  if( collision.floor ){ utl.log( .DEBUG, @src(), "Illegal {s}: floor collision", .{ action }); }
  if( collision.cell  ){ utl.log( .DEBUG, @src(), "Illegal {s}: cell collision",  .{ action }); }
}

/// Renders the fixed board through the engine's world draw pass.
pub fn OnRenderWorld( ng : *eng.Engine ) void
{
  const grid = stateInj.getGrid() orelse return;

  // The grid is a display cache; keep it derived from the game-owned board.
  stateInj.syncGridDisplay();
  grid.drawSelf( ng.camera.toViewBox(), eng.wDraw );

  if( !stateInj.GAME.isClearEventActive() ){ renderActivePiece( grid ); }
  renderNextPiece( grid );
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

/// Renders the small shell HUD without taking on a general UI dependency.
pub fn OnRenderOverlay( ng : *eng.Engine ) void
{
  _ = ng;

  const screenCenter = utl.getHalfScreenSize();
  const screenSize   = utl.getScreenSize();
  const leftX        : f64 = 24.0;
  const rightX       : f64 = screenSize.x - 24.0;
  const bottomY      : f64 = screenSize.y - 32.0;

  renderTitle( screenCenter.x );
  utl.sDraw.textLeft(     "Enter: reset", .new( leftX, bottomY - 84.0 ), 20.0, palette.CONTROLS );
  utl.sDraw.textLeft(     "= / - : piece    W / S: vertical    A / D : diagonal down", .new( leftX, bottomY - 56.0 ), 20.0, palette.CONTROLS );
  utl.sDraw.textLeft(     "Q / E : rotate and wall kick    G : toggle gravity", .new( leftX, bottomY - 28.0 ), 20.0, palette.CONTROLS );
  utl.sDraw.textRightFmt( "Gravity : {s}   Fall : {d:.2}s   Air : {d:.2}s   Lock : {d:.2}s", .{ if( GRAVITY_MODE ) "on" else "manual", FALLING_SPEED, AIR_TIME, LOCK_DELAY }, .new( rightX, bottomY - 56.0 ), 20.0, palette.TEXT_MUTED );
  utl.sDraw.textRightFmt( "Piece : {s} Piece   Rotation : {s}", .{ stateInj.GAME.activePiece.kind.getName(), stateInj.GAME.activePiece.rotation.getName() }, .new( rightX, bottomY - 28.0 ), 20.0, palette.TEXT );
  utl.sDraw.textRightFmt( "Score : {d}", .{ stateInj.GAME.score }, .new( rightX, bottomY - 84.0 ), 28.0, palette.SCORE );

  if( CLEAR_FEEDBACK.isVisible )
  {
    const scorePos  : utl.Vec2 = .new( screenCenter.x, screenCenter.y - 28.0 );
    const detailPos : utl.Vec2 = .new( screenCenter.x, screenCenter.y + 28.0 );

    utl.sDraw.textCenterFmt( "+{d}", .{ CLEAR_FEEDBACK.eventScore }, scorePos, CLEAR_FEEDBACK.getEventTextSize(), palette.SCORE );
    utl.sDraw.textCenterFmt( "Wave +{d}    Combo +{d}", .{ CLEAR_FEEDBACK.latestWaveScore, CLEAR_FEEDBACK.comboBonus }, detailPos, 22.0, palette.CONTROLS );
  }

  if( stateInj.GAME.isGameOver )
  {
    utl.sDraw.coverScreenWithCol( palette.GAME_OVER_VEIL );
    utl.sDraw.textCenter(    "GAME OVER", screenCenter, 64.0, palette.RED );
    utl.sDraw.textCenterFmt( "Score : {d}", .{ stateInj.GAME.score }, .new( screenCenter.x, screenCenter.y + 64.0 ), 32.0, palette.SCORE );
    utl.sDraw.textCenter(    "Enter : restart", .new( screenCenter.x, screenCenter.y + 104.0 ), 28.0, palette.CONTROLS );
  }
}

/// Draws the title in tile-palette rainbow order, from red through purple.
fn renderTitle( centerX : f64 ) void
{
  const letters = [ _ ][ :0 ]const u8{ "T", "E", "T", "R", "O", "M" };
  const colours = [ _ ]utl.Colour{ palette.RED, palette.ORANGE, palette.YELLOW, palette.CYAN, palette.BLUE, palette.PURPLE };
  const spacing : f64 = 36.0;
  const firstX = centerX - (( @as( f64, @floatFromInt( letters.len - 1 )) * spacing ) / 2.0 );

  for( letters, colours, 0 .. )| letter, col, index |
  {
    const x = firstX + ( @as( f64, @floatFromInt( index )) * spacing );
    utl.sDraw.textCenter( letter, .new( x, 48.0 ), 48.0, col );
  }
}
