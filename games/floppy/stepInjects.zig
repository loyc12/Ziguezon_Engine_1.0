const std      = @import( "std" );
const eng      = @import( "engine" );
const utl = @import( "utils" );
const stateInj = @import( "stateInjects.zig" );

// ================================ HELPER FUNCTIONS ================================


// ================================ GLOBAL GAME VARIABLES ================================

const GRAVITY    : f32 = 6000.0;  // Base gravity of the disk
const JUMP_FORCE : f32 = 80000.0; // Instant force applied when the disk jumps
const MAX_VEL_Y  : f32 = 2000.0;  // Maximum vertical velocity of the disk

//var SCROLL_SPEED : f32 = 100.0; // Base speed of the pillars
var SCORE        : u8  = 0;     // Score of the player

var IS_GAME_OVER  : bool = false; // Flag to check if the game is over ( hit bottom of screen or pillar )
var IS_JUMPING    : bool = false; // Flag to check if the disk is jumping



const DISK_ID        = &stateInj.DISK_ID;
const TransformStore = stateInj.TransformStore;
const ShapeStore     = stateInj.ShapeStore;


// ================================ STEP INJECTION FUNCTIONS ================================

pub fn OnUpdateFrame( ng : *eng.Engine ) void
{

  // Toggle pause if the P key is pressed
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.p ) or utl.ray.isKeyPressed( utl.ray.KeyboardKey.enter ))
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
        utl.log( .WARN, 0, @src(), "Failed to find Transform component for Entity {}", .{ DISK_ID.* });
        return;
      };

      diskTransform.pos = stateInj.diskStartPos;
      diskTransform.vel = stateInj.diskStartVel;
      diskTransform.acc = .{};

      utl.qlog( .INFO, 0, @src(), "Game reseted" );
    }
  }

  if( ng.state == .PLAYING ) // If the game is launched, check for input
  {
    if( IS_GAME_OVER ){ ng.changeState( .OPENED ); return; }

    if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.space ) or
        utl.ray.isKeyPressed( utl.ray.KeyboardKey.up ) or
        utl.ray.isKeyPressed( utl.ray.KeyboardKey.w ))
    {
      IS_JUMPING = true;
    }
  }
}


pub fn OnTickWorld( ng : *eng.Engine ) void
{
  const transformStore : *TransformStore = @ptrCast( @alignCast( ng.componentRegistry.get( "transformStore" )));

  var diskTransform = transformStore.get( DISK_ID.* ) orelse
  {
    utl.log( .WARN, 0, @src(), "Failed to find Transform component for Entity {}", .{ DISK_ID.* });
    return;
  };


  const shapeStore : *ShapeStore = @ptrCast( @alignCast( ng.componentRegistry.get( "shapeStore" )));

  var diskShape = shapeStore.get( DISK_ID.* ) orelse
  {
    utl.log( .WARN, 0, @src(), "Failed to find Shape component for Entity {}", .{ DISK_ID.* });
    return;
  };


  // ================ APPLYING ACC AND VEL ================

  diskTransform.vel.y = utl.clmp( diskTransform.vel.y, -MAX_VEL_Y, MAX_VEL_Y );

  if( IS_JUMPING ) // Apply jump force
  {
    diskTransform.acc.y = -JUMP_FORCE;

    if( diskTransform.vel.y > 0 ){ diskTransform.vel.y = 0; }

    IS_JUMPING = false;

    SCORE += 1; // NOTE : DEBUG SCORE ( 1 POINT PER JUMP )
  }
  else { diskTransform.acc.y = GRAVITY; } // Apply gravity


  diskTransform.updatePos( ng.getTargetTickSDT() );


  // ================ CLAMPING THE DISK POSITIONS ================

  const hHeight : f64 = utl.getHalfScreenHeight();

  const hitbox = diskShape.getAABB( diskTransform.pos );

  if( hitbox.getTopY() < -hHeight )
  {
    diskTransform.pos.y = -hHeight + hitbox.scale.y;
    diskTransform.vel.y = 0;
  }

  if( hitbox.getBottomY() > hHeight )
  {
    utl.log( .DEBUG, 0, @src(), "Disk {d} has fallen off the screen", .{ DISK_ID.* });
    IS_GAME_OVER = true;
    return;
  }


  // ================ DISK-PILLAR COLLISIONS ================


  // DEBUG INFO

  //utl.qlog( .DEBUG, 0, @src(), "DISK DATA" );
  //utl.log(  .CONT,  0, @src(), "pos.y :{}", .{ disk.pos.y });
  //utl.log(  .CONT,  0, @src(), "vel.y :{}", .{ disk.vel.y });
  //utl.log(  .CONT,  0, @src(), "acc.y :{}", .{ disk.acc.y });

}

