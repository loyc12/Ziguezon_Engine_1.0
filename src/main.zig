const std = @import( "std" );
const def = @import( "defs" );


// ================================ INITIALIZATION ================================
const gh = @import( "gameHooks" );

pub fn initAll() void
{
  def.qlog( .INFO, 0, @src(), "# Initializing all subsystems..." );

  // Initialize the timer
  def.logger.initLogTimer();

  // Initialize the game hooks
  def.initHooks( gh );

  // Initialize the log file if needed
  def.logger.initFile();

  def.qlog( .INFO, 0, @src(), "$ Initialized all subsystems !\n" );
}

pub fn deinitAll() void
{
  def.qlog( .INFO, 0, @src(), "# Deinitializing all subsystems..." );

  // Deinitialize the log file if present
  def.logger.deinitFile();

  def.qlog( .INFO, 0, @src(), "$ Deinitialized all subsystems\n" );
}

// ================================ MAIN FUNCTION ================================
// This is the entry point of the application

pub fn main() !void
{
  initAll();
  defer deinitAll();

  def.G_NG.changeState( .LAUNCHED );

  def.G_NG.loopLogic();

  def.G_NG.changeState( .CLOSED );
}

test "example test"
{
  def.misc.testTryCall();
}
