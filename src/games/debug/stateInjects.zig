const eng = @import( "engine" );
const utl = @import( "utils" );


// ================================ STATE INJECTION FUNCTIONS ================================

pub fn OnGameStart( ng : *eng.Engine ) void
{
  _ = ng;
}

pub fn OnGameOpen( ng : *eng.Engine ) void
{
  ng.resourceManager.addAudioFromFile( "hit_1", "assets/sounds/Boop_2.wav" ) catch | err |
  {
    utl.log( .ERROR, @src(), "Failed to load audio 'hit_1': {}\n", .{ err } );
  };

  ng.resourceManager.addSpriteFromFile( "cubes_1", .{ .x = 32, .y = 32 }, 256, "assets/textures/Cubes.png" ) catch | err |
  {
    utl.log( .ERROR, @src(), "Failed to load sprite 'cubes_1': {}\n", .{ err } );
  };
}
