const eng = @import( "engine" );
const utl = @import( "utils" );


// ================================ UI SANDBOX STATE ================================

// Toggle with `u` at runtime. `false` drives direct utility UI; `true` drives
// the engine-owned manager path.
var ACTIVE_UI_USES_ENGINE_MANAGER : bool = false;

const PrimaryUiHandles = struct
{
  title       : utl.UiHandle = .{},
  status      : utl.UiHandle = .{},
  rowGroup    : utl.UiHandle = .{},
  countButton : utl.UiHandle = .{},
  optionCheck : utl.UiHandle = .{},
  moveButton  : utl.UiHandle = .{},
  absGroup    : utl.UiHandle = .{},
  absButton   : utl.UiHandle = .{},
  debug       : utl.UiHandle = .{},
};

const PrimaryUiKeys = struct
{
  title       : []const u8,
  status      : []const u8,
  rowGroup    : []const u8,
  countButton : []const u8,
  optionCheck : []const u8,
  moveButton  : []const u8,
  absGroup    : []const u8,
  absButton   : []const u8,
  spacer      : []const u8,
  debug       : []const u8,
};

const PrimaryUiState = struct
{
  clickCount : u32 = 0,
  moveStep   : u32 = 0,
  absCount   : u32 = 0,
  eventCount : u32 = 0,
};

var MAIN_PANEL  : ?utl.Panel = null;
var BACK_PANEL  : ?utl.Panel = null;
var FRONT_PANEL : ?utl.Panel = null;
var DEBUG_PANEL : ?utl.Panel = null;

var UTILITY_UI    : PrimaryUiHandles = .{};
var ENGINE_UI     : PrimaryUiHandles = .{};
var UTILITY_STATE : PrimaryUiState   = .{};
var ENGINE_STATE  : PrimaryUiState   = .{};

var BACK_LABEL  : utl.UiHandle = .{};
var BACK_DEBUG  : utl.UiHandle = .{};
var BACK_BUTTON : utl.UiHandle = .{};
var BACK_HANDLE  : eng.UiPanelHandle = .{};
var FRONT_HANDLE : eng.UiPanelHandle = .{};
var BACK_COUNT  : u32 = 0;

var DEBUG_TITLE   : utl.UiHandle = .{};
var DEBUG_MOUSE   : utl.UiHandle = .{};
var DEBUG_STATE   : utl.UiHandle = .{};
var DEBUG_HOVER   : utl.UiHandle = .{};
var DEBUG_CAPTURE : utl.UiHandle = .{};
var DEBUG_QUEUE   : utl.UiHandle = .{};

var ACTIVE_WANTS_MOUSE : bool = false;
var DEBUG_PANEL_VISIBLE : bool = true;
var DEBUG_BOUNDS_ENABLED : bool = false;


// ================================ UI SANDBOX LAYOUT ================================

fn primaryPanelBox() utl.Box2
{
  return utl.uiBoxFromTopLeft( .new( 24.0, 24.0 ), .new( 460.0, 390.0 ));
}

fn backPanelBox() utl.Box2
{
  return utl.uiBoxFromTopLeft( .new( 452.0, 104.0 ), .new( 300.0, 206.0 ));
}

fn debugPanelBox() utl.Box2
{
  const size = utl.Vec2.new( 430.0, 410.0 );
  return utl.uiBoxFromTopLeft( .new( utl.getScreenWidth() - size.x - 24.0, 24.0 ), size );
}

fn buttonConfig() utl.WidgetConfig
{
  return .{
    .desiredSize = .new( 0.0, 36.0 ),
    .textAlign   = .center,
  };
}

fn labelConfig( height : f64 ) utl.WidgetConfig
{
  return .{
    .desiredSize = .new( 0.0, height ),
  };
}

fn containerConfig( layout : utl.UiLayout, height : f64 ) utl.WidgetConfig
{
  return .{
    .layout      = layout,
    .desiredSize = .new( 0.0, height ),
    .padding     = 0.0,
    .gap         = 8.0,
  };
}

