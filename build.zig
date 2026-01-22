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
    "Path to a game's engineInterface implementations ( default : exampleGames/gameFolder/engineInterface.zig )"
  );
  const engine_interface_path = if( tmp_engine_interface_path )| path | path else "exampleGames/debug/engineInterface.zig";

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



  // ================================ EXECUTABLE ============ ====================

  // This creates a module for the executable itself
  const exe_mod = b.createModule(
  .{
    .root_source_file = b.path( "src/main.zig" ),
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



  // ================================ LIBRARIES ================================

  // This creates a dependency on the raylib_zig package, which is a Zig wrapper
  // around the raylib C library. The `raylib_zig` package is expected to be
  // available in the Zig package registry, or in the local filesystem if the
  // user has specified a local path to it.
  //const raylib_zig = b.dependency( "raylib_zig_url",
  //.{
  //  .target   = target,
  //  .optimize = optimize,
  //  .linkage  = link_mode,
  //});

  // This imports the raylib module from the raylib_zig package
  //const raylib = raylib_zig.module( "raylib" );

  // This links the raylib library to the executable,
  // allowing it to use the raylib functions and types.
  //exe.root_module.linkLibrary( raylib_zig.artifact( "raylib" ) );
  //exe.root_module.addImport( "raylib", raylib );


  const raylib_dep = b.dependency( "raylib_zig",
  .{
    .target   = target,
    .optimize = optimize,
    .linkage  = link_mode,
  });

  const raylibC = raylib_dep.artifact( "raylib" ); // raylib C library
  const raylib  = raylib_dep.module(   "raylib" ); // main raylib module
//const raygui  = raylib_dep.module(   "raygui" ); // raygui module

  exe.linkLibrary( raylibC );
  exe.root_module.addImport( "raylib", raylib );
//exe.root_module.addImport( "raygui", raygui );


  // ================================ INTERNAL MODULES ================================

  // This adds defs.zig as a module, which contains common definitions and utilities
  // used throughout the project. This module is expected to be in the `src/` directory,
  // and it is used to provide a simple way to access commonly used src definitions
  const defs = b.createModule(
  .{
    .root_source_file = b.path( "./src/defs.zig" ),
    .target   = target,
    .optimize = optimize,
  });
  defs.addImport( "defs",   defs   ); // Allows def to call import itself
  defs.addImport( "raylib", raylib );
//defs.addImport( "raygui", raygui );


  exe.root_module.addImport( "defs", defs );

  // This adds the engine interface module, which is expected to contain the game-specific gameHooks & engineSettings implementations.
  const engine_interface = b.createModule(
  .{
    .root_source_file = b.path( engine_interface_path ), // NOTE : This path is user defined at build time
    .target           = target,
    .optimize         = optimize,
  });
  engine_interface.addImport( "defs",   defs   );

  exe.root_module.addImport(  "engineInterface", engine_interface );




  // ================================ COMMANDS ================================

  // These create steps in the build graph, to be executed when called, or if another step is evaluated that depends on it ( similar to Makefile targets ).


  // ================ GENERIC COMANDS ================

  const run_step = b.step( "run", "Runs the engine with the provided game path" );
  const run_cmd  = b.addRunArtifact( exe );
  run_step.dependOn( &run_cmd.step );
  if( b.args )| args |{ run_cmd.addArgs( args ); }

  //const all_step = b.step( "all", "Compiles all predefined executables in ther debug versions" );
  //const all_cmd  = b.addSystemCommand(
  //all_step.dependOn( &all_cmd.step );


  // ================ SPECIFIC COMMANDS ================

  const games =
  .{
    .{ "ping",        "exampleGames/ping/engineInterface.zig"        },
    .{ "debug",       "exampleGames/debug/engineInterface.zig"       }, // Default
    .{ "floppy",      "exampleGames/floppy/engineInterface.zig"      },
    .{ "dehexer",     "exampleGames/dehexer/engineInterface.zig"     },
    .{ "isofloor",    "exampleGames/isofloor/engineInterface.zig"    },
    .{ "politator",   "exampleGames/politator/engineInterface.zig"   },
    .{ "granulater",  "exampleGames/granulater/engineInterface.zig"  },
    .{ "labyrinther", "exampleGames/labyrinther/engineInterface.zig" },
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

    const dbg_exe_name = "lnx_dbg_" ++ n1;

    const game_step = b.step( n1, "Compiles " ++ n1 ++ " in debug mode and runs it" );
    const game_cmd  = b.addSystemCommand(
      &.{
        "zig",
        "build",
        "run", // NOTE : comment "run" out to avoid launching debug ver on build
        "--release="               ++ "off",
        "-Dexecutable_name="       ++ dbg_exe_name,
        "-Dengine_interface_path=" ++ path,
      });

    game_step.dependOn( &game_cmd.step );

    inline for( optimizations )| opt |
    {
      const n2   = opt[ 0 ];
      const mode = opt[ 1 ];

      const opt_exe_name = "lnx_" ++ n2 ++ "_" ++ n1;

      const mode_step = b.step( n2 ++ "_" ++ n1, "  Compiles " ++ n1 ++ " in " ++ mode ++ " for native platform" );
      const mode_cmd  = b.addSystemCommand(
        &.{
          "zig",
          "build",
          "--release="               ++ n2,
          "-Dexecutable_name="       ++ opt_exe_name,
          "-Dengine_interface_path=" ++ path,
        });

      mode_step.dependOn( &mode_cmd.step );

      inline for( platforms )| plat |
      {
        const n3   = plat[ 0 ];
        const targ = plat[ 1 ];

        const plt_exe_name = n3 ++ "_" ++ n2 ++ "_" ++ n1;

        const targ_step = b.step( plt_exe_name, "    Compiles " ++ n1 ++ " in " ++ mode ++ " for " ++ targ );
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
