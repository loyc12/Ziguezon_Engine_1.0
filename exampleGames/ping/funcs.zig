const gameState = @import( "stateInjects.zig" );

  pub const OnLaunch = gameState.OnLaunch;


const gameStep = @import( "stepInjects.zig" );

  pub const OnUpdate        = gameStep.OnUpdate;
  pub const OnTick          = gameStep.OnTick;
  pub const OnRenderOverlay = gameStep.OnRenderOverlay;