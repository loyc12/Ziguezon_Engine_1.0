const std      = @import( "std" );
const def      = @import( "defs" );
const stateInj = @import( "stateInjects.zig" );

// ================================ HELPER FUNCTIONS ================================

pub fn cpyEntityPosViaID( ng : *def.eng.engine , dstID : u32, srcID : u32, ) void
{
  const src = ng.entityManager.getEntity( srcID ) orelse
  {
    def.log( .WARN, 0, @src(), "Entity with ID {d} not found", .{ srcID });
    return;
  };

  const dst = ng.entityManager.getEntity( dstID ) orelse
  {
    def.log( .WARN, 0, @src(), "Entity with ID {d} not found", .{ dstID });
    return;
  };

  dst.cpyEntityPos( src );
}

pub fn emitParticles( ng : *def.eng.engine, pos : def.vec2, dPos : def.vec2, vel : def.vec2, dVel : def.vec2, count : u32, colour : def.ray.Color ) void
{
  // Emit particles at the given position with the given colour
  for( 0 .. count )| i |
  {
    _ = i; // Prevent unused variable warning\

    const particle = ng.entityManager.createDefaultEntity();
    if( particle == null )
    {
      def.qlog( .WARN, 0, @src(), "Failed to create particle entity" );
      return;
    }

    var tmp : *def.ntt.entity = particle.?;

    tmp.pos = ng.rng.getVec2Scaled( dPos, pos ); // Set the particle position
    tmp.vel = ng.rng.getVec2Scaled( dVel, vel ); // Set the particle velocity
    tmp.colour = colour; // Set the particle colour
    tmp.scale = .{ .x = 4, .y = 4 }; // Set the particle size
  }
}

pub fn emitParticlesOnBounce( ng : *def.eng.engine, ball : *def.ntt.entity ) void
{
  // Emit particles at the ball's position relative to the ball's post-bounce velocity
  emitParticles( ng, ball.getCenter(), .{ .x = 4, .y = 4 }, .{ .x = @divTrunc( ball.vel.x, 3 ), .y = @divTrunc( ball.vel.y, 3 )}, .{ .x = 128, .y = 32 }, 8, def.ray.Color.yellow );
}

// ================================ GLOBAL GAME VARIABLES ================================

var   P1_MV_FAC   : f32 = 0.0;   // Player 1 movement direction
var   P2_MV_FAC   : f32 = 0.0;   // Player 2 movement direction
const MV_FAC_STEP : f32 = 0.5;   // Movement factor step ( size of increment / decrement )
const MV_FAC_CAP  : f32 = 16.0;  // Movement factor cap, to prevent excessive speed

const B_BASE_VEL  : f32 = 500.0; // Base velocity of the ball when it is launched
const B_BASE_GRAV : f32 = 600.0; // Base gravity of the ball

const WIN_SCORE : u8 = 8;              // Score needed to win the game
var   SCORES    : [ 2 ]u8 = .{ 0, 0 }; // Scores for player 1 and player 2
var   WINNER    : u8 = 0;              // The winner of the game, 1 for player 1, 2 for player 2, 0 for no winner yet

// ================================ STEP INJECTION FUNCTIONS ================================

