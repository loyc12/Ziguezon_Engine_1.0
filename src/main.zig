//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import( "std" );
const rlz = @import( "raylib_zig" );
const h   = @import( "headers.zig" );

const eng = @import( "core/engine.zig" );

pub fn main() !void
{
  h.initAll();
  eng.G_NG.changeState( .LAUNCHED );

  rlz.init( .{
    .window_title = "Zig Game Engine",
    .window_width = 800,
    .window_height = 600,
    .window_flags = .{ .resizable, .vsync_hint },
  }) catch |err| {
    h.log( .ERROR, 0, @src(), "Failed to initialize Raylib: {}", .{ err });
    return err;
  };
  defer rlz.deinit();
  rlz.setTargetFPS( 60 );

  rlz.openWindow() catch |err| {
    h.log( .ERROR, 0, @src(), "Failed to open window: {}", .{ err });
    return err;
  };
  defer rlz.closeWindow();

  eng.G_NG.runGameLoop();

  eng.G_NG.changeState( .CLOSED );
  h.deinitAll();
}

//test "example test"
//{
//  var list = std.ArrayList( i32 ).init( std.testing.allocator );   defer list.deinit();
//
//  try list.append( 42 );
//  try std.testing.expectEqual( @as( i32, 42 ), list.pop() );
//}
