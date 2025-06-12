const std = @import( "std" );

const USE_LOG_FILE   : bool = true; // If true, log messages will be written to a file instead of stdout/stderr
const G_LOG_FILE     : [] const u8 = "debug.log"; // The file to write log messages to if USE_LOG_FILE is true

// This union defines the output type for the debug logging system.
pub const writeOut = union( enum )
{
  // TODO : de-engineer this and simply use a File type

  // This union allows for different output types, such as console or file.
  File : std.fs.File, // Log file output
  Cons : std.fs.File, // Console output
  None : void, // This is used to indicate no output chosen

  // ================ LOGIC ================

  pub fn isInit( self: writeOut ) bool
  {
    return switch( self )
    {
      .File => | _ | true,  // If we have a file, we consider it initialized
      .Cons => | _ | true,  // If we have a console output, we consider it initialized
      .None => | _ | false, // No output is initialized
    };
  }

  pub fn usesFile( self: writeOut ) bool
  {
    return switch( self )
    {
      .File => | _ | true,  // File output is used
      .Cons => | _ | false, // Console output is not a file
      .None => | _ | false, // No output is not a file
    };
  }

  pub fn init( self: *writeOut ) !void
  {
    // If already initialized, do nothing
    if ( self.isInit() )
    {
      std.debug.print( "Writer is already initialized.\n", .{} );
      return;
    }

    // If we have no log file usage, set the console as the output
    if( !USE_LOG_FILE )
    {
      self.* = writeOut{ .Cons = std.io.getStdErr() }; // Set console output
      return;
    }

    // Else, we try to create & open the log file
    const log_file = try std.fs.cwd().createFile( G_LOG_FILE, .{ .truncate = false });
    //try log_file.open( .{ .append = true, .read = true, .write = true });

    // If we successfully opened the log file, set it as the output and return
    self.* = writeOut{ .File = log_file };
  }

  pub fn deinit( self: *writeOut ) void
  {
    if ( !self.isInit() )
    {
      std.debug.print( "Writer is not initialized, nothing to deinitialize.\n", .{} );
      return;
    }
    switch( self )
    {
      .File => | file | file.close(),
      .Cons => | _    | {}, // No action needed for console output
      .None => | _    | {}, // No action needed for no output
    }
    self = .{ .None = {} }; // Reset to None after deinitialization
  }

  pub fn print( self : writeOut, comptime format : []const u8, args : anytype ) !void
  {
    switch( self )
    {
      .File => | file | try file.writer().print( format, args ), // File output uses the file writer
      .Cons => | cons | try cons.writer().print( format, args ), // Console output uses the writer directly
      .None => | _    |         std.debug.print( format, args ), // Default to debug print if no output is set
    }
  }

  pub fn sprint( self : writeOut, comptime format : []const u8 ) !void
  {
    switch( self )
    {
      .File => | file | try file.writer().print( format, .{} ), // File output uses the file writer
      .Cons => | cons | try cons.writer().print( format, .{} ), // Console output uses the writer directly
      .None => | _    |         std.debug.print( format, .{} ), // Default to debug print if no output is set
    }
  }
};