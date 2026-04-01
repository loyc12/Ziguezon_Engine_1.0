const std = @import( "std" );
const def = @import( "defs" );

const gbl = @import( "gameGlobals.zig" );

const BodyType = gbl.BodyType;

const orb    = gbl.orb;
const bdy    = gbl.bdy;
const ecn    = gbl.econ;


// ================================ STATE INJECT ================================

inline fn initStellarBody( orbitComp : *orb.OrbitComp, bodyComp : *bdy.BodyComp, bodyName : gbl.BodyName, orbitedId : def.EntityId ) void
{
  const orbiterMass = gbl.STLR_DATA.get( bodyName, .MASS );
  var   orbitedMass = gbl.STLR_DATA.get( .SOL,     .MASS );

  if( orbitedId != gbl.starId ){ if( gbl.bodyStore.get( orbitedId ))| b |
  {
    orbitedMass = b.mass;
  }
  else
  {
    def.log( .WARN, 0, @src(), "Failed to find bodyComp for id {d} : defaulting to using star's mass", .{ orbitedId });
  }}

  orbitComp.* = .initFromParams(
    orbitedMass,       orbiterMass,
    gbl.STLR_DATA.get( bodyName, .PERIAP ),
    gbl.STLR_DATA.get( bodyName, .APOAP  ),
    gbl.STLR_DATA.get( bodyName, .LONG   ),
    null,
  );
  orbitComp.orbitedID = orbitedId;

  bodyComp.bodyType = .fromFlt( gbl.STLR_DATA.get( bodyName, .TYPE ));
  bodyComp.name     = bodyName;
  bodyComp.mass     = orbiterMass;
  bodyComp.radius   = gbl.STLR_DATA.get( bodyName, .RADIUS );

  bodyComp.softInitAllEcons();

  if( bodyName == .TERRA )
  {
    bodyComp.quickInitEcon( .GROUND, true );
  }
}


pub fn initStellarSystem( ng : *def.Engine ) void
{
  // Setting up relevant components
  for( 0..gbl.ENTITY_COUNT )| idx |
  {
    gbl.entityArray[ idx ] = ng.entityIdRegistry.getNewEntity();

    const id = gbl.entityArray[ idx ].id;

    def.log( .INFO, 0, @src(), "Initializing components of entity #{d} at idx #{d}", .{ id, idx });


    if( id == 1 ) // TODO : use bodyComp for sol as well, as it need not be its own thing
    {
      gbl.starCompInst.mass   = gbl.STLR_DATA.get( .SOL, .MASS );
      gbl.starCompInst.radius = gbl.STLR_DATA.get( .SOL, .RADIUS );

      const terraMin = gbl.STLR_DATA.get( .TERRA, .PERIAP );
      const terraMax = gbl.STLR_DATA.get( .TERRA, .APOAP  );

      gbl.starCompInst.setShineAtDist( 1.0, 0.5 * ( terraMin + terraMax )); // TODO : replace with irl units for sunlight

      const r = gbl.starCompInst.radius;

      _ = gbl.transStore.add(  id, .{ .pos    = .{} });
      _ = gbl.shapeStore.add(  id, .{ .colour = .gold, .minSize = .new( 6, 6 ), .scale = .new( r, r ), .shape = .ELLI });

      continue;
    }


    // Non-sun component instanciation

    var orbitComp : gbl.orb.OrbitComp = undefined;
    var bodyComp  : gbl.bdy.BodyComp  = .{};

    switch( id ) // Adjusting bodyType-specific orbitComp and bodyComp variables
    {
      2 => initStellarBody( &orbitComp, &bodyComp, .MERCURY, 1 ),

      3 => initStellarBody( &orbitComp, &bodyComp, .VENUS,   1 ),

      4 => // EARTH
      {
        initStellarBody( &orbitComp, &bodyComp, .TERRA, 1 );

        // NOTE : DEBUG
        bodyComp.debugSetEconVals( .GROUND, 1 );
      },
      5 => initStellarBody( &orbitComp, &bodyComp, .LUNA,   4 ),

      6 => initStellarBody( &orbitComp, &bodyComp, .MARS,   1 ),
      7 => initStellarBody( &orbitComp, &bodyComp, .PHOBOS, 6 ),
      8 => initStellarBody( &orbitComp, &bodyComp, .DEIMOS, 6 ),

      else => // Wil ignore all subsequent Ids ( should be none )
      {
        def.log( .INFO, 0, @src(), "Id #{d} is invalid: will not initialize related comps", .{ id });
        continue;
      },
    }

    var startPos = orbitComp.getRelPos(); // Get initial position from orbit

    if( orbitComp.orbitedID != gbl.starId ){ if( gbl.transStore.get( orbitComp.orbitedID ))| trans |
    {
      startPos = startPos.add( trans.pos.toVec2() );
    }
    else
    {
      def.log( .WARN, 0, @src(), "Failed to find bodyComp for id {d} : defaulting to using star's mass", .{ orbitComp.orbitedID });
    }}

    _ = gbl.transStore.add(  id, .{ .pos = .new( startPos.x, startPos.y, .{} )});
    _ = gbl.shapeStore.add(  id,
    .{
      .colour  = bodyComp.bodyType.getDisplayColour(),
      .minSize = bodyComp.bodyType.getMinDisplaySize(),
      .scale   = .new( bodyComp.radius, bodyComp.radius ),
      .shape   = .ELLI
    });
  //_ = gbl.spriteStore.add( id, .{} );

    _ = gbl.orbitStore.add(  id, orbitComp );
    _ = gbl.bodyStore.add(   id, bodyComp  );
  }
}



