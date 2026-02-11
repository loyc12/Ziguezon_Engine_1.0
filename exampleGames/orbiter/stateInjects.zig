const std = @import( "std" );
const def = @import( "defs" );

const glb = @import( "gameGlobals.zig" );
const utl = @import( "gameUtils.zig" );


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
  glb.orbitStore.init(  alloc );
  glb.shapeStore.init(  alloc );
  glb.spriteStore.init( alloc );

  // Registering base componentStores
  if( !ng.componentRegistry.register( "transStore", &glb.transStore ))
  {
    def.qlog( .ERROR, 0, @src(), "Failed to register transStore" );
  }
  if( !ng.componentRegistry.register( "orbitStore", &glb.orbitStore ))
  {
    def.qlog( .ERROR, 0, @src(), "Failed to register orbitStore" );
  }
  if( !ng.componentRegistry.register( "shapeStore", &glb.shapeStore ))
  {
    def.qlog( .ERROR, 0, @src(), "Failed to register shapeStore" );
  }
  if( !ng.componentRegistry.register( "spriteStore", &glb.spriteStore ))
  {
    def.qlog( .ERROR, 0, @src(), "Failed to register spriteStore" );
  }

  for( 0..glb.entityCount )| idx |
  {
    glb.entityArray[ idx ] = ng.entityIdRegistry.getNewEntity();

    const id = glb.entityArray[ idx ].id;

    def.log( .INFO, 0, @src(), "Initializing components of entity #{}", .{ id });

    if( id == 1 ) // Here comes the sun, lalalala
    {
      _ = glb.transStore.add(  id, .{ .pos = .{} });
      _ = glb.shapeStore.add(  id, .{ .colour = .yellow, .scale = .new( 64, 64 ), .shape = .ELLI });
    //_ = glb.spriteStore.add( id, .{} );
    }
    else // Planetoids
    {
      const place : f32 = @floatFromInt( id - 2 );
      const factor = place / ( glb.entityCount - 1 );

      const minMin = 200.0;
      const maxMin = 300.0;

      const minMax = 300.0;
      const maxMax = 900.0;

      const orbitComp = glb.orb.OrbitComp
      {
        .orbitedMass = 100_000_000.0,
        .minRadius   = def.lerp( minMin, maxMin, factor ),
        .maxRadius   = def.lerp( minMax, maxMax, factor ),
        .orientation = def.TAU * factor,
      };
      const startPos = orbitComp.getAbsPos( .{} ); // Get initial position from orbit

      _ = glb.transStore.add(  id,
      .{
        .pos = .new( startPos.x, startPos.y, .{} ),
      });
      _ = glb.orbitStore.add(  id, orbitComp );
      _ = glb.shapeStore.add(  id, .{ .colour = .nWhite, .scale = .new( 16, 16 ), .shape = .ELLI });
    //_ = glb.spriteStore.add( id, .{} );
    }
  }
}

pub fn OnClose( ng : *def.Engine ) void // Called by engine.close()
{
  _ = ng; // Prevent unused variable warning

  glb.transStore.deinit();
  glb.shapeStore.deinit();
  glb.orbitStore.deinit();
  glb.spriteStore.deinit();
}


pub fn OnPlay( ng : *def.Engine ) void // Called by engine.play()
{
  _ = ng; // Prevent unused variable warning
}
pub fn OnPause( ng : *def.Engine ) void // Called by engine.pause()
{
  _ = ng; // Prevent unused variable warning
}





