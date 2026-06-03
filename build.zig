const std = @import( "std" );
const rlz = @import( "raylib_zig" );

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


  const link_mode :std.builtin.LinkMode = switch( optimize )
  {
    .Debug => .dynamic,

    else => switch( target.result.os.tag )
    {
      .linux   => .static,
      .macos   => .static,
      .windows => .static, // windows being windows, not willing to play ball with dynamic for now
      else     => .static,
    },
  };

  const use_llvm = switch( target.result.os.tag )
  {
    .windows => true,  // NOTE : Zig's built-in compiler backend cannot properly handle windows builds yet
    else     => false,
  };



  // ================================ LIBRARIES AND MODULES  ================================

  // ================ EXECUTABLE ================

  // This creates a module for the executable itself
  const exe_mod = b.createModule(
  .{
    .root_source_file = b.path( "engine/main.zig" ),
    .target           = target,
    .optimize         = optimize,
  });

  // This adds the executable module to the build graph, which is the main entry point of the application.
  const exe = b.addExecutable(
  .{
    .name        = executable_name,
    .root_module = exe_mod,
    .use_llvm    = use_llvm,
  });

  exe.root_module.link_libc = true;
  exe.bundle_compiler_rt    = true;

  // This declares the intent to install the executable artifact, which is the binary that will be built by the build system.
  b.installArtifact( exe );


  // ================ RAYLIB ================

  // This creates a dependency on the raylib_zig package, which is a
  // Zig wrapper around the raylib C library. The `raylib_zig` package
  // is expected to be available in the Zig package registry, or in the
  // local filesystem if the user has specified a local path to it.

  const raylib_optimize : std.builtin.OptimizeMode = switch( optimize )
  {
    .Debug        => .ReleaseFast,
    .ReleaseSafe  => .ReleaseFast,
    else          => optimize,
  };

  const raylib_dep = b.dependency( "raylib_zig",
  .{
    .target   = target,
    .optimize = raylib_optimize,
    .linkage  = link_mode,
  });

  const raylib  = raylib_dep.module(   "raylib" ); // main raylib module
  const raylibC = raylib_dep.artifact( "raylib" ); // raylib C library

  exe.linkLibrary( raylibC );


  // ================ UTILITIES ================

  const utils = b.createModule(
  .{
    .root_source_file = b.path( "utils/utilsDef.zig" ),
    .target   = target,
    .optimize = optimize,
  });

  exe.root_module.addImport( "utils", utils );


  // ================ ENGINE ================

  const engine = b.createModule(
  .{
    .root_source_file = b.path( "engine/engineDef.zig" ),
    .target   = target,
    .optimize = optimize,
  });

  exe.root_module.addImport( "engine", engine );


  // ================ INTERFACE ================

  // This adds the engine interface module, which is expected to contain the game-specific gameHooks & engineSettings implementations.
  const interface = b.createModule(
  .{
    .root_source_file = b.path( interface_path ), // NOTE : This path is user defined at build time
    .target           = target,
    .optimize         = optimize,
  });

  exe.root_module.addImport( "interface", interface ); // Public engine interface // TOOD : review naming convention for it


  // ================ LINKAGE ================

  utils.addImport( "raylib", raylib ); // Should only be accessed through utils
  utils.addImport( "utils",  utils  ); // Allows utils to call import itself
  utils.addImport( "engine", engine );

  engine.addImport( "utils",  utils  );
  engine.addImport( "engine", engine ); // Allows engine to call import itself

  interface.addImport( "engine", engine );
  interface.addImport( "utils",  utils  );



  // ================================ COMMANDS ================================

  // These create steps in the build graph, to be executed when called, or when
  // another step is evaluated that depends on them ( similar to Makefile targets ).


  // ================ GENERIC COMANDS ================

  const run_step = b.step( "run", "Runs the engine with the provided game path" );
  const run_cmd  = b.addRunArtifact( exe );
  run_step.dependOn( &run_cmd.step );
  if( b.args )| args |{ run_cmd.addArgs( args ); }


  // ================ SPECIFIC COMMANDS ================

  const games =
  .{
    .{ "debug",       "games/debug/engineInterface.zig"       }, // Default

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
  //.{ "dbg",   "Debug"         }, // Default
    .{ "fast",  "Release Fast"  },
    .{ "safe",  "Release Safe"  },
    .{ "small", "Release Small" },
  };

  const platforms =
  .{
  //.{ "lnx", "native"             }, // Default
    .{ "win", "x86_64-windows-gnu" },
    .{ "mac", "x86_64-macos"       },
  };

  inline for( games )| game |
  {
    const n1   = game[ 0 ];
    const path = game[ 1 ];

    const dbg_exe_name = n1;

    const game_step = b.step( n1, "Compiles " ++ n1 ++ " in debug mode" );
    const game_cmd  = b.addSystemCommand(
      &.{
        "zig",
        "build",
        "--release="               ++ "off",
        "-Dexecutable_name="       ++ dbg_exe_name,
        "-Dengine_interface_path=" ++ path,
      });

    game_step.dependOn( &game_cmd.step );


    const game_run_step = b.step( n1 ++ "_run", "Compiles " ++ n1 ++ " in debug mode and runs it" );
    const game_run_cmd  = b.addSystemCommand(
      &.{
        "zig",
        "build",
        "run",
        "--release="               ++ "off",
        "-Dexecutable_name="       ++ dbg_exe_name,
        "-Dengine_interface_path=" ++ path,
      });


    game_run_cmd.step.dependOn( &game_cmd.step );
    game_run_step.dependOn( &game_run_cmd.step );


    inline for( optimizations )| opt |
    {
      const n2   = opt[ 0 ];
      const mode = opt[ 1 ];

      const opt_exe_name = n1 ++ "_" ++ n2;


      const mode_step = b.step( n1 ++ "_" ++ n2, "- Compiles " ++ n1 ++ " in " ++ mode ++ " for native platform" );
      const mode_cmd  = b.addSystemCommand(
        &.{
          "zig",
          "build",
          "--release="               ++ n2,
          "-Dexecutable_name="       ++ opt_exe_name,
          "-Dengine_interface_path=" ++ path,
        });

      mode_step.dependOn( &mode_cmd.step );


      const mode_run_step = b.step( n1 ++ "_" ++ n2 ++ "_run", "- Compiles " ++ n1 ++ " in " ++ mode ++ " for native platform and runs it" );
      const mode_run_cmd  = b.addSystemCommand(
        &.{
          "zig",
          "build",
          "run",
          "--release="               ++ n2,
          "-Dexecutable_name="       ++ opt_exe_name,
          "-Dengine_interface_path=" ++ path,
        });

      mode_run_cmd.step.dependOn( &mode_cmd.step );
      mode_run_step.dependOn( &mode_run_cmd.step );


      inline for( platforms )| plat |
      {
        const n3   = plat[ 0 ];
        const targ = plat[ 1 ];

        const plt_exe_name = n1 ++ "_" ++ n2 ++ "_" ++ n3;

        const targ_step = b.step( n1 ++ "_" ++ n2 ++ "_" ++ n3, "-   Compiles " ++ n1 ++ " in " ++ mode ++ " for " ++ targ );
        const targ_cmd  = b.addSystemCommand(
          &.{
            "zig",
            "build",
            "--release="               ++ n2,
            "-Dexecutable_name="       ++ plt_exe_name,
            "-Dengine_interface_path=" ++ path,
            "-Dtarget="                ++ targ,
          });

        targ_step.dependOn( &targ_cmd.step );
      }
    }

    inline for( platforms )| plat |
    {
      const n3   = plat[ 0 ];
      const targ = plat[ 1 ];

      const plt_exe_name = n1 ++ "_" ++ n3;

      const targ_step = b.step( n1 ++ "_" ++ n3, "- Compiles " ++ n1 ++ " in debug mode for " ++ targ );
      const targ_cmd  = b.addSystemCommand(
        &.{
          "zig",
          "build",
          "--release="               ++ "off",
          "-Dexecutable_name="       ++ plt_exe_name,
          "-Dengine_interface_path=" ++ path,
          "-Dtarget="                ++ targ,
        });

      targ_step.dependOn( &targ_cmd.step );
    }
  }


  // ================ TEST COMANDS ================
  // NOTE : NOT IN CURRENT USE

  const exe_unit_tests     = b.addTest(.{ .root_module = exe_mod });
  const run_exe_unit_tests = b.addRunArtifact( exe_unit_tests );

  // Similar to creating the run step earlier, this exposes a `test` step to the `zig build --help` menu,
  // providing a way for the user to request running the unit tests instead of the main application.
  const test_step = b.step( "test", "Runs unit tests (N/A)" );
  test_step.dependOn( &run_exe_unit_tests.step );
}
