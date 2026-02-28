const std = @import( "std" );
const def = @import( "defs" );

const glb = @import( "gameGlobals.zig" );
const orb = @import( "comp/orbitComp.zig" );
const ecn = @import( "comp/economy.zig" );



// ================================ STATE INJECT ================================

pub fn initDebugSystem( ng : *def.Engine ) void
{
  const STAR_MASS   = 10_000_000.0;
  const PLANET_MASS =    310_000.0;
  const MOON_MASS   =      1_000.0;
  const COMET_MASS  =         31.0;

  // Setting up relevant components
  for( 0..glb.entityCount )| idx |
  {
    glb.entityArray[ idx ] = ng.entityIdRegistry.getNewEntity();

    const id = glb.entityArray[ idx ].id;

    def.log( .INFO, 0, @src(), "Initializing components of entity #{} at idx #{}", .{ id, idx });


    if( id == 1 ) // Here comes the sun, lalalala
    {

      glb.starCompInst.shine  = 1.0;         // TODO : adjust to proper shunshine amount
      glb.starCompInst.mass   = STAR_MASS;

      glb.starCompInst.setRadiusViaDensity( 0.1 );
      glb.starCompInst.setShineAtDist( 1.0, 2500 ); // making sure sunshine strenght is 1 around main planet

      const r = glb.starCompInst.radius;

      _ = glb.transStore.add(  id, .{ .pos = .{} });
      _ = glb.shapeStore.add(  id, .{ .colour = .yellow, .scale = .new( r, r ), .shape = .ELLI });
    //_ = glb.spriteStore.add( id, .{} );

      continue;
    }


    // Non-sun component instanciation

    const place : f32 = @floatFromInt( id - 2 );
    const factor = place / ( glb.entityCount - 1 );

    var orbitComp : glb.orb.OrbitComp = // Rotating orbital ellipses for fun
    .{
      .orientation = def.TAU * factor,
      .retrograde  = ( 0 == id % 2 ),
    };

    var bodyComp   : glb.bdy.BodyComp = .{ .bodyType = .PLANET };

    switch( id ) // Adjusting bodyType-specific orbitComp and bodyComp variables
    {
      2 =>
      {
        orbitComp.orbitedMass = STAR_MASS;
        orbitComp.orbiterMass = PLANET_MASS;
        orbitComp.minRadius   = 2500 - 50;
        orbitComp.maxRadius   = 2500 + 50;

        bodyComp.bodyType = .PLANET;
        bodyComp.mass     = PLANET_MASS;

        bodyComp.initEcon( .GROUND );
      //bodyComp.initEcon( .ORBIT  );
      //bodyComp.initEcon( .L1     );
      //bodyComp.initEcon( .L2     );
      //bodyComp.initEcon( .L3     );
      //bodyComp.initEcon( .L4     );
      //bodyComp.initEcon( .L5     );

        bodyComp.debugSetEconVals( 1 );
      },

      3 =>
      {
        orbitComp.orbitedMass = PLANET_MASS;
        orbitComp.orbiterMass = MOON_MASS;
        orbitComp.minRadius   = 300 - 20;
        orbitComp.maxRadius   = 300 + 20;

        bodyComp.bodyType = .MOON;
        bodyComp.mass     = MOON_MASS;

      //bodyComp.initEcon( .GROUND );
      //bodyComp.initEcon( .ORBIT  );
      //bodyComp.initEcon( .L1     );
      //bodyComp.initEcon( .L2     );
      //bodyComp.initEcon( .L3     );
      },

      4 =>
      {
        orbitComp.orbitedMass = MOON_MASS;
        orbitComp.orbiterMass = COMET_MASS;
        orbitComp.minRadius   = 20 - 2;
        orbitComp.maxRadius   = 20 + 2;

        bodyComp.bodyType  = .COMET;
        bodyComp.mass      = COMET_MASS;

      //bodyComp.initEcon( .GROUND );
      //bodyComp.initEcon( .ORBIT  );
      },

      else =>
      {
        orbitComp.orbitedMass = COMET_MASS;
        orbitComp.orbiterMass = COMET_MASS;
        orbitComp.minRadius   = 10 - 3;
        orbitComp.maxRadius   = 10 + 3;

        bodyComp.bodyType = .COMET;
        bodyComp.mass     = COMET_MASS;
      },
    }
    bodyComp.setRadiusViaDensity( 1.0 );


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
  if( def.ray.isKeyDown( def.ray.KeyboardKey.w ) or def.ray.isKeyDown( def.ray.KeyboardKey.up    )){ cam.moveByS( def.Vec2.new(  0, -8 )); }
  if( def.ray.isKeyDown( def.ray.KeyboardKey.s ) or def.ray.isKeyDown( def.ray.KeyboardKey.down  )){ cam.moveByS( def.Vec2.new(  0,  8 )); }
  if( def.ray.isKeyDown( def.ray.KeyboardKey.a ) or def.ray.isKeyDown( def.ray.KeyboardKey.left  )){ cam.moveByS( def.Vec2.new( -8,  0 )); }
  if( def.ray.isKeyDown( def.ray.KeyboardKey.d ) or def.ray.isKeyDown( def.ray.KeyboardKey.right )){ cam.moveByS( def.Vec2.new(  8,  0 )); }

  // Zoom in and out with the mouse wheel
  if( def.ray.getMouseWheelMove() > 0.0 ){ cam.zoomBy( 1.1 ); }
  if( def.ray.getMouseWheelMove() < 0.0 ){ cam.zoomBy( 0.9 ); }

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
    const orbitedTrans = transStore.get( glb.entityArray[ idx - 1 ].id );

    if( orbiterTrans != null and orbitedTrans != null )
    {
      def.log( .TRACE, 0, @src(), "Updating orbit of entity #{d}", .{ id });
      orbiter.?.updateOrbit( orbiterTrans.?, orbitedTrans.?, sdt );
    }
    else
    {
      def.log( .WARN, 0, @src(), "Failed to get all required components to tick orbit of entity #{d}", .{ id });
    }

    // NOTE : No need to update transComps for orbiters
  }
}

