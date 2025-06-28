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

pub fn OnUpdate( ng : *eng.engine ) void // Called by engine.update() ( every frame, no exception )
{
  // Toggle pause if the P key is pressed
  if( h.rl.isKeyPressed( h.rl.KeyboardKey.p )){ ng.togglePause(); }

  // Move entity 1 with A and D keys
  if( h.rl.isKeyDown( h.rl.KeyboardKey.a )){ ng.entityManager.entities.items[ 0 ].pos.x -= 4.0; }
  if( h.rl.isKeyDown( h.rl.KeyboardKey.d )){ ng.entityManager.entities.items[ 0 ].pos.x += 4.0; }

  // Move entity 2 with Side Arrow keys
  if( h.rl.isKeyDown( h.rl.KeyboardKey.left  )){ ng.entityManager.entities.items[ 1 ].pos.x -= 4.0; }
  if( h.rl.isKeyDown( h.rl.KeyboardKey.right )){ ng.entityManager.entities.items[ 1 ].pos.x += 4.0; }
}

pub fn OnTick( ng : *eng.engine ) void // Called by engine.tick() ( every frame, when not paused )
{
  ng.entityManager.entities.items[ 3 ].pos.y += 4.0; // Move the ball down

  if( ng.entityManager.entities.items[ 3 ].pos.y > 512 )
  {
    ng.entityManager.entities.items[ 3 ].pos.y = -256; // Reset the ball position
  }

  return;
}

pub fn OnRenderWorld( ng : *eng.engine ) void // Called by engine.render()
{
  _ = ng; // Prevent unused variable warning
  return;
}

pub fn OnRenderOverlay( ng : *eng.engine ) void // Called by engine.render()
{
  _ = ng; // Prevent unused variable warning
  return;
}