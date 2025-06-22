const std  = @import( "std" );
const h    = @import( "../headers.zig" );

pub const entity = struct
{
  id : u32, // Unique identifier for the entity

  active : bool, // Whether the entity is active or not

  position : h.vec2, // Position of the entity in 2D space

};



