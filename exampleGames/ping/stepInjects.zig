const std = @import( "std" );
const h   = @import( "defs" );

pub fn cpyEntityPosViaID( ng : *h.eng.engine , dstID : u32, srcID : u32, ) void
{
  const src = ng.entityManager.getEntity( srcID ) orelse
  {
    h.log( .WARN, 0, @src(), "Entity with ID {d} not found", .{ srcID });
    return;
  };

  const dst = ng.entityManager.getEntity( dstID ) orelse
  {
    h.log( .WARN, 0, @src(), "Entity with ID {d} not found", .{ dstID });
    return;
  };

  dst.cpyEntityPos( src );
}

// ================================ GLOBAL GAME VARIABLES ================================

const BALL_ID : u32 = 16; // ID of the ball entity

var   P1_MV_FAC   : f32 = 0.0;   // Player 1 movement direction
var   P2_MV_FAC   : f32 = 0.0;   // Player 2 movement direction
const MV_FAC_STEP : f32 = 1.0;   // Movement factor step ( size of increment / decrement )
const MV_FAC_CAP  : f32 = 32.0;  // Movement factor cap, to prevent excessive speed

const B_BASE_VEL  : f32 = 500.0; // Base velocity of the ball when it is launched
const B_BASE_GRAV : f32 = 600.0; // Base gravity of the ball

const WIN_SCORE : u8 = 8;              // Score needed to win the game
var   SCORES    : [ 2 ]u8 = .{ 0, 0 }; // Scores for player 1 and player 2
var   WINNER    : u8 = 0;              // The winner of the game, 1 for player 1, 2 for player 2, 0 for no winner yet

// ================================ STEP INJECTION FUNCTIONS ================================

pub fn OnUpdateStep( ng : *h.eng.engine ) void // Called by engine.update() ( every frame, no exception )
{
  // Toggle pause if the P key is pressed
  if( h.ray.isKeyPressed( h.ray.KeyboardKey.p ) or h.ray.isKeyPressed( h.ray.KeyboardKey.enter ))
  {
    ng.togglePause();
    if( WINNER != 0 )
    {
      // Reset the scores
      SCORES = .{ 0, 0 }; // Reset scores if the game is restarted
      WINNER = 0;         // Reset winner

      // Reset the ball position and velocity
      var ball = ng.entityManager.getEntity( BALL_ID ) orelse
      {
        h.log( .WARN, 0, @src(), "Entity with ID {d} ( Ball ) not found", .{ BALL_ID });
        return;
      };

      ball.pos = .{ .x = 0, .y = 0 };
      ball.vel = .{ .x = 0, .y = 0 };

      // Reset the positions of the ball shadows
      for( 4..16 )| i |{ cpyEntityPosViaID( ng, @intCast( i ), BALL_ID ); }

      h.qlog( .INFO, 0, @src(), "Match restarted" );
    }
  }

  if( ng.state == .PLAYING )
  {
    // Move entity 1 with A and D keys
    if( h.ray.isKeyDown( h.ray.KeyboardKey.d )){ P1_MV_FAC = @min( P1_MV_FAC + MV_FAC_STEP,  MV_FAC_CAP ); }
    if( h.ray.isKeyDown( h.ray.KeyboardKey.a )){ P1_MV_FAC = @max( P1_MV_FAC - MV_FAC_STEP, -MV_FAC_CAP ); }
    if( h.ray.isKeyDown( h.ray.KeyboardKey.s ) or h.ray.isKeyDown( h.ray.KeyboardKey.space )){ P1_MV_FAC = 0; }


    // Move entity 2 with side arrow keys
    if( h.ray.isKeyDown( h.ray.KeyboardKey.right )){ P2_MV_FAC = @min( P2_MV_FAC + MV_FAC_STEP,  MV_FAC_CAP ); }
    if( h.ray.isKeyDown( h.ray.KeyboardKey.left  )){ P2_MV_FAC = @max( P2_MV_FAC - MV_FAC_STEP, -MV_FAC_CAP ); }
    if( h.ray.isKeyDown( h.ray.KeyboardKey.down ) or h.ray.isKeyDown( h.ray.KeyboardKey.kp_enter )){ P2_MV_FAC = 0; }
  }

  if( SCORES[ 0 ] >= WIN_SCORE or SCORES[ 1 ] >= WIN_SCORE )
  {
    ng.changeState( .LAUNCHED ); // Pause the game on victory

    if( SCORES[ 0 ] >= WIN_SCORE )
    {
      WINNER = 1; // Player 1 wins
      h.log( .INFO, 0, @src(), "Player 1 wins! : {d} to {d}", .{ SCORES[ 0 ], SCORES[ 1 ] });
    }
    else if( SCORES[ 1 ] >= WIN_SCORE )
    {
      WINNER = 2; // Player 2 wins
      h.log( .INFO, 0, @src(), "Player 2 wins! : {d} to {d}", .{ SCORES[ 1 ], SCORES[ 0 ] });
    }
  }
}