pub fn OffTickWorld( ng : *eng.Engine ) void
{
  _ = ng;
}


pub fn OnRenderWorld( ng : *eng.Engine ) void
{
  const transformStore : *TransformStore = @ptrCast( @alignCast( ng.componentRegistry.get( "transformStore" )));

  const diskTransform = transformStore.get( DISK_ID.* ) orelse
  {
    utl.log( .WARN, 0, @src(), "Failed to find Transform component for Entity {}", .{ DISK_ID.* });
    return;
  };

  const shapeStore : *ShapeStore = @ptrCast( @alignCast( ng.componentRegistry.get( "shapeStore" )));

  const diskShape = shapeStore.get( DISK_ID.* ) orelse
  {
    utl.log( .WARN, 0, @src(), "Failed to find Shape component for Entity {}", .{ DISK_ID.* });
    return;
  };

  diskShape.render( diskTransform.pos );
}


pub fn OnRenderOverlay( ng : *eng.Engine ) void
{
  // Declare the buffer to hold the formatted scores
  var s_buff : [ 6:0 ]u8 = std.mem.zeroes( [ 6:0 ]u8 );

  // Convert the score to strings
  const s_slice = std.fmt.bufPrint( &s_buff, "{d}", .{ SCORE }) catch | err |
  {
      utl.log(.ERROR, 0, @src(), "Failed to format score : {}", .{err});
      return;
  };

  s_buff[ s_slice.len ] = 0;


  const halfScreenSize = utl.getHalfScreenSize();

  utl.sDraw.textCenter( &s_buff, .new( halfScreenSize.x * 1.6, halfScreenSize.y ), 128, utl.Colour.yellow );


  if( ng.state == .OPENED ) // NOTE : Greys out the game when it is paused
  {
    utl.sDraw.coverScreenWithCol( .new( 0, 0, 0, 128 ));
  }


  if( IS_GAME_OVER ) // If the player lost, display the game over message
  {
    const game_over_msg = "Final score : ";

    utl.sDraw.textCenter( game_over_msg ++ &s_buff, .new( halfScreenSize.x, halfScreenSize.y - 192 ), 128, utl.Colour.red );
    utl.sDraw.textCenter( "Press Enter to restart", .new( halfScreenSize.x, halfScreenSize.y       ),  64, utl.Colour.yellow );
    utl.sDraw.textCenter( "Press Escape to exit",   .new( halfScreenSize.x, halfScreenSize.y + 128 ),  64, utl.Colour.yellow );
  }
  else if( ng.state == .OPENED ) // If the game is paused, display the resume message
  {
    utl.sDraw.textCenter( "Press Enter to resume",   .new( halfScreenSize.x, halfScreenSize.y - 256 ), 64, utl.Colour.yellow );
    utl.sDraw.textCenter( "Press Escape to exit",    .new( halfScreenSize.x, halfScreenSize.y - 128 ), 64, utl.Colour.yellow );
    utl.sDraw.textCenter( "Press W, Up or Space to", .new( halfScreenSize.x, halfScreenSize.y + 128 ), 64, utl.Colour.yellow );
    utl.sDraw.textCenter( "jump during the game",    .new( halfScreenSize.x, halfScreenSize.y + 256 ), 64, utl.Colour.yellow );
  }
}