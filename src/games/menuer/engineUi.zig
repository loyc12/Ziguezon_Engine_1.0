const eng    = @import( "engine" );
const utl    = @import( "utils" );
const common = @import( "uiCommon.zig" );


// ================================ ENGINE UI STATE ================================

const ControlHandles = struct
{
  title            : utl.UiHandle = .{},
  orderReadout     : utl.UiHandle = .{},
  flagReadout      : utl.UiHandle = .{},
  staleReadout     : utl.UiHandle = .{},
  routeReadout     : utl.UiHandle = .{},
  eventReadout     : utl.UiHandle = .{},
  flagRow          : utl.UiHandle = .{},
  visibleButton    : utl.UiHandle = .{},
  inputButton      : utl.UiHandle = .{},
  drawButton       : utl.UiHandle = .{},
  lifecycleRow     : utl.UiHandle = .{},
  registerButton   : utl.UiHandle = .{},
  unregisterButton : utl.UiHandle = .{},
  reregisterButton : utl.UiHandle = .{},
  clearButton      : utl.UiHandle = .{},
};

const EngineStats = struct
{
  frontVisible       : bool  = true,
  frontInputEnabled  : bool  = true,
  frontDrawEnabled   : bool  = true,
  backClicks         : u32   = 0,
  managerEventsTotal : u32   = 0,
  queuedBeforeDrain  : usize = 0,
  drainedThisFrame   : usize = 0,
  clearCount         : u32   = 0,
  lastSummary        : []const u8 = "none",
};

var FRONT_PANEL   : ?utl.Panel = null;
var BACK_PANEL    : ?utl.Panel = null;
var CONTROL_PANEL : ?utl.Panel = null;

var PRIMARY_HANDLES : common.PrimaryUiHandles = .{};
var PRIMARY_STATE   : common.PrimaryUiState   = .{};
var CONTROLS        : ControlHandles          = .{};
var STATS           : EngineStats             = .{};

var BACK_LABEL  : utl.UiHandle = .{};
var BACK_DEBUG  : utl.UiHandle = .{};
var BACK_BUTTON : utl.UiHandle = .{};

var FRONT_HANDLE   : eng.UiPanelHandle = .{};
var BACK_HANDLE    : eng.UiPanelHandle = .{};
var CONTROL_HANDLE : eng.UiPanelHandle = .{};

var LAST_STALE_FRONT : eng.UiPanelHandle = .{};
var LAST_FRESH_FRONT : eng.UiPanelHandle = .{};
var LAST_CLEAR_FRONT : eng.UiPanelHandle = .{};
var LAST_CLEAR_BACK  : eng.UiPanelHandle = .{};


// ================================ LIFETIME ================================

/// Builds game-owned engine panels and registers the manager-routed harness.
pub fn build( ng : *eng.Engine ) void
{
  close( ng );

  PRIMARY_STATE = .{};
  STATS         = .{};

  buildPrimaryPanel();
  buildBackPanel();
  buildControlPanel();

  registerFrontPanel( ng );
  registerBackPanel( ng );
  registerControlPanel( ng );
}

/// Unregisters manager handles before releasing the game-owned panel storage.
pub fn close( ng : ?*eng.Engine ) void
{
  if( ng )| engine |
  {
    if( CONTROL_HANDLE.isValid() ){ _ = engine.uiManager.unregisterPanel( CONTROL_HANDLE ); }
    if( BACK_HANDLE.isValid()    ){ _ = engine.uiManager.unregisterPanel( BACK_HANDLE    ); }
    if( FRONT_HANDLE.isValid()   ){ _ = engine.uiManager.unregisterPanel( FRONT_HANDLE   ); }
  }

  if( FRONT_PANEL   )| *panel |{ panel.deinit(); }
  if( BACK_PANEL    )| *panel |{ panel.deinit(); }
  if( CONTROL_PANEL )| *panel |{ panel.deinit(); }

  FRONT_PANEL   = null;
  BACK_PANEL    = null;
  CONTROL_PANEL = null;

  PRIMARY_HANDLES = .{};
  PRIMARY_STATE   = .{};
  CONTROLS        = .{};
  STATS           = .{};

  BACK_LABEL  = .{};
  BACK_DEBUG  = .{};
  BACK_BUTTON = .{};

  FRONT_HANDLE   = .{};
  BACK_HANDLE    = .{};
  CONTROL_HANDLE = .{};

  LAST_STALE_FRONT = .{};
  LAST_FRESH_FRONT = .{};
  LAST_CLEAR_FRONT = .{};
  LAST_CLEAR_BACK  = .{};
}

