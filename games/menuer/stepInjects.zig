const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

// ================================ GLOBAL GAME VARIABLES ================================

var MAIN_PANEL     : utl.UiId = .{};
var STATUS_LABEL   : utl.UiId = .{};
var COUNTER_LABEL  : utl.UiId = .{};
var CAPTURE_LABEL  : utl.UiId = .{};

var CLICK_BUTTON   : utl.UiId = .{};
var CHECKBOX       : utl.UiId = .{};
var POPUP_BUTTON   : utl.UiId = .{};
var MODAL_BUTTON   : utl.UiId = .{};
var WINDOW_BUTTON  : utl.UiId = .{};
var DEBUG_MENU_BUTTON : utl.UiId = .{};
var DEBUG_CHECKBOX : utl.UiId = .{};
var SLIDER         : utl.UiId = .{};
var SLIDER_LABEL   : utl.UiId = .{};

var POPUP_PANEL    : utl.UiId = .{};
var POPUP_SPAWN    : utl.UiId = .{};
var POPUP_CLOSE    : utl.UiId = .{};

var FEATURE_PANEL  : utl.UiId = .{};
var SCROLL_AREA    : utl.UiId = .{};

var MODAL_PANEL    : utl.UiId = .{};
var MODAL_CLOSE    : utl.UiId = .{};

var DEBUG_MENU        : utl.UiId = .{};
var DEBUG_MOVE_TOGGLE : utl.UiId = .{};
var DEBUG_MENU_CLOSE  : utl.UiId = .{};

var CLICK_COUNT    : u32 = 0;
var WINDOW_COUNT   : u32 = 0;


// ================================ UI SANDBOX ================================

pub fn buildUi( ng : *eng.Engine ) void
{
  var ui = &ng.uiManager;

  CLICK_COUNT  = 0;
  WINDOW_COUNT = 0;
  ui.setDebugOverlay( false, true );

  MAIN_PANEL = ui.createPanel(
    .{
      .box     = utl.uiBoxFromTopLeft( .{ .x = 24.0, .y = 24.0 }, .{ .x = 372.0, .y = 584.0 }),
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
  ) orelse utl.UiId.none();

  COUNTER_LABEL = ui.createLabel(
    .{
      .parent      = MAIN_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 24.0 },
      .text        = "Button clicks: 0",
    }
  ) orelse utl.UiId.none();

  CLICK_BUTTON = ui.createButton(
    .{
      .parent      = MAIN_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 34.0 },
      .text        = "Count click",
      .tooltip     = "Buttons emit clicked events through the UI-local buffer.",
    }
  ) orelse utl.UiId.none();

  CHECKBOX = ui.createCheckbox(
    .{
      .parent      = MAIN_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 34.0 },
      .text        = "Enable sandbox flag",
      .valueBool   = true,
      .tooltip     = "Checkboxes emit changed events and keep retained bool state.",
    }
  ) orelse utl.UiId.none();

  POPUP_BUTTON = ui.createButton(
    .{
      .parent      = MAIN_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 34.0 },
      .text        = "Open dependent popup",
      .tooltip     = "The popup is on the popup layer and closes on outside click or Escape.",
    }
  ) orelse utl.UiId.none();

  SLIDER_LABEL = ui.createLabel(
    .{
      .parent      = MAIN_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 24.0 },
      .text        = "Slider value: 42",
    }
  ) orelse utl.UiId.none();

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
  ) orelse utl.UiId.none();

  MODAL_BUTTON = ui.createButton(
    .{
      .parent      = MAIN_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 34.0 },
      .text        = "Open modal blocker",
      .tooltip     = "Modal nodes block lower-layer controls and do not close on outside click.",
    }
  ) orelse utl.UiId.none();

  WINDOW_BUTTON = ui.createButton(
    .{
      .parent      = MAIN_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 34.0 },
      .text        = "Spawn independent window",
      .tooltip     = "Creates a detached window without opening the dependent popup.",
    }
  ) orelse utl.UiId.none();

  DEBUG_MENU_BUTTON = ui.createButton(
    .{
      .parent      = MAIN_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 34.0 },
      .text        = "Open movable debug menu",
      .tooltip     = "The debug menu can toggle its own isMovable flag.",
    }
  ) orelse utl.UiId.none();

  DEBUG_CHECKBOX = ui.createCheckbox(
    .{
      .parent      = MAIN_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 34.0 },
      .text        = "Show UI debug overlay",
      .valueBool   = false,
      .tooltip     = "Draws retained UI internals without creating UI events itself.",
    }
  ) orelse utl.UiId.none();

  CAPTURE_LABEL = ui.createLabel(
    .{
      .parent      = MAIN_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 52.0 },
      .text        = "capture: free",
    }
  ) orelse utl.UiId.none();

  FEATURE_PANEL = ui.createPanel(
    .{
      .box     = utl.uiBoxFromTopLeft( .{ .x = 420.0, .y = 24.0 }, .{ .x = 354.0, .y = 330.0 }),
      .layout  = .vertical,
      .padding = 12.0,
      .gap     = 8.0,
    }
  ) orelse utl.UiId.none();

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
  ) orelse utl.UiId.none();

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

