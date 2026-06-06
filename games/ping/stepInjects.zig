const std      = @import( "std"    );
const eng      = @import( "engine" );
const utl      = @import( "utils"  );
const stateInj = @import( "stateInjects.zig" );

const Engine = eng.Engine;
const Angle  = utl.Angle;
const Vec2   = utl.Vec2;
const VecA   = utl.VecA;
const Box2   = utl.Box2;

const BodyComps = struct
{
  id     :  eng.EntityId,
  trans  : *eng.TransComp,
  shape  : *eng.ShapeComp,
  hitbox : *eng.HitboxComp,
};

const PlayerId = enum( u8 )
{
  NONE = 0,
  P1   = 1,
  P2   = 2,
};


// ================================ GLOBAL GAME VARIABLES ================================

var pendingBallParticles : u32 = 0;

var   P1_MV_FAC   : f64 = 0.0;   // Player 1 movement direction
var   P2_MV_FAC   : f64 = 0.0;   // Player 2 movement direction

const MV_FAC_STEP : f64 = 0.4;   // Movement factor step ( size of increment / decrement )
const MV_FAC_CAP  : f64 = 16.0;  // Movement factor cap, to prevent excessive speed

const B_BASE_VEL  : f64 = 500.0; // Base velocity of the ball when it is launched
const B_GRAVITY   : f64 = 800.0; // Base gravitational acceleration of the ball

const BAR_HALF_WIDTH      : f64 = 8.0;  // Half the width of the separator bar
const PLAYER_SPEED_FACTOR : f64 = 64.0; // Base speed of the players

const WALL_BOUNCE_FAC_X   : f64 = 0.85; // Perpendicular bounce factor for the ball when hitting walls
const WALL_BOUNCE_FAC_Y   : f64 = 0.90; // Parallel bounce factor for the ball when hitting walls

const PLAYER_BOUNCE_FAC_X : f64 = 0.75; // Parallel bounce factor for the ball when hitting players
const PLAYER_BOUNCE_FAC_Y : f64 = 0.80; // Perpendicular bounce factor for the ball when hitting players

const WIN_SCORE : u8       = 5;     // Score needed to win the game
var   WINNER    : PlayerId = .NONE; // The winner of the game

var   SCORES : [ 2 ]u8 = .{ 0, 0 }; // Scores for player 1 and player 2

const BOUNCE_CAP    : u8       = 3;     // Number of consecutive player bounces at which a fault occures
var   BOUNCE_CHAIN  : u8       = 0;     // Number of consecutive bounces by the same player
var   LAST_BOUNCE_P : PlayerId = .NONE; // Last player to bounce the ball

const B_MIN_BOUNCE_SPEED_Y : f64 = 256.0; // Minimum vertical speed of the ball when bouncing off players

const B_KIN_TRANS_FACTOR_X : f64 = 0.50; // How much of the player's velocity is given to the ball on bounce ( horizontal )
const B_KIN_TRANS_FACTOR_Y : f64 = 0.25; // How much of the player's velocity is given to the ball on bounce ( vertical )


// ================================ HELPER FUNCTIONS ================================

