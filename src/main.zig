//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import( "std" );
const h   = @import( "defs" );

pub fn main() !void
{
  h.initAll();
  defer h.deinitAll();

  h.eng.G_NG.changeState( .LAUNCHED );

  h.eng.G_NG.loopLogic();

  h.eng.G_NG.changeState( .CLOSED );
}

test "example test"
{
  h.misc.testTryCall();
}
