const std = @import( "std" );
const eng = @import( "engine" );

// ================================ STATE INJECTION FUNCTIONS ================================
// These functions are called by the engine whenever it changes state ( see changeState() in engine.zig )

pub fn OnStart( ng : *eng.Engine ) void // Called by engine.start()    // NOTE : This is where you should initialize your resources
{
  _ = ng; // Prevent unused variable warning
}
pub fn OnStop( ng : *eng.Engine ) void // Called by engine.stop()
{
  _ = ng; // Prevent unused variable warning
}


pub fn OnOpen( ng : *eng.Engine ) void // Called by engine.open()      // NOTE : This is where you should initialize your entities
{
  _ = ng; // Prevent unused variable warning
}
pub fn OnClose( ng : *eng.Engine ) void // Called by engine.close()
{
  _ = ng; // Prevent unused variable warning
}


pub fn OnPlay( ng : *eng.Engine ) void // Called by engine.play()
{
  _ = ng; // Prevent unused variable warning
}
pub fn OnPause( ng : *eng.Engine ) void // Called by engine.pause()
{
  _ = ng; // Prevent unused variable warning
}





