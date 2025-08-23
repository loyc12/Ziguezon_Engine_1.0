const std  = @import( "std" );
const def  = @import( "defs" );

const Vec2    = def.Vec2;
const VecR    = def.VecR;
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


// ================================ TILE TO POS ================================

pub fn getAbsTilePos( tlmp : *const Tilemap, gridCoords : Coords2 ) ?VecR
{
  const  tilePos = getRelTilePos( tlmp, gridCoords ) orelse return null;
  return tilePos.rot( tlmp.gridPos.r ).add( tlmp.gridPos );
}

pub fn getRelTilePos( tlmp : *const Tilemap, gridCoords : Coords2 ) ?VecR
{
  if( !tlmp.isCoordsValid( gridCoords )){ return null; }

  const X = @as( f32, @floatFromInt( gridCoords.x )) - ( @as( f32, @floatFromInt( tlmp.gridSize.x - 1 )) / 2.0 );
  const Y = @as( f32, @floatFromInt( gridCoords.y )) - ( @as( f32, @floatFromInt( tlmp.gridSize.y - 1 )) / 2.0 );

  const rowOffset : f32 = switch( @mod( gridCoords.x, 2 ))
  {
    0 => 0.0,
    1 => 0.5,
    else => 0.0, // Should never happen
  };

  var pos : VecR = undefined;


  switch( tlmp.tileShape )
  {
    .RECT => { pos = VecR.new( X, Y, 0 ); },

    .DIAM => { pos = VecR.new(( X - Y ), ( X + Y ), 0 ).mulVal( R2I ); },

    // Upright triangle
    .TRI1 =>
    {
      //const parity = ( 1 == @mod( gridCoords.x, 2 ));
//
      //const baseX  = X; //( X * 1 );
      //const baseY  = Y; //( Y * R3 );
//
      //if( parity ){ pos = VecR.new( baseX + ( HR3 / 3.0 ), baseY, 0 ); }
      //else        { pos = VecR.new( baseX - ( HR3 / 3.0 ), baseY, 0 ); }

      pos = VecR.new( X * 1.5, ( Y + rowOffset ) * R3, 0 );
    },

    // Sideways triangle
    .TRI2 => { pos = VecR.new(( X + rowOffset ) * R3, Y * 1.5, 0 ); },

    // Pointy top hexagon
    .HEX1 => { pos = VecR.new(( X + rowOffset ) * R3, Y * 1.5, 0 ); },

    // Flat top hexagon
    .HEX2 => { pos = VecR.new( X * 1.5, ( Y + rowOffset ) * R3, 0 ); },
  }
  return pos.mul( tlmp.tileScale.toVecR( 0 ));
}

// ================================ POS TO TILE ================================

pub fn getCoordsFromAbsPos( tlmp : *const Tilemap, pos : VecR ) ?Coords2
{
  const relPos = pos.sub( tlmp.gridPos ).rot( -tlmp.gridPos.r );

  if( relPos.lenSqr() > tlmp.gridSize.toVec2().mulVal( 0.5 ).mul( tlmp.tileScale ).lenSqr() )
  {
    def.log( .DEBUG, 0, @src(), "Position {d}:{d} is out of bounds for tilemap {d} with scale {d}:{d}", .{ relPos.x, relPos.y, tlmp.id, tlmp.gridSize.x, tlmp.gridSize.y });
    return null;
  }

  return getCoordsFromRelPos( tlmp, relPos );
}

pub fn getCoordsFromRelPos( tlmp : *const Tilemap, pos : VecR ) ?Coords2
{
  const X =  pos.x / tlmp.tileScale.x;
  const Y =  pos.y / tlmp.tileScale.y;
  const R = -pos.r;

  // TODO : check if the tile is in bounds first

  _ = X + Y + R; // prevent unused variable warning

  def.log( .ERROR, 0, @src(), "getCoordsFromRelPos() is not implemented for tile shape {s}", .{ tlmp.tileShape });

  return null;
}

// ================================ TILE DRAWING ================================

pub fn drawTileShape( tlmp : *const Tilemap, tile : *const Tile ) void
{
  //def.log( .DEBUG, 0, @src(), "Drawing tile at position {d}:{d} in tilemap {d}", .{ tile.gridCoords.x, tile.gridCoords.y, tlmp.id });
  const pos = getAbsTilePos( tlmp, tile.gridCoords ) orelse
  {
    def.log( .ERROR, 0, @src(), "Tile at position {d}:{d} does not exist in tilemap {d}", .{ tile.gridCoords.x, tile.gridCoords.y, tlmp.id });
    return;
  };

  // TODO : check if pos is in or near screen bounds first

  switch( tlmp.tileShape )
  {
    .TRI1 =>
    {
      //const parity = ( 1 == @mod( tile.gridCoords.x, 2 ));
      //if( parity ){ def.drawTria( pos.toVec2(), tlmp.tileScale.mulVal( 0.5 ), pos.r + def.DtR(   0 ), tile.colour ); }
      //else        { def.drawTria( pos.toVec2(), tlmp.tileScale.mulVal( 0.5 ), pos.r + def.DtR( 180 ), tile.colour ); }

      def.drawCircle( pos.toVec2(), tlmp.tileScale.mulVal( 0.5 ).len(), tile.colour ); // NOTE : TEMP
    },

    .TRI2 =>
    {
      def.drawCircle( pos.toVec2(), tlmp.tileScale.mulVal( 0.5 ).len(), tile.colour ); // NOTE : TEMP
    },

    .RECT =>
    {
      def.drawRect( pos.toVec2(), tlmp.tileScale.mulVal( 0.5 ), pos.r, tile.colour );
    },

    .DIAM =>
    {
      def.drawDiam( pos.toVec2(), tlmp.tileScale.mulVal( R2I ), pos.r, tile.colour );
    },

    .HEX1 =>
    {
      def.drawPoly( pos.toVec2(), tlmp.tileScale.mulVal( HR3 ), pos.r - def.DtR( 90 ), tile.colour, 6 );
    },

    .HEX2 =>
    {
      def.drawPoly( pos.toVec2(), tlmp.tileScale.mulVal( HR3 ), pos.r, tile.colour, 6 );
    },
  }
}