pub fn OnUpdateStep( ng : *def.eng.engine ) void // Called by engine.update() ( every frame, no exception )
{
  // Toggle pause if the P key is pressed
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.p ) or def.ray.isKeyPressed( def.ray.KeyboardKey.enter ))
  {
    ng.togglePause();

    if( WINNER != 0 )
    {
      // Reset the scores
      SCORES = .{ 0, 0 }; // Reset scores if the game is restarted
      WINNER = 0;         // Reset winner

      // Reset the ball position and velocity
      var ball = ng.entityManager.getEntity( stateInj.BALL_ID ) orelse
      {
        def.log( .WARN, 0, @src(), "Entity with ID {d} ( Ball ) not found", .{ stateInj.BALL_ID });
        return;
      };

      ball.pos = .{ .x = 0, .y = 0 };
      ball.vel = .{ .x = 0, .y = 0 };

      // Reset the positions of the ball shadows
      for( stateInj.SHADOW_RANGE_START .. 1 + stateInj.SHADOW_RANGE_END )| i |{ cpyEntityPosViaID( ng, @intCast( i ), stateInj.BALL_ID ); }

      def.qlog( .INFO, 0, @src(), "Match reseted" );
    }
  }

  if( ng.state == .PLAYING )
  {
    // Move entity 1 with A and D keys
    if( def.ray.isKeyDown( def.ray.KeyboardKey.d )){ P1_MV_FAC = @min( P1_MV_FAC + MV_FAC_STEP,  MV_FAC_CAP ); }
    if( def.ray.isKeyDown( def.ray.KeyboardKey.a )){ P1_MV_FAC = @max( P1_MV_FAC - MV_FAC_STEP, -MV_FAC_CAP ); }
    if( def.ray.isKeyDown( def.ray.KeyboardKey.s ) or def.ray.isKeyDown( def.ray.KeyboardKey.space )){ P1_MV_FAC = 0; }


    // Move entity 2 with side arrow keys
    if( def.ray.isKeyDown( def.ray.KeyboardKey.right )){ P2_MV_FAC = @min( P2_MV_FAC + MV_FAC_STEP,  MV_FAC_CAP ); }
    if( def.ray.isKeyDown( def.ray.KeyboardKey.left  )){ P2_MV_FAC = @max( P2_MV_FAC - MV_FAC_STEP, -MV_FAC_CAP ); }
    if( def.ray.isKeyDown( def.ray.KeyboardKey.down ) or def.ray.isKeyDown( def.ray.KeyboardKey.kp_enter )){ P2_MV_FAC = 0; }
  }

  if( SCORES[ 0 ] >= WIN_SCORE or SCORES[ 1 ] >= WIN_SCORE )
  {
    ng.changeState( .LAUNCHED ); // Pause the game on victory

    if( SCORES[ 0 ] >= WIN_SCORE )
    {
      WINNER = 1; // Player 1 wins
      def.log( .INFO, 0, @src(), "Player 1 wins! : {d} to {d}", .{ SCORES[ 0 ], SCORES[ 1 ] });
    }
    else if( SCORES[ 1 ] >= WIN_SCORE )
    {
      WINNER = 2; // Player 2 wins
      def.log( .INFO, 0, @src(), "Player 2 wins! : {d} to {d}", .{ SCORES[ 1 ], SCORES[ 0 ] });
    }
  }
}

pub fn OnTickStep( ng : *def.eng.engine ) void // Called by engine.tick() ( every frame, when not paused )
{
  var ball = ng.entityManager.getEntity( stateInj.BALL_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Entity with ID {d} ( Ball ) not found", .{ stateInj.BALL_ID });
    return;
  };

  ball.acc.y = B_BASE_GRAV;

  // Swaps the positions of the ball shadows repeatedly
  for( stateInj.SHADOW_RANGE_START .. 0 + stateInj.SHADOW_RANGE_END )| i |{ cpyEntityPosViaID( ng, @intCast( i ), @intCast( i + 1 ) ); }

  cpyEntityPosViaID( ng, @intCast( stateInj.SHADOW_RANGE_END ), @intCast( stateInj.BALL_ID ));

  if( ng.entityManager.getMaxID() == stateInj.BALL_ID ){ return; } // If the ball is the last entity, no particles exist, so we can skip the rest of the function

  for( stateInj.BALL_ID + 1 .. 1 + ng.entityManager.getMaxID() )| i |
  {
    const part = ng.entityManager.getEntity( @intCast( i )) orelse
    {
      def.log( .WARN, 0, @src(), "Entity with ID {d} not found", .{ i });
      continue;
    };

    if( part.active == false ){ continue; } // Skip inactive entities

    if( part.getTopY() >= def.getScreenHeight() / 2 )
    {
      // If the particle is above the top of the screen, set it to inactive
      part.active = false;
      continue;
    }

    part.acc.y = B_BASE_GRAV; // Apply gravity to all remaining particles
  }
}

