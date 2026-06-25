const eng      = @import( "engine" );
const utl      = @import( "utils" );
const common   = @import( "uiCommon.zig" );
const engineUi = @import( "engineUi.zig" );
const utilUi   = @import( "utilUi.zig" );


// ================================ UI SANDBOX STATE ================================

// Toggle with `u` at runtime. `false` drives direct utility UI; `true` drives
// the engine-owned manager path.
var ACTIVE_UI_USES_ENGINE_MANAGER : bool = false;

var DEBUG_PANEL : ?utl.Panel = null;

var DEBUG_TITLE   : utl.UiHandle = .{};
var DEBUG_MOUSE   : utl.UiHandle = .{};
var DEBUG_STATE   : utl.UiHandle = .{};
var DEBUG_HOVER   : utl.UiHandle = .{};
var DEBUG_CAPTURE : utl.UiHandle = .{};
var DEBUG_QUEUE   : utl.UiHandle = .{};

var ACTIVE_WANTS_MOUSE  : bool = false;
var DEBUG_PANEL_VISIBLE : bool = true;
var DEBUG_BOUNDS_ENABLED : bool = false;


// ================================ BUILD HELPERS ================================

/// Builds all sandbox UI storage and applies the current active-mode gate.
pub fn buildUi( ng : *eng.Engine ) void
{
  closeUi( ng );

  utilUi.build();
  engineUi.build( ng );
  buildDebugUi();
  applyDebugBounds();
  applyActiveMode( ng );
}

fn buildDebugUi() void
{
  DEBUG_PANEL = utl.Panel.init(
    utl.getDefaultAlloc(),
    .{
      .key    = utl.uiKey( "menuer.debug.panel" ),
      .box    = common.debugPanelBox(),
      .config = common.debugPanelConfig(),
    }
  ) catch | err |
  {
    utl.log( .ERROR, @src(), "Failed to create menuer debug panel : {}", .{ err });
    return;
  };

  var panel = &( DEBUG_PANEL.? );
  panel.setDebugDrawBounds( DEBUG_BOUNDS_ENABLED );

  DEBUG_TITLE = panel.addLabel(
    .{
      .key    = utl.uiKey( "menuer.debug.title" ),
      .text   = "UI sandbox debug",
      .config = common.labelConfig( 28.0 ),
    }
  ) catch .{};

  DEBUG_MOUSE = panel.addLabel(
    .{
      .key    = utl.uiKey( "menuer.debug.mouse" ),
      .text   = "mouse pending",
      .config = common.labelConfig( 38.0 ),
    }
  ) catch .{};

  DEBUG_STATE = panel.addLabel(
    .{
      .key    = utl.uiKey( "menuer.debug.state" ),
      .text   = "state pending",
      .config = common.labelConfig( 42.0 ),
    }
  ) catch .{};

  DEBUG_HOVER = panel.addLabel(
    .{
      .key    = utl.uiKey( "menuer.debug.hover" ),
      .text   = "hover pending",
      .config = common.labelConfig( 38.0 ),
    }
  ) catch .{};

  DEBUG_CAPTURE = panel.addLabel(
    .{
      .key    = utl.uiKey( "menuer.debug.capture" ),
      .text   = "capture pending",
      .config = common.labelConfig( 60.0 ),
    }
  ) catch .{};

  DEBUG_QUEUE = panel.addLabel(
    .{
      .key    = utl.uiKey( "menuer.debug.queue" ),
      .text   = "queue pending",
      .config = common.labelConfig( 46.0 ),
    }
  ) catch .{};

  panel.updateLayout();
}


// ================================ LIFETIME HELPERS ================================

/// Releases game-owned panels after unregistering any manager registrations.
pub fn closeUi( ng : ?*eng.Engine ) void
{
  engineUi.close( ng );
  utilUi.close();

  if( DEBUG_PANEL )| *panel |{ panel.deinit(); }

  DEBUG_PANEL = null;

  DEBUG_TITLE   = .{};
  DEBUG_MOUSE   = .{};
  DEBUG_STATE   = .{};
  DEBUG_HOVER   = .{};
  DEBUG_CAPTURE = .{};
  DEBUG_QUEUE   = .{};

  ACTIVE_WANTS_MOUSE  = false;
  DEBUG_PANEL_VISIBLE = true;
}

fn applyDebugBounds() void
{
  utilUi.applyDebugBounds( DEBUG_BOUNDS_ENABLED );
  engineUi.applyDebugBounds( DEBUG_BOUNDS_ENABLED );
  if( DEBUG_PANEL )| *panel |{ panel.setDebugDrawBounds( DEBUG_BOUNDS_ENABLED ); }
}

fn applyActiveMode( ng : *eng.Engine ) void
{
  clearQueuedUiEvents( ng );
  engineUi.applyActiveMode( ng, ACTIVE_UI_USES_ENGINE_MANAGER );
}

fn clearQueuedUiEvents( ng : *eng.Engine ) void
{
  utilUi.clearEvents();
  engineUi.clearEvents( ng );
}

fn toggleActiveMode( ng : *eng.Engine ) void
{
  ACTIVE_UI_USES_ENGINE_MANAGER = !ACTIVE_UI_USES_ENGINE_MANAGER;
  applyActiveMode( ng );

  utl.log( .INFO, @src(), "Menuer active UI mode : {s}", .{ activeModeName() });
}

fn toggleDebugBounds() void
{
  DEBUG_BOUNDS_ENABLED = !DEBUG_BOUNDS_ENABLED;
  applyDebugBounds();

  utl.log( .INFO, @src(), "Menuer UI debug bounds : {}", .{ DEBUG_BOUNDS_ENABLED });
}

