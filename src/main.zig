const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );


// ================================ INITIALIZATION / DEINITIALIZATION ================================

const adp = @import( "adapter" );

pub fn initCriticals( randomSeed : ?i128 ) void
{
//const alloc = utl.getDefaultAlloc();
//
//std.debug.print( "allocator.ptr    = {}\n", .{ alloc.ptr    });
//std.debug.print( "allocater.vtable = {}\n", .{ alloc.vtable });

  utl.qlog( .TRACE, @src(), "# Initializing all subsystems..." );

  utl.G_EPOCH = utl.getNow();
  if( randomSeed )| seed |
  {
    eng.G_ENG.rng.seedInit( seed );
    utl.log( .INFO, @src(), "Using command-line random seed {d}", .{ seed });
  }
  else { eng.G_ENG.rng.randInit(); }

  utl.initAllUtils();

  eng.loadConfigs( adp );
  eng.loadHooks(   adp );

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
  const randomSeed = try getRandomSeedArg();

  initCriticals( randomSeed );
  defer deinitCriticals();

  eng.G_ENG.changeState( .OPENED );

  if( eng.G_CNFGS.AutoApply_State_Playing ){ eng.G_ENG.changeState( .PLAYING ); }

  // NOTE : this loop should eventually be multithreaded / forked out
  eng.G_ENG.runGameLoop();

  eng.G_ENG.changeState( .OFF );
}

/// Accepts either `tetrom <seed>` or `tetrom --seed <seed>`.
fn getRandomSeedArg() !?i128
{
  const allocator = std.heap.page_allocator;
  const args = try std.process.argsAlloc( allocator );
  defer std.process.argsFree( allocator, args );

  if( args.len <= 1 ){ return null; }

  const rawSeed : []const u8 = blk:
  {
    if( std.mem.eql( u8, args[ 1 ], "--seed" ))
    {
      if( args.len != 3 )
      {
        std.debug.print( "Usage: tetrom [seed | --seed seed]\\n", .{} );
        return error.InvalidRandomSeed;
      }
      break :blk args[ 2 ];
    }

    if( args.len != 2 )
    {
      std.debug.print( "Usage: tetrom [seed | --seed seed]\\n", .{} );
      return error.InvalidRandomSeed;
    }
    break :blk args[ 1 ];
  };

  return std.fmt.parseInt( i128, rawSeed, 10 ) catch
  {
    std.debug.print( "Invalid random seed: {s}\\n", .{ rawSeed });
    return error.InvalidRandomSeed;
  };
}
