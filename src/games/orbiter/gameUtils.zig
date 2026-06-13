const eng = @import( "engine" );
const utl = @import( "utils" );

const gbl = @import( "gameGlobals.zig" );
const gdf = @import( "gameDef.zig"    );

const times  = &gbl.G_DATA.times;
const target = &gbl.G_DATA.target;

const BodyName = gdf.BodyName;

const orb = gdf.orb;
const bdy = gdf.bdy;


// ================================ STATE INJECT ================================

inline fn initStar( bodyComp : *bdy.BodyComp, bodyName : BodyName ) void
{
  bodyComp.bodyType = .fromFlt( gbl.STLR_DATA.get( bodyName, .TYPE ));
  bodyComp.name     = bodyName;
  bodyComp.mass     = gbl.STLR_DATA.get( bodyName, .MASS );
  bodyComp.radius   = gbl.STLR_DATA.get( bodyName, .RADIUS );

  bodyComp.softInitAllEcons();
}

fn initStellarBody( view : *gdf.BodyTransView, orbitComp : *orb.OrbitComp, bodyComp : *bdy.BodyComp, bodyName : BodyName, orbitedId : eng.EntityId ) void
{
  const orbiterMass = gbl.STLR_DATA.get( bodyName, .MASS );
  var   orbitedMass = gbl.STLR_DATA.get( gdf.G_CONSTS.starBody, .MASS );

  if( view.get( bdy.BodyComp, orbitedId ))| b |
  {
    orbitedMass = b.mass;
  }
  else
  {
    utl.log( .WARN, @src(), "Failed to find parent BodyComp for id {d} : defaulting to using star's mass", .{ orbitedId });
  }

  bodyComp.bodyType = .fromFlt( gbl.STLR_DATA.get( bodyName, .TYPE ));
  bodyComp.name     = bodyName;
  bodyComp.mass     = orbiterMass;
  bodyComp.radius   = gbl.STLR_DATA.get( bodyName, .RADIUS );

  orbitComp.* = .initFromParams(
    orbitedMass,       orbiterMass,
    gbl.STLR_DATA.get( bodyName, .PERIAP ),
    gbl.STLR_DATA.get( bodyName, .APOAP  ),
    gbl.STLR_DATA.get( bodyName, .LONG   ),
    null,
    bodyComp.bodyType.getDisplayColour(),
  );

  bodyComp.softInitAllEcons();


  const dist     = gbl.STLR_DATA.get( bodyName, .PERIAP );
  const sunshine = gbl.SUNSHINE.getShineAt( dist * dist );


  if( bodyName == .TERRA )
  {
    bodyComp.quickInitEcon( .GROUND, true );
    bodyComp.debugSetEconState( .GROUND, 10_000, sunshine ); // Setup a 1B pop econ
  }
  if( gdf.G_FLAGS.STRESS_TEST )
  {
    inline for( 0..gdf.EconLoc.count )| l |
    {
      const loc = gdf.EconLoc.fromIdx( l );

      if( loc == .GROUND or loc == .ORBIT )
      {
        if( bodyName != .TERRA or loc != .GROUND )
        {
          bodyComp.quickInitEcon( loc, true );
          bodyComp.debugSetEconState( loc, 1, sunshine ); // Setup a 100K pop econ
        }
      }
    }
  }
}

fn abortStellarBodySetup( ng : *eng.Engine, bodyName : BodyName, bodyId : eng.EntityId ) void
{
  if( ng.world.isEntityAlive( bodyId )){ _ = ng.world.destroyEntity( bodyId ); }
  gbl.G_DATA.bodyRegistry.clearId( bodyName );
}

fn addOrbitRelationAndRefreshCache( ng : *eng.Engine, bodyName : BodyName, bodyId : eng.EntityId ) bool
{
  const parentName = gdf.getOrbitedName( bodyName ) orelse
  {
    utl.log( .ERROR, @src(), "Missing static orbit parent for {s}", .{ @tagName( bodyName )});
    return false;
  };
  const parentId = gbl.G_DATA.bodyRegistry.idOf( parentName );
  if( parentId == 0 )
  {
    utl.log( .ERROR, @src(), "Cannot add orbit relation for {s} : parent {s} has no live entity", .{ @tagName( bodyName ), @tagName( parentName )});
    return false;
  }

  if( !ng.world.addRelation( gdf.Orbits, bodyId, parentId, .{} ))
  {
    utl.log( .ERROR, @src(), "Failed to add Orbits relation {s} -> {s}", .{ @tagName( bodyName ), @tagName( parentName )});
    return false;
  }

  return gbl.refreshOrbitParentCacheEntry( ng, bodyName );
}

