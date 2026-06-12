//! Logger-local debug output helpers with comptime level gating, terminal colors, and optional plain-text log files.

const std = @import( "std" );
const utl = @import( "utils" );

const Duration = utl.Duration;

const LOG_BUFF_LEN   : usize       = 8192;
const LOG_NAME_LEN   : usize       = 256;
const LOG_TRUNC_MSG  : [] const u8 = "\n[LOGGER RECORD TRUNCATED]\n";
const LOG_INIT_MSG   : [] const u8 = "\n[LOGGER INITIALIZED]\n";
const LOG_DEINIT_MSG : [] const u8 = "\n[LOGGER DEINITIALIZED]\n";

var LoggedLastMsg : bool      = false;
var LastLogLevel  : ?LogLevel = null;


// ================================ DEFINITIONS ================================

pub const LogLevel = enum( u4 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  // Higher configured values include every lower-severity value.
  NONE,  // No output                                          ( deactivates the logging system entirely )
  CONT,  // Continues the latest log message if it was printed ( does not print message header )
  ERROR, // Error messages                                     ( critical issues that prevent normal execution )
  WARN,  // Warnings too                                       ( non critical issues that do not prevent normal execution )
  INFO,  // Long term informational messages                   ( key events in the program )
  DEBUG, // Tracing of abnormal execution flow                 ( unhappy path and temporary debugging messages )
  TRACE, // Tracing of normal   execution flow                 ( happy path )

  /// Returns whether this level is active under the comptime global gate.
  pub fn canLog( self : LogLevel ) bool
  {
    if( comptime G_LOG_LVL == .NONE ){                     return false; }
    if( @intFromEnum( self ) > @intFromEnum( G_LOG_LVL )){ return false; }
    return true;
  }
};

// Global configuration variables for the debug logging system.
pub const G_LOG_LVL      : LogLevel    = .DEBUG; // Sets the global log level for debug printing ( do not use CONT here )
pub const SHOW_TIMESTAMP : bool        = true;   // If true, messages include a timestamp relative to the first logger timestamp
pub const SHOW_MSG_SRC   : bool        = true;   // If true, messages include the source file, line number, and function name
pub const ADD_PREC_NL    : bool        = true;   // If true, a newline is inserted before the message body

pub const USE_LOG_FILE   : bool        = false;       // If true, log messages are also written to plain-text log files
pub const LOG_FILE_NAME  : [] const u8 = "debug.log"; // Aggregate file name used when USE_LOG_FILE is true


// ================================ FILE STATE ================================

const FileSlot = struct
{
  file     : std.fs.File        = undefined,
  nameBuff : [ LOG_NAME_LEN ]u8 = undefined,
  name     : [] const u8        = "",
  isOpen   : bool               = false,


  fn openNamed( self : *FileSlot, name : [] const u8 ) !void
  {
    if( name.len > self.nameBuff.len ){ return error.LogFileNameTooLong; }

    std.mem.copyForwards( u8, self.nameBuff[ 0..name.len ], name );
    self.name = self.nameBuff[ 0..name.len ];

    self.file   = try std.fs.cwd().createFile( self.name, .{ .truncate = true });
    self.isOpen = true;
  }

  fn openForLevel( self : *FileSlot, level : LogLevel ) !void
  {
    const extStart = std.mem.lastIndexOfScalar( u8, LOG_FILE_NAME, '.' ) orelse LOG_FILE_NAME.len;

    self.name = std.fmt.bufPrint(
      &self.nameBuff,
      "{s}_{s}{s}",
      .{ LOG_FILE_NAME[ 0..extStart ], @tagName( level ), LOG_FILE_NAME[ extStart.. ] }
    ) catch return error.LogFileNameTooLong;

    self.file   = try std.fs.cwd().createFile( self.name, .{ .truncate = true });
    self.isOpen = true;
  }

  fn close( self : *FileSlot ) void
  {
    if( !self.isOpen ){ return; }

    self.file.close();
    self.isOpen = false;
  }

  fn writeAll( self : *FileSlot, bytes : [] const u8 ) !void
  {
    if( !self.isOpen ){ return; }

    try self.file.writeAll( bytes );
  }
};


var AggregateLogFile : FileSlot = FileSlot{};
var LevelLogFiles    : [ LogLevel.count ]FileSlot = [_]FileSlot{ FileSlot{} } ** LogLevel.count;
var G_IsFileOpened   : bool = false;


