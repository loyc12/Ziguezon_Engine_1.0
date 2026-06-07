pub const duration = @import( "duration.zig" );
pub const instant  = @import( "instant.zig" );
pub const timer    = @import( "timerCore.zig" );

pub const gameTimer = @import( "gameTimer.zig" );
pub const realTimer = @import( "realTimer.zig" );

pub const Duration = duration.Duration;
pub const Instant  = instant.Instant;

pub const TimeUnit  = duration.TimeUnit;
pub const TimeRatio = duration.TimeRatio;

pub const getTimeRatio = duration.getTimeRatio;

pub const TimerCore   = timer.TimerCore;
pub const TimerLoop   = timer.TimerLoop;
pub const TimerState  = timer.TimerState;
pub const TimerUpdate = timer.TimerUpdate;

pub const GameTimer = gameTimer.GameTimer;
pub const RealTimer = realTimer.RealTimer;

pub const getNow              = instant.getNow;
pub const getDurationSince    = instant.getDurationSince;
pub const getDurationTo       = instant.getDurationTo;
pub const getDurationBetween  = instant.getDurationBetween;