fn primaryPanelConfig( edgeCol : utl.Colour ) utl.PanelConfig
{
  var style = utl.UiStyle{};
  style.fillCol = utl.Colour.nBlack.setA( 214 );
  style.edgeCol = edgeCol;

  return .{
    .layout  = .column,
    .padding = 12.0,
    .gap     = 8.0,
    .style   = style,
  };
}

fn managerPanelConfig( fillCol : utl.Colour ) utl.PanelConfig
{
  var style = utl.UiStyle{};
  style.fillCol = fillCol;
  style.edgeCol = utl.Colour.pGold;

  return .{
    .layout  = .column,
    .padding = 10.0,
    .gap     = 8.0,
    .style   = style,
  };
}

fn debugPanelConfig() utl.PanelConfig
{
  var style = utl.UiStyle{};
  style.fillCol = utl.Colour.nBlack.setA( 210 );
  style.edgeCol = utl.Colour.pTeal;

  return .{
    .layout  = .column,
    .padding = 10.0,
    .gap     = 8.0,
    .style   = style,
  };
}


// ================================ BUILD HELPERS ================================

/// Builds all sandbox UI storage and applies the current active-mode gate.
pub fn buildUi( ng : *eng.Engine ) void
{
  closeUi( ng );

  UTILITY_STATE = .{};
  ENGINE_STATE  = .{};
  BACK_COUNT    = 0;

  buildUtilityUi();
  buildEngineUi( ng );
  buildDebugUi();
  applyActiveMode( ng );
}

fn buildUtilityUi() void
{
  MAIN_PANEL = utl.Panel.init(
    utl.getDefaultAlloc(),
    .{
      .key    = utl.uiKey( "menuer.utility.primary" ),
      .box    = primaryPanelBox(),
      .config = primaryPanelConfig( utl.Colour.pTeal ),
    }
  ) catch | err |
  {
    utl.log( .ERROR, @src(), "Failed to create menuer utility panel : {}", .{ err });
    return;
  };

  var panel = &( MAIN_PANEL.? );
  panel.setDebugDrawBounds( DEBUG_BOUNDS_ENABLED );

  addPrimaryControls(
    panel,
    &UTILITY_UI,
    .{
      .title       = "menuer.utility.title",
      .status      = "menuer.utility.status",
      .rowGroup    = "menuer.utility.row_group",
      .countButton = "menuer.utility.count_button",
      .optionCheck = "menuer.utility.option_check",
      .moveButton  = "menuer.utility.move_button",
      .absGroup    = "menuer.utility.absolute_group",
      .absButton   = "menuer.utility.absolute_button",
      .spacer      = "menuer.utility.spacer",
      .debug       = "menuer.utility.debug",
    },
    "Utility mode",
    "Direct Panel.updateInput(), local events, direct draw."
  );
}

fn buildEngineUi( ng : *eng.Engine ) void
{
  buildEnginePrimaryUi( ng );
  buildEngineBackUi( ng );
}

fn buildEnginePrimaryUi( ng : *eng.Engine ) void
{
  FRONT_PANEL = utl.Panel.init(
    utl.getDefaultAlloc(),
    .{
      .key    = utl.uiKey( "menuer.engine.primary" ),
      .box    = primaryPanelBox(),
      .config = primaryPanelConfig( utl.Colour.pGold ),
    }
  ) catch | err |
  {
    utl.log( .ERROR, @src(), "Failed to create menuer engine primary panel : {}", .{ err });
    return;
  };

  var panel = &( FRONT_PANEL.? );
  panel.setDebugDrawBounds( DEBUG_BOUNDS_ENABLED );

  addPrimaryControls(
    panel,
    &ENGINE_UI,
    .{
      .title       = "menuer.engine.title",
      .status      = "menuer.engine.status",
      .rowGroup    = "menuer.engine.row_group",
      .countButton = "menuer.engine.count_button",
      .optionCheck = "menuer.engine.option_check",
      .moveButton  = "menuer.engine.move_button",
      .absGroup    = "menuer.engine.absolute_group",
      .absButton   = "menuer.engine.absolute_button",
      .spacer      = "menuer.engine.spacer",
      .debug       = "menuer.engine.debug",
    },
    "Engine mode",
    "UiManager routes input, forwards events, and draws this panel."
  );

  FRONT_HANDLE = ng.uiManager.registerPanel( panel, .{ .key = utl.uiKey( "menuer.engine.primary" ), .layer = 5, .z = 1 } ) catch | err |
  {
    utl.log( .ERROR, @src(), "Failed to register menuer engine primary panel : {}", .{ err });
    return;
  };
}

