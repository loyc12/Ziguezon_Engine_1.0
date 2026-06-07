const Duration = @import( "duration.zig" ).Duration;
const Instant  = @import( "instant.zig" ).Instant;
const coreMod  = @import( "timerCore.zig" );

const TimerCore   = coreMod.TimerCore;
const TimerLoop   = coreMod.TimerLoop;
const TimerUpdate = coreMod.TimerUpdate;


// ================================ REAL TIMER ================================

// RealTimer samples Instant.now() itself. Use it for UI/tooling/real elapsed
// delays, not deterministic simulation logic.
pub const RealTimer = struct
{
  core     : TimerCore = .{},
  // Last real timestamp used to compute the next update delta.
  lastTime : ?Instant  = null,


  // ================ INITIALIZATION ================

  pub inline fn init( duration : ?Duration ) RealTimer
  {
    return .{ .core = .init( duration )};
  }

  pub inline fn started( duration : ?Duration ) RealTimer
  {
    var timer : RealTimer = .init( duration );
    timer.start();
    return timer;
  }

  pub inline fn looping( duration : Duration, loop : TimerLoop ) RealTimer
  {
    var timer : RealTimer = .{ .core = .looping( duration, loop )};
    timer.lastTime = .now();
    return timer;
  }


  // ================ UPDATE ================

  pub fn update( self : *RealTimer ) TimerUpdate
  {
    // Convert real elapsed time since the last update into a TimerCore delta.
    const now : Instant = .now();
    defer self.lastTime = now;

    const last = self.lastTime orelse return .{};

    return self.core.updateBy( now.diff( last ));
  }


  // ================ STATE ================

  pub inline fn start( self : *RealTimer ) void
  {
    self.core.start();
    self.lastTime = .now();
  }

  pub inline fn restart( self : *RealTimer ) void
  {
    self.start();
  }

  pub inline fn reset( self : *RealTimer ) void
  {
    self.core.reset();
    self.lastTime = null;
  }

  pub inline fn stop( self : *RealTimer ) void
  {
    self.core.stop();
    self.lastTime = null;
  }

  pub inline fn pause( self : *RealTimer ) void
  {
    self.core.pause();
  }

  pub inline fn unpause( self : *RealTimer ) void
  {
    self.core.unpause();
    self.lastTime = .now();
  }

  pub inline fn isIdle(    self : *const RealTimer ) bool { return self.core.isIdle();    }
  pub inline fn isRunning( self : *const RealTimer ) bool { return self.core.isRunning(); }
  pub inline fn isPaused(  self : *const RealTimer ) bool { return self.core.isPaused();  }
  pub inline fn isDone(    self : *const RealTimer ) bool { return self.core.isDone();    }


  // ================ QUERIES ================

  pub inline fn getElapsed(             self : *const RealTimer ) Duration  { return self.core.getElapsed();             }
  pub inline fn getDuration(            self : *const RealTimer ) ?Duration { return self.core.getDuration();            }
  pub inline fn getRemaining(           self : *const RealTimer ) ?Duration { return self.core.getRemaining();           }
  pub inline fn getProgressFactor(      self : *const RealTimer ) f64       { return self.core.getProgressFactor();      }
  pub inline fn getTotalDuration(       self : *const RealTimer ) ?Duration { return self.core.getTotalDuration();       }
  pub inline fn getTotalProgress(       self : *const RealTimer ) Duration  { return self.core.getTotalProgress();       }
  pub inline fn getTotalProgressFactor( self : *const RealTimer ) f64       { return self.core.getTotalProgressFactor(); }
};
