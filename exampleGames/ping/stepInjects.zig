const std      = @import( "std" );
const def      = @import( "defs" );
const stateInj = @import( "stateInjects.zig" );

const Engine = def.Engine;
const Entity = def.Entity;
const Vec2   = def.Vec2;
const VecR   = def.VecR;

// ================================ HELPER FUNCTIONS ================================

pub fn cpyEntityPosViaID( ng : *Engine , dstID : u32, srcID : u32, ) void
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

// Emit particles in a given position and velocity range, with the given colour
pub fn emitParticles( ng : *Engine, pos : VecR, vel : VecR, dPos : VecR, dVel : VecR, amount : u32, colour : def.Colour ) void
{
  ng.entityManager.entityList.ensureTotalCapacity( ng.entityManager.entityList.items.len + amount ) catch |err|
  {
    def.log(.ERROR, 0, @src(), "Failed to preallocate entity capacity for particles: {}", .{ err });
    return;
  };

  for( 0 .. amount )| i |
  {
    _ = i; // Ignore the index, we don't need it

    const size = def.G_RNG.getScaledFloat( 2.0, 7.0 );

    _ = ng.entityManager.addEntity( // NOTE : We do not care if this fails, as we are just emitting particles
    .{
      .pos    = def.G_RNG.getScaledVecR( dPos, pos ),
      .vel    = def.G_RNG.getScaledVecR( dVel, vel ),
      .scale  = def.newVec2( size, size ),

      .shape  = def.G_RNG.getVal( def.ntt.e_ntt_shape ),
      .colour = colour,
    });
  }
}

pub fn emitParticlesOnBounce( ng : *Engine, ball : *Entity ) void
{
  // Emit particles at the ball's position relative to the ball's post-bounce velocity

  emitParticles( ng,
    ball.pos, // NOTE : Had to set .use_llvm to false to avoid PRO issues with this line
    .{ .x = @divTrunc( ball.vel.x, 3 ), .y = @divTrunc( ball.vel.y, 3 ), .z = 0.0 },
    .{ .x = 16,  .y = 16, .z = 1.0 },
    .{ .x = 128, .y = 32, .z = 2.0 },
    12, def.Colour.yellow );

  ng.resourceManager.playAudio( "hit_1" );
}


// ================================ GLOBAL GAME VARIABLES ================================

var   P1_MV_FAC : f32 = 0.0; // Player 1 movement direction
var   P2_MV_FAC : f32 = 0.0; // Player 2 movement direction

const MV_FAC_STEP : f32 = 0.4;  // Movement factor step ( size of increment / decrement )
const MV_FAC_CAP  : f32 = 16.0; // Movement factor cap, to prevent excessive speed

const B_BASE_VEL : f32 = 500.0; // Base velocity of the ball when it is launched
const B_GRAVITY  : f32 = 600.0; // Base gravitational acceleration of the ball

const WIN_SCORE : u8 = 5; // Score needed to win the game
var   WINNER    : u8 = 0; // The winner of the game, 1 for player 1, 2 for player 2, 0 for no winner yet

var   SCORES    : [ 2 ]u8 = .{ 0, 0 }; // Scores for player 1 and player 2

const B_MIN_BOUNCE_SPEED_X : f32 = 128.0; // Minimum parallel speed of the ball when bouncing off players
const B_MIN_BOUNCE_SPEED_Y : f32 = 256.0; // Minimum perpendicular speed of the ball when bouncing off players

const B_KIN_TRANS_FACTOR_X : f32 = 0.25; // How much of the player's velocity is given to the ball on bounce ( horizontal )
const B_KIN_TRANS_FACTOR_Y : f32 = 0.25; // How much of the player's velocity is given to the ball on bounce ( vertical )

pub fn ensureBallMinSpeeds( ball : *Entity ) void
{
  if( ball.vel.x > 0 ){ ball.vel.x = @max( ball.vel.x,  B_MIN_BOUNCE_SPEED_X ); }
  if( ball.vel.x < 0 ){ ball.vel.x = @min( ball.vel.x, -B_MIN_BOUNCE_SPEED_X ); }

  if( ball.vel.y > 0 ){ ball.vel.y = @max( ball.vel.y,  B_MIN_BOUNCE_SPEED_Y ); }
  if( ball.vel.y < 0 ){ ball.vel.y = @min( ball.vel.y, -B_MIN_BOUNCE_SPEED_Y ); }
}