pub fn OffTickStep( ng : *def.eng.engine ) void // Called by engine.tick() ( every frame, when not paused )
{
  // ================ VARIABLES AND CONSTANTS ================

  const hWidth  : f32 = def.getScreenWidth()  / 2.0;
  const hHeight : f32 = def.getScreenHeight() / 2.0;

  const barHalfWidth : f32 = 16.0; // Half the width of the separator bar
  const playerSpeed  : f32 = 64.0; // Speed of the players

  const wallBounceFactor   : f32 = 0.90; // Bounce factor for the ball when hitting walls
  const playerBounceFactor : f32 = 1.03; // Bounce factor for the ball when hitting players

  var p1 = ng.entityManager.getEntity( stateInj.P1_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Entity with ID {d} ( P1 ) not found", .{ stateInj.P1_ID } );
    return;
  };

  var p2 = ng.entityManager.getEntity( stateInj.P2_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Entity with ID {d} ( P2 ) not found", .{ stateInj.P2_ID } );
    return;
  };

  var ball = ng.entityManager.getEntity( stateInj.BALL_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Entity with ID {d} ( Ball ) not found", .{ stateInj.BALL_ID });
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
    def.qlog( .DEBUG, 0, @src(), "Ball hit the bottom edge" );
    ball.vel.y = -B_BASE_VEL; // Reset ball vertical velocity to the base velocity
    ball.pos.y =  0.0; // Reset ball height to the middle of the screen

    if( ball.pos.x < 0 ) // Player 2 scores a point
    {
      def.log( .INFO, 0, @src(), "Player 2 scores a point! : {d}:{d}", .{ SCORES[ 0 ], SCORES[ 1 ] });
      SCORES[ 1 ] += 1;

      // Set the ball to be thrown towards player 1
      ball.vel.x = -B_BASE_VEL;
      ball.pos.x =  hWidth / 2; // Set the ball horizontal position to the middle of player 2's field
    }
    else if( ball.pos.x > 0 ) // Player 1 scores a point
    {
      def.log( .INFO, 0, @src(), "Player 1 scores a point! : {d}:{d}", .{ SCORES[ 0 ], SCORES[ 1 ] });
      SCORES[ 0 ] += 1;

      // Set the ball to be thrown towards player 2
      ball.vel.x =  B_BASE_VEL;
      ball.pos.x = -hWidth / 2; // Reset ball horizontal position to the middle of player 1's field
    }
    else // If the ball is in the middle of the screen, reset its horizontal position
    {
      def.qlog( .WARN, 0, @src(), "No player scored, throwing ball to Player 1" );
      ball.vel.x = -B_BASE_VEL; // Set the ball horizontal velocity to the base velocity
      ball.pos.x =  hWidth / 2; // Reset ball horizontal position to the middle of player 1's field
    }
  }
  else if( ball.getTopY() <= -hHeight ) // Bounce the ball if it goes above the top of the screen
  {
    def.qlog( .DEBUG, 0, @src(), "Ball hit the top edge" );
    ball.setTopY( -hHeight );

    if( ball.vel.y < 0 )
    {
      ball.vel.y *= -wallBounceFactor;
      ball.vel.x *=  wallBounceFactor;

      emitParticlesOnBounce( ng, ball );
    }
  }

  // Clamping to left and right edges of the screen
  if( ball.getRightX() >= hWidth ) // Bounce the ball if it goes past the right edge
  {
    def.qlog( .DEBUG, 0, @src(), "Ball hit the right edge" );
    ball.setRightX( hWidth );

    if( ball.vel.x > 0 )
    {
      ball.vel.x *= -wallBounceFactor;
      ball.vel.y *=  wallBounceFactor;

      emitParticlesOnBounce( ng, ball );
    }
  }
  else if( ball.getLeftX() <= -hWidth ) // Bounce the ball if it goes past the left edge
  {
    def.qlog( .DEBUG, 0, @src(), "Ball hit the left edge" );
    ball.setLeftX( -hWidth );

    if( ball.vel.x < 0 )
    {
      ball.vel.x *= -wallBounceFactor;
      ball.vel.y *=  wallBounceFactor;

      emitParticlesOnBounce( ng, ball );
    }
  }

  // ================ BALL-PLAYER COLLISIONS ================

  // Check if the ball is overlapping with player 1
  if( ball.isOverlapping( p1 ))
  {
    def.qlog( .DEBUG, 0, @src(), "Ball collided with player 1" );

    ball.setBottomY( p1.getTopY() );

    // Dividing by bounceFactor to accelerate the ball after each player bounce
    if( ball.vel.y > 0 ){ ball.vel.y = -ball.vel.y * playerBounceFactor; }

    ball.vel.x += p1.vel.x * wallBounceFactor;

    emitParticlesOnBounce( ng, ball );
  }

  // Check if the ball is overlapping with player 2
  if( ball.isOverlapping( p2 ))
  {
    def.qlog( .DEBUG, 0, @src(), "Ball collided with player 2" );

    ball.setBottomY( p2.getTopY() );

    // Dividing by bounceFactor to accelerate the ball after each player bounce
    if( ball.vel.y > 0 ){ ball.vel.y = -ball.vel.y * playerBounceFactor; }

    ball.vel.x += p2.vel.x * wallBounceFactor;

    emitParticlesOnBounce( ng, ball );
  }

}


