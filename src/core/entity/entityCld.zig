const std = @import( "std" );
const def = @import( "defs" );

const Entity = def.ntt.Entity;
const Vec2   = def.Vec2;

// ================ DISTANCE FUNCTIONS ================
// These functions calculate the distance between two entities in various ways.

pub fn getXDistTo(    e1 : *const Entity, e2 : *const Entity ) f32 { return def.getVecRDistX(    e1.pos, e2.pos ); }
pub fn getYDistTo(    e1 : *const Entity, e2 : *const Entity ) f32 { return def.getVecRDistY(    e1.pos, e2.pos ); }
pub fn getSqrDistTo(  e1 : *const Entity, e2 : *const Entity ) f32 { return def.getVecRSqrDist(  e1.pos, e2.pos ); }
pub fn getDistTo(     e1 : *const Entity, e2 : *const Entity ) f32 { return def.getVecRDist(     e1.pos, e2.pos ); }
pub fn getCartDistTo( e1 : *const Entity, e2 : *const Entity ) f32 { return def.getVecRCartDist( e1.pos, e2.pos ); }

// ================ COLLISION FUNCTIONS ================

// This function checks if the Entity overlaps with another via AABB based on the entities's scales
pub fn isOverlapping( e1 : *const Entity, e2 : *const Entity ) bool
{
  def.log( .TRACE, e1.id, @src(), "Checking if Entity {d} overlaps with {d}", .{ e1.id, e2.id });

  const linearDists = Vec2{ .x = @abs( e2.pos.x - e1.pos.x ), .y = @abs( e2.pos.y - e1.pos.y )};
  const sumOfScales = Vec2{ .x = e1.scale.x + e2.scale.x, .y = e1.scale.y + e2.scale.y };

  if( linearDists.x > sumOfScales.x or linearDists.y > sumOfScales.y )
  {
    return false; // No overlap in at least one axis
  }

  def.qlog( .TRACE, e1.id, @src(), "Entities are overlapping : returning" );
  return true; // Overlap detected in both axes
}

// This function checks if the Entity overlaps with another Entity and returns the overlap vector if they do.
// The overlap vector is the magnitude of the overlap in each axis, relative to the first Entity.
// NOTE : This function assumes that the entities are axis-aligned rectangles
// NOTE : Use isOverlapping() if you simply want to check for collision without needing the overlap vector.
pub fn getOverlap( e1 : *const Entity, e2 : *const Entity ) ?Vec2
{
  def.log( .TRACE, e1.id, @src(), "Checking overlap between Entity {d} and {d}", .{ e1.id, e2.id });

  if( e1.id == e2.id )
  {
    def.qlog( .DEBUG, e1.id, @src(), "Entities are the same : returning" );
    return null;
  }
  if( e1.pos.x == e2.pos.x and e1.pos.y == e2.pos.y ) // No overlap direction possible
  {
    def.qlog( .TRACE, e1.id, @src(), "Entities are at the same position : returning" );
    return def.zeroVec2();
  }
  if( !isOverlapping( e1, e2 ))
  {
    def.qlog( .DEBUG, e1.id, @src(), "Entities are not overlapping : returning" );
    return null;
  }

  // Find the directions of the overlap ( relative to e1 )
  const offset = Vec2{ .x = e2.pos.x - e1.pos.x, .y = e2.pos.y - e1.pos.y };
  const dir    = Vec2{ .x = if( offset.x > 0 ) 1 else if( offset.x < 0 ) -1 else 0,
                       .y = if( offset.y > 0 ) 1 else if( offset.y < 0 ) -1 else 0 };

  // Find the edges of each entities bounding box
  // NOTE : This assumes that the entities are axis-aligned rectangles
  // TODO : Add support for e2 shapes
  const selfEdge  = Vec2{
    .x = e1.pos.x + ( dir.x * e1.scale.x ),
    .y = e1.pos.y + ( dir.y * e1.scale.y )};

  const otherEdge = Vec2{
    .x = e2.pos.x - ( dir.x * e2.scale.x ),
    .y = e2.pos.y - ( dir.y * e2.scale.y )};

  // Check for lack of overlap in either axis, based on respective directions
  if( dir.x > 0 and selfEdge.x < otherEdge.x or
      dir.x < 0 and selfEdge.x > otherEdge.x )
  {
    def.qlog( .DEBUG, e1.id, @src(), "No overlap detected in X direction : returning" );
    return null;
  }
  if( dir.y > 0 and selfEdge.y < otherEdge.y or
      dir.y < 0 and selfEdge.y > otherEdge.y )
  {
    def.qlog( .DEBUG, e1.id, @src(), "No overlap detected in Y direction : returning" );
    return null;
  }

  // If we reach here, there is an overlap in both axes
  // Find the overlap vector ( the magniture of the overlap in each axis )
  const overlap = Vec2{
    .x = if(       dir.x > 0 ) selfEdge.x  - otherEdge.x
          else if( dir.x < 0 ) otherEdge.x - selfEdge.x
          else 0,
    .y = if(       dir.y > 0 ) selfEdge.y  - otherEdge.y
          else if( dir.y < 0 ) otherEdge.y - selfEdge.y
          else 0, };

  def.log( .DEBUG, e1.id, @src(), "Overlap of magniture {d}:{d} detected", .{ overlap.x, overlap.y });
  return overlap;
}

pub fn collideWith( e1 : *Entity, e2 : *Entity ) bool
{
  if( !e1.isSolid() or !e2.isSolid() )
  {
    def.qlog( .DEBUG, e1.id, @src(), "One of the entities is not solid : returning" );
    return false; // No collision if either Entity is not solid
  }

  def.log( .TRACE, e1.id, @src(), "Checking collision between Entity {d} and {d}", .{ e1.id, e2.id });

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