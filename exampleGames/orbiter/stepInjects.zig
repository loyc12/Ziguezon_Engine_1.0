const std = @import( "std" );
const def = @import( "defs" );

const glb = @import( "gameGlobals.zig" );
const utl = @import( "gameUtils.zig" );


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
  if( ng.isPaused() and def.ray.isKeyPressed( def.ray.KeyboardKey.o )){ ng.forceTick(); }

  if( def.ray.isKeyPressed( def.ray.KeyboardKey.kp_add      )){ glb.targetId = glb.targetId +| 1; }
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.kp_subtract )){ glb.targetId = glb.targetId -| 1; }



  utl.updateCameraLogic( &ng.camera );
}


// NOTE : This is where you should write gameplay logic ( AI, physics, etc. )
pub fn OnTickWorld( ng : *def.Engine ) void // Called by engine.tryTick() ( every game frame, when not paused )
{
  const sdt = ng.times.getScaledTargetTickDeltaFloat();

  const transStore : *glb.TransStore = @ptrCast( @alignCast( ng.componentRegistry.get( "transStore" )));
  const orbitStore : *glb.OrbitStore = @ptrCast( @alignCast( ng.componentRegistry.get( "orbitStore" )));
  const bodyStore  : *glb.BodyStore  = @ptrCast( @alignCast( ng.componentRegistry.get( "bodyStore"  )));


  utl.tickOrbiters( transStore, orbitStore, sdt );


  const starPos : def.Vec2 = transStore.get( 1 ).?.pos.toVec2();

  utl.tickGlobalEconomy( transStore, orbitStore, bodyStore, starPos );
}



// NOTE : This is where you should render all background effects besides the background reset ( done via )
pub fn OnRenderBckgrnd( ng : *def.Engine ) void // Called by engine.renderGraphics()
{
  _ = ng; // Prevent unused variable warning
}


// NOTE : This is where you should render all world-position relative effects
pub fn OnRenderWorld( ng : *def.Engine ) void // Called by engine.renderGraphics()
{
  const transStore : *glb.TransStore = @ptrCast( @alignCast( ng.componentRegistry.get( "transStore" )));
  const shapeStore : *glb.ShapeStore = @ptrCast( @alignCast( ng.componentRegistry.get( "shapeStore" )));

  const orbitStore : *glb.OrbitStore = @ptrCast( @alignCast( ng.componentRegistry.get( "orbitStore" )));
  const bodyStore  : *glb.BodyStore  = @ptrCast( @alignCast( ng.componentRegistry.get( "bodyStore"  )));


  utl.renderOrbiters( transStore, shapeStore, orbitStore, bodyStore );
}

pub fn OffRenderWorld( ng : *def.Engine ) void // Called by engine.renderGraphics()
{
  _ = ng; // Prevent unused variable warning
}


// NOTE : This is where you should render all screen-position relative effects ( UI, HUD, etc. )
pub fn OnRenderOverlay( ng : *def.Engine ) void // Called by engine.renderGraphics()
{
  if( ng.isPaused() )
  {
    def.coverScreenWithCol( def.Colour.new( 0, 0, 0, 64 )); // grays out the screen
  }

  const transStore : *glb.TransStore = @ptrCast( @alignCast( ng.componentRegistry.get( "transStore" )));
  const shapeStore : *glb.ShapeStore = @ptrCast( @alignCast( ng.componentRegistry.get( "shapeStore" )));

  const orbitStore : *glb.OrbitStore = @ptrCast( @alignCast( ng.componentRegistry.get( "orbitStore" )));
  const bodyStore  : *glb.BodyStore  = @ptrCast( @alignCast( ng.componentRegistry.get( "bodyStore"  )));

  utl.drawTargetInfo( transStore, shapeStore, orbitStore, bodyStore );
}