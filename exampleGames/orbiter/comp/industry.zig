const std = @import( "std" );
const def = @import( "defs" );

const res = @import( "resource.zig" );

const EconLoc  = @import( "economy.zig" ).EconLoc;
const PowerSrc = @import( "powerSrc.zig" ).PowerSrc;


pub const indTypeCount = @typeInfo( IndType ).@"enum".fields.len;

pub const IndType = enum( u8 )
{
  pub inline fn toIdx( self : IndType ) usize { return @intFromEnum( self ); }
  pub inline fn fromIdx( i : usize ) IndType  { return @enumFromInt( @as( u8, @intCast( i ))); }

  AGRONOMIC,    // Generate food   ( solar powered )
  HYDROPONIC,   // Generate food   ( grid powered )
  WATER_PLANT,  // Generate water  ( grid powered )
  SOLAR_PLANT,  // Generate energy ( solar powered )
//POWER_PLANT,  // Generate energy ( fission / fusion )

  PROBE_MINE,   // Extracts raw materials ( autonomous but restricted to asteroids )
  GROUND_MINE,  // Extracts raw materials
  REFINERY,     // Refines  raw materials
  FACTORY,      // Create parts from refined materials
  ASSEMBLY,     // Assembles parts into industry, infrastructure & vehicles


  pub inline fn getMass( self : IndType ) f32
  {
    return switch( self )
    {
      .AGRONOMIC   => 1.0,
      .HYDROPONIC  => 5.0,
      .WATER_PLANT => 2.0,
      .SOLAR_PLANT => 2.0,

      .PROBE_MINE  => 2.0,
      .GROUND_MINE => 15.0,
      .REFINERY    => 10.0,
      .FACTORY     => 5.0,
      .ASSEMBLY    => 3.0,
    };
  }

  pub inline fn getAreaCost( self : IndType ) f32
  {
    return switch( self )
    {
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

  pub inline fn getPartCost( self : IndType ) u64 // Assembly cost in parts
  {
    return switch( self )
    {
      .AGRONOMIC   => 1,
      .HYDROPONIC  => 2,
      .WATER_PLANT => 2,
      .SOLAR_PLANT => 3,

      .PROBE_MINE  => 1,
      .GROUND_MINE => 2,
      .REFINERY    => 3,
      .FACTORY     => 4,
      .ASSEMBLY    => 5,
    };
  }

  pub inline fn canBeBuiltAt( self : IndType, loc : EconLoc, hasAtmosphere : bool ) bool
  {
    if( loc == .GROUND )
    {
      return switch( self )
      {
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
        .HYDROPONIC  => true,
        .SOLAR_PLANT => true,

        .REFINERY    => true,
        .FACTORY     => true,
        .ASSEMBLY    => true,

        else         => false,
      };
    }
  }

  // TODO : Add maintenance costs ?
};



pub const IndInstance = struct
{
  indType  : IndType,
  powerSrc : PowerSrc,

  indCount : u64 = 0,

  resConsPerInd : [ res.resTypeCount ]u64 = std.mem.zeroes([ res.resTypeCount ]u64 ),
  resProdPerInd : [ res.resTypeCount ]u64 = std.mem.zeroes([ res.resTypeCount ]u64 ),

  // NOTE : FOOD will be consumed by population to saturation before being available for use in industry
  // NOTE : WORK should never be produce, as it scales base on population ( for now at least )

  pub fn initByType( indType : IndType ) IndInstance
  {
    var instance : IndInstance = .{ .indType = indType, .powerSrc = .GRID };

    switch ( indType )
    {
      // NOTE : SOLAR power is halved on planet ground GROUND
      .AGRONOMIC =>
      {
        instance.powerSrc = .SOLAR;
        instance.addResConsPerInd( .WORK,  3 ) ;
        instance.addResConsPerInd( .WATER, 5  );

        instance.addResProdPerInd( .FOOD,  16 );
      },
      .HYDROPONIC =>
      {
        instance.addResConsPerInd( .WORK,  4  );
        instance.addResConsPerInd( .POWER, 3  );
        instance.addResConsPerInd( .WATER, 5  );

        instance.addResProdPerInd( .FOOD,  16 );
      },
      .WATER_PLANT =>
      {
        instance.addResConsPerInd( .WORK,  3  );

        instance.addResConsPerInd( .POWER, 4  );
        instance.addResProdPerInd( .WATER, 16 );
      },
      .SOLAR_PLANT =>
      {
        instance.powerSrc = .SOLAR;
        instance.addResConsPerInd( .WORK,  2  );

        instance.addResProdPerInd( .POWER, 32 );
      },
      .PROBE_MINE => // No resource consumption.
      {
        instance.powerSrc = .SOLAR;
        instance.addResProdPerInd( .ORE,   1  );
      },
      .GROUND_MINE =>
      {
        instance.addResConsPerInd( .WORK,  3 );
        instance.addResConsPerInd( .POWER, 3  );
        instance.addResConsPerInd( .WATER, 1  );

        instance.addResProdPerInd( .ORE,   1  );
      },
      .REFINERY =>
      {
        instance.addResConsPerInd( .WORK,  3  );
        instance.addResConsPerInd( .POWER, 3  );
        instance.addResConsPerInd( .ORE,   2  );

        instance.addResProdPerInd( .INGOT, 1  );
      },
      .FACTORY =>
      {
        instance.addResConsPerInd( .WORK,  3  );
        instance.addResConsPerInd( .POWER, 3  );
        instance.addResConsPerInd( .INGOT, 2  );

        instance.addResProdPerInd( .PART,  1  );
      },
      .ASSEMBLY => // No resource production. TODO : Increments build queue construction
      {
        instance.addResConsPerInd( .WORK,  3  );
        instance.addResConsPerInd( .POWER, 4  );
        instance.addResConsPerInd( .PART,  2  );
      },
    }

    return instance;
  }


  // ================================ CONSUMPTION ================================

  pub fn getResConsPerInd( self : *const IndInstance, resType : res.ResType ) u64
  {
    return self.resConsPerInd[ resType.toIdx() ];
  }
  pub fn setResConsPerInd( self : *IndInstance, resType : res.ResType, value : u64 ) void
  {
    self.resConsPerInd[ resType.toIdx() ] = value;
  }
  pub inline fn addResConsPerInd( self : *IndInstance, resType : res.ResType, value : u64 ) void
  {
    self.resConsPerInd[ resType.toIdx() ] += value;
  }
  pub inline fn subResConsPerInd( self : *IndInstance, resType : res.ResType, value : u64 ) void
  {
    const count = @min( value, self.resConsPerInd[ resType.toIdx() ]);

    self.resConsPerInd[ resType.toIdx() ] -= count;

    if( value != count )
    {
      def.log( .WARN, 0, @src(), "Tried to remove {d} res of type {s} from IndInstance.resConsPerInd, but only had {d} left", .{ value, @tagName( resType ), count });
    }
  }


  // ================================ PRODUCTION ================================

  pub fn getResProdPerInd( self : *const IndInstance, resType : res.ResType ) u64
  {
    return self.resProdPerInd[ resType.toIdx() ];
  }
  pub fn setResProdPerInd( self : *IndInstance, resType : res.ResType, value : u64 ) void
  {
    self.resProdPerInd[ resType.toIdx() ] = value;
  }
  pub inline fn addResProdPerInd( self : *IndInstance, resType : res.ResType, value : u64 ) void
  {
    self.resProdPerInd[ resType.toIdx() ] += value;
  }
  pub inline fn subResProdPerInd( self : *IndInstance, resType : res.ResType, value : u64 ) void
  {
    const count = @min( value, self.resProdPerInd[ resType.toIdx() ]);

    self.resProdPerInd[ resType.toIdx() ] -= count;

    if( value != count )
    {
      def.log( .WARN, 0, @src(), "Tried to remove {d} res of type {s} from IndInstance.resProbPerInd, but only had {d} left", .{ value, @tagName( resType ), count });
    }
  }
};