const std = @import( "std" );
const def = @import( "defs" );

pub const cmp = @import( "gameComps.zig" );


// ================================ ENGINE & GAME SETTINGS ================================

pub const backColour : def.Colour = .dIndigo;
pub const foreColour : def.Colour = .dCrimson;
pub const textColour : def.Colour = .lGreen;


pub const TransStore  = def.TransComp.getStoreType();
pub const OrbitStore  = cmp.OrbitComp.getStoreType();
pub const ShapeStore  = def.ShapeComp.getStoreType();
pub const SpriteStore = def.SpriteComp.getStoreType();

pub var transStore  : TransStore  = .{};
pub var shapeStore  : ShapeStore  = .{};
pub var spriteStore : SpriteStore = .{};
pub var orbitStore  : OrbitStore  = .{};

pub const entityCount : usize = 9;

pub var entityArray : [ entityCount ]def.Entity = std.mem.zeroes([ entityCount ]def.Entity );