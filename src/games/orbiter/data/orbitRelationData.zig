const std = @import( "std" );
const gdf = @import( "../gameDef.zig" );

const BodyName = gdf.BodyName;


pub const bodyOrder = [_]BodyName
{
  .SOL,

  .MERCURY,
  .VENUS,
  .TERRA,
  .LUNA,

  .MARS,
  .PHOBOS,
  .DEIMOS,

  .CERES,
  .VESTA,
  .PALLAS,
  .HYGIEA,
  .EUROPEA,
  .DAVIDA,
  .SYLVIA,

  .JUPITER,
  .SATURN,
  .URANUS,
  .NEPTUNE,

  .DEBUGY,
};

pub const OrbitRelationPair = struct
{
  orbiter : BodyName,
  orbited : BodyName,
};

pub const orbitRelationPairs = [_]OrbitRelationPair
{
  .{ .orbiter = .MERCURY, .orbited = .SOL   },
  .{ .orbiter = .VENUS,   .orbited = .SOL   },

  .{ .orbiter = .TERRA,   .orbited = .SOL   },
  .{ .orbiter = .LUNA,    .orbited = .TERRA },

  .{ .orbiter = .MARS,    .orbited = .SOL   },
  .{ .orbiter = .PHOBOS,  .orbited = .MARS  },
  .{ .orbiter = .DEIMOS,  .orbited = .MARS  },

  .{ .orbiter = .CERES,   .orbited = .SOL   },
  .{ .orbiter = .VESTA,   .orbited = .SOL   },
  .{ .orbiter = .PALLAS,  .orbited = .SOL   },
  .{ .orbiter = .HYGIEA,  .orbited = .SOL   },
  .{ .orbiter = .EUROPEA, .orbited = .SOL   },
  .{ .orbiter = .DAVIDA,  .orbited = .SOL   },
  .{ .orbiter = .SYLVIA,  .orbited = .SOL   },

  .{ .orbiter = .JUPITER, .orbited = .SOL   },
  .{ .orbiter = .SATURN,  .orbited = .SOL   },
  .{ .orbiter = .URANUS,  .orbited = .SOL   },
  .{ .orbiter = .NEPTUNE, .orbited = .SOL   },

  .{ .orbiter = .DEBUGY,  .orbited = .SOL   },
};


comptime
{
  if( bodyOrder.len != BodyName.count )
  {
    @compileError( "bodyOrder must list every BodyName exactly once" );
  }

  for( bodyOrder, 0.. )| bodyName, idx |
  {
    for( bodyOrder[ 0..idx ] )| prevName |
    {
      if( bodyName == prevName ){ @compileError( "bodyOrder contains duplicate BodyName entries" ); }
    }

    var parentCount : usize = 0;
    var parentIdx   : usize = 0;

    for( orbitRelationPairs )| pair |
    {
      if( pair.orbiter == .SOL ){ @compileError( "SOL must not have an orbit parent" ); }

      if( pair.orbiter == bodyName )
      {
        parentCount += 1;

        var parentFound = false;
        for( bodyOrder, 0.. )| parentName, pIdx |
        {
          if( parentName == pair.orbited )
          {
            parentFound = true;
            parentIdx   = pIdx;
            break;
          }
        }

        if( !parentFound ){ @compileError( "Static orbit parent is missing from bodyOrder" ); }
      }
    }

    if( bodyName == .SOL )
    {
      if( parentCount != 0 ){ @compileError( "SOL must not have an orbit parent" ); }
    }
    else
    {
      if( parentCount != 1 ){ @compileError( "Every non-star body must have exactly one static orbit parent" ); }
      if( parentIdx >= idx ){ @compileError( "Static orbit parent must come before child in bodyOrder" ); }
    }
  }
}


pub fn getBodyOrderIdx( bodyName : BodyName ) ?usize
{
  for( bodyOrder, 0.. )| name, idx |
  {
    if( name == bodyName ){ return idx; }
  }

  return null;
}

pub fn getOrbitedName( orbiter : BodyName ) ?BodyName
{
  for( orbitRelationPairs )| pair |
  {
    if( pair.orbiter == orbiter ){ return pair.orbited; }
  }

  return null;
}
