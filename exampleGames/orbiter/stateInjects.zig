const std = @import( "std" );
const def = @import( "defs" );

const glb = @import( "gameGlobals.zig" );
const utl = @import( "gameUtils.zig" );


const STAR_MASS   = 100_000_000.0;
const PLANET_MASS =   1_000_000.0;
const MOON_MASS   =      10_000.0;
const COMET_MASS  =         100.0;

const STAR_RADIUS   = 256.0;
const PLANET_RADIUS =  64.0;
const MOON_RADIUS   =  16.0;
const COMET_RADIUS  =   4.0;


// ================================ STATE INJECTION FUNCTIONS ================================
// These functions are called by the engine whenever it changes state ( see changeState() in engine.zig )

pub fn OnStart( ng : *def.Engine ) void // Called by engine.start()    // NOTE : This is where you should initialize your resources
{
  _ = ng; // Prevent unused variable warning
}
pub fn OnStop( ng : *def.Engine ) void // Called by engine.stop()
{
  _ = ng; // Prevent unused variable warning
}


pub fn OnOpen( ng : *def.Engine ) void // Called by engine.open()      // NOTE : This is where you should initialize your entities
{
  const alloc = def.getAlloc();

  glb.transStore.init(  alloc );
  glb.shapeStore.init(  alloc );
  glb.spriteStore.init( alloc );

  glb.orbitStore.init(  alloc );
  glb.bodyStore.init(   alloc );

  // Registering componentStores
  if( !ng.componentRegistry.register( "transStore", &glb.transStore ))
  {
    def.qlog( .ERROR, 0, @src(), "Failed to register transStore" );
  }
  if( !ng.componentRegistry.register( "shapeStore", &glb.shapeStore ))
  {
    def.qlog( .ERROR, 0, @src(), "Failed to register shapeStore" );
  }
  if( !ng.componentRegistry.register( "spriteStore", &glb.spriteStore ))
  {
    def.qlog( .ERROR, 0, @src(), "Failed to register spriteStore" );
  }

  if( !ng.componentRegistry.register( "orbitStore", &glb.orbitStore ))
  {
    def.qlog( .ERROR, 0, @src(), "Failed to register orbitStore" );
  }
  if( !ng.componentRegistry.register( "bodyStore", &glb.bodyStore ))
  {
    def.qlog( .ERROR, 0, @src(), "Failed to register bodyStore" );
  }

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

pub fn OnClose( ng : *def.Engine ) void // Called by engine.close()
{
  _ = ng; // Prevent unused variable warning

  glb.transStore.deinit();
  glb.shapeStore.deinit();
  glb.spriteStore.deinit();

  glb.orbitStore.deinit();
  glb.bodyStore.deinit();
}


pub fn OnPlay( ng : *def.Engine ) void // Called by engine.play()
{
  _ = ng; // Prevent unused variable warning
}
pub fn OnPause( ng : *def.Engine ) void // Called by engine.pause()
{
  _ = ng; // Prevent unused variable warning
}





