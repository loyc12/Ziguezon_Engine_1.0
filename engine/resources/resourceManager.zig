const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

pub const ResourceManager = struct
{
  isInit    : bool = false,
//allocator : std.mem.Allocator = undefined,
  sounds    : std.StringHashMap( utl.ray.Sound     ) = undefined,
  music     : std.StringHashMap( utl.ray.Music     ) = undefined,
  fonts     : std.StringHashMap( utl.ray.Font      ) = undefined,
  sprites   : std.StringHashMap( utl.Spritemap     ) = undefined,

  pub fn init( self : *ResourceManager, allocator : std.mem.Allocator ) void
  {
    utl.qlog( .TRACE, 0, @src(), "# Initializing resource manager..." );

    if( self.isInit )
    {
      utl.qlog( .WARN, 0, @src(), "@ Resource manager is already initialized" );
      return;
    }

    self.sounds  = std.StringHashMap( utl.ray.Sound ).init( allocator );
    self.music   = std.StringHashMap( utl.ray.Music ).init( allocator );
    self.fonts   = std.StringHashMap( utl.ray.Font  ).init( allocator );
    self.sprites = std.StringHashMap( utl.Spritemap ).init( allocator );

    self.isInit    = true;
  //self.allocator = allocator;
    utl.qlog( .INFO, 0, @src(), "$ Resource manager initialized !\n" );
  }

  pub fn deinit( self : *ResourceManager ) void
  {
    utl.qlog( .TRACE, 0, @src(), "# Deinitializing resource manager..." );

    if( !self.isInit )
    {
      utl.qlog( .WARN, 0, @src(), "@ Resource manager was not initialized" );
      return;
    }

    self.isInit = false;

    var it_audio = self.sounds.iterator();
    while( it_audio.next()) | entry | utl.ray.unloadSound( entry.value_ptr.* );

    var it_music = self.music.iterator();
    while( it_music.next()) | entry | utl.ray.unloadMusicStream( entry.value_ptr.* );

    var it_fonts = self.fonts.iterator();
    while( it_fonts.next()) | entry | utl.ray.unloadFont( entry.value_ptr.* );

    var it_sprites = self.sprites.iterator();
    while( it_sprites.next()) | entry |
    {
      var spritemap : *utl.Spritemap = entry.value_ptr;
      spritemap.deinit();
    }

    self.sounds.clearAndFree();
    self.music.clearAndFree();
    self.fonts.clearAndFree();
    self.sprites.clearAndFree();

    utl.qlog( .INFO, 0, @src(), "$ Resource manager deinitialized !\n" );
  }

  // Get resources from the map
  pub fn getAudio( self : *const ResourceManager, name : [ :0 ]const u8 ) ?utl.ray.Sound
  {
    return self.sounds.get( name );
  }
  pub fn getMusic( self : *const ResourceManager, name : [ :0 ]const u8 ) ?utl.ray.Music
  {
    return self.music.get( name );
  }
  pub fn getFont( self : *const ResourceManager, name : [ :0 ]const u8 ) ?utl.ray.Font
  {
    return self.fonts.get( name );
  }
  pub fn getSprite( self : *const ResourceManager, name : [ :0 ]const u8 ) ?utl.Spritemap
  {
    return self.sprites.get( name );
  }

  // Add resources from raylib struct
  pub fn addAudio( self : *ResourceManager, name : [ :0 ]const u8, audio : utl.ray.Sound ) !void
  {
    utl.log( .DEBUG, 0, @src(), "& Adding audio: {s}", .{ name });
    try self.sounds.put( name, audio );
  }
  pub fn addMusic( self : *ResourceManager, name : [ :0 ]const u8, music : utl.ray.Music ) !void
  {
    utl.log( .DEBUG, 0, @src(), "& Adding music: {s}", .{ name });
    try self.music.put( name, music );
  }
  pub fn addFont( self : *ResourceManager, name : [ :0 ]const u8, font : utl.ray.Font ) !void
  {
    utl.log( .DEBUG, 0, @src(), "& Adding font: {s}", .{ name });
    try self.fonts.put( name, font );
  }
  pub fn addSprite( self : *ResourceManager, name : [ :0 ]const u8, sprite : utl.Spritemap ) !void
  {
    utl.log( .DEBUG, 0, @src(), "& Adding sprite: {s}", .{ name });
    try self.sprites.put( name, sprite );
  }

  // Add resources from file
  pub fn addAudioFromFile( self : *ResourceManager, name : [ :0 ]const u8, filePath : [ :0 ]const u8 ) !void
  {
    utl.log( .DEBUG, 0, @src(), "& Adding audio from file: {s}", .{ filePath });
    const sound : utl.ray.Sound = try utl.ray.loadSound( filePath );
    try self.addAudio( name, sound );
  }

  pub fn addMusicFromFile( self : *ResourceManager, name : [ :0 ]const u8, filePath : [ :0 ]const u8 ) !void
  {
    utl.log( .DEBUG, 0, @src(), "#& Adding music from file: {s}", .{ filePath });
    const music : utl.ray.Music = try utl.ray.loadMusicStream( filePath );
    try self.addMusic( name, music );
  }

  pub fn addFontFromFile( self : *ResourceManager, name : [ :0 ]const u8, filePath : [ :0 ]const u8 ) !void
  {
    utl.log( .DEBUG, 0, @src(), "& Adding font from file: {s}", .{ filePath });
    const font : utl.ray.Font = utl.ray.loadFont( filePath );
    try self.addFont( name, font );
  }

  pub fn addSpriteFromFile( self : *ResourceManager, name : [ :0 ]const u8, frameSize : utl.Vec2, frameCount : u32, filePath : [ :0 ]const u8 ) !void
  {
    utl.log( .DEBUG, 0, @src(), "& Adding sprite from file: {s}", .{ filePath });
    var spritemap : utl.Spritemap = .{};
        spritemap.init( filePath, frameSize, frameCount );

    if( spritemap.atlas == null ) return error.LoadImage;

    try self.addSprite( name, spritemap );
  }

  // Sound action Shortcuts
  pub fn playAudio( self : *ResourceManager, name : [ :0 ]const u8 ) void
  {
    const audio = self.getAudio( name ) orelse
    {
      utl.log( .ERROR, 0, @src(), "@ Audio '{s}' not found", .{ name });
      return;
    };
    utl.ray.playSound( audio );
  }

  pub fn playMusic( self : *ResourceManager, name : [ :0 ]const u8 ) void
  {
    const music = self.getMusic( name ) orelse
    {
      utl.log( .ERROR, 0, @src(), "@ Music '{s}' not found", .{ name });
      return;
    };
    utl.ray.playMusicStream( music );
  }

  pub fn stopMusic( self : *ResourceManager, name : [ :0 ]const u8 ) void
  {
    const music = self.getMusic( name ) orelse
    {
      utl.log( .ERROR, 0, @src(), "@ Music '{s}' not found", .{ name });
      return;
    };
    utl.ray.stopMusicStream( music );
  }

  pub fn drawFromSprite( self : *ResourceManager, name : [ :0 ]const u8, index : u32, pos : utl.VecA, scale : utl.Vec2, col : utl.Colour ) void
  {
    const spritemap = self.getSprite( name ) orelse
    {
      utl.log( .ERROR, 0, @src(), "@ Sprite '{s}' not found", .{ name });
      return;
    };

    utl.log( .TRACE, 0, @src(), "Drawing from sprite '{s}'", .{ name });
    spritemap.drawSprite( index, pos, scale, col );
  }

  pub fn drawScreenFromSprite( self : *ResourceManager, name : [ :0 ]const u8, index : u32, pos : utl.VecA, scale : utl.Vec2, col : utl.Colour ) void
  {
    const spritemap = self.getSprite( name ) orelse
    {
      utl.log( .ERROR, 0, @src(), "! Sprite '{s}' not found", .{ name });
      return;
    };

    utl.log( .TRACE, 0, @src(), "Drawing from sprite '{s}'", .{ name });
    spritemap.drawScreenSprite( index, pos, scale, col );
  }

};