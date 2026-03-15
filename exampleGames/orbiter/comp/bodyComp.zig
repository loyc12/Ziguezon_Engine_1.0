const std = @import( "std" );
const def = @import( "defs" );

const glb = @import( "../gameGlobals.zig" );
const orb = @import( "orbitComp.zig" );

const ecn = @import( "economy.zig" );


pub const BodyType = enum( u8 )
{
  pub const count = @typeInfo( BodyType ).@"enum".fields.len;

  pub inline fn toIdx( self : BodyType ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) BodyType {  return @enumFromInt( @as( u8, @intCast( i ))); }

  PLANET, // Has L1-5
  MOON,   // Has L1-2 only
  COMET,  // Has no LPs    // NOTE : Also includes asteroids, captured or otherwise


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

  bodyType : BodyType = .PLANET, // TODO : auto-assign type based on mass instead ? ( and orbital radius ? )

  // NOTE : defaults to earth values

  mass   : f64 = 5_972_000_000_000.0, // Gigatons   ( Gt )
  radius : f64 =             6_371.0, // kilometers ( km ) // NOTE : for gaseous worlds : radius at 1 atm
//temp   : f32 =               390.0, // Kelvins    ( Dk )
//tilt   : f32 =                 0.0, // Radians

  econArray : [ ecn.EconLoc.count ]ecn.Economy = std.mem.zeroes([ ecn.EconLoc.count ]ecn.Economy ),


  // Sphere surface area : 4πr^2
  pub inline fn getSurfaceArea( self : *const BodyComp ) f64
  {
    const r2  = self.radius * self.radius;
    const tmp = 4.0 * def.PI * r2;

    return tmp;
  }

  // Sphere volume : ( 4/3 )πr^3
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

  // NOTE : Radius needs to be properly set BEFORE calling this function
  pub fn initEcon( self : *BodyComp, loc : ecn.EconLoc ) void
  {
    var econ : ecn.Economy = undefined;

    if( loc == .GROUND ) // TODO : add useableLand modifier ( ex : what proportion is solid ground )
    {
      econ = ecn.Economy.newEcon( loc, self.getSurfaceArea(), 0.6, true ); // TODO : Stop giving all GROUND an atmosphere and 0.6 habitability
    }
    else
    {
      econ = ecn.Economy.newEcon( loc, 1_000_000_000.0, 1.0, true );
    }

    self.econArray[ loc.toIdx() ] = econ;
  }

  pub fn tickEcons( self : *BodyComp, orbiterPos : def.Vec2, starPos : def.Vec2 ) void
  {
    for( 0..self.bodyType.getEconLocCount() )| i |
    {
      const econ : *ecn.Economy = &self.econArray[ i ];

      if( econ.isActive ) // TODO : Activate locs when player build infra there
      {
        const distSqr = orbiterPos.getDistSqr( starPos );
        const shine   = glb.starCompInst.getSunshineAt( distSqr );

        def.log( .CONT, 0, @src(), "Ticking {s} econ with sunshine of {d:.4} ( day {d} )", .{ @tagName( econ.location ), shine, econ.dayCount + 1 });

        econ.tickEcon( shine );
      }
    }
  }

  pub fn getEcon( self : *BodyComp, econLoc : ecn.EconLoc ) *ecn.Economy
  {
    return &self.econArray[ econLoc.toIdx() ];
  }

  pub fn logEcons( self : *const BodyComp ) void
  {
    for( 0..self.bodyType.getEconLocCount() )| i |
    {
      const econ : *const ecn.Economy = &self.econArray[ i ];

      if( econ.isActive ) // TODO : Activate locs when player build infra there
      {
        econ.logPopCount();
        econ.logResCounts();
        econ.logInfCounts();
      }
    }
  }

  pub fn debugSetEconVals( self : *BodyComp, value : u64 ) void
  {
    for( 0..self.bodyType.getEconLocCount() )| i |
    {
      var econ : *ecn.Economy = &self.econArray[ i ];

      if( econ.isActive ) // TODO : Activate locs when player build infra there
      {
        econ.addPopCount(       value * 1600 );
        econ.debugSetResCounts( value * 1600 );
        econ.debugSetInfCounts( value );
        econ.debugSetIndCounts( value );
      }
    }
  }
};