const std = @import( "std"  );
const def = @import( "defs" );

const gbl = @import( "gameGlobals.zig" );
const gdf = @import( "gameDefs.zig"    );
const gtl = @import( "gameUtils.zig"   );


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

  if( def.ray.isKeyPressed( def.ray.KeyboardKey.kp_add      )){ gbl.GAME_DATA.targetId     =  gbl.GAME_DATA.targetId +| 1; }
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.kp_subtract )){ gbl.GAME_DATA.targetId     =  gbl.GAME_DATA.targetId -| 1; }
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.f           )){ gbl.GAME_DATA.followTarget = !gbl.GAME_DATA.followTarget;  }

  if( def.ray.isKeyPressed( def.ray.KeyboardKey.kp_multiply )){ gbl.GAME_DATA.times.changeSpeed(  1 ); }
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.kp_divide   )){ gbl.GAME_DATA.times.changeSpeed( -1 ); }

  if( def.ray.isKeyDown( def.ray.KeyboardKey.left_shift ))
  {
    const bodyStore : *gdf.BodyStore = @ptrCast( @alignCast( ng.componentRegistry.get( "bodyStore"  )));

    var mainEcon = bodyStore.get( gbl.GAME_DATA.homeworldId ).?.getEcon( .GROUND );

    if( def.ray.isKeyPressed( def.ray.KeyboardKey.zero  )){ mainEcon.addPopCount(                10000 ); }
    if( def.ray.isKeyPressed( def.ray.KeyboardKey.one   )){ mainEcon.addResCount( .fromIdx( 0 ), 10000 ); }
    if( def.ray.isKeyPressed( def.ray.KeyboardKey.two   )){ mainEcon.addResCount( .fromIdx( 1 ), 10000 ); }
    if( def.ray.isKeyPressed( def.ray.KeyboardKey.three )){ mainEcon.addResCount( .fromIdx( 2 ), 10000 ); }
    if( def.ray.isKeyPressed( def.ray.KeyboardKey.four  )){ mainEcon.addResCount( .fromIdx( 3 ), 10000 ); }
    if( def.ray.isKeyPressed( def.ray.KeyboardKey.five  )){ mainEcon.addResCount( .fromIdx( 4 ), 10000 ); }
    if( def.ray.isKeyPressed( def.ray.KeyboardKey.six   )){ mainEcon.addResCount( .fromIdx( 5 ), 10000 ); }
    if( def.ray.isKeyPressed( def.ray.KeyboardKey.seven )){ mainEcon.addResCount( .fromIdx( 6 ), 10000 ); }
  }

  gtl.updateCameraLogic();
}


// NOTE : This is where you should write gameplay logic ( AI, physics, etc. )
pub fn OnTickWorld( ng : *def.Engine ) void // Called by engine.tryTick() ( every game frame, when not paused )
{
  const transStore : *gdf.TransStore = @ptrCast( @alignCast( ng.componentRegistry.get( "transStore" )));
  const orbitStore : *gdf.OrbitStore = @ptrCast( @alignCast( ng.componentRegistry.get( "orbitStore" )));
  const bodyStore  : *gdf.BodyStore  = @ptrCast( @alignCast( ng.componentRegistry.get( "bodyStore"  )));

  gbl.GAME_DATA.times.stepTime();

  gtl.tickOrbiters( transStore, orbitStore );

  const starPos : def.Vec2 = transStore.get( gbl.GAME_DATA.starId ).?.pos.toVec2();

  gtl.tickGlobalEconomy( transStore, bodyStore, starPos );
}



// NOTE : This is where you should render all background effects besides the background reset ( done via )
pub fn OnRenderBckgrnd( ng : *def.Engine ) void // Called by engine.renderGraphics()
{
  _ = ng; // Prevent unused variable warning
}


// NOTE : This is where you should render all world-position relative effects
pub fn OnRenderWorld( ng : *def.Engine ) void // Called by engine.renderGraphics()
{
  const transStore : *gdf.TransStore = @ptrCast( @alignCast( ng.componentRegistry.get( "transStore" )));
  const shapeStore : *gdf.ShapeStore = @ptrCast( @alignCast( ng.componentRegistry.get( "shapeStore" )));

  const orbitStore : *gdf.OrbitStore = @ptrCast( @alignCast( ng.componentRegistry.get( "orbitStore" )));
  const bodyStore  : *gdf.BodyStore  = @ptrCast( @alignCast( ng.componentRegistry.get( "bodyStore"  )));


  gtl.renderOrbiters( transStore, shapeStore, orbitStore, bodyStore );
}

pub fn OffRenderWorld( ng : *def.Engine ) void // Called by engine.renderGraphics()
{
  _ = ng; // Prevent unused variable warning
}


// NOTE : This is where you should render all screen-position relative effects ( UI, HUD, etc. )
pub fn OnRenderOverlay( ng : *def.Engine ) void // Called by engine.renderGraphics()
{
  const edgeWidth : f64 = 10.0;
  if( ng.isPaused() )
  {
    // Draw lines around screen edge to show it is paused
    def.surroundScreenWithCol( def.Colour.new( 255, 0, 0, 64 ), edgeWidth );

    def.drawTextTop( "Press P to resume", .{ .x = def.getHalfScreenWidth(), .y = edgeWidth + 10.0 }, 24, .yellow );
  }

  def.drawTextOffsetFmt( "Speed : {s}", .{ @tagName( gbl.GAME_DATA.times.speedSetting )}, .{ .x = def.getScreenWidth() - 10.0, .y = def.getScreenHeight() - 10.0 }, .new( 1.0, 1.0 ), 24, .yellow );


  const transStore : *gdf.TransStore = @ptrCast( @alignCast( ng.componentRegistry.get( "transStore" )));
  const shapeStore : *gdf.ShapeStore = @ptrCast( @alignCast( ng.componentRegistry.get( "shapeStore" )));

  const orbitStore : *gdf.OrbitStore = @ptrCast( @alignCast( ng.componentRegistry.get( "orbitStore" )));
  const bodyStore  : *gdf.BodyStore  = @ptrCast( @alignCast( ng.componentRegistry.get( "bodyStore"  )));

  gtl.drawTargetInfo( transStore, shapeStore, orbitStore, bodyStore );
}