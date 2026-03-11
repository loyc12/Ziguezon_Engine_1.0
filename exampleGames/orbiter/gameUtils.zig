const std = @import( "std" );
const def = @import( "defs" );

const glb = @import( "gameGlobals.zig" );
const orb = @import( "comp/orbitComp.zig" );
const ecn = @import( "comp/economy.zig" );



// ================================ STATE INJECT ================================

pub fn initDebugSystem( ng : *def.Engine ) void
{
  // Setting up relevant components
  for( 0..glb.ENTITY_COUNT )| idx |
  {
    glb.entityArray[ idx ] = ng.entityIdRegistry.getNewEntity();

    const id = glb.entityArray[ idx ].id;

    def.log( .INFO, 0, @src(), "Initializing components of entity #{} at idx #{}", .{ id, idx });


    if( id == 1 ) // Here comes the sun, lalalala
    {
    //glb.starId = 1;

      glb.starCompInst.mass   = glb.STLR_DATA.get( .SOL, .MASS );
      glb.starCompInst.radius = glb.STLR_DATA.get( .SOL, .RADIUS );

      const terraMin = glb.STLR_DATA.get( .TERRA, .PERIAP );
      const terraMax = glb.STLR_DATA.get( .TERRA, .APOAP  );

      glb.starCompInst.setShineAtDist( 1.0, 0.5 * ( terraMin + terraMax ));

      const r = glb.starCompInst.radius;

      _ = glb.transStore.add(  id, .{ .pos = .{} });
      _ = glb.shapeStore.add(  id, .{ .colour = .yellow, .scale = .new( r, r ), .shape = .ELLI });
    //_ = glb.spriteStore.add( id, .{} );

      continue;
    }


    // Non-sun component instanciation

    var orbitComp : glb.orb.OrbitComp = .{};
    var bodyComp  : glb.bdy.BodyComp  = .{};

    switch( id ) // Adjusting bodyType-specific orbitComp and bodyComp variables
    {
      2 => // MERCURY
      {

        orbitComp.orbitedMass = glb.STLR_DATA.get( .SOL,     .MASS );
        orbitComp.orbiterMass = glb.STLR_DATA.get( .MERCURY, .MASS );

        orbitComp.minRadius   = glb.STLR_DATA.get( .MERCURY, .PERIAP );
        orbitComp.maxRadius   = glb.STLR_DATA.get( .MERCURY, .APOAP  );

        orbitComp.orientation = @floatCast( glb.STLR_DATA.get( .MERCURY, .LONG ));


        bodyComp.mass         = glb.STLR_DATA.get( .MERCURY, .MASS   );
        bodyComp.radius       = glb.STLR_DATA.get( .MERCURY, .RADIUS );

        bodyComp.bodyType     = .PLANET;
      },
      3 => // VENUS
      {
        orbitComp.orbitedMass = glb.STLR_DATA.get( .SOL,   .MASS );
        orbitComp.orbiterMass = glb.STLR_DATA.get( .VENUS, .MASS );

        orbitComp.minRadius   = glb.STLR_DATA.get( .VENUS, .PERIAP );
        orbitComp.maxRadius   = glb.STLR_DATA.get( .VENUS, .APOAP  );

        orbitComp.orientation = @floatCast( glb.STLR_DATA.get( .VENUS, .LONG ));


        bodyComp.mass         = glb.STLR_DATA.get( .VENUS, .MASS   );
        bodyComp.radius       = glb.STLR_DATA.get( .VENUS, .RADIUS );

        bodyComp.bodyType     = .PLANET;
      },


      4 => // EARTH
      {
      //glb.homeworldId = 4;

        orbitComp.orbitedMass = glb.STLR_DATA.get( .SOL,   .MASS );
        orbitComp.orbiterMass = glb.STLR_DATA.get( .TERRA, .MASS );

        orbitComp.minRadius   = glb.STLR_DATA.get( .TERRA, .PERIAP );
        orbitComp.maxRadius   = glb.STLR_DATA.get( .TERRA, .APOAP  );

        orbitComp.orientation = @floatCast( glb.STLR_DATA.get( .TERRA, .LONG ));


        bodyComp.mass         = glb.STLR_DATA.get( .TERRA, .MASS   );
        bodyComp.radius       = glb.STLR_DATA.get( .TERRA, .RADIUS );

        bodyComp.bodyType     = .PLANET;

        bodyComp.initEcon( .GROUND );

        // NOTE : DEBUG
        bodyComp.debugSetEconVals( 1 );
      },
      5 => // MOON
      {
        orbitComp.orbitedID   = 4; // Terra

        orbitComp.orbitedMass = glb.STLR_DATA.get( .SOL,  .MASS );
        orbitComp.orbiterMass = glb.STLR_DATA.get( .LUNA, .MASS );

        orbitComp.minRadius   = glb.STLR_DATA.get( .LUNA, .PERIAP );
        orbitComp.maxRadius   = glb.STLR_DATA.get( .LUNA, .APOAP  );

        orbitComp.orientation = @floatCast( glb.STLR_DATA.get( .LUNA, .LONG ));


        bodyComp.mass         = glb.STLR_DATA.get( .LUNA, .MASS   );
        bodyComp.radius       = glb.STLR_DATA.get( .LUNA, .RADIUS );

        bodyComp.bodyType     = .MOON;
      },


      6 => // MARS
      {
        orbitComp.orbitedMass = glb.STLR_DATA.get( .SOL,  .MASS );
        orbitComp.orbiterMass = glb.STLR_DATA.get( .MARS, .MASS );

        orbitComp.minRadius   = glb.STLR_DATA.get( .MARS, .PERIAP );
        orbitComp.maxRadius   = glb.STLR_DATA.get( .MARS, .APOAP  );

        orbitComp.orientation = @floatCast( glb.STLR_DATA.get( .MARS, .LONG ));


        bodyComp.mass         = glb.STLR_DATA.get( .MARS, .MASS   );
        bodyComp.radius       = glb.STLR_DATA.get( .MARS, .RADIUS );

        bodyComp.bodyType     = .PLANET;
      },
      7 => // PHOBOS
      {
        orbitComp.orbitedID   = 6; // Mars

        orbitComp.orbitedMass = glb.STLR_DATA.get( .MARS,   .MASS );
        orbitComp.orbiterMass = glb.STLR_DATA.get( .PHOBOS, .MASS );

        orbitComp.minRadius   = glb.STLR_DATA.get( .PHOBOS, .PERIAP );
        orbitComp.maxRadius   = glb.STLR_DATA.get( .PHOBOS, .APOAP  );

        orbitComp.orientation = @floatCast( glb.STLR_DATA.get( .PHOBOS, .LONG ));


        bodyComp.mass         = glb.STLR_DATA.get( .PHOBOS, .MASS   );
        bodyComp.radius       = glb.STLR_DATA.get( .PHOBOS, .RADIUS );

        bodyComp.bodyType     = .COMET;
      },
      8 => // DEIMOS
      {
        orbitComp.orbitedID   = 6; // Mars

        orbitComp.orbitedMass = glb.STLR_DATA.get( .MARS,   .MASS );
        orbitComp.orbiterMass = glb.STLR_DATA.get( .DEIMOS, .MASS );

        orbitComp.minRadius   = glb.STLR_DATA.get( .DEIMOS, .PERIAP );
        orbitComp.maxRadius   = glb.STLR_DATA.get( .DEIMOS, .APOAP  );

        orbitComp.orientation = @floatCast( glb.STLR_DATA.get( .DEIMOS, .LONG ));


        bodyComp.mass         = glb.STLR_DATA.get( .DEIMOS, .MASS   );
        bodyComp.radius       = glb.STLR_DATA.get( .DEIMOS, .RADIUS );

        bodyComp.bodyType     = .COMET;
      },

      else => // Wil ignore all subsequent Ids ( should be none )
      {
        def.log( .INFO, 0, @src(), "Id #{d} is invalid: will not initialize related comps", .{ id });
        continue;
      },
    }


    const startPos = orbitComp.getAbsPos( .{} ); // Get initial position from orbit

    _ = glb.transStore.add(  id, .{ .pos = .new( startPos.x, startPos.y, .{} )});
    _ = glb.shapeStore.add(  id, .{ .colour = .nWhite, .scale = .new( bodyComp.radius, bodyComp.radius ), .shape = .ELLI });
  //_ = glb.spriteStore.add( id, .{} );

    _ = glb.orbitStore.add(  id, orbitComp );
    _ = glb.bodyStore.add(   id, bodyComp  );
  }
}



