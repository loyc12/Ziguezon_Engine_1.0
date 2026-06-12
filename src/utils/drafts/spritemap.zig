const std  = @import( "std" );
const utl = @import( "utils" );

const Vec2   = utl.Vec2;
const VecA   = utl.VecA;
const Angle  = utl.Angle;
const Colour = utl.Colour;

const Texture = utl.Texture;
const RayRect = utl.RayRect;


// ================================ SPRITE STRUCT ================================

pub const Sprite = struct
{
  spritemapPtr : *Spritemap,
  spritemapIdx : u32,

  animStartIdx : u32 = 0,
  animEndIdx   : u32 = 0,
  animLeapSize : u32 = 1,

  pos    : VecA,
  scale  : Vec2,
  colour : Colour = .white,


  pub fn tickAnimation( self : *Sprite ) void
  {
    std.debug.assert( self.animStartIdx <= self.animEndIdx );

    self.spritemapIdx += 1;

    if( self.spritemapIdx > self.animEndIdx )
    {
      self.spritemapIdx = self.animStartIdx;
    }
  }
};


// ================================ SPRITEMAP STRUCT ================================

pub const Spritemap = struct
{
  atlas        : ?Texture = null,

  frameSize    : Vec2 = .{},
  frameCount   : u32  = 1,

  layoutWidth  : u32  = 1,
  layoutHeight : u32  = 1,

  pub fn deinit( self : *Spritemap ) void
  {
    utl.qlog( .TRACE, @src(), "Deinitializing spritemap" );

    //if( self.atlas != null ){ self.atlas.?.unload(); } // NOTE : done by closeWindow(), presumably... ?
    self.* = .{};
  }

  pub fn init( self : *Spritemap, fileName : [ :0 ]const u8, frameSize : Vec2, frameCount : u32 ) void
  {
    utl.log( .TRACE, @src(), "Initializing spritemap using : {s}", .{ fileName });


    // Initializing texture

    if( self.atlas != null )
    {
      utl.qlog( .WARN, @src(), "Overiding previous spritemap info" );
      self.atlas.?.unload();
    }

    self.atlas = Texture.init( fileName ) catch | err |
    {
      utl.log( .ERROR, @src(), "Failed to init spritemap atlas using : {s} : {} : returning", .{ fileName, err });
      self.* = .{};
      return;
    };



    // Initializing sprite size

    const atlasSize = Vec2{ .x = @floatFromInt( self.atlas.?.width ), .y = @floatFromInt( self.atlas.?.height )};

    if( frameSize.x > atlasSize.x or frameSize.y > atlasSize.y )
    {
      utl.qlog( .ERROR, @src(), "frameSize is larger than atlasSize : returning" );
      self.deinit();
      return;
    }
    if( frameSize.x < 1.0 or frameSize.y < 1.0 )
    {
      utl.qlog( .ERROR, @src(), "frameSize must be at least 1.0 in both axis" );
      self.deinit();
      return;
    }

    self.frameSize = frameSize;


    // Initializing frameCount and layout dimensions

    if( frameCount == 0 )
    {
      utl.qlog( .ERROR, @src(), "frameCount cannot be zero : returning" );
      self.deinit();
      return;
    }
    else if ( frameCount == 1 )
    {
      self.frameCount   = 1;
      self.layoutWidth  = 1;
      self.layoutHeight = 1;
    }
    else
    {
      self.layoutWidth  = @intFromFloat( atlasSize.x / self.frameSize.x );
      self.layoutHeight = @divFloor( frameCount, self.layoutWidth );

      if( self.layoutWidth * self.layoutHeight > frameCount ){ self.layoutHeight += 1; }

      var layoutPixelHeight : f64 = @floatFromInt( self.layoutHeight );
          layoutPixelHeight      *= self.frameSize.y;

      if( layoutPixelHeight > atlasSize.y )
      {
        utl.qlog( .ERROR, @src(), "atlas is not large enough to fit the frameCount with given frameSize : returning" );
        self.deinit();
        return;
      }

      self.frameCount = frameCount;
    }

    utl.qlog( .DEBUG, @src(), "$ spritemap initialized !" );
  }

  pub fn getSpriteRect( self : *const Spritemap, index : u32 ) RayRect
  {
    const i : u32 = @mod( index, self.frameCount );

    const w : f32 = @floatCast( self.frameSize.x );
    const h : f32 = @floatCast( self.frameSize.y );

    const x : f32 = @floatFromInt( @mod(      i, self.layoutWidth  ));
    const y : f32 = @floatFromInt( @divFloor( i, self.layoutHeight ));

    return .{ .x = x * w, .y = y * h, .width = w, .height = h };
  }

  pub fn drawScreenSprite( self : *const Spritemap, index : u32, pos : VecA, scale : Vec2, col : utl.Colour ) void
  {
    utl.log( .TRACE, @src(), "Drawing spritemap frame #{} at {}:{}", .{ index, pos.x, pos.y });

    if( self.atlas == null )
    {
      utl.qlog( .ERROR, @src(), "Trying to draw from uninitialized spritemap" );
      return;
    }

    const src : RayRect = self.getSpriteRect( index );
    const dst : RayRect =
    .{
      .x      = @floatCast( pos.x ),
      .y      = @floatCast( pos.y ),
      .width  = @floatCast( self.frameSize.x * scale.x ),
      .height = @floatCast( self.frameSize.y * scale.y ),
    };

    self.atlas.?.drawPro( src, dst, self.frameSize.mul( scale ).mulVal( 0.5 ).toRayVec2(), @floatCast( pos.a.toDeg() ), col.toRayCol() );
  }
};
