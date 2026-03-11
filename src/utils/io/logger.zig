const std    = @import( "std" );
const def    = @import( "defs" );
//const stdOut = @import( "./outputer.zig" ).demoStdout;

const TimeVal = def.TimeVal;
const getNow  = def.getNow;

var LoggedLastMsg : bool = false;

// This file defines helper functions to conditionally print debug info based on the following enum's value
// Yes, this might very well be a shittier version of std.log...

// ================================ DEFINITIONS ================================

pub const LogLevel = enum
{
  // These values are used to control the verbosity of debug output.
  // The higher the value, the more verbose the output.
  // This means each value prints all values below it.

  NONE,  // No output      ( deactivates the debug print system entirely )
  CONT,  // Continues the latest log message if it was printed ( does not print message header )
  ERROR, // Error messages ( critical issues that prevent normal execution )
  WARN,  // Warnings too   ( non critical issues that do not prevent normal execution )
  INFO,  // Long term informational messages   ( key events in the program )
  DEBUG, // Tracing of abnormal execution flow ( unhappy path ) and short term debugging messages
  TRACE, // Tracing of normal   execution flow ( happy path )


  // an enum method... ? in THIS economy ?!
  pub fn canLog( self : LogLevel ) bool
  {
    if( comptime G_LOG_LVL == .NONE ){                     return false; }
    if( @intFromEnum( self ) > @intFromEnum( G_LOG_LVL )){ return false; }
    return true;
  }
};

// Global configuration variables for the debug logging system
pub const G_LOG_LVL      : LogLevel    = .DEBUG; // Set the global log level for debug printing ( do not use CONT here )

pub const SHOW_ID_MSGS   : bool        = true;   // If true, messages with id will not be omitted
pub const SHOW_TIMESTAMP : bool        = true;   // If true, messages will include a timestamp of the system clock
pub const SHOW_MSG_SRC   : bool        = true;   // If true, messages will include the source file, line number, and function name of the call location
pub const ADD_PREC_NL    : bool        = true;   // If true, a newline will be before the actual message, to make it more readable

pub const USE_LOG_FILE   : bool        = false;              // If true, log messages will be written to a file instead of stdout/stderr
pub const LOG_FILE_NAME  : [] const u8 = "debug.log";        // The file to write log messages to if USE_LOG_FILE is true
var       G_LOG_FILE     : std.fs.File = undefined;             // The file to write log messages in ( default is stderr )
var       G_IsFileOpened : bool        = false;              // Flag to check if the log file is opened ( and different from stderr )

// TODO : have each log level be printed in its own file, on top of the shared main one


// ================================ CORE FUNCTIONS ================================

//const buffLen   = 4096;
//const LogStream = struct
//{
//  buff : [ buffLen ]u8 = undefined,
//  idx  : usize = 0,
//
//  pub inline fn init( ) LogStream { return.{ .buff = std.mem.zeroes([ buffLen ]u8 ), .idx = 0 }; }
//
//
//  pub fn writer( self: *LogStream ) std.io.Writer
//  {
//    return std.io.Writer.fixed( self.buff[ 0..self.idx ]);
//  }
//
//  pub fn writeChar( self : *LogStream, char : u8 ) !void
//  {
//    if( self.idx >= buffLen ){ return error.NoSpaceLeft; }
//
//    self.buff[ self.idx ] = char;
//
//    self.idx += 1;
//  }
//
//  pub fn write( self : *LogStream, bytes : []const u8 ) !usize
//  {
//    const size : usize = @min( buffLen - self.idx, bytes.len );
//
//    if( size == 0 ){ return error.NoSpaceLeft; }
//
//    const start = self.idx;
//    const end   = start + size;
//
//    std.mem.copyForwards( u8, self.buff[ start..end ], bytes[ 0..size ] );
//    self.idx += size;
//
//    return size;
//  }
//
//
//  pub inline fn flush( self : *LogStream ) void
//  {
//    const col = if( comptime !USE_LOG_FILE ) def.tcl_u.RESET else "";
//
//    std.debug.print( "{s}{s}", .{ self.buff[ 0..self.idx ], col });
//    self.idx = 0;
//  }
//
//  pub inline fn clear( self : *LogStream ) void
//  {
//    self.idx = 0;
//  }
//};
//
//var stream = LogStream.init();



