const std = @import( "std" );
const h   = @import( "../headers.zig" );
const eng = @import( "../core/engine.zig" );
const ntt = @import( "../core/entity/entityCore.zig" );

pub fn OnLoopStart( ng : *eng.engine ) void // Called by engine.loopLogic()
{
  _ = ng; // Prevent unused variable warning
  return;
}

pub fn OnLoopIter( ng : *eng.engine ) void // Called by engine.loopLogic() ( every frame, no exception )
{
  _ = ng; // Prevent unused variable warning
  return;
}

pub fn OnLoopEnd( ng : *eng.engine ) void // Called by engine.loopLogic()
{
  _ = ng; // Prevent unused variable warning
  return;
}

var   P1_MV_FAC   : f32 = 0.0;   // Player 1 movement direction
var   P2_MV_FAC   : f32 = 0.0;   // Player 2 movement direction
const MV_FAC_CAP  : f32 = 16.0;  // Movement factor cap, to prevent excessive speed

const B_BASE_VEL  : f32 = 500.0; // Base velocity of the ball when it is launched
const B_BASE_GRAV : f32 = 600.0; // Base gravity of the ball

var   Scores : [ 2 ]u8 = .{ 0, 0 }; // Scores for player 1 and player 2

pub fn OnUpdate( ng : *eng.engine ) void // Called by engine.update() ( every frame, no exception )
{
  // Toggle pause if the P key is pressed
  if( h.rl.isKeyPressed( h.rl.KeyboardKey.p )){ ng.togglePause(); }

  if( ng.state == .PLAYING )
  {
    // Move entity 1 with A and D keys
    if( h.rl.isKeyDown( h.rl.KeyboardKey.d     )){ P1_MV_FAC = @min( P1_MV_FAC + 1,  MV_FAC_CAP ); }
    if( h.rl.isKeyDown( h.rl.KeyboardKey.a     )){ P1_MV_FAC = @max( P1_MV_FAC - 1, -MV_FAC_CAP ); }
    if( h.rl.isKeyDown( h.rl.KeyboardKey.w     )){ P1_MV_FAC = 0; }
    if( h.rl.isKeyDown( h.rl.KeyboardKey.space )){ P1_MV_FAC = 0; }


    // Move entity 2 with side arrow keys
    if( h.rl.isKeyDown( h.rl.KeyboardKey.right )){ P2_MV_FAC = @min( P2_MV_FAC + 1,  MV_FAC_CAP ); }
    if( h.rl.isKeyDown( h.rl.KeyboardKey.left  )){ P2_MV_FAC = @max( P2_MV_FAC - 1, -MV_FAC_CAP ); }
    if( h.rl.isKeyDown( h.rl.KeyboardKey.up    )){ P2_MV_FAC = 0; }
    if( h.rl.isKeyDown( h.rl.KeyboardKey.enter )){ P2_MV_FAC = 0; }
  }
}

