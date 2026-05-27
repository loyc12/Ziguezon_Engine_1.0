const std = @import( "std" );
const def = @import( "defs" );


const gbl = @import( "../gameGlobals.zig" );
const gdf = @import( "../gameDefs.zig" );

const EntityId = def.EntityId;
const BodyName = gdf.BodyName;


pub inline fn idFromName( n : BodyName ) EntityId { return n.toNttId();             }
pub inline fn nameFromId( i : EntityId ) BodyName { return BodyName.fromNttId( i ); }


pub const OrbitTree = struct
{
  const arrayLen = gdf.G_CONSTS.bodyCount + 1;
  const maxNttId = gdf.G_CONSTS.maxEntityId;


  targetArray : [ arrayLen ]EntityId = undefined, // Maps each orbiter ( idx = id ) to and orbited ( id )


  pub inline fn new() OrbitTree
  {
    var self : OrbitTree = .{};

    inline for( 0..arrayLen )| idx |
    {
      self.targetArray[ idx ] = 0; // No 0th entity id
    }

    return self;
  }

  /// Usage : orbitTree.setOrbitance( moon, earth );
  pub inline fn addOrbitance( self : *OrbitTree, orbiterId : EntityId, orbitedId : EntityId ) void
  {
    if( orbiterId == 0 )
    {
      def.qlog( .WARN, 0, @src(), "Tried to modify orbit for entityId 0 : returning" );
      return;
    }

    if( orbitedId > maxNttId or orbiterId > maxNttId )
    {
      def.log( .WARN, 0, @src(), "Invalid id ( {d} & {d} ) : cannot be greater than maximum id ( {d} ) : returning", .{ orbiterId, orbitedId, maxNttId });
      return;
    }

    def.log( .CONT, 0, @src(), "{d} > {d}  ( {s} > {s} )", .{ orbiterId, orbitedId, @tagName( nameFromId( orbiterId )), @tagName( nameFromId( orbitedId ))});

    self.targetArray[ @intCast( orbiterId )] = orbitedId;
  }


  /// Allows itterating over all orbiterIds linked to an orbitedId without allocating memory, via successive calls
  /// Finds and returns the lowest entityId that orbits orbitedId, ignoring all entries lower than prevId + 1
  /// Returns 0 ( invalid id ) if no orbiterId was found
  pub inline fn getNextOrbiterId( self : *OrbitTree, targetOrbitedId : EntityId, prevId : EntityId ) EntityId
  {
    const startId = prevId + 1;

    if( startId > maxNttId )
    {
      def.log( .WARN, 0, @src(), "Tried to lookup orbitedIds past maxNttId ( {d} + 1 > {d} ) : returning 0", .{ prevId, maxNttId });
      return 0;
    }

    for( startId..arrayLen )| orbiterId |
    {
      const orbitedId = self.targetArray[ orbiterId ];

      if( orbitedId == targetOrbitedId )
      {
        def.log( .DEBUG, 0, @src(), "Found an orbiter with id {d}", .{ orbiterId });

        return orbiterId;
      }
    }

    return 0; // Invalid id == no additional orbiter found
  }


  pub inline fn getOrbitedId( self : *OrbitTree, orbiterId : EntityId ) EntityId
  {
    return self.targetArray[ @intCast( orbiterId )];
  }
};


pub var orbitTree : OrbitTree = undefined;


pub inline fn loadOrbitanceTree() void
{
  orbitTree = OrbitTree.new();

   def.qlog( .DEBUG, 0, @src(), "Loading orbitance :" );

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
