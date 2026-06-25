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
  generateButton    : utl.UiHandle = .{},
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

const GENERATED_MIN_WIDGETS : usize = 3;
const GENERATED_MAX_WIDGETS : usize = 7;

/// Supported primitive kinds for the utility random-panel generator. This stays
/// narrower than `utl.WidgetKind` so unsupported/future widgets cannot leak into
/// the visible sandbox by accident.
const GeneratedKind = enum( u8 )
{
  label,
  button,
  checkbox,
  spacer,
  container,
};

/// Runtime handle plus kind metadata used by generated-panel readouts and event
/// summaries after widgets are inserted in randomized order.
const GeneratedItem = struct
{
  handle : utl.UiHandle  = .{},
  kind   : GeneratedKind = .label,
};

/// Compact generated-panel state shown through the utility control and debug
/// readouts. The panel itself owns widget/event storage; this only stores
/// generation metadata and last-frame observations.
const GeneratedStats = struct
{
  generationCount   : u32   = 0,
  widgetCount       : usize = 0,
  queuedBeforeDrain : usize = 0,
  drainedThisFrame  : usize = 0,
  lastClearedCount  : usize = 0,
  lastEvent         : []const u8 = "none",
  items             : [ GENERATED_MAX_WIDGETS ]GeneratedItem = [_]GeneratedItem{ .{} } ** GENERATED_MAX_WIDGETS,
};

var MAIN_PANEL    : ?utl.Panel = null;
var CONTROL_PANEL : ?utl.Panel = null;
var GENERATED_PANEL : ?utl.Panel = null;

var HANDLES  : common.PrimaryUiHandles = .{};
var STATE    : common.PrimaryUiState   = .{};
var CONTROLS : ControlHandles          = .{};
var STATS    : UtilityStats            = .{};
var GENERATED_STATS : GeneratedStats   = .{};


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

  CONTROLS.generateButton = panel.addButton(
    .{
      .key    = utl.uiKey( "menuer.utility.controls.generate" ),
      .parent = CONTROLS.lifecycleRow,
      .text   = "Random panel",
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
  if( GENERATED_PANEL )| *panel |{ panel.deinit(); }
  if( MAIN_PANEL      )| *panel |{ panel.deinit(); }
  if( CONTROL_PANEL   )| *panel |{ panel.deinit(); }

  GENERATED_PANEL = null;
  MAIN_PANEL      = null;
  CONTROL_PANEL   = null;

  HANDLES         = .{};
  STATE           = .{};
  CONTROLS        = .{};
  STATS           = .{};
  GENERATED_STATS = .{};
}

pub fn clearEvents() void
{
  if( MAIN_PANEL      )| *panel |{ panel.clearEvents(); }
  if( CONTROL_PANEL   )| *panel |{ panel.clearEvents(); }
  if( GENERATED_PANEL )| *panel |{ panel.clearEvents(); }
}

pub fn applyDebugBounds( enabled : bool ) void
{
  if( MAIN_PANEL      )| *panel |{ panel.setDebugDrawBounds( enabled ); }
  if( CONTROL_PANEL   )| *panel |{ panel.setDebugDrawBounds( enabled ); }
  if( GENERATED_PANEL )| *panel |{ panel.setDebugDrawBounds( enabled ); }
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
      drainControlEvents( ng, control, panel );
    }

    if( GENERATED_PANEL )| *generated |
    {
      generated.setPanelBox( common.utilityGeneratedPanelBox() );
      generated.updateInput( ng.mouse );
    }

    STATS.queuedBeforeDrain = panel.getEventCount();
    STATS.drainedThisFrame  = 0;
    GENERATED_STATS.queuedBeforeDrain = generatedEventCount();
    GENERATED_STATS.drainedThisFrame  = 0;

    if( !STATS.holdMainEvents ){ drainEvents( panel ); }
    drainGeneratedEvents();

    common.updatePrimaryDebugLabel( panel, &HANDLES, &STATE, "utility" );
    updateControlReadouts( ng, panel );

    var wantsMouse = panel.wantsMouse();
    if( CONTROL_PANEL   )| *control   |{ wantsMouse = wantsMouse or control.wantsMouse();    }
    if( GENERATED_PANEL )| *generated |{ wantsMouse = wantsMouse or generated.wantsMouse();  }
    return wantsMouse;
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

fn drainControlEvents( ng : *eng.Engine, control : *utl.Panel, main : *utl.Panel ) void
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
      if( GENERATED_PANEL )| *panel |{ panel.clearEvents(); }
      STATS.clearEventCount += 1;
      STATS.lastSummary = "events cleared";
    }
    else if( event.isClicked( CONTROLS.generateButton ))
    {
      replaceGeneratedPanel( ng );
      STATS.lastSummary = "generated panel";
    }
    else if( event.isClicked( CONTROLS.mutateButton ))
    {
      mutatePrimaryHandles( main );
    }
  }
}

