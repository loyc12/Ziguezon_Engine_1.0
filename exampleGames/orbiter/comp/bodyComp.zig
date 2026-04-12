const std = @import( "std"  );
const def = @import( "defs" );

const gbl = @import( "../gameGlobals.zig" );
const gdf = @import( "../gameDefs.zig"    );

const orb = gdf.orb;
const ecn = gdf.ecn;

const EconLoc  = gdf.EconLoc;
const BodyName = gdf.BodyName;
const BodyType = gdf.BodyType;


pub const BodyComp = struct // DISTINCT FROM ENGINE BUILTIN COMP
{
  pub inline fn getStoreType() type { return def.componentStoreFactory( @This() ); }

  name     : BodyName = .CUSTOM,
  bodyType : BodyType = .PLANET, // TODO : auto-assign type based on mass instead ? ( and orbital radius ? )

  // NOTE : defaults to earth values

  mass   : f64 = 5_972_000_000_000.0, // Gigatons   ( Gt )
  radius : f64 =             6_371.0, // kilometers ( km ) // NOTE : for gaseous worlds : radius at 1 atm pressure
//temp   : f32 =               390.0, // Kelvins    ( Dk )
//tilt   : f32 =                 0.0, // Radians

  econArray : [ EconLoc.count ]ecn.Economy = std.mem.zeroes([ EconLoc.count ]ecn.Economy ),


  // Sphere surface area : 4πr^2
  pub inline fn getSurfaceArea( self : *const BodyComp ) f64
  {
    const r2  = self.radius * self.radius;
    const tmp = 4.0 * def.PI * r2;

    return tmp;
  }

  // Sphere volume : (4/3)πr^3
  pub inline fn getVolume( self : *const BodyComp ) f64
  {
    const r3  = self.radius * self.radius * self.radius;
    const tmp = ( 4.0 * def.PI * r3 ) / 3.0;

    return tmp;
  }

  pub inline fn getDensity( self : *const BodyComp ) f64
  {
    return self.mass / self.getVolume();
  }


  pub inline fn setRadiusViaArea( self : *BodyComp, area : f64 ) void
  {
    const r2 = area / ( 4.0 * def.PI );

    self.radius = def.sqrt( r2 );
  }
  pub inline fn setRadiusViaVolume( self : *BodyComp, volume : f64 ) void
  {
    const r3 = volume * 3.0 / ( 4.0 * def.PI );

    self.radius = def.cbrt( r3 );
  }

  pub inline fn setMassViaDensity( self : *BodyComp, density : f64 ) void
  {
    self.mass = density * self.getVolume();
  }

  pub inline fn setRadiusViaDensity( self : *BodyComp, density : f64 ) void
  {
    const v = self.mass / density;

    self.setRadiusViaVolume( v );
  }


  // ================================ ECONOMIES ================================

  pub fn getEcon( self : *BodyComp, econLoc : EconLoc ) *ecn.Economy
  {
    return &self.econArray[ econLoc.toIdx() ];
  }

  /// NOTE : bodyComp.radius needs to be set beforhand
  pub fn quickInitEcon( self : *BodyComp, loc : EconLoc, activate : bool ) void
  {
    if( self.radius < def.EPS )
    {
      def.log( .WARN, 0, @src(), "BodyComp radius not set for {s} : will result in area errors", .{ @tagName( self.name )});
    }
    const econ : *ecn.Economy = self.getEcon( loc );

    econ.softInit( loc );

    // Checking if the econ is valid and active according to bodyType and activate
    if( self.bodyType.canHostEconLoc( loc ))
    {
      if( loc == .GROUND )
      {
        if( self.name == .TERRA ){ econ.hardInit( loc, self.getSurfaceArea(), 0.6, true  ); } // TERRA is hardocded to have an atmosphere
        else{                      econ.hardInit( loc, self.getSurfaceArea(), 0.1, false ); }
      } else{                      econ.hardInit( loc, 1_000_000_000_000_000, 1.0, false ); }

      econ.isActive = activate;
    }
    else if( activate )
    {
      def.log( .ERROR, 0, @src(), "Failed to initialize economy at {s}_{s} : invalid location", .{ @tagName( self.name ), @tagName( loc )});
    }
  }

  pub fn softInitAllEcons( self : *BodyComp ) void
  {
    if( self.radius < def.EPS )
    {
      def.log( .WARN, 0, @src(), "BodyComp radius not set for {s} : will result in area errors", .{ @tagName( self.name )});
    }

    for( 0..gdf.EconLoc.count )| i |
    {
      const loc  : gdf.EconLoc  = .fromIdx( i );
      const econ : *ecn.Economy = self.getEcon( loc );

      econ.softInit( loc );
    }
  }

  pub fn tickAllEcons( self : *BodyComp, orbiterPos : def.Vec2, orbiterVel : def.Vec2, starPos : def.Vec2 ) void
  {
    for( 0..self.bodyType.getEconLocCount() )| i |
    {
      const loc  : gdf.EconLoc  = .fromIdx( i );
      const econ : *ecn.Economy = self.getEcon( loc );

      gdf.updateOrbitalDataEntry( self, loc, orbiterPos, orbiterVel, starPos );

      _ = econ.tryTick( econ.sunshine ); // NOTE : econ sunshine updated in updateOrbitalDataEntry()
    }
  }

  pub fn logEcon( self : *const BodyComp, loc : gdf.EconLoc ) void
  {
    const econ : *const ecn.Economy = self.getEcon( loc );

    if( econ.isActive ) // TODO : Activate locs when player build infra there
    {
      econ.logPopCount();
      econ.logResMetrics();
      econ.logInfMetrics();
    }
  }

  pub fn debugSetEconState( self : *BodyComp, loc : gdf.EconLoc, value : u64 ) void
  {
    const econ : *ecn.Economy = self.getEcon( loc );

    if( econ.isActive ) // TODO : Activate locs when player build infra there
    {
      econ.debugSetEconState( value );
    }
  }
};