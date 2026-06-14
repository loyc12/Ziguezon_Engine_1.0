const tileCore  = @import( "tile.zig" );
const tilemap   = @import( "tilemap.zig" );
const tlmpFlood = @import( "tilemapFlood.zig" );
const tlmpShape = @import( "tilemapShape.zig" );

pub const Tile         = tileCore.Tile;
pub const TileFlags    = tileCore.TileFlags;
pub const TileType     = tileCore.TileType;

pub const Tilemap      = tilemap.Tilemap;
pub const TilemapFlags = tilemap.TilemapFlags;

pub const FloodRule    = tlmpFlood.FloodRule;
pub const TilemapShape = tlmpShape.TilemapShape;

test "legacy tilemap declarations"
{
  const std = @import( "std" );

  std.testing.refAllDecls( tilemap   );
  std.testing.refAllDecls( tlmpFlood );
  std.testing.refAllDecls( tlmpShape );
}