pub fn OnTick( ng : *eng.engine, scaledDeltaTime : f32 ) void // Called by engine.tick() ( every frame, when not paused )
{
  _ = scaledDeltaTime; // Prevent unused variable warning

  const hWidth  : f32 = h.getScreenWidth()  / 2.0;
  const hHeight : f32 = h.getScreenHeight() / 2.0;

  const barHalfWidth : f32 = 16.0;  // Half the width of the separator bar
  const playerSpeed  : f32 = 64.0; // Speed of the players

  const wallBounceFactor   : f32 = 0.90;  // Bounce factor for the ball when hitting walls
  const playerBounceFactor : f32 = 1.03;  // Bounce factor for the ball when hitting players


  // ================ CLAMPING THE PLAYER POSITIONS ================

  if( ng.entityManager.getEntity( 1 ))| p1 |
  {
    p1.vel.x = P1_MV_FAC * playerSpeed;    // Set p1's velocity based on the movement direction
    p1.clampInX( -hWidth, -barHalfWidth ); // Clamp p1's position to the left side
    if( p1.vel.x == 0 ) { P1_MV_FAC = 0; } // Reset movement direction if p1's velocity was clamped

  }
  else { h.qlog( .WARN, 0, @src(), "Entity with ID 1 not found" ); }

  if( ng.entityManager.getEntity( 2 ))| p2 |
  {

    p2.vel.x = P2_MV_FAC * playerSpeed;    // Set p2's velocity based on the movement direction
    p2.clampInX( barHalfWidth, hWidth );   // Clamp p2's position to the right side
    if( p2.vel.x == 0 ) { P2_MV_FAC = 0; } // Reset movement direction if p2's velocity was clamped

  }
  else { h.qlog( .WARN, 0, @src(), "Entity with ID 2 not found" ); }


  // ================ UPDATING THE BALL POSITION ================

  if( ng.entityManager.getEntity( 4 ))| ball |
  {
    ball.acc.y = B_BASE_GRAV; // Set the ball's vertical acceleration to the base gravity

    // Clamping to top and bottom of the screen
    if( ball.getBottomSide() >= hHeight ) // Scoring a point if the ball goes below the bottom of the screen
    {
      h.qlog( .DEBUG, 0, @src(), "Ball hit the bottom edge" );
      ball.vel.y = -B_BASE_VEL; // Reset ball vertical velocity to the base velocity
      ball.pos.y = 0.0; // Reset ball height to the middle of the screen

      if( ball.pos.x < 0 ) // Player 2 scores a point
      {
        h.log( .INFO, 0, @src(), "Player 2 scores a point! : {d}:{d}", .{ Scores[ 0 ], Scores[ 1 ] });
        Scores[ 1 ] += 1;

        // Set the ball to be thrown towards player 1
        ball.vel.x = -B_BASE_VEL;
        ball.pos.x = hWidth / 2; // Set the ball horizontal position to the middle of player 2's field
      }
      else if( ball.pos.x > 0 ) // Player 1 scores a point
      {
        h.log( .INFO, 0, @src(), "Player 1 scores a point! : {d}:{d}", .{ Scores[ 0 ], Scores[ 1 ] });
        Scores[ 0 ] += 1;

        // Set the ball to be thrown towards player 2
        ball.vel.x = B_BASE_VEL;
        ball.pos.x = -hWidth / 2; // Reset ball horizontal position to the middle of player 1's field
      }
      else // If the ball is in the middle of the screen, reset its horizontal position
      {
        h.qlog( .WARN, 0, @src(), "No player scored, throwing ball to Player 1" );
        ball.vel.x = -B_BASE_VEL; // Set the ball horizontal velocity to the base velocity
        ball.pos.x = hWidth / 2; // Reset ball horizontal position to the middle of player 1's field
      }
    }
    else if( ball.getTopSide() <= -hHeight ) // Bounce the ball if it goes above the top of the screen
    {
      h.qlog( .DEBUG, 0, @src(), "Ball hit the top edge" );
      ball.setTopSide( -hHeight );

      if( ball.vel.y < 0 )
      {
        ball.vel.y *= -wallBounceFactor;
        ball.vel.x *=  wallBounceFactor;
      }
    }

    // Clamping to left and right edges of the screen
    if( ball.getRightSide() >= hWidth ) // Bounce the ball if it goes past the right edge
    {
      h.qlog( .DEBUG, 0, @src(), "Ball hit the right edge" );
      ball.setRightSide( hWidth );

      if( ball.vel.x > 0 )
      {
        ball.vel.x *= -wallBounceFactor;
        ball.vel.y *=  wallBounceFactor;
      }
    }
    else if( ball.getLeftSide() <= -hWidth ) // Bounce the ball if it goes past the left edge
    {
      h.qlog( .DEBUG, 0, @src(), "Ball hit the left edge" );
      ball.setLeftSide( -hWidth );

      if( ball.vel.x < 0 )
      {
        ball.vel.x *= -wallBounceFactor;
        ball.vel.y *=  wallBounceFactor;
      }
    }

    // Colliding with player 1
    if( ng.entityManager.getEntity( 1 ))| p1 |
    {
      if( ball.getOverlap( p1 ))| over | // Check if the ball overlaps with player 1
      {
        _ = over; // Prevent unused variable warning
        h.qlog( .DEBUG, 0, @src(), "Ball collided with player 1" );

        ball.setBottomSide( p1.getTopSide() );

        // Dividing by bounceFactor to accelerate the ball after each player bounce
        if( ball.vel.y > 0 ){ ball.vel.y = -ball.vel.y * playerBounceFactor; }

        // Add player 1's velocity to the ball's velocity
        ball.vel.x += p1.vel.x * wallBounceFactor;
      }
    }
    else { h.qlog( .WARN, 0, @src(), "Entity with ID 1 not found" ); }

    // Colliding with player 2
    if( ng.entityManager.getEntity( 2 ))| p2 |
    {
      if( ball.getOverlap( p2 ))| over | // Check if the ball overlaps with player 2
      {
        _ = over; // Prevent unused variable warning
        h.qlog( .DEBUG, 0, @src(), "Ball collided with player 2" );

        ball.setBottomSide( p2.getTopSide() );

        // Dividing by bounceFactor to accelerate the ball after each player bounce
        if( ball.vel.y > 0 ){ ball.vel.y = -ball.vel.y * playerBounceFactor; }

        // Add player 2's velocity to the ball's velocity
        ball.vel.x += p2.vel.x * wallBounceFactor;
      }
    }
    else { h.qlog( .WARN, 0, @src(), "Entity with ID 2 not found" ); }
  }
  else { h.qlog( .WARN, 0, @src(), "Entity with ID 4 not found" ); }
}



