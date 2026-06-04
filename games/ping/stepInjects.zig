const std      = @import( "std"    );
const eng      = @import( "engine" );
const utl      = @import( "utils"  );
const stateInj = @import( "stateInjects.zig" );

const Engine = eng.Engine;
const Angle  = utl.Angle;
const Vec2   = utl.Vec2;
const VecA   = utl.VecA;
const Box2   = utl.Box2;

const BodyParts = struct
{
  id     :  eng.EntityId,
  trans  : *eng.TransComp,
  shape  : *eng.ShapeComp,
  hitbox : *eng.HitboxComp,
};

var pendingBallParticles : u32 = 0;

// ================================ HELPER FUNCTIONS ================================

fn getBodyParts( id : eng.EntityId, name : []const u8 ) ?BodyParts
{
  const trans = stateInj.getTransStore().get( id ) orelse
  {
    utl.log( .WARN, 0, @src(), "Transform for Entity {d} ( {s} ) not found", .{ id, name });
    return null;
  };

  const shape = stateInj.getShapeStore().get( id ) orelse
  {
    utl.log( .WARN, 0, @src(), "Shape for Entity {d} ( {s} ) not found", .{ id, name });
    return null;
  };

  const hitbox = stateInj.getHitboxStore().get( id ) orelse
  {
    utl.log( .WARN, 0, @src(), "Hitbox for Entity {d} ( {s} ) not found", .{ id, name });
    return null;
  };

  return .{
    .id     = id,
    .trans  = trans,
    .shape  = shape,
    .hitbox = hitbox,
  };
}

fn syncBodyHitbox( body : BodyParts ) void
{
  body.hitbox.hitbox = body.shape.getAABB( body.trans.pos );
}

fn cpyBodyPosViaId( dstId : eng.EntityId, srcId : eng.EntityId ) void
{
  const src = getBodyParts( srcId, "Source" ) orelse return;
  const dst = getBodyParts( dstId, "Destination" ) orelse return;

  dst.trans.pos = src.trans.pos;
  syncBodyHitbox( dst );
}

fn setBodyBox( body : BodyParts, box : Box2 ) void
{
  body.trans.pos.x = box.center.x;
  body.trans.pos.y = box.center.y;
  body.hitbox.hitbox = body.shape.getAABB( body.trans.pos );
}

fn setBodyTopY( body : BodyParts, topY : f64 ) void
{
  var box = body.hitbox.hitbox;
  box.setTopY( topY );
  setBodyBox( body, box );
}

fn setBodyBottomY( body : BodyParts, bottomY : f64 ) void
{
  var box = body.hitbox.hitbox;
  box.setBottomY( bottomY );
  setBodyBox( body, box );
}

fn setBodyLeftX( body : BodyParts, leftX : f64 ) void
{
  var box = body.hitbox.hitbox;
  box.setLeftX( leftX );
  setBodyBox( body, box );
}

fn setBodyRightX( body : BodyParts, rightX : f64 ) void
{
  var box = body.hitbox.hitbox;
  box.setRightX( rightX );
  setBodyBox( body, box );
}

fn clampBodyInXRange( body : BodyParts, xMin : f64, xMax : f64 ) void
{
  var box = body.hitbox.hitbox;
  box.clampInXRange( xMin, xMax );
  setBodyBox( body, box );
}

// Emit particles in a given position and velocity range, with the given colour
pub fn emitParticles( ng : *Engine, pos : VecA, vel : VecA, dPos : VecA, dVel : VecA, amount : u32, colour : utl.Colour ) void
{
  // NOTE : Can invalidate component pointers after use. Call after body pointers are no longer needed.

  for( 0 .. amount )| i |
  {
    _ = i; // Ignore the index, we don't need it

    const size = eng.G_ENG.rng.getScaledFloat( 2.0, 7.0 );

    _ = stateInj.createEntity( ng, // NOTE : We do not care if this fails, as we are just emitting particles
    .{
      .pos    = eng.G_ENG.rng.getScaledVecA( dPos, pos ),
      .vel    = eng.G_ENG.rng.getScaledVecA( dVel, vel ),
      .scale  = Vec2.new( size, size ),

      .shape  = eng.G_ENG.rng.getVal( utl.Shape2D ),
      .colour = colour,
      .mobile = true,
      .particle = true,
    });
  }
}

