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
  utl.updateCameraLogic( ng );
}


// NOTE : This is where you should write gameplay logic ( AI, physics, etc. )
pub fn OnTickWorld( ng : *def.Engine ) void // Called by engine.tryTick() ( every game frame, when not paused )
{
  const transStore : *glb.TransStore = @ptrCast( @alignCast( ng.componentRegistry.get( "transStore" )));
  const orbitStore : *glb.OrbitStore = @ptrCast( @alignCast( ng.componentRegistry.get( "orbitStore" )));
//const bodyStore  : *glb.BodyStore  = @ptrCast( @alignCast( ng.componentRegistry.get( "bodyStore"  )));

  const sdt = ng.getScaledTargetTickDelta();

  for( 1..glb.entityArray.len )| idx |
  {
    const id = glb.entityArray[ idx ].id;

    def.log( .TRACE, 0, @src(), "Updating orbit of entity #{}", .{ id });

    const orbiter = orbitStore.get( id );

    if( orbiter == null ){ continue; }

    const orbiterTrans = transStore.get( id );
    const orbitedTrans = transStore.get( glb.entityArray[ idx - 1 ].id );

    if( orbiterTrans != null and orbitedTrans != null )
    {
      orbiter.?.updateOrbit( orbiterTrans.?, orbitedTrans.?, sdt );
    }
    else
    {
      def.log( .WARN, 0, @src(), "Failed to get all required components to tick orbit of entity #{}", .{ id });
    }

    // NOTE : No need to update transComps for orbiters
  }
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


  // Rendering bodies' orbits and debug info
  for( 1..glb.entityArray.len )| idx |
  {
    const id = glb.entityArray[ idx ].id;

    def.log( .TRACE, 0, @src(), "Rendering path & dbg info of entity #{} at idx #{}", .{ id, idx });

    const orbiter      = orbitStore.get( id );
    const orbiterBody  = bodyStore.get(  id );

    const orbiterTrans = transStore.get( id );
    const orbitedTrans = transStore.get( glb.entityArray[ idx - 1 ].id );

    if( orbiter != null and orbitedTrans != null and orbiterBody != null )
    {
      orbiter.?.renderDebug( orbiterTrans.?.pos.toVec2(), orbiterBody.?.radius, 1.0 );

      orbiter.?.renderPath( orbitedTrans.?.pos.toVec2() );

      orbiter.?.renderLPs( orbitedTrans.?.pos.toVec2(), orbiterBody.?.bodyType.getLPCount() );
    }
    else
    {
      def.log( .WARN, 0, @src(), "Failed to get all required components to render orbital path of entity #{}", .{ id });
    }
  }

  // Rendering bodies
  for( 0..glb.entityArray.len )| idx |
  {
    const id = glb.entityArray[ idx ].id;

    def.log( .TRACE, 0, @src(), "Rendering shape of entity #{}", .{ id });

    const orbiterTrans = transStore.get( id );
    const orbiterShape = shapeStore.get( id );

    if( orbiterTrans != null and orbiterShape != null )
    {
      orbiterShape.?.render( orbiterTrans.?.pos );
    }
    else
    {
      def.log( .WARN, 0, @src(), "Failed to get all required components to render shape of entity #{}", .{ id });
    }
  }
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
    def.coverScreenWithCol( def.Colour.new( 0, 0, 0, 128 )); // grays out the screen
  }
}