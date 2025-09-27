const std    = @import( "std" );
const def    = @import( "defs" );
const stdOut = @import( "./outputer.zig" ).demoStdout;

const TimeVal = def.TimeVal;
const getNow = def.getNow;

// This file defines helper functions to conditionally print debug info based on the following enum's value
// Yes, this might very well be a shittier version of std.log...

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


  // an enum method... ? in THIS economy ?!
  pub fn canLog( self : LogLevel ) bool
  {
    if( comptime G_LOG_LVL == .NONE ){                     return false; }
    if( @intFromEnum( self ) > @intFromEnum( G_LOG_LVL )){ return false;  }
    return true;
  }
};

// Global configuration variables for the debug logging system
pub const G_LOG_LVL      : LogLevel    = .DEBUG; // Set the global log level for debug printing

pub const SHOW_ID_MSGS   : bool        = true;   // If true, messages with id will not be omitted
pub const SHOW_TIMESTAMP : bool        = true;   // If true, messages will include a timestamp of the system clock
pub const SHOW_MSG_SRC   : bool        = true;   // If true, messages will include the source file, line number, and function name of the call location
pub const ADD_PREC_NL    : bool        = true;   // If true, a newline will be before the actual message, to make it more readable

// TODO : reimplement logging to file ( need my own io implementation for that )

pub const USE_LOG_FILE   : bool        = false;              // If true, log messages will be written to a file instead of stdout/stderr
pub const LOG_FILE_NAME  : [] const u8 = "debug.log";        // The file to write log messages to if USE_LOG_FILE is true
var       G_LOG_FILE     : std.fs.File = undefined;             // The file to write log messages in ( default is stderr )
var       G_IsFileOpened : bool        = false;              // Flag to check if the log file is opened ( and different from stderr )

// TODO : have each log level be printed in its own file, on top of the shared main one

// ================================ LOG TIMERS ================================

var GLOBAL_LOG_EPOCH : def.TimeVal = .{};
var TMP_LOG_EPOCH    : def.TimeVal = .{};
var TMP_LOG_LAPS     : u32         =   0;

// NOTE : Initialize the log timer before using it, otherwise it will not work
pub fn initLogTimers() void
{
  const now = getNow();
  GLOBAL_LOG_EPOCH = now;
  TMP_LOG_EPOCH    = now;
}

// Returns the elapsed time since the global epoch
pub fn getGlobalLogTime() TimeVal
{
  if( !GLOBAL_LOG_EPOCH.isSet() ){ return .{}; }

  return GLOBAL_LOG_EPOCH.timeSince();
}

// Returns the time since the last call to resetTmpTimer()
pub fn getTmpLogTime() TimeVal
{
  if( !TMP_LOG_EPOCH.isSet() ){ return .{}; }

  return TMP_LOG_EPOCH.timeSince();
}

// Resets the temporary timer to the current time
pub fn resetTmpTimer() void
{
  TMP_LOG_EPOCH = getNow();
  TMP_LOG_LAPS += 1;
}


// ================================ CORE FUNCTIONS ================================

// Shortcut to log a message with no arguments ( for simple text with no formatting )
pub fn qlog( level : LogLevel, id : u32, callLocation : ?std.builtin.SourceLocation, comptime message : [:0] const u8 ) void
{
  log( level, id, callLocation, message, .{} );
}

pub fn log( level : LogLevel, id : u32, callLocation : ?std.builtin.SourceLocation, comptime message : [:0] const u8, args : anytype ) void
{
  // LOG EXAMPLE :

    // [DEBUG] (1) - 2025-10-01 12:34:56 - main.zig:42 (main)
    // > This is a debug message

  if( !level.canLog() ) return;

  // If the message is IDed and SHOW_ID_MSGS is false, do nothing
  if( comptime !SHOW_ID_MSGS and id != 0 ) return;

  // TODO : Implement the trace system properly, to log/unlog functions when they are called and exited ( maybe via a trace stack file ?)


  // ================ LOGGING LOGIC ================

  // Show the log level as a string
  logLevel( level ) catch | err |
  {
    std.debug.print( "Failed to write log level : {}\n", .{ err });
    return;
  };

  // Shows the message id if SHOW_ID_MSGS is true
  if( id != 0 )
  {
    //G_LOG_FILE.writer().print( "{d:0>4} ", .{ id }) catch | err |
    //{
    //  std.debug.print( "Failed to write message id : {}\n", .{ err });
    //  return;
    //};
    std.debug.print( "{d:0>4} ", .{ id });
  }

  // Shows the time of the message relative to the system clock if SHOW_TIMESTAMP is true
  logTime() catch | err |
  {
    std.debug.print( "Failed to write timestamp : {}\n", .{ err });
    return;
  };

  logChar( ':' );

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
      '!'  => setCol( def.col_u.RED ),
      '@'  => setCol( def.col_u.MAGEN ),
      '#'  => setCol( def.col_u.YELOW ),
      '$'  => setCol( def.col_u.GREEN ),
      '%'  => setCol( def.col_u.BLUE ),
      '&'  => setCol( def.col_u.CYAN ),
      else => setCol( def.col_u.RESET ),
    }
  }

  if( comptime ADD_PREC_NL )
  {
    // If ADD_PREC_NL is true, print a newline before the actual message
    //G_LOG_FILE.writer().print( "\n > ", .{} ) catch | err |
    //{
    //  std.debug.print( "Failed to write newline : {}\n", .{ err });
    //  return;
    //};

    std.debug.print( "\n > ", .{} );
  }

  // Prints the actual message
  //G_LOG_FILE.writer().print( message ++ "\n", args ) catch | err |
  //{
  //  std.debug.print( "Failed to write message : {}\n", .{ err });
  //  return;
  //};

  std.debug.print( message ++ "\n", args );
}

