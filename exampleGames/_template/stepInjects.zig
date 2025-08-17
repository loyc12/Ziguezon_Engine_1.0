const std      = @import( "std" );
const def      = @import( "defs" );
const stateInj = @import( "stateInjects.zig" );

const Engine = def.Engine;
const Entity = def.Entity;
const Vec2   = def.Vec2;
const VecR   = def.VecR;

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
  var exampleEntity = ng.getEntity( stateInj.EXAMPLE_NTT_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Entity with ID {d} ( Example Entity ) not found", .{ stateInj.EXAMPLE_NTT_ID });
    return;
  };

  exampleEntity.pos.r += 0.01 * ( @cos( exampleEntity.pos.r ) + 1.5 ); // Example of a simple variable rotation effect
  exampleEntity.pos.y  = 256  * ( @sin( exampleEntity.pos.r ) );       // Example of a simple variable vertical movement effect

  var exampleTilemap = ng.getTilemap( stateInj.EXAMPLE_TLM_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Tilemap with ID {d} ( Example Tilemap ) not found", .{ stateInj.EXAMPLE_TLM_ID });
    return;
  };

  exampleTilemap.gridPos.r += 0.01;
}

pub fn OffTickEntities( ng : *def.Engine ) void // Called by engine.tickEntities() ( every frame, when not paused )
{
  _ = ng; // Prevent unused variable warning
}


// NOTE : This is where you should render all background effects ( sky, etc. )
pub fn OnRenderBackground( ng : *def.Engine ) void // Called by engine.renderGraphics()
{
  _ = ng; // Prevent unused variable warning

  def.ray.clearBackground( def.Colour.black ); // Clear the screen with a black color
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
    def.drawCenteredText( "TEST", def.getHalfScreenWidth(), def.getHalfScreenHeight(), 64, def.Colour.green );
  }

  if( ng.state == .OPENED ) // NOTE : Gray out the game when it is paused
  {
    def.coverScreenWith( def.Colour.init( 0, 0, 0, 128 ));
  }
}