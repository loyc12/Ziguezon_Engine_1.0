const gameState = @import( "stateInjects.zig" );

  pub const OnStart  = gameState.OnStart;
  pub const OnLaunch = gameState.OnLaunch;
  pub const OnPlay   = gameState.OnPlay;

  pub const OnPause  = gameState.OnPause;
  pub const OnStop   = gameState.OnStop;
  pub const OnClose  = gameState.OnClose;


const gameStep  = @import( "stepInjects.zig" );

  pub const OnLoopStart = gameStep.OnLoopStart;
  pub const OnLoopEnd   = gameStep.OnLoopEnd;
  pub const OnLoopIter  = gameStep.OnLoopIter;
//pub const OffLoopIter = gameStep.OffLoopIter; // NOTE : Useless for now ( equivalent to OnLoopIter )

  pub const OnUpdateStep  = gameStep.OnUpdateStep;
  pub const OffUpdateStep = gameStep.OffUpdateStep;
  pub const OnTickStep    = gameStep.OnTickStep;
//pub const OffTickStep   = gameStep.OffTickStep; // NOTE : Useless for now ( equivalent to OnTickStep )

  pub const OnRenderBackground  = gameStep.OnRenderBackground;
//pub const OffRenderBackground = gameStep.OffRenderBackground; // NOTE : Useless for now ( equivalent to OnRenderBackground )
  pub const OnRenderWorld       = gameStep.OnRenderWorld;
  pub const OffRenderWorld      = gameStep.OffRenderWorld;
  pub const OnRenderOverlay     = gameStep.OnRenderOverlay;
//pub const OffRenderOverlay    = gameStep.OffRenderOverlay; // NOTE : Useless for now ( equivalent to OnRenderOverlay )