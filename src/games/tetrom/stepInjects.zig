const eng = @import( "engine" );
const utl = @import( "utils" );

const stateInj = @import( "stateInjects.zig" );


// ================================ STEP INJECTION FUNCTIONS ================================

/// Handles shell controls until falling-piece input is implemented.
pub fn OnUpdateInputs( ng : *eng.Engine ) void
{
  _ = ng;

  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.r ))
  {
    stateInj.GAME.reset();
    stateInj.syncGridDisplay();
  }

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
}

/// Renders the small shell HUD without taking on a general UI dependency.
pub fn OnRenderOverlay( ng : *eng.Engine ) void
{
  _ = ng;

  const screenCenter = utl.getHalfScreenSize();

  utl.sDraw.textCenter( "Tetrom", .new( screenCenter.x, 48.0 ), 48.0, .white );
  utl.sDraw.textLeft( "R: reset", .new( 24.0, 88.0 ), 20.0, .lGray );
}
