const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );


// ================================ INITIALIZATION / DEINITIALIZATION ================================

const ngi = @import( "interface" );

pub fn initCriticals() void
{
//const alloc = utl.getDefaultAlloc();
//
//std.debug.print( "allocator.ptr    = {}\n", .{ alloc.ptr    });
//std.debug.print( "allocater.vtable = {}\n", .{ alloc.vtable });

  utl.qlog( .TRACE, @src(), "# Initializing all subsystems..." );

  utl.G_EPOCH = utl.getNow();
  eng.G_ENG.rng.randInit();

  utl.initAllUtils();

  eng.loadConfigs( ngi );
  eng.loadHooks(   ngi );

  eng.G_ENG.initTimers();

  utl.qlog( .INFO, @src(), "$ Initialized all subsystems !\n" );
}

pub fn deinitCriticals() void
{
  utl.qlog( .TRACE, @src(), "# Deinitializing all subsystems..." );

  utl.deinitAllUtils();

  utl.qlog( .INFO, @src(), "$ Deinitialized all subsystems !\n" );
}


pub fn main() !void
{
  initCriticals();
  defer deinitCriticals();

  eng.G_ENG.changeState( .OPENED );

  if( eng.G_CNFGS.AutoApply_State_Playing ){ eng.G_ENG.changeState( .PLAYING ); }

  // NOTE : this loop should eventually be multithreaded / forked out
  eng.G_ENG.stepEngineLoop();

  eng.G_ENG.changeState( .OFF );
}
