//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import( "std" );
const h   = @import( "headers.zig" );

pub fn main() !void
{
  h.timer.initTimer();
  h.logger.initFile();
  defer h.logger.deinitFile();

  while( true )
  {
    h.logger.log( .TRACE, 1, "This is a trace message",   @src() );
    h.logger.log( .DEBUG, 2, "This is a debug message",   @src() );
    h.logger.log( .WARN , 3, "This is a warning message", @src() );
    h.logger.log( .INFO , 4, "This is an info message",   @src() );
    h.logger.log( .ERROR, 5, "This is an error message",  @src() );
  }

}

//test "example test"
//{
//  var list = std.ArrayList( i32 ).init( std.testing.allocator );   defer list.deinit();
//
//  try list.append( 42 );
//  try std.testing.expectEqual( @as( i32, 42 ), list.pop() );
//}
