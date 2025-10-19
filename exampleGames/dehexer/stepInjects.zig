const std      = @import( "std" );
const def      = @import( "defs" );
const stateInj = @import( "stateInjects.zig" );

const Engine = def.Engine;
const Entity = def.Entity;

const Angle  = def.Angle;
const Vec2   = def.Vec2;
const VecA   = def.VecA;
const Box2   = def.Box2;

// ================================ GLOBAL GAME VARIABLES ================================




// ================================ STEP INJECTION FUNCTIONS ================================

pub fn OnLoopStart( ng : *def.Engine ) void
{
  ng.changeState( .PLAYING ); // force the game to unpause on start
}


pub fn OnUpdateInputs( ng : *def.Engine ) void
{
  var mazeMap = ng.getTilemap( stateInj.MAZE_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Tilemap with ID {d} ( Maze ) not found", .{ stateInj.MAZE_ID });
    return;
  };

  // If left clicked, check if a tile was clicked on the example tilemap
  if( def.ray.isMouseButtonPressed( def.ray.MouseButton.left ))
  {
    const mouseScreemPos = def.ray.getMousePosition();
    const mouseWorldPos  = def.ray.getScreenToWorld2D( mouseScreemPos, ng.getCameraCpy().?.toRayCam() );

    const worldCoords = mazeMap.findHitTileCoords( Vec2{ .x = mouseWorldPos.x, .y = mouseWorldPos.y });

    if( worldCoords != null )
    {
      def.log( .INFO, 0, @src(), "Clicked on tile at {d}:{d}", .{ worldCoords.?.x, worldCoords.?.y });

      var clickedTile = mazeMap.getTile( worldCoords.? ) orelse
      {
        def.log( .WARN, 0, @src(), "No tile found at {d}:{d} in tilemap {d}", .{ worldCoords.?.x, worldCoords.?.y, mazeMap.id });
        return;
      };

      // Change the color of the clicked tile
      clickedTile.colour = def.G_RNG.getColour();

      // Change the color of all neighbouring tiles to their direction color
      const dirArray = [_]def.e_dir_2{ .NO, .NE, .EA, .SE, .SO, .SW, .WE, .NW };
      for( dirArray )| dir |
      {

        const n_coords = mazeMap.getNeighbourCoords( clickedTile.gridCoords, dir ) orelse
        {
          def.log( .TRACE, 0, @src(), "No northern neighbour in direcetion {s} found for tile at {d}:{d} in tilemap {d}",
                  .{ @tagName( dir ), clickedTile.gridCoords.x, clickedTile.gridCoords.y, mazeMap.id });
          continue;
        };

        var n_tile = mazeMap.getTile( n_coords ) orelse
        {
          def.log( .WARN, 0, @src(), "No tile found at {d}:{d} in tilemap {d}", .{ n_coords.x, n_coords.y, mazeMap.id });
          continue;
        };

        n_tile.colour = dir.getDebugColour();
      }
    }
  }
}


pub fn OnTickWorld( ng : *def.Engine ) void
{
  const mazeMap = ng.getTilemap( stateInj.MAZE_ID ) orelse
  {
    def.log( .WARN, 0, @src(), "Tilemap with ID {d} ( Example Tilemap ) not found", .{ stateInj.MAZE_ID });
    return;
  };

  _ = mazeMap; // Prevent unused variable warning
}


pub fn OnRenderWorld( ng : *def.Engine ) void
{
  // NOTE : All active entities are rendered after the function is called, so no need to render them here.

  _ = ng; // Prevent unused variable warning
}

pub fn OffRenderWorld( ng : *def.Engine ) void
{
  _ = ng; // Prevent unused variable warning
}

// NOTE : This is where you should render all screen-position relative effects ( UI, HUD, etc. )
pub fn OnRenderOverlay( ng : *def.Engine ) void
{
  _ = ng; // Prevent unused variable warning
}