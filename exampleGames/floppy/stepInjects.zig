const std      = @import( "std" );
const def      = @import( "defs" );
const stateInj = @import( "stateInjects.zig" );

// ================================ HELPER FUNCTIONS ================================


// ================================ GLOBAL GAME VARIABLES ================================

const GRAVITY    : f32 = 1000.0;   // Base gravity of the disk
const JUMP_FORCE : f32 = 100000.0; // Force applied when the disk jumps
const MAX_VEL_Y  : f32 = 1000.0;   // Maximum vertical velocity of the disk

//var SCROLL_SPEED : f32 = 100.0; // Base speed of the pillars
var SCORE        : u8  = 0;     // Score of the player

var IS_GAME_OVER  : bool = false; // Flag to check if the game is over ( hit bottom of screen or pillar )
var IS_JUMPING    : bool = false; // Flag to check if the disk is jumping

// ================================ STEP INJECTION FUNCTIONS ================================

pub fn OnUpdateInputs( ng : *def.Engine ) void // Called by engine.updateInputs() ( every frame, no exception )
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

      var disk = ng.getEntity( stateInj.DISK_ID ) orelse
      {
        def.log( .WARN, 0, @src(), "Entity with ID {d} ( Disk ) not found", .{ stateInj.DISK_ID });
        return;
      };

      disk.pos.y = 0;
      disk.vel.y = 0;

      def.qlog( .INFO, 0, @src(), "Game reseted" );
    }
  }

  if( ng.state == .PLAYING ) // If the game is launched, check for input
  {
    if( IS_GAME_OVER ){ ng.changeState( .OPENED ); return; }

    if( def.ray.isKeyPressed( def.ray.KeyboardKey.space ) or def.ray.isKeyPressed( def.ray.KeyboardKey.up ) or def.ray.isKeyPressed( def.ray.KeyboardKey.w ))
    {
      IS_JUMPING = true;
      def.log( .DEBUG, 0, @src(), "Disk {d} jumped", .{ stateInj.DISK_ID });
    }
  }
}

pub fn OnTickEntities( ng : *def.Engine ) void // Called by engine.tickEntities() ( every frame, when not paused )
{
  var disk = ng.getEntity( stateInj.DISK_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Entity with ID {d} ( Disk ) not found", .{ stateInj.DISK_ID });
    return;
  };

  disk.vel.y = def.clmp( disk.vel.y, -MAX_VEL_Y, MAX_VEL_Y );

  if( IS_JUMPING ) // Apply jump force
  {
    disk.acc.y = -JUMP_FORCE;

    if( disk.vel.y < 0 ){ disk.vel.y = 0; }

    IS_JUMPING = false;

    // NOTE : TESTS SCORE
    SCORE += 1;
  }
  else { disk.acc.y = GRAVITY; } // Apply gravity
}

pub fn OffTickEntities( ng : *def.Engine ) void // Called by engine.tickEntities() ( every frame, when not paused )
{
  const hHeight : f32 = def.getScreenHeight() / 2.0;

  var disk = ng.getEntity( stateInj.DISK_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Entity with ID {d} ( Ball ) not found", .{ stateInj.DISK_ID });
    return;
  };

  // ================ CLAMPING THE DISK POSITIONS ================

  disk.clampTopY( -hHeight );

  if( disk.getBottomY() > hHeight )
  {
    def.log( .DEBUG, 0, @src(), "Disk {d} has fallen off the screen", .{ disk.id });
    IS_GAME_OVER = true;
    return;
  }

  // ================ DISK-PILLAR COLLISIONS ================
}

pub fn OnRenderBackground( ng : *def.Engine ) void // Called by engine.renderGraphics()
{
  _ = ng; // Prevent unused variable warning

  def.ray.clearBackground( def.Colour.green );
}

pub fn OnRenderOverlay( ng : *def.Engine ) void // Called by engine.renderGraphics()
{
  // Declare the buffer to hold the formatted scores
  var s_buff : [ 4:0 ]u8 = .{ 0, 0, 0, 0 };

  // Convert the score to strings
  const s_slice = std.fmt.bufPrint( &s_buff, "{d}", .{ SCORE }) catch | err |
  {
      def.log(.ERROR, 0, @src(), "Failed to format score : {}", .{err});
      return;
  };

  // Null terminate the string
  s_buff[ s_slice.len ] = 0;
  def.log( .DEBUG, 0, @src(), "Score: {s}", .{ s_slice });

  if( ng.state == .OPENED ) // NOTE : Greys out the game when it is paused
  {
    def.coverScreenWith( def.Colour.init( 0, 0, 0, 128 ));
  }

  // Draw each the score in the middle of the screen
  def.drawCenteredText( &s_buff, def.getScreenWidth() * 0.8, def.getScreenHeight() * 0.5, 128, def.Colour.yellow );

  if( IS_GAME_OVER ) // If there is a winner, display the winner message ( not grayed out )
  {
    const winner_msg = "Womp Womp..."; // TODO : Change message based on final score
    def.drawCenteredText( winner_msg,               def.getScreenWidth() * 0.5, ( def.getScreenHeight() * 0.5 ) - 192, 128, def.Colour.red );
    def.drawCenteredText( "Press Enter to restart", def.getScreenWidth() * 0.5, ( def.getScreenHeight() * 0.5 ),       64,  def.Colour.yellow );
    def.drawCenteredText( "Press Escape to exit",   def.getScreenWidth() * 0.5, ( def.getScreenHeight() * 0.5 ) + 128, 64,  def.Colour.yellow );
  }
  else if( ng.state == .OPENED ) // If the game is paused, display the resume message
  {
    def.drawCenteredText( "Press Enter to resume",   def.getScreenWidth() * 0.5, ( def.getScreenHeight() * 0.5 ) - 256, 64, def.Colour.yellow );
    def.drawCenteredText( "Press Escape to exit",    def.getScreenWidth() * 0.5, ( def.getScreenHeight() * 0.5 ) - 128, 64, def.Colour.yellow );
    def.drawCenteredText( "Press W, Up or Space to", def.getScreenWidth() * 0.5, ( def.getScreenHeight() * 0.5 ) + 128, 64, def.Colour.yellow );
    def.drawCenteredText( "jump during the game",    def.getScreenWidth() * 0.5, ( def.getScreenHeight() * 0.5 ) + 256, 64, def.Colour.yellow );
  }
}