// ================================ CORE FUNCTIONS ================================

const LogStamp = struct
{
  sec  : u64,
  nano : u64,
};

/// Fixed-size formatter used to build one complete log record before flushing.
const LogStream = struct
{
  buff       : [ LOG_BUFF_LEN ]u8 = undefined,
  idx        : usize              = 0,
  overflowed : bool               = false,


  fn init() LogStream { return .{}; }

  fn bytes( self : *const LogStream ) [] const u8 { return self.buff[ 0..self.idx ]; }

  fn append( self : *LogStream, text : [] const u8 ) void
  {
    if( self.overflowed ){ return; }

    const available = self.buff.len - self.idx;
    if( text.len <= available )
    {
      std.mem.copyForwards( u8, self.buff[ self.idx..self.idx + text.len ], text );
      self.idx += text.len;
      return;
    }

    if( available > 0 )
    {
      std.mem.copyForwards( u8, self.buff[ self.idx.. ], text[ 0..available ] );
      self.idx = self.buff.len;
    }
    self.markOverflow();
  }

  fn appendFormat( self : *LogStream, comptime fmt : [] const u8, args : anytype ) void
  {
    if( self.overflowed ){ return; }

    const written = std.fmt.bufPrint( self.buff[ self.idx.. ], fmt, args ) catch
    {
      self.markOverflow();
      return;
    };
    self.idx += written.len;
  }

  fn markOverflow( self : *LogStream ) void
  {
    if( self.overflowed ){ return; }

    self.overflowed = true;

    const keepLen = if( self.buff.len > LOG_TRUNC_MSG.len ) self.buff.len - LOG_TRUNC_MSG.len else 0;
    self.idx = @min( self.idx, keepLen );

    if( LOG_TRUNC_MSG.len <= self.buff.len - self.idx )
    {
      std.mem.copyForwards( u8, self.buff[ self.idx..self.idx + LOG_TRUNC_MSG.len ], LOG_TRUNC_MSG );
      self.idx += LOG_TRUNC_MSG.len;
    }
  }
};

fn _log( level : LogLevel, logLoc : ?std.builtin.SourceLocation, comptime message : [] const u8, args : anytype ) !void
{
  if( level == .NONE  ){                    return; }
  if( level == .CONT and !LoggedLastMsg  ){ return; }

  LoggedLastMsg = false;

  const stamp = if( level == .CONT ) null else getLogStamp();

  var terminalRecord = LogStream.init();
  appendRecord( &terminalRecord, level, logLoc, stamp, message, args, true );
  std.debug.print( "{s}", .{ terminalRecord.bytes() });

  if( comptime USE_LOG_FILE )
  {
    if( G_IsFileOpened )
    {
      var fileRecord = LogStream.init();
      appendRecord( &fileRecord, level, logLoc, stamp, message, args, false );
      writeFileRecords( level, fileRecord.bytes() ) catch | err |
      {
        std.debug.print(
          utl.termColour.YELLOW ++ "Logger file write failed: {}. Continuing terminal-only.\n" ++ utl.termColour.RESET,
          .{ err }
        );
      };
    }
  }

  if( level != .CONT ){ LastLogLevel = level; }
  LoggedLastMsg = true;
}

fn appendRecord(
  stream           : *LogStream,
  level            : LogLevel,
  logLoc           : ?std.builtin.SourceLocation,
  stamp            : ?LogStamp,
  comptime message : [] const u8,
  args             : anytype,
  comptime hasCol  : bool,
) void
{
  if( level != .CONT )
  {
    appendLevel(    stream, level,  hasCol );
    appendTime(     stream, stamp,  hasCol );
    appendLocation( stream, logLoc, hasCol );
  }

  if( comptime hasCol ){ stream.append( msgColour( message )); }

  if( comptime ADD_PREC_NL )
  {
    if( level == .CONT ){ stream.append( "   "   ); }
    else                { stream.append( "\n > " ); }
  }

  stream.appendFormat( message ++ "\n", args );

  if( comptime hasCol ){ stream.append( utl.termColour.RESET ); }
}


// ================================ FILE FUNCTIONS ================================

