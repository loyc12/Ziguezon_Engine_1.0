const std = @import( "std" );
const def = @import( "defs" );

var BALL_ID : u32 = 0;

// ================================ STATE INJECTION FUNCTIONS ================================
// These functions are called by the engine whenever it changes state ( see changeState() in engine.zig )

pub fn OnStart( ng : *def.Engine ) void // Called by engine.start()    // NOTE : This is where you should initialize your resources
{
  ng.resourceManager.addAudioFromFile( "hit_1", "exampleGames/assets/sounds/Boop_2.wav" ) catch | err |
  {
    def.log( .ERROR, 0, @src(), "Failed to load audio 'hit_2': {}\n", .{ err } );
  };
}
pub fn OnStop( ng : *def.Engine ) void // Called by engine.stop()
{
  _ = ng; // Prevent unused variable warning
}


pub fn OnOpen( ng : *def.Engine ) void // Called by engine.open()      // NOTE : This is where you should initialize your entities
{
  if( ng.entityManager.addEntity( // ball
  .{
    .shape  = .DSTR,
    .scale  = .{ .x = 62, .y = 62 },
    .colour = def.Colour.white,
    .pos    = .{ .x = 512, .y = 0, .z = 0 },
  })
  )| ball |{ BALL_ID = ball.id; } else { def.qlog( .ERROR, 0, @src(), "Failed to create ball entity" ); }
}
pub fn OnClose( ng : *def.Engine ) void // Called by engine.close()
{
  _ = ng; // Prevent unused variable warning
}


pub fn OnPlay( ng : *def.Engine ) void // Called by engine.play()
{
  _ = ng; // Prevent unused variable warning
}
pub fn OnPause( ng : *def.Engine ) void // Called by engine.pause()
{
  _ = ng; // Prevent unused variable warning
}





