const std = @import( "std" );
const def = @import( "defs" );

pub var EXAMPLE_NTT_ID : u32 = 0;
pub var EXAMPLE_TLM_ID : u32 = 0;

// ================================ STATE INJECTION FUNCTIONS ================================
// These functions are called by the engine whenever it changes state ( see changeState() in engine.zig )

pub fn OnStart( ng : *def.Engine ) void // Called by engine.start()    // NOTE : This is where you should initialize your resources
{
  ng.addAudioFromFile( "hit_1", "exampleGames/assets/sounds/Boop_2.wav" ) catch | err |
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
  if( ng.loadEntityFromParams(
  .{
    .shape  = .DSTR,
    .scale  = .{ .x = 62, .y = 62 },
    .colour = def.Colour.white,
    .pos    = .{ .x = 512, .y = 0, .r = 0 },
  })
  )| ntt |{ EXAMPLE_NTT_ID = ntt.id; } else { def.qlog( .ERROR, 0, @src(), "Failed to create example entity" ); }

  if( ng.loadTilemapFromParams(
  .{
    .gridPos   = def.VecR.new( -512, 0, def.DtR( 0 )),
    .gridSize  = .{ .x = 5,  .y = 5  },
    .tileScale = .{ .x = 64, .y = 64 },
    .tileShape = .TRIA,
  }, .FLOOR )
  )| tlm |{ EXAMPLE_TLM_ID = tlm.id; } else { def.qlog( .ERROR, 0, @src(), "Failed to create example tilemap" ); }
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