pub fn OnTickStep( ng : *h.eng.engine ) void // Called by engine.tick() ( every frame, when not paused )
{
  var ball = ng.entityManager.getEntity( BALL_ID ) orelse
  {
    h.log( .WARN, 0, @src(), "Entity with ID {d} ( Ball ) not found", .{ BALL_ID });
    return;
  };

   // Set the ball's vertical acceleration to the base gravity
  ball.acc.y = B_BASE_GRAV;

  // Swaps the positions of the ball shadows repeatedly
  for( 4..15 )| i |{ cpyEntityPosViaID( ng, @intCast( i ), @intCast( i + 1 ) ); }

  var ballShadow15 = ng.entityManager.getEntity( 15 ) orelse
  {
    h.qlog( .WARN, 0, @src(), "Entity with ID 15 ( BallShadow ) not found" );
    return;
  };

  ballShadow15.cpyEntityPos( ball );
}

pub fn OffTickStep( ng : *h.eng.engine ) void // Called by engine.tick() ( every frame, when not paused )
{
  // ================ VARIABLES AND CONSTANTS ================

  const hWidth  : f32 = h.getScreenWidth()  / 2.0;
  const hHeight : f32 = h.getScreenHeight() / 2.0;

  const barHalfWidth : f32 = 16.0; // Half the width of the separator bar
  const playerSpeed  : f32 = 64.0; // Speed of the players

  const wallBounceFactor   : f32 = 0.90; // Bounce factor for the ball when hitting walls
  const playerBounceFactor : f32 = 1.03; // Bounce factor for the ball when hitting players

  var p1 = ng.entityManager.getEntity( 1 ) orelse
  {
    h.qlog( .WARN, 0, @src(), "Entity with ID 1 ( P1 ) not found" );
    return;
  };

  var p2 = ng.entityManager.getEntity( 2 ) orelse
  {
    h.qlog( .WARN, 0, @src(), "Entity with ID 2 ( P2 ) not found" );
    return;
  };

  var ball = ng.entityManager.getEntity( BALL_ID ) orelse
  {
    h.log( .WARN, 0, @src(), "Entity with ID {d} ( Ball ) not found", .{ BALL_ID });
    return;
  };

  // ================ CLAMPING THE PLAYER POSITIONS ================

  p1.vel.x = P1_MV_FAC * playerSpeed;    // Set p1's velocity based on the movement direction
  p1.clampInX( -hWidth, -barHalfWidth ); // Clamp p1's position to the left side
  if( p1.vel.x == 0 ) { P1_MV_FAC = 0; } // Reset movement direction if p1's velocity was clamped

  p2.vel.x = P2_MV_FAC * playerSpeed;    // Set p2's velocity based on the movement direction
  p2.clampInX( barHalfWidth, hWidth );   // Clamp p2's position to the right side
  if( p2.vel.x == 0 ) { P2_MV_FAC = 0; } // Reset movement direction if p2's velocity was clamped


  // ================ CLAMPING THE BALL POSITION ================

  // Clamping to top and bottom of the screen
  if( ball.pos.y >= hHeight ) // Scoring a point if the ball goes below the bottom of the screen
  {
    h.qlog( .DEBUG, 0, @src(), "Ball hit the bottom edge" );
    ball.vel.y = -B_BASE_VEL; // Reset ball vertical velocity to the base velocity
    ball.pos.y =  0.0; // Reset ball height to the middle of the screen

    if( ball.pos.x < 0 ) // Player 2 scores a point
    {
      h.log( .INFO, 0, @src(), "Player 2 scores a point! : {d}:{d}", .{ SCORES[ 0 ], SCORES[ 1 ] });
      SCORES[ 1 ] += 1;

      // Set the ball to be thrown towards player 1
      ball.vel.x = -B_BASE_VEL;
      ball.pos.x =  hWidth / 2; // Set the ball horizontal position to the middle of player 2's field
    }
    else if( ball.pos.x > 0 ) // Player 1 scores a point
    {
      h.log( .INFO, 0, @src(), "Player 1 scores a point! : {d}:{d}", .{ SCORES[ 0 ], SCORES[ 1 ] });
      SCORES[ 0 ] += 1;

      // Set the ball to be thrown towards player 2
      ball.vel.x =  B_BASE_VEL;
      ball.pos.x = -hWidth / 2; // Reset ball horizontal position to the middle of player 1's field
    }
    else // If the ball is in the middle of the screen, reset its horizontal position
    {
      h.qlog( .WARN, 0, @src(), "No player scored, throwing ball to Player 1" );
      ball.vel.x = -B_BASE_VEL; // Set the ball horizontal velocity to the base velocity
      ball.pos.x =  hWidth / 2; // Reset ball horizontal position to the middle of player 1's field
    }
  }
  else if( ball.getTopY() <= -hHeight ) // Bounce the ball if it goes above the top of the screen
  {
    h.qlog( .DEBUG, 0, @src(), "Ball hit the top edge" );
    ball.setTopY( -hHeight );

    if( ball.vel.y < 0 )
    {
      ball.vel.y *= -wallBounceFactor;
      ball.vel.x *=  wallBounceFactor;
    }
  }

  // Clamping to left and right edges of the screen
  if( ball.getRightX() >= hWidth ) // Bounce the ball if it goes past the right edge
  {
    h.qlog( .DEBUG, 0, @src(), "Ball hit the right edge" );
    ball.setRightX( hWidth );

    if( ball.vel.x > 0 )
    {
      ball.vel.x *= -wallBounceFactor;
      ball.vel.y *=  wallBounceFactor;
    }
  }
  else if( ball.getLeftX() <= -hWidth ) // Bounce the ball if it goes past the left edge
  {
    h.qlog( .DEBUG, 0, @src(), "Ball hit the left edge" );
    ball.setLeftX( -hWidth );

    if( ball.vel.x < 0 )
    {
      ball.vel.x *= -wallBounceFactor;
      ball.vel.y *=  wallBounceFactor;
    }
  }

  // ================ BALL-PLAYER COLLISIONS ================

  // Check if the ball is overlapping with player 1
  if( ball.isOverlapping( p1 ))
  {
    h.qlog( .DEBUG, 0, @src(), "Ball collided with player 1" );

    ball.setBottomY( p1.getTopY() );

    // Dividing by bounceFactor to accelerate the ball after each player bounce
    if( ball.vel.y > 0 ){ ball.vel.y = -ball.vel.y * playerBounceFactor; }

    // Add player 1's velocity to the ball's velocity
    ball.vel.x += p1.vel.x * wallBounceFactor;
  }

  // Check if the ball is overlapping with player 2
  if( ball.isOverlapping( p2 ))
  {
    h.qlog( .DEBUG, 0, @src(), "Ball collided with player 2" );

    ball.setBottomY( p2.getTopY() );

    // Dividing by bounceFactor to accelerate the ball after each player bounce
    if( ball.vel.y > 0 ){ ball.vel.y = -ball.vel.y * playerBounceFactor; }

    // Add player 2's velocity to the ball's velocity
    ball.vel.x += p2.vel.x * wallBounceFactor;
  }

}


