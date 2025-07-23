const gameState = @import( "stateInjects.zig" );

  pub const OnLaunch = gameState.OnLaunch;


const gameStep = @import( "stepInjects.zig" );

  pub const OnUpdateStep = gameStep.OnUpdateStep;
  pub const OnTickStep   = gameStep.OnTickStep;
  pub const OffTickStep  = gameStep.OffTickStep;

  pub const OnRenderBackground = gameStep.OnRenderBackground;
  pub const OnRenderOverlay    = gameStep.OnRenderOverlay;