fn buildPrimaryPanel() void
{
  FRONT_PANEL = utl.Panel.init(
    utl.getDefaultAlloc(),
    .{
      .key    = utl.uiKey( "menuer.engine.primary" ),
      .box    = common.primaryPanelBox(),
      .config = common.primaryPanelConfig( utl.Colour.pGold ),
    }
  ) catch | err |
  {
    utl.log( .ERROR, @src(), "Failed to create menuer engine primary panel : {}", .{ err });
    return;
  };

  const panel = &( FRONT_PANEL.? );
  common.addPrimaryControls(
    panel,
    &PRIMARY_HANDLES,
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
}

fn buildBackPanel() void
{
  BACK_PANEL = utl.Panel.init(
    utl.getDefaultAlloc(),
    .{
      .key    = utl.uiKey( "menuer.engine.back" ),
      .box    = common.engineBackPanelBox(),
      .config = common.managerPanelConfig( utl.Colour.dGray.setA( 225 )),
    }
  ) catch | err |
  {
    utl.log( .ERROR, @src(), "Failed to create menuer engine back panel : {}", .{ err });
    return;
  };

  var panel = &( BACK_PANEL.? );

  BACK_LABEL = panel.addLabel(
    .{
      .key    = utl.uiKey( "menuer.engine.back.label" ),
      .text   = "Engine back panel",
      .config = common.labelConfig( 28.0 ),
    }
  ) catch .{};

  BACK_DEBUG = panel.addLabel(
    .{
      .key    = utl.uiKey( "menuer.engine.back.debug" ),
      .text   = "manager route pending",
      .config = common.labelConfig( 54.0 ),
    }
  ) catch .{};

  BACK_BUTTON = panel.addButton(
    .{
      .key    = utl.uiKey( "menuer.engine.back.button" ),
      .text   = "Back routed click",
      .config = common.buttonConfig(),
    }
  ) catch .{};

  panel.updateLayout();
}

fn buildControlPanel() void
{
  CONTROL_PANEL = utl.Panel.init(
    utl.getDefaultAlloc(),
      .{
        .key    = utl.uiKey( "menuer.engine.controls" ),
        .box    = common.engineControlPanelBox(),
        .config = controlPanelConfig(),
      }
  ) catch | err |
  {
    utl.log( .ERROR, @src(), "Failed to create menuer engine control panel : {}", .{ err });
    return;
  };

  var panel = &( CONTROL_PANEL.? );

  CONTROLS.title = panel.addLabel(
    .{
      .key    = utl.uiKey( "menuer.engine.controls.title" ),
      .text   = "Engine manager harness",
      .config = common.labelConfig( 20.0 ),
    }
  ) catch .{};

  CONTROLS.orderReadout = panel.addLabel(
    .{
      .key    = utl.uiKey( "menuer.engine.controls.order" ),
      .text   = "order pending",
      .config = common.labelConfig( 34.0 ),
    }
  ) catch .{};

  CONTROLS.flagReadout = panel.addLabel(
    .{
      .key    = utl.uiKey( "menuer.engine.controls.flags" ),
      .text   = "flags pending",
      .config = common.labelConfig( 24.0 ),
    }
  ) catch .{};

  CONTROLS.staleReadout = panel.addLabel(
    .{
      .key    = utl.uiKey( "menuer.engine.controls.stale" ),
      .text   = "stale pending",
      .config = common.labelConfig( 42.0 ),
    }
  ) catch .{};

  CONTROLS.routeReadout = panel.addLabel(
    .{
      .key    = utl.uiKey( "menuer.engine.controls.route" ),
      .text   = "route pending",
      .config = common.labelConfig( 28.0 ),
    }
  ) catch .{};

  CONTROLS.eventReadout = panel.addLabel(
    .{
      .key    = utl.uiKey( "menuer.engine.controls.events" ),
      .text   = "events pending",
      .config = common.labelConfig( 24.0 ),
    }
  ) catch .{};

  CONTROLS.flagRow = panel.addContainer(
    .{
      .key    = utl.uiKey( "menuer.engine.controls.flag_row" ),
      .config = common.containerConfig( .row, 30.0 ),
    }
  ) catch .{};

  CONTROLS.visibleButton = panel.addButton(
    .{
      .key    = utl.uiKey( "menuer.engine.controls.visible" ),
      .parent = CONTROLS.flagRow,
      .text   = "Front V",
      .config = smallButtonConfig(),
    }
  ) catch .{};

  CONTROLS.inputButton = panel.addButton(
    .{
      .key    = utl.uiKey( "menuer.engine.controls.input" ),
      .parent = CONTROLS.flagRow,
      .text   = "Front I",
      .config = smallButtonConfig(),
    }
  ) catch .{};

  CONTROLS.drawButton = panel.addButton(
    .{
      .key    = utl.uiKey( "menuer.engine.controls.draw" ),
      .parent = CONTROLS.flagRow,
      .text   = "Front D",
      .config = smallButtonConfig(),
    }
  ) catch .{};

  CONTROLS.lifecycleRow = panel.addContainer(
    .{
      .key    = utl.uiKey( "menuer.engine.controls.lifecycle_row" ),
      .config = common.containerConfig( .row, 30.0 ),
    }
  ) catch .{};

  CONTROLS.registerButton = panel.addButton(
    .{
      .key    = utl.uiKey( "menuer.engine.controls.register" ),
      .parent = CONTROLS.lifecycleRow,
      .text   = "Reg",
      .config = tinyButtonConfig(),
    }
  ) catch .{};

  CONTROLS.unregisterButton = panel.addButton(
    .{
      .key    = utl.uiKey( "menuer.engine.controls.unregister" ),
      .parent = CONTROLS.lifecycleRow,
      .text   = "Unreg",
      .config = tinyButtonConfig(),
    }
  ) catch .{};

  CONTROLS.reregisterButton = panel.addButton(
    .{
      .key    = utl.uiKey( "menuer.engine.controls.reregister" ),
      .parent = CONTROLS.lifecycleRow,
      .text   = "Re-reg",
      .config = tinyButtonConfig(),
    }
  ) catch .{};

  CONTROLS.clearButton = panel.addButton(
    .{
      .key    = utl.uiKey( "menuer.engine.controls.clear" ),
      .parent = CONTROLS.lifecycleRow,
      .text   = "Clear",
      .config = tinyButtonConfig(),
    }
  ) catch .{};

  panel.updateLayout();
}

fn smallButtonConfig() utl.WidgetConfig
{
  return .{
    .desiredSize = .new( 136.0, 28.0 ),
    .textAlign   = .center,
  };
}

fn tinyButtonConfig() utl.WidgetConfig
{
  return .{
    .desiredSize = .new( 98.0, 28.0 ),
    .textAlign   = .center,
  };
}

fn controlPanelConfig() utl.PanelConfig
{
  var style = utl.UiStyle{};
  style.fillCol = utl.Colour.nBlack.setA( 222 );
  style.edgeCol = utl.Colour.pGold;

  return .{
    .layout  = .column,
    .padding = 8.0,
    .gap     = 4.0,
    .style   = style,
  };
}


// ================================ REGISTRATION HELPERS ================================

fn registerFrontPanel( ng : *eng.Engine ) void
{
  if( FRONT_HANDLE.isValid() ){ return; }

  if( FRONT_PANEL )| *panel |
  {
    FRONT_HANDLE = ng.uiManager.registerPanel(
      panel,
      .{
        .key            = utl.uiKey( "menuer.engine.primary" ),
        .layer          = 5,
        .z              = 1,
        .isVisible      = STATS.frontVisible,
        .isInputEnabled = STATS.frontInputEnabled,
        .isDrawEnabled  = STATS.frontDrawEnabled,
      }
    ) catch | err |
    {
      utl.log( .ERROR, @src(), "Failed to register menuer engine primary panel : {}", .{ err });
      return;
    };

    LAST_FRESH_FRONT = FRONT_HANDLE;
  }
}

fn registerBackPanel( ng : *eng.Engine ) void
{
  if( BACK_HANDLE.isValid() ){ return; }

  if( BACK_PANEL )| *panel |
  {
    BACK_HANDLE = ng.uiManager.registerPanel( panel, .{ .key = utl.uiKey( "menuer.engine.back" ), .layer = 5, .z = 0 } ) catch | err |
    {
      utl.log( .ERROR, @src(), "Failed to register menuer engine back panel : {}", .{ err });
      return;
    };
  }
}

fn registerControlPanel( ng : *eng.Engine ) void
{
  if( CONTROL_HANDLE.isValid() ){ return; }

  if( CONTROL_PANEL )| *panel |
  {
    CONTROL_HANDLE = ng.uiManager.registerPanel( panel, .{ .key = utl.uiKey( "menuer.engine.controls" ), .layer = 8, .z = 0 } ) catch | err |
    {
      utl.log( .ERROR, @src(), "Failed to register menuer engine controls panel : {}", .{ err });
      return;
    };
  }
}

fn unregisterFrontPanel( ng : *eng.Engine ) void
{
  if( !FRONT_HANDLE.isValid() ){ return; }

  LAST_STALE_FRONT = FRONT_HANDLE;
  _ = ng.uiManager.unregisterPanel( FRONT_HANDLE );
  FRONT_HANDLE = .{};

  if( FRONT_PANEL )| *panel |{ panel.clearEvents(); }
}

fn reregisterFrontPanel( ng : *eng.Engine ) void
{
  unregisterFrontPanel( ng );
  registerFrontPanel( ng );
}

fn clearAndRestoreHarness( ng : *eng.Engine ) void
{
  LAST_CLEAR_FRONT = FRONT_HANDLE;
  LAST_CLEAR_BACK  = BACK_HANDLE;

  ng.uiManager.clear();

  FRONT_HANDLE   = .{};
  BACK_HANDLE    = .{};
  CONTROL_HANDLE = .{};
  STATS.clearCount += 1;

  if( FRONT_PANEL   )| *panel |{ panel.clearEvents(); }
  if( BACK_PANEL    )| *panel |{ panel.clearEvents(); }
  if( CONTROL_PANEL )| *panel |{ panel.clearEvents(); }

  // The control and back panels are restored immediately so the clear action
  // remains observable and recoverable from inside the sandbox.
  registerBackPanel( ng );
  registerControlPanel( ng );
}


// ================================ MODE AND DEBUG FLAGS ================================

pub fn applyDebugBounds( enabled : bool ) void
{
  if( FRONT_PANEL   )| *panel |{ panel.setDebugDrawBounds( enabled ); }
  if( BACK_PANEL    )| *panel |{ panel.setDebugDrawBounds( enabled ); }
  if( CONTROL_PANEL )| *panel |{ panel.setDebugDrawBounds( enabled ); }
}

pub fn clearEvents( ng : *eng.Engine ) void
{
  if( FRONT_PANEL   )| *panel |{ panel.clearEvents(); }
  if( BACK_PANEL    )| *panel |{ panel.clearEvents(); }
  if( CONTROL_PANEL )| *panel |{ panel.clearEvents(); }
  ng.uiManager.clearEvents();
}

pub fn applyActiveMode( ng : *eng.Engine, isActive : bool ) void
{
  if( isActive )
  {
    applyFrontFlags( ng );
    ng.uiManager.setPanelVisible(      BACK_HANDLE,    true );
    ng.uiManager.setPanelInputEnabled( BACK_HANDLE,    true );
    ng.uiManager.setPanelDrawEnabled(  BACK_HANDLE,    true );
    ng.uiManager.setPanelVisible(      CONTROL_HANDLE, true );
    ng.uiManager.setPanelInputEnabled( CONTROL_HANDLE, true );
    ng.uiManager.setPanelDrawEnabled(  CONTROL_HANDLE, true );
  }
  else
  {
    ng.uiManager.setPanelVisible(      FRONT_HANDLE,   false );
    ng.uiManager.setPanelInputEnabled( FRONT_HANDLE,   false );
    ng.uiManager.setPanelDrawEnabled(  FRONT_HANDLE,   false );
    ng.uiManager.setPanelVisible(      BACK_HANDLE,    false );
    ng.uiManager.setPanelInputEnabled( BACK_HANDLE,    false );
    ng.uiManager.setPanelDrawEnabled(  BACK_HANDLE,    false );
    ng.uiManager.setPanelVisible(      CONTROL_HANDLE, false );
    ng.uiManager.setPanelInputEnabled( CONTROL_HANDLE, false );
    ng.uiManager.setPanelDrawEnabled(  CONTROL_HANDLE, false );
  }
}

fn applyFrontFlags( ng : *eng.Engine ) void
{
  ng.uiManager.setPanelVisible(      FRONT_HANDLE, STATS.frontVisible      );
  ng.uiManager.setPanelInputEnabled( FRONT_HANDLE, STATS.frontInputEnabled );
  ng.uiManager.setPanelDrawEnabled(  FRONT_HANDLE, STATS.frontDrawEnabled  );
}


// ================================ UPDATE AND EVENTS ================================

/// Updates manager-routed panels and returns manager mouse consumption.
pub fn update( ng : *eng.Engine ) bool
{
  ng.uiManager.updateInput( ng.mouse );

  STATS.queuedBeforeDrain = ng.uiManager.getEventCount();
  STATS.drainedThisFrame  = 0;
  drainManagerEvents( ng );

  updateBackPanelReadout( ng );
  updateControlPanelReadouts( ng );

  if( FRONT_PANEL )| *panel |{ common.updatePrimaryDebugLabel( panel, &PRIMARY_HANDLES, &PRIMARY_STATE, "engine" ); }

  return ng.uiManager.wantsMouse();
}

fn drainManagerEvents( ng : *eng.Engine ) void
{
  while( ng.uiManager.popEvent() )| managerEvent |
  {
    STATS.drainedThisFrame  += 1;
    STATS.managerEventsTotal += 1;

    if( managerEvent.panel.isEq( FRONT_HANDLE ))
    {
      if( FRONT_PANEL )| *panel |
      {
        common.handlePrimaryEvent( panel, &PRIMARY_HANDLES, &PRIMARY_STATE, managerEvent.event, "Engine" );
        STATS.lastSummary = eventKindName( managerEvent.event );
      }
    }
    else if( managerEvent.panel.isEq( BACK_HANDLE ))
    {
      handleBackEvent( managerEvent.event );
    }
    else if( managerEvent.panel.isEq( CONTROL_HANDLE ))
    {
      handleControlEvent( ng, managerEvent.event );
    }
  }
}

fn handleBackEvent( event : utl.UiEvent ) void
{
  if( BACK_PANEL )| *panel |
  {
    if( event.isClicked( BACK_BUTTON ))
    {
      STATS.backClicks += 1;
      STATS.lastSummary = "back clicked";
      panel.setTextFmt( BACK_BUTTON, "Back routed ({d})", .{ STATS.backClicks });
    }
  }
}

fn handleControlEvent( ng : *eng.Engine, event : utl.UiEvent ) void
{
  if( event.isClicked( CONTROLS.visibleButton ))
  {
    STATS.frontVisible = !STATS.frontVisible;
    applyFrontFlags( ng );
    STATS.lastSummary = "front visible";
  }
  else if( event.isClicked( CONTROLS.inputButton ))
  {
    STATS.frontInputEnabled = !STATS.frontInputEnabled;
    applyFrontFlags( ng );
    STATS.lastSummary = "front input";
  }
  else if( event.isClicked( CONTROLS.drawButton ))
  {
    STATS.frontDrawEnabled = !STATS.frontDrawEnabled;
    applyFrontFlags( ng );
    STATS.lastSummary = "front draw";
  }
  else if( event.isClicked( CONTROLS.registerButton ))
  {
    registerFrontPanel( ng );
    applyFrontFlags( ng );
    STATS.lastSummary = "front register";
  }
  else if( event.isClicked( CONTROLS.unregisterButton ))
  {
    unregisterFrontPanel( ng );
    STATS.lastSummary = "front unregister";
  }
  else if( event.isClicked( CONTROLS.reregisterButton ))
  {
    reregisterFrontPanel( ng );
    applyFrontFlags( ng );
    STATS.lastSummary = "front re-register";
  }
  else if( event.isClicked( CONTROLS.clearButton ))
  {
    clearAndRestoreHarness( ng );
    STATS.lastSummary = "manager clear";
  }
}

fn eventKindName( event : utl.UiEvent ) []const u8
{
  return switch( event.eType )
  {
    .clicked => "front clicked",
    .changed => "front changed",
  };
}


// ================================ READOUTS ================================

fn updateBackPanelReadout( ng : *eng.Engine ) void
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
        .{ reg.isVisible, reg.isInputEnabled, reg.isDrawEnabled, panel.getEventCount(), STATS.backClicks }
      );
    }
    else
    {
      panel.setText( BACK_LABEL, "back handle stale" );
      panel.setText( BACK_DEBUG, "register restored by clear control" );
    }
  }
}

