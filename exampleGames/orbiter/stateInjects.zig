const std = @import( "std" );
const def = @import( "defs" );

const gbl = @import( "gameGlobals.zig" );
const utl = @import( "gameUtils.zig" );


// ================================ STATE INJECTION FUNCTIONS ================================
// These functions are called by the engine whenever it changes state ( see changeState() in engine.zig )

pub fn OnStart( ng : *def.Engine ) void // Called by engine.start()    // NOTE : This is where you should initialize your resources
{
  _ = ng; // Prevent unused variable warning

  gbl.loadAllData();
}
pub fn OnStop( ng : *def.Engine ) void // Called by engine.stop()
{
  _ = ng; // Prevent unused variable warning
}


pub fn OnOpen( ng : *def.Engine ) void // Called by engine.open()      // NOTE : This is where you should initialize your entities
{
  const alloc = def.getAlloc();

  gbl.transStore.init(  alloc );
  gbl.shapeStore.init(  alloc );
  gbl.spriteStore.init( alloc );

  gbl.orbitStore.init(  alloc );
  gbl.bodyStore.init(   alloc );

  // Registering componentStores
  if( !ng.componentRegistry.register( "transStore", &gbl.transStore ))
  {
    def.qlog( .ERROR, 0, @src(), "Failed to register transStore" );
  }
  if( !ng.componentRegistry.register( "shapeStore", &gbl.shapeStore ))
  {
    def.qlog( .ERROR, 0, @src(), "Failed to register shapeStore" );
  }
  if( !ng.componentRegistry.register( "spriteStore", &gbl.spriteStore ))
  {
    def.qlog( .ERROR, 0, @src(), "Failed to register spriteStore" );
  }

  if( !ng.componentRegistry.register( "orbitStore", &gbl.orbitStore ))
  {
    def.qlog( .ERROR, 0, @src(), "Failed to register orbitStore" );
  }
  if( !ng.componentRegistry.register( "bodyStore", &gbl.bodyStore ))
  {
    def.qlog( .ERROR, 0, @src(), "Failed to register bodyStore" );
  }

  // Setting up components
  utl.initStellarSystem( ng );
}

pub fn OnClose( ng : *def.Engine ) void // Called by engine.close()
{
  _ = ng; // Prevent unused variable warning

  gbl.transStore.deinit();
  gbl.shapeStore.deinit();
  gbl.spriteStore.deinit();

  gbl.orbitStore.deinit();
  gbl.bodyStore.deinit();
}


pub fn OnPlay( ng : *def.Engine ) void // Called by engine.play()
{
  _ = ng; // Prevent unused variable warning
}
pub fn OnPause( ng : *def.Engine ) void // Called by engine.pause()
{
  _ = ng; // Prevent unused variable warning
}