fn buildEngineBackUi( ng : *eng.Engine ) void
{
  BACK_PANEL = utl.Panel.init(
    utl.getDefaultAlloc(),
    .{
      .key    = utl.uiKey( "menuer.engine.back" ),
      .box    = backPanelBox(),
      .config = managerPanelConfig( utl.Colour.dGray.setA( 225 )),
    }
  ) catch | err |
  {
    utl.log( .ERROR, @src(), "Failed to create menuer engine back panel : {}", .{ err });
    return;
  };

  var panel = &( BACK_PANEL.? );
  panel.setDebugDrawBounds( DEBUG_BOUNDS_ENABLED );

  BACK_LABEL = panel.addLabel(
    .{
      .key    = utl.uiKey( "menuer.engine.back.label" ),
      .text   = "Engine back panel",
      .config = labelConfig( 28.0 ),
    }
  ) catch .{};

  BACK_DEBUG = panel.addLabel(
    .{
      .key    = utl.uiKey( "menuer.engine.back.debug" ),
      .text   = "manager route pending",
      .config = labelConfig( 54.0 ),
    }
  ) catch .{};

  BACK_BUTTON = panel.addButton(
    .{
      .key    = utl.uiKey( "menuer.engine.back.button" ),
      .text   = "Back routed click",
      .config = buttonConfig(),
    }
  ) catch .{};

  panel.updateLayout();

  BACK_HANDLE = ng.uiManager.registerPanel( panel, .{ .key = utl.uiKey( "menuer.engine.back" ), .layer = 5, .z = 0 } ) catch | err |
  {
    utl.log( .ERROR, @src(), "Failed to register menuer engine back panel : {}", .{ err });
    return;
  };
}

fn buildDebugUi() void
{
  DEBUG_PANEL = utl.Panel.init(
    utl.getDefaultAlloc(),
    .{
      .key    = utl.uiKey( "menuer.debug.panel" ),
      .box    = debugPanelBox(),
      .config = debugPanelConfig(),
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
      .config = labelConfig( 28.0 ),
    }
  ) catch .{};

  DEBUG_MOUSE = panel.addLabel(
    .{
      .key    = utl.uiKey( "menuer.debug.mouse" ),
      .text   = "mouse pending",
      .config = labelConfig( 38.0 ),
    }
  ) catch .{};

  DEBUG_STATE = panel.addLabel(
    .{
      .key    = utl.uiKey( "menuer.debug.state" ),
      .text   = "state pending",
      .config = labelConfig( 42.0 ),
    }
  ) catch .{};

  DEBUG_HOVER = panel.addLabel(
    .{
      .key    = utl.uiKey( "menuer.debug.hover" ),
      .text   = "hover pending",
      .config = labelConfig( 38.0 ),
    }
  ) catch .{};

  DEBUG_CAPTURE = panel.addLabel(
    .{
      .key    = utl.uiKey( "menuer.debug.capture" ),
      .text   = "capture pending",
      .config = labelConfig( 60.0 ),
    }
  ) catch .{};

  DEBUG_QUEUE = panel.addLabel(
    .{
      .key    = utl.uiKey( "menuer.debug.queue" ),
      .text   = "queue pending",
      .config = labelConfig( 46.0 ),
    }
  ) catch .{};

  panel.updateLayout();
}

