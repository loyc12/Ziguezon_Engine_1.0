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

  HEX1, // <_> ( pointy top )
  HEX2, // <_> (  flat top  )

  TRI1, // /\  ( upright )
  TRI2, // >   ( sideway )

//PEN1, // ( upright ) // TODO : implement me
//PEN2, // ( sideway ) // TODO : implement me

  //pub fn getTileScaleFactor( self : e_tlmp_shape ) f32

  pub fn getGridScaleFactors( self : e_tlmp_shape ) Vec2 // TODO : add a getBoundingBox() method to tilemaps
  {
    const base = Vec2.new( 1.0, 1.0 );
    var tmp = switch( self )
    {
      .RECT => base.mulVal( RECT_FACTOR ),
      .DIAM => base.mulVal( DIAM_FACTOR * 2.0 ),
      .HEX1 => Vec2.new( R3,  1.5 ).mulVal( HEXA_FACTOR ),
      .HEX2 => Vec2.new( 1.5, R3  ).mulVal( HEXA_FACTOR ),
      .TRI1 => Vec2.new( HR3, 1.5 ).mulVal( TRIA_FACTOR ),
      .TRI2 => Vec2.new( 1.5, HR3 ).mulVal( TRIA_FACTOR ),
    };
    return tmp.mulVal( 0.5 );
  }

  pub fn getParityOffset( self : e_tlmp_shape, coords : Coords2 ) Vec2
  {
    switch( self )
    {
      .RECT => return .{},
      .DIAM => return .{},
      .HEX1 =>
      {
        //const xOffset = ( @as( f32, @floatFromInt( @mod( coords.y, 2 ))) - 0.5 ) / 2.0;

        const yParity : f32 = @floatFromInt( @mod( coords.y, 2 ));
        const xOffset = ( yParity - 0.5 ) / 2.0;
        return Vec2.new( xOffset, 0.0 );
      },
      .HEX2 =>
      {
        //const yOffset = ( @as( f32, @floatFromInt( @mod( coords.x, 2 ))) - 0.5 ) / 2.0;

        const xParity : f32 = @floatFromInt( @mod( coords.x, 2 ));
        const yOffset = ( xParity - 0.5 ) / 2.0;
        return Vec2.new( 0.0, yOffset );
      },
      .TRI1 =>
      {
        //const yOffset = ( @as( f32, @floatFromInt( @mod( coords.x + coords.y, 2 ))) - 0.5 ) / 3.0;

        const tParity : f32 = @floatFromInt( @mod( coords.x + coords.y, 2 ));
        const yOffset = ( tParity - 0.5 ) / 3.0;
        return Vec2.new( 0.0, yOffset );
      },
      .TRI2 =>
      {
        //const xOffset = ( @as( f32, @floatFromInt( @mod( coords.x + coords.y, 2 ))) - 0.5 ) / 3.0;

        const tParity : f32 = @floatFromInt( @mod( coords.x + coords.y, 2 ));
        const xOffset = ( tParity - 0.5 ) / 3.0;
        return Vec2.new( xOffset, 0.0 );
      },
    }
  }
};

const SIZE_FACTOR   = 1.00; // Base factor to set the size of tiles ( affects all shapes )
const MARGIN_FACTOR = 0.95; // Factor to scale down tiles slightly to leave a margin between them

const RECT_FACTOR = SIZE_FACTOR; // 1x1 square ( R = HR2 )
const DIAM_FACTOR = SIZE_FACTOR * def.getPolyCircum( SIZE_FACTOR, 4 ); // R = 1.0
const HEXA_FACTOR = SIZE_FACTOR * def.getPolyCircum( SIZE_FACTOR, 6 );
const TRIA_FACTOR = SIZE_FACTOR * def.getPolyCircum( SIZE_FACTOR, 3 );
//const PENT_FACTOR = SIZE_FACTOR * def.getPolyCircum( SIZE_FACTOR, 5 );


// ================================ COORDS TO POS ================================

pub fn getAbsTilePos( tlmp : *const Tilemap, gridCoords : Coords2 ) ?VecA
{
  const  tilePos = getRelTilePos( tlmp, gridCoords ) orelse return null;
  return tilePos.rot( tlmp.gridPos.a ).add( tlmp.gridPos );
}

