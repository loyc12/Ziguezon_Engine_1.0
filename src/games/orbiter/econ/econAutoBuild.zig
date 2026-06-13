
const std = @import( "std" );
const utl = @import( "utils" );


//pub const ecnSlvr = @import( "econSolver.zig"  );
//pub const ecnBldr = @import( "econBuilder.zig" );
//pub const ecnEco  = @import( "ecology.zig"     );

//pub const BuildQueue = ecnBldr.BuildQueue;
//pub const Ecology    = ecnEco.EcoState;


const gbl = @import( "../gameGlobals.zig" );
const gdf = @import( "../gameDef.zig" );

const EconLoc = gdf.EconLoc;
const Economy = gdf.ecn.Economy;

const PowerSrc  = gdf.PowerSrc;
const VesType   = gdf.VesType;
const ResType   = gdf.ResType;
const PopType   = gdf.PopType;
const InfType   = gdf.InfType;
const IndType   = gdf.IndType;

const powerSrcC = PowerSrc.count;
const vesTypeC  = VesType.count;
const resTypeC  = ResType.count;
const popTypeC  = PopType.count;
const infTypeC  = InfType.count;
const indTypeC  = IndType.count;

// NOTE : Move these to per-construct values whenever possible

const AUTO_DECAY_RES_FACTOR   : f64 =    0.75; // Fraction of build PART costs reimbursed on decay
const AUTO_BUILD_MAX_SCALE    : f64 =    2.00; // Max build scale multiplier ( 0.0 at thresh, this at 100%+ )
const AUTO_BUILD_QUEUE_LIMIT  : u32 =      96; // Max number of queued construction orders before ignoring autoBuild


const AUTO_BUILD_INF_THRESH   : f64 = 0.80000; // Infrastructure usage level above which it grows
const AUTO_BUILD_INF_FACTOR   : f64 = 0.00005; // Fraction of pop count to build per tick at full scale (inf)
const AUTO_BUILD_ASSEMBLY_F   : f64 = 0.01000; // Max ASSEMBLY count as a fraction of population count

const AUTO_DECAY_INF_THRESH   : f64 = 0.25000; // Infrastructure use rate below which it decays
const AUTO_DECAY_INF_FACTOR   : f64 = 0.00002; // Fraction of pop count to decay per tick at full scale (ind)
const AUTO_DECAY_ASSEMBLY_F   : f64 = 0.00025; // Min ASSEMBLY count as a fraction of population count


const AUTO_BUILD_LABOUR_THRESH  : f64 = 0.90000; // Min LABOUR supply/demand ratio required before expanding industry
const AUTO_BUILD_IND_THRESH   : f64 = 0.80000; // Industry activity target above which it grows
const AUTO_BUILD_IND_FACTOR   : f64 = 0.00002; // Fraction of pop count to build per tick at full scale (ind)
const AUTO_BUILD_ACCESS_LIMIT : f64 =    32.0; // Stored/demand ratio above which build amounts are dampened

const AUTO_DECAY_IND_THRESH   : f64 = 0.60000; // Industry activity target below which it decays
const AUTO_DECAY_IND_FACTOR   : f64 = 0.00001; // Fraction of pop count to decay per tick at full scale (ind)

