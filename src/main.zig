//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import( "std" );
const h = @import( "header.zig" );

pub fn main() !void
{
  h.timer.initEpoch();
  h.timer.initLapEpoch();

  h.logger.log( .DEBUG, 0, "This is a debug message",    @src() );
  h.logger.log( .INFO,  1, "This is an info message",    @src() );
  h.logger.log( .ERROR, 2, "This is an error message",   @src() );
  h.logger.log( .FUNCT, 3, "This is a function message", @src() );
  h.logger.log( .TRACE, 4, "This is a trace message",    @src() );
}

//test "example test"
//{
//  var list = std.ArrayList( i32 ).init( std.testing.allocator );   defer list.deinit();
//
//  try list.append( 42 );
//  try std.testing.expectEqual( @as( i32, 42 ), list.pop() );
//}
