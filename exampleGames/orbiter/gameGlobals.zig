const std = @import( "std" );
const def = @import( "defs" );

const cmp = @import( "gameComps.zig" );


// ================================ ENGINE & GAME SETTINGS ================================

pub const backColour : def.Colour = .dIndigo;
pub const foreColour : def.Colour = .dCrimson;
pub const textColour : def.Colour = .lGreen;


pub const TransStore  = def.TransComp.getStoreType();
pub const ShapeStore  = def.ShapeComp.getStoreType();
pub const SpriteStore = def.SpriteComp.getStoreType();

pub const OrbitStore  = cmp.OrbitComp.getStoreType();