pub fn OnRenderOverlay( ng : *h.eng.engine ) void // Called by engine.render()
{
  // Declare the buffers to hold the formatted scores
  var s1_buff : [ 4:0 ]u8 = .{ 0, 0, 0, 0 }; // Buffer for player 1's score
  var s2_buff : [ 4:0 ]u8 = .{ 0, 0, 0, 0 }; // Buffer for player 2's score

  // Convert the scores to strings
  const s1_slice = std.fmt.bufPrint(&s1_buff, "{d}", .{ SCORES[ 0 ]}) catch | err |
  {
      h.log(.ERROR, 0, @src(), "Failed to format score for player 1: {}", .{err});
      return;
  };
  const s2_slice  = std.fmt.bufPrint(&s2_buff, "{d}", .{ SCORES[ 1 ]}) catch | err |
  {
      h.log(.ERROR, 0, @src(), "Failed to format score for player 2: {}", .{ err });
      return;
  };

  // Null terminate the strings
  s1_buff[ s1_slice.len ] = 0;
  s2_buff[ s2_slice.len ] = 0;
  h.log( .DEBUG, 0, @src(), "Player 1 score: {s}\nPlayer 2 score: {s}", .{ s1_slice, s2_slice });

  // Draw each player's score in the middle of their respective fields
  h.drawCenteredText( &s1_buff, h.getScreenWidth() * 0.25, h.getScreenHeight() * 0.5, 64, h.ray.Color.blue );
  h.drawCenteredText( &s2_buff, h.getScreenWidth() * 0.75, h.getScreenHeight() * 0.5, 64, h.ray.Color.red );

  if( ng.state == .LAUNCHED ) // NOTE : Gray out the game when it is paused
  {
    h.ray.drawRectangle( 0, 0, h.ray.getScreenWidth(), h.ray.getScreenHeight(), h.ray.Color.init( 0, 0, 0, 128 ));
  }

  if( WINNER != 0 ) // If there is a winner, display the winner message ( not grayed out )
  {
    const winner_msg = if( WINNER == 1 ) "Player 1 wins!" else "Player 2 wins!";
    h.drawCenteredText( winner_msg,               h.getScreenWidth() * 0.5, ( h.getScreenHeight() * 0.5 ) - 192, 128, h.ray.Color.green );
    h.drawCenteredText( "Press Enter to restart", h.getScreenWidth() * 0.5, ( h.getScreenHeight() * 0.5 ),       64,  h.ray.Color.yellow );
    h.drawCenteredText( "Press Escape to exit",   h.getScreenWidth() * 0.5, ( h.getScreenHeight() * 0.5 ) + 128, 64,  h.ray.Color.yellow );
  }
  else if( ng.state == .LAUNCHED ) // If the game is paused, display the resume message
  {
    h.drawCenteredText( "Press Enter to resume", h.getScreenWidth() * 0.5, ( h.getScreenHeight() * 0.5 ) - 256, 64, h.ray.Color.yellow );
  }

}