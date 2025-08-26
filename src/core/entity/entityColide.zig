const std = @import( "std" );
const def = @import( "defs" );

const Entity = def.ntt.Entity;
const Vec2   = def.Vec2;

// ================ COLLISION FUNCTIONS ================

// This function checks if the Entity overlaps with another via AABB based on the entities's scales
pub fn isOverlapping( e1 : *const Entity, e2 : *const Entity ) bool
{
  def.log( .TRACE, e1.id, @src(), "Checking if Entity {d} overlaps with {d}", .{ e1.id, e2.id });
  return e1.hitbox.isOverlapping( &( e2.hitbox ) );
}

// This function checks if the Entity overlaps with another Entity and returns the overlap vector if they do.
// The overlap vector is the magnitude of the overlap in each axis, relative to the first Entity.
// NOTE : This function assumes that the entities are axis-aligned rectangles
// NOTE : Use isOverlapping() if you simply want to check for collision without needing the overlap vector.
pub fn getOverlap( e1 : *const Entity, e2 : *const Entity ) ?Vec2
{
  def.log( .TRACE, e1.id, @src(), "Getting overlap between Entity {d} and {d}", .{ e1.id, e2.id });

  if( e1.id == e2.id )
  {
    def.qlog( .WARN, e1.id, @src(), "Attempting to get overlap of the same entity : returning null" );
    return null;
  }
  return e1.hitbox.getOverlap( e2.hitbox );
}

pub fn collideWith( e1 : *Entity, e2 : *Entity ) bool
{
  def.log( .TRACE, e1.id, @src(), "Checking collision between Entity {d} and {d}", .{ e1.id, e2.id });

  if( !e1.isSolid() or !e2.isSolid() )
  {
    def.qlog( .DEBUG, e1.id, @src(), "One of the entities is not solid : returning" );
    return false; // No collision if either Entity is not solid
  }

  if( e1.id == e2.id ) // Check if the entities are the same
  {
    def.qlog( .DEBUG, e1.id, @src(), "Entities are the same : returning" );
    return false;
  }

  if( !isOverlapping( e1, e2 ))
  {
    def.qlog( .DEBUG, e1.id, @src(), "Entities are not overlapping : returning" );
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