fn getBodyComps( view : *stateInj.BodyView, id : eng.EntityId, name : []const u8 ) ?BodyComps
{
  const trans = view.get( eng.TransComp, id ) orelse
  {
    utl.log( .WARN, 0, @src(), "Transform for Entity {d} ( {s} ) not found", .{ id, name });
    return null;
  };

  const shape = view.get( eng.ShapeComp, id ) orelse
  {
    utl.log( .WARN, 0, @src(), "Shape for Entity {d} ( {s} ) not found", .{ id, name });
    return null;
  };

  const hitbox = view.get( eng.HitboxComp, id ) orelse
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

fn syncBodyHitbox( body : BodyComps ) void
{
  body.hitbox.hitbox = body.shape.getAABB( body.trans.pos );
}

fn cpyBodyPosViaId( view : *stateInj.BodyView, dstId : eng.EntityId, srcId : eng.EntityId ) void
{
  const src = getBodyComps( view, srcId, "Source" ) orelse return;
  const dst = getBodyComps( view, dstId, "Destination" ) orelse return;

  dst.trans.pos = src.trans.pos;
  syncBodyHitbox( dst );
}

fn setBodyBox( body : BodyComps, box : Box2 ) void
{
  body.trans.pos.x   = box.center.x;
  body.trans.pos.y   = box.center.y;
  body.hitbox.hitbox = body.shape.getAABB( body.trans.pos );
}

fn setBodyTopY( body : BodyComps, topY : f64 ) void
{
  var box = body.hitbox.hitbox;
  box.setTopY( topY );
  setBodyBox( body, box );
}

fn setBodyBottomY( body : BodyComps, bottomY : f64 ) void
{
  var box = body.hitbox.hitbox;
  box.setBottomY( bottomY );
  setBodyBox( body, box );
}

fn setBodyLeftX( body : BodyComps, leftX : f64 ) void
{
  var box = body.hitbox.hitbox;
  box.setLeftX( leftX );
  setBodyBox( body, box );
}

fn setBodyRightX( body : BodyComps, rightX : f64 ) void
{
  var box = body.hitbox.hitbox;
  box.setRightX( rightX );
  setBodyBox( body, box );
}

fn clampBodyInXRange( body : BodyComps, xMin : f64, xMax : f64 ) void
{
  var box = body.hitbox.hitbox;
  box.clampInXRange( xMin, xMax );
  setBodyBox( body, box );
}

// Emit particles in a given position and velocity range, with the given colour
fn emitParticles( ng : *Engine, view : *stateInj.BodyView, pos : VecA, vel : VecA, dPos : VecA, dVel : VecA, amount : u32, colour : utl.Colour ) void
{
  // NOTE : Can invalidate component pointers after use. Call after body pointers are no longer needed.
  // TODO : Swap over to the new particle system once it is implemented

  for( 0 .. amount )| i |
  {
    _ = i; // Ignore the index, we don't need it

    const size = eng.G_ENG.rng.getScaledFloat( 2.0, 7.0 );

    _ = stateInj.createEntity( ng, view, // NOTE : We do not care if this fails, as we are just emitting particles
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

fn emitBounceParticles( ng : *Engine, view : *stateInj.BodyView, ball : BodyComps ) void
{
  // Emit particles at the ball's position relative to the ball's post-bounce velocity

  if( pendingBallParticles > 0 )
  {
    emitParticles(
      ng,
      view,
      ball.trans.pos, // NOTE : Had to set .use_llvm to false to avoid PRO issues with this line
      .{ .x = @divTrunc( ball.trans.vel.x, 3 ), .y = @divTrunc( ball.trans.vel.y, 3 ) },
      .{ .x = 16,  .y = 16, .a = Angle.newRad( 1.0 )},
      .{ .x = 128, .y = 32, .a = Angle.newRad( 2.0 )},
      pendingBallParticles, utl.Colour.yellow );

    ng.resourceManager.playAudio( "hit_1" );
    pendingBallParticles = 0;
  }
}

fn resetBounceChain() void
{
  LAST_BOUNCE_P = .NONE;
  BOUNCE_CHAIN  = 0;
}

fn playerNum( player : PlayerId ) u8
{
  return @intFromEnum( player );
}

fn playerIndex( player : PlayerId ) usize
{
  return switch( player )
  {
    .P1   => 0,
    .P2   => 1,
    .NONE => 0,
  };
}

fn opponentOf( player : PlayerId ) PlayerId
{
  return switch( player )
  {
    .P1   => .P2,
    .P2   => .P1,
    .NONE => .NONE,
  };
}

fn registerPlayerBounce( player : PlayerId ) bool
{
  if( LAST_BOUNCE_P == player )
  {
    BOUNCE_CHAIN += 1;
  }
  else
  {
    LAST_BOUNCE_P = player;
    BOUNCE_CHAIN  = 1;
  }

  return BOUNCE_CHAIN < BOUNCE_CAP;
}

fn resetRally() void
{
  pendingBallParticles = 0;
  resetBounceChain();
}

fn serveBall( ball : BodyComps, target : PlayerId, hWidth : f64 ) void
{
  ball.trans.vel.y = -B_BASE_VEL; // Reset ball vertical velocity to the base velocity
  ball.trans.pos.y =  0.0;       // Reset ball height to the middle of the screen

  switch( target )
  {
    .P1 =>
    {
      ball.trans.vel.x = -B_BASE_VEL;
      ball.trans.pos.x =  hWidth / 2;
    },
    .P2 =>
    {
      ball.trans.vel.x =  B_BASE_VEL;
      ball.trans.pos.x = -hWidth / 2;
    },
    .NONE => {},
  }

  resetRally();
  syncBodyHitbox( ball );
}

fn serveBallRandom( ball : BodyComps, hWidth : f64 ) void
{
  serveBall( ball, if( eng.G_ENG.rng.getVal( bool )) .P2 else .P1, hWidth );
}

fn scorePoint( ball : BodyComps, scorer : PlayerId, hWidth : f64 ) void
{
  if( scorer == .NONE ){ return; }

  SCORES[ playerIndex( scorer ) ] += 1;
  utl.log( .INFO, 0, @src(), "Player {d} scores a point! : {d}:{d}", .{ playerNum( scorer ), SCORES[ 0 ], SCORES[ 1 ] });

  // Set the ball to be thrown towards the player who lost the point.
  serveBall( ball, opponentOf( scorer ), hWidth );
}

fn resetMatchBall( view : *stateInj.BodyView ) bool
{
  const ball = getBodyComps( view, stateInj.BALL_ID, "Ball" ) orelse return false;

  ball.trans.pos = .{};
  ball.trans.vel = .{};
  ball.trans.acc = .{};
  syncBodyHitbox( ball );

  for( stateInj.SHADOW_RANGE_START .. 1 + stateInj.SHADOW_RANGE_END )| i |{ cpyBodyPosViaId( view, @intCast( i ), stateInj.BALL_ID ); }

  return true;
}

fn updateMoveFactor( mvFac : *f64, positiveKey : utl.ray.KeyboardKey, negativeKey : utl.ray.KeyboardKey, brakeKeyA : utl.ray.KeyboardKey, brakeKeyB : utl.ray.KeyboardKey ) void
{
  if( utl.ray.isKeyDown( positiveKey )){ mvFac.* = @min( mvFac.* + MV_FAC_STEP,  MV_FAC_CAP ); }
  if( utl.ray.isKeyDown( negativeKey )){ mvFac.* = @max( mvFac.* - MV_FAC_STEP, -MV_FAC_CAP ); }
  if( utl.ray.isKeyDown( brakeKeyA ) or utl.ray.isKeyDown( brakeKeyB )){ mvFac.* = 0; }
}

fn updatePlayerInput() void
{
  updateMoveFactor( &P1_MV_FAC, .d,     .a,    .s,    .space    );
  updateMoveFactor( &P2_MV_FAC, .right, .left, .down, .kp_enter );
}

fn updateCameraInput() void
{
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.kp_8 )){ eng.G_ENG.camera.moveByS( Vec2.new(  0, -8 )); }
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.kp_2 )){ eng.G_ENG.camera.moveByS( Vec2.new(  0,  8 )); }
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.kp_4 )){ eng.G_ENG.camera.moveByS( Vec2.new( -8,  0 )); }
  if( utl.ray.isKeyDown( utl.ray.KeyboardKey.kp_6 )){ eng.G_ENG.camera.moveByS( Vec2.new(  8,  0 )); }

  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.r ))
  {
    eng.G_ENG.camera.setZoom( 1.0 );
    eng.G_ENG.camera.cam.pos = .{};
    utl.qlog( .INFO, 0, @src(), "Camera reseted" );
  }
}

