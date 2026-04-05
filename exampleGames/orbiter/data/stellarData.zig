const std = @import( "std" );
const def = @import( "defs" );

const gbl = @import( "../gameGlobals.zig" );
const gdf = @import( "../gameDefs.zig"    );

pub var stellarData : def.GenDataGrid( f64, StellarBodyName, StellarMetricEnum ) = .{};


pub const StellarMetricEnum = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  pub inline fn toIdx( self : @This() ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) @This() {  return @enumFromInt( i    ); }


  MASS,
  RADIUS, // Mean body radius
  PERIAP, // Minimal orbital radius
  APOAP,  // Maximal orbital radius
  LONG,   // Longitude of periapsis ( orientation of exentricity )
  TYPE,   //
};


// https://en.wikipedia.org/wiki/List_of_Solar_System_objects



pub const StellarBodyName = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  pub inline fn toIdx( self : @This() ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) @This() {  return @enumFromInt( i    ); }


  CUSTOM, // Default value   // NOTE : Is this too memory intensive ?
  DEBUGY, // TEST OBJECT

  SOL,

//  INNER - TERRESTRIALS

  MERCURY,

  VENUS,
//  ZOOZVE,      // QUASI-SATELLITE

  TERRA,
    LUNA,
//  CRUITHNE,    // CO-ORBITAL OBJECT

//EROS,

  MARS,
    PHOBOS,
    DEIMOS,
//  TBA_M_1,     // L4 TROJAN 101429
//  TBA_M_2,     // L5 TROJAN 121514
//  EUREKA,      // L5 TROJAN

//  MAIN BELT

//CERES,
//VESTA,
//PALLAS,
//HYGIEA,
//EUROPA_A,
//DAVIDA,
//SYLVIA,

//  OUTER - GIANTS

//  JUPITER,
//    IO,
//    EUROPA,
//    GANYMEDE,
//    CALLISTO,
//    // + TROJANS
//
//  SATURN,
//    MIMAS,
//    ENCELADUS,
//
//    TETHYS,
//      TELESTO,    // L4 TROJAN
//      CALYPSO,    // L5 TROJAN
//
//    DIONE,
//      HELENE,     // L4 TROJAN
//      POLYDEUCES, // L5 TROJAN
//
//    RHEA,
//    TITAN,
//    HYPERION,
//    LAPETUS,
//    PHOEBE,
//    // SHEPHERD MOONS
//
//  URANUS,
//    MIRANDA,
//    ARIEL,
//    UMBRIEL,
//    TITANIA,
//    OBERON,
//    // + TROJANS
//
//  NEPTUNE,
//    PROTEUS,
//    TRITON,
//    NEREID,
//    // + TROJANS

//  TRANS NEPTUNIANS

//  PLUTO,
//    CHARON,
//
//  SALACIA,
//
//  ORCUS,
//
//  ERIS,
//
//  HAUMEA,
//
//  MAKEMAKE,
//
//  QUAOAR,
//
//  GONGGONG,
//
//  SEDNA,

//  KUIPER BELT

//  OORT CLOUD
};


pub const StellarBodyType = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  pub inline fn toIdx( self : @This() ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) @This() {  return @enumFromInt( i    ); }

  pub inline fn toFlt( self : @This() ) f64 { return @floatFromInt( self.toIdx() ); }
  pub inline fn fromFlt( f : f64 ) @This() {  return .fromIdx( @intFromFloat( f )); }


  STAR,      // Has no LPs     Ex : Sol
  PLANET,    // Has L1-5       Ex : Earth,   Saturn
  PLANETOID, // Has L1-2 only  Ex : Ceres,   Pluto
  MOON,      // Has L1-2 only  Ex : Luna,    Titan
  MOONLET,   // Has no LPs     Ex : Phobos,  Deimos
  ASTEROID,  // Has no LPs     Ex : Common belt asteroids
  COMET,     // Has no LPs     Ex : Haley's, extreme orbits


  pub inline fn getMinDisplaySize( self : StellarBodyType ) def.Vec2
  {
    return switch( self )
    {
      .STAR      => .new( 8, 8 ),
      .PLANET    => .new( 4, 4 ),
      .PLANETOID => .new( 3, 3 ),
      .MOON      => .new( 4, 4 ),
      .MOONLET   => .new( 3, 3 ),
      .ASTEROID  => .new( 2, 2 ),
      .COMET     => .new( 2, 2 ),
    };
  }

  pub inline fn getDisplayColour( self : StellarBodyType ) def.Colour
  {
    return switch( self )
    {
      .STAR      => .gold,
      .PLANET    => .cerul,
      .PLANETOID => .lCerul,
      .MOON      => .nWhite,
      .MOONLET   => .pGray,
      .ASTEROID  => .lGray,
      .COMET     => .mGray,
    };
  }

  pub inline fn getEconLocCount( self : StellarBodyType ) usize
  {
    return 2 + self.getLPCount();
  }

  pub inline fn getLPCount( self : StellarBodyType ) usize
  {
    return switch( self )
    {
      .STAR      => 0,
      .PLANET    => 5,
      .PLANETOID => 2,
      .MOON      => 2,
      .MOONLET   => 0,
      .ASTEROID  => 0,
      .COMET     => 0,
    };
  }

  // Whether or not the specified econLoc can be hosted on this bodyType
  pub inline fn canHostEconLoc( self : StellarBodyType, loc : gdf.EconLoc ) bool
  {
    const locIdx = loc.toIdx();

    return( locIdx < self.getEconLocCount() );
  }
};


