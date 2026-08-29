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

const GameExecutable = struct
{
  exe       : *std.Build.Step.Compile,
  utilsMod  : *std.Build.Module,
  engineMod : *std.Build.Module,
};

const LoggerBuildOptions = struct
{
  logLevel               : []const u8,
  useFile                : bool,
  fileName               : []const u8,
  showTimestamp          : bool,
  showSource             : bool,
  showColour              : bool,
  expectFileSetupFailure : bool = false,
};

const CheckGamesCompleteStep = struct
{
  step      : std.Build.Step,
  gameCount : usize,

  fn create( b : *std.Build, gameCount : usize ) *CheckGamesCompleteStep
  {
    const complete = b.allocator.create( CheckGamesCompleteStep ) catch @panic( "OOM" );

    complete.* =
    .{
      .step = std.Build.Step.init(
      .{
        .id      = .custom,
        .name    = "check_games complete",
        .owner   = b,
        .makeFn  = make,
      }),

      .gameCount = gameCount,
    };

    return complete;
  }

  fn make( step : *std.Build.Step, options : std.Build.Step.MakeOptions ) !void
  {
    _ = options;

    const complete : *CheckGamesCompleteStep = @fieldParentPtr( "step", step );

    std.debug.print( "check_games passed: {d} games checked, 0 failed\n", .{ complete.gameCount } );
  }
};

const MessageStep = struct
{
  step    : std.Build.Step,
  message : []const u8,

  fn create( b : *std.Build, name : []const u8, message : []const u8 ) *MessageStep
  {
    const msg = b.allocator.create( MessageStep ) catch @panic( "OOM" );

    msg.* =
    .{
      .step = std.Build.Step.init(
      .{
        .id      = .custom,
        .name    = name,
        .owner   = b,
        .makeFn  = make,
      }),

      .message = message,
    };

    return msg;
  }

  fn make( step : *std.Build.Step, options : std.Build.Step.MakeOptions ) !void
  {
    _ = options;

    const msg : *MessageStep = @fieldParentPtr( "step", step );

    std.debug.print( "{s}\n", .{ msg.message } );
  }
};

