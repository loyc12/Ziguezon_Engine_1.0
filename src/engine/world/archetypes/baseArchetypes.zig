const std = @import( "std" );

const worldMgr = @import( "../worldManager.zig" );
const rel      = @import( "../relations/relation.zig" );
const trt      = @import( "../traits/trait.zig" );


/// Minimal generic archetype example: two persistent entities linked together.
/// Games should define domain-specific archetypes under `src/games`.
pub const PersistentLinkArchetype : worldMgr.Archetype =
.{
  .name    = "engine.persistent_link",
  .spawnFn = spawnPersistentLinkArchetype,
};

fn spawnPersistentLinkArchetype( cntx : *worldMgr.ArchetypeSpawnContext ) bool
{
  const root   = cntx.createEntity();
  const linked = cntx.createEntity();

  return cntx.setRootEntity( root )
    and cntx.reportEntity( "linked", linked )
    and cntx.applyTrait( trt.Persistent, root )
    and cntx.applyTrait( trt.Persistent, linked )
    and cntx.addRelation( rel.LinkedTo, root, linked, .{} );
}


// ================================ TESTS ================================

test "PersistentLinkArchetype creates a reusable minimal bundle"
{
  var world : worldMgr.World = .{};
  world.init( std.testing.allocator );
  defer world.deinit();

  try std.testing.expect( world.registerRelation( rel.LinkedTo   ));
  try std.testing.expect( world.registerTrait(    trt.Persistent ));
  try std.testing.expect( world.registerArchetype( PersistentLinkArchetype ));

  const result   = world.spawnArchetype( PersistentLinkArchetype.name ).?;
  const linkedId = result.getReportedId( "linked" ).?;

  try std.testing.expect( world.hasTrait( trt.Persistent, result.rootId ));
  try std.testing.expect( world.hasTrait( trt.Persistent, linkedId       ));
  try std.testing.expect( world.hasRelation( rel.LinkedTo, result.rootId, linkedId ));
}
