//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import( "std" );
const h   = @import( "headers.zig" );

const eng = @import( "core/engine.zig" );

pub fn main() !void
{
  eng.G_NG.changeState( .LAUNCHED );

  eng.G_NG.runGameLoop();

  eng.G_NG.changeState( .CLOSED );
}

//test "example test"
//{
//  var list = std.ArrayList( i32 ).init( std.testing.allocator );   defer list.deinit();
//
//  try list.append( 42 );
//  try std.testing.expectEqual( @as( i32, 42 ), list.pop() );
//}
