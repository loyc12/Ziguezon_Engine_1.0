const std  = @import( "std" );
const def  = @import( "defs" );

const Angle   = def.Angle;

const Vec2    = def.Vec2;
const VecA    = def.VecA;
const Coords2 = def.Coords2;

const Tile    = def.Tile;
const Tilemap = def.Tilemap;

pub const e_tlmp_shape = enum( u8 ) // TODO : fix worldPoint - > tileCoords
{
  RECT, // []
  DIAM, // <>

  TRI1, // /\  ( upright )
  TRI2, // >   ( sideways )

  HEX1, // <_> ( pointy top )
  HEX2, // <_> ( flat top )
};

const R2 = @sqrt( 2.0 );
const R3 = @sqrt( 3.0 );

const R2I = 1.0 / R2;
const R3I = 1.0 / R3;

const HR2 = R2 / 2.0;
const HR3 = R3 / 2.0;

const HEX_FACTOR = 1.0 - ( HR3 / 6.0 ); // Factor to multiply hex tile pos by to get correct spacing


// ================================ TILE TO POS ================================

pub fn getAbsTilePos( tlmp : *const Tilemap, gridCoords : Coords2 ) ?VecA
{
  const  tilePos = getRelTilePos( tlmp, gridCoords ) orelse return null;
  return tilePos.rot( tlmp.gridPos.a ).add( tlmp.gridPos );
}

pub fn getRelTilePos( tlmp : *const Tilemap, gridCoords : Coords2 ) ?VecA
{
  if( !tlmp.isCoordsValid( gridCoords )){ return null; }

  const X = @as( f32, @floatFromInt( gridCoords.x )) - ( @as( f32, @floatFromInt( tlmp.gridSize.x - 1 )) / 2.0 );
  const Y = @as( f32, @floatFromInt( gridCoords.y )) - ( @as( f32, @floatFromInt( tlmp.gridSize.y - 1 )) / 2.0 );

  var pos : VecA = undefined;

  switch( tlmp.tileShape )
  {
    // Rectangle ( scaled along axis )
    .RECT => { pos = VecA.new( X, Y, null ); },

    // Diamond ( scaled along diagonals )
    .DIAM => { pos = VecA.new(( X - Y ), ( X + Y ), null ).mulVal( R2I ); },

    // Upright triangle
    .TRI1 =>
    {
      const offset : f32 = ( @as( f32, @floatFromInt( @mod( gridCoords.x + gridCoords.y, 2 ))) - 0.5 ) / 3;
      pos = VecA.new( X * HEX_FACTOR , ( Y - offset ) * R3 * HEX_FACTOR, null );
    },

    // Sideways triangle
    .TRI2 =>
    {
      const offset : f32 = ( @as( f32, @floatFromInt( @mod( gridCoords.x + gridCoords.y, 2 ))) - 0.5 ) / 3;
      pos = VecA.new(( X - offset ) * R3 * HEX_FACTOR , Y * HEX_FACTOR, null );
    },

    // Pointy top hexagon
    .HEX1 =>
    {
      const xOffset : f32 = @as( f32, @floatFromInt( @mod( gridCoords.y, 2 ))) * 0.5;
      pos = VecA.new(( X + xOffset ) * R3 * HEX_FACTOR , Y * 1.5 * HEX_FACTOR, null );
    },

    // Flat top hexagon
    .HEX2 =>
    {
      const yOffset : f32 = @as( f32, @floatFromInt( @mod( gridCoords.x, 2 ))) * 0.5;
      pos = VecA.new( X * 1.5 * HEX_FACTOR , ( Y + yOffset ) * R3 * HEX_FACTOR, null );
    },
  }
  return pos.mul( tlmp.tileScale.toVecA( null ));
}

// ================================ POS TO TILE ================================

pub fn getCoordsFromAbsPos( tlmp : *const Tilemap, pos : Vec2 ) ?Coords2
{
  const relPos = pos.sub( tlmp.gridPos.toVec2() ).rot( tlmp.gridPos.a.neg() );

  if( relPos.lenSqr() > tlmp.gridSize.toVec2().mulVal( 0.5 ).mul( tlmp.tileScale ).lenSqr() )
  {
    def.log( .DEBUG, 0, @src(), "Position {d}:{d} is out of bounds for tilemap {d} with scale {d}:{d}", .{ relPos.x, relPos.y, tlmp.id, tlmp.gridSize.x, tlmp.gridSize.y });
    return null;
  }

  return getCoordsFromRelPos( tlmp, relPos );
}

pub fn getCoordsFromRelPos( tlmp : *const Tilemap, pos : Vec2 ) ?Coords2
{
  const X = pos.x / tlmp.tileScale.x;
  const Y = pos.y / tlmp.tileScale.y;

  // TODO : check if the tile is in bounds first

  _ = X + Y; // prevent unused variable warning

  def.log( .ERROR, 0, @src(), "getCoordsFromRelPos() is not implemented for tile shape {}", .{ tlmp.tileShape });

  return null;
}

// ================================ TILE DRAWING ================================

pub fn drawTileShape( tlmp : *const Tilemap, tile : *const Tile ) void
{
  const pos = getAbsTilePos( tlmp, tile.gridCoords ) orelse
  {
    def.log( .ERROR, 0, @src(), "Tile at position {d}:{d} does not exist in tilemap {d}", .{ tile.gridCoords.x, tile.gridCoords.y, tlmp.id });
    return;
  };

  // TODO : check if pos is in or near screen bounds first

  switch( tlmp.tileShape )
  {
    .RECT =>
    {
      def.drawRect( pos.toVec2(), tlmp.tileScale.mulVal( 0.5 ), pos.a, tile.colour );
    },

    .DIAM =>
    {
      def.drawDiam( pos.toVec2(), tlmp.tileScale.mulVal( R2I ), pos.a, tile.colour );
    },

    .TRI1 =>
    {
      const parity = ( 1 == @mod( tile.gridCoords.x + tile.gridCoords.y, 2 ));
      if( parity ){ def.drawTria( pos.toVec2(), tlmp.tileScale.mulVal( 1.0 ), pos.a.addDeg( 90 ), tile.colour ); }
      else        { def.drawTria( pos.toVec2(), tlmp.tileScale.mulVal( 1.0 ), pos.a.subDeg( 90 ), tile.colour ); }
    },

    .TRI2 =>
    {
      const parity = ( 1 == @mod( tile.gridCoords.x + tile.gridCoords.y, 2 ));
      if( parity ){ def.drawTria( pos.toVec2(), tlmp.tileScale.mulVal( 1.0 ), pos.a,               tile.colour ); }
      else        { def.drawTria( pos.toVec2(), tlmp.tileScale.mulVal( 1.0 ), pos.a.addDeg( 180 ), tile.colour ); }
    },

    .HEX1 =>
    {
      def.drawPoly( pos.toVec2(), tlmp.tileScale.mulVal( HR3 ), pos.a.subDeg( 90 ), tile.colour, 6 );
    },

    .HEX2 =>
    {
      def.drawPoly( pos.toVec2(), tlmp.tileScale.mulVal( HR3 ), pos.a, tile.colour, 6 );
    },
  }
}