const std = @import( "std" );
const def = @import( "defs" );

const res = @import( "resource.zig" );

const EconLoc  = @import( "economy.zig" ).EconLoc;
const PowerSrc = @import( "powerSrc.zig" ).PowerSrc;


pub const infTypeCount = @typeInfo( InfType ).@"enum".fields.len;

pub const InfType = enum( u8 )
{
  pub inline fn toIdx( self : InfType ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) InfType { return @enumFromInt( @as( u8, @intCast( i ))); }

  HOUSING,      // Increases population cap
//AMENITIES,    // Services population needs
//EDUCATION,    // Generate research ( efficiency multiplier )
//COMMERCE,     // Increase tax revenues ?

  AGRONOMIC,    // Generate food   ( solar powered )
  HYDROPONIC,   // Generate food   ( grid powered )
  WATER_PLANT,  // Generate water  ( grid powered )
  SOLAR_PLANT,  // Generate energy ( solar powered )
//POWER_PLANT,  // Generate energy ( fission / fusion )

  PROBE_MINE,   // Extracts raw materials ( autonomous but restricted to asteroids )
  GROUND_MINE,   // Extracts raw materials
  REFINERY,     // Refines  raw materials
  FACTORY,      // Create parts from refined materials
  ASSEMBLY,     // Assembles parts into infrastructure & vehicles

//ROAD_NETWORK, // Grants cargo  transport capacity locally
//POWER_GRID,   // Grants energy transport capacity locally
//ELEVATOR,     // Grants cargo  transport capacity to and from orbit
//POWER_BEAM,   // Grants energy transport capacity to and from orbit
//LAUNCHPAD,    // Grants docking capacity for vessels

//WAREHOUSE,    // Grants cargo storage capacity
//BATTERY,      // Grants energy storage capacity

//DATA_CENTER,
//TBA      // Increase area of pressurized locations

  pub inline fn getMass( self : InfType ) f32
  {
   return switch( self )
    {
      .HOUSING     => 2.0,

      .AGRONOMIC   => 1.0,
      .HYDROPONIC  => 5.0,
      .WATER_PLANT => 2.0,
      .SOLAR_PLANT => 2.0,

      .PROBE_MINE  => 2.0,
      .GROUND_MINE  => 15.0,
      .REFINERY    => 10.0,
      .FACTORY     => 5.0,
      .ASSEMBLY    => 3.0,
    };
  }

  pub inline fn getArea( self : InfType ) f32
  {
   return switch( self )
    {
      .HOUSING     => 1.0,

      .AGRONOMIC   => 25.0,
      .HYDROPONIC  => 5.0,
      .WATER_PLANT => 3.0,
      .SOLAR_PLANT => 15.0,

      .PROBE_MINE  => 1.0,
      .GROUND_MINE => 10.0,
      .REFINERY    => 5.0,
      .FACTORY     => 5.0,
      .ASSEMBLY    => 5.0,
    };
  }

  pub inline fn getPartCost( self : InfType ) u64 // Assembly cost in parts
  {
   return switch( self )
    {
      .HOUSING     => 1,

      .AGRONOMIC   => 1,
      .HYDROPONIC  => 2,
      .WATER_PLANT => 2,
      .SOLAR_PLANT => 3,

      .PROBE_MINE  => 1,
      .GROUND_MINE  => 2,
      .REFINERY    => 3,
      .FACTORY     => 4,
      .ASSEMBLY    => 5,
    };
  }

  pub inline fn canBeBuiltAt( self : InfType, loc : EconLoc, hasAtmosphere : bool ) bool
  {
    if( loc == .GROUND )
    {
      return switch( self )
      {
        .HOUSING     => true,

        .AGRONOMIC   => hasAtmosphere,
        .HYDROPONIC  => true,
        .WATER_PLANT => true,
        .SOLAR_PLANT => true,

        .GROUND_MINE => true,
        .REFINERY    => true,
        .FACTORY     => true,
        .ASSEMBLY    => true,

        else         => false,
      };
    }
    else // .ORBIT or .L1-5
    {
      return switch( self )
      {
        .HOUSING     => true,

        .HYDROPONIC  => true,
        .SOLAR_PLANT => true,

        .REFINERY    => true,
        .FACTORY     => true,
        .ASSEMBLY    => true,

        else         => false,
      };
    }
  }

  pub const POP_PER_HOUSE   : u64 = 20;
  pub const WORK_PER_HOUSE  : u64 = 20;
  pub const FOOD_PER_HOUSE  : u64 = 20;
  pub const WATER_PER_HOUSE : u64 = 5;
  pub const POWER_PER_HOUSE : u64 = 1;
};



