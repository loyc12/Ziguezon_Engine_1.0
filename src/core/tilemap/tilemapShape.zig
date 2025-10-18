const std     = @import( "std" );
const def     = @import( "defs" );

const Tile    = def.Tile;
const Tilemap = def.Tilemap;

const Angle   = def.Angle;
const Box2    = def.Box2;
const Coords2 = def.Coords2;
const Vec2    = def.Vec2;
const VecA    = def.VecA;

const R2      = def.R3;
const R3      = def.R3;

const IR2     = 1.0 / R2;
const IR3     = def.IR3;

const HR2     = def.HR2;
const HR3     = def.HR3;

const MARGIN_FACTOR = 0.95; // Factor to scale down tiles, leaving a margin between them

const RECT_FACTOR = 1.0; // 1x1 square              R = HR2
const TRIA_FACTOR = def.getPolyCircum( 1.0, 3 );
const DIAM_FACTOR = def.getPolyCircum( 1.0, 4 ); // R = 1.0
const HEXA_FACTOR = def.getPolyCircum( 1.0, 6 );
//const PENT_FACTOR = SIZE_FACTOR * def.getPolyCircum( SIZE_FACTOR, 5 );

pub const e_tlmp_shape = enum( u8 )
{
  RECT, // []
  DIAM, // <>

  HEX1, // <_> ( pointy top )
  HEX2, // <_> (  flat top  )

  TRI1, // /\  ( upright )
  TRI2, // >   ( sideway )

//PEN1, // ( upright ) // TODO : implement me
//PEN2, // ( sideway ) // TODO : implement me

  pub inline fn getSides( self : e_tlmp_shape ) u8
  {
    return switch( self )
    {
      .RECT, .DIAM => 4,
      .HEX1, .HEX2 => 6,
      .TRI1, .TRI2 => 3,
    };
  }

  pub inline fn getTileScaleFactor( self : e_tlmp_shape ) f32
  {
    return switch( self )
    {
      .RECT        => RECT_FACTOR,
      .DIAM        => DIAM_FACTOR,
      .HEX1, .HEX2 => HEXA_FACTOR,
      .TRI1, .TRI2 => TRIA_FACTOR,
    };
  }

  pub inline fn getGridScaleFactors( self : e_tlmp_shape ) Vec2
  {
    const tmp = switch( self )
    {
      .RECT => comptime Vec2.new( 1.0, 1.0 ),
      .DIAM => comptime Vec2.new( 1.0, 1.0 ),
      .HEX1 => comptime Vec2.new( R3,  1.5 ),
      .HEX2 => comptime Vec2.new( 1.5, R3  ),
      .TRI1 => comptime Vec2.new( HR3, 1.5 ),
      .TRI2 => comptime Vec2.new( 1.5, HR3 ),
    };
    return tmp.mulVal( 0.5 ).mulVal( self.getTileScaleFactor() );
  }

  pub fn getParityOffset( self : e_tlmp_shape, coords : Coords2 ) Vec2
  {
    switch( self )
    {
      .RECT => return .{},
      .DIAM => return .{},
      .HEX1 =>
      {
        const yParity : f32 = @floatFromInt( @mod( coords.y, 2 ));
        const xOffset : f32 = ( yParity - 0.5 ) / 2.0;
        return Vec2.new( xOffset, 0.0 );
      },
      .HEX2 =>
      {
        const xParity : f32 = @floatFromInt( @mod( coords.x, 2 ));
        const yOffset : f32 = ( xParity - 0.5 ) / 2.0;
        return Vec2.new( 0.0, yOffset );
      },
      .TRI1 =>
      {
        const tParity : f32 = @floatFromInt( @mod( coords.x + coords.y, 2 ));
        const yOffset : f32 = ( tParity - 0.5 ) / 3.0;
        return Vec2.new( 0.0, yOffset );
      },
      .TRI2 =>
      {
        const tParity : f32 = @floatFromInt( @mod( coords.x + coords.y, 2 ));
        const xOffset : f32 = ( tParity - 0.5 ) / 3.0;
        return Vec2.new( xOffset, 0.0 );
      },
    }
  }
};


// ================================ COORDS TO POS ================================

pub fn getAbsTilePos( tlmp : *const Tilemap, gridCoords : Coords2 ) VecA
{
  const  tilePos = getRelTilePos( tlmp, gridCoords ).toVecA( .{} );
  return tilePos.rot( tlmp.gridPos.a ).add( tlmp.gridPos );
}