pub fn emitBounceParticles( ng : *Engine, ball : BodyParts ) void
{
  // Emit particles at the ball's position relative to the ball's post-bounce velocity

  if( pendingBallParticles > 0 )
  {
    emitParticles(
      ng,
      ball.trans.pos, // NOTE : Had to set .use_llvm to false to avoid PRO issues with this line
      .{ .x = @divTrunc( ball.trans.vel.x, 3 ), .y = @divTrunc( ball.trans.vel.y, 3 ) },
      .{ .x = 16,  .y = 16, .a = Angle.newRad( 1.0 )},
      .{ .x = 128, .y = 32, .a = Angle.newRad( 2.0 )},
      pendingBallParticles, utl.Colour.yellow );

    ng.resourceManager.playAudio( "hit_1" );
    pendingBallParticles = 0;
  }
}


// ================================ GLOBAL GAME VARIABLES ================================

var   P1_MV_FAC : f64 = 0.0; // Player 1 movement direction
var   P2_MV_FAC : f64 = 0.0; // Player 2 movement direction

const MV_FAC_STEP : f64 = 0.4;  // Movement factor step ( size of increment / decrement )
const MV_FAC_CAP  : f64 = 16.0; // Movement factor cap, to prevent excessive speed

const B_BASE_VEL : f64 = 500.0; // Base velocity of the ball when it is launched
const B_GRAVITY  : f64 = 800.0; // Base gravitational acceleration of the ball

const WIN_SCORE : u8 = 5; // Score needed to win the game
var   WINNER    : u8 = 0; // The winner of the game, 1 for player 1, 2 for player 2, 0 for no winner yet

var   SCORES    : [ 2 ]u8 = .{ 0, 0 }; // Scores for player 1 and player 2

const B_MIN_BOUNCE_SPEED_X : f64 = 128.0; // Minimum parallel speed of the ball when bouncing off players
const B_MIN_BOUNCE_SPEED_Y : f64 = 256.0; // Minimum perpendicular speed of the ball when bouncing off players

const B_KIN_TRANS_FACTOR_X : f64 = 0.25; // How much of the player's velocity is given to the ball on bounce ( horizontal )
const B_KIN_TRANS_FACTOR_Y : f64 = 0.25; // How much of the player's velocity is given to the ball on bounce ( vertical )

pub fn ensureBallMinSpeeds( ball : BodyParts ) void
{
  if( ball.trans.vel.x > 0 ){ ball.trans.vel.x = @max( ball.trans.vel.x,  B_MIN_BOUNCE_SPEED_X ); }
  if( ball.trans.vel.x < 0 ){ ball.trans.vel.x = @min( ball.trans.vel.x, -B_MIN_BOUNCE_SPEED_X ); }

  if( ball.trans.vel.y > 0 ){ ball.trans.vel.y = @max( ball.trans.vel.y,  B_MIN_BOUNCE_SPEED_Y ); }
  if( ball.trans.vel.y < 0 ){ ball.trans.vel.y = @min( ball.trans.vel.y, -B_MIN_BOUNCE_SPEED_Y ); }
}


// ================================ STEP INJECTION FUNCTIONS ================================

