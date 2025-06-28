const std = @import( "std" );
const h   = @import( "../headers.zig" );
const eng = @import( "../core/engine.zig" );
const ntt = @import( "../core/entity.zig" );

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

var   P1_MV_FAC  : f32 = 0.0; // Player 1 movement direction
var   P2_MV_FAC  : f32 = 0.0; // Player 2 movement direction
const MV_FAC_CAP : f32 = 16.0; // Movement factor cap, to prevent excessive speed

fn min(a: f32, b: f32) f32 { return if ( a < b ) a else b; }
fn max(a: f32, b: f32) f32 { return if ( a > b ) a else b; }

pub fn OnUpdate( ng : *eng.engine ) void // Called by engine.update() ( every frame, no exception )
{
  // Toggle pause if the P key is pressed
  if( h.rl.isKeyPressed( h.rl.KeyboardKey.p )){ ng.togglePause(); }

  if( ng.state == .PLAYING )
  {
    // Move entity 1 with A and D keys
    if( h.rl.isKeyDown( h.rl.KeyboardKey.d     )){ P1_MV_FAC = min( P1_MV_FAC + 1,  MV_FAC_CAP ); }
    if( h.rl.isKeyDown( h.rl.KeyboardKey.a     )){ P1_MV_FAC = max( P1_MV_FAC - 1, -MV_FAC_CAP ); }
    if( h.rl.isKeyDown( h.rl.KeyboardKey.w     )){ P1_MV_FAC = 0; }
    if( h.rl.isKeyDown( h.rl.KeyboardKey.space )){ P1_MV_FAC = 0; }


    // Move entity 2 with side arrow keys
    if( h.rl.isKeyDown( h.rl.KeyboardKey.right )){ P2_MV_FAC = min( P2_MV_FAC + 1,  MV_FAC_CAP ); }
    if( h.rl.isKeyDown( h.rl.KeyboardKey.left  )){ P2_MV_FAC = max( P2_MV_FAC - 1, -MV_FAC_CAP ); }
    if( h.rl.isKeyDown( h.rl.KeyboardKey.up    )){ P2_MV_FAC = 0; }
    if( h.rl.isKeyDown( h.rl.KeyboardKey.enter )){ P2_MV_FAC = 0; }
  }
}

pub fn OnTick( ng : *eng.engine, scaledDeltaTime : f32 ) void // Called by engine.tick() ( every frame, when not paused )
{
  _ = scaledDeltaTime; // Prevent unused variable warning

  const sWidth  : f32 = @floatFromInt( h.rl.getScreenWidth() );
  const sHeight : f32 = @floatFromInt( h.rl.getScreenHeight() );

  const halfWidth  : f32 = sWidth  / 2.0;
  const halfHeight : f32 = sHeight / 2.0;

  const barHalfWidth : f32 = 16.0;  // Half the width of the separator bar
  const playerSpeed  : f32 = 64.0; // Speed of the players

  const wallBounceFactor   : f32 = 0.90;  // Bounce factor for the ball when hitting walls
  const playerBounceFactor : f32 = 1.03;  // Bounce factor for the ball when hitting players


  // ================ CLAMPING THE PLAYER POSITIONS ================

  if( ng.entityManager.getEntity( 1 ))| p1 |
  {
    // Move player 1 based on the movement direction
    p1.vel.x = P1_MV_FAC * playerSpeed;

    // Clamp p1's position
    if( p1.getLeftSide() <= -halfWidth )
    {
      p1.setLeftSide( -halfWidth );
      if( p1.vel.x < 0 )
      {
        p1.vel.x  = 0; // Stop moving left if it hits the left edge
        P1_MV_FAC = 0; // Reset movement direction
      }
    }
    if( p1.getRightSide() >= -barHalfWidth )
    {
      p1.setRightSide( -barHalfWidth );
      if( p1.vel.x > 0 )
      {
        p1.vel.x  = 0; // Stop moving right if it hits the center barrier
        P1_MV_FAC = 0; // Reset movement direction
      }
    }
  }
  else { h.qlog( .WARN, 0, @src(), "Entity with ID 1 not found" ); }

  if( ng.entityManager.getEntity( 2 ))| p2 |
  {
    // Move player 2 based on the movement direction
    p2.vel.x = P2_MV_FAC * playerSpeed;

    // Clamp p2's position
    if( p2.getLeftSide() <= barHalfWidth )
    {
      p2.setLeftSide( barHalfWidth );
      if( p2.vel.x < 0 )
      {
        p2.vel.x = 0; // Stop moving left if it hits the center barrier
        P2_MV_FAC = 0; // Reset movement direction
      }
    }
    if( p2.getRightSide() >= halfWidth )
    {
      p2.setRightSide( halfWidth );
      if( p2.vel.x > 0 )
      {
        p2.vel.x = 0; // Stop moving right if it hits the right edge
        P2_MV_FAC = 0; // Reset movement direction
      }
    }
  }
  else { h.qlog( .WARN, 0, @src(), "Entity with ID 2 not found" ); }


  // ================ UPDATING THE BALL POSITION ================

  if( ng.entityManager.getEntity( 4 ))| ball |
  {
    ball.acc.y = 512.0; // Accelerate the ball downwards

    // Clamping to top and bottom of the screen
    if( ball.getBottomSide() >= halfHeight ) // Respawn the ball if it goes below the bottom of the screen
    {
      h.qlog( .DEBUG, 0, @src(), "Ball hit the bottom edge" );

      // Reset the ball's position and speed
      ball.pos.x = -256;
      ball.pos.y = -halfHeight / 2;
      ball.vel.x = 0;
      ball.vel.y = 0;
    }
    else if( ball.getTopSide() <= -halfHeight ) // Bounce the ball if it goes above the top of the screen
    {
      h.qlog( .DEBUG, 0, @src(), "Ball hit the top edge" );
      ball.setTopSide( -halfHeight );

      if( ball.vel.y < 0 )
      {
        ball.vel.y *= -wallBounceFactor; // Reverse the vertical velocity and apply bounce factor to slow it down
        ball.vel.x *=  wallBounceFactor; // Apply bounce factor to horizontal velocity as well
      }
    }

    // Clamping to left and right edges of the screen
    if( ball.getRightSide() >= halfWidth ) // Bounce the ball if it goes past the right edge
    {
      h.qlog( .DEBUG, 0, @src(), "Ball hit the right edge" );
      ball.setRightSide( halfWidth );

      if( ball.vel.x > 0 )
      {
        ball.vel.x *= -wallBounceFactor; // Reverse the horizontal velocity and apply bounce factor to slow it down
        ball.vel.y *=  wallBounceFactor; // Apply bounce factor to vertical velocity as well
      }
    }
    else if( ball.getLeftSide() <= -halfWidth ) // Bounce the ball if it goes past the left edge
    {
      h.qlog( .DEBUG, 0, @src(), "Ball hit the left edge" );
      ball.setLeftSide( -halfWidth );

      if( ball.vel.x < 0 )
      {
        ball.vel.x *= -wallBounceFactor; // Reverse the horizontal velocity and apply bounce factor to slow it down
        ball.vel.y *=  wallBounceFactor; // Apply bounce factor to vertical velocity as well
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
  if( ng.state == .LAUNCHED )
  {
    // Semi-transparent black background, to gray out the game
    h.rl.drawRectangle( 0, 0, h.rl.getScreenWidth(), h.rl.getScreenHeight(), h.rl.Color.init( 0, 0, 0, 128 ));
  }
}