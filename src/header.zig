const std = @import( "std" );
const alloc = std.heap.page_allocator;

pub const initEpoch = @import( "debugLog.zig" ).initEpoch;
pub const logMsg    = @import( "debugLog.zig" ).logMsg;