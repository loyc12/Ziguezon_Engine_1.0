const std  = @import( "std" );
const def  = @import( "defs" );

const Angle   = def.Angle;

const Vec2    = def.Vec2;
const VecA    = def.VecA;
const Coords2 = def.Coords2;

const Tile    = def.Tile;
const Tilemap = def.Tilemap;

const R2  = def.R3;
const R3  = def.R3;

const IR2 = 1.0 / R2;
const IR3 = def.IR3;

const HR2 = def.HR2;
const HR3 = def.HR3;

pub const e_tlmp_shape = enum( u8 ) // TODO : fix worldPoint - > tileCoords
{
  RECT, // []
  DIAM, // <>

  TRI1, // /\  ( upright )
  TRI2, // >   ( sideway )

  HEX1, // <_> ( pointy top )
  HEX2, // <_> (  flat top  )

//PEN1, // ( upright )
//PEN2, // ( sideway )
};

const SIZE_FACTOR   = 1.0;   // Base factor to set the size of tiles ( affects all shapes )
const MARGIN_FACTOR = 0.95; // Factor to scale down tiles slightly to leave a margin between them

const RECT_FACTOR = SIZE_FACTOR; // 1x1 square ( R = HR2 )
const DIAM_FACTOR = SIZE_FACTOR * def.getPolyCircum( SIZE_FACTOR, 4 ); // R = 1.0

const TRIA_FACTOR = SIZE_FACTOR * def.getPolyCircum( SIZE_FACTOR, 3 );
const HEXA_FACTOR = SIZE_FACTOR * def.getPolyCircum( SIZE_FACTOR, 6 );

//const PENT_FACTOR = SIZE_FACTOR * def.getPolyCircum( SIZE_FACTOR, 5 );


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
    .RECT => { pos = VecA.new( X, Y, null ).mulVal( RECT_FACTOR ); },

    // Diamond ( scaled along diagonals )
    .DIAM => { pos = VecA.new(( X - Y ), ( X + Y ), null ).mulVal( DIAM_FACTOR ); },

    // Upright triangle
    .TRI1 =>
    {
      const offset : f32 = ( @as( f32, @floatFromInt( @mod( gridCoords.x + gridCoords.y, 2 ))) - 0.5 ) / 3;
      pos = VecA.new( X * HR3, ( Y - offset ) * 1.5, null ).mulVal( TRIA_FACTOR );
    },

    // Sideways triangle
    .TRI2 =>
    {
      const offset : f32 = ( @as( f32, @floatFromInt( @mod( gridCoords.x + gridCoords.y, 2 ))) - 0.5 ) / 3;
      pos = VecA.new(( X - offset ) * 1.5, Y * HR3, null ).mulVal( TRIA_FACTOR );
    },

    // Pointy top hexagon
    .HEX1 =>
    {
      const xOffset : f32 = @as( f32, @floatFromInt( @mod( gridCoords.y, 2 ))) * 0.5;
      pos = VecA.new(( X + xOffset ) * R3, Y * 1.5, null ).mulVal( HEXA_FACTOR );
    },

    // Flat top hexagon
    .HEX2 =>
    {
      const yOffset : f32 = @as( f32, @floatFromInt( @mod( gridCoords.x, 2 ))) * 0.5;
      pos = VecA.new( X * 1.5, ( Y + yOffset ) * R3, null ).mulVal( HEXA_FACTOR );
    },
  }
  return pos.mul( tlmp.tileScale.toVecA( null ));
}

// ================================ POS TO TILE ================================

pub fn getCoordsFromAbsPos( tlmp : *const Tilemap, pos : Vec2 ) ?Coords2
{
  const relPos = pos.sub( tlmp.gridPos.toVec2() ).rot( tlmp.gridPos.a.neg() );

  const maxX = tlmp.tileScale.x * HR2 * @as( f32, @floatFromInt( tlmp.gridSize.x ));
  const maxY = tlmp.tileScale.y * HR2 * @as( f32, @floatFromInt( tlmp.gridSize.y ));

  // Preleminary check to see if pos is even in tilemap bounds
  if( relPos.x < -maxX or relPos.x > maxX or relPos.y < -maxY or relPos.y > maxY )
  {
    def.log( .DEBUG, 0, @src(), "Position {d},{d} is out of tilemap bounds", .{ relPos.x, relPos.y });
    return null;
  }

  return getCoordsFromRelPos( tlmp, relPos );
}

