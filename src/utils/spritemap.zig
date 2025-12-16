const std  = @import( "std" );
const def  = @import( "defs" );

const Vec2   = def.Vec2;
const VecA   = def.VecA;
const Angle  = def.Angle;

const Texture   = def.ray.Texture2D;
const Rectangle = def.ray.Rectangle;

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
    def.qlog( .TRACE, 0, @src(), "Deinitializing spritemap" );

    //if( self.atlas != null ){ self.atlas.?.unload(); } // NOTE : done by closeWindow(), presumably... ?
    self.* = .{};
  }

  pub fn init( self : *Spritemap, fileName : [ :0 ]const u8, frameSize : Vec2, frameCount : u32 ) void
  {
    def.log( .TRACE, 0, @src(), "Initializing spritemap using : {s}", .{ fileName });


    // Initializing texture

    if( self.atlas != null )
    {
      def.qlog( .WARN, 0, @src(), "Overiding previous spritemap info" );
      self.atlas.?.unload();
    }

    self.atlas = Texture.init( fileName ) catch | err |
    {
      def.log( .ERROR, 0, @src(), "Failed to init spritemap atlas using : {s} : {} : returning", .{ fileName, err });
      self.* = .{};
      return;
    };



    // Initializing sprite size

    const atlasSize = Vec2{ .x = @floatFromInt( self.atlas.?.width ), .y = @floatFromInt( self.atlas.?.height )};

    if( frameSize.isSupXY( atlasSize ))
    {
      def.qlog( .ERROR, 0, @src(), "frameSize is larger than atlasSize : returning" );
      self.deinit();
      return;
    }
    if( frameSize.x < 1.0 or frameSize.y < 1.0 )
    {
      def.qlog( .ERROR, 0, @src(), "frameSize must be at least 1.0 in both axis" );
      self.deinit();
      return;
    }

    self.frameSize = frameSize;


    // Initializing frameCount and layout dimensions

    if( frameCount == 0 )
    {
      def.qlog( .ERROR, 0, @src(), "frameCount cannot be zero : returning" );
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
      self.layoutWidth  = @intFromFloat( @floor( atlasSize.x / self.frameSize.x ));
      self.layoutHeight = @divFloor( frameCount, self.layoutWidth );

      if( self.layoutWidth * self.layoutHeight > frameCount ){ self.layoutHeight += 1; }

      var layoutPixelHeight : f32 = @floatFromInt( self.layoutHeight );
          layoutPixelHeight      *= self.frameSize.y;

      if( layoutPixelHeight > atlasSize.y )
      {
        def.qlog( .ERROR, 0, @src(), "atlas is not large enough to fit the frameCount with given frameSize : returning" );
        self.deinit();
        return;
      }

      self.frameCount = frameCount;
    }

    def.qlog( .DEBUG, 0, @src(), "$ spritemap initialized !" );
  }

  fn getSpriteRect( self : *const Spritemap, index : u32 ) Rectangle
  {
    const i : u32 = @mod( index, self.frameCount );

    const w : f32 = self.frameSize.x;
    const h : f32 = self.frameSize.y;

    const x : f32 = @floatFromInt( @mod(      i, self.layoutWidth  ));
    const y : f32 = @floatFromInt( @divFloor( i, self.layoutHeight ));

    return .{ .x = x * w, .y = y * h, .width = w, .height = h };
  }

  pub fn drawSprite( self : *const Spritemap, index : u32, pos : VecA, scale : Vec2, col : def.Colour ) void
  {
    def.log( .TRACE, 0, @src(), "Drawing spritemap frame #{} at {}:{}", .{ index, pos.x, pos.y });

    if( self.atlas == null )
    {
      def.qlog( .ERROR, 0, @src(), "Trying to draw from uninitialized spritemap" );
      return;
    }

    const src : Rectangle = self.getSpriteRect( index );
    const dst : Rectangle =
    .{
      .x      = pos.x,
      .y      = pos.y,
      .width  = self.frameSize.x * scale.x,
      .height = self.frameSize.y * scale.y,
    };

    self.atlas.?.drawPro( src, dst, self.frameSize.mul( scale ).mulVal( 0.5 ).toRayVec2(), pos.a.toDeg(), col.toRayCol() );
  }
};