//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import( "std" );
const h   = @import( "headers.zig" );

const eng = @import( "core/engine.zig" );

pub fn main() !void
{
  h.initAll();
  defer h.deinitAll();

  eng.G_NG.changeState( .LAUNCHED );

  _ = eng.G_NG.entityManager.addEntity(
    .{
      .id     = 0,
      .active = true,
      .pos    = .{ .x = 50, .y = 50 },
      .rotPos = 0.0,
      .shape  = .TRIA,
      .scale  = .{ .x = 50, .y = 50 },
      .colour = h.rl.Color.red,
    });

  _ = eng.G_NG.entityManager.addEntity(
    .{
      .id     = 1,
      .active = true,
      .pos    = .{ .x = 150, .y = 150 },
      .rotPos = 0.0,
      .shape  = .RECT,
      .scale  = .{ .x = 50, .y = 50 },
      .colour = h.rl.Color.blue,
    });

  _ = eng.G_NG.entityManager.addEntity(
    .{
      .id     = 2,
      .active = true,
      .pos    = .{ .x = 250, .y = 250 },
      .rotPos = 0.0,
      .shape  = .CIRC,
      .scale  = .{ .x = 50, .y = 50 },
      .colour = h.rl.Color.green,
    });

  _ = eng.G_NG.entityManager.addEntity(
    .{
      .id     = 3,
      .active = true,
      .pos    = .{ .x = 350, .y = 350 },
      .rotPos = 0.0,
      .shape  = .DIAM,
      .scale  = .{ .x = 50, .y = 50 },
      .colour = h.rl.Color.yellow,
    });

  eng.G_NG.loopLogic();

  eng.G_NG.changeState( .CLOSED );
}

//test "example test"
//{
//  var list = std.ArrayList( i32 ).init( std.testing.allocator );   defer list.deinit();
//
//  try list.append( 42 );
//  try std.testing.expectEqual( @as( i32, 42 ), list.pop() );
//}