// ================================ STEP INJECT ================================

pub fn updateCameraLogic( cam : *def.Cam2D ) void
{

  // Move the camera with the WASD or arrow keys
  if( def.ray.isKeyDown( def.ray.KeyboardKey.w ) or def.ray.isKeyDown( def.ray.KeyboardKey.up    )){ cam.moveByS( def.Vec2.new(  0.0, -glb.scrollSpeed )); }
  if( def.ray.isKeyDown( def.ray.KeyboardKey.s ) or def.ray.isKeyDown( def.ray.KeyboardKey.down  )){ cam.moveByS( def.Vec2.new(  0.0,  glb.scrollSpeed )); }
  if( def.ray.isKeyDown( def.ray.KeyboardKey.a ) or def.ray.isKeyDown( def.ray.KeyboardKey.left  )){ cam.moveByS( def.Vec2.new( -glb.scrollSpeed,  0.0 )); }
  if( def.ray.isKeyDown( def.ray.KeyboardKey.d ) or def.ray.isKeyDown( def.ray.KeyboardKey.right )){ cam.moveByS( def.Vec2.new(  glb.scrollSpeed,  0.0 )); }

  // Zoom in and out with the mouse wheel
  if( def.ray.getMouseWheelMove() > 0.0 ){ cam.zoomBy( 1.0 * glb.zoomSpeed ); }
  if( def.ray.getMouseWheelMove() < 0.0 ){ cam.zoomBy( 1.0 / glb.zoomSpeed ); }

  // Reset the camera zoom and position when r is pressed
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.r ))
  {
    cam.setZoom(   1.0 );
    cam.pos = .{};
    def.qlog( .INFO, 0, @src(), "Camera reset" );
  }
}

