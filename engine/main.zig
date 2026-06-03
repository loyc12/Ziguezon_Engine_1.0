const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );


// ================================ INITIALIZATION ================================
const ngi = @import( "engineInterface" );

pub fn initCriticals() void
{
  eng.GLOBAL_EPOCH = utl.getNow();

  utl.qlog( .TRACE, 0, @src(), "# Initializing all subsystems..." );

  eng.initAllUtils( eng.getAlloc() );

  eng.loadHooks(    ngi );
  eng.loadSettings( ngi );

  eng.G_NG.times.init();

  utl.qlog( .INFO, 0, @src(), "$ Initialized all subsystems !\n" );
}

pub fn deinitCriticals() void
{
  utl.qlog( .TRACE, 0, @src(), "# Deinitializing all subsystems..." );

  eng.deinitAllUtils();

  utl.qlog( .INFO, 0, @src(), "$ Deinitialized all subsystems !\n" );
}

// ================================ MAIN FUNCTION ================================
// This is the entry point of the application

pub fn main() !void
{
  initCriticals();
  defer deinitCriticals();

  eng.G_NG.changeState( .OPENED );

  if( eng.G_ST.AutoApply_State_Playing ){ eng.G_NG.changeState( .PLAYING ); }

  eng.G_NG.loopLogic();

  eng.G_NG.changeState( .OFF );
}

test "example test"
{

}
