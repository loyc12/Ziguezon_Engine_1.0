const std = @import( "std" );
const def = @import( "defs" );


pub const StarComp = struct
{
  pub inline fn getStoreType() type { return def.componentStoreFactory( @This() ); }

  radius    : f64 = 8.0, // TODO : Figure out irl unit equivalency // NOTE : radius at 1 atm
  mass      : f64 = 1.0, // TODO : Figure out irl unit equivalency
  shine     : f64 = 1.0, // TODO : Figure out irl unit equivalency // sunshine  strenght at dist = 1.0
//radiation : f64 = 0.0, // TODO : Figure out irl unit equivalency // radiation strenght at dist = 1.0


  // Sphere surface area : 4πr^2
  pub inline fn getSurfaceArea( self : *const StarComp ) f64
  {
    const r2 = self.radius * self.radius;

    return 4.0 * def.PI * r2;
  }

  // Sphere volume : ( 4/3 )πr^3
  pub inline fn getVolume( self : *const StarComp ) f64
  {
    const r3 = self.radius * self.radius * self.radius;

    return ( 4.0 * def.PI * r3 ) / 3.0 ;
  }

  pub inline fn getDensity( self : *const StarComp ) f64
  {
    return self.mass / self.getVolume();
  }


  pub inline fn setRadiusViaArea( self : *StarComp, area : f64 ) void
  {
    const r2 = area / ( 4.0 * def.PI );

    self.radius = def.sqrt( r2 );
  }
  pub inline fn setRadiusViaVolume( self : *StarComp, volume : f64 ) void
  {
    const r3 = volume * 3.0 / ( 4.0 * def.PI );

    self.radius = def.cbrt( r3 );
  }

  pub inline fn setMassViaDensity( self : *StarComp, density : f64 ) void
  {
    self.mass = density * self.getVolume();
  }

  pub inline fn setRadiusViaDensity( self : *StarComp, density : f64 ) void
  {
    const v = self.mass / density;

    self.setRadiusViaVolume( v );
  }



  pub inline fn setShineAtDist( self : *StarComp, shine : f64, dist : f64 ) void
  {
    const d2 = dist * dist;

    self.shine = shine * d2;
  }

  pub fn getSunshineAt( self : *const StarComp, distSquare : f64 ) f64
  {
    if( distSquare < self.radius * self.radius )
    {
      def.log( .ERROR, 0, @src(), "Trying to get sunshine inside star radius : {d} < {d} : returning 0.0", .{ @sqrt( distSquare ), self.radius });
      return 0;
    }

    return self.shine / distSquare;
  }
};
