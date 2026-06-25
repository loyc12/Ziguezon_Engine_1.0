const utl = @import( "utils" );


// ================================ SHARED PRIMARY UI ================================

/// Handles for the comparable primary demo surface used by both UI paths.
pub const PrimaryUiHandles = struct
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

pub const PrimaryUiKeys = struct
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

/// Mutable counters that make event handling visible in the sandbox labels.
pub const PrimaryUiState = struct
{
  clickCount : u32 = 0,
  moveStep   : u32 = 0,
  absCount   : u32 = 0,
  eventCount : u32 = 0,
};


// ================================ LAYOUT HELPERS ================================

pub fn primaryPanelBox() utl.Box2
{
  return utl.uiBoxFromTopLeft( .new( 24.0, 24.0 ), .new( 460.0, 390.0 ));
}

pub fn engineBackPanelBox() utl.Box2
{
  return utl.uiBoxFromTopLeft( .new( 452.0, 104.0 ), .new( 300.0, 206.0 ));
}

pub fn engineControlPanelBox() utl.Box2
{
  return utl.uiBoxFromTopLeft( .new( 24.0, 430.0 ), .new( 460.0, 270.0 ));
}

pub fn debugPanelBox() utl.Box2
{
  const size = utl.Vec2.new( 430.0, 410.0 );
  return utl.uiBoxFromTopLeft( .new( utl.getScreenWidth() - size.x - 24.0, 24.0 ), size );
}

pub fn buttonConfig() utl.WidgetConfig
{
  return .{
    .desiredSize = .new( 0.0, 36.0 ),
    .textAlign   = .center,
  };
}

pub fn labelConfig( height : f64 ) utl.WidgetConfig
{
  return .{
    .desiredSize = .new( 0.0, height ),
  };
}

pub fn containerConfig( layout : utl.UiLayout, height : f64 ) utl.WidgetConfig
{
  return .{
    .layout      = layout,
    .desiredSize = .new( 0.0, height ),
    .padding     = 0.0,
    .gap         = 8.0,
  };
}

pub fn primaryPanelConfig( edgeCol : utl.Colour ) utl.PanelConfig
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

pub fn managerPanelConfig( fillCol : utl.Colour ) utl.PanelConfig
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

pub fn debugPanelConfig() utl.PanelConfig
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


// ================================ PRIMARY SURFACE HELPERS ================================

/// Adds the shared primary controls used to compare direct utility UI with
/// manager-routed engine UI.
pub fn addPrimaryControls( panel : *utl.Panel, handles : *PrimaryUiHandles, keys : PrimaryUiKeys, title : []const u8, status : []const u8 ) void
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

/// Applies the shared primary-surface interactions and leaves path-specific
/// routing/event ownership to the caller.
pub fn handlePrimaryEvent( panel : *utl.Panel, handles : *const PrimaryUiHandles, state : *PrimaryUiState, event : utl.UiEvent, pathName : []const u8 ) void
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

pub fn updatePrimaryDebugLabel( panel : *utl.Panel, handles : *const PrimaryUiHandles, state : *const PrimaryUiState, modeName : []const u8 ) void
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

pub fn widgetNameInPanel( panel : *const utl.Panel, widget : utl.UiHandle ) []const u8
{
  if( !widget.isValid() ){ return "none"; }
  return if( panel.getWidgetKind( widget ))| kind | @tagName( kind ) else "stale";
}

pub fn drawFinalBoxMarker( panel : *utl.Panel, handles : *const PrimaryUiHandles ) void
{
  if( panel.getWidgetFinalBox( handles.moveButton ))| box |
  {
    utl.sDraw.basicCirclePerim( box.center, 5.0, utl.Colour.pGold );
    utl.sDraw.basicLine( box.center.add( .new( -10.0, 0.0 )), box.center.add( .new( 10.0, 0.0 )), utl.Colour.pGold, 1.0 );
    utl.sDraw.basicLine( box.center.add( .new( 0.0, -10.0 )), box.center.add( .new( 0.0, 10.0 )), utl.Colour.pGold, 1.0 );
  }
}