fn addPrimaryControls( panel : *utl.Panel, handles : *PrimaryUiHandles, keys : PrimaryUiKeys, title : []const u8, status : []const u8 ) void
{
  handles.title = panel.addLabel(
    .{
      .key    = utl.uiKey( keys.title ),
      .text   = title,
      .config = labelConfig( 28.0 ),
    }
  ) catch .{};

  handles.status = panel.addLabel(
    .{
      .key    = utl.uiKey( keys.status ),
      .text   = status,
      .config = labelConfig( 44.0 ),
    }
  ) catch .{};

  handles.rowGroup = panel.addContainer(
    .{
      .key    = utl.uiKey( keys.rowGroup ),
      .config = containerConfig( .row, 42.0 ),
    }
  ) catch .{};

  handles.countButton = panel.addButton(
    .{
      .key    = utl.uiKey( keys.countButton ),
      .parent = handles.rowGroup,
      .text   = "Count click",
      .config = .{
        .desiredSize = .new( 156.0, 36.0 ),
        .textAlign   = .center,
      },
    }
  ) catch .{};

  handles.optionCheck = panel.addCheckbox(
    .{
      .key    = utl.uiKey( keys.optionCheck ),
      .parent = handles.rowGroup,
      .text   = "Option",
      .config = .{
        .desiredSize = .new( 132.0, 36.0 ),
        .isChecked   = true,
      },
    }
  ) catch .{};

  handles.moveButton = panel.addButton(
    .{
      .key    = utl.uiKey( keys.moveButton ),
      .text   = "Move / style",
      .config = buttonConfig(),
    }
  ) catch .{};

  handles.absGroup = panel.addContainer(
    .{
      .key    = utl.uiKey( keys.absGroup ),
      .config = containerConfig( .absolute, 58.0 ),
    }
  ) catch .{};

  handles.absButton = panel.addButton(
    .{
      .key    = utl.uiKey( keys.absButton ),
      .parent = handles.absGroup,
      .box    = .{ .center = .new( -116.0, 0.0 ), .scale = .new( 86.0, 18.0 ) },
      .text   = "Absolute child",
      .config = .{ .textAlign = .center },
    }
  ) catch .{};

  _ = panel.addSpacer(
    .{
      .key    = utl.uiKey( keys.spacer ),
      .config = .{ .desiredSize = .new( 0.0, 8.0 ) },
    }
  ) catch .{};

  handles.debug = panel.addLabel(
    .{
      .key    = utl.uiKey( keys.debug ),
      .text   = "hover: none | final: none",
      .config = labelConfig( 74.0 ),
    }
  ) catch .{};

  panel.updateLayout();
}


// ================================ LIFETIME HELPERS ================================

/// Releases game-owned panels after unregistering any manager registrations.
pub fn closeUi( ng : ?*eng.Engine ) void
{
  if( ng )| engine |
  {
    if( BACK_HANDLE.isValid()  ){ _ = engine.uiManager.unregisterPanel( BACK_HANDLE  ); }
    if( FRONT_HANDLE.isValid() ){ _ = engine.uiManager.unregisterPanel( FRONT_HANDLE ); }
  }

  if( MAIN_PANEL  )| *panel |{ panel.deinit(); }
  if( BACK_PANEL  )| *panel |{ panel.deinit(); }
  if( FRONT_PANEL )| *panel |{ panel.deinit(); }
  if( DEBUG_PANEL )| *panel |{ panel.deinit(); }

  MAIN_PANEL  = null;
  BACK_PANEL  = null;
  FRONT_PANEL = null;
  DEBUG_PANEL = null;

  UTILITY_UI    = .{};
  ENGINE_UI     = .{};
  UTILITY_STATE = .{};
  ENGINE_STATE  = .{};

  BACK_LABEL   = .{};
  BACK_DEBUG   = .{};
  BACK_BUTTON  = .{};
  BACK_HANDLE  = .{};
  FRONT_HANDLE = .{};
  BACK_COUNT   = 0;

  DEBUG_TITLE   = .{};
  DEBUG_MOUSE   = .{};
  DEBUG_STATE   = .{};
  DEBUG_HOVER   = .{};
  DEBUG_CAPTURE = .{};
  DEBUG_QUEUE   = .{};

  ACTIVE_WANTS_MOUSE = false;
  DEBUG_PANEL_VISIBLE = true;
}

