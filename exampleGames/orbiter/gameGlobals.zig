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


pub const ENTITY_COUNT : usize = 8;

pub var   starId       : def.EntityId = 1;
pub var   homeworldId  : def.EntityId = 4;

pub var   targetId     : def.EntityId = 0;
pub var   entityArray  : [ ENTITY_COUNT ]def.Entity = std.mem.zeroes([ ENTITY_COUNT ]def.Entity );



// ================ UNITS ================

// Mass     : Gigaton   ( Gt ) = 1e12 kg ( 1_000_000_000_000 )
// Distance : Kilometer ( km ) = 1_000 m
// Time     : Week      ( wk ) = 604_800 s
// Density  : Gt/km³           = g/cm³


pub const G_FACTOR   : f64 = 24_410; // km³/Gt¹wk²


// SUN
pub const SOL_MASS   : f64 = 1_988_475_000_000_000_000;
pub const SOL_RADIUS : f64 =                   695_700;

// ================ VALUE NAMEs ================
// Periapsis distance                                   Mass
// Apoapsis distance                                    Longitude of Periapsis
// Mean radius

// INNER PLANETS
pub const MERCURY_ORBIT_MIN : f64 =    46_000_000;      pub const MERCURY_MASS  : f64 =   330_103_000_000;
pub const MERCURY_ORBIT_MAX : f64 =    69_820_000;      pub const MERCURY_LONG  : f32 =            77.460;
pub const MERCURY_RADIUS    : f64 =     2_439.400;

pub const VENUS_ORBIT_MIN   : f64 =   107_480_000;      pub const VENUS_MASS    : f64 = 4_867_310_000_000;
pub const VENUS_ORBIT_MAX   : f64 =   108_940_000;      pub const VENUS_LONG    : f32 =           131.530;
pub const VENUS_RADIUS      : f64 =     6_051.800;

pub const TERRA_ORBIT_MIN   : f64 =   147_098_450;      pub const TERRA_MASS    : f64 = 5_972_170_000_000;
pub const TERRA_ORBIT_MAX   : f64 =   152_097_597;      pub const TERRA_LONG    : f32 =           102.950;
pub const TERRA_RADIUS      : f64 =     6_371.008;

  pub const LUNA_ORBIT_MIN    : f64 =     362_600;        pub const LUNA_MASS     : f64 =  73_460_000_000;
  pub const LUNA_ORBIT_MAX    : f64 =     405_400;        pub const LUNA_LONG     : f32 =         218.030;
  pub const LUNA_RADIUS       : f64 =   1_737.400;

pub const MARS_ORBIT_MIN    : f64 =   206_650_000;      pub const MARS_MASS     : f64 =   641_691_000_000;
pub const MARS_ORBIT_MAX    : f64 =   249_261_000;      pub const MARS_LONG     : f32 =           336.040;
pub const MARS_RADIUS       : f64 =     3_389.500;

  pub const PHOBOS_ORBIT_MIN  : f64 =   9_234_420;        pub const PHOBOS_MASS   : f64 =          16_000;
  pub const PHOBOS_ORBIT_MAX  : f64 =   9_517_580;        pub const PHOBOS_LONG   : f32 =          21.520;
  pub const PHOBOS_RADIUS     : f64 =      11.080;

  pub const DEIMOS_ORBIT_MIN  : f64 =    23_455.5;        pub const DEIMOS_MASS   : f64 =           1_510;
  pub const DEIMOS_ORBIT_MAX  : f64 =    23_470.9;        pub const DEIMOS_LONG   : f32 =           0.000;
  pub const DEIMOS_RADIUS     : f64 =       6.270;


