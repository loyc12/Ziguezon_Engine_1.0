const std = @import( "std" );
const def = @import( "defs" );

const gbl = @import( "gameGlobals.zig" );
const gdf = @import( "gameDefs.zig"    );

const times  = &gbl.G_DATA.times;
const stores = &gbl.G_DATA.stores;
const target = &gbl.G_DATA.target;
const nttArr = &gbl.G_DATA.entityArray;

const BodyName  = gdf.BodyName;
const BodyType  = gdf.BodyType;
const bodyCount = gdf.G_CONSTS.bodyCount;

const orb = gdf.orb;
const bdy = gdf.bdy;
const ecn = gdf.econ;


// ================================ STATE INJECT ================================

inline fn initStar( bodyComp : *bdy.BodyComp, bodyName : BodyName ) void
{
  bodyComp.bodyType = .fromFlt( gbl.STLR_DATA.get( bodyName, .TYPE ));
  bodyComp.name     = bodyName;
  bodyComp.mass     = gbl.STLR_DATA.get( bodyName, .MASS );
  bodyComp.radius   = gbl.STLR_DATA.get( bodyName, .RADIUS );

  bodyComp.softInitAllEcons();

  // TODO : find a better way to manage shine
  if( bodyName == .SOL )
  {
    const terraMin = gbl.STLR_DATA.get( .TERRA, .PERIAP );
    const terraMax = gbl.STLR_DATA.get( .TERRA, .APOAP  );

    gbl.SUNSHINE.setShineAt( 1.0, @sqrt( terraMin * terraMax ));
  }
}

fn initStellarBody( orbitComp : *orb.OrbitComp, bodyComp : *bdy.BodyComp, bodyName : BodyName, orbitedId : def.EntityId ) void
{
  const orbiterMass = gbl.STLR_DATA.get( bodyName, .MASS );
  var   orbitedMass = gbl.STLR_DATA.get( .SOL,     .MASS );

  if( orbitedId != gdf.G_CONSTS.starId ){ if( stores.body.get( orbitedId ))| b |
  {
    orbitedMass = b.mass;
  }
  else
  {
    def.log( .WARN, 0, @src(), "Failed to find bodyComp for id {d} : defaulting to using star's mass", .{ orbitedId });
  }}

  bodyComp.bodyType = .fromFlt( gbl.STLR_DATA.get( bodyName, .TYPE ));
  bodyComp.name     = bodyName;
  bodyComp.mass     = orbiterMass;
  bodyComp.radius   = gbl.STLR_DATA.get( bodyName, .RADIUS );

  orbitComp.* = .initFromParams(
    orbitedMass,       orbiterMass,
    gbl.STLR_DATA.get( bodyName, .PERIAP ),
    gbl.STLR_DATA.get( bodyName, .APOAP  ),
    gbl.STLR_DATA.get( bodyName, .LONG   ),
    null,
    bodyComp.bodyType.getDisplayColour(),
  );
  orbitComp.orbitedID = orbitedId;

  bodyComp.softInitAllEcons();

  if( bodyName == .TERRA )
  {
    bodyComp.quickInitEcon( .GROUND, true );
    bodyComp.debugSetEconState( .GROUND, 100_000 ); // Setup a 1B pop econ

  }
  if( gdf.G_FLAGS.STRESS_TEST )
  {
    inline for( 0..gdf.EconLoc.count )| l |
    {
      const loc = gdf.EconLoc.fromIdx( l );

      if( bodyComp.bodyType.canHostEconLoc( loc ))
      {
        if( bodyName != .TERRA or loc != .GROUND )
        {
          bodyComp.quickInitEcon(     loc, true );
          bodyComp.debugSetEconState( loc, @divFloor( gdf.G_FLAGS.DEFAULT_POP, 10_000 )); // Setup a 10K pop econ
          bodyComp.getEcon( loc ).addInfCount( .HABITAT, @divFloor( gdf.G_FLAGS.DEFAULT_POP, 10 ));
        }
      }
    }
  }
}