pub fn getRelTilePos( tlmp : *const Tilemap, gridCoords : Coords2 ) ?VecA
{
  if( !tlmp.isCoordsValid( gridCoords )){ return null; }

  const baseX = @as( f32, @floatFromInt( gridCoords.x )) - ( @as( f32, @floatFromInt( tlmp.gridSize.x - 1 )) / 2.0 );
  const baseY = @as( f32, @floatFromInt( gridCoords.y )) - ( @as( f32, @floatFromInt( tlmp.gridSize.y - 1 )) / 2.0 );

  const offset = tlmp.tileShape.getParityOffset( gridCoords );

  const pos = switch( tlmp.tileShape )
  {
    // Rectangle ( scaled along axis )
    .RECT => VecA.new( baseX, baseY, null ).mulVal( RECT_FACTOR ),

    // Diamond ( scaled along diagonals )
    .DIAM => VecA.new(( baseX - baseY ), ( baseX + baseY ), null ).mulVal( DIAM_FACTOR ),

    // Pointy top hexagon
    .HEX1 => VecA.new(( baseX - offset.x ) * R3, baseY * 1.5, null ).mulVal( HEXA_FACTOR ),

    // Flat top hexagon
    .HEX2 => VecA.new( baseX * 1.5, ( baseY - offset.y ) * R3, null ).mulVal( HEXA_FACTOR ),

    // Upright triangle
    .TRI1 => VecA.new( baseX * HR3, ( baseY - offset.y ) * 1.5, null ).mulVal( TRIA_FACTOR ),

    // Sideways triangle
    .TRI2 => VecA.new(( baseX - offset.x ) * 1.5, baseY * HR3, null ).mulVal( TRIA_FACTOR ),
  };

  return pos.mul( tlmp.tileScale.toVecA( .{} )); // TODO : multiply by factors here isntead
}

