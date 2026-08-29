const std = @import( "std" );
const eng = @import( "engine" );

// ================================ STATE INJECTION FUNCTIONS ================================
// // These hooks will be called by the engine at whenever it changes state ( see src/engine/core/engineState.zig )

pub fn OnGameStart( ng : *eng.Engine ) void // Called by engine.start()    // NOTE : This is where you should initialize your resources
{
  _ = ng; // Prevent unused variable warning
}

pub fn OnGameStop( ng : *eng.Engine ) void // Called by engine.stop()      // NOTE : This is where you should deinitialize your resources
{
  _ = ng; // Prevent unused variable warning
}


pub fn OnGameOpen( ng : *eng.Engine ) void // Called by engine.open()      // NOTE : This is where you should initialize your data
{
  _ = ng; // Prevent unused variable warning
}

pub fn OnGameClose( ng : *eng.Engine ) void // Called by engine.close()    // NOTE : This is where you should initialize your data
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





