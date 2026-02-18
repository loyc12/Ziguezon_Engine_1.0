const std = @import( "std" );
const def = @import( "defs" );

pub const orb = @import( "comp/orbitComp.zig" );
pub const bdy = @import( "comp/bodyComp.zig"  );


// ================================ ENGINE & GAME SETTINGS ================================

pub const backColour : def.Colour = .dIndigo;
pub const foreColour : def.Colour = .dCrimson;
pub const textColour : def.Colour = .lGreen;

pub const TransStore  = def.TransComp.getStoreType();
pub const ShapeStore  = def.ShapeComp.getStoreType();
pub const SpriteStore = def.SpriteComp.getStoreType();

pub const OrbitStore  = orb.OrbitComp.getStoreType();
pub const BodyStore   = bdy.BodyComp.getStoreType();


pub var transStore  : TransStore  = .{};
pub var shapeStore  : ShapeStore  = .{};
pub var spriteStore : SpriteStore = .{};

pub var orbitStore  : OrbitStore  = .{};
pub var bodyStore   : BodyStore   = .{};


pub const entityCount : usize = 4;

pub var entityArray : [ entityCount ]def.Entity = std.mem.zeroes([ entityCount ]def.Entity );