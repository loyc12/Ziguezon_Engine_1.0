const std = @import( "std" );
const def = @import( "defs" );

// TODO : figure me out better

var outputBuffer : [ 4096 ]u8 = undefined;
var errorBuffer  : [ 4096 ]u8 = undefined;

// Buffered for multiple small writes
pub fn outBuf() !void
{
  var output_writer: std.fs.File.Writer = std.fs.File.stdout().writer( outputBuffer );

  // IMPORTANT: capture an interface pointer
  const writer: *std.Io.Writer = &output_writer.interface;

  try writer.writeAll( "Hello world\n" );
  try writer.flush();
}
pub fn errBuf() !void
{
  var output_writer: std.fs.File.Writer = std.fs.File.stderr().writer( errorBuffer );

  // IMPORTANT: capture an interface pointer
  const writer: *std.Io.Writer = &output_writer.interface;

  try writer.writeAll( "Hello world\n" );
  try writer.flush();
}

// Unbuffered for single large writes
pub fn outUnbuf() !void
{
  var output_writer: std.fs.File.Writer = std.fs.File.stdout().writer( &.{} );

  // IMPORTANT: capture an interface pointer
  const writer: *std.Io.Writer = &output_writer.interface;

  try writer.writeAll( "Hello world\n" );
  try writer.flush();
}
pub fn errUnbuf() !void
{
  var output_writer: std.fs.File.Writer = std.fs.File.stderr().writer( &.{} );

  // IMPORTANT: capture an interface pointer
  const writer: *std.Io.Writer = &output_writer.interface;

  try writer.writeAll( "Hello world\n" );
  try writer.flush();
}