pub fn initStellarSystem( ng : *eng.Engine ) void
{
  const bodyView = gbl.G_DATA.views.getBodyTrans( ng ) orelse return;

  gbl.G_DATA.bodyRegistry.clear();
  gbl.G_DATA.economies.clear();
  gbl.clearOrbitParentCache();

  // Setting up relevant components
  for( gdf.bodyOrder, 0.. )| bodyName, idx |
  {
    const id = ng.world.createEntity().id;
    if( id == 0 )
    {
      utl.log( .ERROR, @src(), "Failed to create entity for {s}", .{ @tagName( bodyName )});
      continue;
    }

    gbl.G_DATA.bodyRegistry.setId( bodyName, id );

    utl.log( .TRACE, @src(), "Initializing components of body {s} on entity #{d} at body idx #{d}", .{ @tagName( bodyName ), id, idx });


    // Non-sun component instanciation

    var orbitComp : orb.OrbitComp = undefined;
    var bodyComp  : bdy.BodyComp  = .{};


    var startPos : utl.Vec2 = .{};

    if( bodyName == gdf.G_CONSTS.starBody )
    {
      if( !gbl.refreshOrbitParentCacheEntry( ng, bodyName ))
      {
        abortStellarBodySetup( ng, bodyName, id );
        continue;
      }

      initStar( &bodyComp, bodyName ); // Setting sol's bodyComp variables
    }
    else
    {
      if( !addOrbitRelationAndRefreshCache( ng, bodyName, id ))
      {
        abortStellarBodySetup( ng, bodyName, id );
        continue;
      }

      const orbitedId = gbl.getOrbitedIdCached( bodyName );

      initStellarBody( bodyView, &orbitComp, &bodyComp, bodyName, orbitedId ); // Setting bodyType-specific orbitComp and bodyComp variables

      startPos = orbitComp.getRelPos();

      if( bodyView.get( eng.TransComp, orbitedId ))| trans |
      {
        startPos = startPos.add( trans.pos.toVec2() );
      }
      else
      {
        utl.log( .ERROR, @src(), "Failed to find parent TransComp for id {d} : using relative start position", .{ orbitedId });
      }

      _ = ng.world.addComp( orb.OrbitComp, id, orbitComp ); // SOL does not have an orbit comp
    }

    _ = ng.world.addComp( eng.TransComp, id, .{ .pos = startPos.toVecA( .{} )});
    _ = ng.world.addComp( bdy.BodyComp,  id, bodyComp  );
    _ = ng.world.addComp( eng.ShapeComp, id,
    .{
      .colour  = bodyComp.bodyType.getDisplayColour(),
      .minSize = bodyComp.bodyType.getMinDisplaySize(),
      .scale   = .new( bodyComp.radius, bodyComp.radius ),
      .shape   = .ELLI
    });

  }

  if( !gbl.rebuildOrbitParentCache( ng ))
  {
    utl.qlog( .ERROR, @src(), "Failed to rebuild orbit-parent cache after stellar setup" );
  }

  const orbitView = gbl.G_DATA.views.getOrbitTick( ng ) orelse return;
  gdf.trvlSlvr.refreshAllTransferNodes( orbitView );
}



// ================================ STEP INJECT ================================

pub fn updateCameraLogic() void
{
  var cam = &eng.G_ENG.camera;

  const scrollSpeed = gdf.G_CONSTS.scrollSpeed;
  const zoomSpeed   = gdf.G_CONSTS.zoomSpeed;

  if( !target.camFollow )
  {
    // Moves the camera with the WASD or arrow keys
    if( utl.ray.isKeyDown( utl.ray.KeyboardKey.w ) or utl.ray.isKeyDown( utl.ray.KeyboardKey.up    )){ cam.moveByS( utl.Vec2.new(  0.0, -scrollSpeed )); }
    if( utl.ray.isKeyDown( utl.ray.KeyboardKey.s ) or utl.ray.isKeyDown( utl.ray.KeyboardKey.down  )){ cam.moveByS( utl.Vec2.new(  0.0,  scrollSpeed )); }
    if( utl.ray.isKeyDown( utl.ray.KeyboardKey.a ) or utl.ray.isKeyDown( utl.ray.KeyboardKey.left  )){ cam.moveByS( utl.Vec2.new( -scrollSpeed,  0.0 )); }
    if( utl.ray.isKeyDown( utl.ray.KeyboardKey.d ) or utl.ray.isKeyDown( utl.ray.KeyboardKey.right )){ cam.moveByS( utl.Vec2.new(  scrollSpeed,  0.0 )); }

    // Zooms in and out with the mouse wheel
    if( utl.ray.getMouseWheelMove() >  utl.EPS ){ cam.zoomOnMouseBy( 1.0 * zoomSpeed ); }
    if( utl.ray.getMouseWheelMove() < -utl.EPS ){ cam.zoomOnMouseBy( 1.0 / zoomSpeed ); }
  }
  else
  {
    // Zooms in and out with the mouse wheel
    if( utl.ray.getMouseWheelMove() >  utl.EPS ){ cam.zoomBy( 1.0 * zoomSpeed ); }
    if( utl.ray.getMouseWheelMove() < -utl.EPS ){ cam.zoomBy( 1.0 / zoomSpeed ); }
  }

  // Resets the camera zoom and position
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.r ))
  {
    cam.setZoom( 1.0 );
    cam.cam.pos = .{};
    utl.qlog( .INFO, @src(), "Camera reset" );
  }
}


