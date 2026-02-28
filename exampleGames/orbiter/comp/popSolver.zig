const std = @import( "std" );
const def = @import( "defs" );

const inf = @import( "infrastructure.zig" );
const res = @import( "resource.zig" );
const ecn = @import( "economy.zig" );


const resTypeCount = res.resTypeCount;
const infTypeCount = inf.infTypeCount;

const ResType = res.ResType;
const InfType = inf.InfType;

const ResInstance = res.ResInstance;
const InfInstance = inf.InfInstance;


const POP_PER_HOUSE   : f32 = @floatFromInt( InfType.POP_PER_HOUSE );
const WORK_PER_HOUSE  : f32 = @floatFromInt( InfType.WORK_PER_HOUSE );
const FOOD_PER_HOUSE  : f32 = @floatFromInt( InfType.FOOD_PER_HOUSE );
const WATER_PER_HOUSE : f32 = @floatFromInt( InfType.WATER_PER_HOUSE );
const POWER_PER_HOUSE : f32 = @floatFromInt( InfType.POWER_PER_HOUSE );

const WORK_PER_POP    : f32 = WORK_PER_HOUSE  / POP_PER_HOUSE;
const FOOD_PER_POP    : f32 = FOOD_PER_HOUSE  / POP_PER_HOUSE;
const WATER_PER_POP   : f32 = WATER_PER_HOUSE / POP_PER_HOUSE;
const POWER_PER_POP   : f32 = POWER_PER_HOUSE / POP_PER_HOUSE;

pub inline fn getPopWorkProd(  pop : f32 ) f32 { return pop * WORK_PER_POP;  }
pub inline fn getPopFoodCons(  pop : f32 ) f32 { return pop * FOOD_PER_POP;  }
pub inline fn getPopWaterCons( pop : f32 ) f32 { return pop * WATER_PER_POP; }
pub inline fn getPopPowerCons( pop : f32 ) f32 { return pop * POWER_PER_POP; }


const WEEKLY_POP_GROWTH  : f32 = 1.010266631; // x4 each century // TODO : cahnge min growth of less than 1.0 to chance of growth
const WEEKLY_PARCH_RATE  : f32 = 0.25;
const WEEKLY_STARVE_RATE : f32 = 0.10;
const WEEKLY_FREEZE_RATE : f32 = 0.05;

const MIN_WORK_RATE      : f32 = 0.25;


pub inline fn resolvePop( econ : *ecn.Economy ) void
{
  var solver : PopSolver = .{};

  solver.updatePop( econ );
}


const PopSolver = struct
{
  prevPopCount  : f32 = 0.0,
  nextPopCount  : f32 = 0.0,
  popResAccess  : f32 = 0.0,


  fn updatePop( self : *PopSolver, econ : *ecn.Economy ) void
  {
    self.prevPopCount = @floatFromInt( econ.popCount );
    self.nextPopCount = self.prevPopCount;
    self.popResAccess = 1.0;

    const foodRequired   : f32 = getPopFoodCons(  self.prevPopCount );
    const waterRequired  : f32 = getPopWaterCons( self.prevPopCount );
    const powerRequired  : f32 = getPopPowerCons( self.prevPopCount );

    const foodAvailable  : f32 = @floatFromInt( econ.getResCount( .FOOD ));
    const waterAvailable : f32 = @floatFromInt( econ.getResCount( .WATER ));
    const powerAvailable : f32 = @floatFromInt( econ.getResCount( .POWER ));


    if( foodRequired > foodAvailable )
    {
      def.qlog( .INFO, 0, @src(), "Population is experiencing food shortages !" );

      const foodAccess     = if( foodRequired > 0 ) foodAvailable / foodRequired else 1.0;
      const popStarveCount = ( 1.0 - foodAccess ) * self.prevPopCount; // How many are left without access to Food

      self.nextPopCount  = @max( self.nextPopCount - ( popStarveCount * WEEKLY_STARVE_RATE ), 0.0 );
      self.popResAccess *= @min( foodAccess, 1.0 );
    }

    if( waterRequired > waterAvailable )
    {
      def.qlog( .INFO, 0, @src(), "Population is experiencing water shortages !" );

      const waterAccess   = if( waterRequired > 0 ) waterAvailable / waterRequired else 1.0;
      const popParchCount = ( 1.0 - waterAccess ) * self.prevPopCount; // How many are left without access to water

      self.nextPopCount  = @max( self.nextPopCount - ( popParchCount * WEEKLY_PARCH_RATE ), 0.0 );
      self.popResAccess *= @min( waterAccess, 1.0 );
    }

    if( powerRequired > powerAvailable )
    {
      def.qlog( .INFO, 0, @src(), "Population is experiencing power shortages !" );

      const powerAccess   = if( powerRequired > 0 ) powerAvailable / powerRequired else 1.0;
      const popFreezeCount = ( 1.0 - powerAccess ) * self.prevPopCount; // How many are left without access to power

      self.nextPopCount  = @max( self.nextPopCount - ( popFreezeCount * WEEKLY_FREEZE_RATE ), 0.0 );
      self.popResAccess *= @min( powerAccess, 1.0 );
    }

    if( foodRequired <= foodAvailable and waterRequired <= waterAvailable )
    {
      // Normal pop growth when no critical shortages ( being powerless is non-critical )
      self.nextPopCount *= WEEKLY_POP_GROWTH;
    }

    // Updating pop

    const popCap           : f32 = @floatFromInt( econ.getPopCap() );
    const prevPopCount_i64 : i64 = @intFromFloat( @ceil(           self.prevPopCount               ));
    const nextPopCount_i64 : i64 = @intFromFloat( @ceil( def.clmp( self.nextPopCount, 0.0, popCap )));

    econ.popCount     = @intCast( nextPopCount_i64 );
    econ.popDelta     = nextPopCount_i64 - prevPopCount_i64;
    econ.popResAccess = self.popResAccess;


    // Updating work

    const workRate = @max( self.popResAccess, MIN_WORK_RATE ); // Garantees at least a minimum of productivity
    const workId = ResType.WORK.toIdx();

    econ.resBank[ workId ] = @intFromFloat( @floor( workRate * getPopWorkProd( self.nextPopCount )));
    econ.resProd[ workId ] = @intCast( econ.resBank[ workId ] );


    // Updating non-work resource

    const foodCons  : u64 = @intFromFloat( @ceil( @min( foodRequired,  foodAvailable )));
    const waterCons : u64 = @intFromFloat( @ceil( @min( waterRequired, foodAvailable )));
    const powerCons : u64 = @intFromFloat( @ceil( @min( powerRequired, foodAvailable )));

    econ.subResCount( .FOOD,  foodCons  );
    econ.subResCount( .WATER, waterCons );
    econ.subResCount( .POWER, powerCons );

    econ.resCons[ ResType.FOOD.toIdx()  ] += @intCast( foodCons  );
    econ.resCons[ ResType.WATER.toIdx() ] += @intCast( waterCons );
    econ.resCons[ ResType.POWER.toIdx() ] += @intCast( powerCons  );
  }
};