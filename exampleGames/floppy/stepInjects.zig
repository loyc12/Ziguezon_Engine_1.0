const std      = @import( "std" );
const def      = @import( "defs" );
const stateInj = @import( "stateInjects.zig" );

// ================================ HELPER FUNCTIONS ================================


// ================================ GLOBAL GAME VARIABLES ================================

const GRAVITY    : f32 = 8000.0;   // Base gravity of the disk
const JUMP_FORCE : f32 = 160000.0; // Instant force applied when the disk jumps
const MAX_VEL_Y  : f32 = 2400.0;   // Maximum vertical velocity of the disk

//var SCROLL_SPEED : f32 = 100.0; // Base speed of the pillars
var SCORE        : u8  = 0;     // Score of the player

var IS_GAME_OVER  : bool = false; // Flag to check if the game is over ( hit bottom of screen or pillar )
var IS_JUMPING    : bool = false; // Flag to check if the disk is jumping



const DISK_ID        = &stateInj.DISK_ID;
const TransformStore = stateInj.TransformStore;
const ShapeStore     = stateInj.ShapeStore;


// ================================ STEP INJECTION FUNCTIONS ================================

pub fn OnUpdateInputs( ng : *def.Engine ) void
{

  // Toggle pause if the P key is pressed
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.p ) or def.ray.isKeyPressed( def.ray.KeyboardKey.enter ))
  {
    ng.togglePause();

    if( IS_GAME_OVER )
    {
      SCORE         = 0;
      IS_GAME_OVER  = false;
      IS_JUMPING    = false;

      const transformStore : *TransformStore = @ptrCast( @alignCast( ng.componentRegistry.get( "transformStore" )));

      var diskTransform = transformStore.get( DISK_ID.* ) orelse
      {
        def.log( .WARN, 0, @src(), "Failed to find Transform component for Entity {}", .{ DISK_ID.* });
        return;
      };

      diskTransform.pos = stateInj.diskStartPos;
      diskTransform.vel = stateInj.diskStartVel;
      diskTransform.acc = .{};

      def.qlog( .INFO, 0, @src(), "Game reseted" );
    }
  }

  if( ng.state == .PLAYING ) // If the game is launched, check for input
  {
    if( IS_GAME_OVER ){ ng.changeState( .OPENED ); return; }

    if( def.ray.isKeyPressed( def.ray.KeyboardKey.space ) or
        def.ray.isKeyPressed( def.ray.KeyboardKey.up ) or
        def.ray.isKeyPressed( def.ray.KeyboardKey.w ))
    {
      IS_JUMPING = true;
    }
  }
}


pub fn OnTickWorld( ng : *def.Engine ) void
{
  const transformStore : *TransformStore = @ptrCast( @alignCast( ng.componentRegistry.get( "transformStore" )));

  var diskTransform = transformStore.get( DISK_ID.* ) orelse
  {
    def.log( .WARN, 0, @src(), "Failed to find Transform component for Entity {}", .{ DISK_ID.* });
    return;
  };


  const shapeStore : *ShapeStore = @ptrCast( @alignCast( ng.componentRegistry.get( "shapeStore" )));

  var diskShape = shapeStore.get( DISK_ID.* ) orelse
  {
    def.log( .WARN, 0, @src(), "Failed to find Shape component for Entity {}", .{ DISK_ID.* });
    return;
  };


  // ================ APPLYING ACC AND VEL ================

  diskTransform.vel.y = def.clmp( diskTransform.vel.y, -MAX_VEL_Y, MAX_VEL_Y );

  if( IS_JUMPING ) // Apply jump force
  {
    diskTransform.acc.y = -JUMP_FORCE;

    if( diskTransform.vel.y > 0 ){ diskTransform.vel.y = 0; }

    IS_JUMPING = false;

    SCORE += 1; // NOTE : DEBUG SCORE ( 1 POINT PER JUMP )
  }
  else { diskTransform.acc.y = GRAVITY; } // Apply gravity


  diskTransform.updatePos( ng.getScaledTargetTickDelta() );

  diskShape.angle = diskTransform.pos.a;

  diskShape.updateHitbox( diskTransform.pos.toVec2() );


  // ================ CLAMPING THE DISK POSITIONS ================

  const hHeight : f32 = def.getHalfScreenHeight();

  if( diskShape.hitbox.getTopY() < -hHeight )
  {
    diskShape.hitbox.setTopY( -hHeight );
    diskTransform.pos.y = diskShape.hitbox.center.y;
    diskTransform.vel.y = 0;
  }

  if( diskShape.hitbox.getBottomY() > hHeight )
  {
    def.log( .DEBUG, 0, @src(), "Disk {d} has fallen off the screen", .{ DISK_ID.* });
    IS_GAME_OVER = true;
    return;
  }


  // ================ DISK-PILLAR COLLISIONS ================


  // DEBUG INFO

  //def.qlog( .DEBUG, 0, @src(), "DISK DATA" );
  //def.log(  .CONT,  0, @src(), "pos.y :{}", .{ disk.pos.y });
  //def.log(  .CONT,  0, @src(), "vel.y :{}", .{ disk.vel.y });
  //def.log(  .CONT,  0, @src(), "acc.y :{}", .{ disk.acc.y });

}

