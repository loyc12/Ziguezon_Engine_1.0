const std = @import( "std" );
const def = @import( "defs" );

// ================================ GLOBAL GAME VARIABLES ================================

var MAIN_PANEL     : def.UiId = .{};
var STATUS_LABEL   : def.UiId = .{};
var COUNTER_LABEL  : def.UiId = .{};
var CAPTURE_LABEL  : def.UiId = .{};

var CLICK_BUTTON   : def.UiId = .{};
var CHECKBOX       : def.UiId = .{};
var POPUP_BUTTON   : def.UiId = .{};
var MODAL_BUTTON   : def.UiId = .{};
var DEBUG_CHECKBOX : def.UiId = .{};
var SLIDER         : def.UiId = .{};
var SLIDER_LABEL   : def.UiId = .{};

var POPUP_PANEL    : def.UiId = .{};
var POPUP_SPAWN    : def.UiId = .{};
var POPUP_CLOSE    : def.UiId = .{};

var FEATURE_PANEL  : def.UiId = .{};
var SCROLL_AREA    : def.UiId = .{};

var MODAL_PANEL    : def.UiId = .{};
var MODAL_CLOSE    : def.UiId = .{};

var CLICK_COUNT    : u32 = 0;
var WINDOW_COUNT   : u32 = 0;


// ================================ UI SANDBOX ================================

pub fn buildUi( ng : *def.Engine ) void
{
  var ui = &ng.uiManager;

  CLICK_COUNT  = 0;
  WINDOW_COUNT = 0;
  ui.setDebugOverlay( false, true );

  MAIN_PANEL = ui.createPanel(
    .{
      .box     = def.uiBoxFromTopLeft( .{ .x = 24.0, .y = 24.0 }, .{ .x = 372.0, .y = 500.0 }),
      .layout  = .vertical,
      .padding = 12.0,
      .gap     = 8.0,
    }
  ) orelse return;

  _ = ui.createLabel(
    .{
      .parent      = MAIN_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 28.0 },
      .text        = "Retained UI v0.5",
    }
  );

  STATUS_LABEL = ui.createLabel(
    .{
      .parent      = MAIN_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 24.0 },
      .text        = "Click, drag, scroll, and open layered panels.",
    }
  ) orelse def.UiId.none();

  COUNTER_LABEL = ui.createLabel(
    .{
      .parent      = MAIN_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 24.0 },
      .text        = "Button clicks: 0",
    }
  ) orelse def.UiId.none();

  CLICK_BUTTON = ui.createButton(
    .{
      .parent      = MAIN_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 34.0 },
      .text        = "Count click",
      .tooltip     = "Buttons emit clicked events through the UI-local buffer.",
    }
  ) orelse def.UiId.none();

  CHECKBOX = ui.createCheckbox(
    .{
      .parent      = MAIN_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 34.0 },
      .text        = "Enable sandbox flag",
      .valueBool   = true,
      .tooltip     = "Checkboxes emit changed events and keep retained bool state.",
    }
  ) orelse def.UiId.none();

  POPUP_BUTTON = ui.createButton(
    .{
      .parent      = MAIN_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 34.0 },
      .text        = "Open dependent popup",
      .tooltip     = "The popup is on the popup layer and closes on outside click or Escape.",
    }
  ) orelse def.UiId.none();

  SLIDER_LABEL = ui.createLabel(
    .{
      .parent      = MAIN_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 24.0 },
      .text        = "Slider value: 42",
    }
  ) orelse def.UiId.none();

  SLIDER = ui.createSlider(
    .{
      .parent      = MAIN_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 38.0 },
      .valueFlt    = 42.0,
      .sliderMin   = 0.0,
      .sliderMax   = 100.0,
      .sliderStep  = 1.0,
      .tooltip     = "Drag the handle; the slider captures the mouse until release.",
    }
  ) orelse def.UiId.none();

  MODAL_BUTTON = ui.createButton(
    .{
      .parent      = MAIN_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 34.0 },
      .text        = "Open modal blocker",
      .tooltip     = "Modal nodes block lower-layer controls until they close.",
    }
  ) orelse def.UiId.none();

  DEBUG_CHECKBOX = ui.createCheckbox(
    .{
      .parent      = MAIN_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 34.0 },
      .text        = "Show UI debug overlay",
      .valueBool   = false,
      .tooltip     = "Draws retained UI internals without creating UI events itself.",
    }
  ) orelse def.UiId.none();

  CAPTURE_LABEL = ui.createLabel(
    .{
      .parent      = MAIN_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 52.0 },
      .text        = "capture: free",
    }
  ) orelse def.UiId.none();

  FEATURE_PANEL = ui.createPanel(
    .{
      .box     = def.uiBoxFromTopLeft( .{ .x = 420.0, .y = 24.0 }, .{ .x = 354.0, .y = 330.0 }),
      .layout  = .vertical,
      .padding = 12.0,
      .gap     = 8.0,
    }
  ) orelse def.UiId.none();

  _ = ui.createLabel(
    .{
      .parent      = FEATURE_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 26.0 },
      .text        = "Clip and scroll area",
    }
  );

  SCROLL_AREA = ui.createScrollArea(
    .{
      .parent      = FEATURE_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 216.0 },
      .layout      = .vertical,
      .padding     = 8.0,
      .gap         = 6.0,
      .tooltip     = "Mouse wheel over this box scrolls clipped retained children.",
    }
  ) orelse def.UiId.none();

  const scrollRows = [_][]const u8{
    "Clipped row 01",
    "Clipped row 02",
    "Clipped row 03",
    "Clipped row 04",
    "Clipped row 05",
    "Clipped row 06",
    "Clipped row 07",
    "Clipped row 08",
    "Clipped row 09",
    "Clipped row 10",
    "Clipped row 11",
    "Clipped row 12",
  };

  for( scrollRows )| rowText |
  {
    _ = ui.createButton(
      .{
        .parent      = SCROLL_AREA,
        .desiredSize = .{ .x = 0.0, .y = 30.0 },
        .text        = rowText,
        .tooltip     = "Scroll children stay clipped to the scroll-area bounds.",
      }
    );
  }

  _ = ui.createLabel(
    .{
      .parent      = FEATURE_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 36.0 },
      .text        = "Wheel here; popup/modal overlap.",
    }
  );
}

