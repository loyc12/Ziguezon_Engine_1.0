const std = @import( "std" );
const def = @import( "defs" );

// This file defines helper functions to conditionally print debug info based on the following enum's value
// NOTE : this essentially implements a shittier version of std.log...

// ================================ DEFINITIONS ================================

pub const LogLevel = enum
{
  // These values are used to control the verbosity of debug output.
  // The higher the value, the more verbose the output.
  // This means each value prints all values below it.

  NONE,  // No output ( deactivates the debug print system entirely )
  ERROR, // Error messages ( critical issues that prevent normal execution )
  WARN,  // Warnings   ( non critical issues that do not prevent normal execution )
  INFO,  // Long term informational messages ( key events in the program )
  DEBUG, // tracing of abnormal execution flow ( unhappy path ) and short term debugging messages
  TRACE, // Tracing of normal execution flow   ( happy path )
};

// Global configuration variables for the debug logging system
pub const G_LOG_LVL : LogLevel = .DEBUG; // Set the global log level for debug printing

pub const SHOW_ID_MSGS   : bool = true;  // If true, messages with id will not be omitted
pub const SHOW_TIMESTAMP : bool = true;  // If true, messages will include a timestamp of the system clock
pub const SHOW_LAPTIME   : bool = false; // If true, the timestamp, if present, will be the time since the last message instead of the system clock
pub const SHOW_MSG_SRC   : bool = true;  // If true, messages will include the source file, line number, and function name of the call location
pub const ADD_PREC_NL    : bool = true;  // If true, a newline will be before the actual message, to make it more readable

pub const USE_LOG_FILE   : bool = false;                     // If true, log messages will be written to a file instead of stdout/stderr
pub const LOG_FILE_NAME  : [] const u8 = "debug.log";        // The file to write log messages to if USE_LOG_FILE is true
var       G_LOG_FILE     : std.fs.File = std.io.getStdErr(); // The file to write log messages in ( default is stderr )
var       G_IsFileOpened : bool = false;                     // Flag to check if the log file is opened ( and different from stderr )

// TODO : have each log level be printed in its own file, on top of the shared main one

// ================================ LOGGING TIMER ================================

var LOG_TIMER  : def.timer.timer = .{};
var IS_LT_INIT : bool = false; // Whether the timer has been initialized

// NOTE : Initialize the log timer before using it, otherwise it will not work
pub fn initLogTimer() void
{
  LOG_TIMER.qInit( def.timer.getNow(), 0 );
  IS_LT_INIT = true;
}

// Returns the elapsed time since the global epoch
fn getLogElapsedTime() i128
{
  if( !IS_LT_INIT ){ return def.timer.getNow(); } // If the timer is not initialized, return now

  LOG_TIMER.incrementTo( def.timer.getNow() );
  return LOG_TIMER.getElapsedTime();
}

// Returns the elapsed time since the last time increment
fn getLogDeltaTime() i128
{
  if( !IS_LT_INIT ){ return 0; } // If the timer is not initialized, return 0

  LOG_TIMER.incrementTo( def.timer.getNow() );
  return LOG_TIMER.delta;
}

// ================================ CORE FUNCTIONS ================================

pub fn qlog( level : LogLevel, id : u32, callLocation : ?std.builtin.SourceLocation, comptime message : [:0] const u8 ) void
{
  // Call the log function with no arguments
  log( level, id, callLocation, message, .{} );
}