// ================================ STEP INJECTION FUNCTIONS ================================

pub fn OnUpdateInputs( ng : *Engine ) void // Called by engine.updateInputs() ( every frame, no exception )
{
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.p ) or def.ray.isKeyPressed( def.ray.KeyboardKey.enter ))
  {
    ng.togglePause();

    if( WINNER != 0 )
    {
      SCORES = .{ 0, 0 }; // Reset scores if the game is restarted
      WINNER = 0;         // Reset winner

      // Reset the ball position and velocity
      var ball = ng.entityManager.getEntity( stateInj.BALL_ID ) orelse
      {
        def.log( .WARN, 0, @src(), "Entity with ID {d} ( Ball ) not found", .{ stateInj.BALL_ID });
        return;
      };

      ball.pos = def.newVecR( 0, 0, 0 );
      ball.vel = def.newVecR( 0, 0, 0 );
      ball.acc = def.newVecR( 0, 0, 0 );

      // Reset the positions of the ball shadows
      for( stateInj.SHADOW_RANGE_START .. 1 + stateInj.SHADOW_RANGE_END )| i |{ cpyEntityPosViaID( ng, @intCast( i ), stateInj.BALL_ID ); }

      def.qlog( .INFO, 0, @src(), "Match reseted" );
    }
  }

  if( ng.isPlaying() )
  {
    // Move player 1 with A and D keys
    if( def.ray.isKeyDown( def.ray.KeyboardKey.d )){ P1_MV_FAC = @min( P1_MV_FAC + MV_FAC_STEP,  MV_FAC_CAP ); }
    if( def.ray.isKeyDown( def.ray.KeyboardKey.a )){ P1_MV_FAC = @max( P1_MV_FAC - MV_FAC_STEP, -MV_FAC_CAP ); }
    if( def.ray.isKeyDown( def.ray.KeyboardKey.s ) or def.ray.isKeyDown( def.ray.KeyboardKey.space )){ P1_MV_FAC = 0; }

    // Move player 2 with side arrow keys
    if( def.ray.isKeyDown( def.ray.KeyboardKey.right )){ P2_MV_FAC = @min( P2_MV_FAC + MV_FAC_STEP,  MV_FAC_CAP ); }
    if( def.ray.isKeyDown( def.ray.KeyboardKey.left  )){ P2_MV_FAC = @max( P2_MV_FAC - MV_FAC_STEP, -MV_FAC_CAP ); }
    if( def.ray.isKeyDown( def.ray.KeyboardKey.down  ) or def.ray.isKeyDown( def.ray.KeyboardKey.kp_enter )){ P2_MV_FAC = 0; }

    // Move the camera with the numpad keys
    if( def.ray.isKeyDown( def.ray.KeyboardKey.kp_8 )){ ng.viewManager.moveBy( def.newVec2(  0, -8 )); }
    if( def.ray.isKeyDown( def.ray.KeyboardKey.kp_2 )){ ng.viewManager.moveBy( def.newVec2(  0,  8 )); }
    if( def.ray.isKeyDown( def.ray.KeyboardKey.kp_4 )){ ng.viewManager.moveBy( def.newVec2( -8,  0 )); }
    if( def.ray.isKeyDown( def.ray.KeyboardKey.kp_6 )){ ng.viewManager.moveBy( def.newVec2(  8,  0 )); }

    // Zoom in and out with the mouse wheel
    if( def.ray.getMouseWheelMove() > 0.0 ){ ng.viewManager.zoomBy( 1.111 ); }
    if( def.ray.getMouseWheelMove() < 0.0 ){ ng.viewManager.zoomBy( 0.900 ); }

    // Reset the camera zoom and position when the middle mouse button is pressed
    if( def.ray.isMouseButtonPressed( def.ray.MouseButton.middle ))
    {
      ng.viewManager.setMainCameraZoom( 1.0 );
      ng.viewManager.setMainCameraTarget( def.zeroVec2() );
      def.qlog( .INFO, 0, @src(), "Camera reseted" );
    }
  }

  if( SCORES[ 0 ] >= WIN_SCORE or SCORES[ 1 ] >= WIN_SCORE )
  {
    ng.changeState( .OPENED ); // Pause the game on victory

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

pub fn OnTickEntities( ng : *Engine ) void // Called by engine.tickEntities() ( every frame, when not paused )
{
  var ball = ng.entityManager.getEntity( stateInj.BALL_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Entity with ID {d} ( Ball ) not found", .{ stateInj.BALL_ID });
    return;
  };

  ball.acc.y = B_GRAVITY;

  // Swaps the positions of the ball shadows repeatedly
  for( stateInj.SHADOW_RANGE_START .. 0 + stateInj.SHADOW_RANGE_END )| i |{ cpyEntityPosViaID( ng, @intCast( i ), @intCast( i + 1 ) ); }

  cpyEntityPosViaID( ng, @intCast( stateInj.SHADOW_RANGE_END ), @intCast( stateInj.BALL_ID ));

  if( ng.entityManager.getMaxID() == stateInj.BALL_ID ){ return; } // If the ball is the last entity, no particles exist, so we can skip the rest of the function

  for( stateInj.BALL_ID + 1 .. 1 + ng.entityManager.getMaxID() )| i |
  {
    const part = ng.entityManager.getEntity( @intCast( i )) orelse continue;

    if( part.canBeDel() ){ continue; } // skip pre-marked particles

    // If the particle is bellow the screen, deactivate it and mark it for deletion
    if( part.getTopY() >= def.getScreenHeight() / 2 )
    {
      part.delFlag( .ACTIVE );
      part.addFlag( .DELETE );
      continue;
    }

    part.acc.y = B_GRAVITY; // Apply gravity to all remaining particles
  }
}

pub fn OffTickEntities( ng : *Engine ) void // Called by engine.tickEntities() ( every frame, when not paused )
{
  // ================ VARIABLES AND CONSTANTS ================

  const hWidth  : f32 = def.getScreenWidth()  / 2.0; // NOTE : uses the initial screen width  only
  const hHeight : f32 = def.getScreenHeight() / 2.0; // NOTE : uses the initial screen height only

  const barHalfWidth        : f32 = 8.0;  // Half the width of the separator bar
  const playerSpeedFactor   : f32 = 64.0; // Base speed of the players

  const wallBounceFactorX   : f32 = 0.85; // Perpendicular bounce factor for the ball when hitting walls
  const wallBounceFactorY   : f32 = 0.90; // Parallel bounce factor for the ball when hitting walls

  const playerBounceFactorY : f32 = 0.80; // Perpendicular bounce factor for the ball when hitting players
  const playerBounceFactorX : f32 = 0.75; // Parallel bounce factor for the ball when hitting players

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

  p1.vel.x = P1_MV_FAC * playerSpeedFactor;
  p1.clampInX( -hWidth, -barHalfWidth );
  if( p1.vel.x == 0 ) { P1_MV_FAC = 0; }

  p2.vel.x = P2_MV_FAC * playerSpeedFactor;
  p2.clampInX( barHalfWidth, hWidth );
  if( p2.vel.x == 0 ) { P2_MV_FAC = 0; }


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
      ball.vel.x *=  wallBounceFactorY; // Inverted X and Y because this is a horizontal wall
      ball.vel.y *= -wallBounceFactorX; // Inverted X and Y because this is a horizontal wall

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
      ball.vel.x *= -wallBounceFactorX;
      ball.vel.y *=  wallBounceFactorY;

      emitParticlesOnBounce( ng, ball );
    }
  }
  else if( ball.getLeftX() <= -hWidth ) // Bounce the ball if it goes past the left edge
  {
    def.qlog( .DEBUG, 0, @src(), "Ball hit the left edge" );
    ball.setLeftX( -hWidth );

    if( ball.vel.x < 0 )
    {
      ball.vel.x *= -wallBounceFactorX;
      ball.vel.y *=  wallBounceFactorY;

      emitParticlesOnBounce( ng, ball );
    }
  }

  // ================ BALL-PLAYER COLLISIONS ================

  // Check if the ball is overlapping with player 1
  if( ball.isOverlapping( p1 ))
  {
    def.qlog( .DEBUG, 0, @src(), "Ball collided with player 1" );

    ball.setBottomY( p1.getTopY() );

    if( ball.vel.y > 0 )
    {
      ball.vel.y  = -ball.vel.y * playerBounceFactorY;
      ball.vel.y -= @abs( p1.vel.x ) * B_KIN_TRANS_FACTOR_Y;

      ball.vel.x *= playerBounceFactorX;
      ball.vel.x += p1.vel.x * B_KIN_TRANS_FACTOR_X;

      ensureBallMinSpeeds( ball );
      emitParticlesOnBounce( ng, ball );
    }
  }

  // Check if the ball is overlapping with player 2
  if( ball.isOverlapping( p2 ))
  {
    def.qlog( .DEBUG, 0, @src(), "Ball collided with player 2" );

    ball.setBottomY( p2.getTopY() );

    if( ball.vel.y > 0 )
    {
      ball.vel.y  = -ball.vel.y * playerBounceFactorY;
      ball.vel.y -= @abs( p2.vel.x ) * B_KIN_TRANS_FACTOR_Y;

      ball.vel.x *= playerBounceFactorX;
      ball.vel.x += p2.vel.x * B_KIN_TRANS_FACTOR_X;

      ensureBallMinSpeeds( ball );
      emitParticlesOnBounce( ng, ball );
    }
  }

}

