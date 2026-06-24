const std     = @import( "std"              );
const eng     = @import( "engine"           );
const utl     = @import( "utils"            );
const harvest = @import( "harvestFacts.zig" );
const station = @import( "stationFacts.zig" );

// ================================ STATE INJECTION FUNCTIONS ================================
// These functions are called by the engine whenever it changes state ( see changeState() in engine.zig )

pub fn OnGameStart( ng : *eng.Engine ) void // Called by engine.start()
{
  // Initialize shared resources for world-feature demos here.
  _ = ng;
}
pub fn OnGameStop( ng : *eng.Engine ) void // Called by engine.stop()
{
  _ = ng;
}


pub fn OnGameOpen( ng : *eng.Engine ) void // Called by engine.open()
{
  if( !station.registerStationStores( ng ))
  {
    utl.qlog( .ERROR, @src(), "Drifter station fact stores are unavailable" );
    return;
  }
  if( !harvest.registerHarvestStores( ng ))
  {
    station.unregisterStationStores( ng );

    utl.qlog( .ERROR, @src(), "Drifter harvest fact stores are unavailable" );
    return;
  }

  if( !station.resetStation( ng ))
  {
    utl.qlog( .ERROR, @src(), "Drifter station setup failed" );
    return;
  }

  if( !harvest.resetHarvestFacts( ng ))
  {
    utl.qlog( .ERROR, @src(), "Drifter harvest setup failed" );
  }
}
pub fn OnGameClose( ng : *eng.Engine ) void // Called by engine.close()
{
  harvest.unregisterHarvestStores( ng );
  station.unregisterStationStores( ng );
}


pub fn OnGameResume( ng : *eng.Engine ) void // Called by engine.play()
{
  _ = ng;
}
pub fn OnGamePause( ng : *eng.Engine ) void // Called by engine.pause()
{
  _ = ng;
}