pub fn OnRenderWorld( ng : *eng.engine ) void // Called by engine.render()
{
  _ = ng; // Prevent unused variable warning
  return;
}

pub fn OnRenderOverlay( ng : *eng.engine ) void // Called by engine.render()
{
  // Declare the buffers to hold the formatted scores
  var s1_buff : [ 4:0 ]u8 = .{ 0, 0, 0, 0 }; // Buffer for player 1's score
  var s2_buff : [ 4:0 ]u8 = .{ 0, 0, 0, 0 }; // Buffer for player 2's score

  // Convert the scores to strings
  const s1_slice = std.fmt.bufPrint(&s1_buff, "{d}", .{ Scores[ 0 ]}) catch |err|
  {
      h.log(.ERROR, 0, @src(), "Failed to format score for player 1: {}", .{err});
      return;
  };
  const s2_slice  = std.fmt.bufPrint(&s2_buff, "{d}", .{ Scores[ 1 ]}) catch |err|
  {
      h.log(.ERROR, 0, @src(), "Failed to format score for player 2: {}", .{err});
      return;
  };

  // Null terminate the strings
  s1_buff[ s1_slice.len ] = 0;
  s2_buff[ s2_slice.len ] = 0;
  h.log( .DEBUG, 0, @src(), "Player 1 score: {s}\nPlayer 2 score: {s}", .{ s1_slice, s2_slice });

  // Draw each player's score in the middle of their respective fields
  h.rl.drawText( &s1_buff, @divTrunc( h.rl.getScreenWidth(), 4 ),     @divTrunc( h.rl.getScreenHeight(), 2 ), 64, h.rl.Color.blue );
  h.rl.drawText( &s2_buff, @divTrunc( h.rl.getScreenWidth(), 4 ) * 3, @divTrunc( h.rl.getScreenHeight(), 2 ), 64, h.rl.Color.red );

  if( ng.state == .LAUNCHED ) // NOTE : Gray out the game when it is paused
  {
    h.rl.drawRectangle( 0, 0, h.rl.getScreenWidth(), h.rl.getScreenHeight(), h.rl.Color.init( 0, 0, 0, 128 ));
  }

}