pub fn tickOrbiters( transStore : *glb.TransStore, orbitStore : *glb.OrbitStore, sdt : f32 ) void
{
  for( 1..glb.entityArray.len )| idx |
  {
    const id      = glb.entityArray[ idx ].id;
    const orbiter = orbitStore.get( id );

    if( orbiter == null ){ continue; }

    const orbiterTrans = transStore.get( id );
    const orbitedTrans = transStore.get( orbiter.?.orbitedID );

    if( orbiterTrans != null and orbitedTrans != null )
    {
      def.log( .TRACE, 0, @src(), "Updating orbit of entity #{d}", .{ id });
      orbiter.?.updateOrbit( orbiterTrans.?, orbitedTrans.?, sdt );
    }
    else
    {
      def.log( .WARN, 0, @src(), "Failed to get all required components to tick orbit of entity #{d}", .{ id });
    }
  }
}

pub fn tickGlobalEconomy( transStore : *glb.TransStore, bodyStore : *glb.BodyStore, starPos : def.Vec2 ) void
{
  inline for( 1..glb.entityArray.len )| idx |
  {
    const id    = glb.entityArray[ idx ].id;
    const trans = transStore.get( id );
    const body  = bodyStore.get(  id );

    if( trans != null and body != null )
    {
      def.log( .TRACE, 0, @src(), "Updating economies of entity #{d}", .{ id });

      body.?.tickEcons( trans.?.pos.toVec2(), starPos );
    }
    else
    {
      def.log( .WARN, 0, @src(), "Failed to get all required components to tick economy of entity #{d}", .{ id });
    }
  }
}

