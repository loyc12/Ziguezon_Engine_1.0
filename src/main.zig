const std = @import( "std" );
const def = @import( "defs" );


// ================================ INITIALIZATION ================================
const ngi = @import( "engineInterface" );

pub fn initCriticals() void
{
  def.GLOBAL_EPOCH = def.getNow();

  def.qlog( .TRACE, 0, @src(), "# Initializing all subsystems..." );

  def.initAllUtils( def.getAlloc() );

  def.loadHooks(    ngi );
  def.loadSettings( ngi );

  def.G_NG.setTargetTickRate(  def.G_ST.Startup_Target_TickRate );
  def.G_NG.setTargetFrameRate( def.G_ST.Startup_Target_FrameRate );
  def.G_NG.simTimeUpdate();

  def.qlog( .INFO, 0, @src(), "$ Initialized all subsystems !\n" );
}

pub fn deinitCriticals() void
{
  def.qlog( .TRACE, 0, @src(), "# Deinitializing all subsystems..." );

  def.deinitAllUtils();

  def.qlog( .INFO, 0, @src(), "$ Deinitialized all subsystems !\n" );
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
