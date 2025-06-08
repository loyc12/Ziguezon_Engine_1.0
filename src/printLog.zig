const std = @import( "std" );
const stdAlloc = std.mem.Allocator;

// This file defines helper functiosn to conditionally print debug info based on the following enum's value
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

const G_LOG_LVL : LogLevel = LogLevel.DEBUG; // Set the global log level for debug printing

const SHOW_MSG_SRC   : bool = true; 	// If true, file location information will be included in log messages
const SHOW_TIMESTAMP : bool = true; 	// If true, timestamps will be included in log messages
const SHOW_ID_MSGS   : bool = true; 	// If true, the id of the message will be included in log messages
const USE_LOG_FILE   : bool = false; 	// If true, log messages will be written to a file instead of stdout/stderr

const G_LOG_FILE     : [] const u8 = "ziguezon.log"; // The file to write log messages to if USE_LOG_FILE is true

// This function is used to print debug messages based on the inputed DebugPrint level.
pub fn logMsg( level : LogLevel, id : u32, message : [] const u8, fileLocation : ?std.builtin.SourceLocation ) void
{
	// OUTPUT EXAMPLE :
	// [DEBUG] (1) - 2025-10-01 12:34:56 - main.zig:42 - This is a debug message

	// If the global log level is NONE, we instantly return, as nothing will ever be logged anyway
	comptime { if( G_LOG_LVL == LogLevel.NONE ) return; }

	if( level > G_LOG_LVL )         return; // If the level is higher than the global log level, do nothing
	if( !SHOW_ID_MSGS and id != 0 ) return; // If the message is IDed and SHOW_ID_MSGS is false, do nothing

	// Choose the writer based on USE_LOG_FILE
	var writer = std.io.getStdErr().writer(); // Default to stderr
	if( USE_LOG_FILE )
	{
		const log_file = std.fs.cwd().createFile( G_LOG_FILE, .{ .append = true, .truncate = false }) catch | err |
		{
			std.debug.print( "Failed to create or open log file: {}\n", .{ err });
			return;
		};
		defer log_file.close();

		writer = log_file.writer(); // Make it so that we write to the log file instead of stderr
	}

	// Show the log level as a string
	var level_str: []const u8 = "";
	switch ( level )
	{
		LogLevel.NONE  => level_str = "NONE ",
		LogLevel.ERROR => level_str = "ERROR",
		LogLevel.WARN  => level_str = "WARN ",
		LogLevel.INFO  => level_str = "INFO ",
		LogLevel.DEBUG => level_str = "DEBUG",
		LogLevel.FUNCT => level_str = "FUNCT",
		LogLevel.TRACE => level_str = "TRACE",
		else => level_str = "UNKNOWN"
	}
	writer.print( "[{s}] ", .{ level_str }) catch | err |
	{
		std.debug.print( "Failed to write log level: {}\n", .{ err });
		return;
	};

	// Shows the message id if differetn from 0
	if( id != 0 )
	{
		writer.print( "{d} ", .{ id }) catch | err |
		{
			std.debug.print( "Failed to write message id: {}\n", .{ err });
			return;
		};
	}

	writer.print( "- ", .{} ) catch | err |
	{
		std.debug.print( "Failed to write separator: {}\n", .{ err });
		return;
	};

	// Shows the time of the message if SHOW_TIMESTAMP is true
	var timestamp: []const u8 = "";
	if( SHOW_TIMESTAMP )
	{
		const time = std.time.timestamp( std.time.utc );
		timestamp = std.fmt.allocPrint( stdAlloc, "{d}-{d}-{d} {d}:{d}:{d}",
		.{
			time.year, time.month, time.day, time.hour, time.minute, time.second,
		}) catch | err |
		{
			std.debug.print( "Failed to allocate timestamp: {}\n", .{ err });
			return;
		};
		defer stdAlloc.free( timestamp );
	}
	writer.print( "{s} - ", .{ timestamp }) catch | err |
	{
		std.debug.print( "Failed to write timestamp: {}\n", .{ err });
		return;
	};
	// Shows the file location if SHOW_MSG_SRC is true
	var file_info: []const u8 = "";
	if( SHOW_MSG_SRC )
	{
		if ( fileLocation == null ){ file_info = "UNKNOWN:0"; }
		else
		{
			file_info = std.fmt.allocPrint( stdAlloc, "{s}:{d}", .{ fileLocation.file, fileLocation.line }) catch | err |
			{
				std.debug.print( "Failed to allocate file info: {}\n", .{ err });
				return;
			};
		}
		defer stdAlloc.free( file_info );
	}
	writer.print( "{s} - ", .{ file_info }) catch | err |
	{
		std.debug.print( "Failed to write file info: {}\n", .{ err });
		return;
	};

	// Finally, print the actual message
	writer.print( "{s}\n", .{ message }) catch | err |
	{
		std.debug.print( "Failed to write message: {}\n", .{ err });
		return;
	};

	// Flush the writer to ensure all data is written out
	writer.flush() catch | err |
	{
		std.debug.print( "Failed to flush writer: {}\n", .{ err });
		return;
	};
}