fn applyDebugBounds() void
{
  if( MAIN_PANEL  )| *panel |{ panel.setDebugDrawBounds( DEBUG_BOUNDS_ENABLED ); }
  if( BACK_PANEL  )| *panel |{ panel.setDebugDrawBounds( DEBUG_BOUNDS_ENABLED ); }
  if( FRONT_PANEL )| *panel |{ panel.setDebugDrawBounds( DEBUG_BOUNDS_ENABLED ); }
  if( DEBUG_PANEL )| *panel |{ panel.setDebugDrawBounds( DEBUG_BOUNDS_ENABLED ); }
}

fn applyActiveMode( ng : *eng.Engine ) void
{
  clearQueuedUiEvents( ng );

  const engineActive = ACTIVE_UI_USES_ENGINE_MANAGER;
  ng.uiManager.setPanelVisible(      FRONT_HANDLE, engineActive );
  ng.uiManager.setPanelInputEnabled( FRONT_HANDLE, engineActive );
  ng.uiManager.setPanelDrawEnabled(  FRONT_HANDLE, engineActive );
  ng.uiManager.setPanelVisible(      BACK_HANDLE,  engineActive );
  ng.uiManager.setPanelInputEnabled( BACK_HANDLE,  engineActive );
  ng.uiManager.setPanelDrawEnabled(  BACK_HANDLE,  engineActive );
}