fn togglePopup( ng : *eng.Engine ) void
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
      .box            = utl.uiBoxFromTopLeft( .{ .x = 446.0, .y = 72.0 }, .{ .x = 286.0, .y = 158.0 }),
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
  ) orelse utl.UiId.none();

  POPUP_CLOSE = ui.createButton(
    .{
      .parent      = POPUP_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 34.0 },
      .text        = "Close popup",
      .tooltip     = "Closes this dependent popup and its owned controls.",
    }
  ) orelse utl.UiId.none();
}

fn openModal( ng : *eng.Engine ) void
{
  var ui = &ng.uiManager;

  if( ui.isNodeAlive( MODAL_PANEL )){ return; }

  MODAL_PANEL = ui.createPanel(
    .{
      .box            = utl.uiBoxFromTopLeft( .{ .x = 330.0, .y = 166.0 }, .{ .x = 376.0, .y = 178.0 }),
      .layout         = .vertical,
      .padding        = 12.0,
      .gap            = 8.0,
      .isModal        = true,
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
      .text        = "Lower panels are blocked. Outside click does not close this.",
    }
  );

  MODAL_CLOSE = ui.createButton(
    .{
      .parent      = MODAL_PANEL,
      .desiredSize = .{ .x = 0.0, .y = 34.0 },
      .text        = "Close modal",
      .tooltip     = "Escape also closes this modal.",
    }
  ) orelse utl.UiId.none();
}

fn openDebugMenu( ng : *eng.Engine ) void
{
  var ui = &ng.uiManager;

  if( ui.isNodeAlive( DEBUG_MENU )){ return; }

  DEBUG_MENU = ui.createWindow(
    .{
      .box           = utl.uiBoxFromTopLeft( .{ .x = 812.0, .y = 72.0 }, .{ .x = 324.0, .y = 174.0 }),
      .layout        = .vertical,
      .padding       = 10.0,
      .gap           = 8.0,
      .isMovable     = false,
      .closeOnEscape = true,
      .tooltip       = "Click empty menu space and drag after movability is enabled.",
    }
  ) orelse return;

  _ = ui.createLabel(
    .{
      .parent      = DEBUG_MENU,
      .desiredSize = .{ .x = 0.0, .y = 24.0 },
      .text        = "Movable debug menu",
    }
  );

  _ = ui.createLabel(
    .{
      .parent      = DEBUG_MENU,
      .desiredSize = .{ .x = 0.0, .y = 36.0 },
      .text        = "Toggle movement, then drag empty menu space.",
    }
  );

  DEBUG_MOVE_TOGGLE = ui.createButton(
    .{
      .parent      = DEBUG_MENU,
      .desiredSize = .{ .x = 0.0, .y = 34.0 },
      .text        = "Movable: off",
      .tooltip     = "Toggles this menu's retained isMovable flag.",
    }
  ) orelse utl.UiId.none();

  DEBUG_MENU_CLOSE = ui.createButton(
    .{
      .parent      = DEBUG_MENU,
      .desiredSize = .{ .x = 0.0, .y = 34.0 },
      .text        = "Close debug menu",
    }
  ) orelse utl.UiId.none();
}

fn spawnWindow( ng : *eng.Engine ) void
{
  var ui = &ng.uiManager;

  WINDOW_COUNT += 1;

  const offset : f64 = @floatFromInt(( WINDOW_COUNT - 1 ) % 5 );
  const window = ui.createWindow(
    .{
      .box           = utl.uiBoxFromTopLeft( .{ .x = 420.0 + ( offset * 28.0 ), .y = 246.0 + ( offset * 20.0 ) }, .{ .x = 320.0, .y = 148.0 }),
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
  ) orelse utl.UiId.none();
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

fn handleUiEvents( ng : *eng.Engine ) void
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
        else if( event.node.isEq( WINDOW_BUTTON ))
        {
          spawnWindow( ng );
          ui.setText( STATUS_LABEL, "Independent window spawned directly." );
        }
        else if( event.node.isEq( DEBUG_MENU_BUTTON ))
        {
          openDebugMenu( ng );
          ui.setText( STATUS_LABEL, "Debug menu opened." );
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
        else if( event.node.isEq( DEBUG_MOVE_TOGGLE ))
        {
          const isMovable = !ui.getMovable( DEBUG_MENU );
          ui.setMovable( DEBUG_MENU, isMovable );
          ui.setTextFmt( DEBUG_MOVE_TOGGLE, "Movable: {s}", .{ if( isMovable ) "on" else "off" });
          ui.setTextFmt( STATUS_LABEL, "Debug menu movable: {s}", .{ if( isMovable ) "on" else "off" });
        }
        else if( event.node.isEq( DEBUG_MENU_CLOSE ))
        {
          ui.closeNode( DEBUG_MENU );
          ui.setText( STATUS_LABEL, "Debug menu closed." );
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
        else if( event.node.isEq( DEBUG_MENU ))
        {
          DEBUG_MENU = .{};
          DEBUG_MOVE_TOGGLE = .{};
          DEBUG_MENU_CLOSE = .{};
        }
      },
    }
  }
}

