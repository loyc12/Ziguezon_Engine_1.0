const eng = @import( "engine" );
const utl = @import( "utils" );

const stateInj = @import( "stateInjects.zig" );
const tlmp = utl.legacy_tilemap;

const Tilemap = tlmp.Tilemap;


// ================================ STEP INJECTION FUNCTIONS ================================

/// Handles shell controls and manual preview selection during piece development.
pub fn OnUpdateInputs( ng : *eng.Engine ) void
{
  _ = ng;

  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.r ))
  {
    stateInj.GAME.reset();
    stateInj.syncGridDisplay();
  }

  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.kp_add      )){ stateInj.GAME.changePieceBy(     1 ); }
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.kp_subtract )){ stateInj.GAME.changePieceBy(    -1 ); }
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.kp_multiply )){ stateInj.GAME.changeRotationBy(  1 ); }
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.kp_divide   )){ stateInj.GAME.changeRotationBy( -1 ); }

  // The engine refreshes the camera before calling this hook.
  if( utl.ray.isWindowResized() ){ stateInj.updateGridScale(); }
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

  for( 0 .. 4 )| index |
  {
    const preview = stateInj.GAME.getPreviewCell( index );
    if( !grid.isCoordsValid( preview.coords )){ continue; }

    const pos = grid.getAbsTilePos( preview.coords );
    var col = stateInj.getCellColour( preview.cell );

    if( preview.isAnchor ){ col = col.addRGB( 64 ); }

    eng.wDraw.hexa( pos.toVec2(), radii, pos.a, col );
  }
}

/// Renders the small shell HUD without taking on a general UI dependency.
pub fn OnRenderOverlay( ng : *eng.Engine ) void
{
  _ = ng;

  const screenCenter = utl.getHalfScreenSize();

  utl.sDraw.textCenter( "Tetrom", .new( screenCenter.x, 48.0 ), 48.0, .white );
  utl.sDraw.textLeft( "R: reset", .new( 24.0, 88.0 ), 20.0, .lGray );
  utl.sDraw.textLeft( "Keypad + / -: piece", .new( 24.0, 116.0 ), 20.0, .lGray );
  utl.sDraw.textLeft( "Keypad * / /: rotation", .new( 24.0, 144.0 ), 20.0, .lGray );
  utl.sDraw.textLeft( "Pale cell: anchor", .new( 24.0, 172.0 ), 20.0, .lGray );
  utl.sDraw.textLeftFmt( "Piece: {s}   Rotation: {s}", .{ @tagName( stateInj.GAME.activePiece.kind ), @tagName( stateInj.GAME.activePiece.rotation ) }, .new( 24.0, 200.0 ), 20.0, .white );
}