pub fn OnFrameUpdate( ng : *Engine ) void
{
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.p ) or utl.ray.isKeyPressed( utl.ray.KeyboardKey.enter ))
  {
    ng.togglePause();

    if( WINNER != 0 )
    {
      SCORES = .{ 0, 0 }; // Reset scores if the game is restarted
      WINNER = 0;         // Reset winner

      // Reset the ball position and velocity
      const ball = getBodyParts( stateInj.BALL_ID, "Ball" ) orelse return;

      ball.trans.pos = .{};
      ball.trans.vel = .{};
      ball.trans.acc = .{};
      syncBodyHitbox( ball );

      // Reset the positions of the ball shadows
      for( stateInj.SHADOW_RANGE_START .. 1 + stateInj.SHADOW_RANGE_END )| i |{ cpyBodyPosViaId( @intCast( i ), stateInj.BALL_ID ); }

      utl.qlog( .INFO, 0, @src(), "Match reseted" );
    }
  }

  if( ng.isPlaying() )
  {
    // Move player 1 with A and D keys
    if( utl.ray.isKeyDown( utl.ray.KeyboardKey.d )){ P1_MV_FAC = @min( P1_MV_FAC + MV_FAC_STEP,  MV_FAC_CAP ); }
    if( utl.ray.isKeyDown( utl.ray.KeyboardKey.a )){ P1_MV_FAC = @max( P1_MV_FAC - MV_FAC_STEP, -MV_FAC_CAP ); }
    if( utl.ray.isKeyDown( utl.ray.KeyboardKey.s ) or utl.ray.isKeyDown( utl.ray.KeyboardKey.space )){ P1_MV_FAC = 0; }

    // Move player 2 with side arrow keys
    if( utl.ray.isKeyDown( utl.ray.KeyboardKey.right )){ P2_MV_FAC = @min( P2_MV_FAC + MV_FAC_STEP,  MV_FAC_CAP ); }
    if( utl.ray.isKeyDown( utl.ray.KeyboardKey.left  )){ P2_MV_FAC = @max( P2_MV_FAC - MV_FAC_STEP, -MV_FAC_CAP ); }
    if( utl.ray.isKeyDown( utl.ray.KeyboardKey.down  ) or utl.ray.isKeyDown( utl.ray.KeyboardKey.kp_enter )){ P2_MV_FAC = 0; }

    // Move the camera with the numpad keys
    if( utl.ray.isKeyDown( utl.ray.KeyboardKey.kp_8 )){ eng.G_ENG.camera.moveByS( Vec2.new(  0, -8 )); }
    if( utl.ray.isKeyDown( utl.ray.KeyboardKey.kp_2 )){ eng.G_ENG.camera.moveByS( Vec2.new(  0,  8 )); }
    if( utl.ray.isKeyDown( utl.ray.KeyboardKey.kp_4 )){ eng.G_ENG.camera.moveByS( Vec2.new( -8,  0 )); }
    if( utl.ray.isKeyDown( utl.ray.KeyboardKey.kp_6 )){ eng.G_ENG.camera.moveByS( Vec2.new(  8,  0 )); }

    // Reset the camera zoom and position when r is pressed
    if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.r ))
    {
      eng.G_ENG.camera.setZoom( 1.0 );
      eng.G_ENG.camera.cam.pos = .{};
      utl.qlog( .INFO, 0, @src(), "Camera reseted" );
    }
  }

  if( WINNER == 0 and ( SCORES[ 0 ] >= WIN_SCORE or SCORES[ 1 ] >= WIN_SCORE ))
  {
    ng.changeState( .OPENED ); // Pause the game on victory

    if( SCORES[ 0 ] >= WIN_SCORE )
    {
      WINNER = 1; // Player 1 wins
      utl.log( .INFO, 0, @src(), "Player 1 wins! : {d} to {d}", .{ SCORES[ 0 ], SCORES[ 1 ] });
    }
    else if( SCORES[ 1 ] >= WIN_SCORE )
    {
      WINNER = 2; // Player 2 wins
      utl.log( .INFO, 0, @src(), "Player 2 wins! : {d} to {d}", .{ SCORES[ 1 ], SCORES[ 0 ] });
    }
  }
}

