const gameState  = @import( "stateInjects.zig" );

  pub const OnStart         = gameState.OnStart;
  pub const OnLaunch        = gameState.OnLaunch;
  pub const OnPlay          = gameState.OnPlay;

  pub const OnPause         = gameState.OnPause;
  pub const OnStop          = gameState.OnStop;
  pub const OnClose         = gameState.OnClose;


const gameStep   = @import( "stepInjects.zig" );

  pub const OnLoopStart     = gameStep.OnLoopStart;
  pub const OnLoopEnd       = gameStep.OnLoopEnd;
  pub const OnLoopIter      = gameStep.OnLoopIter;
  pub const OffLoopIter     = gameStep.OffLoopIter;

  pub const OnUpdateStep    = gameStep.OnUpdateStep;
  pub const OffUpdateStep   = gameStep.OffUpdateStep;
  pub const OnTickStep      = gameStep.OnTickStep;
  pub const OffTickStep     = gameStep.OffTickStep;

  pub const OnRenderWorld   = gameStep.OnRenderWorld;
  pub const OffRenderWorld  = gameStep.OffRenderWorld;
  pub const OnRenderOverlay = gameStep.OnRenderOverlay;
  pub const OffRenderOverlay = gameStep.OffRenderOverlay;
