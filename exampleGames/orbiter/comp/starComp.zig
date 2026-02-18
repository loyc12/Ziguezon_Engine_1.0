const std = @import( "std" );
const def = @import( "defs" );


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
