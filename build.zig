const std = @import( "std" );
const rlz = @import( "raylib_zig" );

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build( b: *std.Build ) void
{
  // ================================ BUILD CONFIGURATION ================================

  // This is the "standard" build target, which is the default for the current platform and architecture.
  const target   = b.standardTargetOptions(  .{} );
  const optimize = b.standardOptimizeOption( .{ .preferred_optimize_mode = .Debug } );

  // This is a build option that allows the user to specify the path to the game-specific engine interface module
  const tmp_engine_interface_path = b.option(
    []const u8,
    "engine_interface_path",
    "Path to a game's engineInterface implementations (e.g., exampleGames/gameFolder/engineInterface.zig)"
  );

  // This sets the default path for the engine interface module to the template
  const engine_interface_path = if( tmp_engine_interface_path )| path | path else "exampleGames/debug/engineInterface.zig";


  // ================================ EXECUTABLE ================================

  // This creates a module for the executable itself
  const exe_mod = b.createModule(
  .{
    .root_source_file = b.path( "src/main.zig" ),
    .target           = target,
    .optimize         = optimize,
  //.linkage          = .static,
  });

  // This adds the executable module to the build graph,
  // which is the main entry point of the application.
  const exe = b.addExecutable(
  .{
    .name        = "ZiguezonEngine",
    .root_module = exe_mod,
    .use_llvm    = false,
  });

  exe.linkLibC();
  exe.bundle_compiler_rt = true;

  // This declares the intent to install the executable artifact,
  // which is the binary that will be built by the build system.
  b.installArtifact( exe );


  // ================================ LIBRARIES ================================

  // This creates a dependency on the raylib_zig package, which is a Zig wrapper
  // around the raylib C library. The `raylib_zig` package is expected to be
  // available in the Zig package registry, or in the local filesystem if the
  // user has specified a local path to it.
  const raylib_dep = b.dependency( "raylib_zig",
  .{
    .target   = target,
    .optimize = optimize,
    .linkage  = .static,
  });

  // This imports the raylib module from the raylib_zig package
  const raylib = raylib_dep.module( "raylib" );

  // This links the raylib library to the executable,
  // allowing it to use the raylib functions and types.
  exe.linkLibrary( raylib_dep.artifact( "raylib" ) );
  exe.root_module.addImport( "raylib", raylib );

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
  defs.addImport( "raylib", raylib );
  defs.addImport( "defs", defs );
  exe.root_module.addImport( "defs", defs );

  // This adds the engine interface module, which is expected to contain the game-specific gameHooks & engineSettings implementations.
  const engine_interface = b.createModule(
  .{
    .root_source_file = b.path( engine_interface_path ), // NOTE : This path is user defined at build time
    .target           = target,
    .optimize         = optimize,
  });
  engine_interface.addImport( "raylib", raylib );
  engine_interface.addImport( "defs", defs );
  exe.root_module.addImport(  "engineInterface", engine_interface );


  // ================================ COMMANDS ================================

  // This creates steps in the build graph, to be executed when called, or if
  // another step is evaluated that depends on it ( similar to Makefile targets ).


  // ================ GENERIC COMANDS ================

  const run_step = b.step( "run", "Run the engine with the provided game path" );
  const run_cmd  = b.addRunArtifact( exe );
  run_step.dependOn( &run_cmd.step );
  if( b.args )| args |{ run_cmd.addArgs( args ); }


  // ================ GAME SPECIFIC COMMANDS ================

  const games =
  .{
    .{ "ping",        "exampleGames/ping/engineInterface.zig"        },
    .{ "debug",       "exampleGames/debug/engineInterface.zig"       }, // Default
    .{ "floppy",      "exampleGames/floppy/engineInterface.zig"      },
    .{ "dehexer",     "exampleGames/dehexer/engineInterface.zig"     },
    .{ "labyrinther", "exampleGames/labyrinther/engineInterface.zig" },
  };

  inline for( games )| game |
  {
    const name = game[ 0 ];
    const path = game[ 1 ];

    const game_step = b.step( name, "Compiles and runs " ++ name );
    const game_cmd  = b.addSystemCommand( &.{ "zig", "build", "run", "-Dengine_interface_path=" ++ path });
    game_step.dependOn( &game_cmd.step );
  }


  // ================ TARGET SPECIFIC COMANDS ================

  const platforms =
  .{
    .{ "lnx", "x86_64-linux-gnu"   },
    .{ "win", "x86_64-windows-gnu" },
    .{ "mac", "x86_64-macos"       },
  };

  inline for( platforms )| plat |
  {
    const name = plat[ 0 ];
    const comp = plat[ 1 ];

    const comp_step = b.step( "comp_" ++ name, "Compiles for " ++ comp );
    const comp_cmd  = b.addSystemCommand( &.{ "zig", "build", "-Dtarget=" ++ comp });
    comp_step.dependOn( &comp_cmd.step );
  }


  // ================ MODE SPECIFIC COMANDS ================

  const optimizations =
  .{
    .{ "dbg",   "Debug"        }, // Default
    .{ "fast",  "ReleaseFast"  },
    .{ "safe",  "ReleaseSafe"  },
    .{ "small", "ReleaseSmall" },
  };

  inline for( optimizations )| opt |
  {
    const name = opt[ 0 ];
    const mode = opt[ 1 ];

    const mode_step = b.step( "mode_" ++ name, "Compiles in " ++ name );
    const mode_cmd  = b.addSystemCommand( &.{ "zig", "build", "-Doptimize=" ++ "." ++ mode });
    mode_step.dependOn( &mode_cmd.step );
  }


  // ================ TEST COMANDS ================

  const exe_unit_tests     = b.addTest(.{ .root_module = exe_mod });
  const run_exe_unit_tests = b.addRunArtifact( exe_unit_tests );

  // Similar to creating the run step earlier, this exposes a `test` step to the `zig build --help` menu,
  // providing a way for the user to request running the unit tests instead of the main application.
  const test_step = b.step( "test", "Run unit tests" );
  test_step.dependOn( &run_exe_unit_tests.step );
}