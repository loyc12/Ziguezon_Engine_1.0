const std = @import( "std" );
const def = @import( "defs" );

const res = @import( "resource.zig" );

const EconLoc = @import( "econComp.zig" ).EconLoc;


pub const infTypeCount = @typeInfo( InfType ).@"enum".fields.len;

pub const InfType = enum( u8 )
{
  pub inline fn toIdx( self : InfType ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : u8 ) InfType { return @enumFromInt( @as( u8, @intCast( i ))); }

  HOUSING,      // Increases population cap
//AMENITIES,    // Services population needs
//EDUCATION,    // Generate research ( efficiency multiplier )
//COMMERCE,     // Increase tax revenues ?

  AGRONOMIC,    // Generate food ( solar powered )
  HYDROPONIC,   // Generate food ( grid powered )
  SOLAR_PLANT,  // Generate energy ( solar powered )
//POWER_PLANT,  // Generate energy ( fission / fusion )

//ROAD_NETWORK, // Grants cargo transport capacity locally
//POWER_GRID,   // Grants energy transport capacity locally
//ELEVATOR,     // Transports things to and from orbit
//LAUNCHPAD,    // Grants docking capacity to transport vessels

  PROBE_MINE,   // Extracts raw materials ( autonomous but restricted to asteroids )
  GROUD_MINE,   // Extracts raw materials
  REFINERY,     // Refines raw materials
  FACTORY,      // Create parts from refined materials
  ASSEMBLY,     // Assembles parts into infrastructure & vehicles

//WAREHOUSE,    // Grants resource storage capacity
//BATTERY,      // Grants power storage capacity

//STATION,      // Increase area of orbital locations


  pub fn getCost( self : InfType ) u32 // Assembly cost in parts
  {
    return switch( self )
    {
      .HOUSING     => 1,

      .AGRONOMIC   => 1,
      .HYDROPONIC  => 2,
      .SOLAR_PLANT => 2,

      .PROBE_MINE  => 1,
      .GROUD_MINE  => 2,
      .REFINERY    => 3,
      .FACTORY     => 4,
      .ASSEMBLY    => 5,
    };
  }

  pub fn getMass( self : InfType ) u32
  {
    return switch( self )
    {
      .HOUSING     => 2,

      .AGRONOMIC   => 1,
      .HYDROPONIC  => 5,
      .SOLAR_PLANT => 2,

      .PROBE_MINE  => 1,
      .GROUD_MINE  => 15,
      .REFINERY    => 10,
      .FACTORY     => 5,
      .ASSEMBLY    => 2,
    };
  }

  pub fn getArea( self : InfType ) u32
  {
    return switch( self )
    {
      .HOUSING     => 1,

      .AGRONOMIC   => 20,
      .HYDROPONIC  => 2,
      .SOLAR_PLANT => 15,

      .PROBE_MINE  => 1,
      .GROUD_MINE  => 10,
      .REFINERY    => 5,
      .FACTORY     => 5,
      .ASSEMBLY    => 10,
    };
  }

  pub fn getPop( self : InfType ) u32
  {
    return switch( self )
    {
      .HOUSING     => 10,

      .AGRONOMIC   => 2,
      .HYDROPONIC  => 5,
      .SOLAR_PLANT => 1,

      .PROBE_MINE  => 0,
      .GROUD_MINE  => 20,
      .REFINERY    => 15,
      .FACTORY     => 10,
      .ASSEMBLY    => 5,
    };
  }


  pub fn canBeBuilt( self : InfType, loc : EconLoc ) bool
  {
    if( loc == .COMET )
    {
      return switch( self )
      {
        .PROBE_MINE => true,
        else        => false,
      };
    }
    else if( loc == .GROUND )
    {
      return switch( self )
      {
        .HOUSING     => true,

        .AGRONOMIC   => true,
        .HYDROPONIC  => true,
        .SOLAR_PLANT => true,

        .GROUD_MINE  => true,
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
};


pub const InfInstance = struct
{
  infType  : InfType,
  infCount : u32 = 0,

  resConsPerInf : [ res.resTypeCount ]u32 = std.mem.zeroes([ res.resTypeCount ]u32 ),
  resProdPerInf : [ res.resTypeCount ]u32 = std.mem.zeroes([ res.resTypeCount ]u32 ),

  pub fn initByType( infType : InfType ) InfInstance
  {
    var instance : InfInstance = .{ .infType = infType };

    switch ( infType )
    {
      .HOUSING => // No resource production. Increases population cap instead
      {
        instance.addConsPerInf( .POWER, 1 );
      },
      .AGRONOMIC => // Requires sunlight
      {
        instance.addConsPerInf( .POWER, 1 );
        instance.addProdPerInf( .FOOD,  10 );
      },
      .HYDROPONIC =>
      {
        instance.addConsPerInf( .POWER, 5 );
        instance.addProdPerInf( .FOOD,  15 );
      },
      .SOLAR_PLANT => // No resource consumption. Requires sunlight
      {
        instance.addProdPerInf( .POWER, 20 );
      },
      .PROBE_MINE => // No resource consumption. Requires sunlight
      {
        instance.addProdPerInf( .ORE, 1 );
      },
      .GROUD_MINE =>
      {
        instance.addConsPerInf( .POWER, 5 );
        instance.addProdPerInf( .ORE,   1 );
      },
      .REFINERY =>
      {
        instance.addConsPerInf( .POWER, 5 );
        instance.addConsPerInf( .ORE,   1 );
        instance.addProdPerInf( .INGOT, 1 );
      },
      .FACTORY =>
      {
        instance.addConsPerInf( .POWER, 3 );
        instance.addConsPerInf( .INGOT, 1 );
        instance.addProdPerInf( .PART,  1 );
      },
      .ASSEMBLY => // No resource production. Increments build queue instead
      {
        instance.addConsPerInf( .POWER, 2 );
        instance.addProdPerInf( .PART,  1 );
      },
    }

    return instance;
  }


  // ================================ CONSUMPTION ================================

  pub fn getConsPerInf( self : *const InfInstance, resType : res.ResType ) u32
  {
    return self.resConsPerInf[ resType.toIdx() ];
  }
  pub fn setConsPerInf( self : *InfInstance, resType : res.ResType, value : u32 ) void
  {
    self.resConsPerInf[ resType.toIdx() ] = value;
  }
  pub inline fn addConsPerInf( self : *InfInstance, resType : res.resType, value : u32 ) void
  {
    self.resConsPerInf[ resType.toIdx() ] += value;
  }
  pub inline fn subConsPerInf( self : *InfInstance, resType : res.resType, value : u32 ) void
  {
    const count = @min( value, self.resConsPerInf[ resType.toIdx() ]);

    self.resConsPerInf[ resType.toIdx() ] -= count;

    if( value != count )
    {
      def.log( .WARN, 0, @src(), "Tried to remove {d} res of type {s} from InfInstance.resConsPerInf, but only had {d} left", .{ value, @tagName( resType ), count });
    }
  }


  // ================================ PRODUCTION ================================

  pub fn getProdPerInf( self : *const InfInstance, resType : res.ResType ) u32
  {
    return self.resProdPerInf[ resType.toIdx() ];
  }
  pub fn setProdPerInf( self : *InfInstance, resType : res.ResType, value : u32 ) void
  {
    self.resProdPerInf[ resType.toIdx() ] = value;
  }
  pub inline fn addProdPerInf( self : *InfInstance, resType : res.resType, value : u32 ) void
  {
    self.resProdPerInf[ resType.toIdx() ] += value;
  }
  pub inline fn subProdPerInf( self : *InfInstance, resType : res.resType, value : u32 ) void
  {
    const count = @min( value, self.resProdPerInf[ resType.toIdx() ]);

    self.resProdPerInf[ resType.toIdx() ] -= count;

    if( value != count )
    {
      def.log( .WARN, 0, @src(), "Tried to remove {d} res of type {s} from InfInstance.resProbPerInf, but only had {d} left", .{ value, @tagName( resType ), count });
    }
  }
};