pub fn getRelTilePos( tlmp : *const Tilemap, gridCoords : Coords2 ) Vec2
{
  const baseX = @as( f32, @floatFromInt( gridCoords.x )) - ( @as( f32, @floatFromInt( tlmp.gridSize.x - 1 )) / 2.0 );
  const baseY = @as( f32, @floatFromInt( gridCoords.y )) - ( @as( f32, @floatFromInt( tlmp.gridSize.y - 1 )) / 2.0 );

  var tile = tlmp.getTile( gridCoords );

  if( tile != null ) // Return cached position if available
  {
    if( tile.?.relPos )| pos |{ return pos; }
  }

  var basePos = Vec2.new( baseX, baseY );

  if( tlmp.tileShape == .DIAM )
  {
    basePos.x -= baseY;
    basePos.y += baseX;
  }

  basePos = basePos.sub( tlmp.tileShape.getParityOffset( gridCoords ));
  basePos = basePos.mul( tlmp.tileShape.getGridScaleFactors() );
  basePos = basePos.mul( tlmp.tileScale );
  basePos = basePos.mulVal( 2.0 );

  if( tile != null ){ tile.?.relPos = basePos; }

  return basePos;
}

// ================================ POS TO COORDS ================================

pub fn getCoordsFromAbsPos( tlmp : *const Tilemap, pos : Vec2 ) ?Coords2
{
  const area = tlmp.getMapBoundingBox();

  if( !area.isOnPoint( pos )) // Quick check to see if pos is even in tilemap bounds
  {
    def.log( .DEBUG, 0, @src(), "Position {d},{d} is out of tilemap bounding box", .{ pos.x, pos.y });
    return null;
  }

  const relPos = pos.sub( tlmp.gridPos.toVec2() ).rot( tlmp.gridPos.a.neg() );
  return getCoordsFromRelPos( tlmp, relPos );
}

