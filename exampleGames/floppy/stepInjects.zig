const std      = @import( "std" );
const def      = @import( "defs" );
const stateInj = @import( "stateInjects.zig" );

// ================================ HELPER FUNCTIONS ================================


// ================================ GLOBAL GAME VARIABLES ================================

const GRAVITY    : f32 = 2000.0;  // Base gravity of the disk
const JUMP_FORCE : f32 = 60000.0; // Force applied when the disk jumps
const MAX_VEL_Y  : f32 = 2000.0;  // Maximum vertical velocity of the disk

//var SCROLL_SPEED : f32 = 100.0; // Base speed of the pillars
var SCORE        : u8  = 0;     // Score of the player

var IS_GAME_OVER  : bool = false; // Flag to check if the game is over ( hit bottom of screen or pillar )
var IS_JUMPING    : bool = false; // Flag to check if the disk is jumping


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

      const mobileStore : *stateInj.MobileStore = @ptrCast( @alignCast( ng.getComponentStorePtr( "mobileStore" )));

      var disk = mobileStore.get( stateInj.DISK_ID ) orelse
      {
        def.log( .WARN, 0, @src(), "Failed to find mobile component for Entity {}", .{ stateInj.DISK_ID });
        return;
      };

      disk.pos.y = 0;
      disk.vel.y = -MAX_VEL_Y;

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
  const mobileStore : *stateInj.MobileStore = @ptrCast( @alignCast( ng.getComponentStorePtr( "mobileStore" )));

  var disk = mobileStore.get( stateInj.DISK_ID ) orelse
  {
    def.log( .ERROR, 0, @src(), "Failed to find mobile component for entity with id {}", .{ stateInj.DISK_ID });
    return;
  };

  disk.vel.y = def.clmp( disk.vel.y, -MAX_VEL_Y, MAX_VEL_Y );

  if( IS_JUMPING ) // Apply jump force
  {
    disk.acc.y = -JUMP_FORCE;

    if( disk.vel.y > 0 ){ disk.vel.y = 0; }

    IS_JUMPING = false;

    // NOTE : DEBUG SCORE ( 1 POINT PER JUMP )
    SCORE += 1;
  }
  else { disk.acc.y = GRAVITY; } // Apply gravity


  // ================ APPLYING ACC AND VEL ================

  const sdt = ng.getScaledTargetTickDelta();

  const halfScaledAcc = disk.acc.mulVal( 0.5 * sdt );

  disk.vel = disk.vel.add( halfScaledAcc );
  disk.pos = disk.pos.add( disk.vel.mulVal( sdt ).toVecA( .{} ));
  disk.vel = disk.vel.add( halfScaledAcc );


  // ================ CLAMPING THE DISK POSITIONS ================

  const hHeight : f32 = def.getHalfScreenHeight();

  if( disk.pos.y < -hHeight + disk.scale.y )
  {
    disk.pos.y = -hHeight + disk.scale.y;
    disk.vel.y = 0;
  }

  if( disk.pos.y > hHeight - disk.scale.y )
  {
    def.log( .DEBUG, 0, @src(), "Disk {d} has fallen off the screen", .{ stateInj.DISK_ID });
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
  const mobileStore : *stateInj.MobileStore = @ptrCast( @alignCast( ng.getComponentStorePtr( "mobileStore" )));

  const disk = mobileStore.get( stateInj.DISK_ID ) orelse
  {
    def.log( .ERROR, 0, @src(), "Failed to find mobile component for entity with id {}", .{ stateInj.DISK_ID });
    return;
  };

  def.drawRect( disk.pos.toVec2(), disk.scale, disk.pos.a, disk.col );
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