fn updateControlPanelReadouts( ng : *eng.Engine ) void
{
  if( CONTROL_PANEL )| *panel |
  {
    panel.setPanelBox( common.engineControlPanelBox() );
    updateControlButtonText( panel );

    panel.setTextFmt(
      CONTROLS.orderReadout,
      "F {s} l:{d} z:{d} o:{d} | B {s} l:{d} z:{d} o:{d}\nC {s} l:{d} z:{d} o:{d} | draw 0:{s} 1:{s} 2:{s}",
      .{
        registrationState( ng, FRONT_HANDLE ),   registrationLayer( ng, FRONT_HANDLE ),   registrationZ( ng, FRONT_HANDLE ),   registrationOrder( ng, FRONT_HANDLE ),
        registrationState( ng, BACK_HANDLE ),    registrationLayer( ng, BACK_HANDLE ),    registrationZ( ng, BACK_HANDLE ),    registrationOrder( ng, BACK_HANDLE ),
        registrationState( ng, CONTROL_HANDLE ), registrationLayer( ng, CONTROL_HANDLE ), registrationZ( ng, CONTROL_HANDLE ), registrationOrder( ng, CONTROL_HANDLE ),
        panelName( ng.uiManager.getPanelAtDrawIndex( 0 )),
        panelName( ng.uiManager.getPanelAtDrawIndex( 1 )),
        panelName( ng.uiManager.getPanelAtDrawIndex( 2 )),
      }
    );

    panel.setTextFmt(
      CONTROLS.flagReadout,
      "front desired V:{} I:{} D:{} | live:{}",
      .{ STATS.frontVisible, STATS.frontInputEnabled, STATS.frontDrawEnabled, ng.uiManager.getRegistration( FRONT_HANDLE ) != null }
    );

    panel.setTextFmt(
      CONTROLS.staleReadout,
      "stale {s} {d}:{d} | fresh {s} {d}:{d} | reuse:{}\nclear F:{s} B:{s}",
      .{
        handleReadout( LAST_STALE_FRONT ),
        handleIdx( LAST_STALE_FRONT ),
        handleGen( LAST_STALE_FRONT ),
        handleReadout( LAST_FRESH_FRONT ),
        handleIdx( LAST_FRESH_FRONT ),
        handleGen( LAST_FRESH_FRONT ),
        isSlotReuse(),
        staleState( ng, LAST_CLEAR_FRONT ),
        staleState( ng, LAST_CLEAR_BACK ),
      }
    );

    panel.setTextFmt(
      CONTROLS.routeReadout,
      "input hover:{s} widget:{s} | Lcap:{s}",
      .{
        panelName( ng.uiManager.getHoveredPanel() ),
        widgetName( ng, ng.uiManager.getHoveredPanel(), ng.uiManager.getHoveredWidget() ),
        panelName( ng.uiManager.getCapturedPanel( .left )),
      }
    );

    panel.setTextFmt(
      CONTROLS.eventReadout,
      "queue before:{d} drained:{d} total:{d} last:{s}",
      .{ STATS.queuedBeforeDrain, STATS.drainedThisFrame, STATS.managerEventsTotal, STATS.lastSummary }
    );

    panel.updateLayout();
  }
}

