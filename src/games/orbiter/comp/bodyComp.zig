const std = @import( "std"  );
const eng = @import( "engine" );
const utl = @import( "utils" );

const gbl = @import( "../gameGlobals.zig" );
const gdf = @import( "../gameDef.zig"    );

const orb = gdf.orb;
const ecn = gdf.ecn;

const EconLoc  = gdf.EconLoc;
const BodyName = gdf.BodyName;
const BodyType = gdf.BodyType;

const invalidEconomyIds = [_]gdf.EconomyId{ .INVALID } ** EconLoc.count;


pub const BodyComp = struct // DISTINCT FROM ENGINE BUILTIN COMP
{
  pub const compStorePolicy : eng.CompStorePolicy = .PACKED;

  pub inline fn StoreType() type { return eng.CompStoreFactory( @This() ); }

  name     : BodyName = .DEBUGY, // NOTE : Should be overwritten. If more than one DEBUGY exists, something went wrong
  bodyType : BodyType = .PLANET, // TODO : infer type based on mass ( and orbit relationship ) instead ?

  // NOTE : defaults to earth values

  mass   : f64 = 5_972_000_000_000.0, // Gigatons   ( Gt )
  radius : f64 =             6_371.0, // kilometers ( km ) // NOTE : for gaseous worlds : radius at 1 atm pressure
//temp   : f32 =               390.0, // Kelvins    ( Dk )
//tilt   : f32 =                 0.0, // Radians

  econIds : [ EconLoc.count ]gdf.EconomyId = invalidEconomyIds,


  // Sphere surface area : 4πr^2
  pub inline fn getSurfaceArea( self : *const BodyComp ) f64
  {
    const r2  = self.radius * self.radius;
    const tmp = 4.0 * utl.PI * r2;

    return tmp;
  }

  // Sphere volume : (4/3)πr^3
  pub inline fn getVolume( self : *const BodyComp ) f64
  {
    const r3  = self.radius * self.radius * self.radius;
    const tmp = ( 4.0 * utl.PI * r3 ) / 3.0;

    return tmp;
  }

  pub inline fn getDensity( self : *const BodyComp ) f64
  {
    return self.mass / self.getVolume();
  }


  pub inline fn setRadiusViaArea( self : *BodyComp, area : f64 ) void
  {
    const r2 = area / ( 4.0 * utl.PI );

    self.radius = utl.sqrt( r2 );
  }
  pub inline fn setRadiusViaVolume( self : *BodyComp, volume : f64 ) void
  {
    const r3 = volume * 3.0 / ( 4.0 * utl.PI );

    self.radius = utl.cbrt( r3 );
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

  /// Returns the game-owned economy referenced by this body/location pair.
  pub inline fn getEcon( self : *const BodyComp, econLoc : EconLoc ) ?*ecn.Economy
  {
    return gbl.G_DATA.economies.get( self.econIds[ econLoc.toIdx() ] );
  }

  pub inline fn getEconConst( self : *const BodyComp, econLoc : EconLoc ) ?*const ecn.Economy
  {
    return gbl.G_DATA.economies.getConst( self.econIds[ econLoc.toIdx() ] );
  }

  fn getSettlementType( self : *const BodyComp, loc : EconLoc ) ?gdf.SettlementType
  {
    return switch( loc )
    {
      .GROUND => self.name.getDefaultSettlementType() orelse
        if( gdf.G_FLAGS.STRESS_TEST ) .surface else null, // TODO: replace stress fallback with real body settlement data.
      .ORBIT  => .orbital,

      // TODO: Add Lagrange settlement economies after the Phase 1A ownership
      // path is stable. Travel can still use L1-L5 as body locations.
      else    => null,
    };
  }

  fn ensureEconId( self : *BodyComp, loc : EconLoc ) ?gdf.EconomyId
  {
    if( !self.bodyType.canHostEconLoc( loc )){ return null; }
    if( self.getSettlementType( loc ) == null ){ return null; }

    const id = &self.econIds[ loc.toIdx() ];
    if( id.*.isValid() ){ return id.*; }

    id.* = gbl.G_DATA.economies.create( loc ) orelse .INVALID;
    if( !id.*.isValid() )
    {
      utl.log( .ERROR, @src(), "Failed to allocate economy reference for {s}_{s}", .{ @tagName( self.name ), @tagName( loc )});
      return null;
    }

    return id.*;
  }

  fn softInitEcon( self : *BodyComp, loc : EconLoc ) void
  {
    const id   = self.ensureEconId( loc ) orelse return;
    const econ = gbl.G_DATA.economies.get( id ) orelse return;

    econ.softInitForSettlement( loc, self.getSettlementType( loc ).? );
  }

  /// NOTE : bodyComp.radius needs to be set beforehand
  pub fn quickInitEcon( self : *BodyComp, loc : EconLoc, activate : bool ) void
  {
    if( self.radius < utl.EPS )
    {
      utl.log( .WARN, @src(), "BodyComp radius not set for {s} : will result in area errors", .{ @tagName( self.name )});
    }

    const settlementType = self.getSettlementType( loc ) orelse
    {
      if( activate )
      {
        utl.log( .WARN, @src(), "Deferred economy initialization at {s}_{s} : no Phase 1 settlement type", .{ @tagName( self.name ), @tagName( loc )});
      }
      return;
    };

    const econ : *ecn.Economy = self.getEcon( loc ) orelse blk:
    {
      const id = self.ensureEconId( loc ) orelse return;
      break :blk gbl.G_DATA.economies.get( id ) orelse return;
    };

    econ.softInitForSettlement( loc, settlementType );

    // Checking if the econ is valid and active according to bodyType and activate
    if( self.bodyType.canHostEconLoc( loc ))
    {
      if( loc == .GROUND )
      {
        const hasAtmo = switch( settlementType )
        {
          .surface => self.name == .TERRA, // TERRA preserves the old atmospheric baseline.
          .aerial  => true,
          else     => false,
        };
        const landCover : f64 = if( settlementType == .surface ) 0.25 else 0.50;

        econ.hardInitForSettlement( loc, settlementType, self.getSurfaceArea(), landCover, hasAtmo );
      } else{ econ.hardInitForSettlement( loc, settlementType, 1_000_000_000_000_000, 1.00, false ); }

      econ.isActive = activate;
    }
    else if( activate )
    {
      utl.log( .ERROR, @src(), "Failed to initialize economy at {s}_{s} : invalid location", .{ @tagName( self.name ), @tagName( loc )});
    }
  }

  pub fn softInitAllEcons( self : *BodyComp ) void
  {
    self.econIds = invalidEconomyIds;

    if( self.radius < utl.EPS )
    {
      utl.log( .WARN, @src(), "BodyComp radius not set for {s} : will result in area errors", .{ @tagName( self.name )});
    }

    self.softInitEcon( .GROUND );
    self.softInitEcon( .ORBIT  );
  }

  /// Updates cached orbital/sunshine data for each economy attached to this body.
  pub fn updateOrbitData( self : *BodyComp, orbiterPos : utl.Vec2, orbiterVel : utl.Vec2, starPos : utl.Vec2 ) void
  {
    for( 0..gdf.EconLoc.count )| i |
    {
      const loc : gdf.EconLoc = .fromIdx( i );
      const econ = self.getEcon( loc ) orelse continue;
      if( !econ.isActive ){ continue; }

      gdf.updateOrbitDataEntry( self, loc, orbiterPos, orbiterVel, starPos );
    }
  }

  pub fn logEcon( self : *const BodyComp, loc : gdf.EconLoc ) void
  {
    const econ : *const ecn.Economy = self.getEconConst( loc ) orelse return;

    if( econ.isActive ) // TODO : Activate locs when player build infra there
    {
      econ.logPopCount();
      econ.logResMetrics();
      econ.logInfMetrics();
    }
  }

  pub fn debugSetEconState( self : *BodyComp, loc : gdf.EconLoc, value : u64, sunshine : f64 ) void
  {
    const econ : *ecn.Economy = self.getEcon( loc ) orelse return;

    if( econ.isActive ) // TODO : Activate locs when player build infra there
    {
      econ.debugSetEconState( value, sunshine );
    }
  }
};
