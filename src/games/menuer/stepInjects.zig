const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );


// ================================ UI SANDBOX STATE ================================

var MAIN_PANEL   : ?utl.Panel   = null;
var TITLE_LABEL  : utl.UiHandle = .{};
var STATUS_LABEL : utl.UiHandle = .{};
var DEBUG_LABEL  : utl.UiHandle = .{};
var ROW_GROUP    : utl.UiHandle = .{};
var ABS_GROUP    : utl.UiHandle = .{};
var COUNT_BUTTON : utl.UiHandle = .{};
var MOVE_BUTTON  : utl.UiHandle = .{};
var OPTION_CHECK : utl.UiHandle = .{};
var ABS_BUTTON   : utl.UiHandle = .{};
var CLICK_COUNT  : u32          = 0;
var MOVE_STEP    : u32          = 0;


// ================================ UI SANDBOX ================================

fn mainPanelBox() utl.Box2
{
  return utl.uiBoxFromTopLeft( .new( 24.0, 24.0 ), .new( 460.0, 390.0 ));
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

pub fn buildUi( ng : *eng.Engine ) void
{
  _ = ng;

  closeUi();

  CLICK_COUNT = 0;
  MOVE_STEP   = 0;

  MAIN_PANEL = utl.Panel.init(
    utl.getDefaultAlloc(),
    .{
      .key    = utl.uiKey( "menuer.main" ),
      .box    = mainPanelBox(),
      .config = .{
        .layout  = .column,
        .padding = 12.0,
        .gap     = 8.0,
      },
    }
  ) catch | err |
  {
    utl.log( .ERROR, 0, @src(), "Failed to create menuer UI panel : {}", .{ err });
    return;
  };

  var panel = &( MAIN_PANEL.? );
  panel.setDebugDrawBounds( true );

  TITLE_LABEL = panel.addLabel(
    .{
      .key    = utl.uiKey( "menuer.title" ),
      .text   = "Primitive UI testbed",
      .config = labelConfig( 28.0 ),
    }
  ) catch .{};

  STATUS_LABEL = panel.addLabel(
    .{
      .key    = utl.uiKey( "menuer.status" ),
      .text   = "Click a button to mutate retained UI state.",
      .config = labelConfig( 44.0 ),
    }
  ) catch .{};

  ROW_GROUP = panel.addContainer(
    .{
      .key    = utl.uiKey( "menuer.row_group" ),
      .config = containerConfig( .row, 42.0 ),
    }
  ) catch .{};

  COUNT_BUTTON = panel.addButton(
    .{
      .key    = utl.uiKey( "menuer.count_button" ),
      .parent = ROW_GROUP,
      .text   = "Count click",
      .config = .{
        .desiredSize = .new( 156.0, 36.0 ),
        .textAlign   = .center,
      },
    }
  ) catch .{};

  OPTION_CHECK = panel.addCheckbox(
    .{
      .key    = utl.uiKey( "menuer.option_check" ),
      .parent = ROW_GROUP,
      .text   = "Option",
      .config = .{
        .desiredSize = .new( 132.0, 36.0 ),
        .isChecked   = true,
      },
    }
  ) catch .{};

  MOVE_BUTTON = panel.addButton(
    .{
      .key    = utl.uiKey( "menuer.move_button" ),
      .text   = "Move this button",
      .config = buttonConfig(),
    }
  ) catch .{};

  ABS_GROUP = panel.addContainer(
    .{
      .key    = utl.uiKey( "menuer.absolute_group" ),
      .config = containerConfig( .absolute, 58.0 ),
    }
  ) catch .{};

  ABS_BUTTON = panel.addButton(
    .{
      .key    = utl.uiKey( "menuer.absolute_button" ),
      .parent = ABS_GROUP,
      .box    = .{ .center = .new( -116.0, 0.0 ), .scale = .new( 86.0, 18.0 ) },
      .text   = "Absolute child",
      .config = .{ .textAlign = .center },
    }
  ) catch .{};

  _ = panel.addSpacer(
    .{
      .key    = utl.uiKey( "menuer.spacer" ),
      .config = .{ .desiredSize = .new( 0.0, 8.0 ) },
    }
  ) catch .{};

  DEBUG_LABEL = panel.addLabel(
    .{
      .key    = utl.uiKey( "menuer.debug" ),
      .text   = "hover: none | final: none",
      .config = labelConfig( 74.0 ),
    }
  ) catch .{};

  panel.updateLayout();
}

pub fn closeUi() void
{
  if( MAIN_PANEL )| *panel |{ panel.deinit(); }

  MAIN_PANEL   = null;
  TITLE_LABEL  = .{};
  STATUS_LABEL = .{};
  DEBUG_LABEL  = .{};
  ROW_GROUP    = .{};
  ABS_GROUP    = .{};
  COUNT_BUTTON = .{};
  MOVE_BUTTON  = .{};
  OPTION_CHECK = .{};
  ABS_BUTTON   = .{};
}

fn handleUiEvents( panel : *utl.Panel ) void
{
  while( panel.popEvent() )| event |
  {
    if( event.isClicked( COUNT_BUTTON ))
    {
      CLICK_COUNT += 1;
      panel.setTextFmt( COUNT_BUTTON, "Count click ({d})", .{ CLICK_COUNT });
      panel.setTextFmt( STATUS_LABEL, "Button event received. Click count: {d}.", .{ CLICK_COUNT });
    }
    else if( event.isClicked( MOVE_BUTTON ))
    {
      MOVE_STEP = ( MOVE_STEP + 1 ) % 7;

      const offset = utl.Vec2.new( @as( f64, @floatFromInt( MOVE_STEP )) * 12.0, 0.0 );
      panel.setVisualOffset( MOVE_BUTTON, offset );
      panel.setTextFmt( STATUS_LABEL, "Moved button by {d:.0}px using setVisualOffset().", .{ offset.x });
    }
    else if( event.isClicked( ABS_BUTTON ))
    {
      panel.bringWidgetForward( ABS_BUTTON );
      panel.setText( STATUS_LABEL, "Absolute child clicked; sibling order helper ran." );
    }
    else if( event.isChanged( OPTION_CHECK ))
    {
      const checked = panel.getChecked( OPTION_CHECK ) orelse false;
      panel.setTextFmt( STATUS_LABEL, "Checkbox changed. Checked: {}.", .{ checked });
    }
  }
}

fn updateDebugLabel( panel : *utl.Panel ) void
{
  panel.updateLayout();

  const hovered = panel.getHovered();
  const hoverName =
    if( panel.getWidgetKind( hovered ))| kind | @tagName( kind )
    else "none";

  const childCount = panel.getChildCount( ROW_GROUP );

  if( panel.getWidgetFinalBox( MOVE_BUTTON ))| box |
  {
    if( panel.getWidgetTextMetrics( STATUS_LABEL ))| metrics |
    {
      panel.setTextFmt(
        DEBUG_LABEL,
        "hover:{s} | row children:{d} | move:{d:.0}:{d:.0} | status text:{d:.0}x{d:.0}",
        .{ hoverName, childCount, box.center.x, box.center.y, metrics.measuredSize.x, metrics.lineHeight }
      );
    }
    else
    {
      panel.setTextFmt(
        DEBUG_LABEL,
        "hover:{s} | row children:{d} | move:{d:.0}:{d:.0} | text:none",
        .{ hoverName, childCount, box.center.x, box.center.y }
      );
    }
  }
  else
  {
    panel.setTextFmt( DEBUG_LABEL, "hover: {s} | final: none", .{ hoverName });
  }
}

fn uiWantsMouse( panel : *utl.Panel ) bool
{
  return panel.getHovered().isValid()
    or panel.getPressed( .left   ).isValid()
    or panel.getPressed( .right  ).isValid()
    or panel.getPressed( .middle ).isValid();
}

fn drawFinalBoxMarker( panel : *utl.Panel ) void
{
  if( panel.getWidgetFinalBox( MOVE_BUTTON ))| box |
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
  var wantsMouse = false;

  if( MAIN_PANEL )| *panel |
  {
    panel.updateInput( ng.mouse );
    handleUiEvents( panel );
    updateDebugLabel( panel );

    wantsMouse = uiWantsMouse( panel );
  }

  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.enter ) or utl.ray.isKeyPressed( utl.ray.KeyboardKey.p )){ ng.togglePause(); }

  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.w ) or utl.ray.isKeyDown( utl.ray.KeyboardKey.up    )){ eng.G_ENG.camera.moveByS( utl.Vec2.new(  0, -8 )); }
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.s ) or utl.ray.isKeyDown( utl.ray.KeyboardKey.down  )){ eng.G_ENG.camera.moveByS( utl.Vec2.new(  0,  8 )); }
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.a ) or utl.ray.isKeyDown( utl.ray.KeyboardKey.left  )){ eng.G_ENG.camera.moveByS( utl.Vec2.new( -8,  0 )); }
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.d ) or utl.ray.isKeyDown( utl.ray.KeyboardKey.right )){ eng.G_ENG.camera.moveByS( utl.Vec2.new(  8,  0 )); }

  if( !wantsMouse )
  {
    if( ng.mouse.wheelMove > 0.0 ){ eng.G_ENG.camera.zoomBy( 1.1 ); }
    if( ng.mouse.wheelMove < 0.0 ){ eng.G_ENG.camera.zoomBy( 0.9 ); }
  }

  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.r ))
  {
    eng.G_ENG.camera.setZoom(   1.0 );
    eng.G_ENG.camera.cam.pos = .{};
    utl.qlog( .INFO, 0, @src(), "Camera reset" );
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

pub fn OffRenderWorld( ng : *eng.Engine ) void
{
  _ = ng;
}

pub fn OnRenderOverlay( ng : *eng.Engine ) void
{
  if( ng.isPaused() )
  {
    utl.sDraw.coverScreenWithCol( utl.Colour.new( 0, 0, 0, 128 ));
  }

  if( MAIN_PANEL )| *panel |
  {
    panel.draw();
    drawFinalBoxMarker( panel );
  }
}