pub fn OnTickUpdate( ng : *Engine ) void
{
  const ball = getBodyParts( stateInj.BALL_ID, "Ball" ) orelse return;

  ball.trans.acc.y = B_GRAVITY;

  // Chainwap the positions of the ball shadows
  for( stateInj.SHADOW_RANGE_START .. 0 + stateInj.SHADOW_RANGE_END )| i |{ cpyBodyPosViaId( @intCast( i ), @intCast( i + 1 ) ); }

  cpyBodyPosViaId( stateInj.SHADOW_RANGE_END, stateInj.BALL_ID );

  var particleIndex : usize = 0;
  while( particleIndex < stateInj.getParticleCount() )
  {
    const part = getBodyParts( stateInj.getParticleId( particleIndex ), "Particle" ) orelse
    {
      stateInj.removeParticleAt( particleIndex );
      continue;
    };

    // If the particle is below the screen, deactivate it and mark it for deletion
    if( part.hitbox.hitbox.getTopY() >= utl.getScreenHeight() / 2 )
    {
      stateInj.removeParticleAt( particleIndex );
      continue;
    }

    part.trans.acc.y = B_GRAVITY; // Apply gravity to all remaining particles
    particleIndex += 1;
  }

  stateInj.updateMobileEntities( ng.getTargetTickSDT() );
}

