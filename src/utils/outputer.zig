const std = @import( "std" );
const def = @import( "defs" );

pub fn demoStdout() !void
{
  // buffered or unbuffered, buffer when doing many small writes
  const buffered = true;
  var   buffer : [ 4096 ]u8 = undefined;

  const write_buffer = if ( buffered ) &buffer else &.{};
  var output_writer: std.fs.File.Writer = std.fs.File.stdout().writer(write_buffer);

  // IMPORTANT: capture an interface pointer
  const writer: *std.Io.Writer = &output_writer.interface;
  try writer.writeAll( "Hello world\n" );
  try writer.flush();
}

//pub fn demoStdin(allocator: std.mem.Allocator, useFixed: bool) !void
//{
//  // buffered or unbuffered, buffer when doing many small reads
//  const buffered = true;
//  var buffer: [4096]u8 = undefined;
//  const read_buffer = if (buffered) &buffer else &.{};
//
//  var input_reader: std.fs.File.Reader = std.fs.File.stdin().reader(read_buffer);
//  // IMPORTANT: capture an interface pointer
//  const reader: *std.Io.Reader = &input_reader.interface;
//
//  const limit = 1024;
//  if (useFixed)
//  {
//    // must be large enough for read to succeed
//    var write_buffer: [1024]u8 = undefined;
//    var writer_fixed = std.Io.Writer.fixed(&write_buffer);
//    const len = try reader.streamDelimiterLimit(&writer_fixed, '\n', .limited(limit));
//    std.debug.print("Read fixed: {d}:{s}\n", .{ len, writer_fixed.buffered() });
//  }
//  else
//  {
//    var writer_alloc = std.Io.Writer.Allocating.init(allocator);
//    defer writer_alloc.deinit();
//    const writer = &writer_alloc.writer;
//    const len = try reader.streamDelimiterLimit(writer, '\n', .limited(limit));
//    std.debug.print("Read alloc: {d}:{s}\n", .{ len, writer_alloc.written() });
//  }
//}