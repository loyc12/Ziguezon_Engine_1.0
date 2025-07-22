const std = @import( "std" );
const def = @import( "defs" );


// ================================ GLOBAL GAME VARIABLES ================================

var DRAW_TEST : bool = true; // Example input-toggled flag


// ================================ STEP INJECTION FUNCTIONS ================================
// These functions are called by the engine at various points in the game loop ( see loopLogic() in engine.zig ).

pub fn OnLoopStart( ng : *def.eng.engine ) void // Called by engine.loopLogic()
{
  _ = ng; // Prevent unused variable warning
}

pub fn OnLoopEnd( ng : *def.eng.engine ) void // Called by engine.loopLogic()
{
  _ = ng; // Prevent unused variable warning
}

pub fn OnLoopIter( ng : *def.eng.engine ) void // Called by engine.loopLogic() ( every frame, no exception )
{
  _ = ng; // Prevent unused variable warning
}

pub fn OffLoopIter( ng : *def.eng.engine ) void // Called by engine.loopLogic() ( every frame, no exception )
{
  _ = ng; // Prevent unused variable warning
}



// NOTE : This is where you should capture inputs to update global flags
pub fn OnUpdateStep( ng : *def.eng.engine ) void // Called by engine.update() ( every frame, no exception )
{
  // Toggle pause if the P key is pressed
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.p )){ ng.togglePause(); }

  // Toggle the "DRAW_TEST" example flag if the T key is pressed
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.t ))
  {
    DRAW_TEST = !DRAW_TEST;
    def.log( .DEBUG, 0, @src(), "DRAW_TEST is now: {s}", .{ if( DRAW_TEST ) "true" else "false" });
  }
}

pub fn OffUpdateStep( ng : *def.eng.engine ) void // Called by engine.update() ( every frame, no exception )
{
  _ = ng; // Prevent unused variable warning
}

// NOTE : This is where you should write gameplay logic ( AI, physics, etc. )
pub fn OnTickStep( ng : *def.eng.engine ) void // Called by engine.tick() ( every frame, when not paused )
{
  _ = ng; // Prevent unused variable warning
}

pub fn OffTickStep( ng : *def.eng.engine ) void // Called by engine.tick() ( every frame, when not paused )
{
  _ = ng; // Prevent unused variable warning
}



// NOTE : This is where you should render all world-position relative effects
pub fn OnRenderWorld( ng : *def.eng.engine ) void // Called by engine.render()
{
  // NOTE : All active entities are rendered after the function is called, so no need to render them here.

  _ = ng; // Prevent unused variable warning
}

pub fn OffRenderWorld( ng : *def.eng.engine ) void // Called by engine.render()
{
  _ = ng; // Prevent unused variable warning
}

// NOTE : This is where you should render all screen-position relative effects ( UI, HUD, etc. )
pub fn OnRenderOverlay( ng : *def.eng.engine ) void // Called by engine.render()
{
  if( DRAW_TEST ) // Example of a flag toggled feature
  {
    def.ray.drawText( "TEST", @divTrunc( def.ray.getScreenWidth(), 2 ), @divTrunc( def.ray.getScreenHeight(), 2 ), 64, def.ray.Color.green );
  }

  if( ng.state == .LAUNCHED ) // NOTE : Gray out the game when it is paused
  {
    def.ray.drawRectangle( 0, 0, def.ray.getScreenWidth(), def.ray.getScreenHeight(), def.ray.Color.init( 0, 0, 0, 128 ));
  }
}

pub fn OffRenderOverlay( ng : *def.eng.engine ) void // Called by engine.render()
{
  _ = ng; // Prevent unused variable warning
}