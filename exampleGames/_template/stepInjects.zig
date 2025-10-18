const std      = @import( "std" );
const def      = @import( "defs" );
const stateInj = @import( "stateInjects.zig" );

const Engine = def.Engine;
const Entity = def.Entity;
const Angle  = def.Angle;
const Vec2   = def.Vec2;
const VecA   = def.VecA;

// ================================ GLOBAL GAME VARIABLES ================================

var DRAW_TEST : bool = true; // Example input-toggled flag


// ================================ STEP INJECTION FUNCTIONS ================================
// These functions are called by the engine at various points in the game loop ( see loopLogic() in engine.zig ).

pub fn OnLoopStart( ng : *def.Engine ) void // Called by engine.loopLogic()
{
  _ = ng; // Prevent unused variable warning
}

pub fn OnLoopEnd( ng : *def.Engine ) void // Called by engine.loopLogic()
{
  _ = ng; // Prevent unused variable warning
}

pub fn OnLoopCycle( ng : *def.Engine ) void // Called by engine.loopLogic() ( every frame, no exception )
{
  _ = ng; // Prevent unused variable warning
}


// NOTE : This is where you should capture inputs to update global flags
pub fn OnUpdateInputs( ng : *def.Engine ) void // Called by engine.updateInputs() ( every frame, no exception )
{
  // Toggle pause if the P key is pressed
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.enter ) or def.ray.isKeyPressed( def.ray.KeyboardKey.p )){ ng.togglePause(); }

  // Move the camera with the WASD or arrow keys
  if( def.ray.isKeyDown( def.ray.KeyboardKey.w ) or def.ray.isKeyDown( def.ray.KeyboardKey.up    )){ ng.moveCameraByS( Vec2.new(  0, -8 )); }
  if( def.ray.isKeyDown( def.ray.KeyboardKey.s ) or def.ray.isKeyDown( def.ray.KeyboardKey.down  )){ ng.moveCameraByS( Vec2.new(  0,  8 )); }
  if( def.ray.isKeyDown( def.ray.KeyboardKey.a ) or def.ray.isKeyDown( def.ray.KeyboardKey.left  )){ ng.moveCameraByS( Vec2.new( -8,  0 )); }
  if( def.ray.isKeyDown( def.ray.KeyboardKey.d ) or def.ray.isKeyDown( def.ray.KeyboardKey.right )){ ng.moveCameraByS( Vec2.new(  8,  0 )); }

  // Zoom in and out with the mouse wheel
  if( def.ray.getMouseWheelMove() > 0.0 ){ ng.zoomCameraBy( 11.0 / 10.0 ); }
  if( def.ray.getMouseWheelMove() < 0.0 ){ ng.zoomCameraBy(  9.0 / 10.0 ); }

  // Reset the camera zoom and position when r is pressed
  if( def.ray.isKeyDown( def.ray.KeyboardKey.r ))
  {
    ng.setCameraZoom(   1.0 );
    ng.setCameraCenter( .{} );
    ng.setCameraRot(    .{} );
    def.qlog( .INFO, 0, @src(), "Camera reset" );
  }

  // Toggle the "DRAW_TEST" example flag if the T key is pressed
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.t ))
  {
    DRAW_TEST = !DRAW_TEST;
    ng.playAudio( "hit_1" );
    def.log( .DEBUG, 0, @src(), "DRAW_TEST is now: {s}", .{ if( DRAW_TEST ) "true" else "false" });
  }
}

// NOTE : This is where you should write gameplay logic ( AI, physics, etc. )
pub fn OnTickEntities( ng : *def.Engine ) void // Called by engine.tickEntities() ( every frame, when not paused )
{
  _ = ng; // Prevent unused variable warning
}

pub fn OffTickEntities( ng : *def.Engine ) void // Called by engine.tickEntities() ( every frame, when not paused )
{
  _ = ng; // Prevent unused variable warning
}


// NOTE : This is where you should render all background effects besides the background reset ( done via )
pub fn OnRenderBackground( ng : *def.Engine ) void // Called by engine.renderGraphics()
{
  _ = ng; // Prevent unused variable warning
}

// NOTE : This is where you should render all world-position relative effects
pub fn OnRenderWorld( ng : *def.Engine ) void // Called by engine.renderGraphics()
{
  // NOTE : All active entities are rendered after the function is called, so no need to render them here.

  _ = ng; // Prevent unused variable warning
}

pub fn OffRenderWorld( ng : *def.Engine ) void // Called by engine.renderGraphics()
{
  _ = ng; // Prevent unused variable warning
}

// NOTE : This is where you should render all screen-position relative effects ( UI, HUD, etc. )
pub fn OnRenderOverlay( ng : *def.Engine ) void // Called by engine.renderGraphics()
{
  if( DRAW_TEST ) // Example of a flag toggled feature
  {
    def.drawCenteredText( "TEST", def.getHalfScreenWidth(), def.getHalfScreenHeight(), 256, def.Colour.red );
  }

  if( ng.isPaused() )
  {
    def.coverScreenWith( def.Colour.init( 0, 0, 0, 128 )); // grays out the screen
  }
}