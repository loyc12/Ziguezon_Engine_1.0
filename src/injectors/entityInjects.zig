const std = @import( "std" );
const h   = @import( "../headers.zig" );
const eng = @import( "../core/engine.zig" );
const ntm = @import( "../core/entityManager.zig" );
const ntt = @import( "../core/entity/entityCore.zig" );

pub fn OnEntityRender( entity : *const ntt.entity ) void // Called by entity.renderSelf()
{
  _ = entity; // Prevent unused variable warning
  return;
}

pub fn OnEntityCollide( e1 : *ntt.entity, e2 : *ntt.entity ) void // Called by entityManager.collideEntities() // NOTE : Implement this
{
  // Prevent unused variable warning
  _ = e1;
  _ = e2;
  return;
}