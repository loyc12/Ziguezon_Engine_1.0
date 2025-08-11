const std = @import( "std" );
const def = @import( "defs" );

pub const ResourceManager = struct
{
  sounds  : std.StringHashMap( def.ray.Sound     ),
  music   : std.StringHashMap( def.ray.Music     ),
  fonts   : std.StringHashMap( def.ray.Font      ),
  sprites : std.StringHashMap( def.ray.Texture2D ),

  pub fn init( self : *ResourceManager, mapAlloc : std.mem.Allocator ) void
  {
    def.qlog( .TRACE, 0, @src(), "Initializing resource manager..." );

    self.sounds  = std.StringHashMap( def.ray.Sound     ).init( mapAlloc );
    self.music   = std.StringHashMap( def.ray.Music     ).init( mapAlloc );
    self.fonts   = std.StringHashMap( def.ray.Font      ).init( mapAlloc );
    self.sprites = std.StringHashMap( def.ray.Texture2D ).init( mapAlloc );

    def.qlog( .INFO, 0, @src(), "Resource manager initialized." );
  }

  pub fn deinit( self : *ResourceManager ) void
  {
    def.qlog( .TRACE, 0, @src(), "Deinitializing resource manager..." );

    var it_audio = self.sounds.iterator();
    while( it_audio.next()) | entry | def.ray.unloadSound( entry.value_ptr.* );

    var it_music = self.music.iterator();
    while( it_music.next()) | entry | def.ray.unloadMusicStream( entry.value_ptr.* );

    var it_fonts = self.fonts.iterator();
    while( it_fonts.next()) | entry | def.ray.unloadFont( entry.value_ptr.* );

    var it_sprites = self.sprites.iterator();
    while( it_sprites.next()) | entry | def.ray.unloadTexture( entry.value_ptr.* );


    self.sounds.clearAndFree();
    self.music.clearAndFree();
    self.fonts.clearAndFree();
    self.sprites.clearAndFree();

    def.qlog( .INFO, 0, @src(), "Resource manager deinitialized." );
  }

  // Get resources from the map
  pub fn getAudio( self : *const ResourceManager, name : [ :0 ]const u8 ) ?def.ray.Sound
  {
    return self.sounds.get( name );
  }
  pub fn getMusic( self : *const ResourceManager, name : [ :0 ]const u8 ) ?def.ray.Music
  {
    return self.music.get( name );
  }
  pub fn getFont( self : *const ResourceManager, name : [ :0 ]const u8 ) ?def.ray.Font
  {
    return self.fonts.get( name );
  }
  pub fn getSprite( self : *const ResourceManager, name : [ :0 ]const u8 ) ?def.ray.Texture2
  {
    return self.sprites.get( name );
  }

  // Add resources from raylib struct
  pub fn addAudio( self : *ResourceManager, name : [ :0 ]const u8, audio : def.ray.Sound ) !void
  {
    def.log( .DEBUG, 0, @src(), "Adding audio: {s}", .{ name });
    try self.sounds.put( name, audio );
  }
  pub fn addMusic( self : *ResourceManager, name : [ :0 ]const u8, music : def.ray.Music ) !void
  {
    def.log( .DEBUG, 0, @src(), "Adding music: {s}", .{ name });
    try self.music.put( name, music );
  }
  pub fn addFont( self : *ResourceManager, name : [ :0 ]const u8, font : def.ray.Font ) !void
  {
    def.log( .DEBUG, 0, @src(), "Adding font: {s}", .{ name });
    try self.fonts.put( name, font );
  }
  pub fn addSprite( self : *ResourceManager, name : [ :0 ]const u8, sprite : def.ray.Texture2 ) !void
  {
    def.log( .DEBUG, 0, @src(), "Adding sprite: {s}", .{ name });
    try self.sprites.put( name, sprite );
  }

  // Add resources from file
  pub fn addAudioFromFile( self : *ResourceManager, name : [ :0 ]const u8, filePath : [ :0 ]const u8 ) !void
  {
    def.log( .DEBUG, 0, @src(), "Adding audio from file: {s}", .{ filePath });
    const sound : def.ray.Sound = try def.ray.loadSound( filePath ); // catch | err |
    try self.addAudio( name, sound );
  }

  pub fn addMusicFromFile( self : *ResourceManager, name : [ :0 ]const u8, filePath : [ :0 ]const u8 ) !void
  {
    def.log( .DEBUG, 0, @src(), "Adding music from file: {s}", .{ filePath });
    const music : def.ray.Music = try def.ray.loadMusicStream( filePath );
    try self.addMusic( name, music );
  }

  pub fn addFontFromFile( self : *ResourceManager, name : [ :0 ]const u8, filePath : [ :0 ]const u8 ) !void
  {
    def.log( .DEBUG, 0, @src(), "Adding font from file: {s}", .{ filePath });
    const font : def.ray.Font = def.ray.loadFont( filePath );
    try self.addFont( name, font );
  }

  pub fn addSpriteFromFile( self : *ResourceManager, name : [ :0 ]const u8, filePath : [ :0 ]const u8 ) !void
  {
    def.log( .DEBUG, 0, @src(), "Adding sprite from file: {s}", .{ filePath });
    const texture : def.ray.texture2D = try def.ray.loadTexture( filePath );
    try self.addSprite( name, texture );
  }

  // Sound action Shortcuts
  pub fn playAudio( self : *ResourceManager, name : [ :0 ]const u8 ) void
  {
    const audio = self.getAudio( name ) orelse
    {
      def.log( .ERROR, 0, @src(), "Audio '{s}' not found", .{ name });
      return;
    };
    def.ray.playSound( audio );
  }

  pub fn playMusic( self : *ResourceManager, name : [ :0 ]const u8 ) void
  {
    const music = self.getMusic( name ) orelse
    {
      def.log( .ERROR, 0, @src(), "Music '{s}' not found", .{ name });
      return;
    };
    def.ray.playMusicStream( music );
  }

  pub fn stopMusic( self : *ResourceManager, name : [ :0 ]const u8 ) void
  {
    const music = self.getMusic( name ) orelse
    {
      def.log( .ERROR, 0, @src(), "Music '{s}' not found", .{ name });
      return;
    };
    def.ray.stopMusicStream( music );
  }

};