fn toggleDebugPanel() void
{
  DEBUG_PANEL_VISIBLE = !DEBUG_PANEL_VISIBLE;

  utl.log( .INFO, @src(), "Menuer UI debug panel : {}", .{ DEBUG_PANEL_VISIBLE });
}


// ================================ UPDATE HELPERS ================================

fn updateActiveUi( ng : *eng.Engine ) bool
{
  return if( ACTIVE_UI_USES_ENGINE_MANAGER ) engineUi.update( ng ) else utilUi.update( ng );
}

fn updateDebugUi( ng : *eng.Engine ) void
{
  if( !DEBUG_PANEL_VISIBLE ){ return; }

  if( DEBUG_PANEL )| *panel |
  {
    panel.setPanelBox( common.debugPanelBox() );

    panel.setTextFmt(
      DEBUG_TITLE,
      "UI sandbox debug | active:{s}",
      .{ activeModeName() }
    );
    panel.setTextFmt(
      DEBUG_MOUSE,
      "mouse {d:.0}:{d:.0} | wantsMouse:{} | bounds:{}",
      .{ ng.mouse.screenPos.x, ng.mouse.screenPos.y, ACTIVE_WANTS_MOUSE, DEBUG_BOUNDS_ENABLED }
    );

    if( ACTIVE_UI_USES_ENGINE_MANAGER )
    {
      engineUi.writeDebugUi( ng, panel, DEBUG_STATE, DEBUG_HOVER, DEBUG_CAPTURE, DEBUG_QUEUE );
    }
    else
    {
      utilUi.writeDebugUi( panel, DEBUG_STATE, DEBUG_HOVER, DEBUG_CAPTURE, DEBUG_QUEUE );
    }

    panel.updateLayout();
  }
}

fn activeModeName() []const u8
{
  return if( ACTIVE_UI_USES_ENGINE_MANAGER ) "engine" else "utility";
}

fn drawWorldOriginMarker() void
{
  const origin = utl.Vec2.new( 0.0, 0.0 );

  // World-space marker for checking camera pan/zoom behind the UI sandbox.
  eng.wDraw.basicCircle( origin, 18.0, utl.Colour.pGold.setA( 180 ));
  eng.wDraw.basicCirclePerim( origin, 18.0, utl.Colour.pTeal );
  eng.wDraw.basicLine( origin.add( .new( -34.0, 0.0 )), origin.add( .new( 34.0, 0.0 )), utl.Colour.pTeal, 2.0 );
  eng.wDraw.basicLine( origin.add( .new( 0.0, -34.0 )), origin.add( .new( 0.0, 34.0 )), utl.Colour.pTeal, 2.0 );
}


// ================================ STEP INJECTION FUNCTIONS ================================
// These functions are called by the engine at various points in the game loop.

pub fn OnLoopStart( ng : *eng.Engine ) void
{
  _ = ng;
}

pub fn OnLoopEnd( ng : *eng.Engine ) void
{
  _ = ng;
}

pub fn OnLoopUpdate( ng : *eng.Engine ) void
{
  _ = ng;
}

pub fn OnInputUpdate( ng : *eng.Engine ) void
{
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.u )){ toggleActiveMode( ng ); }
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.b )){ toggleDebugBounds();   }
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.d )){ toggleDebugPanel();    }

  ACTIVE_WANTS_MOUSE = updateActiveUi( ng );
  updateDebugUi( ng );

  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.enter ) or utl.ray.isKeyPressed( utl.ray.KeyboardKey.p )){ ng.togglePause(); }

  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.up    )){ eng.G_ENG.camera.moveByS( utl.Vec2.new(  0, -8 )); }
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.down  )){ eng.G_ENG.camera.moveByS( utl.Vec2.new(  0,  8 )); }
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.left  )){ eng.G_ENG.camera.moveByS( utl.Vec2.new( -8,  0 )); }
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.right )){ eng.G_ENG.camera.moveByS( utl.Vec2.new(  8,  0 )); }

  if( !ACTIVE_WANTS_MOUSE )
  {
    if( ng.mouse.wheelMove > 0.0 ){ eng.G_ENG.camera.zoomBy( 1.1 ); }
    if( ng.mouse.wheelMove < 0.0 ){ eng.G_ENG.camera.zoomBy( 0.9 ); }
  }

  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.r ))
  {
    eng.G_ENG.camera.setZoom(   1.0 );
    eng.G_ENG.camera.cam.pos = .{};
    utl.qlog( .INFO, @src(), "Camera reset" );
  }
}

pub fn OnTickUpdate( ng : *eng.Engine ) void
{
  _ = ng;
}

pub fn OnRenderBckgrnd( ng : *eng.Engine ) void
{
  _ = ng;
}

pub fn OnRenderWorld( ng : *eng.Engine ) void
{
  _ = ng;

  drawWorldOriginMarker();
}

pub fn OnRenderOverlay( ng : *eng.Engine ) void
{
  if( ng.isPaused() )
  {
    utl.sDraw.coverScreenWithCol( utl.Colour.new( 0, 0, 0, 128 ));
  }

  if( ACTIVE_UI_USES_ENGINE_MANAGER ){ engineUi.draw( ng ); }
  else{ utilUi.draw(); }

  if( DEBUG_PANEL_VISIBLE )
  {
    if( DEBUG_PANEL )| *panel |{ panel.draw(); }
  }
}