// ================================ POS TO COORDS ================================

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
      const gridX = @round(( baseX * RECT_FACTOR ) + ( @as( f32, @floatFromInt( tlmp.gridSize.x - 1 )) / 2.0 ));
      const gridY = @round(( baseY * RECT_FACTOR ) + ( @as( f32, @floatFromInt( tlmp.gridSize.y - 1 )) / 2.0 ));

      const coords = Coords2{
        .x = @intFromFloat( gridX ),
        .y = @intFromFloat( gridY ),
      };

      if( !tlmp.isCoordsValid( coords )){ return null; }
      return coords;
    },

    .DIAM =>
    {
      const gridX = @round((( baseX + baseY ) * DIAM_FACTOR ) + ( @as( f32, @floatFromInt( tlmp.gridSize.x - 1 )) / 2.0 ));
      const gridY = @round((( baseY - baseX ) * DIAM_FACTOR ) + ( @as( f32, @floatFromInt( tlmp.gridSize.y - 1 )) / 2.0 ));

      const coords = Coords2{
        .x = @intFromFloat( gridX ),
        .y = @intFromFloat( gridY ),
      };

      if( !tlmp.isCoordsValid( coords )){ return null; }
      return coords;
    },

    .HEX1 =>
    {
      const descaledX = ( baseX / ( HEXA_FACTOR * R3  )) + ( @as( f32, @floatFromInt( tlmp.gridSize.x - 1 )) / 2.0 );
      const rawGridY  = ( baseY / ( HEXA_FACTOR * 1.5 )) + ( @as( f32, @floatFromInt( tlmp.gridSize.y - 1 )) / 2.0 );

      const gridYFract = rawGridY - @floor( rawGridY );

      var coords : Coords2 = undefined;

      if( gridYFract < ( 1.0 / 3.0 ) or gridYFract > ( 2.0 / 3.0 )) // NOTE : not in danger zone : approximation permissible
      {
        const gridY = @round( rawGridY );

        const offset = e_tlmp_shape.HEX1.getParityOffset( Coords2.new( 0.0, @intFromFloat( gridY )));

        const gridX = @round( descaledX + offset.x ) ;

        coords = Coords2{
          .x = @intFromFloat( gridX ),
          .y = @intFromFloat( gridY ),
        };
      }

      else // NOTE : in the danger zone ( tip of the hex ) : need to check distances to centers
      {
        // ======== TILE A ========
        const gridYA = @floor( rawGridY );

        const offsetA = e_tlmp_shape.HEX1.getParityOffset( Coords2.new( 0.0, @intFromFloat( gridYA )));

        const gridXA = @round( descaledX + offsetA.x );

        const coordsA = Coords2{
          .x = @intFromFloat( gridXA ),
          .y = @intFromFloat( gridYA ),
        };

        // ======== TILE B ========
        const gridYB = @ceil( rawGridY );

        const gridXB = @round( descaledX - offsetA.x );

        const coordsB = Coords2{
          .x = @intFromFloat( gridXB ),
          .y = @intFromFloat( gridYB ),
        };

        // ======== DISTANCE COMPARISON ========
        const distToA = pos.getDistSqr( tlmp.getRelTilePos( coordsA ).?.toVec2() );
        const distToB = pos.getDistSqr( tlmp.getRelTilePos( coordsB ).?.toVec2() );

        coords = if( distToA < distToB ) coordsA else coordsB;
      }

      if ( !tlmp.isCoordsValid( coords )){ return null; }
      return coords;
    },
    .HEX2 =>
    {
      const descaledY = ( baseY / ( HEXA_FACTOR * R3  )) + ( @as( f32, @floatFromInt( tlmp.gridSize.y - 1 )) / 2.0 );
      const rawGridX  = ( baseX / ( HEXA_FACTOR * 1.5 )) + ( @as( f32, @floatFromInt( tlmp.gridSize.x - 1 )) / 2.0 );

      const gridXFract = rawGridX - @floor( rawGridX );

      var coords : Coords2 = undefined;

      if( gridXFract < ( 1.0 / 3.0 ) or gridXFract > ( 2.0 / 3.0 )) // NOTE : not in danger zone : approximation permissible
      {
        const gridX = @round( rawGridX );

        const offset = e_tlmp_shape.HEX2.getParityOffset( Coords2.new( @intFromFloat( gridX ), 0.0 ));

        const gridY = @round( descaledY + offset.y) ;

        coords = Coords2{
          .x = @intFromFloat( gridX ),
          .y = @intFromFloat( gridY ),
        };
      }

      else // NOTE : in the danger zone ( tip of the hex ) : need to check distances to centers
      {
        // ======== TILE A ========
        const gridXA = @floor( rawGridX );

        const offsetA = e_tlmp_shape.HEX2.getParityOffset( Coords2.new( @intFromFloat( gridXA ), 0.0 ));

        const gridYA = @round( descaledY + offsetA.y );

        const coordsA = Coords2{
          .x = @intFromFloat( gridXA ),
          .y = @intFromFloat( gridYA ),
        };

        // ======== TILE B ========
        const gridXB = @ceil( rawGridX );

        const gridYB = @round( descaledY - offsetA.y );

        const coordsB = Coords2{
          .x = @intFromFloat( gridXB ),
          .y = @intFromFloat( gridYB ),
        };

        // ======== DISTANCE COMPARISON ========
        const distToA = pos.getDistSqr( tlmp.getRelTilePos( coordsA ).?.toVec2() );
        const distToB = pos.getDistSqr( tlmp.getRelTilePos( coordsB ).?.toVec2() );

        coords = if( distToA < distToB ) coordsA else coordsB;
      }

      if ( !tlmp.isCoordsValid( coords )){ return null; }
      return coords;
    },

    // TODO : implement TRI1 and TRI2

    else => def.log( .WARN, 0, @src(), "getCoordsFromRelPos() is not implemented for tile shape {s}", .{ @tagName( tlmp.tileShape )}),
  }

  return null;
}

// ================================ COORDS TO COORDS ================================