/// Initializes aggregate and per-level log files when file logging is enabled.
pub fn initFile() void
{
  std.debug.assert( G_LOG_LVL != .CONT );

  LoggedLastMsg = false;
  LastLogLevel  = null;

  if( comptime !USE_LOG_FILE ){ return; }

  initFileInner() catch | err |
  {
    closeAllFiles();
    G_IsFileOpened = false;

    std.debug.print( utl.termColour.YELLOW ++ "Failed to initialize log files: {}. Continuing terminal-only.\n" ++ utl.termColour.RESET, .{ err });
    return;
  };

  G_IsFileOpened = true;
  std.debug.print( utl.termColour.YELLOW ++ "Logging to file '{s}'\n" ++ utl.termColour.RESET, .{ LOG_FILE_NAME });
}

/// Writes shutdown records and closes all opened logger files.
pub fn deinitFile() void
{
  if( comptime !USE_LOG_FILE ){ return; }
  if( !G_IsFileOpened ){ return; }

  AggregateLogFile.writeAll( LOG_DEINIT_MSG ) catch {};

  inline for( @typeInfo( LogLevel ).@"enum".fields )| field |
  {
    const level : LogLevel = @enumFromInt( field.value );
    if( isLevelFileIsActive( level ))
    {
      LevelLogFiles[ getLevelIndex( level ) ].writeAll( LOG_DEINIT_MSG ) catch {};
    }
  }

  closeAllFiles();
  G_IsFileOpened = false;
}

fn initFileInner() !void
{
  AggregateLogFile.openNamed( LOG_FILE_NAME ) catch | err | return err;
  try AggregateLogFile.writeAll( LOG_INIT_MSG );

  inline for( @typeInfo( LogLevel ).@"enum".fields )| field |
  {
    const level : LogLevel = @enumFromInt( field.value );
    if( isLevelFileIsActive( level ))
    {
      var slot = &LevelLogFiles[ getLevelIndex( level ) ];
      try slot.openForLevel( level );
      try slot.writeAll( LOG_INIT_MSG );
    }
  }
}

fn writeFileRecords( level : LogLevel, bytes : [] const u8 ) !void
{
  try AggregateLogFile.writeAll( bytes );

  const fileLevel = if( level == .CONT ) LastLogLevel else level;
  if( fileLevel )| lvl |
  {
    if( isLevelFileIsActive( lvl ))
    {
      try LevelLogFiles[ getLevelIndex( lvl ) ].writeAll( bytes );
    }
  }
}

fn closeAllFiles() void
{
  AggregateLogFile.close();

  inline for( @typeInfo( LogLevel ).@"enum".fields )| field |
  {
    const level : LogLevel = @enumFromInt( field.value );
    LevelLogFiles[ getLevelIndex( level ) ].close();
  }
}

fn isLevelFileIsActive( level : LogLevel ) bool
{
  return switch( level )
  {
    .NONE, .CONT => false,
    else         => @intFromEnum( level ) <= @intFromEnum( G_LOG_LVL ),
  };
}

fn getLevelIndex( level : LogLevel ) usize
{
  return @intCast( @intFromEnum( level ));
}


// ================================ HELPER FUNCTIONS ================================

fn getLogStamp() ?LogStamp
{
  if( comptime !SHOW_TIMESTAMP ){ return null; }

  const epoch = utl.G_EPOCH orelse blk:
  {
    const now = utl.getNow();
    utl.G_EPOCH = now;
    break :blk now;
  };
  const prog = epoch.since();

  return .{
    .sec  = @intCast( prog.toSec() ),
    .nano = @intCast( prog.getRemainder( .SEC ).value ),
  };
}

fn appendLevel( stream : *LogStream, level : LogLevel, comptime colour : bool ) void
{
  if( comptime colour ){ stream.append( levelColour( level )); }

  stream.appendFormat( "{s} ", .{ getLevelLabel( level ) });
}

fn appendTime( stream : *LogStream, stamp : ?LogStamp, comptime colour : bool ) void
{
  if( stamp )| s |
  {
    if( comptime colour ){ stream.append( utl.termColour.GRAY ); }
    stream.appendFormat( "{d}.{d:0>9} : ", .{ s.sec, s.nano });
  }
}

fn appendLocation( stream : *LogStream, logloc : ?std.builtin.SourceLocation, comptime colour : bool ) void
{
  if( comptime !SHOW_MSG_SRC ){ return; }

  if( logloc )| loc |
  {
    if( comptime colour ){ stream.append( utl.termColour.BLUE ); }
    stream.appendFormat( "{s}:{d} ", .{ loc.file, loc.line });

    if( comptime colour ){ stream.append( utl.termColour.GRAY ); }
    stream.appendFormat( "| {s}() :", .{ loc.fn_name });
  }
  else
  {
    if( comptime colour ){ stream.append( utl.termColour.YELLOW ); }
    stream.append( "UNLOCATED : " );
  }
}