pub const InfInstance = struct
{
  infType  : InfType,
  powerSrc : PowerSrc,

  infCount : u64 = 0,

  resConsPerInf : [ res.resTypeCount ]u64 = std.mem.zeroes([ res.resTypeCount ]u64 ),
  resProdPerInf : [ res.resTypeCount ]u64 = std.mem.zeroes([ res.resTypeCount ]u64 ),

  // NOTE : FOOD will be consumed by population to saturation before being available for use in infrastructure
  // NOTE : WORK should never be produce, as it scales base on population ( for now at least )

  pub fn initByType( infType : InfType ) InfInstance
  {
    var instance : InfInstance = .{ .infType = infType, .powerSrc = .GRID };

    switch ( infType )
    {
      .HOUSING => // Food and water are priority updates, directly in economy methods
      {
        // Can house 10 pop
      //instance.addResConsPerInf( .FOOD,  InfType.FOOD_PER_HOUSE  );
      //instance.addResConsPerInf( .WATER, InfType.WATER_PER_HOUSE );
        instance.addResConsPerInf( .POWER, InfType.POWER_PER_HOUSE );

        instance.addResProdPerInf( .WORK,  InfType.WORK_PER_HOUSE );
      },
      .AGRONOMIC =>
      {
        instance.powerSrc = .SOLAR;            // Delta roughly divided by two on GROUND due to being solar powered
        instance.addResConsPerInf( .WORK,  3 );
        instance.addResConsPerInf( .WATER, 5 );

        instance.addResProdPerInf( .FOOD,  20 );
      },
      .HYDROPONIC =>
      {
        instance.addResConsPerInf( .WORK,  5  );
        instance.addResConsPerInf( .POWER, 3  );
        instance.addResConsPerInf( .WATER, 5  );

        instance.addResProdPerInf( .FOOD,  15 );
      },
      .WATER_PLANT =>
      {
        instance.addResConsPerInf( .WORK,  3 );

        instance.addResConsPerInf( .POWER, 2  );
        instance.addResProdPerInf( .WATER, 20 );
      },
      .SOLAR_PLANT =>
      {
        instance.powerSrc = .SOLAR;            // Delta roughly divided by two on GROUND due to being solar powered
        instance.addResConsPerInf( .WORK,  2 );

        instance.addResProdPerInf( .POWER, 30 );
      },
      .PROBE_MINE => // No resource consumption.
      {
        instance.powerSrc = .SOLAR;            // Delta roughly divided by two on GROUND due to being solar powered
        instance.addResProdPerInf( .ORE, 2 );
      },
      .GROUND_MINE =>
      {
        instance.addResConsPerInf( .WORK,  10 );
        instance.addResConsPerInf( .POWER, 5  );
        instance.addResConsPerInf( .WATER, 1  );

        instance.addResProdPerInf( .ORE,   3  );
      },
      .REFINERY =>
      {
        instance.addResConsPerInf( .WORK,  8 );
        instance.addResConsPerInf( .POWER, 5 );
        instance.addResConsPerInf( .ORE,   4 );

        instance.addResProdPerInf( .INGOT, 3 );
      },
      .FACTORY =>
      {
        instance.addResConsPerInf( .WORK,  6 );
        instance.addResConsPerInf( .POWER, 2 );
        instance.addResConsPerInf( .INGOT, 4 );
        instance.addResConsPerInf( .WATER, 1  );

        instance.addResProdPerInf( .PART,  3 );
      },
      .ASSEMBLY => // No resource production. TODO : Increments build queue construction
      {
        instance.addResConsPerInf( .WORK,  4 );
        instance.addResConsPerInf( .POWER, 2 );
      },
    }

    return instance;
  }


  // ================================ CONSUMPTION ================================

  pub fn getResConsPerInf( self : *const InfInstance, resType : res.ResType ) u64
  {
    return self.resConsPerInf[ resType.toIdx() ];
  }
  pub fn setResConsPerInf( self : *InfInstance, resType : res.ResType, value : u64 ) void
  {
    self.resConsPerInf[ resType.toIdx() ] = value;
  }
  pub inline fn addResConsPerInf( self : *InfInstance, resType : res.ResType, value : u64 ) void
  {
    self.resConsPerInf[ resType.toIdx() ] += value;
  }
  pub inline fn subResConsPerInf( self : *InfInstance, resType : res.ResType, value : u64 ) void
  {
    const count = @min( value, self.resConsPerInf[ resType.toIdx() ]);

    self.resConsPerInf[ resType.toIdx() ] -= count;

    if( value != count )
    {
      def.log( .WARN, 0, @src(), "Tried to remove {d} res of type {s} from InfInstance.resConsPerInf, but only had {d} left", .{ value, @tagName( resType ), count });
    }
  }


  // ================================ PRODUCTION ================================

  pub fn getResProdPerInf( self : *const InfInstance, resType : res.ResType ) u64
  {
    return self.resProdPerInf[ resType.toIdx() ];
  }
  pub fn setResProdPerInf( self : *InfInstance, resType : res.ResType, value : u64 ) void
  {
    self.resProdPerInf[ resType.toIdx() ] = value;
  }
  pub inline fn addResProdPerInf( self : *InfInstance, resType : res.ResType, value : u64 ) void
  {
    self.resProdPerInf[ resType.toIdx() ] += value;
  }
  pub inline fn subResProdPerInf( self : *InfInstance, resType : res.ResType, value : u64 ) void
  {
    const count = @min( value, self.resProdPerInf[ resType.toIdx() ]);

    self.resProdPerInf[ resType.toIdx() ] -= count;

    if( value != count )
    {
      def.log( .WARN, 0, @src(), "Tried to remove {d} res of type {s} from InfInstance.resProbPerInf, but only had {d} left", .{ value, @tagName( resType ), count });
    }
  }
};