pub fn OnRenderOverlay( ng : *def.eng.engine ) void // Called by engine.render()
{
  // Declare the buffers to hold the formatted scores
  var s1_buff : [ 4:0 ]u8 = .{ 0, 0, 0, 0 }; // Buffer for player 1's score
  var s2_buff : [ 4:0 ]u8 = .{ 0, 0, 0, 0 }; // Buffer for player 2's score

  // Convert the scores to strings
  const s1_slice = std.fmt.bufPrint(&s1_buff, "{d}", .{ SCORES[ 0 ]}) catch | err |
  {
      def.log(.ERROR, 0, @src(), "Failed to format score for player 1: {}", .{err});
      return;
  };
  const s2_slice  = std.fmt.bufPrint(&s2_buff, "{d}", .{ SCORES[ 1 ]}) catch | err |
  {
      def.log(.ERROR, 0, @src(), "Failed to format score for player 2: {}", .{ err });
      return;
  };

  // Null terminate the strings
  s1_buff[ s1_slice.len ] = 0;
  s2_buff[ s2_slice.len ] = 0;
  def.log( .DEBUG, 0, @src(), "Player 1 score: {s}\nPlayer 2 score: {s}", .{ s1_slice, s2_slice });

  // Draw each player's score in the middle of their respective fields
  def.drawCenteredText( &s1_buff, def.getScreenWidth() * 0.25, def.getScreenHeight() * 0.5, 64, def.ray.Color.blue );
  def.drawCenteredText( &s2_buff, def.getScreenWidth() * 0.75, def.getScreenHeight() * 0.5, 64, def.ray.Color.red );

  if( ng.state == .LAUNCHED ) // NOTE : Gray out the game when it is paused
  {
    def.ray.drawRectangle( 0, 0, def.ray.getScreenWidth(), def.ray.getScreenHeight(), def.ray.Color.init( 0, 0, 0, 128 ));
  }

  if( WINNER != 0 ) // If there is a winner, display the winner message ( not grayed out )
  {
    const winner_msg = if( WINNER == 1 ) "Player 1 wins!" else "Player 2 wins!";
    def.drawCenteredText( winner_msg,               def.getScreenWidth() * 0.5, ( def.getScreenHeight() * 0.5 ) - 192, 128, def.ray.Color.green );
    def.drawCenteredText( "Press Enter to restart", def.getScreenWidth() * 0.5, ( def.getScreenHeight() * 0.5 ),       64,  def.ray.Color.yellow );
    def.drawCenteredText( "Press Escape to exit",   def.getScreenWidth() * 0.5, ( def.getScreenHeight() * 0.5 ) + 128, 64,  def.ray.Color.yellow );
  }
  else if( ng.state == .LAUNCHED ) // If the game is paused, display the resume message
  {
    def.drawCenteredText( "Press Enter to resume", def.getScreenWidth() * 0.5, ( def.getScreenHeight() * 0.5 ) - 256, 64, def.ray.Color.yellow );
  }
}