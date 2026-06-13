const std  = @import( "std"  );
const eng  = @import( "engine" );
const utl  = @import( "utils" );

const gbl  = @import( "gameGlobals.zig" );
const gdf  = @import( "gameDef.zig"    );
const gUtl = @import( "gameUtils.zig"   );

const times  = &gbl.G_DATA.times;
const target = &gbl.G_DATA.target;
const views  = &gbl.G_DATA.views;


// ================================ STEP INJECTION FUNCTIONS ================================
// These functions are called by the engine at various points in the game loop ( see loopLogic() in engine.zig ).

pub fn OnLoopStart( ng : *eng.Engine ) void // Called by engine.loopLogic()
{
  _ = ng; // Prevent unused variable warning
}

pub fn OnLoopEnd( ng : *eng.Engine ) void // Called by engine.loopLogic()
{
  _ = ng; // Prevent unused variable warning
}

pub fn OnLoopUpdate( ng : *eng.Engine ) void // Called by engine.loopLogic() ( every frame, no exception )
{
  _ = ng; // Prevent unused variable warning
}


// NOTE : This is where you should capture inputs to update global flags
pub fn OnInputUpdate( ng : *eng.Engine ) void // Called by engine.updateInputs() ( every frame, no exception )
{
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.space )){ ng.togglePause(); }

  if( ng.isPaused() and utl.ray.isKeyPressed( utl.ray.KeyboardKey.o ))
  {
    utl.qlog( .INFO, @src(), "$ Forcing tick to occur" );
    ng.forceTickWorld();
  }

  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.j ) or utl.ray.isKeyPressed( utl.ray.KeyboardKey.kp_subtract )){ target.changeTargetBy( -1 ); }
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.k ) or utl.ray.isKeyPressed( utl.ray.KeyboardKey.kp_add      )){ target.changeTargetBy(  1 ); }
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.f ))
  {
    target.camFollow = !target.camFollow;
    if( target.camFollow )
    {
      const bodyView = views.getBodyTrans( ng ) orelse return;

      target.hasMoved = true;
      target.moveCamOver( bodyView );
    }
  }

  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.u ) or utl.ray.isKeyPressed( utl.ray.KeyboardKey.kp_divide   )){ times.changeSpeed( -1 ); }
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.i ) or utl.ray.isKeyPressed( utl.ray.KeyboardKey.kp_multiply )){ times.changeSpeed(  1 ); }

  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.left_shift ) or utl.ray.isKeyDown( utl.ray.KeyboardKey.right_shift ))
  {
    const bodyView = views.getBodyTrans( ng ) orelse return;
    const homeId = gbl.G_DATA.bodyRegistry.idOf( gdf.G_CONSTS.homeBody );
    const homeBody = bodyView.get( gdf.bdy.BodyComp, homeId ) orelse return;
    const mainEcon = homeBody.getEcon( .GROUND ) orelse return;

    if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.zero  )){ mainEcon.addPopCount( .WORKER,        100000 ); }
    if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.one   )){ mainEcon.addResCount( .fromIdx( 0 ), 100000 ); }
    if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.two   )){ mainEcon.addResCount( .fromIdx( 1 ), 100000 ); }
    if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.three )){ mainEcon.addResCount( .fromIdx( 2 ), 100000 ); }
    if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.four  )){ mainEcon.addResCount( .fromIdx( 3 ), 100000 ); }
    if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.five  )){ mainEcon.addResCount( .fromIdx( 4 ), 100000 ); }
    if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.six   )){ mainEcon.addResCount( .fromIdx( 5 ), 100000 ); }
    if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.seven )){ mainEcon.addResCount( .fromIdx( 6 ), 100000 ); }
  }

  gUtl.updateCameraLogic();
}


// NOTE : This is where you should write gameplay logic ( AI, physics, etc. )
pub fn OnTickUpdate( ng : *eng.Engine ) void // Called by engine.tryTick() ( every game frame, when not paused )
{
  const orbitView = views.getOrbitTick( ng ) orelse return;
  const bodyView  = views.getBodyTrans( ng ) orelse return;

  times.stepTime();

  gUtl.tickOrbiters( orbitView );

  const starId = gbl.G_DATA.bodyRegistry.idOf( gdf.G_CONSTS.starBody );
  const starPos : utl.Vec2 = bodyView.get( eng.TransComp, starId ).?.pos.toVec2();

  gUtl.tickGlobalEconomy( bodyView, starPos );
}



// NOTE : This is where you should render all background effects besides the background reset ( done via )
pub fn OnRenderBckgrnd( ng : *eng.Engine ) void // Called by engine.renderGraphics()
{
  _ = ng; // Prevent unused variable warning
}


// NOTE : This is where you should render all world-position relative effects
pub fn OnRenderWorld( ng : *eng.Engine ) void // Called by engine.renderGraphics()
{
  const view = views.getOrbitRender( ng ) orelse return;

  gUtl.renderOrbiters( view );
}

pub fn OffRenderWorld( ng : *eng.Engine ) void // Called by engine.renderGraphics()
{
  _ = ng; // Prevent unused variable warning
}


// NOTE : This is where you should render all screen-position relative effects ( UI, HUD, etc. )
pub fn OnRenderOverlay( ng : *eng.Engine ) void // Called by engine.renderGraphics()
{
  const edgeWidth : f64 = 10.0;
  if( ng.isPaused() )
  {
    // Draw lines around screen edge to show it is paused
    utl.sDraw.surroundScreenWithCol( utl.Colour.new( 255, 0, 0, 64 ), edgeWidth );

    utl.sDraw.textTop( "Press P to resume", .{ .x = utl.getHalfScreenWidth(), .y = edgeWidth + 10.0 }, 24, .yellow );
  }

  utl.sDraw.textOffsetFmt( "Speed : {s}", .{ @tagName( times.speedSetting )},
  .{ .x = utl.getScreenWidth() - 10.0, .y = utl.getScreenHeight() - 10.0 }, .new( 1.0, 1.0 ), 24, .yellow );


  const view = views.getOrbitRender( ng ) orelse return;

  gUtl.drawTargetInfo( view );
}
