const std = @import( "std" );
const def = @import( "defs" );


// ================================ INITIALIZATION ================================
const gh = @import( "gameHooks" );

pub fn initCriticals() void
{
  def.qlog( .INFO, 0, @src(), "# Initializing all subsystems..." );

  def.initAllUtils( def.alloc );

  // Initialize the game hooks
  def.initHooks( gh );

  def.qlog( .INFO, 0, @src(), "$ Initialized all subsystems !\n" );
}

pub fn deinitCriticals() void
{
  def.qlog( .INFO, 0, @src(), "# Deinitializing all subsystems..." );

  def.deinitAllUtils();

  def.qlog( .INFO, 0, @src(), "$ Deinitialized all subsystems\n" );
}

// ================================ MAIN FUNCTION ================================
// This is the entry point of the application

pub fn main() !void
{
  initCriticals();
  defer deinitCriticals();

  def.G_NG.changeState( .OPENED );

  def.G_NG.loopLogic();

  def.G_NG.changeState( .OFF );
}

test "example test"
{

}