fn togglePopup( ng : *def.Engine ) void
{
  var ui = &ng.uiManager;

  if( ui.isNodeAlive( POPUP_PANEL ))
  {
    ui.closeNode( POPUP_PANEL );
    return;
  }

  POPUP_PANEL = ui.createPopup(
    .{
      .dependsOn      = POPUP_BUTTON,
      .box            = def.uiBoxFromTopLeft( .{ .x = 446.0, .y = 72.0 }, .{ .x = 286.0, .y = 158.0 }),
      .layout         = .vertical,
      .padding        = 10.0,
      .gap            = 8.0,
      .closeOnOutside = true,
      .closeOnEscape  = true,
    }
  ) orelse return;

  _ = ui.createLabel(
    .{
      .parent      = POPUP_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 24.0 },
      .text        = "Dependent popup",
    }
  );

  POPUP_SPAWN = ui.createButton(
    .{
      .parent      = POPUP_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 34.0 },
      .text        = "Spawn independent window",
      .tooltip     = "Windows are detached roots and stay open when this popup closes.",
    }
  ) orelse def.UiId.none();

  POPUP_CLOSE = ui.createButton(
    .{
      .parent      = POPUP_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 34.0 },
      .text        = "Close popup",
      .tooltip     = "Closes this dependent popup and its owned controls.",
    }
  ) orelse def.UiId.none();
}

fn openModal( ng : *def.Engine ) void
{
  var ui = &ng.uiManager;

  if( ui.isNodeAlive( MODAL_PANEL )){ return; }

  MODAL_PANEL = ui.createPanel(
    .{
      .box            = def.uiBoxFromTopLeft( .{ .x = 330.0, .y = 166.0 }, .{ .x = 376.0, .y = 178.0 }),
      .layout         = .vertical,
      .padding        = 12.0,
      .gap            = 8.0,
      .isModal        = true,
      .closeOnOutside = true,
      .closeOnEscape  = true,
    }
  ) orelse return;

  _ = ui.createLabel(
    .{
      .parent      = MODAL_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 26.0 },
      .text        = "Modal blocker",
    }
  );

  _ = ui.createLabel(
    .{
      .parent      = MODAL_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 42.0 },
      .text        = "Lower panels are blocked while this is open.",
    }
  );

  MODAL_CLOSE = ui.createButton(
    .{
      .parent      = MODAL_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 34.0 },
      .text        = "Close modal",
      .tooltip     = "Escape or outside click also closes this modal.",
    }
  ) orelse def.UiId.none();
}

