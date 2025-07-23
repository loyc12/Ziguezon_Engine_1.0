const std = @import( "std" );
const def = @import( "defs" );

// NOTE : We treat zero ( the exact time of the "universal" epoch : UTC 1970-01-01 )
// as a uninitialized time. This hopefully shouldn't cause any issues, as time is mesured
// in nanoseconds, and the epoch is set to 1970-01-01 00:00:00Z, which is >55 years ago

pub fn getNow() i128 { return std.time.nanoTimestamp(); }

pub fn getNewTimer() timer
{
  const tmp = getNow();
  return timer
  {
    .epoch    = tmp,
    .latest   = tmp,
    .started  = true,
  };
}

// ================================ TIMER STRUCT ================================

pub const timer = struct
{
  // All times are in nanoseconds
  epoch  : i128 = 0, // Start time ( 0 means no epoch )
  cutoff : i128 = 0, // End time   ( 0 means no cutoff )

  latest : i128 = 0, // Latest time set ( used for lap time )
  delta  : i128 = 0, // Delta time ( used for lap time )

  lapCount : u32 = 0, // Number of times the timer has been incremented ( aka lapped )
  maxLaps  : u32 = 0, // Maximum number of laps ( 0 means no limit )

  started : bool = false, // Whether the timer has started
  expired : bool = false, // Whether the timer has ended


  // ================ INITIALIZATION ================

  pub fn setEpoch(    self : *timer, startTime : i128 ) void { self.epoch  = startTime; }
  pub fn setCutoff(   self : *timer, endTime   : i128 ) void { self.cutoff = endTime; }
  pub fn setDuration( self : *timer, duration  : i128 ) void
  {
    if( self.epoch == 0 )
    {
      def.qlog( .WARN, 0, @src(), "Tried to set duration without an epoch set" );
      return;
    }
    self.cutoff = self.epoch + duration;
  }

  // ================ UPDATE ================

  pub fn qInit( self : *timer, startTime : i128, duration : i128 ) void
  {
    self.setEpoch( startTime );
    self.setDuration( duration );

    self.latest = startTime;
    self.delta  = 0;

    self.lapCount = 0;
    self.maxLaps  = 0;

    self.started = true;
    self.expired = false;
  }

  pub fn reset( self : *timer ) void
  {
    self.epoch    = 0;
    self.cutoff   = 0;

    self.latest   = 0;
    self.delta    = 0;

    self.lapCount = 0;
    self.maxLaps  = 0;

    self.started  = false;
    self.expired  = false;
  }

  pub fn incrementTo(  self : *timer, currentTime : i128 ) void
  {
    if( currentTime < self.latest )
    {
      def.log( .WARN, 0, @src(), "Tried to increment timer to a past time ({d})", .{ currentTime });
      return;
    }
    // Prevents outrageous delta times if lastest had not yet been set
    if( self.latest != 0 ){ self.delta = currentTime - self.latest; }
    else( def.qlog( .DEBUG, 0, @src(), "Tried to increment timer without a previous time set" ));

    self.latest    = currentTime;
    self.lapCount += 1;

    self.updateStatus();
  }

  pub fn incrementBy( self : *timer, deltaTime: i128 ) void
  {
    if( deltaTime < 0 )
    {
      def.log( .WARN, 0, @src(), "Tried to increment timer by a non-positive delta time ({d})", .{ deltaTime });
      return;
    }
    self.delta     = deltaTime;
    self.latest   += deltaTime;
    self.lapCount += 1;

    self.updateStatus();
  }

  pub fn updateStatus( self : *timer ) void
  {
    self.started = self.isStarted();
    self.expired = self.isExpired();
  }

  // ================ ACCESSORS ================

  pub fn isStarted( self : *const timer ) bool
  {
    if( self.epoch == 0 ) return true; // No epoch set, timer is considered started
    if( self.latest >= self.epoch ) return true; // Timer started after epoch
    return false; // Timer not started yet
  }
  pub fn isExpired( self : *const timer ) bool
  {
    if( self.cutoff  == 0 and self.maxLaps == 0 ) return false; // No cutoff or max laps set
    if( self.cutoff  != 0 and self.latest   >= self.cutoff  ) return true; // Cutoff reached
    if( self.maxLaps != 0 and self.lapCount >= self.maxLaps ) return true; // Max laps reached
    return false; // Not expired
  }

  pub fn getPreviousTime( self : *const timer ) i128
  {
    if ( self.latest == 0 ) return 0;

    const tmp = self.latest - self.delta;

    // Previous time cannot be before epoch
    if( tmp < self.epoch ) return self.epoch;
    return tmp;
  }

  pub fn getTotalDuration( self : *const timer ) i128
  {
    if( self.epoch or self.cutoff == 0 )
    {
      def.log( .WARN, 0, @src(), "Tried to get total duration without an epoch and/or cutoff set" );
      return 0;
    }
    return self.cutoff - self.epoch;
  }

  pub fn getElapsedTime( self : *const timer ) i128
  {
    if(  self.epoch == 0  ) return 0;
    if( !self.isStarted() ) return 0;

    return self.latest - self.epoch;
  }
  pub fn getRemainTime( self : *const timer ) i128
  {
    if(  self.cutoff == 0 ) return 0;
    if(  self.isExpired() ) return 0;
    if( !self.isStarted() ) return self.getTotalDuration(); // Timer not yet started

    return self.cutoff - self.latest;
  }

  pub fn getElapsedFraction( self : *const timer ) f32
  {
    if(  self.epoch == 0 or self.cutoff == 0 ) return 0;
    if(  self.isExpired() ) return 1;
    if( !self.isStarted() ) return 0;

    return @floatFromInt( @divTrunc( self.getElapsedTime(), self.getTotalDuration() ));
  }
  pub fn getRemainFraction( self : *const timer ) f32
  {
    if(  self.epoch == 0 or self.cutoff == 0 ) return 0;
    if(  self.isExpired() ) return 0;
    if( !self.isStarted() ) return 1;

    return @floatFromInt( @divTrunc( self.getRemainTime(), self.getTotalDuration() ));
  }
};