pub fn OffTickUpdate( ng : *Engine ) void
{
  // ================ VARIABLES AND CONSTANTS ================

  const hWidth  : f64 = utl.getScreenWidth()  / 2.0;
  const hHeight : f64 = utl.getScreenHeight() / 2.0;

  const barHalfWidth        : f64 = 8.0;  // Half the width of the separator bar
  const playerSpeedFactor   : f64 = 64.0; // Base speed of the players

  const wallBounceFactorX   : f64 = 0.85; // Perpendicular bounce factor for the ball when hitting walls
  const wallBounceFactorY   : f64 = 0.90; // Parallel bounce factor for the ball when hitting walls

  const playerBounceFactorY : f64 = 0.80; // Perpendicular bounce factor for the ball when hitting players
  const playerBounceFactorX : f64 = 0.75; // Parallel bounce factor for the ball when hitting players

  const p1   = getBodyParts( stateInj.P1_ID,   "P1"   ) orelse return;
  const p2   = getBodyParts( stateInj.P2_ID,   "P2"   ) orelse return;
  const ball = getBodyParts( stateInj.BALL_ID, "Ball" ) orelse return;

  // ================ CLAMPING THE PLAYER POSITIONS ================

  p1.trans.vel.x = P1_MV_FAC * playerSpeedFactor;
  if( !p1.hitbox.hitbox.isInXRange( -hWidth, -barHalfWidth ))
  {
    clampBodyInXRange( p1, -hWidth, -barHalfWidth );
    p1.trans.vel.x = 0;
    P1_MV_FAC = 0;
  }

  p2.trans.vel.x = P2_MV_FAC * playerSpeedFactor;
  if( !p2.hitbox.hitbox.isInXRange( barHalfWidth, hWidth ))
  {
    clampBodyInXRange( p2, barHalfWidth, hWidth );
    p2.trans.vel.x = 0;
    P2_MV_FAC = 0;
  }


  // ================ CLAMPING THE BALL POSITION ================

  // Clamping to top and bottom of the screen
  if( ball.trans.pos.y >= hHeight ) // Scoring a point if the ball goes below the bottom of the screen
  {
    utl.qlog( .DEBUG, 0, @src(), "Ball hit the bottom edge" );
    ball.trans.vel.y = -B_BASE_VEL; // Reset ball vertical velocity to the base velocity
    ball.trans.pos.y =  0.0; // Reset ball height to the middle of the screen

    if( ball.trans.pos.x < 0 ) // Player 2 scores a point
    {
      utl.log( .INFO, 0, @src(), "Player 2 scores a point! : {d}:{d}", .{ SCORES[ 0 ], SCORES[ 1 ] });
      SCORES[ 1 ] += 1;

      // Set the ball to be thrown towards player 1
      ball.trans.vel.x = -B_BASE_VEL;
      ball.trans.pos.x =  hWidth / 2;
    }
    else if( ball.trans.pos.x > 0 ) // Player 1 scores a point
    {
      utl.log( .INFO, 0, @src(), "Player 1 scores a point! : {d}:{d}", .{ SCORES[ 0 ], SCORES[ 1 ] });
      SCORES[ 0 ] += 1;

      // Set the ball to be thrown towards player 2
      ball.trans.vel.x =  B_BASE_VEL;
      ball.trans.pos.x = -hWidth / 2;
    }
    else // If the ball is in the middle of the screen, reset its horizontal position
    {
      utl.qlog( .WARN, 0, @src(), "No player scored, throwing ball to Player 1" );
      if( eng.G_ENG.rng.getVal( bool ))
      {
        ball.trans.vel.x =  B_BASE_VEL;
        ball.trans.pos.x = -hWidth / 2;
      }
      else
      {
        ball.trans.vel.x = -B_BASE_VEL;
        ball.trans.pos.x =  hWidth / 2;
      }
    }
    syncBodyHitbox( ball );
  }
  else if( ball.hitbox.hitbox.getTopY() <= -hHeight ) // Bounce the ball if it goes above the top of the screen
  {
    utl.qlog( .DEBUG, 0, @src(), "Ball hit the top edge" );
    setBodyTopY( ball, -hHeight );

    if( ball.trans.vel.y < 0 )
    {
      ball.trans.vel.x *=  wallBounceFactorY; // Inverted X and Y because this is a horizontal wall
      ball.trans.vel.y *= -wallBounceFactorX; // Inverted X and Y because this is a horizontal wall

      pendingBallParticles += 6;
    }
  }

  // Clamping to left and right edges of the screen
  if( ball.hitbox.hitbox.getRightX() >= hWidth ) // Bounce the ball if it goes past the right edge
  {
    utl.qlog( .DEBUG, 0, @src(), "Ball hit the right edge" );
    setBodyRightX( ball, hWidth );

    if( ball.trans.vel.x > 0 )
    {
      ball.trans.vel.x *= -wallBounceFactorX;
      ball.trans.vel.y *=  wallBounceFactorY;

      pendingBallParticles += 12;
    }
  }
  else if( ball.hitbox.hitbox.getLeftX() <= -hWidth ) // Bounce the ball if it goes past the left edge
  {
    utl.qlog( .DEBUG, 0, @src(), "Ball hit the left edge" );
    setBodyLeftX( ball, -hWidth );

    if( ball.trans.vel.x < 0 )
    {
      ball.trans.vel.x *= -wallBounceFactorX;
      ball.trans.vel.y *=  wallBounceFactorY;

      pendingBallParticles += 12;
    }
  }

  // ================ BALL-PLAYER COLLISIONS ================

  // Check if the ball is overlapping with player 1
  if( ball.hitbox.isOverlapping( p1.hitbox ))
  {
    utl.qlog( .DEBUG, 0, @src(), "Ball collided with player 1" );

    setBodyBottomY( ball, p1.hitbox.hitbox.getTopY() );

    //utl.qlog( .DEBUG, 0, @src(), "HERE" );

    if( ball.trans.vel.y > 0 )
    {
      ball.trans.vel.y  = -ball.trans.vel.y * playerBounceFactorY;
      ball.trans.vel.y -= @abs( p1.trans.vel.x ) * B_KIN_TRANS_FACTOR_Y;

      ball.trans.vel.x *= playerBounceFactorX;
      ball.trans.vel.x += p1.trans.vel.x * B_KIN_TRANS_FACTOR_X;

      ensureBallMinSpeeds( ball );
      pendingBallParticles += 6;
    }
  }

  // Check if the ball is overlapping with player 2
  if( ball.hitbox.isOverlapping( p2.hitbox ))
  {
    utl.qlog( .DEBUG, 0, @src(), "Ball collided with player 2" );

    setBodyBottomY( ball, p2.hitbox.hitbox.getTopY() );

    if( ball.trans.vel.y > 0 )
    {
      ball.trans.vel.y  = -ball.trans.vel.y * playerBounceFactorY;
      ball.trans.vel.y -= @abs( p2.trans.vel.x ) * B_KIN_TRANS_FACTOR_Y;

      ball.trans.vel.x *= playerBounceFactorX;
      ball.trans.vel.x += p2.trans.vel.x * B_KIN_TRANS_FACTOR_X;

      ensureBallMinSpeeds( ball );
      pendingBallParticles += 6;
    }
  }

  emitBounceParticles( ng, ball );
}

