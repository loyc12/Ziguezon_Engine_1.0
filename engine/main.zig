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

  utl.qlog( .TRACE, 0, @src(), "# Initializing all subsystems..." );

  utl.G_EPOCH = utl.getNow();
  eng.G_ENG.rng.randInit();
  eng.G_ENG.initTimers();

  utl.initAllUtils();

  eng.loadConfigs( ngi );
  eng.loadHooks(   ngi );

  utl.qlog( .INFO, 0, @src(), "$ Initialized all subsystems !\n" );
}

pub fn deinitCriticals() void
{
  utl.qlog( .TRACE, 0, @src(), "# Deinitializing all subsystems..." );

  utl.deinitAllUtils();

  utl.qlog( .INFO, 0, @src(), "$ Deinitialized all subsystems !\n" );
}


pub fn main() !void
{
  initCriticals();
  defer deinitCriticals();

  eng.G_ENG.changeState( .OPENED );

  if( eng.G_CNFGS.AutoApply_State_Playing ){ eng.G_ENG.changeState( .PLAYING ); }

  eng.G_ENG.loopLogic();

  eng.G_ENG.changeState( .OFF );
}

test "example test"
{

}
