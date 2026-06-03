const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );


const gbl = @import( "../gameGlobals.zig" );
const gdf = @import( "../gameDef.zig" );

const EntityId = eng.EntityId;
const BodyName = gdf.BodyName;


pub inline fn idFromName( n : BodyName ) EntityId { return n.toNttId();             }
pub inline fn nameFromId( i : EntityId ) BodyName { return BodyName.fromNttId( i ); }


pub const OrbitanceData = struct
{
  const arrayLen = gdf.G_CONSTS.bodyCount + 1;
  const maxNttId = gdf.G_CONSTS.maxEntityId;


  orbitArray : [ arrayLen ]EntityId = undefined, // Maps each orbiter ( idx == id ) to an orbited ( id )


  pub inline fn new() OrbitanceData
  {
    var self : OrbitanceData = .{};

    inline for( 0..arrayLen )| idx |
    {
      self.orbitArray[ idx ] = 0; // No 0th entity id
    }

    return self;
  }

  /// Usage : orbitTree.setOrbitance( moon, earth );
  pub inline fn addOrbitance( self : *OrbitanceData, orbiterId : EntityId, orbitedId : EntityId ) void
  {
    if( orbiterId == 0 )
    {
      utl.qlog( .WARN, 0, @src(), "Tried to modify orbit for entityId 0 : returning" );
      return;
    }

    if( orbitedId > maxNttId or orbiterId > maxNttId )
    {
      utl.log( .WARN, 0, @src(), "Invalid id ( {d} & {d} ) : cannot be greater than maximum id ( {d} ) : returning", .{ orbiterId, orbitedId, maxNttId });
      return;
    }

    utl.log( .CONT, 0, @src(), "{d} > {d}  ( {s} > {s} )", .{ orbiterId, orbitedId, @tagName( nameFromId( orbiterId )), @tagName( nameFromId( orbitedId ))});

    self.orbitArray[ @intCast( orbiterId )] = orbitedId;
  }


  /// Allows itterating over all orbiterIds linked to an orbitedId without allocating memory, via successive calls
  /// Finds and returns the lowest entityId that orbits orbitedId, ignoring all entries lower than prevId + 1
  /// Returns 0 ( invalid id ) if no orbiterId was found
  pub inline fn getNextOrbiterId( self : *OrbitanceData, targetOrbitedId : EntityId, prevId : EntityId ) EntityId
  {
    const startId = prevId + 1;

    if( startId > maxNttId )
    {
      utl.log( .WARN, 0, @src(), "Tried to lookup orbitedIds past maxNttId ( {d} + 1 > {d} ) : returning 0", .{ prevId, maxNttId });
      return 0;
    }

    for( startId..arrayLen )| orbiterId |
    {
      const orbitedId = self.orbitArray[ orbiterId ];

      if( orbitedId == targetOrbitedId )
      {
        utl.log( .DEBUG, 0, @src(), "Found an orbiter with id {d}", .{ orbiterId });

        return orbiterId;
      }
    }

    return 0; // Invalid id == no additional orbiter found
  }


  pub inline fn getOrbitedId( self : *OrbitanceData, orbiterId : EntityId ) EntityId
  {
    return self.orbitArray[ @intCast( orbiterId )];
  }
};


pub var orbitTree : OrbitanceData = undefined;


pub inline fn loadOrbitanceTree() void
{
  orbitTree = OrbitanceData.new();

//utl.qlog( .DEBUG, 0, @src(), "Loading orbitance :" );

  // NOTE : This should list all bodies except the main star
  orbitTree.addOrbitance( idFromName( .MERCURY  ), idFromName( .SOL   ));
  orbitTree.addOrbitance( idFromName( .VENUS,   ), idFromName( .SOL   ));

  orbitTree.addOrbitance( idFromName( .TERRA,   ), idFromName( .SOL   ));
  orbitTree.addOrbitance( idFromName( .LUNA,    ), idFromName( .TERRA ));

  orbitTree.addOrbitance( idFromName( .MARS,    ), idFromName( .SOL   ));
  orbitTree.addOrbitance( idFromName( .PHOBOS,  ), idFromName( .MARS  ));
  orbitTree.addOrbitance( idFromName( .DEIMOS,  ), idFromName( .MARS  ));

  orbitTree.addOrbitance( idFromName( .CERES,   ), idFromName( .SOL   ));
  orbitTree.addOrbitance( idFromName( .VESTA,   ), idFromName( .SOL   ));
  orbitTree.addOrbitance( idFromName( .PALLAS,  ), idFromName( .SOL   ));
  orbitTree.addOrbitance( idFromName( .HYGIEA,  ), idFromName( .SOL   ));
  orbitTree.addOrbitance( idFromName( .EUROPEA  ), idFromName( .SOL   ));
  orbitTree.addOrbitance( idFromName( .DAVIDA,  ), idFromName( .SOL   ));
  orbitTree.addOrbitance( idFromName( .SYLVIA,  ), idFromName( .SOL   ));

  orbitTree.addOrbitance( idFromName( .JUPITER  ), idFromName( .SOL   ));
  orbitTree.addOrbitance( idFromName( .SATURN,  ), idFromName( .SOL   ));
  orbitTree.addOrbitance( idFromName( .URANUS,  ), idFromName( .SOL   ));
  orbitTree.addOrbitance( idFromName( .NEPTUNE  ), idFromName( .SOL   ));

  orbitTree.addOrbitance( idFromName( .DEBUGY,  ), idFromName( .SOL   ));
}
