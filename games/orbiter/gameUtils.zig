const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

const gbl = @import( "gameGlobals.zig" );
const gdf = @import( "gameDef.zig"    );

const times  = &gbl.G_DATA.times;
const stores = &gbl.G_DATA.stores;
const target = &gbl.G_DATA.target;
const nttArr = &gbl.G_DATA.entityArray;

const BodyName  = gdf.BodyName;
const BodyType  = gdf.BodyType;
const bodyCount = gdf.G_CONSTS.bodyCount;

const orb = gdf.orb;
const bdy = gdf.bdy;
const ecn = gdf.econ;


// ================================ STATE INJECT ================================

inline fn initStar( bodyComp : *bdy.BodyComp, bodyId : eng.EntityId ) void
{
  const bodyName = gdf.nameFromId( bodyId );

  bodyComp.bodyType = .fromFlt( gbl.STLR_DATA.get( bodyName, .TYPE ));
  bodyComp.name     = bodyName;
  bodyComp.mass     = gbl.STLR_DATA.get( bodyName, .MASS );
  bodyComp.radius   = gbl.STLR_DATA.get( bodyName, .RADIUS );

  bodyComp.softInitAllEcons();
}

fn initStellarBody( orbitComp : *orb.OrbitComp, bodyComp : *bdy.BodyComp, bodyId : eng.EntityId ) void
{
  const bodyName  = gdf.nameFromId( bodyId );
  const orbitedId = gbl.ORBITANCE.getOrbitedId( bodyId );

//utl.log( .DEBUG, 0, @src(), "{s} orbits {s} ( {d} > {d} )", .{ @tagName( gdf.nameFromId( bodyId )), @tagName( gdf.nameFromId( orbitedId )), bodyId, orbitedId });

  const orbiterMass = gbl.STLR_DATA.get( bodyName, .MASS );
  var   orbitedMass = gbl.STLR_DATA.get( .SOL,     .MASS );

  if( orbitedId != gdf.G_CONSTS.starId ){ if( stores.body.get( orbitedId ))| b |
  {
    orbitedMass = b.mass;
  }
  else
  {
    utl.log( .WARN, 0, @src(), "Failed to find bodyComp for id {d} : defaulting to using star's mass", .{ orbitedId });
  }}

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

      if( bodyComp.bodyType.canHostEconLoc( loc ))
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


pub fn initStellarSystem( ng : *eng.Engine ) void
{
  // Setting up relevant components
  for( 0..bodyCount )| idx |
  {
    nttArr[ idx ] = ng.entityIdRegistry.getNewEntity();

    const id = nttArr[ idx ].id;

    utl.log( .TRACE, 0, @src(), "Initializing components of entity #{d} at idx #{d}", .{ id, idx });


    // Non-sun component instanciation

    var orbitComp : orb.OrbitComp = undefined;
    var bodyComp  : bdy.BodyComp  = .{};


    var startPos : utl.Vec2 = .{};

    if( id > gdf.G_CONSTS.maxEntityId ) // Will ignore all subsequent Ids ( should have none left )
    {
      utl.log( .INFO, 0, @src(), "Id #{d} is invalid: will not initialize related comps", .{ id });
      continue;
    }
    else if( id == gdf.G_CONSTS.starId )
    {
      initStar( &bodyComp, id ); // Setting sol's bodyComp variables
    }
    else
    {
      initStellarBody( &orbitComp, &bodyComp, id ); // Setting bodyType-specific orbitComp and bodyComp variables

      const orbitedId = gbl.ORBITANCE.getOrbitedId( id );
             startPos = orbitComp.getRelPos();

      if( orbitedId != gdf.G_CONSTS.starId )
      {
        if( stores.trans.get( orbitedId ))| trans |
        {
          startPos = startPos.add( trans.pos.toVec2() );
        }
        else
        {
          utl.log( .ERROR, 0, @src(), "Failed to find bodyComp for id {d} : defaulting to using star's mass", .{ orbitedId });
        }
      }

      _ = stores.orbit.add( id, orbitComp ); // SOL does not have an orbit comp
    }


    _ = stores.trans.add( id, .{ .pos = startPos.toVecA( .{} )});
    _ = stores.body.add(  id, bodyComp  );
    _ = stores.shape.add( id,
    .{
      .colour  = bodyComp.bodyType.getDisplayColour(),
      .minSize = bodyComp.bodyType.getMinDisplaySize(),
      .scale   = .new( bodyComp.radius, bodyComp.radius ),
      .shape   = .ELLI
    });

  }

  gdf.trvlSlvr.refreshAllTransferNodes();
}



// ================================ STEP INJECT ================================

pub fn updateCameraLogic() void
{
  var cam = &eng.G_CAM;

  const scrollSpeed = gdf.G_CONSTS.scrollSpeed;
  const zoomSpeed   = gdf.G_CONSTS.zoomSpeed;

  // Moves the camera with the WASD or arrow keys
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.w ) or utl.ray.isKeyDown( utl.ray.KeyboardKey.up    )){ cam.moveByS( utl.Vec2.new(  0.0, -scrollSpeed )); }
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.s ) or utl.ray.isKeyDown( utl.ray.KeyboardKey.down  )){ cam.moveByS( utl.Vec2.new(  0.0,  scrollSpeed )); }
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.a ) or utl.ray.isKeyDown( utl.ray.KeyboardKey.left  )){ cam.moveByS( utl.Vec2.new( -scrollSpeed,  0.0 )); }
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.d ) or utl.ray.isKeyDown( utl.ray.KeyboardKey.right )){ cam.moveByS( utl.Vec2.new(  scrollSpeed,  0.0 )); }

  // Zooms in and out with the mouse wheel
  if( target.camFollow )
  {
    if( utl.ray.getMouseWheelMove() >  utl.EPS ){ cam.zoomBy( 1.0 * zoomSpeed ); }
    if( utl.ray.getMouseWheelMove() < -utl.EPS ){ cam.zoomBy( 1.0 / zoomSpeed ); }
  }
  else
  {
    if( utl.ray.getMouseWheelMove() >  utl.EPS ){ cam.zoomOnMouseBy( 1.0 * zoomSpeed ); }
    if( utl.ray.getMouseWheelMove() < -utl.EPS ){ cam.zoomOnMouseBy( 1.0 / zoomSpeed ); }
  }

  // Resets the camera zoom and position
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.r ))
  {
    cam.setZoom( 1.0 );
    cam.pos = .{};
    utl.qlog( .INFO, 0, @src(), "Camera reset" );
  }
}