pub fn loadStellarData() void
{
  const SBT = StellarBodyType;


  stellarData.set( .DEBUGY,   .MASS,                   1_000_000 );
  stellarData.set( .DEBUGY,   .RADIUS,                   100.000 );
  stellarData.set( .DEBUGY,   .PERIAP,                40_000_000 );
  stellarData.set( .DEBUGY,   .APOAP,                800_000_000 );
  stellarData.set( .DEBUGY,   .LONG,                     123.456 );
  stellarData.set( .DEBUGY,   .TYPE,        SBT.ASTEROID.toFlt() );

  stellarData.set( .SOL,      .MASS,   1_988_475_000_000_000_000 );
  stellarData.set( .SOL,      .RADIUS,                   695_700 );
  stellarData.set( .SOL,      .PERIAP,                         0 );
  stellarData.set( .SOL,      .APOAP,                          0 );
  stellarData.set( .SOL,      .LONG,                           0 );
  stellarData.set( .SOL,      .TYPE,            SBT.STAR.toFlt() );


  stellarData.set( .MERCURY,  .MASS,      330_103_000_000 );
  stellarData.set( .MERCURY,  .RADIUS,          2_439.400 );
  stellarData.set( .MERCURY,  .PERIAP,         46_000_000 );
  stellarData.set( .MERCURY,  .APOAP,          69_820_000 );
  stellarData.set( .MERCURY,  .LONG,               77.460 );
  stellarData.set( .MERCURY,  .TYPE,   SBT.PLANET.toFlt() );


  stellarData.set( .VENUS,    .MASS,    4_867_310_000_000 );
  stellarData.set( .VENUS,    .RADIUS,          6_051.800 );
  stellarData.set( .VENUS,    .PERIAP,        107_480_000 );
  stellarData.set( .VENUS,    .APOAP,         108_940_000 );
  stellarData.set( .VENUS,    .LONG,              131.530 );
  stellarData.set( .VENUS,    .TYPE,   SBT.PLANET.toFlt() );

  //stellarData.set( .ZOOZVE, .MASS,                0.024 ); // Estimated
  //stellarData.set( .ZOOZVE, .RADIUS,              0.236 );
  //stellarData.set( .ZOOZVE, .PERIAP,         63_848_371 );
  //stellarData.set( .ZOOZVE, .APOAP,         152_679_586 );
  //stellarData.set( .ZOOZVE, .LONG,               227.03 );
  //stellarData.set( .ZOOZVE, .TYPE, SBT.ASTEROID.toFlt() );


  stellarData.set( .TERRA,    .MASS,    5_972_170_000_000 );
  stellarData.set( .TERRA,    .RADIUS,          6_371.008 );
  stellarData.set( .TERRA,    .PERIAP,        147_098_450 );
  stellarData.set( .TERRA,    .APOAP,         152_097_597 );
  stellarData.set( .TERRA,    .LONG,              102.947 );
  stellarData.set( .TERRA,    .TYPE,   SBT.PLANET.toFlt() );

    stellarData.set( .LUNA,   .MASS,       73_460_000_000 );
    stellarData.set( .LUNA,   .RADIUS,          1_737.400 );
    stellarData.set( .LUNA,   .PERIAP,            362_600 );
    stellarData.set( .LUNA,   .APOAP,             405_400 );
    stellarData.set( .LUNA,   .LONG,              218.030 );
    stellarData.set( .LUNA,   .TYPE,     SBT.MOON.toFlt() );


//stellarData.set( .EROS,     .MASS,                 6_687 );
//stellarData.set( .EROS,     .RADIUS,              16.840 );
//stellarData.set( .EROS,     .PERIAP,         169_554_226 );
//stellarData.set( .EROS,     .APOAP,          266_658_204 );
//stellarData.set( .EROS,     .LONG,               123.140 );
//stellarData.set( .EROS,     .TYPE,    SBT.ASTEROID.toFlt() );


  stellarData.set( .MARS,     .MASS,       641_691_000_000 );
  stellarData.set( .MARS,     .RADIUS,           3_389.500 );
  stellarData.set( .MARS,     .PERIAP,         206_650_000 );
  stellarData.set( .MARS,     .APOAP,          249_261_000 );
  stellarData.set( .MARS,     .LONG,               336.040 );
  stellarData.set( .MARS,     .TYPE,    SBT.PLANET.toFlt() );

    stellarData.set( .PHOBOS, .MASS,                16_000 );
    stellarData.set( .PHOBOS, .RADIUS,              11.080 );
    stellarData.set( .PHOBOS, .PERIAP,           9_234.420 );
    stellarData.set( .PHOBOS, .APOAP,            9_517.580 );
    stellarData.set( .PHOBOS, .LONG,                21.520 );
    stellarData.set( .PHOBOS, .TYPE,   SBT.MOONLET.toFlt() );

    stellarData.set( .DEIMOS, .MASS,                 1_510 );
    stellarData.set( .DEIMOS, .RADIUS,               6.270 );
    stellarData.set( .DEIMOS, .PERIAP,          23_455.500 );
    stellarData.set( .DEIMOS, .APOAP,           23_470.900 );
    stellarData.set( .DEIMOS, .LONG,                     0 );
    stellarData.set( .DEIMOS, .TYPE,   SBT.MOONLET.toFlt() );
}