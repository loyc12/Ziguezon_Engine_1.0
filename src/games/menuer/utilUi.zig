const eng    = @import( "engine" );
const utl    = @import( "utils" );
const common = @import( "uiCommon.zig" );


// ================================ UTILITY UI STATE ================================

/// Handles for the utility-only control panel that exercises direct primitive
/// behavior outside the engine UI manager.
const ControlHandles = struct
{
  title             : utl.UiHandle = .{},
  lifecycleReadout  : utl.UiHandle = .{},
  queueReadout      : utl.UiHandle = .{},
  hitReadout        : utl.UiHandle = .{},
  handleReadout     : utl.UiHandle = .{},
  lifecycleRow      : utl.UiHandle = .{},
  rebuildButton     : utl.UiHandle = .{},
  removeButton      : utl.UiHandle = .{},
  eventRow          : utl.UiHandle = .{},
  holdEventsCheck   : utl.UiHandle = .{},
  clearEventsButton : utl.UiHandle = .{},
  mutateButton      : utl.UiHandle = .{},
};

/// Utility harness counters and stale-handle samples shown in the control and
/// debug readouts.
const UtilityStats = struct
{
  rebuildCount        : u32          = 0,
  removeCount         : u32          = 0,
  restoreCount        : u32          = 0,
  clearEventCount     : u32          = 0,
  mutateStep          : u32          = 0,
  queuedBeforeDrain   : usize        = 0,
  drainedThisFrame    : usize        = 0,
  controlQueueDrained : usize        = 0,
  holdMainEvents      : bool         = false,
  lastClearedCount    : utl.UiHandle = .{},
  lastRemovedAbs      : utl.UiHandle = .{},
  lastRestoredAbs     : utl.UiHandle = .{},
  lastSummary         : []const u8   = "none",
};

var MAIN_PANEL    : ?utl.Panel = null;
var CONTROL_PANEL : ?utl.Panel = null;

var HANDLES  : common.PrimaryUiHandles = .{};
var STATE    : common.PrimaryUiState   = .{};
var CONTROLS : ControlHandles          = .{};
var STATS    : UtilityStats            = .{};


// ================================ LIFETIME ================================

/// Builds the direct utility panels used as the primitive-side comparison path.
pub fn build() void
{
  close();

  STATE = .{};
  STATS = .{};

  buildPrimaryPanel();
  buildControlPanel();
}

fn buildPrimaryPanel() void
{
  MAIN_PANEL = utl.Panel.init(
    utl.getDefaultAlloc(),
    .{
      .key    = utl.uiKey( "menuer.utility.primary" ),
      .box    = common.primaryPanelBox(),
      .config = common.primaryPanelConfig( utl.Colour.pTeal ),
    }
  ) catch | err |
  {
    utl.log( .ERROR, @src(), "Failed to create menuer utility panel : {}", .{ err });
    return;
  };

  populatePrimaryPanel( &( MAIN_PANEL.? ));
}

