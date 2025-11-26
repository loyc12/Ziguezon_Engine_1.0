const std     = @import( "std" );
const def     = @import( "defs" );

const Coords2 = def.Coords2;


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

  // Tile effect types

  PARITY = 254, // Row / Column paritiy colours
  RANDOM = 255, // For random tile generation only

  // an enum method... ? in THIS economy ?!
  pub fn getTileTypeColour( self : e_tile_type ) def.Colour
  {
    return switch( self )
    {
      .EMPTY   => .new( 0,   0,   0,   0 ),
    //.MORE...
      .PARITY, .RANDOM => .magenta, // Won't ever be seen in normal usecase

      else    => .new( 150, 150, 150, 255 ),
    };
  }
};


pub const Tile = struct
{
  // ================ PROPERTIES ================
  tType      : e_tile_type = .EMPTY, // TODO : store as u16 isntead, so that it can be customized more easily

  // ======== GRID POS DATA ========
  gridCoords : Coords2     = .{},

  // ======== RENDERING DATA ======== ( DEBUG )
  colour     : def.Colour  = .magenta, // Won't ever be seen in normal usecase

  relPos     : ?def.Vec2   = null, // Position relative to tilemap origin. if null, needs to be (re)calculated

  // ======== CUSTOM BEHAVIOUR ========
//data     : ?*anyopaque = null, // Pointer to instance specific data ( if any )
//script   : ?*anyopaque = null, // Pointer to instance specific scripting ( if any )
};