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


const WEEKLY_POP_GROWTH  : f32 = 1.0002113; // x3 each century
const WEEKLY_PARCH_RATE  : f32 = 0.5;
const WEEKLY_STARVE_RATE : f32 = 0.1;

const MIN_WORK_RATE      : f32 = 0.1;


const WORK_PER_HOUSE  : f32 = @floatFromInt( InfType.WORK_PER_HOUSE );
const FOOD_PER_HOUSE  : f32 = @floatFromInt( InfType.FOOD_PER_HOUSE );
const WATER_PER_HOUSE : f32 = @floatFromInt( InfType.WATER_PER_HOUSE );
const POWER_PER_HOUSE : f32 = @floatFromInt( InfType.POWER_PER_HOUSE );
const POP_PER_HOUSE   : f32 = @floatFromInt( InfType.POP_PER_HOUSE );

pub inline fn getPopWorkProd(  pop : f32 ) f32 { return pop * WORK_PER_HOUSE  / POP_PER_HOUSE; }
pub inline fn getPopFoodCons(  pop : f32 ) f32 { return pop * FOOD_PER_HOUSE  / POP_PER_HOUSE; }
pub inline fn getPopPowerCons( pop : f32 ) f32 { return pop * POWER_PER_HOUSE / POP_PER_HOUSE; }
pub inline fn getPopWaterCons( pop : f32 ) f32 { return pop * WATER_PER_HOUSE / POP_PER_HOUSE; }


pub inline fn resolvePop( econ : *ecn.Economy ) void
{
  var solver : PopSolver = .{};

  solver.updatePop( econ );
}


const PopSolver = struct
{
  maxEfficiency : f32 = 1.0, // Work production throttle / multiplier

  nextPopCount  : f32 = 0.0,
  popResAccess  : f32 = 0.0,


  fn updatePop( self : *PopSolver, econ : *ecn.Economy ) void
  {
    self.nextPopCount = @floatFromInt( econ.popCount );
    self.popResAccess = 1.0;


    const waterPerPop    : f32 = WATER_PER_HOUSE / POP_PER_HOUSE;
    const foodPerPop     : f32 = FOOD_PER_HOUSE  / POP_PER_HOUSE;

    const waterRequired  : f32 = self.nextPopCount * waterPerPop;
    const foodRequired   : f32 = self.nextPopCount * foodPerPop;

    const waterAvailable : f32 = @floatFromInt( econ.getResCount( .WATER ));
    const foodAvailable  : f32 = @floatFromInt( econ.getResCount( .FOOD ));

    const popCap         : f32 = @floatFromInt( econ.getPopCap() );

    if( waterRequired > waterAvailable ) // Water shortage
    {
      def.qlog( .INFO, 0, @src(), "Population is parching !" );

      econ.setResCount( .WATER, 0 );

      const waterAccess  = waterAvailable / waterRequired;
      const waterDeficit = waterRequired  - waterAvailable;
      const popParch     = waterDeficit   * waterPerPop; // How many are left without access to water

      self.nextPopCount  = @min( self.nextPopCount - ( popParch * WEEKLY_PARCH_RATE ), 0.0 );
      self.popResAccess *= @min( waterAccess, 1.0 );
    }

    if( foodRequired > foodAvailable ) // Food shortage
    {
      def.qlog( .INFO, 0, @src(), "Population is starving !" );

      econ.setResCount( .FOOD, 0 );

      const foodAccess  = foodAvailable / foodRequired;
      const foodDeficit = foodRequired  - foodAvailable;
      const popStarve   = foodDeficit   * foodPerPop; // How many are left without access to food

      self.nextPopCount  = @min( self.nextPopCount - ( popStarve * WEEKLY_PARCH_RATE ), 0.0 );
      self.popResAccess *= @min( foodAccess, 1.0 );
    }

    const waterCons : u64 = @intFromFloat( @ceil( waterRequired ));
    const foodCons  : u64 = @intFromFloat( @ceil( foodRequired  ));

    if( waterRequired <= waterAvailable and foodRequired <= foodAvailable ) // No shortage ( normal growth )
    {
      econ.subResCount( .WATER, waterCons );
      econ.subResCount( .FOOD,  foodCons  );

      if( self.nextPopCount < popCap ){ self.nextPopCount *= WEEKLY_POP_GROWTH; }
    }

    econ.resDelta[ ResType.WATER.toIdx() ] -= @intCast( waterCons );
    econ.resDelta[ ResType.FOOD.toIdx()  ] -= @intCast( foodCons  );

    self.nextPopCount = def.clmp( self.nextPopCount, 0.0, popCap );

    const lastCount : i64 = @intCast( econ.popCount );
    const nextCount : i64 = @intFromFloat( @ceil( self.nextPopCount ));

    econ.popCount     = @intCast( nextCount );
    econ.popResAccess = self.popResAccess;
    econ.popDelta    += @intCast( nextCount - lastCount );


    const workRate = @max( self.popResAccess, MIN_WORK_RATE ); // Garantees at least a minimum of productivity
    const workId = ResType.WORK.toIdx();

    econ.resBank[  workId ] = @intFromFloat( @floor( workRate * getPopWorkProd( self.nextPopCount )));
    econ.resDelta[ workId ] = @intCast( econ.resBank[ workId ] );
  }

};