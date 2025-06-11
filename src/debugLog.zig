const std = @import( "std" );
const h = @import( "header.zig" );

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

const SHOW_MSG_SRC   : bool = true; 	// If true, file location information will be included in log messages
const SHOW_TIMESTAMP : bool = true; 	// If true, timestamps will be included in log messages
const SHOW_ID_MSGS   : bool = true; 	// If true, the id of the message will be included in log messages
const USE_LOG_FILE   : bool = true; 	// If true, log messages will be written to a file instead of stdout/stderr
const G_LOG_FILE     : [] const u8 = "debug.log"; // The file to write log messages to if USE_LOG_FILE is true


// This union defines the output type for the debug logging system.
const Output = union( enum )
{
	// This union allows for different output types, such as console or file.
	// Currently, only the console output is implemented.
	File : std.fs.File,
	Cons : std.fs.File,
	None : void, // This is used to indicate no output

	// ================ LOGIC ================

	pub fn init( self: Output ) Output
	{
		if( USE_LOG_FILE )
		{
			const log_file = std.fs.cwd().createFile( G_LOG_FILE, .{ .truncate = false }) catch | err |
			{
				std.debug.print( "Failed to create or open log file: {}\n", .{ err });
				return self{ .None = {} }; // Return None if file creation fails
			};
			return self{ .File = log_file };
		}
		else
		{
			return self{ .Cons = std.io.getStdErr() };
		}
	}

	pub fn deinit( self: Output ) void
	{
		switch ( self )
		{
			.File => | file   | file.close(),
			.Cons => | _      | {}, // No action needed for console output
			.None => | _      | {}, // No action needed for no output
		}
	}

	pub fn print( self : Output, format : []const u8, args : anytype ) !void
	{
		switch (self)
		{
			.File => | file   | try file.writer().print( format, args ),
			.Cons => | writer | try        writer.print( format, args ),
			.None => | _      | {}, // No action needed for no output
		}
	}
};

// TODO : move this to a time.zig file
var G_EPOCH: i128 = 0; // Global epoch variable

// This function initializes the global epoch variable to the current system time.
pub fn initEpoch() void { G_EPOCH = std.time.nanoTimestamp(); }

// ================================ CORE FUNCTIONS ================================

// This function is used to print debug messages based on the inputed DebugPrint level.
pub fn logMsg( level : LogLevel, id : u32, message : [] const u8, callLocation : ?std.builtin.SourceLocation ) void
{
	// OUTPUT EXAMPLE :
	// [DEBUG] (1) - 2025-10-01 12:34:56 - main.zig:42 (main) - This is a debug message

	// If the global log level is NONE, we instantly return, as nothing will ever be logged anyways
	comptime { if( G_LOG_LVL == LogLevel.NONE ) return; }

	// If the level is higher than the global log level, do nothing
	if( @intFromEnum( level ) > @intFromEnum( G_LOG_LVL )) return;

	// If the message is IDed and SHOW_ID_MSGS is false, do nothing
	if( !SHOW_ID_MSGS and id != 0 ) return;

	// Initialize the output writer based on the configuration
	var writer : Output = .None; // Start with no output

	if ( writer.init() == .None )
	{
		std.debug.print( "Failed to initialize output: {}\n", .{} );
		return;
	}
	defer writer.deinit(); // Ensure the writer is closed after use

	// ================ LOGGING LOGIC ================

	// Show the log level as a string
	logLevel( &writer, level ) catch | err |
	{
		std.debug.print( "Failed to write log level: {}\n", .{ err });
		return;
	};

	// Shows the message id if different from 0
	if( id != 0 )
	{
		writer.print( "( {d} ) ", .{ id }) catch | err |
		{
			std.debug.print( "Failed to write message id: {}\n", .{ err });
			return;
		};
	}

	logChar( &writer, '-' ); // Print a separator character

	// Shows the time of the message relative to the system clock if SHOW_TIMESTAMP is true
	logTime( &writer ) catch | err |
	{
		std.debug.print( "Failed to write timestamp: {}\n", .{ err });
		return;
	};

	logChar( &writer, '-' ); // Print a separator character

	// Shows the file location if SHOW_MSG_SRC is true
	logLoc( &writer, callLocation ) catch | err |
	{
		std.debug.print( "Failed to write source location: {}\n", .{ err });
		return;
	};

	logChar( &writer, '-' ); // Print a separator character

	// Prints the actual message
	writer.print( "{s}\n", .{ message }) catch | err |
	{
		std.debug.print( "Failed to write message: {}\n", .{ err });
		return;
	};
}

// ================================ HELPER FUNCTIONS ================================

// Print the character followed by a space
fn logChar( writer : *Output, c : u8 ) void
{
	writer.print( "{c} ", .{ c }) catch | err |
	{
		std.debug.print( "Failed to write character: {}\n", .{ err });
		return;
	};
}

fn logLevel( writer : *Output, level: LogLevel ) !void
{
	switch ( level )
	{
		LogLevel.NONE  => try writer.print( "[NONE ]" ),
		LogLevel.ERROR => try writer.print( "[ERROR] " ),
		LogLevel.WARN  => try writer.print( "[WARN ] " ),
		LogLevel.INFO  => try writer.print( "[INFO ] " ),
		LogLevel.DEBUG => try writer.print( "[DEBUG] " ),
		LogLevel.FUNCT => try writer.print( "[FUNCT] " ),
		LogLevel.TRACE => try writer.print( "[TRACE] " ),
	}
}

fn logTime( writer : *Output ) !void
{
	if( SHOW_TIMESTAMP )
	{
		const elapsed_time : u128 = @intCast( std.time.nanoTimestamp() - G_EPOCH ); // Time since program start in nanoseconds
		const elapsed_sec  : u64  = @intCast( @divTrunc( elapsed_time, @as( u128, std.time.ns_per_s ))); // Convert to seconds
		const elapsed_ns   : u64  = @intCast( @rem(      elapsed_time, @as( u128, std.time.ns_per_s ))); // Remaining nanoseconds
		try writer.print( "{d}.{d:0>9} ", .{ elapsed_sec, elapsed_ns });
	}
}

fn logLoc( writer : *Output, callLocation : ?std.builtin.SourceLocation ) !void
{
	if( SHOW_MSG_SRC )
	{
		if( callLocation )| loc |
		{
			// If the call location is defined, print the file, line, and function name
			try writer.print( "{s}:{d} ( {s} ) ", .{ loc.file, loc.line, loc.fn_name });
		}
		else
		{
			// If the call location is undefined, print "UNDEFINED"
			try writer.print( "UNDEFINED ", .{} );
		}
	}
}