fn getLevelLabel( level : LogLevel ) [] const u8
{
  return switch( level )
  {
    .ERROR => "[ERROR]",
    .WARN  => "[WARN ]",
    .INFO  => "[INFO ]",
    .DEBUG => "[DEBUG]",
    .TRACE => "[TRACE]",
    else   => undefined,
  };
}

fn levelColour( level : LogLevel ) [] const u8
{
  return switch( level )
  {
    .NONE  => utl.termColour.RESET,
    .ERROR => utl.termColour.RED,
    .WARN  => utl.termColour.MAGEN,
    .INFO  => utl.termColour.GREEN,
    .DEBUG => utl.termColour.CYAN,
    .TRACE => utl.termColour.GRAY,
    else   => utl.termColour.RESET,
  };
}

fn msgColour( message : [] const u8 ) [] const u8
{
  if( message.len == 0 ){ return utl.termColour.RESET; }

  return switch( message[ 0 ])
  {
    '!'  => utl.termColour.RED,
    '@'  => utl.termColour.MAGEN,
    '#'  => utl.termColour.YELLOW,
    '$'  => utl.termColour.GREEN,
    '%'  => utl.termColour.BLUE,
    '&'  => utl.termColour.CYAN,
    else => utl.termColour.RESET,
  };
}


// =============================== SHORTHAND FUNCTIONS ================================

/// Logs a static message with no formatting arguments.
pub fn qlog( comptime level : LogLevel, logLoc : ?std.builtin.SourceLocation, comptime message : []const u8 ) void
{
  if( comptime !level.canLog() ){ return; }

  _log( level, logLoc, message, .{} ) catch | err |
  {
    std.debug.print( "Logging failed : {}", .{ err });
  };
}

/// Logs a comptime format string and its arguments.
pub fn log( comptime level : LogLevel, logLoc : ?std.builtin.SourceLocation, comptime message : []const u8, args : anytype ) void
{
  if( comptime !level.canLog() ){ return; }

  _log( level, logLoc, message, args ) catch | err |
  {
    std.debug.print( "Logging failed : {}", .{ err });
  };
}

/// Logs the current raylib frame time using the standard info level.
pub fn logRayFrameTime( logloc : ?std.builtin.SourceLocation ) void
{
  const frameTime = Duration.fromRayDeltaTime( utl.ray.getFrameTime() );

  const sec  : u64 = @intCast( frameTime.toSec() );
  const nano : u64 = @intCast( frameTime.getRemainder( .SEC ).value );

  if( logloc )| loc |{ log( .INFO, loc,    "$ Full frame time : {d}.{d:0>9} sec | {d:.2} fps", .{ sec, nano, 1.0 / frameTime.toRayDeltaTime() }); }
  else {               log( .INFO, @src(), "$ Full frame time : {d}.{d:0>9} sec | {d:.2} fps", .{ sec, nano, 1.0 / frameTime.toRayDeltaTime() }); }
}

/// Logs a duration with a caller-provided prefix.
pub fn logDeltaTime( deltaTime : Duration, logloc : ?std.builtin.SourceLocation, comptime message : [:0] const u8 ) void
{
  const sec  : u64 = @intCast( deltaTime.toSec() );
  const nano : u64 = @intCast( deltaTime.getRemainder( .SEC ).value );

  if( logloc )| loc |{ log( .INFO, loc,    message ++ ": {d}.{d:0>9}", .{ sec, nano }); }
  else {               log( .INFO, @src(), message ++ ": {d}.{d:0>9}", .{ sec, nano }); }
}


// =============================== FORMATTING HELPER FUNCTIONS ================================

pub inline fn getSignChar( val : anytype ) u8
{
  comptime switch( @typeInfo( @TypeOf( val )))
  {
    .float, .comptime_float =>
    {
      if( val >= 0.0 ){ return '+'; }
      else{             return '-'; }
    },
    .int, .comptime_int =>
    {
      if( val >= 0 ){ return '+'; }
      else{           return '-'; }
    },
    else => @compileError( "getSignChar() only supports Int and Float types" ),
  };
}
