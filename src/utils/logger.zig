const std    = @import( "std" );
const timer  = @import( "timer.zig" );
const writer = @import( "writer.zig" );

// ================================ PREAMBLE ================================

// This file defines helper functions to conditionally print debug info based on the following enum's value
pub const LogLevel = enum
{
  // These values are used to control the verbosity of debug output.
  // The higher the value, the more verbose the output.
  // This means each value prints all values below it.

  NONE,  // No output ( deactivates the debug print system entirely )
  ERROR, // Error messages only
  WARN,  // Warnings about potential issues
  INFO,  // Informational messages
  DEBUG, // Debug messages ( e.g. variable values, state changes )
  FUNCT, // Function calls and return logging
  TRACE, // Detailed tracing of execution flow
};

// Global configuration variables for the debug logging system
const G_LOG_LVL : LogLevel = LogLevel.DEBUG; // Set the global log level for debug printing

const SHOW_ID_MSGS   : bool = true;  // If true, messages with id will not be omitted
const SHOW_TIMESTAMP : bool = true;  // If true, messages will include a timestamp of the system clock
const SHOW_LAPTIME   : bool = false; // If true, the timestamp, if present, will be the time since the last message instead of the system clock
const SHOW_MSG_SRC   : bool = true;  // If true, messages will include the source file, line number, and function name of the call location

// ================================ CORE FUNCTIONS ================================

// This function is used to print debug messages based on the inputed DebugPrint level.
pub fn log( level : LogLevel, id : u32, message : [] const u8, callLocation : ?std.builtin.SourceLocation ) void
{
  // LOGMSG OUTPUT EXAMPLE :
  // [DEBUG] (1) - 2025-10-01 12:34:56 - main.zig:42 (main) - This is a debug message

  // If the global log level is NONE, we instantly return, as nothing will ever be logged anyways
  comptime { if( G_LOG_LVL == LogLevel.NONE ) return; }

  // If the level is higher than the global log level, do nothing
  if( @intFromEnum( level ) > @intFromEnum( G_LOG_LVL )) return;

  // If the message is IDed and SHOW_ID_MSGS is false, do nothing
  if( !SHOW_ID_MSGS and id != 0 ) return;

  // Get the output writer based on the configuration
  var output = writer.writeOut{ .None = {} }; // Default to no output
  output.init() catch | err |
  {
    std.debug.print( "Failed to initialize writer: {}\n", .{ err });
    output = writer.writeOut{ .Cons = std.io.getStdErr() }; // Fallback to console output
  };

  // ================ LOGGING LOGIC ================

  // Show the log level as a string
  logLevel( &output, level ) catch | err |
  {
    std.debug.print( "Failed to write log level: {}\n", .{ err });
    return;
  };

  // Shows the message id if different from 0
  if( id != 0 )
  {
    output.print( "( {d} ) ", .{ id }) catch | err |
    {
      std.debug.print( "Failed to write message id: {}\n", .{ err });
      return;
    };
  }

  logChar( &output, '-' ); // Print a separator character

  // Shows the time of the message relative to the system clock if SHOW_TIMESTAMP is true
  logTime( &output ) catch | err |
  {
    std.debug.print( "Failed to write timestamp: {}\n", .{ err });
    return;
  };

  logChar( &output, '-' ); // Print a separator character

  // Shows the file location if SHOW_MSG_SRC is true
  logLoc( &output, callLocation ) catch | err |
  {
    std.debug.print( "Failed to write source location: {}\n", .{ err });
    return;
  };

  logChar( &output, '-' ); // Print a separator character

  // Prints the actual message
  output.print( "{s}\n", .{ message }) catch | err |
  {
    std.debug.print( "Failed to write message: {}\n", .{ err });
    return;
  };
}

// ================================ HELPER FUNCTIONS ================================

// Print the character followed by a space
fn logChar( output : *writer.writeOut, c : u8 ) void
{
  output.print( "{c} ", .{ c }) catch | err |
  {
    std.debug.print( "Failed to write character: {}\n", .{ err });
    return;
  };
}

fn logLevel( output : *writer.writeOut, level: LogLevel ) !void
{
  switch ( level )
  {
    LogLevel.NONE  => try output.sprint( "[NONE ] " ),
    LogLevel.ERROR => try output.sprint( "[ERROR] " ),
    LogLevel.WARN  => try output.sprint( "[WARN ] " ),
    LogLevel.INFO  => try output.sprint( "[INFO ] " ),
    LogLevel.DEBUG => try output.sprint( "[DEBUG] " ),
    LogLevel.FUNCT => try output.sprint( "[FUNCT] " ),
    LogLevel.TRACE => try output.sprint( "[TRACE] " ),
  }
}

fn logTime( output : *writer.writeOut ) !void
{
  if( SHOW_TIMESTAMP )
  {
    var now : i128 = undefined; // Get the elapsed time since the epoch

    if( SHOW_LAPTIME ){ now = timer.getLapTime(); }     // Get the lap time if SHOW_LAPTIME is true
    else              { now = timer.getElapsedTime(); } // Get the elapsed time since the epoch

    const sec  : u64 = @intCast( @divTrunc( now, @as( i128, std.time.ns_per_s )));
    const nano : u64 = @intCast( @rem(      now, @as( i128, std.time.ns_per_s )));

    // Print the time in seconds and nanoseconds
    try output.print( "{d}.{d:0>9} ", .{ sec, nano });
  }
}

fn logLoc( output : *writer.writeOut, callLocation : ?std.builtin.SourceLocation ) !void
{
  if( SHOW_MSG_SRC )
  {
    if( callLocation )| loc |
    {
      // If the call location is defined, print the file, line, and function name
      try output.print( "{s}:{d} ( {s} ) ", .{ loc.file, loc.line, loc.fn_name });
    }
    else
    {
      // If the call location is undefined, print "UNDEFINED"
      try output.print( "UNDEFINED ", .{} );
    }
  }
}
