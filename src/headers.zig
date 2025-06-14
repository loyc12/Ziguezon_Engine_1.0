pub const std = @import( "std" );

pub const timer  = @import( "utils/timer.zig" );
pub const logger = @import( "utils/logger.zig" );

// ================================ SHORTHANDS ================================
// These are shorthand imports for commonly used modules in the project.

pub const alloc = std.heap.smp_allocator;