pub fn tickOrbiters( transStore : *gdf.TransStore, orbitStore : *gdf.OrbitStore ) void
{
  var stepCount : u64 = 0;

  while( times.shouldBodyTick() )
  {
    stepCount += 1;
    times.consumeBodyTick();
  }

  if( stepCount == 0 ){ return; }


  for( 1..nttArr.len )| idx |
  {
    const id      = nttArr[ idx ].id;
    const orbiter = orbitStore.get( id );

    if( orbiter == null ){ continue; }

    const orbiterTrans = transStore.get( id );
    const orbitedTrans = transStore.get( gbl.ORBITANCE.getOrbitedId( id ) );

    if( orbiterTrans != null and orbitedTrans != null )
    {
      utl.log( .TRACE, 0, @src(), "Updating orbit of entity #{d}", .{ id });
      orbiter.?.updateOrbit( orbiterTrans.?, orbitedTrans.?, stepCount );
    }
    else
    {
      utl.log( .WARN, 0, @src(), "Failed to get all required components to tick orbit of entity #{d}", .{ id });
    }
  }

//utl.log( .DEBUG, 0, @src(), "Ticked all orbiters {d} steps", .{ stepCount });

  gdf.trvlSlvr.refreshDynamicTransferNodes();

  target.hasMoved = true; // Redundant for now since we update right after, but might become useful again later
}

