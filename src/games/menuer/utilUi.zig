const eng    = @import( "engine" );
const utl    = @import( "utils" );
const common = @import( "uiCommon.zig" );


// ================================ UTILITY UI STATE ================================

var MAIN_PANEL : ?utl.Panel = null;

var HANDLES : common.PrimaryUiHandles = .{};
var STATE   : common.PrimaryUiState   = .{};


// ================================ LIFETIME ================================

/// Builds the direct utility panel used as the primitive-side comparison path.
pub fn build() void
{
  close();

  STATE = .{};

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

  const panel = &( MAIN_PANEL.? );
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

/// Releases utility-owned panel storage.
pub fn close() void
{
  if( MAIN_PANEL )| *panel |{ panel.deinit(); }

  MAIN_PANEL = null;
  HANDLES    = .{};
  STATE      = .{};
}

pub fn clearEvents() void
{
  if( MAIN_PANEL )| *panel |{ panel.clearEvents(); }
}

pub fn applyDebugBounds( enabled : bool ) void
{
  if( MAIN_PANEL )| *panel |{ panel.setDebugDrawBounds( enabled ); }
}


// ================================ UPDATE AND DRAW ================================

/// Updates the direct panel path and returns its mouse-consumption state.
pub fn update( ng : *eng.Engine ) bool
{
  if( MAIN_PANEL )| *panel |
  {
    panel.updateInput( ng.mouse );
    drainEvents( panel );
    common.updatePrimaryDebugLabel( panel, &HANDLES, &STATE, "utility" );
    return panel.wantsMouse();
  }

  return false;
}

fn drainEvents( panel : *utl.Panel ) void
{
  while( panel.popEvent() )| event |
  {
    common.handlePrimaryEvent( panel, &HANDLES, &STATE, event, "Utility" );
  }
}

pub fn draw() void
{
  if( MAIN_PANEL )| *panel |
  {
    panel.draw();
    common.drawFinalBoxMarker( panel, &HANDLES );
  }
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
      "utility events:{d} pending:{d} checked:{}",
      .{ STATE.eventCount, main.getEventCount(), main.getChecked( HANDLES.optionCheck ) orelse false }
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
      "engine panels inert | active events:{d}",
      .{ STATE.eventCount }
    );
  }
}