pub fn log( level : LogLevel, id : u32, callLocation : ?std.builtin.SourceLocation, comptime message : [:0] const u8, args : anytype ) void
{
  // LOG EXAMPLE :
  // [DEBUG] (1) - 2025-10-01 12:34:56 - main.zig:42 (main) - This is a debug message

  // If the global log level is NONE, we instantly return, as nothing will ever be logged anyways
  if( comptime G_LOG_LVL == LogLevel.NONE ) return;

  // If the level is higher than the global log level, do nothing
  if( @intFromEnum( level ) > @intFromEnum( G_LOG_LVL )) return;

  // If the message is IDed and SHOW_ID_MSGS is false, do nothing
  if( comptime !SHOW_ID_MSGS and id != 0 ) return;

  // TODO : Implement the trace system properly, to log/unlog functions when they are called and exited

  // ================ LOGGING LOGIC ================

  // Show the log level as a string
  logLevel( level ) catch | err |
  {
    std.debug.print( "Failed to write log level : {}\n", .{ err });
    return;
  };

  // Shows the message id if different from 0
  if( id != 0 )
  {
    G_LOG_FILE.writer().print( "{d:0>4} ", .{ id }) catch | err |
    {
      std.debug.print( "Failed to write message id : {}\n", .{ err });
      return;
    };
  }


  // Shows the time of the message relative to the system clock if SHOW_TIMESTAMP is true
  logTime() catch | err |
  {
    std.debug.print( "Failed to write timestamp : {}\n", .{ err });
    return;
  };

  logChar( ':' ); // Print a separator character

  // Shows the file location if SHOW_MSG_SRC is true
  logLoc( callLocation ) catch | err |
  {
    std.debug.print( "Failed to write source location : {}\n", .{ err });
    return;
  };

  logChar( ':' ); // Print a separator character

  // If the message starts with '!', set the color to red
  if( message.len >= 0 )
  {
    switch ( message[ 0 ])
    {
      '!'  => setCol( def.col.RED ),
      '@'  => setCol( def.col.MAGEN ),
      '#'  => setCol( def.col.YELOW ),
      '$'  => setCol( def.col.GREEN ),
      '%'  => setCol( def.col.BLUE ),
      '&'  => setCol( def.col.CYAN ),
      else => setCol( def.col.RESET ),
    }
  }

  if( comptime ADD_PREC_NL )
  {
    // If ADD_PREC_NL is true, print a newline before the actual message
    G_LOG_FILE.writer().print( "\n > ", .{} ) catch | err |
    {
      std.debug.print( "Failed to write newline : {}\n", .{ err });
      return;
    };
  }

  // Prints the actual message
  G_LOG_FILE.writer().print( message ++ "\n", args ) catch | err |
  {
    std.debug.print( "Failed to write message : {}\n", .{ err });
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
  std.debug.print( def.col.YELOW ++ "Logging to file '{s}'\n" ++ def.col.RESET, .{ LOG_FILE_NAME });
  G_IsFileOpened = true; // Set the flag to true as we successfully opened the file

  qlog( .INFO, 0, @src(), "Logfile initialized\n\n" );
}

pub fn deinitFile() void
{
  if( comptime !USE_LOG_FILE ){ return; } // If we are not using a log file, do nothing

  // If we are using a log file, close it
  if( G_IsFileOpened )
  {
    qlog( .INFO, 0, @src(), "Logfile deinitialized\n\n" );
    G_LOG_FILE.close();
    G_IsFileOpened = false; // Set the flag to false as we closed the file
  }
}

fn logChar( char : u8 ) void // Print the character followed by a space
{
  G_LOG_FILE.writer().print( "{c} ", .{ char }) catch | err |
  {
    std.debug.print( "Failed to write character : {}\n", .{ err });
    return;
  };
}

fn setCol( col : []const u8 ) void // Set the ANSI color for the log file
{
  if( comptime USE_LOG_FILE ){ return; } // If writing in a file, do not set the color

  // If we are writing in a terminal, set the color
  G_LOG_FILE.writer().print( "{s}", .{ col }) catch | err |
  {
    std.debug.print( "Failed to set ANSI color to {s} : {}\n", .{ col, err });
    return;
  };
}

fn logLevel( level: LogLevel ) !void
{

  switch ( level )
  {
    LogLevel.NONE  => setCol( def.col.RESET ),
    LogLevel.ERROR => setCol( def.col.RED   ),
    LogLevel.WARN  => setCol( def.col.YELOW ),
    LogLevel.INFO  => setCol( def.col.GREEN ),
    LogLevel.DEBUG => setCol( def.col.CYAN  ),
    LogLevel.TRACE => setCol( def.col.GRAY  ),
  }
  const lvl : []const u8 = switch ( level )
  {
    LogLevel.NONE  => "NONE ",
    LogLevel.ERROR => "[ERROR]",
    LogLevel.WARN  => "[WARN ]",
    LogLevel.INFO  => "[INFO ]",
    LogLevel.DEBUG => "[DEBUG]",
    LogLevel.TRACE => "[TRACE]",
  };
  // Print the log level string followed by a space
  try G_LOG_FILE.writer().print( "{s} ", .{ lvl });
}

fn logTime() !void
{
  if( comptime !SHOW_TIMESTAMP ) return; // If we are not showing the timestamp, do nothing

  var now : i128 = undefined; // Get the elapsed time since the epoch

  if( SHOW_LAPTIME ){ now = getLogDeltaTime(); }   // Get the lap time if SHOW_LAPTIME is true
  else              { now = getLogElapsedTime(); } // Get the elapsed time since the epoch

  const sec  : u64 = @intCast( @divTrunc( now, @as( i128, std.time.ns_per_s )));
  const nano : u64 = @intCast( @rem(      now, @as( i128, std.time.ns_per_s )));

  setCol( def.col.GRAY ); // Set the color to gray for the timestamp

  // Print the time in seconds and nanoseconds
  try G_LOG_FILE.writer().print( "{d}.{d:0>9} ", .{ sec, nano });
}

fn logLoc( callLocation : ?std.builtin.SourceLocation ) !void
{
  if( comptime !SHOW_MSG_SRC ){ return; } // If we are not showing the source location, do nothing

  if( callLocation )| loc | // If the call location is defined, print the file, line, and function name
  {
    setCol( def.col.BLUE ); // Set the color to blue for the source location
    try G_LOG_FILE.writer().print( "{s}:{d} ", .{ loc.file, loc.line });

    setCol( def.col.GRAY ); // Set the color to gray for the function name
    try G_LOG_FILE.writer().print( "| {s} ", .{ loc.fn_name });
  }
  else // If the call location is undefined, print "UNDEFINED"
  {
    setCol( def.col.YELOW ); // Set the color to red for the undefined location
    try G_LOG_FILE.writer().print( "{s} ", .{ "UNLOCATED" });
  }
}

// =============================== SHORTHAND LOGGING ================================

pub fn logLapTime() void
{
  const now : i128 = getLogDeltaTime();

  const sec  : u64 = @intCast( @divTrunc( now, @as( i128, std.time.ns_per_s )));
  const nano : u64 = @intCast( @rem(      now, @as( i128, std.time.ns_per_s )));

  log( .INFO, 0, @src(), "@ Lap time : {d}.{d:0>9} ", .{ sec, nano });
}


