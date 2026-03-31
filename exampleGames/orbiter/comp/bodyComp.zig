const std = @import( "std" );
const def = @import( "defs" );


const gbl = @import( "../gameGlobals.zig" );
const orb = gbl.orb;
const ecn = gbl.ecn;

const EconLoc = gbl.EconLoc;


pub const BodyType = enum( u8 )
{
  pub const count = @typeInfo( @This() ).@"enum".fields.len;

  pub inline fn toIdx( self : BodyType ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) BodyType {  return @enumFromInt( @as( u8, @intCast( i ))); }

//STAR,      // Has no LPs     Ex : Sol
  PLANET,    // Has L1-5       Ex : Earth,   Saturn
  PLANETOID, // Has L1-2 only  Ex : Ceres,   Pluto
  MOON,      // Has L1-2 only  Ex : Luna,    Titan
  MOONLET,   // Has no LPs     Ex : Phobos,  Deimos
  ASTEROID,  // Has no LPs     Ex : Common belt asteroids
  COMET,     // Has no LPs     Ex : Haley's, extreme orbits


  pub inline fn getMinDisplaySize( self : BodyType ) def.Vec2
  {
    return switch( self )
    {
    //.STAR      => .new( 8, 8 ),
      .PLANET    => .new( 4, 4 ),
      .PLANETOID => .new( 3, 3 ),
      .MOON      => .new( 4, 4 ),
      .MOONLET   => .new( 3, 3 ),
      .ASTEROID  => .new( 2, 2 ),
      .COMET     => .new( 2, 2 ),
    };
  }

  pub inline fn getDisplayColour( self : BodyType ) def.Colour
  {
    return switch( self )
    {
    //.STAR      => .gold,
      .PLANET    => .cerul,
      .PLANETOID => .lCerul,
      .MOON      => .nWhite,
      .MOONLET   => .pGray,
      .ASTEROID  => .lGray,
      .COMET     => .mGray,
    };
  }

  pub inline fn getEconLocCount( self : BodyType ) usize
  {
    return 2 + self.getLPCount();
  }

  pub inline fn getLPCount( self : BodyType ) usize
  {
    return switch( self )
    {
    //.STAR      => 0,
      .PLANET    => 5,
      .PLANETOID => 2,
      .MOON      => 2,
      .MOONLET   => 0,
      .ASTEROID  => 0,
      .COMET     => 0,
    };
  }

  // Whether or not the specified econLoc can be hosted on this bodyType
  pub inline fn canHostEconLoc( self : BodyType, loc : EconLoc ) bool
  {
    const locIdx = loc.toIdx();

    return( locIdx < self.getEconLocCount() );
  }
};


pub const BodyComp = struct // DISTINCT FROM ENGINE BUILTIN COMP
{
  pub inline fn getStoreType() type { return def.componentStoreFactory( @This() ); }

  name : gbl.StellarBodyEnum = .CUSTOM,
  bodyType : BodyType        = .PLANET, // TODO : auto-assign type based on mass instead ? ( and orbital radius ? )

  // NOTE : defaults to earth values

  mass   : f64 = 5_972_000_000_000.0, // Gigatons   ( Gt )
  radius : f64 =             6_371.0, // kilometers ( km ) // NOTE : for gaseous worlds : radius at 1 atm
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
  pub fn initEcon( self : *BodyComp, loc : EconLoc ) void
  {
    var econ : ecn.Economy = undefined;

    if( loc == .GROUND ) // TODO : Stop giving all GROUND an atmosphere and 0.6 landCover
    {
      econ = ecn.Economy.newEcon( loc, self.getSurfaceArea(), 0.6, true );
    }
    else
    {
      econ = ecn.Economy.newEcon( loc, 1_000_000_000.0, 1.0, true );
    }

    // Checking if the econ is allowed to exist according to bodyType
    if( self.bodyType.canHostEconLoc( loc ))
    {
      econ.isValid = true;
    }

    self.econArray[ loc.toIdx() ] = econ;
  }

  pub fn tickEcons( self : *BodyComp, orbiterPos : def.Vec2, starPos : def.Vec2 ) void
  {
    for( 0..self.bodyType.getEconLocCount() )| i |
    {
      const econ : *ecn.Economy = &self.econArray[ i ];

      if( econ.isValid )
      {
        const econPos = orbiterPos; // TODO : get precise pos for L1-L5 points instead of using orbiter pos
        const distSqr = econPos.getDistSqr( starPos );

        gbl.ECON_ROOT_RAD_DATA.set( gbl.toBodyEconPair( self.name, econ.location ), @sqrt( @sqrt( distSqr )));


        if( econ.isActive ) // TODO : Activate locations dynamically
        {
          const shine = gbl.starCompInst.getSunshineAt( distSqr );

          econ.tickEcon( shine );
        }
      }
      else
      {
        gbl.ECON_ROOT_RAD_DATA.set( gbl.toBodyEconPair( self.name, econ.location ), 0.0 );
      }
    }
  }

  pub fn getEcon( self : *BodyComp, econLoc : EconLoc ) *ecn.Economy
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
        econ.debugSetResCounts( value * 3200 );
        econ.debugSetInfCounts( value * 250  );
        econ.debugSetIndCounts( value        );
        econ.addPopCount(       value * 6400 );
      }
    }
  }
};