fn updateCaptureLabel( ng : *eng.Engine ) void
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

pub fn OnLoopStart( ng : *eng.Engine ) void // Called by engine.loopLogic()
{
  _ = ng; // Prevent unused variable warning
}

pub fn OnLoopEnd( ng : *eng.Engine ) void // Called by engine.loopLogic()
{
  _ = ng; // Prevent unused variable warning
}

pub fn OnLoopCycle( ng : *eng.Engine ) void // Called by engine.loopLogic() ( every frame, no exception )
{
  _ = ng; // Prevent unused variable warning
}


// NOTE : This is where you should capture inputs to update global flags
pub fn OnUpdateFrame( ng : *eng.Engine ) void // Called by engine.updateInputs() ( every frame, no exception )
{
  handleUiEvents( ng );
  updateCaptureLabel( ng );

  const uiWantsKeyboard = ng.uiManager.wantsKeyboard();
  const uiWantsMouse    = ng.uiManager.wantsMouse();

  // Toggle pause if the P key is pressed
  if( !uiWantsKeyboard and ( utl.ray.isKeyPressed( utl.ray.KeyboardKey.enter ) or utl.ray.isKeyPressed( utl.ray.KeyboardKey.p ))){ ng.togglePause(); }

  // Move the camera with the WASD or arrow keys
  if( !uiWantsKeyboard )
  {
    if( utl.ray.isKeyDown( utl.ray.KeyboardKey.w ) or utl.ray.isKeyDown( utl.ray.KeyboardKey.up    )){ eng.G_CAM.moveByS( utl.Vec2.new(  0, -8 )); }
    if( utl.ray.isKeyDown( utl.ray.KeyboardKey.s ) or utl.ray.isKeyDown( utl.ray.KeyboardKey.down  )){ eng.G_CAM.moveByS( utl.Vec2.new(  0,  8 )); }
    if( utl.ray.isKeyDown( utl.ray.KeyboardKey.a ) or utl.ray.isKeyDown( utl.ray.KeyboardKey.left  )){ eng.G_CAM.moveByS( utl.Vec2.new( -8,  0 )); }
    if( utl.ray.isKeyDown( utl.ray.KeyboardKey.d ) or utl.ray.isKeyDown( utl.ray.KeyboardKey.right )){ eng.G_CAM.moveByS( utl.Vec2.new(  8,  0 )); }
  }

  // Zoom in and out with the mouse wheel
  if( !uiWantsMouse )
  {
    if( utl.ray.getMouseWheelMove() > 0.0 ){ eng.G_CAM.zoomBy( 1.1 ); }
    if( utl.ray.getMouseWheelMove() < 0.0 ){ eng.G_CAM.zoomBy( 0.9 ); }
  }

  // Reset the camera zoom and position when r is pressed
  if( !uiWantsKeyboard and utl.ray.isKeyPressed( utl.ray.KeyboardKey.r ))
  {
    eng.G_CAM.setZoom(   1.0 );
    eng.G_CAM.pos = .{};
    utl.qlog( .INFO, 0, @src(), "Camera reset" );
  }
}


// NOTE : This is where you should write gameplay logic ( AI, physics, etc. )
pub fn OnTickWorld( ng : *eng.Engine ) void // Called by engine.tryTick() ( every game frame, when not paused )
{
  _ = ng; // Prevent unused variable warning
}



// NOTE : This is where you should render all background effects besides the background reset ( done via )
pub fn OnRenderBckgrnd( ng : *eng.Engine ) void // Called by engine.renderGraphics()
{
  _ = ng; // Prevent unused variable warning
}


// NOTE : This is where you should render all world-position relative effects
pub fn OnRenderWorld( ng : *eng.Engine ) void // Called by engine.renderGraphics()
{
  // NOTE : All active bodies and tilemaps are rendered after the function is called, so no need to render them here.

  _ = ng; // Prevent unused variable warning
}

pub fn OffRenderWorld( ng : *eng.Engine ) void // Called by engine.renderGraphics()
{
  _ = ng; // Prevent unused variable warning
}


// NOTE : This is where you should render all screen-position relative effects ( UI, HUD, etc. )
pub fn OnRenderOverlay( ng : *eng.Engine ) void // Called by engine.renderGraphics()
{
  if( ng.isPaused() )
  {
    utl.sDraw.coverScreenWithCol( utl.Colour.new( 0, 0, 0, 128 )); // grays out the screen
  }
}
