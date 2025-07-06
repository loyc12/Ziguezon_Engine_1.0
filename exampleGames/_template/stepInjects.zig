const std = @import( "std" );
const h   = @import( "defs" );


// ================================ GLOBAL GAME VARIABLES ================================

var DRAW_TEST : bool = true; // Example input-toggled flag


// ================================ STEP INJECTION FUNCTIONS ================================
// These functions are called by the engine at various points in the game loop ( see loopLogic() in engine.zig ).

pub fn OnLoopStart( ng : *h.eng.engine ) void // Called by engine.loopLogic()
{
  _ = ng; // Prevent unused variable warning
}

pub fn OnLoopIter( ng : *h.eng.engine ) void // Called by engine.loopLogic() ( every frame, no exception )
{
  _ = ng; // Prevent unused variable warning
}

pub fn OnLoopEnd( ng : *h.eng.engine ) void // Called by engine.loopLogic()
{
  _ = ng; // Prevent unused variable warning
}

// NOTE : This is where you should capture inputs to update global flags
pub fn OnUpdate( ng : *h.eng.engine ) void // Called by engine.update() ( every frame, no exception )
{
  // Toggle pause if the P key is pressed
  if( h.ray.isKeyPressed( h.ray.KeyboardKey.p )){ ng.togglePause(); }

  // Toggle the "DRAW_TEST" example flag if the T key is pressed
  if( h.ray.isKeyPressed( h.ray.KeyboardKey.t ))
  {
    DRAW_TEST = !DRAW_TEST;
    h.log( .DEBUG, 0, @src(), "DRAW_TEST is now: {s}", .{ if( DRAW_TEST ) "true" else "false" });
  }
}

// NOTE : This is where you should write gameplay logic ( AI, physics, etc. )
pub fn OnTick( ng : *h.eng.engine ) void // Called by engine.tick() ( every frame, when not paused )
{
  _ = ng; // Prevent unused variable warning
}

// NOTE : This is where you should render all world-position relative effects
pub fn OnRenderWorld( ng : *h.eng.engine ) void // Called by engine.render()
{
  // NOTE : All active entities are rendered after the function is called, so no need to render them here.

  _ = ng; // Prevent unused variable warning
}

// NOTE : This is where you should render all screen-position relative effects ( UI, HUD, etc. )
pub fn OnRenderOverlay( ng : *h.eng.engine ) void // Called by engine.render()
{
  if( DRAW_TEST ) // Example of a flag toggled feature
  {
    h.ray.drawText( "TEST", @divTrunc( h.ray.getScreenWidth(), 2 ), @divTrunc( h.ray.getScreenHeight(), 2 ), 64, h.ray.Color.green );
  }

  if( ng.state == .LAUNCHED ) // NOTE : Gray out the game when it is paused
  {
    h.ray.drawRectangle( 0, 0, h.ray.getScreenWidth(), h.ray.getScreenHeight(), h.ray.Color.init( 0, 0, 0, 128 ));
  }
}