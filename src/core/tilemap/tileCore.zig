const std     = @import( "std" );
const def     = @import( "defs" );

const Coords2 = def.Coords2;

pub const e_tile_flags = enum( u8 )
{
//DELETE  = 0b10000000, // Tile is marked for deletion ( tiles are on stack )
//IS_INIT = 0b01000000, // Tile is initialized
//ACTIVE  = 0b00100000, // Tile is active and can be used
//MORE... = 0b00010000, //
//MORE... = 0b00001000, //
//MORE... = 0b00000100, //
  FLOODED = 0b00000010, // Flood-fill anti-recursion flag
  DEBUG   = 0b00000001, // Tile will be rendered with debug information

  DEFAULT = 0b01100000, // Default flags for a new tile
//TO_CPY  = 0b00011111, // Flags to copy when creating a new tile from params
  NONE    = 0b00000000, // No flags set
  ALL     = 0b11111111, // All flags set
};


pub const e_tile_type = enum( u8 )
{
  // True tile types
  EMPTY   = 0,
  T1      = 1,
  T2      = 2,
  T3      = 3,
  T4      = 4,
  T5      = 5,
  T6      = 6,
  T7      = 7,
  T8      = 8,
//MORE...

  // Tile modifier types

  PARITY = 254, // Use row & column paritiy colours
  RANDOM = 255, // For random tile generation only

  // an enum method... ? in THIS economy ?!
  pub fn getTileTypeColour( self : e_tile_type ) def.Colour
  {
    return switch( self )
    {
      .EMPTY  => .transpa,

    //.T_ ...

      .PARITY, .RANDOM => .magenta, // Won't ever be seen in normal usecase
      else             => .nWhite,  // Idem
    };
  }
};


pub const Tile = struct
{
  // ================ PROPERTIES ================
  tType     : e_tile_type = .EMPTY, // TODO : store as u16 instead, so that it can be customized more easily (?)
  flags     : def.BitField8 = def.BitField8.new( e_tile_flags.DEFAULT ),

  // ======== GRID POS DATA ========
  mapCoords : Coords2     = .{},

  // ======== RENDERING DATA ======== ( DEBUG )
  colour    : def.Colour  = .transpa,

  relPos    : ?def.Vec2   = null, // Position relative to tilemap origin. if null, needs to be (re)calculated

  // ======== CUSTOM BEHAVIOUR ========
  script : def.Scripter = .{},

  // ================ FLAG MANAGEMENT ================

  pub inline fn hasFlag( self : *const Tile, flag : e_tile_flags ) bool { return self.flags.hasFlag( @intFromEnum( flag )); }

  pub inline fn setAllFlags( self : *Tile, flags : u8 )                       void { self.flags.bitField = flags; }
  pub inline fn setFlag(     self : *Tile, flag  : e_tile_flags, val : bool ) void { self.flags = self.flags.setFlag( @intFromEnum( flag ), val); }
  pub inline fn addFlag(     self : *Tile, flag  : e_tile_flags )             void { self.flags = self.flags.addFlag( @intFromEnum( flag )); }
  pub inline fn delFlag(     self : *Tile, flag  : e_tile_flags )             void { self.flags = self.flags.delFlag( @intFromEnum( flag )); }

//pub inline fn canBeDel( self : *const Tile ) bool { return self.hasFlag( e_tile_flags.DELETE  ); }
//pub inline fn isInit(   self : *const Tile ) bool { return self.hasFlag( e_tile_flags.IS_INIT ); }
//pub inline fn isActive( self : *const Tile ) bool { return self.hasFlag( e_tile_flags.ACTIVE  ); }

  pub inline fn isFlooded( self : *const Tile ) bool { return self.hasFlag( e_tile_flags.FLOODED ); }
  pub inline fn viewDBG(   self : *const Tile ) bool { return self.hasFlag( e_tile_flags.DEBUG   ); }


};