// ================================ STEP INJECT ================================

pub fn updateCameraLogic() void
{
  var cam = &def.G_CAM;

  // Moves the camera with the WASD or arrow keys
  if( def.ray.isKeyDown( def.ray.KeyboardKey.w ) or def.ray.isKeyDown( def.ray.KeyboardKey.up    )){ cam.moveByS( def.Vec2.new(  0.0, -gbl.scrollSpeed )); }
  if( def.ray.isKeyDown( def.ray.KeyboardKey.s ) or def.ray.isKeyDown( def.ray.KeyboardKey.down  )){ cam.moveByS( def.Vec2.new(  0.0,  gbl.scrollSpeed )); }
  if( def.ray.isKeyDown( def.ray.KeyboardKey.a ) or def.ray.isKeyDown( def.ray.KeyboardKey.left  )){ cam.moveByS( def.Vec2.new( -gbl.scrollSpeed,  0.0 )); }
  if( def.ray.isKeyDown( def.ray.KeyboardKey.d ) or def.ray.isKeyDown( def.ray.KeyboardKey.right )){ cam.moveByS( def.Vec2.new(  gbl.scrollSpeed,  0.0 )); }

  // Zooms in and out with the mouse wheel
  if( gbl.followTarget )
  {
    if( def.ray.getMouseWheelMove() > 0.0 ){ cam.zoomBy( 1.0 * gbl.zoomSpeed ); }
    if( def.ray.getMouseWheelMove() < 0.0 ){ cam.zoomBy( 1.0 / gbl.zoomSpeed ); }
  }
  else
  {
    if( def.ray.getMouseWheelMove() > 0.0 ){ cam.zoomOnMouseBy( 1.0 * gbl.zoomSpeed ); }
    if( def.ray.getMouseWheelMove() < 0.0 ){ cam.zoomOnMouseBy( 1.0 / gbl.zoomSpeed ); }
  }

  // Resets the camera zoom and position
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.r ))
  {
    cam.setZoom( 1.0 );
    cam.pos = .{};
    def.qlog( .INFO, 0, @src(), "Camera reset" );
  }

  // Centers the camera on current valid target
  if( gbl.targetId != 0 and gbl.targetHasMoved and gbl.followTarget )
  {
    gbl.targetHasMoved = false;

    const targetTrans = gbl.transStore.get( gbl.targetId );

    if( targetTrans )| trans |
    {
      cam.pos = trans.pos;
      def.qlog( .TRACE, 0, @src(), "View centered on target" );
    }
    else
    {
      def.qlog( .WARN, 0, @src(), "Target does not exist : cannot center view" );
    }
  }
}

pub fn tickOrbiters( transStore : *gbl.TransStore, orbitStore : *gbl.OrbitStore, sdt : f32 ) void
{
  for( 1..gbl.entityArray.len )| idx |
  {
    const id      = gbl.entityArray[ idx ].id;
    const orbiter = orbitStore.get( id );

    if( orbiter == null ){ continue; }

    const orbiterTrans = transStore.get( id );
    const orbitedTrans = transStore.get( orbiter.?.orbitedID );

    if( orbiterTrans != null and orbitedTrans != null )
    {
      def.log( .TRACE, 0, @src(), "Updating orbit of entity #{d}", .{ id });
      orbiter.?.updateOrbit( orbiterTrans.?, orbitedTrans.?, sdt );

      // NOTE : DEBUG
      if( id == gbl.targetId )
      {
        def.log( .DEBUG, 0, @src(), "Period lenght of targeted body : {d:.3}", .{ orbiter.?.period });
      }
    }
    else
    {
      def.log( .WARN, 0, @src(), "Failed to get all required components to tick orbit of entity #{d}", .{ id });
    }
  }

  gbl.targetHasMoved = true;
}

pub fn tickGlobalEconomy( transStore : *gbl.TransStore, bodyStore : *gbl.BodyStore, starPos : def.Vec2 ) void
{
  inline for( 1..gbl.entityArray.len )| idx |
  {
    const id    = gbl.entityArray[ idx ].id;
    const trans = transStore.get( id );
    const body  = bodyStore.get(  id );

    if( trans != null and body != null )
    {
      body.?.tickAllEcons( trans.?.pos.toVec2(), trans.?.vel.toVec2(), starPos );
    }
    else
    {
      def.log( .WARN, 0, @src(), "Failed to get all required components to tick economy of entity #{d}", .{ id });
    }
  }

  // Update travel table from the fresh orbital data generated in tickAllEcons()
  gbl.trfSlvr.updateTravelTable();
}

