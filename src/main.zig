const std = @import( "std" );
const h   = @import( "defs" );


// ================================ INITIALIZATION ================================
const gh = @import( "gameHooks" );

pub fn initAll() void
{
  // Initialize the game hooks
  h.initHooks( gh );

  // Initialize the timer
  h.timer.initTimer();

  // Initialize the log file if needed
  h.logger.initFile();

  h.qlog( .INFO, 0, @src(), "Initialized all subsystems" );
}

pub fn deinitAll() void
{
  h.qlog( .INFO, 0, @src(), "Deinitializing all subsystems" );

  // Deinitialize the log file if present
  h.logger.deinitFile();
}


// ================================ MAIN FUNCTION ================================
// This is the entry point of the application

pub fn main() !void
{
  initAll();
  defer deinitAll();

  h.G_NG.changeState( .LAUNCHED );

  h.G_NG.loopLogic();

  h.G_NG.changeState( .CLOSED );
}

test "example test"
{
  h.misc.testTryCall();
}
