const eng = @import( "engine" );
const utl = @import( "utils" );

const stateInj = @import( "stateInjects.zig" );
const game = @import( "game.zig" );
const tlmp = utl.legacy_tilemap;

const Tilemap = tlmp.Tilemap;

/// Seconds between automatic falling steps. Tune freely while debugging.
pub var FALLING_SPEED : f32 = 1.0;

/// Seconds after spawning before gravity may begin falling the new piece.
pub var AIR_TIME : f32 = 0.5;

/// Seconds a grounded piece remains movable before gravity locks it.
pub var LOCK_DELAY : f32 = 0.5;

/// Enables automatic falling while preserving the manual movement controls.
pub var GRAVITY_MODE : bool = false;

const INPUT_REPEAT_DELAY : f32 = 0.25;

var fallingElapsed : f32 = 0.0;
var airElapsed     : f32 = 0.0;
var lockElapsed    : f32 = 0.0;
var moveHeldTimes  : [ 4 ]f32 = [_]f32{ 0.0 } ** 4;

// ================================ STEP INJECTION FUNCTIONS ================================

/// Handles shell controls and manual preview selection during piece development.
pub fn OnUpdateInputs( ng : *eng.Engine ) void
{
  const deltaTime = ng.time.measuredTickDelta.toRayDeltaTime();

  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.enter ))
  {
    stateInj.GAME.reset( &ng.rng );
    resetInputTimers();
    stateInj.syncGridDisplay();
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

  if( GRAVITY_MODE ){ tickGravity( &ng.rng, deltaTime ); }

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
    logClearResult( result.clear );
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
  logClearResult( result.clear );
  if( result.gameOver ){ utl.log( .INFO, @src(), "Game over: spawned piece collided with the board", .{} ); }
}

fn logClearResult( clear : game.ClearResult ) void
{
  if( clear.lineCount == 0 ){ return; }

  utl.log( .INFO, @src(), "Cleared {d} diagonal lines, {d} crossings, +{d} score", .{ clear.lineCount, clear.crossings, clear.scoreAward });
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
    utl.log( .DEBUG, @src(), "Debug rotation succeeded with wall kick", .{} );
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

  renderActivePiece( grid );
}

fn renderActivePiece( grid : *const Tilemap ) void
{
  const gridFactor : f64 = @floatCast( grid.tileShape.getTileScaleFactor() );
  const radii = grid.tileScale.mulVal( gridFactor * 0.88 );

  for( 0 .. @as( usize, stateInj.GAME.activePiece.getLayout().cellCount ))| index |
  {
    const preview = stateInj.GAME.getPreviewCell( index );
    if( !grid.isCoordsValid( preview.coords )){ continue; }

    const pos = grid.getAbsTilePos( preview.coords );
    var col = stateInj.getCellColour( preview.cell );

    if( preview.isAnchor ){ col = col.subRGB( 16 ); }

    eng.wDraw.hexa( pos.toVec2(), radii, pos.a, col );
  }
}

/// Renders the small shell HUD without taking on a general UI dependency.
pub fn OnRenderOverlay( ng : *eng.Engine ) void
{
  _ = ng;

  const screenCenter = utl.getHalfScreenSize();
  const screenSize   = utl.getScreenSize();

  utl.sDraw.textCenter(  "Tetrom",   .new( screenCenter.x, 48.0 ), 48.0, .cyan );
  utl.sDraw.textLeft(    "Enter: reset", .new( 24.0, 88.0 ), 20.0, .yellow );
  utl.sDraw.textLeft(    "= / - : piece    W / S: vertical    A / D : diagonal down", .new( 24.0, 116.0 ), 20.0, .yellow );
  utl.sDraw.textLeft(    "Q / E : rotate and wall kick    G : toggle gravity", .new( 24.0, 144.0 ), 20.0, .yellow );
  utl.sDraw.textLeftFmt( "Gravity : {s}   Fall : {d:.2}s   Air : {d:.2}s   Lock : {d:.2}s", .{ if( GRAVITY_MODE ) "on" else "manual", FALLING_SPEED, AIR_TIME, LOCK_DELAY }, .new( 24.0, 172.0 ), 20.0, .yellow );
  utl.sDraw.textLeftFmt( "Piece : {s}   Rotation : {s}", .{ @tagName( stateInj.GAME.activePiece.kind ), @tagName( stateInj.GAME.activePiece.rotation ) }, .new( 24.0, 228.0 ), 20.0, .white );
  utl.sDraw.textRightFmt( "Score : {d}", .{ stateInj.GAME.score }, .new( screenSize.x - 24.0, 40.0 ), 28.0, .white );

  if( stateInj.GAME.isGameOver )
  {
    utl.sDraw.textCenter( "GAME OVER", screenCenter, 64.0, .red );
    utl.sDraw.textCenterFmt( "Score : {d}", .{ stateInj.GAME.score }, .new( screenCenter.x, screenCenter.y + 64.0 ), 32.0, .white );
    utl.sDraw.textCenter( "Enter : restart", .new( screenCenter.x, screenCenter.y + 104.0 ), 28.0, .yellow );
  }
}
