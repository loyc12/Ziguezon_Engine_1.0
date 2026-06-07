const Duration = @import( "duration.zig" ).Duration;
const coreMod  = @import( "timerCore.zig" );

const TimerCore   = coreMod.TimerCore;
const TimerLoop   = coreMod.TimerLoop;
const TimerUpdate = coreMod.TimerUpdate;


// ================================ GAME TIMER ================================

// GameTimer is advanced by a caller-provided game/simulation delta. Use it for
// deterministic gameplay timers, pause-aware timers, and fixed-tick systems.
pub const GameTimer = struct
{
  core : TimerCore = .{},


  // ================ INITIALIZATION ================

  pub inline fn init( duration : ?Duration ) GameTimer
  {
    return .{ .core = .init( duration )};
  }

  pub inline fn started( duration : ?Duration ) GameTimer
  {
    return .{ .core = .started( duration )};
  }

  pub inline fn looping( duration : Duration, loop : TimerLoop ) GameTimer
  {
    return .{ .core = .looping( duration, loop )};
  }


  // ================ UPDATE ================

  pub inline fn update( self : *GameTimer, delta : Duration ) TimerUpdate
  {
    // The engine decides what `delta` means: real time, scaled sim time, fixed
    // tick time, etc. TimerCore only consumes the amount passed here.
    return self.core.updateBy( delta );
  }


  // ================ STATE ================

  pub inline fn start(   self : *GameTimer ) void { self.core.start();   }
  pub inline fn restart( self : *GameTimer ) void { self.core.restart(); }
  pub inline fn reset(   self : *GameTimer ) void { self.core.reset();   }
  pub inline fn stop(    self : *GameTimer ) void { self.core.stop();    }
  pub inline fn pause(   self : *GameTimer ) void { self.core.pause();   }
  pub inline fn unpause( self : *GameTimer ) void { self.core.unpause(); }

  pub inline fn isIdle(    self : *const GameTimer ) bool { return self.core.isIdle();    }
  pub inline fn isRunning( self : *const GameTimer ) bool { return self.core.isRunning(); }
  pub inline fn isPaused(  self : *const GameTimer ) bool { return self.core.isPaused();  }
  pub inline fn isDone(    self : *const GameTimer ) bool { return self.core.isDone();    }


  // ================ QUERIES ================

  pub inline fn getElapsed(             self : *const GameTimer ) Duration  { return self.core.getElapsed();             }
  pub inline fn getDuration(            self : *const GameTimer ) ?Duration { return self.core.getDuration();            }
  pub inline fn getRemaining(           self : *const GameTimer ) ?Duration { return self.core.getRemaining();           }
  pub inline fn getProgressFactor(      self : *const GameTimer ) f64       { return self.core.getProgressFactor();      }
  pub inline fn getTotalDuration(       self : *const GameTimer ) ?Duration { return self.core.getTotalDuration();       }
  pub inline fn getTotalProgress(       self : *const GameTimer ) Duration  { return self.core.getTotalProgress();       }
  pub inline fn getTotalProgressFactor( self : *const GameTimer ) f64       { return self.core.getTotalProgressFactor(); }
};
