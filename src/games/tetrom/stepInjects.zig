const eng = @import( "engine" );
const utl = @import( "utils" );

const stateInj = @import( "stateInjects.zig" );
const game = @import( "game.zig" );
const tlmp = utl.legacy_tilemap;

const Tilemap = tlmp.Tilemap;


// ================================ STEP INJECTION FUNCTIONS ================================

/// Handles shell controls and manual preview selection during piece development.
pub fn OnUpdateInputs( ng : *eng.Engine ) void
{
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.r ))
  {
    stateInj.GAME.reset( &ng.rng );
    stateInj.syncGridDisplay();
  }

  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.equal ) or utl.ray.isKeyPressed( utl.ray.KeyboardKey.kp_add      )){ stateInj.GAME.changePieceBy(  1 ); }
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.minus ) or utl.ray.isKeyPressed( utl.ray.KeyboardKey.kp_subtract )){ stateInj.GAME.changePieceBy( -1 ); }

  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.w )){ tryMovePiece( .new(  0, -1 ), "up" ); }
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.s )){ tryMovePiece( .new(  0,  1 ), "down" ); }
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.a )){ tryMovePiece( .new( -1,  1 ), "down-left" ); }
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.d )){ tryMovePiece( .new(  1,  0 ), "down-right" ); }
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.q )){ tryRotatePiece( -1 ); }
  if( utl.ray.isKeyPressed( utl.ray.KeyboardKey.e )){ tryRotatePiece(  1 ); }

  // The engine refreshes the camera before calling this hook.
  if( utl.ray.isWindowResized() ){ stateInj.updateGridScale(); }
}

fn tryMovePiece( offset : game.HexCoord, direction : []const u8 ) void
{
  const collision = stateInj.GAME.tryMoveBy( offset );
  if( collision.isClear() )
  {
    utl.log( .DEBUG, @src(), "Debug piece moved {s}", .{ direction });
    return;
  }

  logIllegalMove( "move", collision );
}

fn tryRotatePiece( offset : i32 ) void
{
  const result = stateInj.GAME.tryRotateBy( offset );
  if( result.kicked )
  {
    utl.log( .DEBUG, @src(), "Debug rotation succeeded with wall kick", .{} );
    return;
  }
  if( result.collision.isClear() )
  {
    utl.log( .DEBUG, @src(), "Debug piece rotated", .{} );
    return;
  }

  logIllegalMove( "rotation", result.collision );
}

fn logIllegalMove( action : []const u8, collision : game.Collision ) void
{
  if( collision.wall  ){ utl.log( .DEBUG, @src(), "Illegal {s}: wall collision",  .{ action }); }
  if( collision.floor ){ utl.log( .DEBUG, @src(), "Illegal {s}: floor collision", .{ action }); }
  if( collision.cell  ){ utl.log( .DEBUG, @src(), "Illegal {s}: cell collision",  .{ action }); }
}

/// Renders the fixed board through the engine's world draw pass.
pub fn OnRenderWorld( ng : *eng.Engine ) void
{
  const grid = stateInj.getGrid() orelse return;

  // The grid is a display cache; keep it derived from the game-owned board.
  stateInj.syncGridDisplay();
  grid.drawSelf( ng.camera.toViewBox(), eng.wDraw );

  renderActivePiece( grid );
}

fn renderActivePiece( grid : *const Tilemap ) void
{
  const gridFactor : f64 = @floatCast( grid.tileShape.getTileScaleFactor() );
  const radii = grid.tileScale.mulVal( gridFactor * 0.88 );

  for( 0 .. @as( usize, stateInj.GAME.activePiece.getLayout().cellCount ))| index |
  {
    const preview = stateInj.GAME.getPreviewCell( index );
    if( !grid.isCoordsValid( preview.coords )){ continue; }

    const pos = grid.getAbsTilePos( preview.coords );
    var col = stateInj.getCellColour( preview.cell );

    if( preview.isAnchor ){ col = col.addRGB( 64 ); }

    eng.wDraw.hexa( pos.toVec2(), radii, pos.a, col );
  }
}

/// Renders the small shell HUD without taking on a general UI dependency.
pub fn OnRenderOverlay( ng : *eng.Engine ) void
{
  _ = ng;

  const screenCenter = utl.getHalfScreenSize();

  utl.sDraw.textCenter( "Tetrom", .new( screenCenter.x, 48.0 ), 48.0, .white );
  utl.sDraw.textLeft( "R: reset", .new( 24.0, 88.0 ), 20.0, .lGray );
  utl.sDraw.textLeft( "= / -: piece    W/S: vertical    A/D: diagonal down", .new( 24.0, 116.0 ), 20.0, .lGray );
  utl.sDraw.textLeft( "Q/E: rotate and wall kick", .new( 24.0, 144.0 ), 20.0, .lGray );
  utl.sDraw.textLeft( "Pale cell: anchor", .new( 24.0, 172.0 ), 20.0, .lGray );
  utl.sDraw.textLeftFmt( "Piece: {s}   Rotation: {s}", .{ @tagName( stateInj.GAME.activePiece.kind ), @tagName( stateInj.GAME.activePiece.rotation ) }, .new( 24.0, 200.0 ), 20.0, .white );
}
