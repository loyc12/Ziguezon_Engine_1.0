const std = @import( "std" );
const def = @import( "defs" );

const gbl = @import( "gameGlobals.zig" );
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
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.p )){ ng.togglePause(); }

  if( ng.isPaused() and def.ray.isKeyPressed( def.ray.KeyboardKey.o ))
  {
    ng.forceTick();
  }

  if( def.ray.isKeyPressed( def.ray.KeyboardKey.kp_add      )){ gbl.targetId     =  gbl.targetId +| 1; }
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.kp_subtract )){ gbl.targetId     =  gbl.targetId -| 1; }
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.f           )){ gbl.followTarget = !gbl.followTarget;  }

  if( def.ray.isKeyDown( def.ray.KeyboardKey.left_shift ))
  {
    const bodyStore : *gbl.BodyStore = @ptrCast( @alignCast( ng.componentRegistry.get( "bodyStore"  )));

    var mainEcon = bodyStore.get( gbl.homeworldId ).?.getEcon( .GROUND );

    if( def.ray.isKeyPressed( def.ray.KeyboardKey.zero  )){ mainEcon.addPopCount(                10000 ); }
    if( def.ray.isKeyPressed( def.ray.KeyboardKey.one   )){ mainEcon.addResCount( .fromIdx( 0 ), 10000 ); }
    if( def.ray.isKeyPressed( def.ray.KeyboardKey.two   )){ mainEcon.addResCount( .fromIdx( 1 ), 10000 ); }
    if( def.ray.isKeyPressed( def.ray.KeyboardKey.three )){ mainEcon.addResCount( .fromIdx( 2 ), 10000 ); }
    if( def.ray.isKeyPressed( def.ray.KeyboardKey.four  )){ mainEcon.addResCount( .fromIdx( 3 ), 10000 ); }
    if( def.ray.isKeyPressed( def.ray.KeyboardKey.five  )){ mainEcon.addResCount( .fromIdx( 4 ), 10000 ); }
    if( def.ray.isKeyPressed( def.ray.KeyboardKey.six   )){ mainEcon.addResCount( .fromIdx( 5 ), 10000 ); }
    if( def.ray.isKeyPressed( def.ray.KeyboardKey.seven )){ mainEcon.addResCount( .fromIdx( 6 ), 10000 ); }
  }

  utl.updateCameraLogic();
}


// NOTE : This is where you should write gameplay logic ( AI, physics, etc. )
pub fn OnTickWorld( ng : *def.Engine ) void // Called by engine.tryTick() ( every game frame, when not paused )
{
  const transStore : *gbl.TransStore = @ptrCast( @alignCast( ng.componentRegistry.get( "transStore" )));
  const orbitStore : *gbl.OrbitStore = @ptrCast( @alignCast( ng.componentRegistry.get( "orbitStore" )));
  const bodyStore  : *gbl.BodyStore  = @ptrCast( @alignCast( ng.componentRegistry.get( "bodyStore"  )));

  utl.tickOrbiters( transStore, orbitStore, 1.0 ); // Each update will represent exactly one wekk of in-game time


  const starPos : def.Vec2 = transStore.get( gbl.starId ).?.pos.toVec2();

  utl.tickGlobalEconomy( transStore, bodyStore, starPos );
}



// NOTE : This is where you should render all background effects besides the background reset ( done via )
pub fn OnRenderBckgrnd( ng : *def.Engine ) void // Called by engine.renderGraphics()
{
  _ = ng; // Prevent unused variable warning
}


// NOTE : This is where you should render all world-position relative effects
pub fn OnRenderWorld( ng : *def.Engine ) void // Called by engine.renderGraphics()
{
  const transStore : *gbl.TransStore = @ptrCast( @alignCast( ng.componentRegistry.get( "transStore" )));
  const shapeStore : *gbl.ShapeStore = @ptrCast( @alignCast( ng.componentRegistry.get( "shapeStore" )));

  const orbitStore : *gbl.OrbitStore = @ptrCast( @alignCast( ng.componentRegistry.get( "orbitStore" )));
  const bodyStore  : *gbl.BodyStore  = @ptrCast( @alignCast( ng.componentRegistry.get( "bodyStore"  )));


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
    const edgeWidth : f64 = 10.0;
    // Draw lines around screen edge to show it is paused
    def.surroundScreenWithCol( def.Colour.new( 255, 0, 0, 64 ), edgeWidth );

    def.drawTextTop( "Press P to resume", .{ .x = def.getHalfScreenWidth(), .y = edgeWidth + 10.0 }, 24, .yellow );
  }

  const transStore : *gbl.TransStore = @ptrCast( @alignCast( ng.componentRegistry.get( "transStore" )));
  const shapeStore : *gbl.ShapeStore = @ptrCast( @alignCast( ng.componentRegistry.get( "shapeStore" )));

  const orbitStore : *gbl.OrbitStore = @ptrCast( @alignCast( ng.componentRegistry.get( "orbitStore" )));
  const bodyStore  : *gbl.BodyStore  = @ptrCast( @alignCast( ng.componentRegistry.get( "bodyStore"  )));

  utl.drawTargetInfo( transStore, shapeStore, orbitStore, bodyStore );
}