fn _log( level : LogLevel, id : u64, logLoc : ?std.builtin.SourceLocation, comptime message : [] const u8, args : anytype ) !void
{
  // LOG EXAMPLE :

    // [DEBUG] (1) - 2025-10-01 12:34:56 - main.zig:42 (main)
    // > This is a debug message
    //   This is a message continuation (.CONT )

  // TODO : reimplement logging to file ( need my own io implementation for that )
  // TODO : Implement the trace system properly, to log/unlog functions when they are called and exited ( maybe via a trace stack file ?)

  // ================ LOGGING CHECKS ================

  if( level == .CONT and !LoggedLastMsg  ){ return; }

  LoggedLastMsg = false; // Leaves this at false unless the message ends up being logged

  if( comptime !SHOW_ID_MSGS and id != 0 ){ return; }




  // ================ LOGGING LOGIC ================

  // Setting the success flag for the next .CONT canLog() check

  if( level != .CONT )
  {
    try logLevel( level ); // Show the log level as a string

    try logId( id ); // Shows the message id if SHOW_ID_MSGS is true

    try logTime(); // Shows the time of the message relative to the system clock if SHOW_TIMESTAMP is true

    try logLocation( logLoc ); // Shows the file location if SHOW_MSG_SRC is true
  }

  try setMsgColour( message );

  if( comptime ADD_PREC_NL ) // If ADD_PREC_NL is true, print a newline before the actual message
  {
    if( level == .CONT ){ std.debug.print( "   ",   .{} ); }
    else                { std.debug.print( "\n > ", .{} );}
  }

  std.debug.print( message ++ "\n", args ); // Prints the actual message
  //stream.flush();

  LoggedLastMsg = true;

}

// ================================ FILE FUNCTIONS ================================

pub fn initFile() void
{
  std.debug.assert( G_LOG_LVL != .CONT );

//if( comptime !USE_LOG_FILE ){ return; }
//
//G_LOG_FILE = std.fs.cwd().createFile( LOG_FILE_NAME, .{ .truncate = false }) catch | err |
//{
//  std.debug.print( "Failed to create or open log file '{s}': {}\nLogging to stderr isntead\n", .{ LOG_FILE_NAME, err });
//  return;
//};
//std.debug.print( def.tcl_u.YELLOW ++ "Logging to file '{s}'\n" ++ def.tcl_u.RESET, .{ LOG_FILE_NAME });
//
//G_IsFileOpened = true; // Set the flag to true as we successfully opened the file
//
//qlog( .INFO, 0, @src(), "Logfile initialized\n\n" );
}

pub fn deinitFile() void
{
//if( comptime !USE_LOG_FILE ){ return; }
//
//if( G_IsFileOpened )
//{
//  qlog( .INFO, 0, @src(), "Logfile deinitialized\n\n" );
//  G_LOG_FILE.stop();
//  G_IsFileOpened = false;
//}
}



// ================================ HELPER FUNCTIONS ================================

inline fn setCol( col : []const u8 ) !void
{
  if( comptime USE_LOG_FILE ){ return; }

  std.debug.print( "{s}", .{ col });
}

fn logLevel( level : LogLevel ) !void
{
  switch ( level )
  {
    LogLevel.NONE  => try setCol( def.tcl_u.RESET  ),
    LogLevel.ERROR => try setCol( def.tcl_u.RED    ),
    LogLevel.WARN  => try setCol( def.tcl_u.MAGEN ),
    LogLevel.INFO  => try setCol( def.tcl_u.GREEN  ),
    LogLevel.DEBUG => try setCol( def.tcl_u.CYAN   ),
    LogLevel.TRACE => try setCol( def.tcl_u.GRAY   ),
    else => {},
  }

  const lvl : []const u8 = switch ( level )
  {
    LogLevel.NONE  => "NONE ",
    LogLevel.ERROR => "[ERROR]",
    LogLevel.WARN  => "[WARN ]",
    LogLevel.INFO  => "[INFO ]",
    LogLevel.DEBUG => "[DEBUG]",
    LogLevel.TRACE => "[TRACE]",
    else           => "[N/A]"
  };

  std.debug.print( "{s} ", .{ lvl });
}