pub fn OnRenderWorld( ng : *Engine ) void
{
  _ = ng;

  stateInj.renderEntities();
}


pub fn OnRenderOverlay( ng : *Engine ) void
{
  // Declare the buffers to hold the formatted scores
  var s1_buff : [ 4:0 ]u8 = .{ 0, 0, 0, 0 }; // Buffer for player 1's score
  var s2_buff : [ 4:0 ]u8 = .{ 0, 0, 0, 0 }; // Buffer for player 2's score

  // Convert the scores to strings
  const s1_slice = std.fmt.bufPrint( &s1_buff, "{d}", .{ SCORES[ 0 ]}) catch | err |
  {
      utl.log(.ERROR, 0, @src(), "Failed to format score for player 1: {}", .{err});
      return;
  };
  const s2_slice  = std.fmt.bufPrint( &s2_buff, "{d}", .{ SCORES[ 1 ]}) catch | err |
  {
      utl.log(.ERROR, 0, @src(), "Failed to format score for player 2: {}", .{ err });
      return;
  };

  // Null terminate the strings
  s1_buff[ s1_slice.len ] = 0;
  s2_buff[ s2_slice.len ] = 0;

  const screenCenter = utl.getHalfScreenSize();

  // Draw each player's score in the middle of their respective fields
  utl.sDraw.textCenter( &s1_buff, .new( screenCenter.x - 512, screenCenter.y ), 64, utl.Colour.blue );
  utl.sDraw.textCenter( &s2_buff, .new( screenCenter.x + 512, screenCenter.y ), 64, utl.Colour.red );

  if( ng.state == .OPENED )
  {
    utl.sDraw.coverScreenWithCol( .new( 0, 0, 0, 128 ));

    if( ng.state == .OPENED and WINNER == 0 ) // NOTE : Gray out the game when it is paused
    {

      utl.sDraw.textCenter( "Hold A or D to accelerate", .new( screenCenter.x * 0.5, screenCenter.y + 128 ), 32, utl.Colour.yellow );
      utl.sDraw.textCenter( "Press S or Space to break", .new( screenCenter.x * 0.5, screenCenter.y + 192 ), 32, utl.Colour.yellow );

      utl.sDraw.textCenter( "Hold Left or Right to accelerate", .new( screenCenter.x * 1.5, screenCenter.y + 128 ), 32, utl.Colour.yellow );
      utl.sDraw.textCenter( "Press Down or KP enter to break",  .new( screenCenter.x * 1.5, screenCenter.y + 192 ), 32, utl.Colour.yellow );
    }

  }

  if( WINNER != 0 ) // If there is a winner, display the winner message ( not grayed out )
  {

    const winner_msg = if( WINNER == 1 ) "Player 1 wins!" else "Player 2 wins!";
    utl.sDraw.textCenter( winner_msg,               .new( screenCenter.x, screenCenter.y - 192 ), 128, utl.Colour.green );
    utl.sDraw.textCenter( "Press Enter to restart", .new( screenCenter.x, screenCenter.y       ),  64, utl.Colour.yellow );
    utl.sDraw.textCenter( "Press Escape to exit",   .new( screenCenter.x, screenCenter.y + 128 ),  64, utl.Colour.yellow );
  }
  else if( ng.state == .OPENED ) // If the game is paused, display the resume message
  {
    utl.sDraw.textCenter( "Press Enter to resume", .new( screenCenter.x, screenCenter.y - 128 ), 128, utl.Colour.yellow );
  }
}