pub fn tickOrbiters( view : *gdf.OrbitTickView ) void
{
  var stepCount : u64 = 0;

  while( times.shouldBodyTick() )
  {
    stepCount += 1;
    times.consumeBodyTick();
  }

  if( stepCount == 0 ){ return; }


  for( gdf.bodyOrder )| bodyName |
  {
    if( bodyName == gdf.G_CONSTS.starBody ){ continue; }

    const id      = gbl.G_DATA.bodyRegistry.idOf( bodyName );
    const orbiter = view.get( orb.OrbitComp, id );

    if( orbiter == null ){ continue; }

    const orbitedId    = gbl.getOrbitedIdCached( bodyName );
    const orbiterTrans = view.get( eng.TransComp, id );
    const orbitedTrans = view.get( eng.TransComp, orbitedId );

    if( orbiterTrans != null and orbitedTrans != null )
    {
      utl.log( .TRACE, @src(), "Updating orbit of body {s} on entity #{d}", .{ @tagName( bodyName ), id });
      orbiter.?.updateOrbit( orbiterTrans.?, orbitedTrans.?, stepCount );
    }
    else
    {
      utl.log( .WARN, @src(), "Failed to get all required components to tick orbit of body {s} on entity #{d}", .{ @tagName( bodyName ), id });
    }
  }

//utl.log( .DEBUG, @src(), "Ticked all orbiters {d} steps", .{ stepCount });

  gdf.trvlSlvr.refreshDynamicTransferNodes( view );

  target.hasMoved = true; // Redundant for now since we update right after, but might become useful again later
}

pub fn tickGlobalEconomy( view : *gdf.BodyTransView, starPos : utl.Vec2 ) void
{
  var stepCount : u64 = 0;

  while( times.shouldEconTick() )
  {
    stepCount += 1;
    times.consumeEconTick();
  }

  if( stepCount == 0 ){ return; }

  for( 0..stepCount )| _ |
  {
    utl.qlog( .DEBUG, @src(), "# ================================ Ticking all econs once ================================" );

    for( gdf.bodyOrder )| bodyName |
    {
      if( bodyName == gdf.G_CONSTS.starBody ){ continue; }

      const id    = gbl.G_DATA.bodyRegistry.idOf( bodyName );
      const trans = view.get( eng.TransComp, id );
      const body  = view.get( bdy.BodyComp,  id );

      if( trans != null and body != null )
      {
        body.?.updateOrbitData( trans.?.pos.toVec2(), trans.?.vel.toVec2(), starPos );
      }
      else
      {
        utl.log( .WARN, @src(), "Failed to get all required components to update economy orbit data of body {s} on entity #{d}", .{ @tagName( bodyName ), id });
      }
    }

    const econCount = gbl.G_DATA.economies.tickAll();
    utl.log( .DEBUG, @src(), "Ticked {d} distinct economies", .{ econCount });
  }
  utl.log( .DEBUG, @src(), "==== Ticked global economy {d} time(s) ====", .{ stepCount });


  // DEBUG logging
//gdf.debugLogTravelCostsList( .TERRA, .ORBIT );
}

