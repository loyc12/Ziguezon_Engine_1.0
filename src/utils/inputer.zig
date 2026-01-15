const std = @import( "std" );
const def = @import( "defs" );

const LINE_DELIMITER = '\n';

// TODO : figure me out better

//pub fn demoStdin( allocator : std.mem.Allocator, useFixed : bool ) !void
//{
//  // buffered or unbuffered, buffer when doing many small reads
//  const buffered : bool     = true;
//  var   buffer   : [ 4096 ]u8 = undefined;
//
//  const read_buffer = if( buffered ) &buffer else &.{};
//
//  var input_reader : std.fs.File.Reader = std.fs.File.stdin().reader( read_buffer );
//
//  // IMPORTANT: capture an interface pointer
//  const reader: *std.Io.Reader = &input_reader.interface;
//
//  const limit = 1024;
//  if( useFixed )
//  {
//    // must be large enough for read to succeed
//    var write_buffer : [ 1024 ]u8 = undefined;
//    var writer_fixed = std.Io.Writer.fixed( &write_buffer );
//
//    const len = try reader.streamDelimiterLimit( &writer_fixed, '\n', .limited( limit ));
//    std.debug.print( "Read fixed: {d}:{s}\n", .{ len, writer_fixed.buffered() });
//  }
//  else
//  {
//    var writer_alloc = std.Io.Writer.Allocating.init( allocator );
//    defer writer_alloc.deinit();
//
//    const writer = &writer_alloc.writer;
//
//    const len = try reader.streamDelimiterLimit( writer, '\n', .limited( limit ));
//    std.debug.print("Read alloc: {d}:{s}\n", .{ len, writer_alloc.written() });
//  }
//}

pub const QuickfileData = struct
{
  isOpened : bool = false,
  eof      : bool = false,
  row      : u32  = 0,
  column   : u32  = 0,

  path   : [] const u8,
  file   : std.fs.File        = undefined,
  reader : std.fs.File.Reader = undefined,

  lineBuffer  : ?[]u8       = null,
  readBuffer  : [ 4096 ] u8 = undefined,
//writeBuffer : [ 4096 ] u8 = undefined,
};

pub fn openFile( data : *QuickfileData ) void
{
  if( data.isOpened )
  {
    def.log( .ERROR, 0, @src(), "File already opened '{s}'", .{ data.path });
    return;
  }

  if( std.fs.cwd().openFile( data.path, .{} ))| f |{ data.file = f; }
  else | err |
  {
    def.log( .ERROR, 0, @src(), "Failed to open file '{s}' : {}", .{ data.path, err });
    data.isOpened = false;
    return;
  }

  data.isOpened = true;
  data.reader   = data.file.reader( &data.readBuffer );
  data.column   = 0;
  data.row      = 0;
  data.eof      = false;
}

pub fn closeFile( data : *QuickfileData ) void
{
  if( !data.isOpened )
  {
    def.log( .WARN, 0, @src(), "Cannot close file '{s}' : already closed", .{ data.path });
    return;
  }

  data.file.close();
  data.isOpened = false;
}

pub fn readFileLine( data : *QuickfileData ) void
{
  if( !data.isOpened )
  {
    def.log( .WARN, 0, @src(), "Cannot read from file '{s}' : file is closed", .{ data.path });
    return;
  }

  if( data.reader.interface.takeDelimiter( LINE_DELIMITER ))| l |{ data.lineBuffer = l; }
  else | err |
  {
    def.log( .ERROR, 0, @src(), "Failed to read file line : {}", .{ err });
    return;
  }

  data.eof = ( data.lineBuffer == null );
  if( !data.eof ){ data.row += 1; }
}

//pub fn readFileMax( data : *QuickfileData ) void
//{
//  data.reader.interface.
//}