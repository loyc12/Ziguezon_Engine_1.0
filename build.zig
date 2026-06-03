const std = @import( "std" );


fn getLinkMode( target : std.Build.ResolvedTarget, optimize : std.builtin.OptimizeMode ) std.builtin.LinkMode
{
  switch( optimize )
  {
    .Debug => return .dynamic,

    else => switch( target.result.os.tag )
    {
      .linux   => return .static,
      .macos   => return .static,
      .windows => return .static, // windows being windows, not willing to play ball with dynamic for now
      else     => return .static,
    },
  }
}

fn shouldUseLlvm( target : std.Build.ResolvedTarget ) bool
{
  return switch( target.result.os.tag )
  {
    .windows => true,  // NOTE : Zig's built-in compiler backend cannot properly handle windows builds yet
    else     => false,
  };
}

fn getRaylibOptimize( optimize : std.builtin.OptimizeMode ) std.builtin.OptimizeMode
{
  return switch( optimize )
  {
    .Debug        => .ReleaseFast,
    .ReleaseSafe  => .ReleaseFast,
    else          => optimize,
  };
}

fn addGameExecutable( b : *std.Build, executableName : []const u8, interfacePath : []const u8, target : std.Build.ResolvedTarget, optimize : std.builtin.OptimizeMode ) *std.Build.Step.Compile
{
  const exeMod = b.createModule(
  .{
    .root_source_file = b.path( "engine/main.zig" ),
    .target           = target,
    .optimize         = optimize,
  });

  const exe = b.addExecutable(
  .{
    .name        = executableName,
    .root_module = exeMod,
    .use_llvm    = shouldUseLlvm( target ),
  });

  exe.root_module.link_libc = true;
  exe.bundle_compiler_rt    = true;

  const raylibDep = b.dependency( "raylib_zig",
  .{
    .target   = target,
    .optimize = getRaylibOptimize( optimize ),
    .linkage  = getLinkMode( target, optimize ),
  });

  const raylib  = raylibDep.module(   "raylib" ); // main raylib module
  const raylibC = raylibDep.artifact( "raylib" ); // raylib C library

  exe.linkLibrary( raylibC );

  const utils = b.createModule(
  .{
    .root_source_file = b.path( "utils/utilsDef.zig" ),
    .target           = target,
    .optimize         = optimize,
  });

  const engine = b.createModule(
  .{
    .root_source_file = b.path( "engine/engineDef.zig" ),
    .target           = target,
    .optimize         = optimize,
  });

  const interface = b.createModule(
  .{
    .root_source_file = b.path( interfacePath ),
    .target           = target,
    .optimize         = optimize,
  });

  exe.root_module.addImport( "utils",     utils     );
  exe.root_module.addImport( "engine",    engine    );
  exe.root_module.addImport( "interface", interface ); // Public engine interface // TODO : review naming convention for it

  utils.addImport( "raylib", raylib );
  utils.addImport( "utils",  utils  );
  utils.addImport( "engine", engine );

  engine.addImport( "utils",  utils  );
  engine.addImport( "engine", engine );

  interface.addImport( "engine", engine );
  interface.addImport( "utils",  utils  );

  return exe;
}


// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build( b : *std.Build ) void
{
  // ================================ BUILD CONFIGURATION ================================

  // This is the "standard" build target, which is the default for the current platform and architecture.
  const target   = b.standardTargetOptions(  .{} );
  const optimize = b.standardOptimizeOption( .{} );


  // Build options ( additional, specifiable cli arguments )
  const tmp_engine_interface_path = b.option(
    []const u8,
    "engine_interface_path",
    "Path to a game's engineInterface implementations ( default : games/gameFolder/engineInterface.zig )"
  );
  const interface_path = if( tmp_engine_interface_path )| path | path else "games/debug/engineInterface.zig";

  const tmp_executable_name = b.option(
    []const u8,
    "executable_name",
    "Name to give the compiled executable"
  );
  const executable_name = if( tmp_executable_name )| name | name else "ZE_Game";


  const exe = addGameExecutable( b, executable_name, interface_path, target, optimize );

  b.installArtifact( exe );



  // ================================ COMMANDS ================================

  // These create steps in the build graph, to be executed when called, or when
  // another step is evaluated that depends on them ( similar to Makefile targets ).


  // ================ GENERIC COMMANDS ================

  const run_step = b.step( "run", "Use [game]_run instead, e.g. debug_run or orbiter_run" );
  const run_fail = b.addFail( "Bare `zig build run` is ambiguous. Use `zig build debug_run`, `zig build orbiter_run`, etc." );
  run_step.dependOn( &run_fail.step );


  const clean_exe_step = b.step( "clean_exe", "Deletes installed executables from zig-out/bin" );
  const clean_exe_cmd  = b.addRemoveDirTree( b.path( "zig-out/bin" ) );
  clean_exe_step.dependOn( &clean_exe_cmd.step );

  const clean_artifacts_step = b.step( "clean_artifacts", "Deletes build artifacts from zig-out" );
  const clean_artifacts_cmd  = b.addRemoveDirTree( b.path( "zig-out" ) );
  clean_artifacts_step.dependOn( &clean_artifacts_cmd.step );

  const clean_cache_step = b.step( "clean_cache", "Deletes the local Zig build cache from .zig-cache" );
  const clean_cache_cmd  = b.addRemoveDirTree( b.path( ".zig-cache" ) );
  clean_cache_step.dependOn( &clean_cache_cmd.step );

  const clean_all_step = b.step( "clean_all", "Deletes build artifacts and the local Zig build cache" );
  clean_all_step.dependOn( &clean_artifacts_cmd.step );
  clean_all_step.dependOn( &clean_cache_cmd.step );


  // ================ SPECIFIC COMMANDS ================

  const games =
  .{
    .{ "debug",       "games/debug/engineInterface.zig"       }, // Default

    .{ "menuer",      "games/menuer/engineInterface.zig"      },
    .{ "ping",        "games/ping/engineInterface.zig"        },
    .{ "floppy",      "games/floppy/engineInterface.zig"      },
    .{ "dehexer",     "games/dehexer/engineInterface.zig"     },
    .{ "isofloor",    "games/isofloor/engineInterface.zig"    },
    .{ "politator",   "games/politator/engineInterface.zig"   },
    .{ "granulater",  "games/granulater/engineInterface.zig"  },
    .{ "labyrinther", "games/labyrinther/engineInterface.zig" },

    .{ "orbiter",     "games/orbiter/engineInterface.zig"     },

  };

  const optimizations =
  .{
  //.{ "dbg",   "Debug",         std.builtin.OptimizeMode.Debug        }, // Default
    .{ "fast",  "Release Fast",  std.builtin.OptimizeMode.ReleaseFast  },
    .{ "safe",  "Release Safe",  std.builtin.OptimizeMode.ReleaseSafe  },
    .{ "small", "Release Small", std.builtin.OptimizeMode.ReleaseSmall },
  };

  const platforms =
  .{
  //.{ "lnx", "native"             }, // Default
    .{ "win", "x86_64-windows-gnu" },
    .{ "mac", "x86_64-macos"       },
  };

  const check_games_step = b.step( "check_games", "Compiles every listed game in debug mode" );

  inline for( games )| game |
  {
    const n1   = game[ 0 ];
    const path = game[ 1 ];

    const dbg_exe_name = n1;
    const game_exe     = addGameExecutable( b, dbg_exe_name, path, target, .Debug );
    const game_install = b.addInstallArtifact( game_exe, .{} );

    const game_step = b.step( n1, "Compiles " ++ n1 ++ " in debug mode" );
    game_step.dependOn( &game_install.step );

    check_games_step.dependOn( &game_exe.step );


    const game_run_step = b.step( n1 ++ "_run", "Compiles " ++ n1 ++ " in debug mode and runs it" );
    const game_run_cmd  = b.addRunArtifact( game_exe );


    game_run_cmd.step.dependOn( &game_install.step );
    game_run_step.dependOn( &game_run_cmd.step );


    inline for( optimizations )| opt |
    {
      const n2   = opt[ 0 ];
      const mode = opt[ 1 ];
      const opti = opt[ 2 ];

      const opt_exe_name = n1 ++ "_" ++ n2;
      const opt_exe      = addGameExecutable( b, opt_exe_name, path, target, opti );
      const opt_install  = b.addInstallArtifact( opt_exe, .{} );


      const mode_step = b.step( n1 ++ "_" ++ n2, "- Compiles " ++ n1 ++ " in " ++ mode ++ " for native platform" );
      mode_step.dependOn( &opt_install.step );


      const mode_run_step = b.step( n1 ++ "_" ++ n2 ++ "_run", "- Compiles " ++ n1 ++ " in " ++ mode ++ " for native platform and runs it" );
      const mode_run_cmd  = b.addRunArtifact( opt_exe );

      mode_run_cmd.step.dependOn( &opt_install.step );
      mode_run_step.dependOn( &mode_run_cmd.step );


      inline for( platforms )| plat |
      {
        const n3   = plat[ 0 ];
        const targ = plat[ 1 ];

        const plt_exe_name = n1 ++ "_" ++ n2 ++ "_" ++ n3;
        const plt_query    = std.Target.Query.parse( .{ .arch_os_abi = targ } ) catch @panic( "Invalid platform target" );
        const plt_target   = b.resolveTargetQuery( plt_query );
        const plt_exe      = addGameExecutable( b, plt_exe_name, path, plt_target, opti );
        const plt_install  = b.addInstallArtifact( plt_exe, .{} );

        const targ_step = b.step( n1 ++ "_" ++ n2 ++ "_" ++ n3, "-   Compiles " ++ n1 ++ " in " ++ mode ++ " for " ++ targ );
        targ_step.dependOn( &plt_install.step );
      }
    }

    inline for( platforms )| plat |
    {
      const n3   = plat[ 0 ];
      const targ = plat[ 1 ];

      const plt_exe_name = n1 ++ "_" ++ n3;
      const plt_query    = std.Target.Query.parse( .{ .arch_os_abi = targ } ) catch @panic( "Invalid platform target" );
      const plt_target   = b.resolveTargetQuery( plt_query );
      const plt_exe      = addGameExecutable( b, plt_exe_name, path, plt_target, .Debug );
      const plt_install  = b.addInstallArtifact( plt_exe, .{} );

      const targ_step = b.step( n1 ++ "_" ++ n3, "- Compiles " ++ n1 ++ " in debug mode for " ++ targ );
      targ_step.dependOn( &plt_install.step );
    }
  }


  // ================ TEST COMMANDS ================

  const exe_unit_tests     = b.addTest(.{ .root_module = exe.root_module });
  const run_exe_unit_tests = b.addRunArtifact( exe_unit_tests );

  // Similar to creating the run step earlier, this exposes a `test` step to the `zig build --help` menu,
  // providing a way for the user to request running the unit tests instead of the main application.
  const test_step = b.step( "test", "Runs unit tests" );
  test_step.dependOn( &run_exe_unit_tests.step );
}
