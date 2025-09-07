const std     = @import( "std" );
const def     = @import( "defs" );

const Coords2 = def.Coords2;


pub const e_tile_type = enum( u8 ) // TODO : abstract this enum to allow for custom tile types ?
{
  EMPTY   = 0,
  FLOOR   = 1,
  WALL    = 2,
//MORE...
  RANDOM = 255, // For random tile generation only

  // an enum method... ? in THIS economy ?!
  pub fn getTileTypeColour( self : e_tile_type ) def.Colour
  {
    return switch( self )
    {
      .EMPTY   => def.newColour( 0,   0,   0,   0 ),
      .FLOOR   => def.newColour( 200, 200, 200, 255 ),
      .WALL    => def.newColour( 150, 150, 150, 255 ),
    //.MORE...
      .RANDOM  => def.newColour( 255, 0,   255, 255 ), // Magenta for debug only
    };
  }
};


pub const Tile = struct
{
  // ================ PROPERTIES ================
  tType      : e_tile_type = .EMPTY, // NOTE : move this to data instead, to allow for custom tile types ?

  // ======== GRID POS DATA ========
  gridCoords : Coords2 = .{},

  // ======== RENDERING DATA ======== ( DEBUG )
  colour     : def.Colour  = def.newColour( 255, 255, 255, 255 ),

  relPos     : ?def.Vec2   = null, // Position relative to tilemap origin. if null, needs to be (re)calculated

  // ======== CUSTOM BEHAVIOUR ========
//data     : ?*anyopaque = null, // Pointer to instance specific data ( if any )
//script   : ?*anyopaque = null, // Pointer to instance specific scripting ( if any )
};