fn updateControlButtonText( panel : *utl.Panel ) void
{
  panel.setTextFmt( CONTROLS.visibleButton,    "Front V:{}", .{ STATS.frontVisible      } );
  panel.setTextFmt( CONTROLS.inputButton,      "Front I:{}", .{ STATS.frontInputEnabled } );
  panel.setTextFmt( CONTROLS.drawButton,       "Front D:{}", .{ STATS.frontDrawEnabled  } );
  panel.setText(    CONTROLS.registerButton,   "Reg" );
  panel.setText(    CONTROLS.unregisterButton, "Unreg" );
  panel.setText(    CONTROLS.reregisterButton, "Re-reg" );
  panel.setTextFmt( CONTROLS.clearButton,      "Clear {d}", .{ STATS.clearCount } );
}

fn registrationState( ng : *eng.Engine, handle : eng.UiPanelHandle ) []const u8
{
  return if( ng.uiManager.getRegistration( handle ) == null ) "stale" else "live";
}

fn registrationLayer( ng : *eng.Engine, handle : eng.UiPanelHandle ) i32
{
  const reg = ng.uiManager.getRegistration( handle ) orelse return 0;
  return reg.layer;
}

fn registrationZ( ng : *eng.Engine, handle : eng.UiPanelHandle ) i32
{
  const reg = ng.uiManager.getRegistration( handle ) orelse return 0;
  return reg.z;
}

