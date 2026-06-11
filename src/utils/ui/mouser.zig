const std = @import( "std" );
const utl = @import( "utils" );

const Duration = utl.Duration;
const Vec2     = utl.Vec2;

fn addDuration( base : Duration, delta : Duration ) Duration
{
  return .{
    .value = std.math.add( i128, base.value, delta.value ) catch std.math.maxInt( i128 ),
  };
}


// ================================ UI MOUSE TARGETS ================================

/// Packed UI target for panel/widget hover and capture state. `Panel` packs its
/// generation-checked `UiHandle` into this generic mouse-layer id; direct mouse
/// callers may still use explicit ids when no panel is involved.
pub const MouseUiTarget = struct
{
  pub const invalidId : u64 = std.math.maxInt( u64 );

  id : u64 = invalidId,

  pub inline fn none() MouseUiTarget { return .{}; }

  pub inline fn fromId( id : u64 ) MouseUiTarget { return .{ .id = id }; }

  pub inline fn isValid( self : MouseUiTarget ) bool { return self.id != invalidId; }

  pub inline fn isEq( self : MouseUiTarget, other : MouseUiTarget ) bool
  {
    return self.id == other.id;
  }
};


// ================================ BUTTON STATE ================================

pub const MouseButton = enum( u8 )
{
  left,
  right,
  middle,

  pub const count = @typeInfo( MouseButton ).@"enum".fields.len;

  pub inline fn toIndex( self : MouseButton ) usize { return @intFromEnum( self ); }
};

pub const MouseButtonState = struct
{
  isDown            : bool     = false,
  pressedThisFrame  : bool     = false,
  releasedThisFrame : bool     = false,
  heldTime          : Duration = .{},
  dragDelta         : Vec2     = .{},

  // Generic packed target so the mouse layer stays independent from `Panel`.
  pressedWidget : MouseUiTarget = .{},

  pub inline fn resetFrame( self : *MouseButtonState ) void
  {
    self.pressedThisFrame  = false;
    self.releasedThisFrame = false;
    self.dragDelta         = .{};
  }

  pub inline fn update( self : *MouseButtonState, isDown : bool, pressed : bool, released : bool, mouseDelta : Vec2, deltaTime : Duration ) void
  {
    self.isDown            = isDown;
    self.pressedThisFrame  = pressed;
    self.releasedThisFrame = released;
    self.dragDelta         = if( isDown ) mouseDelta else .{};

    if( pressed )
    {
      self.heldTime = .{};
    }
    else if( isDown )
    {
      self.heldTime = addDuration( self.heldTime, deltaTime );
    }
    else
    {
      self.heldTime = .{};
    }

    if( released ){ self.pressedWidget = .{}; }
  }
};


// ================================ MODIFIER STATE ================================

pub const MouseModifier = enum( u8 )
{
  shift,
  ctrl,
  alt,
  super,

  pub const count = @typeInfo( MouseModifier ).@"enum".fields.len;

  pub inline fn toIndex( self : MouseModifier ) usize
  {
    return @intFromEnum( self );
  }
};

pub const MouseModifierState = struct
{
  isDown            : bool     = false,
  leftDown          : bool     = false,
  rightDown         : bool     = false,
  pressedThisFrame  : bool     = false,
  releasedThisFrame : bool     = false,
  heldTime          : Duration = .{},

  pub inline fn update( self : *MouseModifierState, leftDown : bool, rightDown : bool, leftPressed : bool, rightPressed : bool, leftReleased : bool, rightReleased : bool, deltaTime : Duration ) void
  {
    self.leftDown          = leftDown;
    self.rightDown         = rightDown;
    self.isDown            = leftDown     or rightDown;
    self.pressedThisFrame  = leftPressed  or rightPressed;
    self.releasedThisFrame = leftReleased or rightReleased;

    // TODO : split into individualize left and right press timers
    if( self.pressedThisFrame )
    {
      self.heldTime = .{};
    }
    else if( self.isDown )
    {
      self.heldTime = addDuration( self.heldTime, deltaTime );
    }
    else
    {
      self.heldTime = .{};
    }
  }
};


// ================================ MOUSE STATE ================================