fn clearQueuedUiEvents( ng : *eng.Engine ) void
{
  if( MAIN_PANEL  )| *panel |{ panel.clearEvents(); }
  if( BACK_PANEL  )| *panel |{ panel.clearEvents(); }
  if( FRONT_PANEL )| *panel |{ panel.clearEvents(); }
  ng.uiManager.clearEvents();
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

fn updateUtilityMode( ng : *eng.Engine ) bool
{
  if( MAIN_PANEL )| *panel |
  {
    panel.updateInput( ng.mouse );
    drainUtilityEvents( panel );
    updatePrimaryDebugLabel( panel, &UTILITY_UI, &UTILITY_STATE, "utility" );
    return panel.wantsMouse();
  }

  return false;
}

fn updateEngineMode( ng : *eng.Engine ) bool
{
  ng.uiManager.updateInput( ng.mouse );
  drainEngineEvents( ng );
  updateEnginePanelDebug( ng );

  if( FRONT_PANEL )| *panel |{ updatePrimaryDebugLabel( panel, &ENGINE_UI, &ENGINE_STATE, "engine" ); }

  return ng.uiManager.wantsMouse();
}

fn drainUtilityEvents( panel : *utl.Panel ) void
{
  while( panel.popEvent() )| event |
  {
    handlePrimaryEvent( panel, &UTILITY_UI, &UTILITY_STATE, event, "Utility" );
  }
}

fn drainEngineEvents( ng : *eng.Engine ) void
{
  while( ng.uiManager.popEvent() )| managerEvent |
  {
    if( managerEvent.panel.isEq( FRONT_HANDLE ))
    {
      if( FRONT_PANEL )| *panel |
      {
        handlePrimaryEvent( panel, &ENGINE_UI, &ENGINE_STATE, managerEvent.event, "Engine" );
      }
    }
    else if( managerEvent.panel.isEq( BACK_HANDLE ))
    {
      if( BACK_PANEL )| *panel |
      {
        if( managerEvent.event.isClicked( BACK_BUTTON ))
        {
          BACK_COUNT += 1;
          panel.setTextFmt( BACK_BUTTON, "Back routed ({d})", .{ BACK_COUNT });
        }
      }
    }
  }
}

fn handlePrimaryEvent( panel : *utl.Panel, handles : *const PrimaryUiHandles, state : *PrimaryUiState, event : utl.UiEvent, pathName : []const u8 ) void
{
  state.eventCount += 1;

  if( event.isClicked( handles.countButton ))
  {
    state.clickCount += 1;
    panel.setTextFmt( handles.countButton, "Count click ({d})", .{ state.clickCount });
    panel.setTextFmt( handles.status, "{s} button event. Total clicks: {d}.", .{ pathName, state.clickCount });
  }
  else if( event.isClicked( handles.moveButton ))
  {
    state.moveStep = ( state.moveStep + 1 ) % 7;

    const offset  = utl.Vec2.new( @as( f64, @floatFromInt( state.moveStep )) * 12.0, 0.0 );
    const visible = state.moveStep % 3 != 1;
    const enabled = state.moveStep % 2 == 0;

    panel.setVisualOffset( handles.moveButton, offset );
    panel.setStyle( handles.moveButton, moveButtonStyle( state.moveStep ));
    panel.setVisible( handles.absButton, visible );
    panel.setEnabled( handles.absButton, enabled );
    panel.setTextFmt( handles.status, "{s} mutation: offset {d:.0}px, abs V:{} E:{}.", .{ pathName, offset.x, visible, enabled });
  }
  else if( event.isClicked( handles.absButton ))
  {
    state.absCount += 1;

    const nextChecked = !( panel.getChecked( handles.optionCheck ) orelse false );
    panel.bringWidgetForward( handles.absButton );
    panel.setChecked( handles.optionCheck, nextChecked );
    panel.setTextFmt( handles.status, "{s} absolute child clicked ({d}); checkbox set to {}.", .{ pathName, state.absCount, nextChecked });
  }
  else if( event.isChanged( handles.optionCheck ))
  {
    const checked = panel.getChecked( handles.optionCheck ) orelse false;
    panel.setTextFmt( handles.status, "{s} checkbox changed. Checked: {}.", .{ pathName, checked });
  }
}

fn moveButtonStyle( step : u32 ) utl.UiStyle
{
  var style = utl.UiStyle.forKind( .button );

  if( step % 2 == 0 )
  {
    style.edgeCol   = utl.Colour.pTeal;
    style.accentCol = utl.Colour.pTeal;
  }
  else
  {
    style.edgeCol   = utl.Colour.pGold;
    style.accentCol = utl.Colour.pGold;
  }

  return style;
}

fn updatePrimaryDebugLabel( panel : *utl.Panel, handles : *const PrimaryUiHandles, state : *const PrimaryUiState, modeName : []const u8 ) void
{
  panel.updateLayout();

  const hovered = panel.getHovered();
  const pressed = panel.getPressed( .left );
  const hoverName =
    if( panel.getWidgetKind( hovered ))| kind | @tagName( kind )
    else "none";
  const pressedName =
    if( panel.getWidgetKind( pressed ))| kind | @tagName( kind )
    else "none";

  const childCount = panel.getChildCount( handles.rowGroup );

  if( panel.getWidgetFinalBox( handles.moveButton ))| box |
  {
    if( panel.getWidgetTextMetrics( handles.status ))| metrics |
    {
      panel.setTextFmt(
        handles.debug,
        "{s} h:{s} p:{s} ev:{d} wants:{}\nrow:{d} move:{d:.0},{d:.0} text:{d:.0}x{d:.0}",
        .{ modeName, hoverName, pressedName, state.eventCount, panel.wantsMouse(), childCount, box.center.x, box.center.y, metrics.measuredSize.x, metrics.lineHeight }
      );
    }
    else
    {
      panel.setTextFmt(
        handles.debug,
        "{s} h:{s} p:{s} ev:{d} wants:{}\nrow:{d} move:{d:.0},{d:.0} text:none",
        .{ modeName, hoverName, pressedName, state.eventCount, panel.wantsMouse(), childCount, box.center.x, box.center.y }
      );
    }
  }
  else
  {
    panel.setTextFmt( handles.debug, "{s} h:{s} p:{s} ev:{d}\nfinal:none", .{ modeName, hoverName, pressedName, state.eventCount });
  }
}

fn updateEnginePanelDebug( ng : *eng.Engine ) void
{
  if( BACK_PANEL )| *panel |
  {
    if( ng.uiManager.getRegistration( BACK_HANDLE ))| reg |
    {
      panel.setTextFmt(
        BACK_LABEL,
        "back h:{d}:{d} layer:{d} z:{d} order:{d}",
        .{ BACK_HANDLE.idx, BACK_HANDLE.gen, reg.layer, reg.z, reg.order }
      );
      panel.setTextFmt(
        BACK_DEBUG,
        "flags V:{} I:{} D:{} | events:{d} | clicks:{d}",
        .{ reg.isVisible, reg.isInputEnabled, reg.isDrawEnabled, panel.getEventCount(), BACK_COUNT }
      );
    }
  }
}

fn updateDebugUi( ng : *eng.Engine ) void
{
  if( !DEBUG_PANEL_VISIBLE ){ return; }

  if( DEBUG_PANEL )| *panel |
  {
    panel.setPanelBox( debugPanelBox() );

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
      updateEngineDebugUi( ng, panel );
    }
    else
    {
      updateUtilityDebugUi( panel );
    }

    panel.updateLayout();
  }
}

