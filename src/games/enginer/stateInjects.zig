const std = @import( "std"    );
const eng = @import( "engine" );

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
  // Initialize demo worlds, entities, stores, and rules here.
  _ = ng;
}
pub fn OnGameClose( ng : *eng.Engine ) void // Called by engine.close()
{
  _ = ng;
}


pub fn OnGameResume( ng : *eng.Engine ) void // Called by engine.play()
{
  _ = ng;
}
pub fn OnGamePause( ng : *eng.Engine ) void // Called by engine.pause()
{
  _ = ng;
}