fn clampPlayerX( player : BodyComps, mvFac : *f64, xMin : f64, xMax : f64 ) void
{
  player.trans.vel.x = mvFac.* * PLAYER_SPEED_FACTOR;

  if( !player.hitbox.hitbox.isInXRange( xMin, xMax ))
  {
    clampBodyInXRange( player, xMin, xMax );
    player.trans.vel.x = 0;
    mvFac.* = 0;
  }
}

fn handleBottomEdge( ball : BodyComps, hWidth : f64, hHeight : f64 ) bool
{
  if( ball.trans.pos.y < hHeight ){ return false; }

  utl.qlog( .DEBUG, 0, @src(), "Ball hit the bottom edge" );

  if( ball.trans.pos.x < 0 )
  {
    scorePoint( ball, .P2, hWidth );
  }
  else if( ball.trans.pos.x > 0 )
  {
    scorePoint( ball, .P1, hWidth );
  }
  else
  {
    utl.qlog( .WARN, 0, @src(), "No player scored, throwing ball to Player 1" );
    serveBallRandom( ball, hWidth );
  }

  return true;
}

fn handleTopEdge( ball : BodyComps, hHeight : f64 ) void
{
  if( ball.hitbox.hitbox.getTopY() > -hHeight ){ return; }

  utl.qlog( .DEBUG, 0, @src(), "Ball hit the top edge" );
  setBodyTopY( ball, -hHeight );

  if( ball.trans.vel.y < 0 )
  {
    ball.trans.vel.x *=  WALL_BOUNCE_FAC_Y; // Inverted X and Y because this is a horizontal wall
    ball.trans.vel.y *= -WALL_BOUNCE_FAC_X; // Inverted X and Y because this is a horizontal wall

    pendingBallParticles += 6;
  }
}

