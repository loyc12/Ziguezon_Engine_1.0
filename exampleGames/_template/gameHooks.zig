const gameState  = @import( "stateInjects.zig" );

  pub const OnStart         = gameState.OnStart;
  pub const OnLaunch        = gameState.OnLaunch;
  pub const OnPlay          = gameState.OnPlay;

  pub const OnPause         = gameState.OnPause;
  pub const OnStop          = gameState.OnStop;
  pub const OnClose         = gameState.OnClose;


const gameStep   = @import( "stepInjects.zig" );

  pub const OnLoopStart     = gameStep.OnLoopStart;
  pub const OnLoopIter      = gameStep.OnLoopIter;
  pub const OnLoopEnd       = gameStep.OnLoopEnd;

  pub const OnUpdate        = gameStep.OnUpdate;
  pub const OnTick          = gameStep.OnTick;

  pub const OnRenderWorld   = gameStep.OnRenderWorld;
  pub const OnRenderOverlay = gameStep.OnRenderOverlay;
