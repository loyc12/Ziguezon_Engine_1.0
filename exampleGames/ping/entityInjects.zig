const std = @import( "std" );
const h   = @import( "defs" );

pub fn OnEntityRender( entity : *const h.ntt.entity ) void // Called by entity.renderSelf()
{
  _ = entity; // Prevent unused variable warning
}