const injEntity = @import( "entityInjects.zig" );

  pub const OnEntityRender = injEntity.OnEntityRender;


const injStep = @import( "stepInjects.zig" );

  pub const OnLoopStart     = injStep.OnLoopStart;
  pub const OnLoopIter      = injStep.OnLoopIter;
  pub const OnLoopEnd       = injStep.OnLoopEnd;

  pub const OnUpdate        = injStep.OnUpdate;
  pub const OnTick          = injStep.OnTick;

  pub const OnRenderWorld   = injStep.OnRenderWorld;
  pub const OnRenderOverlay = injStep.OnRenderOverlay;


const injState = @import( "stateInjects.zig" );

  pub const OnStart  = injState.OnStart;
  pub const OnLaunch = injState.OnLaunch;
  pub const OnPlay   = injState.OnPlay;

  pub const OnPause  = injState.OnPause;
  pub const OnStop   = injState.OnStop;
  pub const OnClose  = injState.OnClose;