pub fn getCoordsFromRelPos( tlmp : *const Tilemap, pos : Vec2 ) ?Coords2
{
  const baseX = pos.x / tlmp.tileScale.x;
  const baseY = pos.y / tlmp.tileScale.y;

  const centerOffsetX = @as( f32, @floatFromInt( tlmp.gridSize.x - 1 )) * 0.5;
  const centerOffsetY = @as( f32, @floatFromInt( tlmp.gridSize.y - 1 )) * 0.5;

  switch( tlmp.tileShape )
  {
    .RECT =>
    {
      const gridX = @round(( baseX * RECT_FACTOR ) + centerOffsetX );
      const gridY = @round(( baseY * RECT_FACTOR ) + centerOffsetY );

      const coords = Coords2{
        .x = @intFromFloat( gridX ),
        .y = @intFromFloat( gridY ),
      };

      if( !tlmp.isCoordsValid( coords )){ return null; }
      return coords;
    },

    .DIAM =>
    {
      const gridX = @round((( baseX + baseY ) * DIAM_FACTOR ) + centerOffsetX );
      const gridY = @round((( baseY - baseX ) * DIAM_FACTOR ) + centerOffsetY );

      const coords = Coords2{
        .x = @intFromFloat( gridX ),
        .y = @intFromFloat( gridY ),
      };

      if( !tlmp.isCoordsValid( coords )){ return null; }
      return coords;
    },

    .HEX1 =>
    {
      const descaledX  = ( baseX / ( HEXA_FACTOR * R3  )) + centerOffsetX ;
      const rawGridY   = ( baseY / ( HEXA_FACTOR * 1.5 )) + centerOffsetY ;

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
        const distToA = pos.getDistSqr( tlmp.getRelTilePos( coordsA ));
        const distToB = pos.getDistSqr( tlmp.getRelTilePos( coordsB ));

        coords = if( distToA < distToB ) coordsA else coordsB;
      }

      if ( !tlmp.isCoordsValid( coords )){ return null; }
      return coords;
    },
    .HEX2 =>
    {
      const descaledY = ( baseY / ( HEXA_FACTOR * R3  )) + centerOffsetY ;
      const rawGridX  = ( baseX / ( HEXA_FACTOR * 1.5 )) + centerOffsetX ;

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
        const distToA = pos.getDistSqr( tlmp.getRelTilePos( coordsA ));
        const distToB = pos.getDistSqr( tlmp.getRelTilePos( coordsB ));

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

    // TODO ! : implement TRI1 and TRI2

    else => null, // TODO : implement PEN1 and 2
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

pub fn getMapBoundingBox( tlmp : *const Tilemap ) Box2 // TODO : make me fit the visuals better ( especially for DIAMS )
{

  var viewableScale = tlmp.gridSize.toVec2();
      viewableScale = viewableScale.mul( tlmp.tileScale );
      viewableScale = viewableScale.mul( tlmp.tileShape.getGridScaleFactors());

  if( tlmp.tileShape == .DIAM ){ return Box2.newPolyAABB( tlmp.gridPos.toVec2(), viewableScale.mulVal( 2.0 ), tlmp.gridPos.a, 4 ); }

  viewableScale = switch( tlmp.tileShape )
  {
    .HEX1 => .{ .x = viewableScale.x + tlmp.tileScale.x / 4.2, .y = viewableScale.y + tlmp.tileScale.y / 7.2 },
    .HEX2 => .{ .x = viewableScale.x + tlmp.tileScale.x / 7.2, .y = viewableScale.y + tlmp.tileScale.y / 4.2 },

    .TRI1 => .{ .x = viewableScale.x + tlmp.tileScale.x / 3.0, .y = viewableScale.y },
    .TRI2 => .{ .x = viewableScale.x, .y = viewableScale.y + tlmp.tileScale.y / 3.0 },

    else => viewableScale,
  };


  return( Box2.newRectAABB( tlmp.gridPos.toVec2(), viewableScale, tlmp.gridPos.a ));
}

pub fn getTileBoundingBox( tlmp : *const Tilemap, relPos : Vec2 ) Box2 // NOTE : Swap for the accurate AABB version
{
  const  absPos = relPos.rot( tlmp.gridPos.a ).add( tlmp.gridPos.toVec2() );
  const  radii  = tlmp.tileScale.mulVal( tlmp.tileShape.getTileScaleFactor() );

  return Box2.newRectAABB( absPos, radii, tlmp.gridPos.a ); // NOTE : approximation for the sake of performance

  //const angle = tlmp.gridPos.a;
  //return switch( tlmp.tileShape ) // NOTE : slow af
  //{
  //  .RECT => return Box2.newRectAABB( absPos, radii, angle                                 ),
  //  .DIAM => return Box2.newPolyAABB( absPos, radii, angle,                              4 ),
  //  .HEX1 => return Box2.newPolyAABB( absPos, radii, angle.addDeg( 90 ),                 6 ),
  //  .HEX2 => return Box2.newPolyAABB( absPos, radii, angle,                              6 ),
  //  .TRI1 => return Box2.newPolyAABB( absPos, radii, angle.addDeg(  1.0 * 90.0 ),        3 ), // TODO : handle triangle orientation
  //  .TRI2 => return Box2.newPolyAABB( absPos, radii, angle.subDeg(( 1.0 * 90.0 ) - 90 ), 3 ), // TODO : handle triangle orientation
  //};
}

pub fn drawTileShape( tlmp : *const Tilemap, tile : *const Tile, viewBox : *const Box2) void
{
  if( !tlmp.isCoordsValid( tile.gridCoords ))
  {
    def.log( .ERROR, 0, @src(), "Tile at position {d}:{d} does not exist in tilemap {d}", .{ tile.gridCoords.x, tile.gridCoords.y, tlmp.id });
    return;
  }


  const relPos  = tile.relPos orelse getRelTilePos( tlmp, tile.gridCoords );
  const tileBox = getTileBoundingBox( tlmp, relPos );

  if( !viewBox.isOverlapping( &tileBox )){ return; } // Quick check to see if tile is even in view

  const absPos = getAbsTilePos( tlmp, tile.gridCoords );
  const dParity : f32 = @floatFromInt(( 2 * @mod( tile.gridCoords.x + tile.gridCoords.y, 2 )) - 1 );

  var radii = tlmp.tileScale.mulVal( tlmp.tileShape.getTileScaleFactor() * MARGIN_FACTOR );
  if( tlmp.tileShape == .RECT ){ radii = radii.mulVal( 0.5 ); }

  switch( tlmp.tileShape )
  {
    .RECT => def.drawRect( absPos.toVec2(), radii, absPos.a, tile.colour ),
    .DIAM => def.drawDiam( absPos.toVec2(), radii, absPos.a, tile.colour ),

    .HEX1 => def.drawHexa( absPos.toVec2(), radii, absPos.a.addDeg( 90.0 ), tile.colour ),
    .HEX2 => def.drawHexa( absPos.toVec2(), radii, absPos.a,                tile.colour ),

    .TRI1 => def.drawTria( absPos.toVec2(), radii, absPos.a.addDeg(  dParity * 90.0 ),        tile.colour ),
    .TRI2 => def.drawTria( absPos.toVec2(), radii, absPos.a.subDeg(( dParity * 90.0 ) - 90 ), tile.colour ),
  }
}