fn populatePrimaryPanel( panel : *utl.Panel ) void
{
  HANDLES = .{};
  STATE   = .{};

  common.addPrimaryControls(
    panel,
    &HANDLES,
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

fn buildControlPanel() void
{
  CONTROL_PANEL = utl.Panel.init(
    utl.getDefaultAlloc(),
    .{
      .key    = utl.uiKey( "menuer.utility.controls" ),
      .box    = common.utilityControlPanelBox(),
      .config = controlPanelConfig(),
    }
  ) catch | err |
  {
    utl.log( .ERROR, @src(), "Failed to create menuer utility controls panel : {}", .{ err });
    return;
  };

  var panel = &( CONTROL_PANEL.? );

  CONTROLS.title = panel.addLabel(
    .{
      .key    = utl.uiKey( "menuer.utility.controls.title" ),
      .text   = "Utility primitive harness",
      .config = common.labelConfig( 20.0 ),
    }
  ) catch .{};

  CONTROLS.lifecycleReadout = panel.addLabel(
    .{
      .key    = utl.uiKey( "menuer.utility.controls.lifecycle" ),
      .text   = "lifecycle pending",
      .config = common.labelConfig( 34.0 ),
    }
  ) catch .{};

  CONTROLS.queueReadout = panel.addLabel(
    .{
      .key    = utl.uiKey( "menuer.utility.controls.queue" ),
      .text   = "queue pending",
      .config = common.labelConfig( 34.0 ),
    }
  ) catch .{};

  CONTROLS.hitReadout = panel.addLabel(
    .{
      .key    = utl.uiKey( "menuer.utility.controls.hit" ),
      .text   = "hit pending",
      .config = common.labelConfig( 34.0 ),
    }
  ) catch .{};

  CONTROLS.handleReadout = panel.addLabel(
    .{
      .key    = utl.uiKey( "menuer.utility.controls.handles" ),
      .text   = "handles pending",
      .config = common.labelConfig( 42.0 ),
    }
  ) catch .{};

  CONTROLS.lifecycleRow = panel.addContainer(
    .{
      .key    = utl.uiKey( "menuer.utility.controls.lifecycle_row" ),
      .config = common.containerConfig( .row, 30.0 ),
    }
  ) catch .{};

  CONTROLS.rebuildButton = panel.addButton(
    .{
      .key    = utl.uiKey( "menuer.utility.controls.rebuild" ),
      .parent = CONTROLS.lifecycleRow,
      .text   = "Rebuild",
      .config = smallButtonConfig(),
    }
  ) catch .{};

  CONTROLS.removeButton = panel.addButton(
    .{
      .key    = utl.uiKey( "menuer.utility.controls.remove" ),
      .parent = CONTROLS.lifecycleRow,
      .text   = "Remove abs",
      .config = smallButtonConfig(),
    }
  ) catch .{};

  CONTROLS.eventRow = panel.addContainer(
    .{
      .key    = utl.uiKey( "menuer.utility.controls.event_row" ),
      .config = common.containerConfig( .row, 30.0 ),
    }
  ) catch .{};

  CONTROLS.holdEventsCheck = panel.addCheckbox(
    .{
      .key    = utl.uiKey( "menuer.utility.controls.hold" ),
      .parent = CONTROLS.eventRow,
      .text   = "Hold events",
      .config = smallCheckConfig(),
    }
  ) catch .{};

  CONTROLS.clearEventsButton = panel.addButton(
    .{
      .key    = utl.uiKey( "menuer.utility.controls.clear_events" ),
      .parent = CONTROLS.eventRow,
      .text   = "Clear events",
      .config = smallButtonConfig(),
    }
  ) catch .{};

  CONTROLS.mutateButton = panel.addButton(
    .{
      .key    = utl.uiKey( "menuer.utility.controls.mutate" ),
      .text   = "Mutate handles",
      .config = common.buttonConfig(),
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

fn smallCheckConfig() utl.WidgetConfig
{
  return .{
    .desiredSize = .new( 150.0, 28.0 ),
  };
}

fn controlPanelConfig() utl.PanelConfig
{
  var style = utl.UiStyle{};
  style.fillCol = utl.Colour.nBlack.setA( 222 );
  style.edgeCol = utl.Colour.pTeal;

  return .{
    .layout  = .column,
    .padding = 8.0,
    .gap     = 4.0,
    .style   = style,
  };
}

/// Releases utility-owned panel storage.
pub fn close() void
{
  if( MAIN_PANEL    )| *panel |{ panel.deinit(); }
  if( CONTROL_PANEL )| *panel |{ panel.deinit(); }

  MAIN_PANEL    = null;
  CONTROL_PANEL = null;

  HANDLES  = .{};
  STATE    = .{};
  CONTROLS = .{};
  STATS    = .{};
}

pub fn clearEvents() void
{
  if( MAIN_PANEL    )| *panel |{ panel.clearEvents(); }
  if( CONTROL_PANEL )| *panel |{ panel.clearEvents(); }
}

pub fn applyDebugBounds( enabled : bool ) void
{
  if( MAIN_PANEL    )| *panel |{ panel.setDebugDrawBounds( enabled ); }
  if( CONTROL_PANEL )| *panel |{ panel.setDebugDrawBounds( enabled ); }
}


// ================================ UPDATE AND DRAW ================================

/// Updates the direct panel path and returns its mouse-consumption state.
pub fn update( ng : *eng.Engine ) bool
{
  if( MAIN_PANEL )| *panel |
  {
    panel.updateInput( ng.mouse );

    if( CONTROL_PANEL )| *control |
    {
      control.setPanelBox( common.utilityControlPanelBox() );
      control.updateInput( ng.mouse );
      drainControlEvents( control, panel );
    }

    STATS.queuedBeforeDrain = panel.getEventCount();
    STATS.drainedThisFrame  = 0;

    if( !STATS.holdMainEvents ){ drainEvents( panel ); }

    common.updatePrimaryDebugLabel( panel, &HANDLES, &STATE, "utility" );
    updateControlReadouts( ng, panel );

    if( CONTROL_PANEL )| *control |{ return panel.wantsMouse() or control.wantsMouse(); }
    return panel.wantsMouse();
  }

  return false;
}

fn drainEvents( panel : *utl.Panel ) void
{
  while( panel.popEvent() )| event |
  {
    STATS.drainedThisFrame += 1;
    STATS.lastSummary = eventKindName( event );
    common.handlePrimaryEvent( panel, &HANDLES, &STATE, event, "Utility" );
  }
}

fn drainControlEvents( control : *utl.Panel, main : *utl.Panel ) void
{
  STATS.controlQueueDrained = 0;

  while( control.popEvent() )| event |
  {
    STATS.controlQueueDrained += 1;

    if( event.isClicked( CONTROLS.rebuildButton ))
    {
      rebuildPrimaryPanel( main );
    }
    else if( event.isClicked( CONTROLS.removeButton ))
    {
      toggleAbsoluteButton( main );
    }
    else if( event.isChanged( CONTROLS.holdEventsCheck ))
    {
      STATS.holdMainEvents = control.getChecked( CONTROLS.holdEventsCheck ) orelse false;
      STATS.lastSummary = "hold events";
    }
    else if( event.isClicked( CONTROLS.clearEventsButton ))
    {
      main.clearEvents();
      STATS.clearEventCount += 1;
      STATS.lastSummary = "events cleared";
    }
    else if( event.isClicked( CONTROLS.mutateButton ))
    {
      mutatePrimaryHandles( main );
    }
  }
}

/// Clears and rebuilds the primary panel in place so stale widget handles and
/// generation-bumped replacement handles can be compared in the readouts.
fn rebuildPrimaryPanel( panel : *utl.Panel ) void
{
  STATS.lastClearedCount = HANDLES.countButton;
  STATS.rebuildCount += 1;

  panel.clear();
  populatePrimaryPanel( panel );

  STATS.lastSummary = "primary rebuild";
}

/// Removes or restores the absolute child button to demonstrate single-widget
/// deletion without rebuilding the whole panel.
fn toggleAbsoluteButton( panel : *utl.Panel ) void
{
  if( panel.isWidgetAlive( HANDLES.absButton ))
  {
    STATS.lastRemovedAbs = HANDLES.absButton;
    STATS.removeCount += 1;

    panel.removeWidget( HANDLES.absButton );
    panel.setTextFmt( HANDLES.status, "Utility removed absolute child. Old handle {d}:{d}.", .{ HANDLES.absButton.idx, HANDLES.absButton.gen });
    STATS.lastSummary = "widget removed";
    return;
  }

  if( !panel.isWidgetAlive( HANDLES.absGroup ))
  {
    STATS.lastSummary = "restore skipped";
    return;
  }

  const oldHandle = HANDLES.absButton;
  HANDLES.absButton = panel.addButton(
    .{
      .key    = utl.uiKey( "menuer.utility.absolute_button" ),
      .parent = HANDLES.absGroup,
      .box    = .{ .center = .new( -116.0, 0.0 ), .scale = .new( 86.0, 18.0 ) },
      .text   = "Absolute child",
      .config = .{ .textAlign = .center },
    }
  ) catch | err |
  {
    HANDLES.absButton = oldHandle;
    utl.log( .ERROR, @src(), "Failed to restore menuer utility absolute child : {}", .{ err });
    return;
  };

  STATS.lastRestoredAbs = HANDLES.absButton;
  STATS.restoreCount += 1;

  panel.setTextFmt( HANDLES.status, "Utility restored absolute child. New handle {d}:{d}.", .{ HANDLES.absButton.idx, HANDLES.absButton.gen });
  STATS.lastSummary = "widget restored";
}

/// Mutates the primary panel through public handle-based setters that are easy
/// to regress when primitive layout or state code changes.
fn mutatePrimaryHandles( panel : *utl.Panel ) void
{
  STATS.mutateStep += 1;

  const enabled : bool = STATS.mutateStep % 2 == 0;
  const wide    : bool = STATS.mutateStep % 3 == 0;
  const gap     : f64  = if( STATS.mutateStep % 2 == 0 ) 8.0 else 14.0;

  panel.setEnabled(     HANDLES.countButton, enabled );
  panel.setDesiredSize( HANDLES.countButton, .new( if( wide ) 186.0 else 156.0, 36.0 ));
  panel.setGap(         HANDLES.rowGroup,    gap );
  panel.setTextFmt(     HANDLES.status,      "Utility handle mutation step {d}: count E:{} gap {d:.0}.", .{ STATS.mutateStep, enabled, gap });

  STATS.lastSummary = "handle mutation";
}

pub fn draw() void
{
  if( MAIN_PANEL )| *panel |
  {
    panel.draw();
    common.drawFinalBoxMarker( panel, &HANDLES );
  }

  if( CONTROL_PANEL )| *panel |{ panel.draw(); }
}


// ================================ DEBUG READOUTS ================================

pub fn writeDebugUi( panel : *utl.Panel, stateLabel : utl.UiHandle, hoverLabel : utl.UiHandle, captureLabel : utl.UiHandle, queueLabel : utl.UiHandle ) void
{
  if( MAIN_PANEL )| *main |
  {
    const hovered = main.getHovered();
    const left    = main.getPressed( .left   );
    const right   = main.getPressed( .right  );
    const middle  = main.getPressed( .middle );

    panel.setTextFmt(
      stateLabel,
      "utility events:{d} pending:{d} checked:{} hold:{}",
      .{ STATE.eventCount, main.getEventCount(), main.getChecked( HANDLES.optionCheck ) orelse false, STATS.holdMainEvents }
    );
    panel.setTextFmt(
      hoverLabel,
      "hover widget:{s}",
      .{ common.widgetNameInPanel( main, hovered ) }
    );
    panel.setTextFmt(
      captureLabel,
      "pressed L:{s} R:{s} M:{s}",
      .{ common.widgetNameInPanel( main, left ), common.widgetNameInPanel( main, right ), common.widgetNameInPanel( main, middle ) }
    );
    panel.setTextFmt(
      queueLabel,
      "engine inert | q:{d} drained:{d} ctrl:{d} last:{s}",
      .{ main.getEventCount(), STATS.drainedThisFrame, STATS.controlQueueDrained, STATS.lastSummary }
    );
  }
}


// ================================ CONTROL READOUT HELPERS ================================

/// Refreshes the utility-only control panel with direct primitive state that is
/// not visible through the shared primary demo surface.
fn updateControlReadouts( ng : *eng.Engine, main : *utl.Panel ) void
{
  if( CONTROL_PANEL )| *panel |
  {
    updateControlButtonText( panel, main );

    const hit = main.hitTest( ng.mouse.screenPos );

    panel.setTextFmt(
      CONTROLS.lifecycleReadout,
      "slots:{d} alive:{d} rebuilds:{d} cleared:{s}",
      .{ main.getWidgetSlotCount(), main.getAliveWidgetCount(), STATS.rebuildCount, handleState( main, STATS.lastClearedCount ) }
    );

    panel.setTextFmt(
      CONTROLS.queueReadout,
      "main q:{d} before:{d} drained:{d} clears:{d}",
      .{ main.getEventCount(), STATS.queuedBeforeDrain, STATS.drainedThisFrame, STATS.clearEventCount }
    );

    panel.setTextFmt(
      CONTROLS.hitReadout,
      "hit:{s} {d}:{d} mouse {d:.0}:{d:.0}",
      .{ common.widgetNameInPanel( main, hit ), handleIdx( hit ), handleGen( hit ), ng.mouse.screenPos.x, ng.mouse.screenPos.y }
    );

    panel.setTextFmt(
      CONTROLS.handleReadout,
      "abs {s} old:{s} {d}:{d} new:{s} {d}:{d}\nremove:{d} restore:{d} mutate:{d}",
      .{
        handleState( main, HANDLES.absButton ),
        handleState( main, STATS.lastRemovedAbs ),
        handleIdx( STATS.lastRemovedAbs ),
        handleGen( STATS.lastRemovedAbs ),
        handleState( main, STATS.lastRestoredAbs ),
        handleIdx( STATS.lastRestoredAbs ),
        handleGen( STATS.lastRestoredAbs ),
        STATS.removeCount,
        STATS.restoreCount,
        STATS.mutateStep,
      }
    );

    panel.updateLayout();
  }
}

fn updateControlButtonText( panel : *utl.Panel, main : *utl.Panel ) void
{
  panel.setTextFmt( CONTROLS.rebuildButton,     "Rebuild {d}", .{ STATS.rebuildCount } );
  panel.setText(    CONTROLS.removeButton,      if( main.isWidgetAlive( HANDLES.absButton ) ) "Remove abs" else "Restore abs" );
  panel.setTextFmt( CONTROLS.clearEventsButton, "Clear {d}",   .{ STATS.clearEventCount } );
  panel.setTextFmt( CONTROLS.mutateButton,      "Mutate {d}",  .{ STATS.mutateStep } );
}

fn eventKindName( event : utl.UiEvent ) []const u8
{
  return switch( event.eType )
  {
    .clicked => "main clicked",
    .changed => "main changed",
  };
}

fn handleState( panel : *const utl.Panel, handle : utl.UiHandle ) []const u8
{
  if( !handle.isValid() ){ return "none"; }
  return if( panel.isWidgetAlive( handle ) ) "live" else "stale";
}

fn handleIdx( handle : utl.UiHandle ) u32
{
  return if( handle.isValid() ) handle.idx else 0;
}

fn handleGen( handle : utl.UiHandle ) u32
{
  return if( handle.isValid() ) handle.gen else 0;
}
