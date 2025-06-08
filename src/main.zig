const std      = @import( "std" );
const stdAlloc = std.mem.Allocator;
const logMsg   = @import( "printLog.zig" ).logMsg;

pub fn main() !void
{
	logMsg( .DEBUG, 1, "This is a debug message",    .{ .file = @src(), .line = @line() });
	logMsg( .INFO,  0, "This is an info message",    .{ .file = @src(), .line = @line() });
	logMsg( .ERROR, 2, "This is an error message",   .{ .file = @src(), .line = @line() });
	logMsg( .FUNCT, 0, "This is a function message", .{ .file = @src(), .line = @line() });
	logMsg( .TRACE, 0, "This is a trace message",    .{ .file = @src(), .line = @line() });
}

test "simple test"
{
	var list = std.ArrayList( i32 ).init( std.testing.allocator );   defer list.deinit();

	try list.append( 42 );
	try std.testing.expectEqual( @as( i32, 42 ), list.pop() );
}
