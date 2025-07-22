const std = @import( "std" );
const rlz = @import( "raylib_zig" );

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build( b: *std.Build ) void
{
  // ================================ BUILD CONFIGURATION ================================

  // This is the "standard" build target, which is the default target for the
  // current platform and architecture. It is used to compile the code for the
  // current platform and architecture, and it is the default target for the
  // build system.
  const target = b.standardTargetOptions(.{} );
  const optimize = b.standardOptimizeOption(.{} );

  // This is a build option that allows the user to specify the path to the
  // game hook implementations. It is used to allow the user to specify a custom
  // path to the game hook implementations, which can be useful for testing or
  // development purposes.
  const tmp_game_hooks_path = b.option(
    []const u8,
    "game_hooks_path",
    "Path to the gameHooks implementations (e.g., exampleGames/ping/gameHooks.zig)"
  );

  // This sets the default path for the game hooks module to the template
  const game_hooks_path = if( tmp_game_hooks_path )| path | path else "exampleGames/_template/gameHooks.zig";


  // ================================ EXECUTABLE ================================

  // This creates a module for the executable itself
  const exe_mod = b.createModule(
  .{
    .root_source_file = b.path( "src/main.zig" ),
    .target   = target,
    .optimize = optimize,
  });

  // This adds the executable module to the build graph,
  // which is the main entry point of the application.
  const exe = b.addExecutable(
  .{
    .name = "ZiguezonEngine",
    .root_module = exe_mod,
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

  // This adds the game hooks module, which is expected to contain the game-specific
  // hook implementations. The `hook_path` variable is used to specify the path to
  // the game hook implementations, allowing the user to specify a custom path.
  const game_hooks = b.createModule(
  .{
    .root_source_file = b.path( game_hooks_path ), // NOTE : This path is user defined at build time
    .target   = target,
    .optimize = optimize,
  });
  game_hooks.addImport( "raylib", raylib );
  game_hooks.addImport( "defs", defs );
  exe.root_module.addImport( "gameHooks", game_hooks );


  // ================================ COMMANDS ================================

  // This creates a Run step in the build graph, to be executed when call, or if
  // another step is evaluated that depends on it ( similar to Makefile targets ).
  const run_cmd = b.addRunArtifact( exe );
  run_cmd.step.dependOn( b.getInstallStep() );
  if( b.args )| args |{ run_cmd.addArgs( args ); }

  const run_step = b.step( "run", "Run the template project" );
  run_step.dependOn( &run_cmd.step );

  // This creates a step for the ping game
  const ping_step = b.step( "ping", "Run the ping game" );
  const ping_cli_cmd = b.addSystemCommand( &.{ "zig", "build", "run", "-Dgame_hooks_path=exampleGames/ping/gameHooks.zig" });
  ping_step.dependOn( &ping_cli_cmd.step );

  // This creates a step for the floppy game
  const floppy_step = b.step( "floppy", "Run the floppy game" );
  const floppy_cli_cmd = b.addSystemCommand( &.{ "zig", "build", "run", "-Dgame_hooks_path=exampleGames/floppy/gameHooks.zig" });
  floppy_step.dependOn( &floppy_cli_cmd.step );

  // ================================ TESTS ================================

  const exe_unit_tests     = b.addTest(.{ .root_module = exe_mod });
  const run_exe_unit_tests = b.addRunArtifact( exe_unit_tests );

  // Similar to creating the run step earlier, this exposes a `test` step to the `zig build --help` menu,
  // providing a way for the user to request running the unit tests instead of the main application.
  const test_step = b.step( "test", "Run unit tests" );
  test_step.dependOn( &run_exe_unit_tests.step );
}