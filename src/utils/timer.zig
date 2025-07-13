const std = @import( "std" );
const h   = @import( "defs" );

pub var G_TIMER : timer =
.{
  .epoch    = 0,
  .cutoff   = 0,
  .previous = 0,
  .current  = 0,
  .started  = false,
  .expired  = false,
  .lapCount = 0,
};

pub fn getNow() i128 { return std.time.nanoTimestamp(); }
pub fn initGlobalTimer() void { G_TIMER.qInit( getNow(), 0 ); }

pub fn getNewTimer() timer
{
  const tmp = getNow();
  return timer
  {
    .epoch    = tmp,
    .cutoff   = 0,
    .previous = tmp,
    .current  = tmp,
    .started  = true,
    .expired  = false,
    .lapCount = 0,
  };
}

pub fn getEpoch() i128 { return G_TIMER.epoch; }
pub fn getElapsedTime() i128
{
  G_TIMER.setCurrent( getNow() );
  return G_TIMER.getElapsedTime();
}

// This function returns the elapsed time since the last lap in nanoseconds
// It also updates the lap time to the current time
pub fn getLapTime() i128
{
  G_TIMER.setCurrent( getNow() );
  return G_TIMER.getLapTime();
}

// ================================ TIMER STRUCT ================================

pub const timer = struct
{
  // All times are in nanoseconds
  epoch  : i128 = 0, // start time ( 0 means no epoch )
  cutoff : i128 = 0, // end time   ( 0 means no cutoff )

  previous : i128 = 0,
  current  : i128 = 0,

  started : bool = false, // Whether the timer has started
  expired : bool = false, // Whether the timer has ended

  lapCount : u64 = 0, // Number of times the timer has been incremented ( aka lapped )
  maxLaps  : u64 = 0, // Maximum number of laps ( 0 means no limit )

  // ================ INITIALIZATION ================

  pub fn setEpoch(    self : *timer, startTime : i128 ) void { self.epoch  = startTime; }
  pub fn setCutoff(   self : *timer, endTime   : i128 ) void { self.cutoff = endTime; }
  pub fn setDuration( self : *timer, duration  : i128 ) void { self.cutoff = self.epoch + duration; }

  // ================ UPDATE ================

  pub fn qInit( self : *timer, startTime : i128, duration : i128 ) void
  {
    self.setEpoch( startTime );
    self.setDuration( duration );

    self.current  = startTime;
    self.previous = startTime;

    self.started = true;
    self.expired = false;
  }

  pub fn reset( self : *timer ) void
  {
    self.epoch    = 0;
    self.cutoff   = 0;
    self.previous = 0;
    self.current  = 0;
    self.started  = false;
    self.expired  = false;
    self.lapCount = 0;
  }

  pub fn updateStatus( self : *timer ) void
  {
    if( self.epoch   != 0 and self.current  >= self.epoch   ){ self.started = true; }
    if( self.cutoff  != 0 and self.current  >= self.cutoff  ){ self.expired = true; }
    if( self.maxLaps != 0 and self.lapCount >= self.maxLaps ){ self.expired = true; }
  }

  pub fn setCurrent(  self : *timer, currentTime : i128 ) void
  {
    self.previous = self.current;
    self.current  = currentTime;
    self.updateStatus();
  }

  pub fn incrementTime( self : *timer, delta: i128 ) void
  {
    self.previous = self.current;
    self.current += delta;

    self.lapCount += 1;
  }

  // ================ ACCESSORS ================

  pub fn isStarted( self : *const timer ) bool { return ( self.epoch  == 0 or  self.started ); }
  pub fn isExpired( self : *const timer ) bool { return ( self.cutoff != 0 and self.expired ); }

  pub fn getElapsedTime( self : *const timer ) i128
  {
    if ( self.epoch == 0 ) return 0; // No epoch set

    return self.current - self.epoch;
  }
  pub fn getRemainingTime( self : *const timer ) i128
  {
    if ( self.cutoff == 0 ) return 0.0; // No cutoff set

    return self.cutoff - self.current;
  }

  pub fn getLapTime( self : *const timer ) i128
  {
    if ( self.previous == 0 or self.current == 0 ) return 0; // No previous or current time set

    return self.current - self.previous;
  }

  pub fn getProgress( self : *const timer ) f32
  {
    if( self.epoch == 0 or self.cutoff == 0 ) return 0.0; // No cutoff or epoch set

    const elapsed = self.getElapsedTime();
    return h.lerp( self.epoch, self.cutoff, elapsed );
  }
};