fn handleSideEdges( ball : BodyComps, hWidth : f64 ) void
{
  if( ball.hitbox.hitbox.getRightX() >= hWidth )
  {
    utl.qlog( .DEBUG, 0, @src(), "Ball hit the right edge" );
    setBodyRightX( ball, hWidth );

    if( ball.trans.vel.x > 0 )
    {
      ball.trans.vel.x *= -WALL_BOUNCE_FAC_X;
      ball.trans.vel.y *=  WALL_BOUNCE_FAC_Y;

      pendingBallParticles += 12;
    }
  }
  else if( ball.hitbox.hitbox.getLeftX() <= -hWidth )
  {
    utl.qlog( .DEBUG, 0, @src(), "Ball hit the left edge" );
    setBodyLeftX( ball, -hWidth );

    if( ball.trans.vel.x < 0 )
    {
      ball.trans.vel.x *= -WALL_BOUNCE_FAC_X;
      ball.trans.vel.y *=  WALL_BOUNCE_FAC_Y;

      pendingBallParticles += 12;
    }
  }
}

fn handlePlayerBounce( ball : BodyComps, player : BodyComps, playerId : PlayerId, hWidth : f64 ) bool
{
  if( !ball.hitbox.isOverlapping( player.hitbox )){ return false; }

  utl.log( .DEBUG, 0, @src(), "Ball collided with player {d}", .{ playerNum( playerId ) });
  setBodyBottomY( ball, player.hitbox.hitbox.getTopY() );

  if( ball.trans.vel.y <= 0 ){ return false; }

  if( !registerPlayerBounce( playerId ))
  {
    utl.log( .INFO, 0, @src(), "Player {d} exceeded the {d}-bounce cap", .{ playerNum( playerId ), BOUNCE_CAP });
    scorePoint( ball, opponentOf( playerId ), hWidth );
    return true;
  }

  ball.trans.vel.y  = -ball.trans.vel.y * PLAYER_BOUNCE_FAC_Y;
  ball.trans.vel.y -= @abs( player.trans.vel.x ) * B_KIN_TRANS_FACTOR_Y;

  ball.trans.vel.x *= PLAYER_BOUNCE_FAC_X;
  ball.trans.vel.x += player.trans.vel.x * B_KIN_TRANS_FACTOR_X;

  ensureBallMinSpeeds( ball );
  pendingBallParticles += 6;

  return false;
}

