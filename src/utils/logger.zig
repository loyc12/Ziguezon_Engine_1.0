const std   = @import( "std" );
const timer = @import( "timer.zig" );

// This file defines helper functions to conditionally print debug info based on the following enum's value
// NOTE : this essentially implements a shittier version of std.log...

//pub fn foo() !void {
//  const logt = std.log.Logger.init(std.io.getStdErr());
//  logt.err("An error occurred: {}", .{"File not found"});
//  logt.warn("This is a warning");
//  logt.info("Application started");
//  logt.debug("Debugging value: {}", .{42});
//}

// ================================ DEFINITIONS ================================

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
  TRACE, // Detailed tracing of execution flow
};

// Global configuration variables for the debug logging system
const G_LOG_LVL : LogLevel = LogLevel.DEBUG; // Set the global log level for debug printing

const USE_LOG_FILE   : bool = false;                     // If true, log messages will be written to a file instead of stdout/stderr
const LOG_FILE_NAME  : [] const u8 = "debug.log";        // The file to write log messages to if USE_LOG_FILE is true
var   G_LOG_FILE     : std.fs.File = std.io.getStdErr(); // The file to write log messages in ( default is stderr )
var   G_IsFileOpened : bool = false;                     // Flag to check if the log file is opened ( and different from stderr )

const SHOW_ID_MSGS   : bool = true;  // If true, messages with id will not be omitted
const SHOW_TIMESTAMP : bool = true;  // If true, messages will include a timestamp of the system clock
const SHOW_LAPTIME   : bool = false; // If true, the timestamp, if present, will be the time since the last message instead of the system clock
const SHOW_MSG_SRC   : bool = true;  // If true, messages will include the source file, line number, and function name of the call location

// ================================ CORE FUNCTIONS ================================

pub fn qlog( level : LogLevel, id : u32, callLocation : ?std.builtin.SourceLocation, comptime message : [] const u8) void
{
  // Call the log function with no arguments
  log( level, id, callLocation, message, .{} );
}

pub fn log( level : LogLevel, id : u32, callLocation : ?std.builtin.SourceLocation, comptime message : [] const u8, args : anytype ) void
{
  // LOG EXAMPLE :
  // [DEBUG] (1) - 2025-10-01 12:34:56 - main.zig:42 (main) - This is a debug message

  // If the global log level is NONE, we instantly return, as nothing will ever be logged anyways
  if( comptime G_LOG_LVL == LogLevel.NONE ) return;

  // If the level is higher than the global log level, do nothing
  if( @intFromEnum( level ) > @intFromEnum( G_LOG_LVL )) return;

  // If the message is IDed and SHOW_ID_MSGS is false, do nothing
  if( comptime !SHOW_ID_MSGS and id != 0 ) return;

  if( level == .TRACE ) return; // TODO : Implement the trace system, to log/unlog functions when they are called and exited

  // ================ LOGGING LOGIC ================

  // Show the log level as a string
  logLevel( level ) catch | err |
  {
    std.debug.print( "Failed to write log level: {}\n", .{ err });
    return;
  };

  // Shows the message id if different from 0
  if( id != 0 )
  {
    G_LOG_FILE.writer().print( "{d:0>4} ", .{ id }) catch | err |
    {
      std.debug.print( "Failed to write message id: {}\n", .{ err });
      return;
    };
  }


  // Shows the time of the message relative to the system clock if SHOW_TIMESTAMP is true
  logTime() catch | err |
  {
    std.debug.print( "Failed to write timestamp: {}\n", .{ err });
    return;
  };

  logChar( '-' ); // Print a separator character

  // Shows the file location if SHOW_MSG_SRC is true
  logLoc( callLocation ) catch | err |
  {
    std.debug.print( "Failed to write source location: {}\n", .{ err });
    return;
  };

  logChar( '-' ); // Print a separator character

  // Prints the actual message
  G_LOG_FILE.writer().print( message, args ) catch | err |
  {
    std.debug.print( "Failed to write message: {}\n", .{ err });
    return;
  };

  G_LOG_FILE.writer().print( "\n", .{} ) catch | err |
  {
    std.debug.print( "Failed to write newline: {}\n", .{ err });
    return;
  };
}

// ================================ HELPER FUNCTIONS ================================

pub fn initFile() void
{
  if( comptime !USE_LOG_FILE ){ return; } // If we are not using a log file, do nothing

  // If we are using a log file, try to open it
  G_LOG_FILE = std.fs.cwd().createFile( LOG_FILE_NAME, .{ .truncate = false }) catch | err |
  {
    std.debug.print( "Failed to create or open log file '{s}': {}\nLogging to stderr isntead\n", .{ LOG_FILE_NAME, err });
    return;
  };
  G_IsFileOpened = true; // Set the flag to true as we successfully opened the file
}

pub fn deinitFile() void
{
  if( comptime !USE_LOG_FILE ){ return; } // If we are not using a log file, do nothing

  // If we are using a log file, close it
  if( G_IsFileOpened )
  {
    G_LOG_FILE.close();
    G_IsFileOpened = false; // Set the flag to false as we closed the file
  }
}

fn logChar( c : u8 ) void // Print the character followed by a space
{
  G_LOG_FILE.writer().print( "{c} ", .{ c }) catch | err |
  {
    std.debug.print( "Failed to write character: {}\n", .{ err });
    return;
  };
}

fn logLevel( level: LogLevel ) !void
{
  var lvl : []const u8 = undefined; // Variable to hold the log level string
  switch ( level )
  {
    LogLevel.NONE  => lvl = "NONE ",
    LogLevel.ERROR => lvl = "ERROR",
    LogLevel.WARN  => lvl = "WARN ",
    LogLevel.INFO  => lvl = "INFO ",
    LogLevel.DEBUG => lvl = "DEBUG",
    LogLevel.TRACE => lvl = "TRACE",
  }
  try G_LOG_FILE.writer().print( "[{s}] ", .{ lvl }); // Print the log level string followed by a space
}

fn logTime() !void
{
  if( comptime !SHOW_TIMESTAMP ) return; // If we are not showing the timestamp, do nothing

  var now : i128 = undefined; // Get the elapsed time since the epoch

  if( SHOW_LAPTIME ){ now = timer.getLapTime(); }     // Get the lap time if SHOW_LAPTIME is true
  else              { now = timer.getElapsedTime(); } // Get the elapsed time since the epoch

  const sec  : u64 = @intCast( @divTrunc( now, @as( i128, std.time.ns_per_s )));
  const nano : u64 = @intCast( @rem(      now, @as( i128, std.time.ns_per_s )));

  // Print the time in seconds and nanoseconds
  try G_LOG_FILE.writer().print( "{d}.{d:0>9} ", .{ sec, nano });
}

fn logLoc( callLocation : ?std.builtin.SourceLocation ) !void
{
  if( comptime !SHOW_MSG_SRC ){ return; } // If we are not showing the source location, do nothing

  if( callLocation )| loc |
  {
    // If the call location is defined, print the file, line, and function name
    try G_LOG_FILE.writer().print( "{s}:{d} ( {s} ) ", .{ loc.file, loc.line, loc.fn_name });
  }
  else
  {
    // If the call location is undefined, print "UNDEFINED"
    try G_LOG_FILE.writer().print( "{s} ", .{ "UNLOCATED" });
  }
}
