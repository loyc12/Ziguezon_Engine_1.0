const std = @import( "std" );
const def = @import( "defs" );

pub const orb = @import( "comp/orbitComp.zig" );
pub const bdy = @import( "comp/bodyComp.zig"  );
pub const str = @import( "comp/starComp.zig"  );


// ================================ ENGINE & GAME SETTINGS ================================

pub const backColour : def.Colour = .dIndigo;
pub const foreColour : def.Colour = .dCrimson;
pub const textColour : def.Colour = .lGreen;

pub const zoomSpeed   : f32 =  1.2;
pub const scrollSpeed : f64 = 12.0;

pub const renderScale : f64 = 0.000_001;


pub const TransStore  = def.TransComp.getStoreType();
pub const ShapeStore  = def.ShapeComp.getStoreType();
pub const SpriteStore = def.SpriteComp.getStoreType();

pub const OrbitStore  = orb.OrbitComp.getStoreType();
pub const BodyStore   = bdy.BodyComp.getStoreType();


pub var transStore   : TransStore   = .{};
pub var shapeStore   : ShapeStore   = .{};
pub var spriteStore  : SpriteStore  = .{};

pub var orbitStore   : OrbitStore   = .{};
pub var bodyStore    : BodyStore    = .{};

pub var starCompInst : str.StarComp = .{};


pub const ENTITY_COUNT : usize = 8; // @typeInfo( stlr_d.StellarBodyEnum ).@"enum".fields.len;

pub var   starId       : def.EntityId = 1; // SUN
pub var   homeworldId  : def.EntityId = 4; // EARTH

pub var   targetId     : def.EntityId = 0;
pub var   entityArray  : [ ENTITY_COUNT ]def.Entity = std.mem.zeroes([ ENTITY_COUNT ]def.Entity );



// ================ UNITS AND CONSTANTS ================

// Mass     : Gigaton   ( Gt ) = 1e12 kg ( 1_000_000_000_000 )
// Distance : Kilometer ( km ) = 1_000 m
// Time     : Day       ( Dy ) = 86_400 s
// Density  : Gt/km³           = g/cm³


pub const G_FACTOR : f64 = 498.163; // km³/Gt¹wk²
                                    // km³/Gt¹Dy²



//  ================ DATA LOADING ================

pub const stlr_d = @import( "stellarData.zig" );
pub const STLR_DATA = &stlr_d.stellarData;

pub fn loadAllData() void
{
  stlr_d.loadStellarData();
}