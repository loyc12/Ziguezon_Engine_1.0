const std = @import( "std" );
const eng = @import( "engine" );
const utl = @import( "utils" );

const gbl = @import( "../gameGlobals.zig" );
const gdf = @import( "../gameDef.zig" );


pub var solShine : StarShine = .{};

pub const StarShine = struct
{
  shineStrenght : f64 = 0.0,

  pub inline fn setShineAt( self : *StarShine, shine : f64, dist : f64 ) void
  {
    const d2 = dist * dist;

    self.shineStrenght = shine * d2;
  }

  pub fn getShineAt( self : StarShine, distSquare : f64 ) f64
  {
    return self.shineStrenght / distSquare;
  }

  /// Requires STLR_DATA to be set
  pub inline fn initFromData( self : *StarShine) bool
  {
    const data = gbl.STLR_DATA;

    if( !data.isInit )
    {
      utl.qlog( .ERROR, 0, @src(), "Tried to init sunshine from uninitialized stellar data" );
      return false;
    }

    const terraMin = data.get( .TERRA, .PERIAP );
    const terraMax = data.get( .TERRA, .APOAP  );

    self.setShineAt( 1.0, @sqrt( terraMin * terraMax ));

    return true;
  }
};