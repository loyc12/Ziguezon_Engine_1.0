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
    def.qlog( .ERROR, 0, @src(), "Failed to register transStore" );
  }
  if( !ng.componentRegistry.register( "shapeStore", &glb.transStore ))
  {
    def.qlog( .ERROR, 0, @src(), "Failed to register shapeStore" );
  }
  if( !ng.componentRegistry.register( "spriteStore", &glb.spriteStore ))
  {
    def.qlog( .ERROR, 0, @src(), "Failed to register spriteStore" );
  }

  // Initializing test entities
  glb.entityArray[ 0 ] = ng.entityIdRegistry.getNewEntity();
  glb.entityArray[ 1 ] = ng.entityIdRegistry.getNewEntity();
  glb.entityArray[ 2 ] = ng.entityIdRegistry.getNewEntity();

  // Adding base components to test orbiters
  for( 0..glb.entityArray.len ) | i |
  {
    _ = glb.transStore.add(  glb.entityArray[i].id, .{ .pos = .{} });
    _ = glb.orbitStore.add(  glb.entityArray[i].id, .{ .mass = 32 });
    _ = glb.shapeStore.add(  glb.entityArray[i].id, .{ .colour = .nWhite, .scale = def.Vec2.new( 32, 32 ), .shape = .ELLI });
  //_ = glb.spriteStore.add( glb.entityArray[i].id, .{} );
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