fn logId( id : u64 ) !void
{
  if( id != 0 )
  {
    std.debug.print( "{d:0>4} ", .{ id });
  }
}

fn logTime() !void
{
  if( comptime !SHOW_TIMESTAMP ) return;

  const prog = def.GLOBAL_EPOCH.timeSince();

  const sec  : u64 = @intCast( prog.toSec() );
  const nano : u64 = @intCast( @mod( prog.value, TimeVal.nsPerSec() ));

  try setCol( def.tcl_u.GRAY );

  //try G_LOG_FILE.writer().print( "{d}.{d:0>9} ", .{ sec, nano });
  std.debug.print( "{d}.{d:0>9} : ", .{ sec, nano });
}

fn logLocation( logloc : ?std.builtin.SourceLocation ) !void
{
  if( comptime !SHOW_MSG_SRC ){ return; }

  if( logloc )| loc | // If the call location is defined, print the file, line, and function name
  {
    try setCol( def.tcl_u.BLUE );
    std.debug.print( "{s}:{d} ", .{ loc.file, loc.line });

    try setCol( def.tcl_u.GRAY );
    std.debug.print( "| {s}() :", .{ loc.fn_name });
  }
  else
  {
    try setCol( def.tcl_u.YELLOW );
    std.debug.print( "{s} : ", .{ "UNLOCATED" });
  }
}

fn setMsgColour( message : [] const u8 ) !void
{
  if( !USE_LOG_FILE and message.len > 0 )
  {
    switch ( message[ 0 ])
    {
      '!'  => try setCol( def.tcl_u.RED    ),
      '@'  => try setCol( def.tcl_u.MAGEN  ),
      '#'  => try setCol( def.tcl_u.YELLOW ),
      '$'  => try setCol( def.tcl_u.GREEN  ),
      '%'  => try setCol( def.tcl_u.BLUE   ),
      '&'  => try setCol( def.tcl_u.CYAN   ),
      else => try setCol( def.tcl_u.RESET  ),
    }
  }
}

// =============================== SHORTHAND FUNCTIONS ================================

// Shortcut to log a message with no arguments ( for simple text with no formatting )
pub fn qlog( comptime level : LogLevel, id : u64, logLoc : ?std.builtin.SourceLocation, comptime message : []const u8 ) void
{
  if( comptime !level.canLog() ){ return; }

  _log( level, id, logLoc, message, .{} ) catch | err |
  {
    std.debug.print( "Logging failed : {}", .{ err });
  };
}

pub fn log( comptime level : LogLevel, id : u64, logLoc : ?std.builtin.SourceLocation, comptime message : []const u8, args : anytype ) void
{
  if( comptime !level.canLog() ){ return; }

  _log( level, id, logLoc, message, args ) catch | err |
  {
    std.debug.print( "Logging failed : {}", .{ err });
  };
}


pub fn logFrameTime( logloc : ?std.builtin.SourceLocation ) void
{
  const frameTime = TimeVal.fromRayDeltaTime( def.ray.getFrameTime() );

  const sec  : u64 = @intCast( frameTime.toSec() );
  const nano : u64 = @intCast( @rem( frameTime.value, TimeVal.nsPerSec() ));

  if( logloc )| loc |{ log( .INFO, 0, loc,    "$ Full frame time : {d}.{d:0>9} sec | {d:.2} fps", .{ sec, nano, 1.0 / frameTime.toRayDeltaTime() }); }
  else {               log( .INFO, 0, @src(), "$ Full frame time : {d}.{d:0>9} sec | {d:.2} fps", .{ sec, nano, 1.0 / frameTime.toRayDeltaTime() }); }
}

pub fn logDeltaTime( deltaTime : TimeVal, logloc : ?std.builtin.SourceLocation, comptime message : [:0] const u8 ) void
{
  const sec  : u64 = @intCast( deltaTime.toSec() );
  const nano : u64 = @intCast( @rem( deltaTime.value, TimeVal.nsPerSec() ));

  if( logloc )| loc |{ log( .INFO, 0, loc,    message ++ ": {d}.{d:0>9}", .{ sec, nano }); }
  else {               log( .INFO, 0, @src(), message ++ ": {d}.{d:0>9}", .{ sec, nano }); }
}