fn registrationOrder( ng : *eng.Engine, handle : eng.UiPanelHandle ) u64
{
  const reg = ng.uiManager.getRegistration( handle ) orelse return 0;
  return reg.order;
}

fn staleState( ng : *eng.Engine, handle : eng.UiPanelHandle ) []const u8
{
  if( !handle.isValid() ){ return "none"; }
  return if( ng.uiManager.getRegistration( handle ) == null ) "stale" else "live";
}

fn isSlotReuse() bool
{
  return LAST_STALE_FRONT.isValid()
    and LAST_FRESH_FRONT.isValid()
    and LAST_STALE_FRONT.idx == LAST_FRESH_FRONT.idx
    and LAST_STALE_FRONT.gen != LAST_FRESH_FRONT.gen;
}

fn handleReadout( handle : eng.UiPanelHandle ) []const u8
{
  if( !handle.isValid() ){ return "none"; }
  if( handle.isEq( FRONT_HANDLE   )){ return "front"; }
  if( handle.isEq( BACK_HANDLE    )){ return "back";  }
  if( handle.isEq( CONTROL_HANDLE )){ return "ctrl";  }
  return "old";
}

fn handleIdx( handle : eng.UiPanelHandle ) u32
{
  return if( handle.isValid() ) handle.idx else 0;
}