pub fn renderOrbiters( transStore : *glb.TransStore, shapeStore : *glb.ShapeStore, orbitStore : *glb.OrbitStore, bodyStore : *glb.BodyStore ) void
{
  // Rendering bodies' orbits and debug info
  for( 1..glb.entityArray.len )| idx |
  {
    const id = glb.entityArray[ idx ].id;

    def.log( .TRACE, 0, @src(), "Rendering path & dbg info of entity #{d} at idx #{d}", .{ id, idx });

    const orbiter = orbitStore.get( id );

    if( orbiter == null ){ continue; }

    const orbiterBody  = bodyStore.get(  id );
    const orbiterTrans = transStore.get( id );

    const orbitedTrans = transStore.get( orbiter.?.orbitedID );

    if( orbiterTrans != null and orbitedTrans != null and orbiterBody != null )
    {

      orbiter.?.renderPath( orbitedTrans.?.pos.toVec2() );

      if( glb.targetId == id )
      {
        orbiter.?.renderDebug( orbiterTrans.?.pos.toVec2(), orbiterBody.?.radius, 1.0 );
        orbiter.?.renderLPs(   orbitedTrans.?.pos.toVec2(), orbiterBody.?.bodyType.getLPCount() );
      }

    }
    else
    {
      def.log( .WARN, 0, @src(), "Failed to get all required components to render orbital path of entity #{d}", .{ id });
    }
  }

  // Rendering bodies
  for( 0..glb.entityArray.len )| idx |
  {
    const id = glb.entityArray[ idx ].id;

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

pub fn drawTargetInfo( transStore : *glb.TransStore, shapeStore : *glb.ShapeStore, orbitStore : *glb.OrbitStore, bodyStore : *glb.BodyStore ) void
{
  const col   = def.G_ST.Graphic_Metrics_Colour.?;
  const posX  = def.getScreenWidth() - 16.0;
  const id    = glb.targetId;

  if( id == 0 or id > glb.ENTITY_COUNT ){ return; }

  const trans = transStore.get( id );
  const shape = shapeStore.get( id );

  const orbit = if( id != glb.starId ) orbitStore.get( id ) else null;
  const body  = if( id != glb.starId ) bodyStore.get(  id ) else null;


  var lineCount : f32 = 1.0;

  def.drawTextRightFmt( "== Entity #{d} ==", .{ id }, posX, lineCount * 32.0, 24, col ); lineCount += 1.5;


  if( trans != null )
  {
    def.drawTextRightFmt( "{d:.3} :     posX", .{ trans.?.pos.x }, posX, lineCount * 32.0, 24, col ); lineCount += 1.0;
    def.drawTextRightFmt( "{d:.3} :     posY", .{ trans.?.pos.y }, posX, lineCount * 32.0, 24, col ); lineCount += 1.0;

    lineCount += 0.5;
  }

  if( shape != null )
  {
    def.drawTextRightFmt( "{d:.3} :  scaleX", .{ shape.?.scale.x }, posX, lineCount * 32.0, 24, col ); lineCount += 1.0;
    def.drawTextRightFmt( "{d:.3} :  scaleY", .{ shape.?.scale.y }, posX, lineCount * 32.0, 24, col ); lineCount += 1.0;

    lineCount += 0.5;
  }

  if( glb.targetId == glb.starId ) // SUN
  {
    const star = glb.starCompInst;

    def.drawTextRightFmt( "{d:.3} :     mass", .{ star.mass         }, posX, lineCount * 32.0, 24, col ); lineCount += 1.0;
    def.drawTextRightFmt( "{d:.3} :  radius",  .{ star.radius       }, posX, lineCount * 32.0, 24, col ); lineCount += 1.0;
    def.drawTextRightFmt( "{d:.3} : density",  .{ star.getDensity() }, posX, lineCount * 32.0, 24, col ); lineCount += 1.0;
    def.drawTextRightFmt( "{d:.3} :    shine", .{ star.shine        }, posX, lineCount * 32.0, 24, col ); lineCount += 1.0;

    lineCount += 0.5;
  }
  else if( body != null ) // PLANETS AND CO.
  {
    def.drawTextRightFmt( "{d:.3} :     mass", .{ body.?.mass         }, posX, lineCount * 32.0, 24, col ); lineCount += 1.0;
    def.drawTextRightFmt( "{d:.3} :  radius",  .{ body.?.radius       }, posX, lineCount * 32.0, 24, col ); lineCount += 1.0;
    def.drawTextRightFmt( "{d:.3} : density",  .{ body.?.getDensity() }, posX, lineCount * 32.0, 24, col ); lineCount += 1.0;

    lineCount += 0.5;
  }

  if( orbit != null )
  {
    def.drawTextRightFmt( "{d:.3} :      minR", .{ orbit.?.minRadius }, posX, lineCount * 32.0, 24, col ); lineCount += 1.0;
    def.drawTextRightFmt( "{d:.3} :     maxR",  .{ orbit.?.maxRadius }, posX, lineCount * 32.0, 24, col ); lineCount += 1.0;

    lineCount += 0.5;
  }
}