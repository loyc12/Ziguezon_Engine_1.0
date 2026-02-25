const std = @import( "std" );
const def = @import( "defs" );

const glb = @import( "gameGlobals.zig" );
const orb = @import( "comp/orbitComp.zig" );


// ================================ STATE INJECT ================================

pub fn initDebugSystem( ng : *def.Engine ) void
{
  const STAR_MASS   = 100_000_000.0;
  const PLANET_MASS =   1_000_000.0;
  const MOON_MASS   =      10_000.0;
  const COMET_MASS  =         100.0;

  const STAR_RADIUS   = 256.0;
  const PLANET_RADIUS =  64.0;
  const MOON_RADIUS   =  16.0;
  const COMET_RADIUS  =   4.0;

  // Setting up relevant components
  for( 0..glb.entityCount )| idx |
  {
    glb.entityArray[ idx ] = ng.entityIdRegistry.getNewEntity();

    const id = glb.entityArray[ idx ].id;

    def.log( .INFO, 0, @src(), "Initializing components of entity #{} at idx #{}", .{ id, idx });


    var shapeScale : def.Vec2 = .new( STAR_RADIUS, STAR_RADIUS );

    if( id == 1 ) // Here comes the sun, lalalala
    {
      _ = glb.transStore.add(  id, .{ .pos = .{} });
      _ = glb.shapeStore.add(  id, .{ .colour = .yellow, .scale = shapeScale, .shape = .ELLI });
    //_ = glb.spriteStore.add( id, .{} );

      glb.starCompInst.radius = STAR_RADIUS;
      glb.starCompInst.mass   = STAR_MASS;
      glb.starCompInst.shine  = 1.0;         // TODO : adjust to proper shunshine amount

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

    var bodyComp : glb.bdy.BodyComp = .{ .bodyType = .PLANET };


    switch( id ) // Adjusting bodyType-specific orbitComp and bodyComp variables
    {
      2 =>
      {
        orbitComp.orbitedMass = STAR_MASS;
        orbitComp.orbiterMass = PLANET_MASS;
        orbitComp.minRadius   = 2500 - 50;
        orbitComp.maxRadius   = 2500 + 50;

        bodyComp.bodyType     = .PLANET;
        bodyComp.radius       = PLANET_RADIUS;
        bodyComp.mass         = PLANET_MASS;

        shapeScale = .new( PLANET_RADIUS, PLANET_RADIUS);
      },

      3 =>
      {
        orbitComp.orbitedMass = PLANET_MASS;
        orbitComp.orbiterMass = MOON_MASS;
        orbitComp.minRadius   = 300 - 20;
        orbitComp.maxRadius   = 300 + 20;

        bodyComp.bodyType     = .MOON;
        bodyComp.radius       = MOON_RADIUS;
        bodyComp.mass         = MOON_MASS;

        shapeScale = .new( MOON_RADIUS, MOON_RADIUS );
      },

      4 =>
      {
        orbitComp.orbitedMass = MOON_MASS;
        orbitComp.orbiterMass = COMET_MASS;
        orbitComp.minRadius   = 40 - 1;
        orbitComp.maxRadius   = 40 + 1;

        bodyComp.bodyType     = .COMET;
        bodyComp.radius       = COMET_RADIUS;
        bodyComp.mass         = COMET_MASS;

        shapeScale = .new( COMET_RADIUS, COMET_RADIUS );
      },

      else =>
      {
        orbitComp.orbitedMass = COMET_MASS;
        orbitComp.orbiterMass = COMET_MASS;
        orbitComp.minRadius   = 20 - 2;
        orbitComp.maxRadius   = 20 + 2;

        bodyComp.bodyType     = .COMET;
        bodyComp.radius       = COMET_RADIUS;
        bodyComp.mass         = COMET_MASS;

        shapeScale = .new( COMET_RADIUS, COMET_RADIUS );
      },
    }

    const startPos = orbitComp.getAbsPos( .{} ); // Get initial position from orbit

    _ = glb.transStore.add(  id, .{ .pos = .new( startPos.x, startPos.y, .{} )});
    _ = glb.shapeStore.add(  id, .{ .colour = .nWhite, .scale = shapeScale, .shape = .ELLI });
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

pub fn renderOrbiters( transStore : *glb.TransStore, shapeStore : *glb.ShapeStore, orbitStore : *glb.OrbitStore, bodyStore : *glb.BodyStore ) void // Called by engine.renderGraphics()
{
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