fn updateUtilityDebugUi( panel : *utl.Panel ) void
{
  if( MAIN_PANEL )| *main |
  {
    const hovered = main.getHovered();
    const left    = main.getPressed( .left   );
    const right   = main.getPressed( .right  );
    const middle  = main.getPressed( .middle );

    panel.setTextFmt(
      DEBUG_STATE,
      "utility events:{d} pending:{d} checked:{}",
      .{ UTILITY_STATE.eventCount, main.getEventCount(), main.getChecked( UTILITY_UI.optionCheck ) orelse false }
    );
    panel.setTextFmt(
      DEBUG_HOVER,
      "hover widget:{s}",
      .{ widgetNameInPanel( main, hovered ) }
    );
    panel.setTextFmt(
      DEBUG_CAPTURE,
      "pressed L:{s} R:{s} M:{s}",
      .{ widgetNameInPanel( main, left ), widgetNameInPanel( main, right ), widgetNameInPanel( main, middle ) }
    );
    panel.setTextFmt(
      DEBUG_QUEUE,
      "engine panels inert | active events:{d}",
      .{ UTILITY_STATE.eventCount }
    );
  }
}

fn updateEngineDebugUi( ng : *eng.Engine, panel : *utl.Panel ) void
{
  const hoveredPanel   = ng.uiManager.getHoveredPanel();
  const hoveredWidget  = ng.uiManager.getHoveredWidget();
  const capturedLeft   = ng.uiManager.getCapturedPanel( .left   );
  const capturedRight  = ng.uiManager.getCapturedPanel( .right  );
  const capturedMiddle = ng.uiManager.getCapturedPanel( .middle );

  panel.setTextFmt(
    DEBUG_STATE,
    "engine events:{d} pending:{d} wants:{}",
    .{ ENGINE_STATE.eventCount, ng.uiManager.getEventCount(), ng.uiManager.wantsMouse() }
  );
  panel.setTextFmt(
    DEBUG_HOVER,
    "hover panel:{s} widget:{s}",
    .{ panelName( hoveredPanel ), widgetName( ng, hoveredPanel, hoveredWidget ) }
  );
  panel.setTextFmt(
    DEBUG_CAPTURE,
    "capture L:{s}/{s} R:{s}/{s} M:{s}/{s}",
    .{
      panelName( capturedLeft   ), widgetName( ng, capturedLeft,   ng.uiManager.getCapturedWidget( .left   )),
      panelName( capturedRight  ), widgetName( ng, capturedRight,  ng.uiManager.getCapturedWidget( .right  )),
      panelName( capturedMiddle ), widgetName( ng, capturedMiddle, ng.uiManager.getCapturedWidget( .middle )),
    }
  );
  panel.setTextFmt(
    DEBUG_QUEUE,
    "front h:{d}:{d} back h:{d}:{d}\ndraw {s}>{s} panels:{d}",
    .{
      FRONT_HANDLE.idx, FRONT_HANDLE.gen,
      BACK_HANDLE.idx,  BACK_HANDLE.gen,
      panelName( ng.uiManager.getPanelAtDrawIndex( 1 )),
      panelName( ng.uiManager.getPanelAtDrawIndex( 0 )),
      ng.uiManager.getPanelCount(),
    }
  );
}