pub fn initStellarSystem( ng : *def.Engine ) void
{
  // Setting up relevant components
  for( 0..bodyCount )| idx |
  {
    nttArr[ idx ] = ng.entityIdRegistry.getNewEntity();

    const id = nttArr[ idx ].id;

    def.log( .INFO, 0, @src(), "Initializing components of entity #{d} at idx #{d}", .{ id, idx });


    // Non-sun component instanciation

    var orbitComp : orb.OrbitComp = undefined;
    var bodyComp  : bdy.BodyComp  = .{};

    switch( id ) // Adjusting bodyType-specific orbitComp and bodyComp variables
    {
      1  => initStar( &bodyComp, .SOL ),
      2  => initStellarBody( &orbitComp, &bodyComp, .DEBUGY,  1 ),

      3  => initStellarBody( &orbitComp, &bodyComp, .MERCURY, 1 ),
      4  => initStellarBody( &orbitComp, &bodyComp, .VENUS,   1 ),
      5  => initStellarBody( &orbitComp, &bodyComp, .TERRA,   1 ),
      6  => initStellarBody( &orbitComp, &bodyComp, .LUNA,    5 ),
      7  => initStellarBody( &orbitComp, &bodyComp, .MARS,    1 ),
      8  => initStellarBody( &orbitComp, &bodyComp, .PHOBOS,  7 ),
      9  => initStellarBody( &orbitComp, &bodyComp, .DEIMOS,  7 ),

      10 => initStellarBody( &orbitComp, &bodyComp, .CERES,   1 ),
      11 => initStellarBody( &orbitComp, &bodyComp, .VESTA,   1 ),
      12 => initStellarBody( &orbitComp, &bodyComp, .PALLAS,  1 ),
      13 => initStellarBody( &orbitComp, &bodyComp, .HYGIEA,  1 ),
      14 => initStellarBody( &orbitComp, &bodyComp, .EUROPEA, 1 ),
      15 => initStellarBody( &orbitComp, &bodyComp, .DAVIDA,  1 ),
      16 => initStellarBody( &orbitComp, &bodyComp, .SYLVIA,  1 ),

      17 => initStellarBody( &orbitComp, &bodyComp, .JUPITER, 1 ),
      18 => initStellarBody( &orbitComp, &bodyComp, .SATURN,  1 ),
      19 => initStellarBody( &orbitComp, &bodyComp, .URANUS,  1 ),
      20 => initStellarBody( &orbitComp, &bodyComp, .NEPTUNE, 1 ),

      else => // Will ignore all subsequent Ids ( should have none left )
      {
        def.log( .INFO, 0, @src(), "Id #{d} is invalid: will not initialize related comps", .{ id });
        continue;
      },
    }

    var startPos : def.Vec2 = .{};

    if( id != gdf.G_CONSTS.starId )
    {
      startPos = orbitComp.getRelPos(); // Getting initial position from orbit

      if( orbitComp.orbitedID != gdf.G_CONSTS.starId )
      {
        if( stores.trans.get( orbitComp.orbitedID ))| trans |
        {
          startPos = startPos.add( trans.pos.toVec2() );
        }
        else
        {
          def.log( .WARN, 0, @src(), "Failed to find bodyComp for id {d} : defaulting to using star's mass", .{ orbitComp.orbitedID });
        }
      }

      _ = stores.orbit.add( id, orbitComp ); // Adding this here because SOL doesn't need one
    }


    _ = stores.trans.add( id, .{ .pos = startPos.toVecA( .{} )});
    _ = stores.body.add(  id, bodyComp  );
    _ = stores.shape.add( id,
    .{
      .colour  = bodyComp.bodyType.getDisplayColour(),
      .minSize = bodyComp.bodyType.getMinDisplaySize(),
      .scale   = .new( bodyComp.radius, bodyComp.radius ),
      .shape   = .ELLI
    });

  }
}



// ================================ STEP INJECT ================================

