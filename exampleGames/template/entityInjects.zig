const std = @import( "std" );
const h   = @import( "defs" );

// ================================ ENTITY INJECTION FUNCTIONS ================================
// These functions are called by the engine during specific entity "method" calls

pub fn OnEntityRender( entity : *const h.ntt.entity ) void // Called by entity.renderSelf()
{
  _ = entity; // Prevent unused variable warning
}