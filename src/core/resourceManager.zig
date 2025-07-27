const std = @import( "std" );
const def = @import( "defs" );

pub const resourceManager = struct
{
  audios  : std.AutoHashMap( [ :0 ]const u8, def.ray.AudioStream ),
  music   : std.AutoHashMap( [ :0 ]const u8, def.ray.Music ),
  fonts   : std.AutoHashMap( [ :0 ]const u8, def.ray.Font ),
  sprites : std.AutoHashMap( [ :0 ]const u8, def.ray.Texture2D ),

  pub fn init( self : *resourceManager, mapAlloc : std.mem.Allocator ) void
  {
    def.qlog( .TRACE, 0, @src(), "Initializing resource manager..." );

    self.audios  = std.AutoHashMap( [ :0 ]const u8, def.ray.AudioStream ).init( mapAlloc );
    self.music   = std.AutoHashMap( [ :0 ]const u8, def.ray.Music       ).init( mapAlloc );
    self.fonts   = std.AutoHashMap( [ :0 ]const u8, def.ray.Font        ).init( mapAlloc );
    self.sprites = std.AutoHashMap( [ :0 ]const u8, def.ray.Texture2D   ).init( mapAlloc );

    def.qlog( .INFO, 0, @src(), "Resource manager initialized." );
  }
  pub fn deinit( self : *resourceManager ) void
  {
    def.qlog( .TRACE, 0, @src(), "Deinitializing resource manager..." );

    var it_audio = self.audios.iterator();
    while( it_audio.next()) | entry | def.ray.unloadAudioStream( entry.value_ptr.* );

    var it_music = self.music.iterator();
    while( it_music.next()) | entry | def.ray.unloadMusicStream( entry.value_ptr.* );

    var it_fonts = self.fonts.iterator();
    while( it_fonts.next()) | entry | def.ray.unloadFont( entry.value_ptr.* );

    var it_sprites = self.sprites.iterator();
    while( it_sprites.next()) | entry | def.ray.unloadTexture( entry.value_ptr.* );


    self.audios.clearAndFree();
    self.music.clearAndFree();
    self.fonts.clearAndFree();
    self.sprites.clearAndFree();

    def.qlog( .INFO, 0, @src(), "Resource manager deinitialized." );
  }

  // Get resources from the map
  pub fn getAudio( self : *const resourceManager, name : [ :0 ]const u8 ) ?def.ray.AudioStream
  {
    return self.audios.get( name );
  }
  pub fn getMusic( self : *const resourceManager, name : [ :0 ]const u8 ) ?def.ray.Music
  {
    return self.music.get( name );
  }
  pub fn getFont( self : *const resourceManager, name : [ :0 ]const u8 ) ?def.ray.Font
  {
    return self.fonts.get( name );
  }
  pub fn getSprite( self : *const resourceManager, name : [ :0 ]const u8 ) ?def.ray.Texture2
  {
    return self.sprites.get( name );
  }

  // Add resources from raylib struct
  pub fn addAudio( self : *resourceManager, name : [ :0 ]const u8, audio : def.ray.AudioStream ) !void
  {
    try self.audios.put( name, audio );
  }
  pub fn addMusic( self : *resourceManager, name : [ :0 ]const u8, music : def.ray.Music ) !void
  {
    try self.music.put( name, music );
  }
  pub fn addFont( self : *resourceManager, name : [ :0 ]const u8, font : def.ray.Font ) !void
  {
    try self.fonts.put( name, font );
  }
  pub fn addSprite( self : *resourceManager, name : [ :0 ]const u8, sprite : def.ray.Texture2 ) !void
  {
    try self.sprites.put( name, sprite );
  }

  // Add resources from file
  pub fn addAudioFromFile( self : *resourceManager, name : [ :0 ]const u8, filePath : [ :0 ]const u8 ) !void
  {
    _ = self;
    _ = name;
    _ = filePath;
    //const audio = def.ray.loadAudioStream( filePath );
    //try self.addAudio( name, audio );
  }
  pub fn addMusicFromFile( self : *resourceManager, name : [ :0 ]const u8, filePath : [ :0 ]const u8 ) !void
  {
    _ = self;
    _ = name;
    _ = filePath;
    //const music = def.ray.loadMusicStream( filePath );
    //try self.addMusic( name, music );
  }
  pub fn addFontFromFile( self : *resourceManager, name : [ :0 ]const u8, filePath : [ :0 ]const u8 ) !void
  {
    _ = self;
    _ = name;
    _ = filePath;
    //const font = def.ray.loadFont( filePath );
    //try self.addFont( name, font );
  }
  pub fn addSpriteFromFile( self : *resourceManager, name : [ :0 ]const u8, filePath : [ :0 ]const u8 ) !void
  {
    _ = self;
    _ = name;
    _ = filePath;
    //const sprite = def.ray.loadTexture( filePath );
    //try self.addSprite( name, sprite );
  }

};