fn handleGen( handle : eng.UiPanelHandle ) u32
{
  return if( handle.isValid() ) handle.gen else 0;
}


// ================================ DEBUG PANEL BRIDGE ================================

pub fn writeDebugUi( ng : *eng.Engine, panel : *utl.Panel, stateLabel : utl.UiHandle, hoverLabel : utl.UiHandle, captureLabel : utl.UiHandle, queueLabel : utl.UiHandle ) void
{
  const hoveredPanel   = ng.uiManager.getHoveredPanel();
  const hoveredWidget  = ng.uiManager.getHoveredWidget();
  const capturedLeft   = ng.uiManager.getCapturedPanel( .left   );
  const capturedRight  = ng.uiManager.getCapturedPanel( .right  );
  const capturedMiddle = ng.uiManager.getCapturedPanel( .middle );

  panel.setTextFmt(
    stateLabel,
    "engine events:{d} pending:{d} wants:{}",
    .{ PRIMARY_STATE.eventCount, ng.uiManager.getEventCount(), ng.uiManager.wantsMouse() }
  );
  panel.setTextFmt(
    hoverLabel,
    "hover panel:{s} widget:{s}",
    .{ panelName( hoveredPanel ), widgetName( ng, hoveredPanel, hoveredWidget ) }
  );
  panel.setTextFmt(
    captureLabel,
    "capture L:{s}/{s} R:{s}/{s} M:{s}/{s}",
    .{
      panelName( capturedLeft   ), widgetName( ng, capturedLeft,   ng.uiManager.getCapturedWidget( .left   )),
      panelName( capturedRight  ), widgetName( ng, capturedRight,  ng.uiManager.getCapturedWidget( .right  )),
      panelName( capturedMiddle ), widgetName( ng, capturedMiddle, ng.uiManager.getCapturedWidget( .middle )),
    }
  );
  panel.setTextFmt(
    queueLabel,
    "q before:{d} drained:{d} last:{s}\ndraw {s}>{s}>{s} panels:{d}",
    .{
      STATS.queuedBeforeDrain,
      STATS.drainedThisFrame,
      STATS.lastSummary,
      panelName( ng.uiManager.getPanelAtDrawIndex( 2 )),
      panelName( ng.uiManager.getPanelAtDrawIndex( 1 )),
      panelName( ng.uiManager.getPanelAtDrawIndex( 0 )),
      ng.uiManager.getPanelCount(),
    }
  );
}

fn panelName( handle : eng.UiPanelHandle ) []const u8
{
  if( handle.isEq( FRONT_HANDLE   )){ return "front"; }
  if( handle.isEq( BACK_HANDLE    )){ return "back";  }
  if( handle.isEq( CONTROL_HANDLE )){ return "ctrl";  }
  return "none";
}

fn widgetName( ng : *eng.Engine, panelHandle : eng.UiPanelHandle, widget : utl.UiHandle ) []const u8
{
  if( !widget.isValid() ){ return "none"; }

  const reg   = ng.uiManager.getRegistration( panelHandle ) orelse return "stale";
  const panel = reg.panel orelse return "null";
  return if( panel.getWidgetKind( widget ))| kind | @tagName( kind ) else "stale";
}


// ================================ DRAWING ================================

pub fn draw( ng : *eng.Engine ) void
{
  ng.uiManager.drawAll();

  if( FRONT_PANEL )| *panel |
  {
    common.drawFinalBoxMarker( panel, &PRIMARY_HANDLES );
  }
}