pub fn tickGlobalEconomy( transStore : *glb.TransStore, orbitStore : *glb.OrbitStore, bodyStore : *glb.BodyStore, starPos : def.Vec2 ) void
{
  inline for( 1..glb.entityArray.len )| idx |
  {
    const id    = glb.entityArray[ idx ].id;
    const body  = bodyStore.get(  id );
    const orbit = orbitStore.get( id );
    const trans = transStore.get( glb.entityArray[ idx - 1 ].id ); // Orbited position

    if( trans != null and orbit != null and body != null )
    {
      def.log( .TRACE, 0, @src(), "Updating economies of entity #{d}", .{ id });

      body.?.tickEcons( orbit.?, trans.?.pos.toVec2(), starPos );
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
      def.log( .WARN, 0, @src(), "Failed to get all required components to render orbital path of entity #{d}", .{ id });
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
      def.log( .WARN, 0, @src(), "Failed to get all required components to render shape of entity #{d}", .{ id });
    }
  }
}

pub fn drawTargetInfo( transStore : *glb.TransStore, shapeStore : *glb.ShapeStore, orbitStore : *glb.OrbitStore, bodyStore : *glb.BodyStore ) void
{
  const col   = def.G_ST.Graphic_Metrics_Colour.?;
  const posX  = def.getScreenWidth() - 16.0;
  const id    = glb.targetId;

  var lineCount : f32 = 1.0;

  def.drawTextRightFmt( "== Entity #{d} ==", .{ id }, posX, lineCount * 32.0, 24, col ); lineCount += 1.5;

  if( id == 0 or id > glb.entityCount ){ return; }


  const trans = transStore.get( id );
  const shape = shapeStore.get( id );

  const orbit = if( id != 1 ) orbitStore.get( id ) else null;
  const body  = if( id != 1 ) bodyStore.get(  id ) else null;


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

  if( glb.targetId == 1 ) // SUN
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