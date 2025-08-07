const std = @import( "std" );
const def = @import( "defs" );


// ================================ GLOBAL GAME VARIABLES ================================

var DRAW_TEST : bool = true; // Example input-toggled flag


// ================================ STEP INJECTION FUNCTIONS ================================
// These functions are called by the engine at various points in the game loop ( see loopLogic() in engine.zig ).

pub fn OnLoopStart( ng : *def.ngn.engine ) void // Called by engine.loopLogic()
{
  _ = ng; // Prevent unused variable warning
}

pub fn OnLoopEnd( ng : *def.ngn.engine ) void // Called by engine.loopLogic()
{
  _ = ng; // Prevent unused variable warning
}

pub fn OnLoopCycle( ng : *def.ngn.engine ) void // Called by engine.loopLogic() ( every frame, no exception )
{
  _ = ng; // Prevent unused variable warning
}


// NOTE : This is where you should capture inputs to update global flags
pub fn OnUpdateInputs( ng : *def.ngn.engine ) void // Called by engine.updateInputs() ( every frame, no exception )
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

// NOTE : This is where you should write gameplay logic ( AI, physics, etc. )
pub fn OnTickEntities( ng : *def.ngn.engine ) void // Called by engine.tickEntities() ( every frame, when not paused )
{
  _ = ng; // Prevent unused variable warning
}

pub fn OffTickEntities( ng : *def.ngn.engine ) void // Called by engine.tickEntities() ( every frame, when not paused )
{
  _ = ng; // Prevent unused variable warning
}


// NOTE : This is where you should render all background effects ( sky, etc. )
pub fn OnRenderBackground( ng : *def.ngn.engine ) void // Called by engine.renderGraphics()
{
  _ = ng; // Prevent unused variable warning

  def.ray.clearBackground( def.ray.Color.black ); // Clear the screen with a black color
}

// NOTE : This is where you should render all world-position relative effects
pub fn OnRenderWorld( ng : *def.ngn.engine ) void // Called by engine.renderGraphics()
{
  // NOTE : All active entities are rendered after the function is called, so no need to render them here.

  _ = ng; // Prevent unused variable warning
}

pub fn OffRenderWorld( ng : *def.ngn.engine ) void // Called by engine.renderGraphics()
{
  _ = ng; // Prevent unused variable warning
}

// NOTE : This is where you should render all screen-position relative effects ( UI, HUD, etc. )
pub fn OnRenderOverlay( ng : *def.ngn.engine ) void // Called by engine.renderGraphics()
{
  if( DRAW_TEST ) // Example of a flag toggled feature
  {
    def.ray.drawText( "TEST", def.rdm.getHalfScreenWidth(), def.rdm.getHalfScreenHeight(), 64, def.ray.Color.green );
  }

  if( ng.state == .OPENED ) // NOTE : Gray out the game when it is paused
  {
    def.coverScreenWith( def.ray.Color.init( 0, 0, 0, 128 ));
  }
}