pub fn getNeighbourCoords( tlmp : *const Tilemap, gridCoords : Coords2, direction : def.e_dir_2 ) ?Coords2
{
  const yParity = ( 1 == @mod( gridCoords.y, 2 ));
  const xParity = ( 1 == @mod( gridCoords.x, 2 ));

  const coords = switch( tlmp.tileShape )
  {
    .RECT => switch( direction )
    {
      .NW => gridCoords.add( Coords2.new( -1, -1 )),
      .NO => gridCoords.add( Coords2.new(  0, -1 )),
      .NE => gridCoords.add( Coords2.new(  1, -1 )),
      .EA => gridCoords.add( Coords2.new(  1,  0 )),
      .SE => gridCoords.add( Coords2.new(  1,  1 )),
      .SO => gridCoords.add( Coords2.new(  0,  1 )),
      .SW => gridCoords.add( Coords2.new( -1,  1 )),
      .WE => gridCoords.add( Coords2.new( -1,  0 )),
    },

    .DIAM => switch( direction )
    {
      .NW => gridCoords.add( Coords2.new( -1,  0 )),
      .NO => gridCoords.add( Coords2.new( -1, -1 )),
      .NE => gridCoords.add( Coords2.new(  0, -1 )),
      .EA => gridCoords.add( Coords2.new(  1, -1 )),
      .SE => gridCoords.add( Coords2.new(  1,  0 )),
      .SO => gridCoords.add( Coords2.new(  1,  1 )),
      .SW => gridCoords.add( Coords2.new(  0,  1 )),
      .WE => gridCoords.add( Coords2.new( -1,  1 )),
    },

    .HEX1 => switch( direction )
    {
      .NO => null,
      .SO => null,

      .WE => gridCoords.add( Coords2.new( -1,  0 )),
      .EA => gridCoords.add( Coords2.new(  1,  0 )),

      .NW => if( yParity ) gridCoords.add( Coords2.new( -1, -1 )) else gridCoords.add( Coords2.new(  0, -1 )),
      .NE => if( yParity ) gridCoords.add( Coords2.new(  0, -1 )) else gridCoords.add( Coords2.new(  1, -1 )),

      .SW => if( yParity ) gridCoords.add( Coords2.new( -1,  1 )) else gridCoords.add( Coords2.new(  0,  1 )),
      .SE => if( yParity ) gridCoords.add( Coords2.new(  0,  1 )) else gridCoords.add( Coords2.new(  1,  1 )),
    },

    .HEX2 => switch( direction )
    {
      .WE => null,
      .EA => null,

      .NO => gridCoords.add( Coords2.new(  0, -1 )),
      .SO => gridCoords.add( Coords2.new(  0,  1 )),

      .NW => if( xParity ) gridCoords.add( Coords2.new( -1, -1 )) else gridCoords.add( Coords2.new( -1,  0 )),
      .SW => if( xParity ) gridCoords.add( Coords2.new( -1,  0 )) else gridCoords.add( Coords2.new( -1,  1 )),

      .NE => if( xParity ) gridCoords.add( Coords2.new(  1, -1 )) else gridCoords.add( Coords2.new(  1,  0 )),
      .SE => if( xParity ) gridCoords.add( Coords2.new(  1,  0 )) else gridCoords.add( Coords2.new(  1,  1 )),
    },

    // TODO : implement TRI1 and TRI2

    else => null, // TODO : implement me
  }
  orelse
  {
    def.log( .TRACE, 0, @src(), "Tilemap shape {s} does not support direction {s}", .{ @tagName( tlmp.tileShape ), @tagName( direction )});
    return null;
  };

  if( !tlmp.isCoordsValid( coords )){ return null; }
  return coords;
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


  const dParity : f32 = @floatFromInt(( 2 * @mod( tile .gridCoords.x + tile .gridCoords.y, 2 )) - 1 );

  switch( tlmp.tileShape )
  {
    .RECT => def.drawRect( pos.toVec2(), tlmp.tileScale.mulVal( RECT_FACTOR * MARGIN_FACTOR * 0.5 ), pos.a, tile.colour ),
    .DIAM => def.drawDiam( pos.toVec2(), tlmp.tileScale.mulVal( DIAM_FACTOR * MARGIN_FACTOR ),       pos.a, tile.colour ),

    .HEX1 => def.drawHexa( pos.toVec2(), tlmp.tileScale.mulVal( HEXA_FACTOR * MARGIN_FACTOR ), pos.a.subDeg( 90.0 ), tile.colour ),
    .HEX2 => def.drawHexa( pos.toVec2(), tlmp.tileScale.mulVal( HEXA_FACTOR * MARGIN_FACTOR ), pos.a,                tile.colour ),

    .TRI1 => def.drawTria( pos.toVec2(), tlmp.tileScale.mulVal( TRIA_FACTOR * MARGIN_FACTOR ), pos.a.addDeg(  dParity * 90.0 ),        tile.colour ),
    .TRI2 => def.drawTria( pos.toVec2(), tlmp.tileScale.mulVal( TRIA_FACTOR * MARGIN_FACTOR ), pos.a.subDeg(( dParity * 90.0 ) - 90 ), tile.colour ),
  }
}