pub fn tickGlobalEconomy( transStore : *gdf.TransStore, bodyStore : *gdf.BodyStore, starPos : utl.Vec2 ) void
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
    utl.qlog( .DEBUG, 0, @src(), "# ================================ Ticking all econs once ================================" );

    var econCount : u32 = 0;

    inline for( 1..nttArr.len )| idx |
    {
      const id    = nttArr[ idx ].id;
      const trans = transStore.get( id );
      const body  = bodyStore.get(  id );

      if( trans != null and body != null )
      {
        econCount += body.?.tickAllEcons( trans.?.pos.toVec2(), trans.?.vel.toVec2(), starPos );
      }
      else
      {
        utl.log( .WARN, 0, @src(), "Failed to get all required components to tick economy of entity #{d}", .{ id });
      }
    }

    utl.log( .DEBUG, 0, @src(), "Ticked {d} distinct economies", .{ econCount });
  }
  utl.log( .DEBUG, 0, @src(), "==== Ticked global economy {d} time(s) ====", .{ stepCount });


  // DEBUG logging
//gdf.debugLogTravelCostsList( .TERRA, .ORBIT );
}

pub fn renderOrbiters( transStore : *gdf.TransStore, shapeStore : *gdf.ShapeStore, orbitStore : *gdf.OrbitStore, bodyStore : *gdf.BodyStore ) void
{
  if( target.hasMoved ){ target.moveCamOver(); }

  // Rendering bodies' orbits and debug info
  for( 1..nttArr.len )| idx |
  {
    const id = nttArr[ idx ].id;

    utl.log( .TRACE, 0, @src(), "Rendering path & dbg info of entity #{d} at idx #{d}", .{ id, idx });

    const orbiter = orbitStore.get( id );

    if( orbiter == null ){ continue; }

    const orbiterBody  = bodyStore.get(  id );
    const orbiterTrans = transStore.get( id );

    const orbitedTrans = transStore.get( gbl.ORBITANCE.getOrbitedId( id ) );

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
      utl.log( .WARN, 0, @src(), "Failed to get all required components to render orbital path of entity #{d}", .{ id });
    }
  }

  // Rendering bodies
  for( 0..nttArr.len )| i |
  {
    const idx = nttArr.len - ( i + 1 ); // Render in opposite order, to ensure planets are above moons
    const id  = nttArr[ idx ].id;

    utl.log( .TRACE, 0, @src(), "Rendering shape of entity #{d} at idx #{d}", .{ id, idx });

    const trans = transStore.get( id );
    const shape = shapeStore.get( id );

    if( trans != null and shape != null )
    {
      shape.?.render( trans.?.pos );
    }
    else
    {
      utl.log( .WARN, 0, @src(), "Failed to get all required components to render shape of entity #{d}", .{ id });
    }
  }
}

pub fn drawTargetInfo( transStore : *gdf.TransStore, shapeStore : *gdf.ShapeStore, orbitStore : *gdf.OrbitStore, bodyStore : *gdf.BodyStore ) void
{
  const col   = eng.CNFGS.Graphic_Metrics_Colour.?;
  const posX  = utl.getScreenWidth() - 16.0;
  const id    = target.targetId;

  if( id == 0 or id > bodyCount ){ return; }

  const trans = transStore.get( id );
  const shape = shapeStore.get( id );

  const orbit = if( id != gdf.G_CONSTS.starId ) orbitStore.get( id ) else null;
  const body  = if( id != gdf.G_CONSTS.starId ) bodyStore.get(  id ) else null;


  var lineCount : f32 = 1.0;

  utl.sDraw.textRightFmt( "== Entity #{d} ==", .{ id }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.5;


  if( trans != null )
  {
    utl.sDraw.textRightFmt( "{d:.3} :     posX", .{ trans.?.pos.x }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;
    utl.sDraw.textRightFmt( "{d:.3} :     posY", .{ trans.?.pos.y }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;

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

    if( target.targetId == gdf.G_CONSTS.starId )
    {
      utl.sDraw.textRightFmt( "{d:.3} :    shine", .{ gbl.SUNSHINE.shineStrenght }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;
    }

    lineCount += 0.5;
  }

  if( orbit != null )
  {
    utl.sDraw.textRightFmt( "{d:.3} :      minR", .{ orbit.?.minRadius }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;
    utl.sDraw.textRightFmt( "{d:.3} :     maxR",  .{ orbit.?.maxRadius }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;

    lineCount += 0.5;
  }

  if( target.camFollow )
  {
    utl.sDraw.textRight( "Traking ON", .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;
    lineCount += 0.5;
  }
}
