const utl = @import( "utils" );

const Coords2 = utl.Coords2;

/// Per-tile state flags stored in the tile's bitfield.
pub const TileFlags = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

//DELETE  = 0b10000000, // Tile is marked for deletion ( tiles are on stack )
//IS_INIT = 0b01000000, // Tile is initialized
//ACTIVE  = 0b00100000, // Tile is active and can be used
//MORE... = 0b00010000, //
//MORE... = 0b00001000, //
//MORE... = 0b00000100, //
//MORE... = 0b00000010, //
  DEBUG   = 0b00000001, // Tile will be rendered with debug information

  DEFAULT = 0b01100000, // Default flags for a new tile
//TO_CPY  = 0b00011111, // Flags to copy when creating a new tile from params
  NONE    = 0b00000000, // No flags set
  ALL     = 0b11111111, // All flags set
};


/// Built-in legacy tile type ids.
/// Games can map these generic slots to their own local meaning.
pub const TileType = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

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

  /// Returns a debug/default display colour for built-in tile types.
  pub fn getTileTypeColour( self : TileType ) utl.Colour
  {
    return switch( self )
    {
      .EMPTY  => .transpa,

    //.T_ ...

      .PARITY => .magenta, // Won't ever be seen in normal usecase
      else    => .nWhite,  // Idem
    };
  }
};


/// One cell in a Tilemap grid.
/// Tile state is intentionally lightweight; map position comes from grid coordinates.
pub const Tile = struct
{
  // ================ PROPERTIES ================
  tType : TileType    = .EMPTY, // TODO: Store as u16 if legacy games outgrow the built-in type slots.
  flags : utl.Bfd8    = .new( TileFlags.DEFAULT ),

  // ======== GRID POS DATA ========
  mapCoords : Coords2 = .{},
  floodMark : u32     = 0,

  // ======== RENDERING DATA ======== ( DEBUG )
  colour : utl.Colour = .transpa,
  relPos : ?utl.Vec2  = null, // Cached tilemap-relative position. Reset when shape/scale changes.

  // ================ FLAG MANAGEMENT ================

  pub inline fn hasFlag( self : *const Tile, flag : TileFlags ) bool { return self.flags.hasFlag( @intFromEnum( flag )); }

  pub inline fn setAllFlags( self : *Tile, flags : u8 )                    void { self.flags.setAllFlags( flags ); }
  pub inline fn setFlag(     self : *Tile, flag  : TileFlags, val : bool ) void { self.flags.setBitFlag( @intFromEnum( flag ), val); }
  pub inline fn addFlag(     self : *Tile, flag  : TileFlags )             void { self.flags.addFlag( @intFromEnum( flag )); }
  pub inline fn delFlag(     self : *Tile, flag  : TileFlags )             void { self.flags.delFlag( @intFromEnum( flag )); }

//pub inline fn canBeDel( self : *const Tile ) bool { return self.hasFlag( TileFlags.DELETE  ); }
//pub inline fn isInit(   self : *const Tile ) bool { return self.hasFlag( TileFlags.IS_INIT ); }
//pub inline fn isActive( self : *const Tile ) bool { return self.hasFlag( TileFlags.ACTIVE  ); }

  pub inline fn viewDBG(   self : *const Tile ) bool { return self.hasFlag( TileFlags.DEBUG   ); }


};