pub fn renderOrbiters( transStore : *gbl.TransStore, shapeStore : *gbl.ShapeStore, orbitStore : *gbl.OrbitStore, bodyStore : *gbl.BodyStore ) void
{
  // Rendering bodies' orbits and debug info
  for( 1..gbl.entityArray.len )| idx |
  {
    const id = gbl.entityArray[ idx ].id;

    def.log( .TRACE, 0, @src(), "Rendering path & dbg info of entity #{d} at idx #{d}", .{ id, idx });

    const orbiter = orbitStore.get( id );

    if( orbiter == null ){ continue; }

    const orbiterBody  = bodyStore.get(  id );
    const orbiterTrans = transStore.get( id );

    const orbitedTrans = transStore.get( orbiter.?.orbitedID );

    if( orbiterTrans != null and orbitedTrans != null and orbiterBody != null )
    {

      orbiter.?.renderPath( orbitedTrans.?.pos.toVec2() );

      if( gbl.targetId == id )
      {
        orbiter.?.renderDebug( orbitedTrans.?.pos.toVec2(), orbiterTrans.?.pos.toVec2(), orbiterBody.?.radius, 1.0 );
        orbiter.?.renderLPs(   orbitedTrans.?.pos.toVec2(), orbiterBody.?.bodyType.getLPCount() );
      }
    }
    else
    {
      def.log( .WARN, 0, @src(), "Failed to get all required components to render orbital path of entity #{d}", .{ id });
    }
  }

  // Rendering bodies
  for( 0..gbl.entityArray.len )| i |
  {
    const idx = gbl.entityArray.len - ( i + 1 ); // Render in opposite order, to ensure planets are above moons
    const id  = gbl.entityArray[ idx ].id;

    def.log( .TRACE, 0, @src(), "Rendering shape of entity #{d} at idx #{d}", .{ id, idx });

    const trans = transStore.get( id );
    const shape = shapeStore.get( id );

    if( trans != null and shape != null )
    {
      shape.?.render( trans.?.pos );
    }
    else
    {
      def.log( .WARN, 0, @src(), "Failed to get all required components to render shape of entity #{d}", .{ id });
    }
  }
}

pub fn drawTargetInfo( transStore : *gbl.TransStore, shapeStore : *gbl.ShapeStore, orbitStore : *gbl.OrbitStore, bodyStore : *gbl.BodyStore ) void
{
  const col   = def.G_ST.Graphic_Metrics_Colour.?;
  const posX  = def.getScreenWidth() - 16.0;
  const id    = gbl.targetId;

  if( id == 0 or id > gbl.ENTITY_COUNT ){ return; }

  const trans = transStore.get( id );
  const shape = shapeStore.get( id );

  const orbit = if( id != gbl.starId ) orbitStore.get( id ) else null;
  const body  = if( id != gbl.starId ) bodyStore.get(  id ) else null;


  var lineCount : f32 = 1.0;

  def.drawTextRightFmt( "== Entity #{d} ==", .{ id }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.5;


  if( trans != null )
  {
    def.drawTextRightFmt( "{d:.3} :     posX", .{ trans.?.pos.x }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;
    def.drawTextRightFmt( "{d:.3} :     posY", .{ trans.?.pos.y }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;

    lineCount += 0.5;
  }

  if( shape != null )
  {
    def.drawTextRightFmt( "{d:.3} :  scaleX", .{ shape.?.scale.x }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;
    def.drawTextRightFmt( "{d:.3} :  scaleY", .{ shape.?.scale.y },. new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;

    lineCount += 0.5;
  }

  if( gbl.targetId == gbl.starId ) // SUN
  {
    const star = gbl.starCompInst;

    def.drawTextRightFmt( "{d:.3} :     mass", .{ star.mass         }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;
    def.drawTextRightFmt( "{d:.3} :  radius",  .{ star.radius       }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;
    def.drawTextRightFmt( "{d:.3} : density",  .{ star.getDensity() }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;
    def.drawTextRightFmt( "{d:.3} :    shine", .{ star.shine        }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;

    lineCount += 0.5;
  }
  else if( body != null ) // PLANETS AND CO.
  {
    def.drawTextRightFmt( "{d:.3} :     mass", .{ body.?.mass         }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;
    def.drawTextRightFmt( "{d:.3} :  radius",  .{ body.?.radius       }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;
    def.drawTextRightFmt( "{d:.3} : density",  .{ body.?.getDensity() }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;

    lineCount += 0.5;
  }

  if( orbit != null )
  {
    def.drawTextRightFmt( "{d:.3} :      minR", .{ orbit.?.minRadius }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;
    def.drawTextRightFmt( "{d:.3} :     maxR",  .{ orbit.?.maxRadius }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;

    lineCount += 0.5;
  }
}