pub fn OffTickWorld( ng : *def.Engine ) void
{
  _ = ng;
}


pub fn OnRenderWorld( ng : *def.Engine ) void
{
  const shapeStore : *ShapeStore = @ptrCast( @alignCast( ng.componentRegistry.get( "shapeStore" )));

  var diskShape = shapeStore.get( DISK_ID.* ) orelse
  {
    def.log( .WARN, 0, @src(), "Failed to find Shape component for Entity {}", .{ DISK_ID.* });
    return;
  };

  diskShape.render();
}


pub fn OnRenderOverlay( ng : *def.Engine ) void
{
  // Declare the buffer to hold the formatted scores
  var s_buff : [ 6:0 ]u8 = std.mem.zeroes( [ 6:0 ]u8 );

  // Convert the score to strings
  const s_slice = std.fmt.bufPrint( &s_buff, "{d}", .{ SCORE }) catch | err |
  {
      def.log(.ERROR, 0, @src(), "Failed to format score : {}", .{err});
      return;
  };

  s_buff[ s_slice.len ] = 0;


  const halfScreenSize = def.getHalfScreenSize();

  def.drawCenteredText( &s_buff, halfScreenSize.x * 1.6, halfScreenSize.y, 128, def.Colour.yellow );


  if( ng.state == .OPENED ) // NOTE : Greys out the game when it is paused
  {
    def.coverScreenWithCol( .new( 0, 0, 0, 128 ));
  }


  if( IS_GAME_OVER ) // If the player lost, display the game over message
  {
    const game_over_msg = "Final score : ";

    def.drawCenteredText( game_over_msg ++ &s_buff, halfScreenSize.x, halfScreenSize.y - 192, 128, def.Colour.red );
    def.drawCenteredText( "Press Enter to restart", halfScreenSize.x, halfScreenSize.y,       64,  def.Colour.yellow );
    def.drawCenteredText( "Press Escape to exit",   halfScreenSize.x, halfScreenSize.y + 128, 64,  def.Colour.yellow );
  }
  else if( ng.state == .OPENED ) // If the game is paused, display the resume message
  {
    def.drawCenteredText( "Press Enter to resume",   halfScreenSize.x, halfScreenSize.y - 256, 64, def.Colour.yellow );
    def.drawCenteredText( "Press Escape to exit",    halfScreenSize.x, halfScreenSize.y - 128, 64, def.Colour.yellow );
    def.drawCenteredText( "Press W, Up or Space to", halfScreenSize.x, halfScreenSize.y + 128, 64, def.Colour.yellow );
    def.drawCenteredText( "jump during the game",    halfScreenSize.x, halfScreenSize.y + 256, 64, def.Colour.yellow );
  }
}