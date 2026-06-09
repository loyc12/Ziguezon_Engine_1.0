const std = @import( "std"  );
const eng = @import( "engine" );

const gbl = @import( "gameGlobals.zig" );
const gdf = @import( "gameDef.zig"    );
const gUtl = @import( "gameUtils.zig"   );


// ================================ STATE INJECTION FUNCTIONS ================================
// These functions are called by the engine whenever it changes state ( see changeState() in engine.zig )

pub fn OnGameStart( ng : *eng.Engine ) void // Called by engine.start()    // NOTE : This is where you should initialize your resources
{
  _ = ng; // Prevent unused variable warning

  gbl.loadStaticDataMatrices();
}
pub fn OnGameStop( ng : *eng.Engine ) void // Called by engine.stop()
{
  _ = ng; // Prevent unused variable warning
}


pub fn OnGameOpen( ng : *eng.Engine ) void // Called by engine.open()      // NOTE : This is where you should initialize your entities
{
  // Initializing and registering all component stores
  if( !gbl.registerOrbiterStores( ng )){ return; }

  // Initializing individual components components
  gUtl.initStellarSystem( ng );
}

pub fn OnGameClose( ng : *eng.Engine ) void // Called by engine.close()
{
  gbl.unregisterOrbiterStores( ng );
}


pub fn OnGameResume( ng : *eng.Engine ) void // Called by engine.play()
{
  _ = ng; // Prevent unused variable warning
}
pub fn OnGamePause( ng : *eng.Engine ) void // Called by engine.pause()
{
  _ = ng; // Prevent unused variable warning
}