fn ensureBallMinSpeeds( ball : BodyComps ) void
{
  if( ball.trans.vel.y > 0 ){ ball.trans.vel.y = @max( ball.trans.vel.y,  B_MIN_BOUNCE_SPEED_Y ); }
  if( ball.trans.vel.y < 0 ){ ball.trans.vel.y = @min( ball.trans.vel.y, -B_MIN_BOUNCE_SPEED_Y ); }
}


// ================================ STEP INJECTION FUNCTIONS ================================

pub fn OnInputUpdate( ng : *Engine ) void
{
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.p ) or utl.ray.isKeyPressed( utl.ray.KeyboardKey.enter ))
  {
    ng.togglePause();

    if( WINNER != .NONE )
    {
      var bodyView = stateInj.getBodyView( ng ) orelse return;

      SCORES = .{ 0, 0 }; // Reset scores if the game is restarted
      WINNER = .NONE;     // Reset winner
      resetRally();
      if( !resetMatchBall( &bodyView )){ return; }

      utl.qlog( .INFO, 0, @src(), "Match reseted" );
    }
  }

  if( ng.isPlaying() )
  {
    updatePlayerInput();
    updateCameraInput();
  }

  if( WINNER == .NONE and ( SCORES[ 0 ] >= WIN_SCORE or SCORES[ 1 ] >= WIN_SCORE ))
  {
    ng.changeState( .OPENED ); // Pause the game on victory

    if( SCORES[ 0 ] >= WIN_SCORE )
    {
      WINNER = .P1;
      utl.log( .INFO, 0, @src(), "Player 1 wins! : {d} to {d}", .{ SCORES[ 0 ], SCORES[ 1 ] });
    }
    else if( SCORES[ 1 ] >= WIN_SCORE )
    {
      WINNER = .P2;
      utl.log( .INFO, 0, @src(), "Player 2 wins! : {d} to {d}", .{ SCORES[ 1 ], SCORES[ 0 ] });
    }
  }
}

pub fn OnTickUpdate( ng : *Engine ) void
{
  var bodyView   = stateInj.getBodyView(   ng ) orelse return;
  const ball = getBodyComps( &bodyView, stateInj.BALL_ID, "Ball" ) orelse return;

  ball.trans.acc.y = B_GRAVITY;

  // Chainwap the positions of the ball shadows
  for( stateInj.SHADOW_RANGE_START .. 0 + stateInj.SHADOW_RANGE_END )| i |{ cpyBodyPosViaId( &bodyView, @intCast( i ), @intCast( i + 1 ) ); }

  cpyBodyPosViaId( &bodyView, stateInj.SHADOW_RANGE_END, stateInj.BALL_ID );

  var particleIndex : usize = 0;
  while( particleIndex < stateInj.getParticleCount() )
  {
    const part = getBodyComps( &bodyView, stateInj.getParticleId( particleIndex ), "Particle" ) orelse
    {
      stateInj.removeParticleAt( ng, particleIndex );
      continue;
    };

    // If the particle is below the screen, deactivate it and mark it for deletion
    if( part.hitbox.hitbox.getTopY() >= utl.getScreenHeight() / 2 )
    {
      stateInj.removeParticleAt( ng, particleIndex );
      continue;
    }

    part.trans.acc.y = B_GRAVITY; // Apply gravity to all remaining particles
    particleIndex += 1;
  }

  stateInj.updateMobileEntities( &bodyView, ng.getTargetTickDelta() );
}