pub fn getCoordsFromRelPos( tlmp : *const Tilemap, pos : Vec2 ) ?Coords2
{
  const baseX = pos.x / tlmp.tileScale.x;
  const baseY = pos.y / tlmp.tileScale.y;

  switch( tlmp.tileShape )
  {
    .RECT =>
    {
      const gridX = @round( baseX + ( @as( f32, @floatFromInt( tlmp.gridSize.x - 1 )) / 2.0 ));
      const gridY = @round( baseY + ( @as( f32, @floatFromInt( tlmp.gridSize.y - 1 )) / 2.0 ));

      const coords = Coords2{
        .x = @intFromFloat( gridX ),
        .y = @intFromFloat( gridY ),
      };

      if( !tlmp.isCoordsValid( coords )){ return null; }
      return coords;
    },

    .DIAM =>
    {
      const gridX = @round(( baseX + baseY ) * IR2 + ( @as( f32, @floatFromInt( tlmp.gridSize.x - 1 )) / 2.0 ));
      const gridY = @round(( baseY - baseX ) * IR2 + ( @as( f32, @floatFromInt( tlmp.gridSize.y - 1 )) / 2.0 ));

      const coords = Coords2{
        .x = @intFromFloat( gridX ),
        .y = @intFromFloat( gridY ),
      };

      if( !tlmp.isCoordsValid( coords )){ return null; }
      return coords;
    },

    else => def.log( .ERROR, 0, @src(), "getCoordsFromRelPos() is not implemented for tile shape {s}", .{ @tagName( tlmp.tileShape )}),
  }

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
      def.drawRect( pos.toVec2(), tlmp.tileScale.mulVal( RECT_FACTOR * MARGIN_FACTOR * 0.5 ), pos.a, tile.colour );
    },

    .DIAM =>
    {
      def.drawDiam( pos.toVec2(), tlmp.tileScale.mulVal( DIAM_FACTOR * MARGIN_FACTOR ), pos.a, tile.colour );
    },

    .TRI1 =>
    {
      const parity = ( 1 == @mod( tile.gridCoords.x + tile.gridCoords.y, 2 ));
      if( parity ){ def.drawTria( pos.toVec2(), tlmp.tileScale.mulVal( TRIA_FACTOR * MARGIN_FACTOR ), pos.a.addDeg( 90 ), tile.colour ); }
      else        { def.drawTria( pos.toVec2(), tlmp.tileScale.mulVal( TRIA_FACTOR * MARGIN_FACTOR ), pos.a.subDeg( 90 ), tile.colour ); }
    },

    .TRI2 =>
    {
      const parity = ( 1 == @mod( tile.gridCoords.x + tile.gridCoords.y, 2 ));
      if( parity ){ def.drawTria( pos.toVec2(), tlmp.tileScale.mulVal( TRIA_FACTOR * MARGIN_FACTOR ), pos.a,               tile.colour ); }
      else        { def.drawTria( pos.toVec2(), tlmp.tileScale.mulVal( TRIA_FACTOR * MARGIN_FACTOR ), pos.a.addDeg( 180 ), tile.colour ); }
    },

    .HEX1 =>
    {
      def.drawPoly( pos.toVec2(), tlmp.tileScale.mulVal( HEXA_FACTOR * MARGIN_FACTOR ), pos.a.subDeg( 90 ), tile.colour, 6 );
    },

    .HEX2 =>
    {
      def.drawPoly( pos.toVec2(), tlmp.tileScale.mulVal( HEXA_FACTOR * MARGIN_FACTOR ), pos.a, tile.colour, 6 );
    },
  }
}