pub fn updateCameraLogic() void
{
  var cam = &def.G_CAM;

  const scrollSpeed = gdf.G_CONSTS.scrollSpeed;
  const zoomSpeed   = gdf.G_CONSTS.zoomSpeed;

  // Moves the camera with the WASD or arrow keys
  if( def.ray.isKeyDown( def.ray.KeyboardKey.w ) or def.ray.isKeyDown( def.ray.KeyboardKey.up    )){ cam.moveByS( def.Vec2.new(  0.0, -scrollSpeed )); }
  if( def.ray.isKeyDown( def.ray.KeyboardKey.s ) or def.ray.isKeyDown( def.ray.KeyboardKey.down  )){ cam.moveByS( def.Vec2.new(  0.0,  scrollSpeed )); }
  if( def.ray.isKeyDown( def.ray.KeyboardKey.a ) or def.ray.isKeyDown( def.ray.KeyboardKey.left  )){ cam.moveByS( def.Vec2.new( -scrollSpeed,  0.0 )); }
  if( def.ray.isKeyDown( def.ray.KeyboardKey.d ) or def.ray.isKeyDown( def.ray.KeyboardKey.right )){ cam.moveByS( def.Vec2.new(  scrollSpeed,  0.0 )); }

  // Zooms in and out with the mouse wheel
  if( target.camFollow )
  {
    if( def.ray.getMouseWheelMove() > 0.0 ){ cam.zoomBy( 1.0 * zoomSpeed ); }
    if( def.ray.getMouseWheelMove() < 0.0 ){ cam.zoomBy( 1.0 / zoomSpeed ); }
  }
  else
  {
    if( def.ray.getMouseWheelMove() > 0.0 ){ cam.zoomOnMouseBy( 1.0 * zoomSpeed ); }
    if( def.ray.getMouseWheelMove() < 0.0 ){ cam.zoomOnMouseBy( 1.0 / zoomSpeed ); }
  }

  // Resets the camera zoom and position
  if( def.ray.isKeyPressed( def.ray.KeyboardKey.r ))
  {
    cam.setZoom( 1.0 );
    cam.pos = .{};
    def.qlog( .INFO, 0, @src(), "Camera reset" );
  }
}


pub fn tickOrbiters( transStore : *gdf.TransStore, orbitStore : *gdf.OrbitStore ) void
{
  var stepCount : u64 = 0;

  while( times.shouldBodyTick() )
  {
    stepCount += 1;
    times.consumeBodyTick();
  }

  if( stepCount == 0 ){ return; }


  for( 1..nttArr.len )| idx |
  {
    const id      = nttArr[ idx ].id;
    const orbiter = orbitStore.get( id );

    if( orbiter == null ){ continue; }

    const orbiterTrans = transStore.get( id );
    const orbitedTrans = transStore.get( orbiter.?.orbitedID );

    if( orbiterTrans != null and orbitedTrans != null )
    {
      def.log( .TRACE, 0, @src(), "Updating orbit of entity #{d}", .{ id });
      orbiter.?.updateOrbit( orbiterTrans.?, orbitedTrans.?, stepCount );
    }
    else
    {
      def.log( .WARN, 0, @src(), "Failed to get all required components to tick orbit of entity #{d}", .{ id });
    }
  }

//def.log( .DEBUG, 0, @src(), "Ticked all orbiters {d} steps", .{ stepCount });

  target.hasMoved = true; // Redundant for now since we update right after, but might become useful again later
}

pub fn tickGlobalEconomy( transStore : *gdf.TransStore, bodyStore : *gdf.BodyStore, starPos : def.Vec2 ) void
{
  var stepCount : u64 = 0;

  while( times.shouldEconTick() )
  {
    stepCount += 1;
    times.consumeEconTick();
  }

  if( stepCount == 0 ){ return; }

  for( 0..stepCount )| _ |
  {
    def.qlog( .DEBUG, 0, @src(), "==== Ticking all econs once ====" );

    var econCount : u32 = 0;

    inline for( 1..nttArr.len )| idx |
    {
      const id    = nttArr[ idx ].id;
      const trans = transStore.get( id );
      const body  = bodyStore.get(  id );

      if( trans != null and body != null )
      {
        econCount += body.?.tickAllEcons( trans.?.pos.toVec2(), trans.?.vel.toVec2(), starPos );
      }
      else
      {
        def.log( .WARN, 0, @src(), "Failed to get all required components to tick economy of entity #{d}", .{ id });
      }
    }

    // Update travel table from the fresh orbital data generated in tickAllEcons()
    gdf.trfSlvr.updateTravelTable();

    def.log( .DEBUG, 0, @src(), "Ticked {d} distinct economies", .{ econCount });
  }
  def.log( .DEBUG, 0, @src(), "==== Ticked global economy {d} time(s) ====", .{ stepCount });
}

