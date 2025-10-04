const std = @import( "std" );
const def = @import( "defs" );

const TimeVal = def.TimeVal;

const Colour  = def.Colour;
const Texture = def.Texture;
const RayRect = def.RayRect;

const Vec2 = def.Vec2;
const VecA = def.VecA;


pub const SpriteModel = struct
{
  frameAtlas : Texture = undefined,

  frameWidth  : u16 = 1, // Height in pixels of a single frame
  frameHeight : u16 = 1, // Width in pixels of a single frame
  frameCount  : u16 = 1, // Number of frames in the atlas

  baseAnimStart  : u16 = 0, // Where a Sprite would, by default, restart its animation to
  defaultAnimEnd : u16 = 0, // Where a Sprite would, by default, loop its animation from

  pub inline fn isValid( self : *const SpriteModel ) bool
  {
    var res : bool = true;

    if( self.frameWidth == 0 or self.frameHeight == 0 )
    {
      def.log( .WARN, 0, @src(), "Invalid SpriteModel frame dimensions : {}x{}", .{ self.frameWidth, self.frameHeight });
      res = false;
    }

    if( self.frameWidth > self.frameAtlas.width or self.frameHeight > self.frameAtlas.height )
    {
      def.log( .WARN, 0, @src(), "Frame dimensions greater than SpriteModel dimensions : {}x{}", .{ self.frameWidth, self.frameHeight });
      res = false;
    }

    const calcFrameCount = self.getAtlasFrameWidth() * self.getAtlasFrameHeight();
    if( self.frameCount != calcFrameCount )
    {
      def.log( .WARN, 0, @src(), "Invalid SpriteModel frame count : {} != {}: ", .{ self.frameCount, calcFrameCount });
      res = false;
    }

    return res;
  }

  pub inline fn getAtlasFrameWidth(  self : *const SpriteModel ) u16 { return @divFloor( self.frameAtlas.width,  self.frameWidth  ); }
  pub inline fn getAtlasFrameHeight( self : *const SpriteModel ) u16 { return @divFloor( self.frameAtlas.height, self.frameHeight ); }

  pub inline fn getFrameSrcRect( self : *const SpriteModel, index : u16 ) RayRect
  {
    if( index >= self.frameCount )
    {
      def.qlog( .WARN, 0, @src(), "Trying to get a RayRect for an index outside the frameAtlas" );
      return RayRect{
        .x = 0,   .width  = @floatFromInt( self.frameWidth  ),
        .y = 0,   .height = @floatFromInt( self.frameHeight ),
      };
    }
    const atlasFrameWidth = self.getAtlasFrameWidth();

    const frameX : f32 = @floatFromInt(( self.frameWidth  * @mod(      index, atlasFrameWidth ))); // Column shifting
    const frameY : f32 = @floatFromInt(( self.frameHeight * @divFloor( index, atlasFrameWidth ))); // Row shifting

    return RayRect
    {
      .x = frameX,   .width  = @floatFromInt( self.frameWidth  ),
      .y = frameY,   .height = @floatFromInt( self.frameHeight ),
    };
  }

  pub inline fn getFrameDstRect( self : *const SpriteModel, spriteInstance : *const Sprite ) RayRect
  {
    return RayRect{
      .x      = spriteInstance.spritePos.x,
      .y      = spriteInstance.spritePos.y,
      .width  = spriteInstance.spriteScale.x * @as( f32, @floatFromInt( self.frameWidth  )),
      .height = spriteInstance.spriteScale.y * @as( f32, @floatFromInt( self.frameHeight )),
    };
  }
};


// TODO : add a flip X/Y option
// TODO : move bools to flags
// TODO : add a z layer component

pub const Sprite = struct
{
  model : ?*SpriteModel = null,

  active  : bool = true,
  animate : bool = true,

  animIndex : u16 = 0, // which frame from the model is currently being displayed
  animStart : u16 = 0, // Where the animation will restart its animation to
  animEnd   : u16 = 0, // Where the animation will loop its animation from ( loop includes animEnd frame )

  animTimer : TimeVal = .{}, // How far into the current animation step is this sprite
  animSpeed : TimeVal = .{}, // If 0, no automatic frame cycling ( animation )

  spritePos   : VecA   = VecA.new( 0.0, 0.0, .{} ), // where to display the sprite, and at which angle
  spriteScale : Vec2   = Vec2.new( 1.0, 1.0 ), // By how much to stretch the sprite when displayed
  spriteTint  : Colour = .white,

  pub fn tickSelf( self : *Sprite, dt : TimeVal ) void
  {
    if( !self.active or !self.animate ){ return; }

    self.animTimer.value += dt.value;

    if( self.animTimer.value > self.animSpeed.value )
    {
      self.animTimer -= self.animSpeed.value;
      self.animIndex += 1;
    }

    if( self.animIndex > self.animEnd )
    {
      self.animIndex = self.animStart;
    }
  }

  pub fn drawSelf( self : *const Sprite ) void
  {
    if( !self.active ){ return; }

    if( self.model == null )
    {
      def.qlog( .WARN, 0, @src(), "Trying to draw a Sprite with no SpriteModel" );
    }
    const model = self.model.?;

    const src  = model.getFrameSrcRect( self.index );
    const dest = model.getFrameDstRect( self );
    const cntr = def.RayVec2{ .x = dest.width / 2, .y = dest.height / 2 };

    def.ray.drawTexturePro( // TODO : move me to drawer or smthg
        model.frameAtlas,
        src,
        dest,
        cntr,
        self.spritePos.a.toDeg(),
        self.spriteTint,
    );
  }
};