const std = @import( "std" );
const def = @import( "defs" );

const ecn = @import( "econComp.zig" );



pub const PlanetComp = struct
{
  pub inline fn getStoreType() type { return def.componentStoreFactory( @This() ); }

  mass   : f32 = 1.0, // TODO : Figure out irl unit equivalency
  radius : f32 = 8.0, // TODO : Figure out irl unit equivalency
  shine  : f32 = 0.0, // TODO : Figure out irl unit equivalency // average solar energy per area unit

  econArray : [ ecn.econLocCount ]ecn.EconComp = std.mem.zeroes([ ecn.econLocCount ]ecn.EconComp ),


  pub inline fn getDensity( self : *const PlanetComp ) f32
  {
    // Sphere volume : ( 4/3 )πr³
    const  volume = ( 4.0 / 3.0 ) * def.PI * ( self.radius * self.radius * self.radius );
    return self.mass / volume;
  }

  pub inline fn getSurfaceArea( self : *const PlanetComp ) f32
  {
    // Sphere surface area : 4πr²
    return 4.0 * def.PI * ( self.radius * self.radius );
  }

  // Useful to update radius on mass change
  pub inline fn setRadiusViaDensity( self : *PlanetComp, density : f32 ) void
  {
    // Solved for r : r = ∛(3m / 4πρ)
    const volume = self.mass / density;
    self.radius  = std.math.cbrt(( 3.0 * volume ) / ( 4.0 * def.PI ));
  }
};
