const eng = @import( "engine" );
const utl = @import( "utils"  );


pub fn drawSprite( sprite : *const utl.Sprite ) void
{
  drawSpritemap( sprite.spritemapPtr, sprite.spritemapIdx, sprite.pos, sprite.scale, sprite.colour );
}

pub fn drawSpritemap( spritemap : *const utl.Spritemap, index : u32, pos : utl.VecA, scale : utl.Vec2, col : utl.Colour ) void
{
  utl.log( .TRACE, @src(), "Drawing spritemap frame #{} at {}:{}", .{ index, pos.x, pos.y });

  if( spritemap.atlas == null )
  {
    utl.qlog( .ERROR, @src(), "Trying to draw from uninitialized spritemap" );
    return;
  }

  const screenPos = eng.G_ENG.camera.worldToRender( pos.toVec2() );
  const src       = spritemap.getSpriteRect( index );
  const dst       = utl.RayRect
  {
    .x      = @floatCast( screenPos.x ),
    .y      = @floatCast( screenPos.y ),
    .width  = @floatCast( spritemap.frameSize.x * scale.x ),
    .height = @floatCast( spritemap.frameSize.y * scale.y ),
  };

  spritemap.atlas.?.drawPro( src, dst, spritemap.frameSize.mul( scale ).mulVal( 0.5 ).toRayVec2(), @floatCast( pos.a.toDeg() ), col.toRayCol() );
}