pub fn debugAutoBuild( self : *Economy ) void
{
  const popC : f64 = @floatFromInt( self.getTotalPopCount() );

  if( self.buildQueue.?.maxEntryCount < AUTO_BUILD_QUEUE_LIMIT )
  {
    utl.qlog( .INFO, @src(), "Logging autoBuilds : ");

    // ======== INFRASTRUCTURE ========

    for( 0..infTypeC )| f |
    {
      const infT   = InfType.fromIdx( f );
      const useLvl = self.infState.get( .USE_LVL, infT );


      if( useLvl > AUTO_BUILD_INF_THRESH )
      {
        // Scale build amount : at THRESH build 0, at 1.0+ build full amount
        var scale : f64 = 1.0;
            scale *= ( useLvl - AUTO_BUILD_INF_THRESH ) / ( 1.0 - AUTO_BUILD_INF_THRESH );
            scale  = @min( AUTO_BUILD_MAX_SCALE, scale );

        var amount : f64 = scale * popC * AUTO_BUILD_INF_FACTOR;

        // Clamp ASSEMBLY to a fraction of population to prevent self-reinforcing build spiral
        if( infT == .ASSEMBLY )
        {
          const count : f64 = self.infState.get( .COUNT, .ASSEMBLY );
          const cap   : f64 = popC * AUTO_BUILD_ASSEMBLY_F;

          amount = @min( amount, @max( 0.0, cap - count ));
        }

        amount = @ceil( amount );

        // Building requested amount, if any
        if( amount > utl.EPS )
        {
          _ = self.buildQueue.?.tryAddEntry( .{ .infT = infT }, .{ .infT = infT }, .CNSTR, .RAISE_TO, @intFromFloat( amount ));

          const avail  = self.infState.get( .SAVINGS, infT );

          if( avail < utl.EPS )
          {
            utl.log( .INFO, @src(), "@ {s} cannot fund construction : no savings available", .{ @tagName( infT )});

            _ = self.buildQueue.?.tryFundEntry( self, .{ .infT = infT }, .{ .infT = infT }, .CNSTR, 1_000_000_000.0 ); // TODO : remove this hacky fix
          }
          else
          {
            const remain = self.buildQueue.?.tryFundEntry( self, .{ .infT = infT }, .{ .infT = infT }, .CNSTR, avail );
            const delta  = avail - remain;

            if( delta > utl.EPS )
            {
              self.infState.set( .SAVINGS, infT, remain );
              self.infState.add( .EXPENSE, infT, delta  );
            }
          }
        }
      }
      else if( useLvl < AUTO_DECAY_INF_THRESH )
      {
        // Scale decay amount : at THRESH decay 0, at 0.0 decay full amount
        var scale : f64 = 1.0;
            scale *= ( AUTO_DECAY_INF_THRESH - useLvl ) / AUTO_DECAY_INF_THRESH;
            scale  = @max( 0.0, scale );

        var amount : f64 = scale * popC * AUTO_DECAY_INF_FACTOR;


        // Clamp ASSEMBLY to a fraction of population to prevent complete selloff
        if( infT == .ASSEMBLY )
        {
          const count : f64 = self.infState.get( .COUNT, .ASSEMBLY );
          const cap   : f64 = popC * AUTO_BUILD_ASSEMBLY_F * 0.01;

          amount  = @min( amount, @max( 0.0, count - cap ));
          amount *= 0.2; // Slows ASSEMBLY decay even further
        }

        amount = @floor( @min( amount, self.infState.get( .COUNT, infT )));

        // Removing requested amount, if any
        if( amount > utl.EPS )
        {
          _ = self.buildQueue.?.tryAddEntry( .{ .infT = infT }, .{ .infT = infT }, .RECYC, .RAISE_TO, @intFromFloat( amount ));
        }
      }
    }


    // ======== INDUSTRY ========

    const labourAcs = self.resState.get( .ACCESS, .LABOUR );

    for( 0..indTypeC )| d |
    {
      const indT = IndType.fromIdx( d );

      if( indT.canBeBuiltIn( self.location, self.hasAtmo ))
      {
        const actTrgt : f64 = self.indState.get( .ACT_TRGT, indT );

        // Don't expand industry if we can't staff what we already have
        const needLabour : bool = ( indT.getResMetric_f64( .CONS, .LABOUR ) > utl.EPS );
        const canBuild : bool = ( !needLabour or labourAcs > AUTO_BUILD_LABOUR_THRESH );

        if( canBuild and actTrgt > AUTO_BUILD_IND_THRESH )
        {
          // Scale build amount : at THRESH build 0, at 1.0+ build full amount
          var scale : f64 = 1.0;
              scale *= ( actTrgt - AUTO_BUILD_IND_THRESH  ) / ( 1.0 - AUTO_BUILD_IND_THRESH  );
              scale *= ( labourAcs - AUTO_BUILD_LABOUR_THRESH ) / ( 1.0 - AUTO_BUILD_LABOUR_THRESH );
              scale  = @min( AUTO_BUILD_MAX_SCALE, scale  );

          var amount : f64 = scale * popC * AUTO_BUILD_IND_FACTOR;

          // Dampen build amounts if any output resource is oversupplied
          inline for( 0..resTypeC )| r |
          {
            const resT = ResType.fromIdx( r );
            const prod = indT.getResMetric_f64( .PROD, resT );

            if( prod > utl.EPS )
            {
              const access = self.resState.get( .ACCESS, resT );

              if( access > AUTO_BUILD_ACCESS_LIMIT )
              {
                //const access_modifier = 1.0 / @max( utl.EPS, access );
                //amount *= access_modifier;

                amount = 0;
              }
            }
          }

          amount = @ceil( amount );

          // Building requested amount, if any
          if( amount > utl.EPS )
          {
            _ = self.buildQueue.?.tryAddEntry( .{ .indT = indT }, .{ .indT = indT }, .CNSTR, .RAISE_TO, @intFromFloat( amount ));

            const avail  = self.indState.get( .SAVINGS, indT );

            if( avail < utl.EPS )
            {
              utl.log( .INFO, @src(), "@ {s} cannot fund construction : no savings available", .{ @tagName( indT )});
            }
            else
            {
              const remain = self.buildQueue.?.tryFundEntry( self, .{ .indT = indT }, .{ .indT = indT }, .CNSTR, avail );
              const delta  = avail - remain;

              if( delta > utl.EPS )
              {
                self.indState.set( .SAVINGS, indT, remain );
                self.indState.add( .EXPENSE, indT, delta  );
              }
            }
          }
        }
        else if( actTrgt < AUTO_DECAY_IND_THRESH )
        {
          // Scale decay amount : at THRESH decay 0, at 0.0 decay full amount
          var scale : f64 = 1.0;
              scale *= ( AUTO_DECAY_IND_THRESH - actTrgt ) / AUTO_DECAY_IND_THRESH;
              scale  = @max( 0, scale );

          var amount : f64 = scale * popC * AUTO_DECAY_IND_FACTOR;
              amount = @ceil( amount );

          amount = @floor( @min( amount, self.indState.get( .COUNT, indT )));

          // Removing requested amount, if any
          if( amount > utl.EPS )
          {
            _ = self.buildQueue.?.tryAddEntry( .{ .indT = indT }, .{ .indT = indT }, .RECYC, .RAISE_TO, @intFromFloat( amount ));
          }
        }
      }
    }
  }

  // ======== VESSELS ========

  // NOTE : TBA
}

