const std = @import( "std" );
const utl = @import( "utils" );
const pcs = @import( "pieces.zig" );

const PieceKind = pcs.PieceKind;

/// Number of each piece kind placed in one shuffled spawn bag.
pub var PIECE_BAG_REPEATS : usize = 1;

const MAX_BAG_REPEATS : usize = 8;

/// A fixed-size shuffled piece queue. One default bag contains every piece once.
pub const PieceBag = struct
{
  pieces : [ PieceKind.count * MAX_BAG_REPEATS ]PieceKind = undefined,
  count  : usize = 0,
  next   : usize = 0,

  pub fn reset( self : *PieceBag ) void
  {
    self.count = 0;
    self.next  = 0;
  }

  /// Draws the next piece, refilling and shuffling once the current bag empties.
  pub fn draw( self : *PieceBag, rng : *utl.Randomiser ) PieceKind
  {
    self.ensureNext( rng );

    const piece = self.pieces[ self.next ];
    self.next += 1;
    self.ensureNext( rng );
    return piece;
  }

  /// Inspects the next item without changing its queue position.
  pub fn peek( self : *const PieceBag ) PieceKind
  {
    return self.pieces[ self.next ];
  }

  fn ensureNext( self : *PieceBag, rng : *utl.Randomiser ) void
  {
    if( self.next >= self.count ){ self.refill( rng ); }
  }

  fn refill( self : *PieceBag, rng : *utl.Randomiser ) void
  {
    const repeats = @min( @max( PIECE_BAG_REPEATS, 1 ), MAX_BAG_REPEATS );
    self.count = 0;
    self.next  = 0;

    for( 0 .. repeats )| _ |
    {
      for( 0 .. PieceKind.count )| index |
      {
        self.pieces[ self.count ] = PieceKind.fromIndex( @intCast( index ) );
        self.count += 1;
      }
    }

    var index = self.count - 1;
    while( index > 0 ) : ( index -= 1 )
    {
      const swapIndex : usize = @intCast( rng.getClampedInt( 0, @intCast( index )));
      const tmp = self.pieces[ index ];
      self.pieces[ index ] = self.pieces[ swapIndex ];
      self.pieces[ swapIndex ] = tmp;
    }
  }
};

test "one bag contains each piece kind once"
{
  const oldRepeats = PIECE_BAG_REPEATS;
  defer PIECE_BAG_REPEATS = oldRepeats;
  PIECE_BAG_REPEATS = 1;

  var rng : utl.Randomiser = .{};
  rng.seedInit( 123 );

  var bag : PieceBag = .{};
  var seen : [ PieceKind.count ]bool = [_]bool{ false } ** PieceKind.count;

  for( 0 .. PieceKind.count )| _ |
  {
    const piece = bag.draw( &rng );
    const index : usize = @intCast( piece.getIndex() );
    try std.testing.expect( !seen[ index ] );
    seen[ index ] = true;
  }
}
