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
  const optimize = b.standardOptimizeOption( .{} );


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
  });

  // This adds the executable module to the build graph,
  // which is the main entry point of the application.
  const exe = b.addExecutable(
  .{
    .name        = "ZiguezonEngine",
    .root_module = exe_mod,
    .use_llvm    = false,
  });

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
    .root_source_file = b.path( "src/defs.zig" ),
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
  exe.root_module.addImport( "engineInterface", engine_interface );


  // ================================ COMMANDS ================================

  // This creates a Run step in the build graph, to be executed when call, or if
  // another step is evaluated that depends on it ( similar to Makefile targets ).
  const run_cmd = b.addRunArtifact( exe );
  run_cmd.step.dependOn( b.getInstallStep() );
  if( b.args )| args |{ run_cmd.addArgs( args ); }

  const run_step = b.step( "run", "Run the debug environment" );
  run_step.dependOn( &run_cmd.step );

  // This creates a step for the ping game
  const ping_step = b.step( "ping", "Run the ping game" );
  const ping_cli_cmd = b.addSystemCommand( &.{ "zig", "build", "run", "-Dengine_interface_path=exampleGames/ping/engineInterface.zig" });
  ping_step.dependOn( &ping_cli_cmd.step );

  // This creates a step for the floppy game
  const floppy_step = b.step( "floppy", "Run the floppy game" );
  const floppy_cli_cmd = b.addSystemCommand( &.{ "zig", "build", "run", "-Dengine_interface_path=exampleGames/floppy/engineInterface.zig" });
  floppy_step.dependOn( &floppy_cli_cmd.step );

  // This creates a step for the labyrinther game
  const labyrinth_step = b.step( "labyrinth", "Run the labyrinth game" );
  const labyrinth_cli_cmd = b.addSystemCommand( &.{ "zig", "build", "run", "-Dengine_interface_path=exampleGames/labyrinther/engineInterface.zig" });
  labyrinth_step.dependOn( &labyrinth_cli_cmd.step );

  // This creates a step for the dehexer game
  const dehexer_step = b.step( "dehexer", "Run the dehexer game" );
  const dehexer_cli_cmd = b.addSystemCommand( &.{ "zig", "build", "run", "-Dengine_interface_path=exampleGames/dehexer/engineInterface.zig" });
  dehexer_step.dependOn( &dehexer_cli_cmd.step );


  // ================================ TESTS ================================

  const exe_unit_tests     = b.addTest(.{ .root_module = exe_mod });
  const run_exe_unit_tests = b.addRunArtifact( exe_unit_tests );

  // Similar to creating the run step earlier, this exposes a `test` step to the `zig build --help` menu,
  // providing a way for the user to request running the unit tests instead of the main application.
  const test_step = b.step( "test", "Run unit tests" );
  test_step.dependOn( &run_exe_unit_tests.step );
}