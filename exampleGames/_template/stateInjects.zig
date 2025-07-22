const std = @import( "std" );
const def = @import( "defs" );

// ================================ STATE INJECTION FUNCTIONS ================================
// These functions are called by the engine whenever it changes state ( see changeState() in engine.zig )

pub fn OnStart( ng : *def.eng.engine ) void // Called by engine.start()
{
  _ = ng; // Prevent unused variable warning
}

// NOTE : This is where you should initialize your entities
pub fn OnLaunch( ng : *def.eng.engine ) void // Called by engine.launch()
{
  _ = ng; // Prevent unused variable warning
}

pub fn OnPlay( ng : *def.eng.engine ) void // Called by engine.play()
{
  _ = ng; // Prevent unused variable warning
}



pub fn OnPause( ng : *def.eng.engine ) void // Called by engine.pause()
{
  _ = ng; // Prevent unused variable warning
}

pub fn OnStop( ng : *def.eng.engine ) void // Called by engine.stop()
{
  _ = ng; // Prevent unused variable warning
}

pub fn OnClose( ng : *def.eng.engine ) void // Called by engine.close()
{
  _ = ng; // Prevent unused variable warning
}

