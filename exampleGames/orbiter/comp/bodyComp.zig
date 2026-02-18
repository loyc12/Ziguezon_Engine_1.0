const std = @import( "std" );
const def = @import( "defs" );

const ecn = @import( "econComp.zig" );


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
    return comptime switch( self )
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

  radius : f32 = 8.0, // TODO : Figure out irl unit equivalency // NOTE : for gasseous worlds : radius at 1 atm
  mass   : f32 = 1.0, // TODO : Figure out irl unit equivalency
//temp   : f32 = 0.0, // TODO : Figure out irl unit equivalency
//tilt   : f32 = 0.0, // Radians

  econArray : [ ecn.econLocCount ]ecn.EconComp = std.mem.zeroes([ ecn.econLocCount ]ecn.EconComp ),


  pub inline fn getSurfaceArea( self : *const BodyComp ) f32
  {
    const r2 = self.radius * self.radius;

    // Sphere surface area : 4πr²
    return 4.0 * def.PI * r2;
  }

  pub inline fn getVolume( self : *const BodyComp ) f32
  {
    const r3 = self.radius * self.radius * self.radius;

    // Sphere volume : ( 4/3 )πr³
    return ( 4.0 / 3.0 ) * def.PI * r3;
  }

  pub inline fn getDensity( self : *const BodyComp ) f32
  {
    return self.mass / self.getVolume();
  }

  const ORBIT_RADIUS_FACTOR = 1.5;

  pub inline fn getMinOrbitRadius( self : *const BodyComp ) f32
  {
    return self.radius * ORBIT_RADIUS_FACTOR;
  }


  // ================================ ECONOMIES ================================

  pub fn tickEcons( self : *BodyComp ) void
  {
    for( 0..self.bodyType.getEconLocCount() )| i |
    {
      const econ : *ecn.EconComp = &self.econArray[ i ];

      if( econ.isActive ) // TODO : activate loc when player build infra there
      {
        econ.sunshine = self.getCurrentSunshine();
        econ.tickEcon();
      }
    }
  }

  pub fn initEcon( self : *const BodyComp, econLoc : ecn.EconLoc ) void
  {
    const econ : *ecn.EconComp = &self.econArray[ econLoc.toIdx() ];

    econ.location = econLoc;
    econ.isActive = true;

    if( econLoc == .GROUND )
    {
      econ.maxAvailArea = self.getSurfaceArea(); // TODO : add useableLand modifier ( ex : what proportion is solid ground )
    }
  }

  pub fn getEcon( self : *const BodyComp, econLoc : ecn.EconLoc ) *ecn.EconComp
  {
    return &self.econArray[ econLoc.toIdx() ];
  }
};


pub const StarComp = struct
{
  pub inline fn getStoreType() type { return def.componentStoreFactory( @This() ); }

  radius    : f32 = 8.0, // TODO : Figure out irl unit equivalency // NOTE : radius at 1 atm
  mass      : f32 = 1.0, // TODO : Figure out irl unit equivalency
  shine     : f32 = 1.0, // TODO : Figure out irl unit equivalency // sunshine  strenght at dist = 1.0
//radiation : f32 = 0.0, // TODO : Figure out irl unit equivalency // radiation strenght at dist = 1.0


  pub inline fn getSurfaceArea( self : *const StarComp ) f32
  {
    const r2 = self.radius * self.radius;

    // Sphere surface area : 4πr²
    return 4.0 * def.PI * r2;
  }

  pub inline fn getVolume( self : *const StarComp ) f32
  {
    const r3 = self.radius * self.radius * self.radius;

    // Sphere volume : ( 4/3 )πr³
    return ( 4.0 / 3.0 ) * def.PI * r3;
  }

  pub inline fn getDensity( self : *const StarComp ) f32
  {
    return self.mass / self.getVolume();
  }

  pub fn getSunshineAt( self : *const StarComp, dist : f32 ) f32
  {
    if( dist < self.radius )
    {
      def.qlog( .ERROR, 0, @src(), "Trying to get sunshine inside star radius : returning 0.0" );
      return 0;
    }

    return self.shine / ( dist * dist );
  }
};