fn widgetNameInPanel( panel : *const utl.Panel, widget : utl.UiHandle ) []const u8
{
  if( !widget.isValid() ){ return "none"; }
  return if( panel.getWidgetKind( widget ))| kind | @tagName( kind ) else "stale";
}

fn panelName( handle : eng.UiPanelHandle ) []const u8
{
  if( handle.isEq( FRONT_HANDLE )){ return "front"; }
  if( handle.isEq( BACK_HANDLE  )){ return "back";  }
  return "none";
}

fn widgetName( ng : *eng.Engine, panelHandle : eng.UiPanelHandle, widget : utl.UiHandle ) []const u8
{
  if( !widget.isValid() ){ return "none"; }

  const reg   = ng.uiManager.getRegistration( panelHandle ) orelse return "stale";
  const panel = reg.panel orelse return "null";
  return if( panel.getWidgetKind( widget ))| kind | @tagName( kind ) else "stale";
}

fn activeModeName() []const u8
{
  return if( ACTIVE_UI_USES_ENGINE_MANAGER ) "engine" else "utility";
}

fn drawFinalBoxMarker( panel : *utl.Panel, handles : *const PrimaryUiHandles ) void
{
  if( panel.getWidgetFinalBox( handles.moveButton ))| box |
  {
    utl.sDraw.basicCirclePerim( box.center, 5.0, utl.Colour.pGold );
    utl.sDraw.basicLine( box.center.add( .new( -10.0, 0.0 )), box.center.add( .new( 10.0, 0.0 )), utl.Colour.pGold, 1.0 );
    utl.sDraw.basicLine( box.center.add( .new( 0.0, -10.0 )), box.center.add( .new( 0.0, 10.0 )), utl.Colour.pGold, 1.0 );
  }
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

  ACTIVE_WANTS_MOUSE =
    if( ACTIVE_UI_USES_ENGINE_MANAGER ) updateEngineMode( ng )
    else updateUtilityMode( ng );

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
}

pub fn OnRenderOverlay( ng : *eng.Engine ) void
{
  if( ng.isPaused() )
  {
    utl.sDraw.coverScreenWithCol( utl.Colour.new( 0, 0, 0, 128 ));
  }

  if( ACTIVE_UI_USES_ENGINE_MANAGER )
  {
    ng.uiManager.drawAll();
    if( FRONT_PANEL )| *panel |{ drawFinalBoxMarker( panel, &ENGINE_UI ); }
  }
  else
  {
    if( MAIN_PANEL )| *panel |
    {
      panel.draw();
      drawFinalBoxMarker( panel, &UTILITY_UI );
    }
  }

  if( DEBUG_PANEL_VISIBLE )
  {
    if( DEBUG_PANEL )| *panel |{ panel.draw(); }
  }
}