pub fn renderOrbiters( view : *gdf.OrbitRenderView ) void
{
  if( target.hasMoved ){ target.moveCamOver( view ); }

  // Rendering bodies' orbits and debug info
  for( gdf.bodyOrder )| bodyName |
  {
    if( bodyName == gdf.G_CONSTS.starBody ){ continue; }

    const id = gbl.G_DATA.bodyRegistry.idOf( bodyName );

    utl.log( .TRACE, @src(), "Rendering path & dbg info of body {s} on entity #{d}", .{ @tagName( bodyName ), id });

    const orbiter = view.get( orb.OrbitComp, id );

    if( orbiter == null ){ continue; }

    const orbiterBody  = view.get( bdy.BodyComp,  id );
    const orbiterTrans = view.get( eng.TransComp, id );

    const orbitedTrans = view.get( eng.TransComp, gbl.getOrbitedIdCached( bodyName ) );

    if( orbiterTrans != null and orbitedTrans != null and orbiterBody != null )
    {

      orbiter.?.renderPath( orbitedTrans.?.pos.toVec2() );

      if( target.targetId == id )
      {
        const orbitedPos = orbitedTrans.?.pos.toVec2();
        const orbitedVel = orbitedTrans.?.vel.toVec2();

        const orbiterPos = orbiterTrans.?.pos.toVec2();

        orbiter.?.renderDebug( orbitedVel, orbitedPos, orbiterPos, orbiterBody.?.radius, 1.0 );
        orbiter.?.renderLPs(   orbitedPos, orbiterBody.?.bodyType.getLPCount() );
      }
    }
    else
    {
      utl.log( .WARN, @src(), "Failed to get all required components to render orbital path of body {s} on entity #{d}", .{ @tagName( bodyName ), id });
    }
  }

  // Rendering bodies
  for( 0..gdf.bodyOrder.len )| i |
  {
    const idx      = gdf.bodyOrder.len - ( i + 1 ); // Render in opposite order, to ensure planets are above moons
    const bodyName = gdf.bodyOrder[ idx ];
    const id       = gbl.G_DATA.bodyRegistry.idOf( bodyName );

    utl.log( .TRACE, @src(), "Rendering shape of body {s} on entity #{d} at body idx #{d}", .{ @tagName( bodyName ), id, idx });

    const trans = view.get( eng.TransComp, id );
    const shape = view.get( eng.ShapeComp, id );

    if( trans != null and shape != null )
    {
      shape.?.render( trans.?.pos );
    }
    else
    {
      utl.log( .WARN, @src(), "Failed to get all required components to render shape of body {s} on entity #{d}", .{ @tagName( bodyName ), id });
    }
  }
}

pub fn drawTargetInfo( view : *gdf.OrbitRenderView ) void
{
  const col   = eng.G_CNFGS.Graphic_Metrics_Colour.?;
  const posX  = utl.getScreenWidth() - 16.0;
  const id    = target.targetId;

  if( id == 0 ){ return; }

  const bodyName = gbl.G_DATA.bodyRegistry.nameOf( id ) orelse return;

  const trans = view.get( eng.TransComp, id );
  const shape = view.get( eng.ShapeComp, id );

  const orbit = if( bodyName != gdf.G_CONSTS.starBody ) view.get( orb.OrbitComp, id ) else null;
  const body  = view.get( bdy.BodyComp, id );


  var lineCount : f32 = 1.0;

  utl.sDraw.textRightFmt( "==== Entity #{d} ====", .{ id }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.5;
  utl.sDraw.textRightFmt( "{s}", .{ @tagName( bodyName )}, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.5;

  if( trans != null )
  {
    utl.sDraw.textRightFmt( "{d:.0} :     posX", .{ trans.?.pos.x }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;
    utl.sDraw.textRightFmt( "{d:.0} :     posY", .{ trans.?.pos.y }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;

    lineCount += 0.5;
  }

  if( shape != null )
  {
    utl.sDraw.textRightFmt( "{d:.3} :  scaleX", .{ shape.?.scale.x }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;
    utl.sDraw.textRightFmt( "{d:.3} :  scaleY", .{ shape.?.scale.y },. new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;

    lineCount += 0.5;
  }

  if( body != null ) // PLANETS AND CO.
  {
    utl.sDraw.textRightFmt( "{d:.3} :     mass", .{ body.?.mass         }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;
    utl.sDraw.textRightFmt( "{d:.3} :  radius",  .{ body.?.radius       }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;
    utl.sDraw.textRightFmt( "{d:.3} : density",  .{ body.?.getDensity() }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;

    lineCount += 0.5;

    if( bodyName == gdf.G_CONSTS.starBody )
    {
      utl.sDraw.textRightFmt( "{d:.3} :    shine", .{ gbl.SUNSHINE.shineStrength }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;
    }
  }

  if( orbit != null )
  {
    utl.sDraw.textRightFmt( "{d:.0} :      minR", .{ orbit.?.minRadius }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;
    utl.sDraw.textRightFmt( "{d:.0} :     maxR",  .{ orbit.?.maxRadius }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;

    lineCount += 0.5;
  }

  if( target.camFollow )
  {
    utl.sDraw.textRight( "Traking ON", .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;
    lineCount += 0.5;
  }
}
