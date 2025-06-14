const std = @import( "std" );

var G_EPOCH     : i128 = 0; // Global epoch variable
var G_LAP_EPOCH : i128 = 0; // Global lap time variable

// These functions are used to initialize the time variables
pub fn initTimer() void { G_EPOCH     = std.time.nanoTimestamp(); G_LAP_EPOCH = std.time.nanoTimestamp(); }

// These functions are used to get the current time variables
pub fn getEpoch()    i128 { return G_EPOCH; }
pub fn getLapEpoch() i128 { return G_LAP_EPOCH; }

// This function returns the elapsed time since the epoch in nanoseconds
pub fn getElapsedTime() i128 { return std.time.nanoTimestamp() - G_EPOCH; }

// This function returns the elapsed time since the last lap in nanoseconds
// It also updates the lap time to the current time
pub fn getLapTime() i128
{
    const current_time = std.time.nanoTimestamp();
    const elapsed_time = current_time - G_LAP_EPOCH;
    G_LAP_EPOCH = current_time; // Update the lap time to the current time
    return elapsed_time;
}