// ================================ HELPER FUNCTIONS ================================

pub fn initFile() void
{
  if( comptime !USE_LOG_FILE ){ return; }

  G_LOG_FILE = std.fs.cwd().createFile( LOG_FILE_NAME, .{ .truncate = false }) catch | err |
  {
    std.debug.print( "Failed to create or open log file '{s}': {}\nLogging to stderr isntead\n", .{ LOG_FILE_NAME, err });
    return;
  };
  std.debug.print( def.col_u.YELOW ++ "Logging to file '{s}'\n" ++ def.col_u.RESET, .{ LOG_FILE_NAME });
  G_IsFileOpened = true; // Set the flag to true as we successfully opened the file

  qlog( .INFO, 0, @src(), "Logfile initialized\n\n" );
}

pub fn deinitFile() void
{
  if( comptime !USE_LOG_FILE ){ return; }

  if( G_IsFileOpened )
  {
    qlog( .INFO, 0, @src(), "Logfile deinitialized\n\n" );
    G_LOG_FILE.stop();
    G_IsFileOpened = false;
  }
}

fn logChar( char : u8 ) void
{
  //G_LOG_FILE.writer().print( "{c} ", .{ char }) catch | err |
  //{
  //  std.debug.print( "Failed to write character : {}\n", .{ err });
  //  return;
  //};

  std.debug.print( "{c} ", .{ char });
}

fn setCol( col : []const u8 ) void
{
  if( comptime USE_LOG_FILE ){ return; }

  //G_LOG_FILE.writer().print( "{s}", .{ col }) catch | err |
  //{
  //  std.debug.print( "Failed to set ANSI color to {s} : {}\n", .{ col, err });
  //  return;
  //};

  std.debug.print( "{s}", .{ col });
}

fn logLevel( level: LogLevel ) !void
{
  switch ( level )
  {
    LogLevel.NONE  => setCol( def.col_u.RESET ),
    LogLevel.ERROR => setCol( def.col_u.RED   ),
    LogLevel.WARN  => setCol( def.col_u.YELOW ),
    LogLevel.INFO  => setCol( def.col_u.GREEN ),
    LogLevel.DEBUG => setCol( def.col_u.CYAN  ),
    LogLevel.TRACE => setCol( def.col_u.GRAY  ),
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

  //try G_LOG_FILE.writer().print( "{s} ", .{ lvl });

  std.debug.print( "{s} ", .{ lvl });
}

fn logTime() !void
{
  if( comptime !SHOW_TIMESTAMP ) return;

  const prog = getGlobalLogTime();

  const sec  : u64 = @intCast( prog.toSec() );
  const nano : u64 = @intCast( @mod( prog.value, TimeVal.nsPerSec() ));

  setCol( def.col_u.GRAY );

  //try G_LOG_FILE.writer().print( "{d}.{d:0>9} ", .{ sec, nano });
  std.debug.print( "{d}.{d:0>9} ", .{ sec, nano });
}

fn logLoc( callLocation : ?std.builtin.SourceLocation ) !void
{
  if( comptime !SHOW_MSG_SRC ){ return; }

  if( callLocation )| loc | // If the call location is defined, print the file, line, and function name
  {
    setCol( def.col_u.BLUE );
    //try G_LOG_FILE.writer().print( "{s}:{d} ", .{ loc.file, loc.line });
    std.debug.print( "{s}:{d} ", .{ loc.file, loc.line });

    setCol( def.col_u.GRAY );
    //try G_LOG_FILE.writer().print( "| {s} ", .{ loc.fn_name });
    std.debug.print( "| {s} ", .{ loc.fn_name });
  }
  else
  {
    setCol( def.col_u.YELOW );
    //try G_LOG_FILE.writer().print( "{s} ", .{ "UNLOCATED" });
    std.debug.print( "{s} ", .{ "UNLOCATED" });

  }
}

// =============================== SHORTHAND LOGGING ================================

pub fn logFrameLapTime( frameTime : f32 ) void
{
  const dt  : TimeVal = TimeVal{ .value = @intFromFloat( frameTime * TimeVal.nsPerSec() )};

  const sec  : u64 = @intCast( dt.toSec() );
  const nano : u64 = @intCast( @rem( dt.value, TimeVal.nsPerSec() ));

  log( .INFO, 0, @src(), "@ Frame lap time : {d}.{d:0>9} ( {d:.2} fps )", .{ sec, nano, 1.0 / frameTime } );
}

// Logs the elapsed time since the last time increment of the temporary timer
// This is used to measure the time between two arbitrary points in the code
pub fn logTmpTimer( callLocation : ?std.builtin.SourceLocation ) void
{
  if( !TMP_LOG_EPOCH.isSet() )
  {
    log( .WARN, 0, @src(), "Temporary timer not initialized, call resetTmpTimer() first", .{} );
    return;
  }

  const prog = TMP_LOG_EPOCH.timeSince();
  const sec  = prog.toSec();
  const nano = @mod( prog.value, TimeVal.nsPerSec() );

  if( callLocation )| loc |{ log( .INFO, 0, loc,    "& Temporary timer : {d}.{d:0>9} ( lap #{d} )", .{ sec, nano, TMP_LOG_LAPS }); }
  else                     { log( .INFO, 0, @src(), "& Temporary timer : {d}.{d:0>9} ( lap #{d} )", .{ sec, nano, TMP_LOG_LAPS }); }
}

