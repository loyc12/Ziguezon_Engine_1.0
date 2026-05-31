const def = @import( "defs" );

pub const UiInput = struct
{
  mousePos      : def.Vec2 = .{},
  mouseDelta    : def.Vec2 = .{},
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
      .mousePos      = def.getMouseScreenPos(),
      .mouseDelta    = def.Vec2.fromRayVec2( def.ray.getMouseDelta() ),
      .mouseWheel    = @floatCast( def.ray.getMouseWheelMove() ),

      .leftPressed   = def.ray.isMouseButtonPressed(  def.ray.MouseButton.left ),
      .leftDown      = def.ray.isMouseButtonDown(     def.ray.MouseButton.left ),
      .leftReleased  = def.ray.isMouseButtonReleased( def.ray.MouseButton.left ),

      .rightPressed  = def.ray.isMouseButtonPressed(  def.ray.MouseButton.right ),
      .rightDown     = def.ray.isMouseButtonDown(     def.ray.MouseButton.right ),
      .rightReleased = def.ray.isMouseButtonReleased( def.ray.MouseButton.right ),

      .escapePressed = def.ray.isKeyPressed( def.ray.KeyboardKey.escape ),
      .enterPressed  = def.ray.isKeyPressed( def.ray.KeyboardKey.enter  ),
      .spacePressed  = def.ray.isKeyPressed( def.ray.KeyboardKey.space  ),
    };
  }
};
