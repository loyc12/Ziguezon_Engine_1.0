const std      = @import( "std"    );
const eng      = @import( "engine" );
const utl      = @import( "utils"  );

// ================================ GLOBAL GAME VARIABLES ================================

var SHOW_OVERLAY : bool = true;


// ================================ STEP INJECTION FUNCTIONS ================================
// These functions are called by the engine at various points in the game loop ( see loopLogic() in engine.zig ).

pub fn OnLoopStart( ng : *eng.Engine ) void // Called by engine.loopLogic()
{
  _ = ng;
}

pub fn OnLoopEnd( ng : *eng.Engine ) void // Called by engine.loopLogic()
{
  _ = ng;
}

pub fn OnLoopUpdate( ng : *eng.Engine ) void // Called by engine.loopLogic() ( every frame, no exception )
{
  _ = ng;
}


pub fn OnInputUpdate( ng : *eng.Engine ) void // Called by engine.updateInputs() ( every frame, no exception )
{
  // Toggle pause if the P key is pressed
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.enter ) or utl.ray.isKeyPressed( utl.ray.KeyboardKey.p )){ ng.togglePause(); }

  // Move the camera with the WASD or arrow keys
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.w ) or utl.ray.isKeyDown( utl.ray.KeyboardKey.up    )){ eng.G_ENG.camera.moveByS( utl.Vec2.new(  0, -8 )); }
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.s ) or utl.ray.isKeyDown( utl.ray.KeyboardKey.down  )){ eng.G_ENG.camera.moveByS( utl.Vec2.new(  0,  8 )); }
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.a ) or utl.ray.isKeyDown( utl.ray.KeyboardKey.left  )){ eng.G_ENG.camera.moveByS( utl.Vec2.new( -8,  0 )); }
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.d ) or utl.ray.isKeyDown( utl.ray.KeyboardKey.right )){ eng.G_ENG.camera.moveByS( utl.Vec2.new(  8,  0 )); }

  // Zoom in and out with the mouse wheel
  if( utl.ray.getMouseWheelMove() > 0.0 ){ eng.G_ENG.camera.zoomBy( 1.1 ); }
  if( utl.ray.getMouseWheelMove() < 0.0 ){ eng.G_ENG.camera.zoomBy( 0.9 ); }

  // Reset the camera zoom and position when r is pressed
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.r ))
  {
    eng.G_ENG.camera.setZoom(   1.0 );
    eng.G_ENG.camera.cam.pos = .{};
    utl.qlog( .INFO, @src(), "Camera reset" );
  }

  // Toggle the testbed overlay if the T key is pressed
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.t ))
  {
    SHOW_OVERLAY = !SHOW_OVERLAY;
    utl.log( .DEBUG, @src(), "Drifter overlay is now: {s}", .{ if( SHOW_OVERLAY ) "true" else "false" });
  }
}


pub fn OnTickUpdate( ng : *eng.Engine ) void // Called by engine.tryTick() ( every game frame, when not paused )
{
  // Advance deterministic world-feature demos here.
  _ = ng;
}

pub fn OffTickUpdate( ng : *eng.Engine ) void // Called by engine.tryTick() after OnTickUpdate
{
  _ = ng;
}



pub fn OnRenderBckgrnd( ng : *eng.Engine ) void // Called by engine.renderGraphics()
{
  _ = ng;
}


pub fn OnRenderWorld( ng : *eng.Engine ) void // Called by engine.renderGraphics()
{
  // Render direct world-space debug views here; engine-owned renderables follow.
  _ = ng;
}


pub fn OnRenderOverlay( ng : *eng.Engine ) void // Called by engine.renderGraphics()
{
  if( SHOW_OVERLAY )
  {
    utl.sDraw.textCenter( "DRIFTER", utl.getHalfScreenSize(), 96, utl.Colour.green );
  }

  if( ng.isPaused() )
  {
    utl.sDraw.coverScreenWithCol( utl.Colour.new( 0, 0, 0, 128 )); // grays out the screen
  }
}