fn drainGeneratedEvents() void
{
  if( GENERATED_PANEL )| *panel |
  {
    while( panel.popEvent() )| event |
    {
      GENERATED_STATS.drainedThisFrame += 1;
      GENERATED_STATS.lastEvent = generatedEventName( panel, event );
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

/// Replaces the current generated panel with a fresh bounded primitive mix.
/// Old local events and handles are discarded before new storage is published.
fn replaceGeneratedPanel( ng : *eng.Engine ) void
{
  const nextGeneration = GENERATED_STATS.generationCount + 1;
  var clearedCount : usize = 0;

  if( GENERATED_PANEL )| *panel |
  {
    clearedCount = panel.getAliveWidgetCount();
    panel.clearEvents();
    panel.deinit();
  }

  GENERATED_PANEL = null;
  GENERATED_STATS = .{ .generationCount = nextGeneration, .lastClearedCount = clearedCount };

  GENERATED_PANEL = utl.Panel.init(
    utl.getDefaultAlloc(),
    .{
      .key    = generatedPanelKey( nextGeneration ),
      .box    = common.utilityGeneratedPanelBox(),
      .config = common.generatedPanelConfig(),
    }
  ) catch | err |
  {
    GENERATED_STATS.lastEvent = "create failed";
    utl.log( .ERROR, @src(), "Failed to create menuer generated utility panel : {}", .{ err });
    return;
  };

  populateGeneratedPanel( ng, &( GENERATED_PANEL.? ), nextGeneration );
}

fn populateGeneratedPanel( ng : *eng.Engine, panel : *utl.Panel, generation : u32 ) void
{
  var kinds : [ GENERATED_MAX_WIDGETS ]GeneratedKind = undefined;
  const widgetCount = randomUsize( ng, GENERATED_MIN_WIDGETS, GENERATED_MAX_WIDGETS );

  for( 0..widgetCount )| i |{ kinds[ i ] = randomGeneratedKind( ng ); }

  // Shuffle the chosen kinds before insertion so child order changes while all
  // panel and widget dimensions remain fixed.
  for( 0..widgetCount )| i |
  {
    const swapIdx = randomUsize( ng, i, widgetCount - 1 );
    const tmp = kinds[ i ];
    kinds[ i ] = kinds[ swapIdx ];
    kinds[ swapIdx ] = tmp;
  }

  for( 0..widgetCount )| i |
  {
    const kind = kinds[ i ];
    if( addGeneratedWidget( panel, kind, generation, i ))| handle |
    {
      GENERATED_STATS.items[ GENERATED_STATS.widgetCount ] = .{ .handle = handle, .kind = kind };
      GENERATED_STATS.widgetCount += 1;
    }
  }

  panel.updateLayout();
  GENERATED_STATS.lastEvent = "generated";
}

fn addGeneratedWidget( panel : *utl.Panel, kind : GeneratedKind, generation : u32, index : usize ) ?utl.UiHandle
{
  const opts : utl.WidgetInit = .{
    .key    = generatedWidgetKey( kind, generation, index ),
    .text   = generatedKindName( kind ),
    .config = generatedWidgetConfig( kind ),
  };

  const handle =
    switch( kind )
    {
      .label     => panel.addLabel(     opts ) catch return null,
      .button    => panel.addButton(    opts ) catch return null,
      .checkbox  => panel.addCheckbox(  opts ) catch return null,
      .spacer    => panel.addSpacer(    opts ) catch return null,
      .container => panel.addContainer( opts ) catch return null,
    };

  switch( kind )
  {
    .label    => panel.setTextFmt( handle, "Label {d}.{d}",  .{ generation, index } ),
    .button   => panel.setTextFmt( handle, "Button {d}.{d}", .{ generation, index } ),
    .checkbox => panel.setTextFmt( handle, "Check {d}.{d}",  .{ generation, index } ),
    else      => {},
  }

  return handle;
}

fn generatedWidgetConfig( kind : GeneratedKind ) utl.WidgetConfig
{
  var config = utl.WidgetConfig{
    .desiredSize = .new( 0.0, 28.0 ),
    .textAlign   = .center,
  };

  if( kind == .container )
  {
    config.style = generatedContainerStyle();
  }

  return config;
}

fn generatedContainerStyle() utl.UiStyle
{
  var style = utl.UiStyle.forKind( .container );
  style.fillCol   = utl.Colour.sGray.setA( 96 );
  style.edgeCol   = utl.Colour.pGold.setA( 210 );
  style.lineWidth = 1.0;
  return style;
}

fn randomGeneratedKind( ng : *eng.Engine ) GeneratedKind
{
  return switch( randomUsize( ng, 0, 4 ))
  {
    0    => .label,
    1    => .button,
    2    => .checkbox,
    3    => .spacer,
    else => .container,
  };
}

fn randomUsize( ng : *eng.Engine, min : usize, max : usize ) usize
{
  return @intCast( ng.rng.getClampedInt( @intCast( min ), @intCast( max ) ) );
}

fn generatedPanelKey( generation : u32 ) utl.UiKey
{
  return utl.uiKey( "menuer.utility.generated.panel" ) ^ @as( utl.UiKey, generation );
}

fn generatedWidgetKey( kind : GeneratedKind, generation : u32, index : usize ) utl.UiKey
{
  const base = utl.uiKey( "menuer.utility.generated.widget" );
  const kindBits = @as( utl.UiKey, @intFromEnum( kind )) << 48;
  const genBits  = @as( utl.UiKey, generation ) << 16;
  return base ^ kindBits ^ genBits ^ @as( utl.UiKey, index );
}

fn generatedEventCount() usize
{
  if( GENERATED_PANEL )| *panel |{ return panel.getEventCount(); }
  return 0;
}

fn generatedEventName( panel : *const utl.Panel, event : utl.UiEvent ) []const u8
{
  return switch( event.eType )
  {
    .clicked => switch( panel.getWidgetKind( event.widget ) orelse .label )
    {
      .button => "button clicked",
      else    => "clicked",
    },

    .changed => switch( panel.getWidgetKind( event.widget ) orelse .label )
    {
      .checkbox => "checkbox changed",
      else      => "changed",
    },
  };
}

fn generatedKindName( kind : GeneratedKind ) []const u8
{
  return switch( kind )
  {
    .label     => "label",
    .button    => "button",
    .checkbox  => "checkbox",
    .spacer    => "spacer",
    .container => "container",
  };
}

fn generatedKindShortName( kind : GeneratedKind ) []const u8
{
  return switch( kind )
  {
    .label     => "lab",
    .button    => "btn",
    .checkbox  => "chk",
    .spacer    => "spc",
    .container => "box",
  };
}

fn generatedOrderName( index : usize ) []const u8
{
  if( index >= GENERATED_STATS.widgetCount ){ return "-"; }
  return generatedKindShortName( GENERATED_STATS.items[ index ].kind );
}

pub fn draw() void
{
  if( MAIN_PANEL )| *panel |
  {
    panel.draw();
    common.drawFinalBoxMarker( panel, &HANDLES );
  }

  if( GENERATED_PANEL )| *panel |{ panel.draw(); }
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

    var genHover : []const u8 = "none";
    var genLeft  : []const u8 = "none";
    var genHit   : []const u8 = "none";

    if( GENERATED_PANEL )| *generated |
    {
      genHover = common.widgetNameInPanel( generated, generated.getHovered() );
      genLeft  = common.widgetNameInPanel( generated, generated.getPressed( .left ) );
      genHit   = common.widgetNameInPanel( generated, generated.hitTest( generated.getPointer().screenPos ) );
    }

    panel.setTextFmt(
      stateLabel,
      "utility events:{d} pending:{d} checked:{} hold:{} gen:{d}/{d}",
      .{ STATE.eventCount, main.getEventCount(), main.getChecked( HANDLES.optionCheck ) orelse false, STATS.holdMainEvents, GENERATED_STATS.generationCount, GENERATED_STATS.widgetCount }
    );
    panel.setTextFmt(
      hoverLabel,
      "hover main:{s} gen:{s} hit:{s}",
      .{ common.widgetNameInPanel( main, hovered ), genHover, genHit }
    );
    panel.setTextFmt(
      captureLabel,
      "pressed main L:{s} R:{s} M:{s} | gen L:{s}",
      .{ common.widgetNameInPanel( main, left ), common.widgetNameInPanel( main, right ), common.widgetNameInPanel( main, middle ), genLeft }
    );
    panel.setTextFmt(
      queueLabel,
      "q main:{d}/{d} gen:{d}/{d} ctrl:{d} last:{s}/{s}",
      .{ main.getEventCount(), STATS.drainedThisFrame, generatedEventCount(), GENERATED_STATS.drainedThisFrame, STATS.controlQueueDrained, STATS.lastSummary, GENERATED_STATS.lastEvent }
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

    var genHitName : []const u8 = "none";
    if( GENERATED_PANEL )| *generated |
    {
      genHitName = common.widgetNameInPanel( generated, generated.hitTest( ng.mouse.screenPos ) );
    }

    panel.setTextFmt(
      CONTROLS.lifecycleReadout,
      "slots:{d} alive:{d} rebuilds:{d} gen:{d} old:{d}",
      .{ main.getWidgetSlotCount(), main.getAliveWidgetCount(), STATS.rebuildCount, GENERATED_STATS.generationCount, GENERATED_STATS.lastClearedCount }
    );

    panel.setTextFmt(
      CONTROLS.queueReadout,
      "main q:{d}->{d} gen q:{d}->{d} clears:{d}",
      .{ STATS.queuedBeforeDrain, STATS.drainedThisFrame, GENERATED_STATS.queuedBeforeDrain, GENERATED_STATS.drainedThisFrame, STATS.clearEventCount }
    );

    panel.setTextFmt(
      CONTROLS.hitReadout,
      "hit main:{s} {d}:{d} gen:{s} mouse {d:.0}:{d:.0}",
      .{ common.widgetNameInPanel( main, hit ), handleIdx( hit ), handleGen( hit ), genHitName, ng.mouse.screenPos.x, ng.mouse.screenPos.y }
    );

    panel.setTextFmt(
      CONTROLS.handleReadout,
      "abs {s} old:{s} {d}:{d} new:{s} {d}:{d}\nrm:{d} rs:{d} mut:{d} order:{s},{s},{s},{s},{s},{s},{s}",
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
        generatedOrderName( 0 ),
        generatedOrderName( 1 ),
        generatedOrderName( 2 ),
        generatedOrderName( 3 ),
        generatedOrderName( 4 ),
        generatedOrderName( 5 ),
        generatedOrderName( 6 ),
      }
    );

    panel.updateLayout();
  }
}

fn updateControlButtonText( panel : *utl.Panel, main : *utl.Panel ) void
{
  panel.setTextFmt( CONTROLS.rebuildButton,     "Rebuild {d}", .{ STATS.rebuildCount } );
  panel.setText(    CONTROLS.removeButton,      if( main.isWidgetAlive( HANDLES.absButton ) ) "Remove abs" else "Restore abs" );
  panel.setTextFmt( CONTROLS.generateButton,    "Random {d}",  .{ GENERATED_STATS.generationCount } );
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