pub fn renderOrbiters( transStore : *gdf.TransStore, shapeStore : *gdf.ShapeStore, orbitStore : *gdf.OrbitStore, bodyStore : *gdf.BodyStore ) void
{
  if( target.hasMoved ){ target.moveCamOver(); }

  // Rendering bodies' orbits and debug info
  for( 1..nttArr.len )| idx |
  {
    const id = nttArr[ idx ].id;

    def.log( .TRACE, 0, @src(), "Rendering path & dbg info of entity #{d} at idx #{d}", .{ id, idx });

    const orbiter = orbitStore.get( id );

    if( orbiter == null ){ continue; }

    const orbiterBody  = bodyStore.get(  id );
    const orbiterTrans = transStore.get( id );

    const orbitedTrans = transStore.get( orbiter.?.orbitedID );

    if( orbiterTrans != null and orbitedTrans != null and orbiterBody != null )
    {

      orbiter.?.renderPath( orbitedTrans.?.pos.toVec2() );

      if( target.targetId == id )
      {
        const orbitedPos = orbitedTrans.?.pos.toVec2();
        const orbitedVel = orbitedTrans.?.vel.toVec2();

        const orbiterPos = orbiterTrans.?.pos.toVec2();

        orbiter.?.renderDebug( orbitedVel, orbitedPos, orbiterPos, orbiterBody.?.radius, 1.0 );
        orbiter.?.renderLPs(   orbitedPos, orbiterBody.?.bodyType.getLPCount() );
      }
    }
    else
    {
      def.log( .WARN, 0, @src(), "Failed to get all required components to render orbital path of entity #{d}", .{ id });
    }
  }

  // Rendering bodies
  for( 0..nttArr.len )| i |
  {
    const idx = nttArr.len - ( i + 1 ); // Render in opposite order, to ensure planets are above moons
    const id  = nttArr[ idx ].id;

    def.log( .TRACE, 0, @src(), "Rendering shape of entity #{d} at idx #{d}", .{ id, idx });

    const trans = transStore.get( id );
    const shape = shapeStore.get( id );

    if( trans != null and shape != null )
    {
      shape.?.render( trans.?.pos );
    }
    else
    {
      def.log( .WARN, 0, @src(), "Failed to get all required components to render shape of entity #{d}", .{ id });
    }
  }
}

pub fn drawTargetInfo( transStore : *gdf.TransStore, shapeStore : *gdf.ShapeStore, orbitStore : *gdf.OrbitStore, bodyStore : *gdf.BodyStore ) void
{
  const col   = def.G_ST.Graphic_Metrics_Colour.?;
  const posX  = def.getScreenWidth() - 16.0;
  const id    = target.targetId;

  if( id == 0 or id > bodyCount ){ return; }

  const trans = transStore.get( id );
  const shape = shapeStore.get( id );

  const orbit = if( id != gdf.G_CONSTS.starId ) orbitStore.get( id ) else null;
  const body  = if( id != gdf.G_CONSTS.starId ) bodyStore.get(  id ) else null;


  var lineCount : f32 = 1.0;

  def.drawTextRightFmt( "== Entity #{d} ==", .{ id }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.5;


  if( trans != null )
  {
    def.drawTextRightFmt( "{d:.3} :     posX", .{ trans.?.pos.x }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;
    def.drawTextRightFmt( "{d:.3} :     posY", .{ trans.?.pos.y }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;

    lineCount += 0.5;
  }

  if( shape != null )
  {
    def.drawTextRightFmt( "{d:.3} :  scaleX", .{ shape.?.scale.x }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;
    def.drawTextRightFmt( "{d:.3} :  scaleY", .{ shape.?.scale.y },. new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;

    lineCount += 0.5;
  }

  if( body != null ) // PLANETS AND CO.
  {
    def.drawTextRightFmt( "{d:.3} :     mass", .{ body.?.mass         }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;
    def.drawTextRightFmt( "{d:.3} :  radius",  .{ body.?.radius       }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;
    def.drawTextRightFmt( "{d:.3} : density",  .{ body.?.getDensity() }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;

    if( target.targetId == gdf.G_CONSTS.starId )
    {
      def.drawTextRightFmt( "{d:.3} :    shine", .{ gbl.SUNSHINE.shineStrenght }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;
    }

    lineCount += 0.5;
  }

  if( orbit != null )
  {
    def.drawTextRightFmt( "{d:.3} :      minR", .{ orbit.?.minRadius }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;
    def.drawTextRightFmt( "{d:.3} :     maxR",  .{ orbit.?.maxRadius }, .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;

    lineCount += 0.5;
  }

  if( target.camFollow )
  {
    def.drawTextRight( "Traking ON", .new( posX, lineCount * 32.0 ), 24, col ); lineCount += 1.0;
    lineCount += 0.5;
  }
}