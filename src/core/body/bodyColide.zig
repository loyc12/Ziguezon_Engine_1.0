const std = @import( "std" );
const def = @import( "defs" );

const Body = def.ntt.Body;
const Vec2   = def.Vec2;

// ================ COLLISION FUNCTIONS ================

// This function checks if the Body overlaps with another via AABB based on the bodies's scales
pub fn isOverlapping( e1 : *const Body, e2 : *const Body ) bool
{
  def.log( .TRACE, e1.id, @src(), "Checking if Body {d} overlaps with {d}", .{ e1.id, e2.id });
  return e1.hitbox.isOverlapping( &( e2.hitbox ) );
}

// This function checks if the Body overlaps with another Body and returns the overlap vector if they do.
// The overlap vector is the magnitude of the overlap in each axis, relative to the first Body.
// NOTE : This function assumes that the bodies are axis-aligned rectangles
// NOTE : Use isOverlapping() if you simply want to check for collision without needing the overlap vector.
pub fn getOverlap( e1 : *const Body, e2 : *const Body ) ?Vec2
{
  def.log( .TRACE, e1.id, @src(), "Getting overlap between Body {d} and {d}", .{ e1.id, e2.id });

  if( e1.id == e2.id )
  {
    def.qlog( .WARN, e1.id, @src(), "Attempting to get overlap of the same body : returning null" );
    return null;
  }
  return e1.hitbox.getOverlap( e2.hitbox );
}

pub fn collideWith( e1 : *Body, e2 : *Body ) bool
{
  def.log( .TRACE, e1.id, @src(), "Checking collision between Body {d} and {d}", .{ e1.id, e2.id });

  if( !e1.isSolid() or !e2.isSolid() )
  {
    def.qlog( .DEBUG, e1.id, @src(), "One of the bodies is not solid : returning" );
    return false; // No collision if either Body is not solid
  }

  if( e1.id == e2.id ) // Check if the bodies are the same
  {
    def.qlog( .DEBUG, e1.id, @src(), "Bodies are the same : returning" );
    return false;
  }

  if( !isOverlapping( e1, e2 ))
  {
    def.qlog( .DEBUG, e1.id, @src(), "Bodies are not overlapping : returning" );
    return false;
  }

  const overlap = getOverlap( e1, e2 );
  if( overlap == null )
  {
    def.qlog( .DEBUG, e1.id, @src(), "No overlap detected : returning" );
    return false;
  }

  if( e1.isMobile() and e2.isMobile() )
  {
    e1.pos.x += overlap.x / 2.0;
    e1.pos.y += overlap.y / 2.0;
  }
  else if( e1.isMobile() )
  {
    e1.pos.x += overlap.x;
    e1.pos.y += overlap.y;
  }
  else if( e2.isMobile() )
  {
    e2.pos.x -= overlap.x;
    e2.pos.y -= overlap.y;
  }

  def.qlog( .TRACE, e1.id, @src(), "Collision detected and resolved : returning" );
  return true;
}