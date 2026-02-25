const std = @import( "std" );
const def = @import( "defs" );

const ecn = @import( "economy.zig" );


pub const bodyTypeCount = @typeInfo( BodyType ).@"enum".fields.len;

pub const BodyType = enum( u8 )
{
  pub inline fn toIdx( self : BodyType ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) BodyType {  return @enumFromInt( @as( u8, @intCast( i ))); }

  PLANET, // Has L1-5
  MOON,   // Has L1-2 only
  COMET,  // Has no LPs    // NOTE : Also includes asteroids


  pub inline fn getEconLocCount( self : BodyType ) usize
  {
    return 2 + self.getLPCount();
  }

  pub inline fn getLPCount( self : BodyType ) usize
  {
    return switch( self )
    {
      .PLANET => 5,
      .MOON   => 2,
      .COMET  => 0,
    };
  }
};


pub const BodyComp = struct // DISTINCT FROM ENGINE BUILTIN COMP
{
  pub inline fn getStoreType() type { return def.componentStoreFactory( @This() ); }

  bodyType : BodyType,

  radius : f32 =   10.0, // TODO : Figure out irl unit equivalency // NOTE : for gasseous worlds : radius at 1 atm
  mass   : f32 = 1000.0, // TODO : Figure out irl unit equivalency
//temp   : f32 =    0.0, // TODO : Figure out irl unit equivalency
//tilt   : f32 =    0.0, // Radians

  econArray : [ ecn.econLocCount ]ecn.Economy = std.mem.zeroes([ ecn.econLocCount ]ecn.Economy ),


  // Sphere surface area : 4πr^2
  pub inline fn getSurfaceArea( self : *const BodyComp ) f32
  {
    const r2 = self.radius * self.radius;

    return 4.0 * def.PI * r2;
  }

  // Sphere volume : ( 4/3 )πr^3
  pub inline fn getVolume( self : *const BodyComp ) f32
  {
    const r3 = self.radius * self.radius * self.radius;

    return ( 4.0 * def.PI * r3 ) / 3.0 ;
  }

  pub inline fn getDensity( self : *const BodyComp ) f32
  {
    return self.mass / self.getVolume();
  }


  pub inline fn setRadiusViaArea( self : *BodyComp, area : f32 ) void
  {
    const r2 = area / ( 4.0 * def.PI );

    self.radius = def.sqrt( r2 );
  }
  pub inline fn setRadiusViaVolume( self : *BodyComp, volume : f32 ) void
  {
    const r3 = volume * 3.0 / ( 4.0 * def.PI );

    self.radius = def.cbrt( r3 );
  }

  pub inline fn setMassViaDensity( self : *BodyComp, density : f32 ) void
  {
    self.mass = density * self.getVolume();
  }

  pub inline fn setRadiusViaDensity( self : *BodyComp, density : f32 ) void
  {
    const v = self.mass / density;

    self.setRadiusViaVolume( v );
  }


  // ================================ ECONOMIES ================================

  pub fn tickEcons( self : *BodyComp ) void
  {
    for( 0..self.bodyType.getEconLocCount() )| i |
    {
      const econ : *ecn.Economy = &self.econArray[ i ];

      if( econ.isActive ) // TODO : activate loc when player build infra there
      {
        econ.sunshine = self.getCurrentSunshine();
        econ.tickEcon();
      }
    }
  }

  pub fn initEcon( self : *const BodyComp, econLoc : ecn.EconLoc ) void
  {
    const econ : *ecn.Economy = &self.econArray[ econLoc.toIdx() ];

    econ.location = econLoc;
    econ.isActive = true;

    if( econLoc == .GROUND )
    {
      econ.maxAvailArea = self.getSurfaceArea(); // TODO : add useableLand modifier ( ex : what proportion is solid ground )
    }
  }

  pub fn getEcon( self : *const BodyComp, econLoc : ecn.EconLoc ) *ecn.Economy
  {
    return &self.econArray[ econLoc.toIdx() ];
  }
};