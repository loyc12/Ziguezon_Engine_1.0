const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

// ================================ GLOBAL IDs ================================

pub var EXAMPLE_TLM_ID : u32 = 0;


// ================================ STATE INJECTION FUNCTIONS ================================

pub fn OnGameStart( ng : *eng.Engine ) void
{
  _ = ng;
}

pub fn OnGameOpen( ng : *eng.Engine ) void
{
  ng.resourceManager.addAudioFromFile( "hit_1", "assets/sounds/Boop_2.wav" ) catch | err |
  {
    utl.log( .ERROR, 0, @src(), "Failed to load audio 'hit_1': {}\n", .{ err } );
  };

  ng.resourceManager.addSpriteFromFile( "cubes_1", .{ .x = 32, .y = 32 }, 256, "assets/textures/Cubes.png" ) catch | err |
  {
    utl.log( .ERROR, 0, @src(), "Failed to load sprite 'cubes_1': {}\n", .{ err } );
  };

  if( ng.tilemapManager.loadTilemapFromParams(
  .{
    .mapPos    = .{ .x = -512, .y = 0 },
    .mapSize   = .{ .x = 8,  .y = 8  },
    .tileScale = .{ .x = 64, .y = 64 },
    .tileShape = .TRI1,
  }, .T1 )
  )| tlm |{ EXAMPLE_TLM_ID = tlm.id; } else { utl.qlog( .ERROR, 0, @src(), "Failed to create example tilemap" ); }
}