fn spawnWindow( ng : *def.Engine ) void
{
  var ui = &ng.uiManager;

  WINDOW_COUNT += 1;

  const offset : f64 = @floatFromInt(( WINDOW_COUNT - 1 ) % 5 );
  const window = ui.createWindow(
    .{
      .box           = def.uiBoxFromTopLeft( .{ .x = 420.0 + ( offset * 28.0 ), .y = 246.0 + ( offset * 20.0 ) }, .{ .x = 320.0, .y = 148.0 }),
      .layout        = .vertical,
      .padding       = 10.0,
      .gap           = 8.0,
      .closeOnEscape = true,
    }
  ) orelse return;

  const title = ui.createLabel(
    .{
      .parent      = window,
      .desiredSize = .{ .x = 0.0, .y = 24.0 },
      .text        = "Independent window",
    }
  ) orelse def.UiId.none();
  ui.setTextFmt( title, "Independent window #{d}", .{ WINDOW_COUNT });

  _ = ui.createLabel(
    .{
      .parent      = window,
      .desiredSize = .{ .x = 0.0, .y = 42.0 },
      .text        = "This window has no dependency on the popup.",
    }
  );

  _ = ui.createButton(
    .{
      .parent      = window,
      .desiredSize = .{ .x = 0.0, .y = 34.0 },
      .text        = "Close window",
      .tooltip     = "Closes only this independent window.",
    }
  );
}

fn handleUiEvents( ng : *def.Engine ) void
{
  var ui = &ng.uiManager;

  while( ui.popEvent() )| event |
  {
    switch( event.eType )
    {
      .clicked =>
      {
        if( event.node.isEq( CLICK_BUTTON ))
        {
          CLICK_COUNT += 1;
          ui.setTextFmt( COUNTER_LABEL, "Button clicks: {d}", .{ CLICK_COUNT });
          ui.setText( STATUS_LABEL, "Button click event received." );
        }
        else if( event.node.isEq( POPUP_BUTTON ))
        {
          togglePopup( ng );
          ui.setText( STATUS_LABEL, "Popup button event received." );
        }
        else if( event.node.isEq( MODAL_BUTTON ))
        {
          openModal( ng );
          ui.setText( STATUS_LABEL, "Modal opened; lower controls are blocked." );
        }
        else if( event.node.isEq( POPUP_SPAWN ))
        {
          spawnWindow( ng );
          ui.setText( STATUS_LABEL, "Independent window spawned." );
        }
        else if( event.node.isEq( POPUP_CLOSE ))
        {
          ui.closeNode( POPUP_PANEL );
          ui.setText( STATUS_LABEL, "Popup closed from button." );
        }
        else if( event.node.isEq( MODAL_CLOSE ))
        {
          ui.closeNode( MODAL_PANEL );
          ui.setText( STATUS_LABEL, "Modal closed from button." );
        }
        else if( std.mem.eql( u8, ui.getText( event.node ), "Close window" ))
        {
          ui.closeNode( ui.getParent( event.node ));
          ui.setText( STATUS_LABEL, "Independent window closed." );
        }
      },

      .changed =>
      {
        if( event.node.isEq( CHECKBOX ))
        {
          ui.setTextFmt( STATUS_LABEL, "Checkbox changed: {s}", .{ if( event.valueBool ) "on" else "off" });
        }
        else if( event.node.isEq( DEBUG_CHECKBOX ))
        {
          ui.setDebugOverlay( event.valueBool, true );
          ui.setTextFmt( STATUS_LABEL, "Debug overlay: {s}", .{ if( event.valueBool ) "shown" else "hidden" });
        }
        else if( event.node.isEq( SLIDER ))
        {
          ui.setTextFmt( SLIDER_LABEL, "Slider value: {d:.0}", .{ event.valueFlt });
          ui.setText( STATUS_LABEL, "Slider changed while dragging." );
        }
      },

      .closed =>
      {
        if( event.node.isEq( POPUP_PANEL ))
        {
          POPUP_PANEL = .{};
          POPUP_SPAWN = .{};
          POPUP_CLOSE = .{};
        }
        else if( event.node.isEq( MODAL_PANEL ))
        {
          MODAL_PANEL = .{};
          MODAL_CLOSE = .{};
        }
      },
    }
  }
}

fn updateCaptureLabel( ng : *def.Engine ) void
{
  var ui = &ng.uiManager;

  ui.setTextFmt(
    CAPTURE_LABEL,
    "capture mouse:{s} key:{s}\nhover:{s} focus:{s} press:{s}",
    .{
      if( ui.wantsMouse()    ) "yes" else "no",
      if( ui.wantsKeyboard() ) "yes" else "no",
      ui.getNodeKindName( ui.getHoveredId() ),
      ui.getNodeKindName( ui.getFocusedId() ),
      ui.getNodeKindName( ui.getPressedId() ),
    }
  );
}