pub fn OffTickUpdate( ng : *Engine ) void
{
  const hWidth  : f64 = utl.getScreenWidth()  / 2.0;
  const hHeight : f64 = utl.getScreenHeight() / 2.0;

  var bodyView = stateInj.getBodyView( ng ) orelse return;
  const p1     = getBodyComps( &bodyView, stateInj.P1_ID,   "P1"   ) orelse return;
  const p2     = getBodyComps( &bodyView, stateInj.P2_ID,   "P2"   ) orelse return;
  const ball   = getBodyComps( &bodyView, stateInj.BALL_ID, "Ball" ) orelse return;

  clampPlayerX( p1, &P1_MV_FAC, -hWidth, -BAR_HALF_WIDTH );
  clampPlayerX( p2, &P2_MV_FAC,  BAR_HALF_WIDTH, hWidth );

  if( !handleBottomEdge( ball, hWidth, hHeight ))
  {
    handleTopEdge( ball, hHeight );
    handleSideEdges( ball, hWidth );
  }

  if( handlePlayerBounce( ball, p1, .P1, hWidth )){ return; }
  if( handlePlayerBounce( ball, p2, .P2, hWidth )){ return; }

  emitBounceParticles( ng, &bodyView, ball );
}

pub fn OnRenderWorld( ng : *Engine ) void
{
  var bodyView = stateInj.getBodyView( ng ) orelse return;

  stateInj.renderEntities( &bodyView );
}

fn drawScore( score : u8, player : PlayerId, pos : Vec2, colour : utl.Colour ) void
{
  var buff : [ 4:0 ]u8 = .{ 0, 0, 0, 0 };

  const slice = std.fmt.bufPrint( &buff, "{d}", .{ score }) catch | err |
  {
    utl.log( .ERROR, 0, @src(), "Failed to format score for player {d}: {}", .{ playerNum( player ), err });
    return;
  };

  buff[ slice.len ] = 0;
  utl.sDraw.textCenter( &buff, pos, 64, colour );
}

fn drawScores( screenCenter : Vec2 ) void
{
  drawScore( SCORES[ 0 ], .P1, .new( screenCenter.x - 512, screenCenter.y ), utl.Colour.blue );
  drawScore( SCORES[ 1 ], .P2, .new( screenCenter.x + 512, screenCenter.y ), utl.Colour.red  );
}

fn drawPauseControls( screenCenter : Vec2 ) void
{
  utl.sDraw.textCenter( "Hold A or D to accelerate", .new( screenCenter.x * 0.5, screenCenter.y + 128 ), 32, utl.Colour.yellow );
  utl.sDraw.textCenter( "Press S or Space to break", .new( screenCenter.x * 0.5, screenCenter.y + 192 ), 32, utl.Colour.yellow );

  utl.sDraw.textCenter( "Hold Left or Right to accelerate", .new( screenCenter.x * 1.5, screenCenter.y + 128 ), 32, utl.Colour.yellow );
  utl.sDraw.textCenter( "Press Down or KP enter to break",  .new( screenCenter.x * 1.5, screenCenter.y + 192 ), 32, utl.Colour.yellow );
}

fn drawWinnerOverlay( screenCenter : Vec2 ) void
{
  const winnerMsg = if( WINNER == .P1 ) "Player 1 wins!" else "Player 2 wins!";

  utl.sDraw.textCenter( winnerMsg,                .new( screenCenter.x, screenCenter.y - 192 ), 128, utl.Colour.green  );
  utl.sDraw.textCenter( "Press Enter to restart", .new( screenCenter.x, screenCenter.y       ),  64, utl.Colour.yellow );
  utl.sDraw.textCenter( "Press Escape to exit",   .new( screenCenter.x, screenCenter.y + 128 ),  64, utl.Colour.yellow );
}

fn drawOpenedOverlay( ng : *Engine, screenCenter : Vec2 ) void
{
  if( ng.state != .OPENED ){ return; }

  utl.sDraw.coverScreenWithCol( .new( 0, 0, 0, 128 ));

  if( WINNER == .NONE ){ drawPauseControls( screenCenter ); }
}


pub fn OnRenderOverlay( ng : *Engine ) void
{
  const screenCenter = utl.getHalfScreenSize();

  drawScores( screenCenter );
  drawOpenedOverlay( ng, screenCenter );

  if( WINNER != .NONE )
  {
    drawWinnerOverlay( screenCenter );
  }
  else if( ng.state == .OPENED )
  {
    utl.sDraw.textCenter( "Press Enter to resume", .new( screenCenter.x, screenCenter.y - 128 ), 128, utl.Colour.yellow );
  }
}
