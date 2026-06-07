const std = @import( "std" );
const eng = @import( "engine" );
const stepInj = @import( "stepInjects.zig" );

// ================================ STATE INJECTION FUNCTIONS ================================
// These functions are called by the engine whenever it changes state ( see changeState() in engine.zig )

pub fn OnGameStart( ng : *eng.Engine ) void // Called by engine.start()    // NOTE : This is where you should initialize your resources
{
  _ = ng; // Prevent unused variable warning
}
pub fn OnGameStop( ng : *eng.Engine ) void // Called by engine.stop()
{
  _ = ng; // Prevent unused variable warning
}


pub fn OnGameOpen( ng : *eng.Engine ) void // Called by engine.open()      // NOTE : This is where you should initialize your entities
{
  stepInj.buildUi( ng );
}
pub fn OnGameClose( ng : *eng.Engine ) void // Called by engine.close()
{
  _ = ng; // Prevent unused variable warning
}


pub fn OnGameResume( ng : *eng.Engine ) void // Called by engine.play()
{
  _ = ng; // Prevent unused variable warning
}
pub fn OnGamePause( ng : *eng.Engine ) void // Called by engine.pause()
{
  _ = ng; // Prevent unused variable warning
}




