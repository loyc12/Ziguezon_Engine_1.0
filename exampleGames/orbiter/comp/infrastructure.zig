const std = @import( "std" );
const def = @import( "defs" );

const res = @import( "resource.zig" );

const EconLoc  = @import( "econComp.zig" ).EconLoc;
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
  GROUD_MINE,   // Extracts raw materials
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

  pub inline fn getMass( self : InfType ) u64
  {
    return comptime switch( self )
    {
      .HOUSING     => 2,

      .AGRONOMIC   => 1,
      .HYDROPONIC  => 5,
      .SOLAR_PLANT => 2,
      .WATER_PLANT => 2,

      .PROBE_MINE  => 1,
      .GROUD_MINE  => 15,
      .REFINERY    => 10,
      .FACTORY     => 5,
      .ASSEMBLY    => 2,
    };
  }

  pub inline fn getArea( self : InfType ) u64
  {
    return comptime switch( self )
    {
      .HOUSING     => 1,

      .AGRONOMIC   => 20,
      .HYDROPONIC  => 5,
      .SOLAR_PLANT => 15,
      .WATER_PLANT => 2,

      .PROBE_MINE  => 1,
      .GROUD_MINE  => 10,
      .REFINERY    => 5,
      .FACTORY     => 5,
      .ASSEMBLY    => 10,
    };
  }

  pub inline fn getPartCost( self : InfType ) u64 // Assembly cost in parts
  {
    return comptime switch( self )
    {
      .HOUSING     => 1,

      .AGRONOMIC   => 1,
      .HYDROPONIC  => 2,
      .SOLAR_PLANT => 3,
      .WATER_PLANT => 2,

      .PROBE_MINE  => 1,
      .GROUD_MINE  => 2,
      .REFINERY    => 3,
      .FACTORY     => 4,
      .ASSEMBLY    => 5,
    };
  }

  pub inline fn getJobCount( self : InfType ) u64
  {
    return switch( self )
    {
      .HOUSING     => 10,

      .AGRONOMIC   => 4,
      .HYDROPONIC  => 5,
      .SOLAR_PLANT => 2,
      .WATER_PLANT => 3,

      .PROBE_MINE  => 0,
      .GROUD_MINE  => 20,
      .REFINERY    => 15,
      .FACTORY     => 10,
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
        .SOLAR_PLANT => true,
        .WATER_PLANT => true,

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
      .HOUSING => // No resource production. Increases population cap instead
      {
        instance.addConsPerInf( .POWER, 1 );
        instance.addConsPerInf( .WATER, 1 );
      },
      .AGRONOMIC => // Requires sunlight
      {
        instance.powerSrc = .SOLAR;
        instance.addConsPerInf( .WATER, 10 );
        instance.addProdPerInf( .FOOD,  10 );
      },
      .HYDROPONIC =>
      {
        instance.addConsPerInf( .POWER, 5 );
        instance.addConsPerInf( .WATER, 5 );
        instance.addProdPerInf( .FOOD,  10 );
      },
      .SOLAR_PLANT => // No resource consumption. Requires sunlight
      {
        instance.powerSrc = .SOLAR;
        instance.addProdPerInf( .POWER, 20 );
      },
      .PROBE_MINE => // No resource consumption. Requires sunlight
      {
        instance.powerSrc = .SOLAR;
        instance.addProdPerInf( .ORE, 1 );
      },
      .GROUD_MINE =>
      {
        instance.addConsPerInf( .POWER, 5 );
        instance.addConsPerInf( .WATER, 1 );
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

  pub fn getResConsPerInf( self : *const InfInstance, resType : res.ResType ) u64
  {
    return self.resConsPerInf[ resType.toIdx() ];
  }
  pub fn setResConsPerInf( self : *InfInstance, resType : res.ResType, value : u64 ) void
  {
    self.resConsPerInf[ resType.toIdx() ] = value;
  }
  pub inline fn addResConsPerInf( self : *InfInstance, resType : res.resType, value : u64 ) void
  {
    self.resConsPerInf[ resType.toIdx() ] += value;
  }
  pub inline fn subResConsPerInf( self : *InfInstance, resType : res.resType, value : u64 ) void
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
  pub inline fn addResProdPerInf( self : *InfInstance, resType : res.resType, value : u64 ) void
  {
    self.resProdPerInf[ resType.toIdx() ] += value;
  }
  pub inline fn subResProdPerInf( self : *InfInstance, resType : res.resType, value : u64 ) void
  {
    const count = @min( value, self.resProdPerInf[ resType.toIdx() ]);

    self.resProdPerInf[ resType.toIdx() ] -= count;

    if( value != count )
    {
      def.log( .WARN, 0, @src(), "Tried to remove {d} res of type {s} from InfInstance.resProbPerInf, but only had {d} left", .{ value, @tagName( resType ), count });
    }
  }
};