fn addGameExecutable(
  b              : *std.Build,
  executableName : []const u8,
  adapterPath    : []const u8,
  target         : std.Build.ResolvedTarget,
  optimize       : std.builtin.OptimizeMode,
  loggerOptions  : LoggerBuildOptions,
) GameExecutable
{
  const exeMod = b.createModule(
  .{
    .root_source_file = b.path( "src/main.zig" ),
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
    .root_source_file = b.path( "src/utils/utilsDef.zig" ),
    .target           = target,
    .optimize         = optimize,
  });

  const loggerConfig = b.addOptions();

  loggerConfig.addOption( []const u8, "log_level",                 loggerOptions.logLevel               );
  loggerConfig.addOption( bool,       "use_file",                  loggerOptions.useFile                );
  loggerConfig.addOption( []const u8, "file_name",                 loggerOptions.fileName               );
  loggerConfig.addOption( bool,       "show_timestamp",            loggerOptions.showTimestamp          );
  loggerConfig.addOption( bool,       "show_source",               loggerOptions.showSource             );
  loggerConfig.addOption( bool,       "show_colour",               loggerOptions.showColour             );
  loggerConfig.addOption( bool,       "expect_file_setup_failure", loggerOptions.expectFileSetupFailure );

  const engine = b.createModule(
  .{
    .root_source_file = b.path( "src/engine/engineDef.zig" ),
    .target           = target,
    .optimize         = optimize,
  });

  const adapter = b.createModule(
  .{
    .root_source_file = b.path( adapterPath ),
    .target           = target,
    .optimize         = optimize,
  });

  exe.root_module.addImport( "utils",   utils   );
  exe.root_module.addImport( "engine",  engine  );
  exe.root_module.addImport( "adapter", adapter );

  utils.addImport( "raylib", raylib );
  utils.addImport( "utils",  utils  );
  utils.addImport( "engine", engine );
  utils.addOptions( "logger_config", loggerConfig );

  engine.addImport( "utils",  utils  );
  engine.addImport( "engine", engine );

  adapter.addImport( "engine", engine );
  adapter.addImport( "utils",  utils  );

  return .{
    .exe       = exe,
    .utilsMod  = utils,
    .engineMod = engine,
  };
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
  const tmp_engine_adapter_path = b.option(
    []const u8,
    "engine_adapter_path",
    "Path to a game's engineAdapter implementation ( default : src/games/gameFolder/engineAdapter.zig )"
  );
  const adapter_path = if( tmp_engine_adapter_path )| path | path else "src/games/debug/engineAdapter.zig";

  const tmp_executable_name = b.option(
    []const u8,
    "executable_name",
    "Name to give the compiled executable"
  );
  const executable_name = if( tmp_executable_name )| name | name else "ZE_Game";

  const tmp_logger_log_level = b.option(
    []const u8,
    "logger_log_level",
    "Comptime logger level: NONE, ERROR, WARN, INFO, DEBUG, or TRACE"
  );

  const tmp_logger_use_file = b.option(
    bool,
    "logger_use_file",
    "If true, writes logger output to aggregate and per-level plain-text files"
  );

  const tmp_logger_file_name = b.option(
    []const u8,
    "logger_file_name",
    "Base aggregate file name used when logger_use_file is true"
  );

  const tmp_logger_show_timestamp = b.option(
    bool,
    "logger_show_timestamp",
    "If true, logger output includes elapsed timestamps"
  );

  const tmp_logger_show_source = b.option(
    bool,
    "logger_show_source",
    "If true, logger output includes source file, line, and function"
  );

  const tmp_logger_show_colour = b.option(
    bool,
    "logger_show_colour",
    "If true, terminal logger output includes ANSI color codes"
  );

  const loggerOptions =
  LoggerBuildOptions
  {
    .logLevel      = if( tmp_logger_log_level      )| level | level else "DEBUG",
    .useFile       = if( tmp_logger_use_file       )| use   | use   else true,
    .fileName      = if( tmp_logger_file_name      )| name  | name  else "logs/debug.log",
    .showTimestamp = if( tmp_logger_show_timestamp )| show  | show  else true,
    .showSource    = if( tmp_logger_show_source    )| show  | show  else true,
    .showColour    = if( tmp_logger_show_colour    )| show  | show  else true,
  };

  const gameBuild = addGameExecutable( b, executable_name, adapter_path, target, optimize, loggerOptions );
  const exe       = gameBuild.exe;

  b.installArtifact( exe );



  // ================================ COMMANDS ================================

  // These create steps in the build graph, to be executed when called, or when
  // another step is evaluated that depends on them ( similar to Makefile targets ).


  // ================ GENERIC COMMANDS ================

  const run_step = b.step( "run", "Runs debug_run. Use [game]_run to run a specific game" );
  const run_msg  = MessageStep.create( b, "run alias notice", "running zig build debug_run. use \"zig build [game]_run\" to run a specific game" );


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
    .{ "debug",       "src/games/debug/engineAdapter.zig"       }, // Default

    .{ "ping",        "src/games/ping/engineAdapter.zig"        },
    .{ "menuer",      "src/games/menuer/engineAdapter.zig"      },
    .{ "floppy",      "src/games/floppy/engineAdapter.zig"      },
    .{ "tetrom",      "src/games/tetrom/engineAdapter.zig"      },
    .{ "drifter",     "src/games/drifter/engineAdapter.zig"     },
    .{ "dehexer",     "src/games/dehexer/engineAdapter.zig"     },
    .{ "isofloor",    "src/games/isofloor/engineAdapter.zig"    },
    .{ "politator",   "src/games/politator/engineAdapter.zig"   },
    .{ "granulater",  "src/games/granulater/engineAdapter.zig"  },
    .{ "labyrinther", "src/games/labyrinther/engineAdapter.zig" },

    .{ "orbiter",     "src/games/orbiter/engineAdapter.zig"     },

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

  // Depends directly on compile steps so checks only populate Zig's cache and
  // never install game executables into zig-out/bin.
  const check_games_step = b.step( "check_games", "Checks every listed game in debug mode without installing executables" );
  const check_games_done = CheckGamesCompleteStep.create( b, games.len );

  inline for( games )| game |
  {
    const n1   = game[ 0 ];
    const path = game[ 1 ];

    const dbg_exe_name = n1;
    const game_exe     = addGameExecutable( b, dbg_exe_name, path, target, .Debug, loggerOptions ).exe;
    const game_install = b.addInstallArtifact( game_exe, .{} );

    const game_step = b.step( n1, "Compiles " ++ n1 ++ " in debug mode" );
    game_step.dependOn( &game_install.step );

    check_games_done.step.dependOn( &game_exe.step );


    const game_run_step = b.step( n1 ++ "_run", "Compiles " ++ n1 ++ " in debug mode and runs it" );
    const game_run_cmd  = b.addRunArtifact( game_exe );


    game_run_cmd.step.dependOn( &game_install.step );
    game_run_step.dependOn( &game_run_cmd.step );

    if( std.mem.eql( u8, n1, "debug" ) )
    {
      const default_run_cmd = b.addRunArtifact( game_exe );

      default_run_cmd.step.dependOn( &game_install.step );
      default_run_cmd.step.dependOn( &run_msg.step );
      run_step.dependOn( &default_run_cmd.step );
    }


    inline for( optimizations )| opt |
    {
      const n2   = opt[ 0 ];
      const mode = opt[ 1 ];
      const opti = opt[ 2 ];

      const opt_exe_name = n1 ++ "_" ++ n2;
      const opt_exe      = addGameExecutable( b, opt_exe_name, path, target, opti, loggerOptions ).exe;
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
        const plt_exe      = addGameExecutable( b, plt_exe_name, path, plt_target, opti, loggerOptions ).exe;
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
      const plt_exe      = addGameExecutable( b, plt_exe_name, path, plt_target, .Debug, loggerOptions ).exe;
      const plt_install  = b.addInstallArtifact( plt_exe, .{} );

      const targ_step = b.step( n1 ++ "_" ++ n3, "- Compiles " ++ n1 ++ " in debug mode for " ++ targ );
      targ_step.dependOn( &plt_install.step );
    }
  }

  check_games_step.dependOn( &check_games_done.step );


  // ================ TEST COMMANDS ================

  const exe_unit_tests     = b.addTest(.{ .root_module = exe.root_module });
  const run_exe_unit_tests = b.addRunArtifact( exe_unit_tests );

  const utils_unit_tests     = b.addTest(.{ .root_module = gameBuild.utilsMod });
  const run_utils_unit_tests = b.addRunArtifact( utils_unit_tests );

  const engine_unit_tests     = b.addTest(.{ .root_module = gameBuild.engineMod });
  const run_engine_unit_tests = b.addRunArtifact( engine_unit_tests );

  // Similar to creating the run step earlier, this exposes a `test` step to the `zig build --help` menu,
  // providing a way for the user to request running the unit tests instead of the main application.
  const test_step = b.step( "test", "Runs unit tests" );
  test_step.dependOn( &run_exe_unit_tests.step );
  test_step.dependOn( &run_utils_unit_tests.step );
  test_step.dependOn( &run_engine_unit_tests.step );


  // ================ LOGGER VALIDATION COMMANDS ================

  const loggerFileOptions =
  LoggerBuildOptions
  {
    .logLevel      = "DEBUG",
    .useFile       = true,
    .fileName      = "logger_validation.log",
    .showTimestamp = true,
    .showSource    = true,
    .showColour     = true,
  };

  const logger_file_build      = addGameExecutable( b, "logger_file_validation", adapter_path, target, optimize, loggerFileOptions );
  const logger_file_tests      = b.addTest(.{ .root_module = logger_file_build.utilsMod });
  const run_logger_file_tests  = b.addRunArtifact( logger_file_tests );
  const logger_file_test_step  = b.step( "test_logger_files", "Runs logger file-sink validation with file logging enabled" );
  logger_file_test_step.dependOn( &run_logger_file_tests.step );

  const loggerFileFailureOptions =
  LoggerBuildOptions
  {
    .logLevel               = "DEBUG",
    .useFile                = true,
    .fileName               = "missing_logger_dir/debug.log",
    .showTimestamp          = true,
    .showSource             = true,
    .showColour              = true,
    .expectFileSetupFailure = true,
  };

  const logger_file_failure_build     = addGameExecutable( b, "logger_file_failure_validation", adapter_path, target, optimize, loggerFileFailureOptions );
  const logger_file_failure_tests     = b.addTest(.{ .root_module = logger_file_failure_build.utilsMod });
  const run_logger_file_failure_tests = b.addRunArtifact( logger_file_failure_tests );
  const logger_file_failure_step      = b.step( "test_logger_file_failure", "Runs logger file setup-failure fallback validation" );
  logger_file_failure_step.dependOn( &run_logger_file_failure_tests.step );
}
