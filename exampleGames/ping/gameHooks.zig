const gameState = @import( "stateInjects.zig" );

  pub const OnStart = gameState.OnStart;
  pub const OnOpen  = gameState.OnOpen;

const gameStep = @import( "stepInjects.zig" );

  pub const OnUpdateInputs  = gameStep.OnUpdateInputs;

  pub const OnTickEntities  = gameStep.OnTickEntities;
  pub const OffTickEntities = gameStep.OffTickEntities;

  pub const OnRenderBackground = gameStep.OnRenderBackground;
  pub const OnRenderOverlay    = gameStep.OnRenderOverlay;