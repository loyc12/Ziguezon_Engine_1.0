const utl = @import( "utils" );

pub const UiInput = struct
{
  mousePos      : utl.Vec2 = .{},
  mouseDelta    : utl.Vec2 = .{},
  mouseWheel    : f64      = 0.0,

  leftPressed   : bool = false,
  leftDown      : bool = false,
  leftReleased  : bool = false,

  rightPressed  : bool = false,
  rightDown     : bool = false,
  rightReleased : bool = false,

  escapePressed : bool = false,
  enterPressed  : bool = false,
  spacePressed  : bool = false,


  /// Only reads mouse, escape, enter and space inputs
  pub fn readRaylib() UiInput
  {
    return .{
      .mousePos      = utl.getMouseScreenPos(),
      .mouseDelta    = utl.Vec2.fromRayVec2( utl.ray.getMouseDelta() ),
      .mouseWheel    = @floatCast( utl.ray.getMouseWheelMove() ),

      .leftPressed   = utl.ray.isMouseButtonPressed(  utl.ray.MouseButton.left ),
      .leftDown      = utl.ray.isMouseButtonDown(     utl.ray.MouseButton.left ),
      .leftReleased  = utl.ray.isMouseButtonReleased( utl.ray.MouseButton.left ),

      .rightPressed  = utl.ray.isMouseButtonPressed(  utl.ray.MouseButton.right ),
      .rightDown     = utl.ray.isMouseButtonDown(     utl.ray.MouseButton.right ),
      .rightReleased = utl.ray.isMouseButtonReleased( utl.ray.MouseButton.right ),

      .escapePressed = utl.ray.isKeyPressed( utl.ray.KeyboardKey.escape ),
      .enterPressed  = utl.ray.isKeyPressed( utl.ray.KeyboardKey.enter  ),
      .spacePressed  = utl.ray.isKeyPressed( utl.ray.KeyboardKey.space  ),
    };
  }
};