/// Engine-agnostic mouse snapshot for UI and camera-aware callers. It stores raw
/// pointer movement, modifier keys, and UI-facing transient targeting state in
/// one place.
pub const Mouse = struct
{
  screenPos  : Vec2 = .{},
  screenPrev : Vec2 = .{},
  screenMove : Vec2 = .{},
  wheelMove  : f64  = 0.0,
  frameTime  : Duration = .{},

  // Optional world-space position supplied by engine/camera code.
  worldPos  : ?Vec2 = null,

  buttons   : [ MouseButton.count   ]MouseButtonState   = [_]MouseButtonState{   .{} } ** MouseButton.count,
  modifiers : [ MouseModifier.count ]MouseModifierState = [_]MouseModifierState{ .{} } ** MouseModifier.count,

  // UI-facing hover targets are set by primitive panels or the future manager
  // after hit testing. They are kept generic to avoid an engine dependency.
  topPanel      : MouseUiTarget = .{},
  topWidget     : MouseUiTarget = .{},
  prevTopPanel  : MouseUiTarget = .{},
  prevTopWidget : MouseUiTarget = .{},

  hoverTime : Duration = .{},


  // ================================ UPDATING ================================

  pub fn fromRayData( deltaTime : Duration ) Mouse
  {
    var mouse : Mouse = .{};
    mouse.updateRaylib( deltaTime );
    return mouse;
  }

  pub fn updateRaylib( self : *Mouse, deltaTime : Duration ) void
  {
    self.frameTime  = deltaTime;
    self.screenPrev = self.screenPos;
    self.screenPos  = utl.getMouseScreenPos();
    self.screenMove = Vec2.fromRayVec2( utl.ray.getMouseDelta() );
    self.wheelMove  = @floatCast( utl.ray.getMouseWheelMove() );

    self.updateButton( .left,
      utl.ray.isMouseButtonDown(     utl.ray.MouseButton.left ),
      utl.ray.isMouseButtonPressed(  utl.ray.MouseButton.left ),
      utl.ray.isMouseButtonReleased( utl.ray.MouseButton.left ),
      deltaTime
    );

    self.updateButton( .right,
      utl.ray.isMouseButtonDown(     utl.ray.MouseButton.right ),
      utl.ray.isMouseButtonPressed(  utl.ray.MouseButton.right ),
      utl.ray.isMouseButtonReleased( utl.ray.MouseButton.right ),
      deltaTime
    );

    self.updateButton( .middle,
      utl.ray.isMouseButtonDown(     utl.ray.MouseButton.middle ),
      utl.ray.isMouseButtonPressed(  utl.ray.MouseButton.middle ),
      utl.ray.isMouseButtonReleased( utl.ray.MouseButton.middle ),
      deltaTime
    );

    self.updateModifier( .shift,
      utl.ray.isKeyDown(     utl.ray.KeyboardKey.left_shift  ),
      utl.ray.isKeyDown(     utl.ray.KeyboardKey.right_shift ),
      utl.ray.isKeyPressed(  utl.ray.KeyboardKey.left_shift  ),
      utl.ray.isKeyPressed(  utl.ray.KeyboardKey.right_shift ),
      utl.ray.isKeyReleased( utl.ray.KeyboardKey.left_shift  ),
      utl.ray.isKeyReleased( utl.ray.KeyboardKey.right_shift ),
      deltaTime
    );

    self.updateModifier( .ctrl,
      utl.ray.isKeyDown(     utl.ray.KeyboardKey.left_control  ),
      utl.ray.isKeyDown(     utl.ray.KeyboardKey.right_control ),
      utl.ray.isKeyPressed(  utl.ray.KeyboardKey.left_control  ),
      utl.ray.isKeyPressed(  utl.ray.KeyboardKey.right_control ),
      utl.ray.isKeyReleased( utl.ray.KeyboardKey.left_control  ),
      utl.ray.isKeyReleased( utl.ray.KeyboardKey.right_control ),
      deltaTime
    );

    self.updateModifier( .alt,
      utl.ray.isKeyDown(     utl.ray.KeyboardKey.left_alt  ),
      utl.ray.isKeyDown(     utl.ray.KeyboardKey.right_alt ),
      utl.ray.isKeyPressed(  utl.ray.KeyboardKey.left_alt  ),
      utl.ray.isKeyPressed(  utl.ray.KeyboardKey.right_alt ),
      utl.ray.isKeyReleased( utl.ray.KeyboardKey.left_alt  ),
      utl.ray.isKeyReleased( utl.ray.KeyboardKey.right_alt ),
      deltaTime
    );

    self.updateModifier( .super,
      utl.ray.isKeyDown(     utl.ray.KeyboardKey.left_super  ),
      utl.ray.isKeyDown(     utl.ray.KeyboardKey.right_super ),
      utl.ray.isKeyPressed(  utl.ray.KeyboardKey.left_super  ),
      utl.ray.isKeyPressed(  utl.ray.KeyboardKey.right_super ),
      utl.ray.isKeyReleased( utl.ray.KeyboardKey.left_super  ),
      utl.ray.isKeyReleased( utl.ray.KeyboardKey.right_super ),
      deltaTime
    );

    // UI routing should overwrite targets through `setUiHoverTarget()` after
    // hit testing. Raw raylib sampling has no panel context.
    self.updateHoverTime( deltaTime );
  }

  pub inline fn updateButton( self : *Mouse, button : MouseButton, buttonDown : bool, pressed : bool, released : bool, deltaTime : Duration ) void
  {
    self.buttons[ button.toIndex() ].update( buttonDown, pressed, released, self.screenMove, deltaTime );
  }

  pub inline fn updateModifier( self : *Mouse, modifier : MouseModifier, leftDown : bool, rightDown : bool, leftPressed : bool, rightPressed : bool, leftReleased : bool, rightReleased : bool, deltaTime : Duration ) void
  {
    self.modifiers[ modifier.toIndex() ].update( leftDown, rightDown, leftPressed, rightPressed, leftReleased, rightReleased, deltaTime );
  }

  pub inline fn hasWorldPos( self : *const Mouse ) bool { return( self.worldPos != null ); }

  /// UI hit testing should call this after it finds the current topmost targets.
  pub fn setUiHoverTarget( self : *Mouse, panel : MouseUiTarget, widget : MouseUiTarget, deltaTime : Duration ) void
  {
    self.prevTopPanel  = self.topPanel;
    self.prevTopWidget = self.topWidget;

    self.topPanel  = panel;
    self.topWidget = widget;

    self.updateHoverTime( deltaTime );
  }

  fn updateHoverTime( self : *Mouse, deltaTime : Duration ) void
  {
    if( !self.topPanel.isEq( self.prevTopPanel ) or !self.topWidget.isEq( self.prevTopWidget ))
    {
      self.hoverTime = .{};
      return;
    }

    if( !self.topPanel.isValid() and !self.topWidget.isValid() )
    {
      self.hoverTime = .{};
      return;
    }

    self.hoverTime = addDuration( self.hoverTime, deltaTime );
  }

  pub inline fn setPressedWidget( self : *Mouse, button : MouseButton, widget : MouseUiTarget ) void
  {
    self.buttons[ button.toIndex() ].pressedWidget = widget;
  }


  // ================================ ACCESSORS ================================

  pub inline fn getButton( self : *const Mouse, button : MouseButton ) MouseButtonState
  {
    return self.buttons[ button.toIndex() ];
  }

  pub inline fn getModifier( self : *const Mouse, modifier : MouseModifier ) MouseModifierState
  {
    return self.modifiers[ modifier.toIndex() ];
  }

  pub inline fn isDown( self : *const Mouse, button : MouseButton ) bool
  {
    return self.buttons[ button.toIndex() ].isDown;
  }

  pub inline fn isPressed( self : *const Mouse, button : MouseButton ) bool
  {
    return self.buttons[ button.toIndex() ].pressedThisFrame;
  }

  pub inline fn isReleased( self : *const Mouse, button : MouseButton ) bool
  {
    return self.buttons[ button.toIndex() ].releasedThisFrame;
  }

  pub inline fn getHeldTime( self : *const Mouse, button : MouseButton ) Duration
  {
    return self.buttons[ button.toIndex() ].heldTime;
  }

  pub inline fn isModDown( self : *const Mouse, modifier : MouseModifier ) bool
  {
    return self.modifiers[ modifier.toIndex() ].isDown;
  }

  pub inline fn isModPressed( self : *const Mouse, modifier : MouseModifier ) bool
  {
    return self.modifiers[ modifier.toIndex() ].pressedThisFrame;
  }

  pub inline fn isModReleased( self : *const Mouse, modifier : MouseModifier ) bool
  {
    return self.modifiers[ modifier.toIndex() ].releasedThisFrame;
  }
};
