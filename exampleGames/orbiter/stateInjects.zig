const std = @import( "std"  );
const def = @import( "defs" );

const gbl = @import( "gameGlobals.zig" );
const gdf = @import( "gameDefs.zig"    );
const utl = @import( "gameUtils.zig"   );


// ================================ STATE INJECTION FUNCTIONS ================================
// These functions are called by the engine whenever it changes state ( see changeState() in engine.zig )

pub fn OnStart( ng : *def.Engine ) void // Called by engine.start()    // NOTE : This is where you should initialize your resources
{
  _ = ng; // Prevent unused variable warning

  gbl.loadStaticDataMatrices();
}
pub fn OnStop( ng : *def.Engine ) void // Called by engine.stop()
{
  _ = ng; // Prevent unused variable warning
}


pub fn OnOpen( ng : *def.Engine ) void // Called by engine.open()      // NOTE : This is where you should initialize your entities
{
  // Initializing and registering all component stores
  _ = gbl.G_DATA.stores.registerAllStores( ng );

  // Initializing individual components components
  utl.initStellarSystem( ng );
}

pub fn OnClose( ng : *def.Engine ) void // Called by engine.close()
{
  _ = ng; // Prevent unused variable warning

  gbl.G_DATA.stores.deinitAllStores();
}


pub fn OnPlay( ng : *def.Engine ) void // Called by engine.play()
{
  _ = ng; // Prevent unused variable warning
}
pub fn OnPause( ng : *def.Engine ) void // Called by engine.pause()
{
  _ = ng; // Prevent unused variable warning
}





