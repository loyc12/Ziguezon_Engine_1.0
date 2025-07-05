const std = @import( "std" );
const h   = @import( "defs" );

pub fn testTryCall() void
{
  const module = struct
  {
    fn testFunc0() void { h.qlog( .DEBUG, 0, @src(), "testFunc0 called" ); }
    fn testFunc1( a : i32 ) void { h.log( .DEBUG, 0, @src(), "testFunc1 called with arg: {d}", .{ a } ); }
    fn testFunc2( a : i32, b : i32 ) void { h.log( .DEBUG, 0, @src(), "testFunc2 called with args: {d}, {d}", .{ a, b } ); }
  };

  // Test with correct function name and arguments
  h.tryCall( module, "testFunc0", .{} );
  h.tryCall( module, "testFunc1", .{ 42 } );
  h.tryCall( module, "testFunc2", .{ 1, 2 } );

  // Test with incorrect function name
  //h.tryCall( module, "testFunc3", .{ 1, 2 } );

  // Test with no arguments for a function that expects arguments
  //h.tryCall( module, "testFunc1", .{} );
}

pub fn tryCall( module : anytype, comptime f_name : []const u8, args : anytype ) void
{
  if( comptime !@hasDecl( module, f_name ))
  {
   // @compileError( "Function definition not found" );
    h.log( .WARN, 0, @src(), "Function definition for '{s}' not found", .{ f_name });
    return;
  }

  const func = @field( module, f_name );
  if( @typeInfo( @TypeOf( func )) != .@"fn" )
  {
    @compileError( "Field is not a function" );
    //h.log( .DEBUG, 0, @src(), "Field '{s}' is not a function", .{ f_name });
    //return;
  }

  if( @typeInfo( @TypeOf( args )) != .@"struct" )
  {
    @compileError( "Arguments must be a tuple" );
    //h.log( .DEBUG, 0, @src(), "Arguments must be a tuple, got {s}", .{ @typeName( args ) });
    //return;
  }

  h.log( .DEBUG, 0, @src(), "Calling function '{s}'", .{ f_name });

  switch( args.len )
  {
    0 => func(),
    1 => func( args[0] ),
    2 => func( args[0], args[1] ),
    3 => func( args[0], args[1], args[2] ),
    4 => func( args[0], args[1], args[2], args[3] ),
    5 => func( args[0], args[1], args[2], args[3], args[4] ),
    else => @compileError( "Unsupported number of arguments" ),
  }
}