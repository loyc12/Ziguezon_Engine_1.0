const std = @import( "std" );
const def = @import( "defs" );


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
};