pub fn OnRenderBackground( ng : *Engine ) void // Called by engine.renderGraphics()
{
  _ = ng; // Prevent unused variable warning

  def.ray.clearBackground( def.Colour.black );
}

pub fn OnRenderOverlay( ng : *Engine ) void // Called by engine.renderGraphics()
{
  // Declare the buffers to hold the formatted scores
  var s1_buff : [ 4:0 ]u8 = .{ 0, 0, 0, 0 }; // Buffer for player 1's score
  var s2_buff : [ 4:0 ]u8 = .{ 0, 0, 0, 0 }; // Buffer for player 2's score

  // Convert the scores to strings
  const s1_slice = std.fmt.bufPrint( &s1_buff, "{d}", .{ SCORES[ 0 ]}) catch | err |
  {
      def.log(.ERROR, 0, @src(), "Failed to format score for player 1: {}", .{err});
      return;
  };
  const s2_slice  = std.fmt.bufPrint( &s2_buff, "{d}", .{ SCORES[ 1 ]}) catch | err |
  {
      def.log(.ERROR, 0, @src(), "Failed to format score for player 2: {}", .{ err });
      return;
  };

  // Null terminate the strings
  s1_buff[ s1_slice.len ] = 0;
  s2_buff[ s2_slice.len ] = 0;

  // Find the center of each field in screen space
  const p1_score_pos = def.ray.getWorldToScreen2D( def.newVec2( def.getScreenWidth() *  0.25, 0 ), ng.viewManager.mainCamera );
  const p2_score_pos = def.ray.getWorldToScreen2D( def.newVec2( def.getScreenWidth() * -0.25, 0 ), ng.viewManager.mainCamera );

  // Draw each player's score in the middle of their respective fields
  def.drawCenteredText( &s1_buff, p1_score_pos.x, p1_score_pos.y, 64, def.Colour.blue );
  def.drawCenteredText( &s2_buff, p2_score_pos.x, p2_score_pos.y, 64, def.Colour.red );

  if( ng.state == .OPENED ) // NOTE : Gray out the game when it is paused
  {
    def.coverScreenWith( def.Colour.init( 0, 0, 0, 128 ));
  }

  if( WINNER != 0 ) // If there is a winner, display the winner message ( not grayed out )
  {
    const winner_msg = if( WINNER == 1 ) "Player 1 wins!" else "Player 2 wins!";
    def.drawCenteredText( winner_msg,               def.getScreenWidth() * 0.5, ( def.getScreenHeight() * 0.5 ) - 192, 128, def.Colour.green );
    def.drawCenteredText( "Press Enter to restart", def.getScreenWidth() * 0.5, ( def.getScreenHeight() * 0.5 ),       64,  def.Colour.yellow );
    def.drawCenteredText( "Press Escape to exit",   def.getScreenWidth() * 0.5, ( def.getScreenHeight() * 0.5 ) + 128, 64,  def.Colour.yellow );
  }
  else if( ng.state == .OPENED ) // If the game is paused, display the resume message
  {
    def.drawCenteredText( "Press Enter to resume", def.getScreenWidth() * 0.5, ( def.getScreenHeight() * 0.5 ) - 256, 64, def.Colour.yellow );
  }
}