// ================================ STEP INJECTION FUNCTIONS ================================
// These functions are called by the engine at various points in the game loop ( see loopLogic() in engine.zig ).

pub fn OnLoopStart( ng : *def.Engine ) void // Called by engine.loopLogic()
{
  _ = ng; // Prevent unused variable warning
}

pub fn OnLoopEnd( ng : *def.Engine ) void // Called by engine.loopLogic()
{
  _ = ng; // Prevent unused variable warning
}

pub fn OnLoopCycle( ng : *def.Engine ) void // Called by engine.loopLogic() ( every frame, no exception )
{
  _ = ng; // Prevent unused variable warning
}


// NOTE : This is where you should capture inputs to update global flags
pub fn OnUpdateFrame( ng : *def.Engine ) void // Called by engine.updateInputs() ( every frame, no exception )
{
  handleUiEvents( ng );
  updateCaptureLabel( ng );

  const uiWantsKeyboard = ng.uiManager.wantsKeyboard();
  const uiWantsMouse    = ng.uiManager.wantsMouse();

  // Toggle pause if the P key is pressed
  if( !uiWantsKeyboard and ( def.ray.isKeyPressed( def.ray.KeyboardKey.enter ) or def.ray.isKeyPressed( def.ray.KeyboardKey.p ))){ ng.togglePause(); }

  // Move the camera with the WASD or arrow keys
  if( !uiWantsKeyboard )
  {
    if( def.ray.isKeyDown( def.ray.KeyboardKey.w ) or def.ray.isKeyDown( def.ray.KeyboardKey.up    )){ def.G_CAM.moveByS( def.Vec2.new(  0, -8 )); }
    if( def.ray.isKeyDown( def.ray.KeyboardKey.s ) or def.ray.isKeyDown( def.ray.KeyboardKey.down  )){ def.G_CAM.moveByS( def.Vec2.new(  0,  8 )); }
    if( def.ray.isKeyDown( def.ray.KeyboardKey.a ) or def.ray.isKeyDown( def.ray.KeyboardKey.left  )){ def.G_CAM.moveByS( def.Vec2.new( -8,  0 )); }
    if( def.ray.isKeyDown( def.ray.KeyboardKey.d ) or def.ray.isKeyDown( def.ray.KeyboardKey.right )){ def.G_CAM.moveByS( def.Vec2.new(  8,  0 )); }
  }

  // Zoom in and out with the mouse wheel
  if( !uiWantsMouse )
  {
    if( def.ray.getMouseWheelMove() > 0.0 ){ def.G_CAM.zoomBy( 1.1 ); }
    if( def.ray.getMouseWheelMove() < 0.0 ){ def.G_CAM.zoomBy( 0.9 ); }
  }

  // Reset the camera zoom and position when r is pressed
  if( !uiWantsKeyboard and def.ray.isKeyPressed( def.ray.KeyboardKey.r ))
  {
    def.G_CAM.setZoom(   1.0 );
    def.G_CAM.pos = .{};
    def.qlog( .INFO, 0, @src(), "Camera reset" );
  }
}


// NOTE : This is where you should write gameplay logic ( AI, physics, etc. )
pub fn OnTickWorld( ng : *def.Engine ) void // Called by engine.tryTick() ( every game frame, when not paused )
{
  _ = ng; // Prevent unused variable warning
}



// NOTE : This is where you should render all background effects besides the background reset ( done via )
pub fn OnRenderBckgrnd( ng : *def.Engine ) void // Called by engine.renderGraphics()
{
  _ = ng; // Prevent unused variable warning
}


// NOTE : This is where you should render all world-position relative effects
pub fn OnRenderWorld( ng : *def.Engine ) void // Called by engine.renderGraphics()
{
  // NOTE : All active bodies and tilemaps are rendered after the function is called, so no need to render them here.

  _ = ng; // Prevent unused variable warning
}

pub fn OffRenderWorld( ng : *def.Engine ) void // Called by engine.renderGraphics()
{
  _ = ng; // Prevent unused variable warning
}


// NOTE : This is where you should render all screen-position relative effects ( UI, HUD, etc. )
pub fn OnRenderOverlay( ng : *def.Engine ) void // Called by engine.renderGraphics()
{
  if( ng.isPaused() )
  {
    def.sDraw.coverScreenWithCol( def.Colour.new( 0, 0, 0, 128 )); // grays out the screen
  }
}
