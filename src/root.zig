//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
//!
const std = @import( "std" );
const def = @import( "defs" );

// TODO : swap these out for a proper test suite

export fn add( a : i32, b : i32 ) i32 { return a + b; }

test "basic add functionality" { try std.testing.expect( add( 3, 7 ) == 10 ); }
