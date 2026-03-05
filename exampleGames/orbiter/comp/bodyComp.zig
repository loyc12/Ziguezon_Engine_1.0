const std = @import( "std" );
const def = @import( "defs" );

const glb = @import( "../gameGlobals.zig" );
const orb = @import( "orbitComp.zig" );

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

  pub fn initEcon( self : *BodyComp, loc : ecn.EconLoc ) void
  {
    var econ : ecn.Economy = undefined;

    if( loc == .GROUND ) // TODO : add useableLand modifier ( ex : what proportion is solid ground )
    {
      econ = ecn.Economy.newEcon( loc, self.getSurfaceArea(), true ); // TODO : Stop giving all GROUND an atmosphere
    }
    else
    {
      econ = ecn.Economy.newEcon( loc, 1_000_000_000.0, true );
    }

    self.econArray[ loc.toIdx() ] = econ;
  }

  pub fn tickEcons( self : *BodyComp, selfOrbit : *const orb.OrbitComp, orbitedPos : def.Vec2, starPos : def.Vec2 ) void
  {
    for( 0..self.bodyType.getEconLocCount() )| i |
    {
      const econ : *ecn.Economy = &self.econArray[ i ];

      if( econ.isActive ) // TODO : Activate locs when player build infra there
      {
        const econPos    = selfOrbit.getEconAbsPos( orbitedPos, econ.location );
        const distSquare = econPos.getDistSqr( starPos );
        var   shine      = glb.starCompInst.getSunshineAt( distSquare );

        if( econ.location == .GROUND ){ shine *= 0.5; } // Losing efficiency from nightime

        def.log( .INFO, 0, @src(), "Ticking {s} econ with sunshine of {d:.4} at pos {d:.2}:{d:.2}", .{ @tagName( econ.location ), shine, econPos.x, econPos.y });

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
        econ.popCount =       ( value * 1600 );
        econ.debugSetResCounts( value * 1600 );
        econ.debugSetInfCounts( value );
        econ.debugSetIndCounts( value );
      }
    }
  }
};