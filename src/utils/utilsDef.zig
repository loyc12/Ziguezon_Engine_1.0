pub var G_EPOCH : TimeVal = .{};


// ================================ RAYLIB SHORTHANDS ================================

pub const ray = @import( "raylib" );

pub const Texture = ray.Texture2D;
pub const Font    = ray.Font;
pub const RayCam  = ray.Camera2D;
pub const RayRect = ray.Rectangle;
pub const RayCol  = ray.Color;

pub fn newRayCol( r : u8, g : u8, b : u8, a : ?u8 ) RayCol
{
  if( a )| alpha | { return RayCol{ .r = r, .g = g, .b = b, .a = alpha }; }
  else             { return RayCol{ .r = r, .g = g, .b = b, .a = 255   }; }
}

pub const RayVec2 = ray.Vector2;
pub const RayVec3 = ray.Vector3;
pub const RayVec4 = ray.Vector4;

pub const zeroRayVec2 = RayVec2{ .x = 0, .y = 0 };
pub const zeroRayVec3 = RayVec3{ .x = 0, .y = 0, .z = 0 };
pub const zeroRayVec4 = RayVec4{ .x = 0, .y = 0, .z = 0, .w = 0 };



// ================================ DATA STRUCTS SHORTHANDS ================================

// ======== ANGLES ========

pub const angle = @import( "data/angle.zig" );

pub const Angle = angle.Angle;


// ======== BOXES ========

pub const box2 = @import( "data/box2.zig" );

pub const Box2 = box2.Box2;

pub const isLeftOf  = box2.isLeftOf;
pub const isRightOf = box2.isRightOf;
pub const isAbove   = box2.isAbove;   // NOTE : Y axis is inverted in raylib rendering
pub const isBelow   = box2.isBelow;   // NOTE : Y axis is inverted in raylib rendering

pub const getCenterXFromLeftX      = box2.getCenterXFromLeftX;
pub const getCenterXFromRightX     = box2.getCenterXFromRightX;
pub const getCenterYFromTopY       = box2.getCenterYFromTopY;
pub const getCenterYFromBottomY    = box2.getCenterYFromBottomY;

pub const getCenterFromTopLeft     = box2.getCenterFromTopLeft;
pub const getCenterFromTopRight    = box2.getCenterFromTopRight;
pub const getCenterFromBottomLeft  = box2.getCenterFromBottomLeft;
pub const getCenterFromBottomRight = box2.getCenterFromBottomRight;


// ======== COORDS ========

pub const coords2 = @import( "data/coords2.zig" );
pub const coords3 = @import( "data/coords3.zig" );

pub const Dir2 = coords2.Dir2;
pub const Dir3 = coords3.Dir3;

pub const Coords2 = coords2.Coords2;
pub const Coords3 = coords3.Coords3;


// ======== DATA MATRICES ========

pub const data1D = @import( "data/data1D.zig" );
pub const data2D = @import( "data/data2D.zig" );
pub const data3D = @import( "data/data3D.zig" );
pub const data4D = @import( "data/data4D.zig" );

pub const GenDataLine     = data1D.GenDataLine;
pub const GenDataGrid     = data2D.GenDataGrid;
pub const GenDataCube     = data3D.GenDataCube;
pub const GenDataMatrix4  = data3D.GenDataMatrix4;


// ======== BITFLAGS ========

pub const bitField = @import( "data/fielder.zig" );

pub const Bfd4   = bitField.Bfd4;
pub const Bfd8   = bitField.Bfd8;
pub const Bfd16  = bitField.Bfd16;
pub const Bfd32  = bitField.Bfd32;
pub const Bfd64  = bitField.Bfd64;
pub const Bfd128 = bitField.Bfd128;
pub const Bfd256 = bitField.Bfd256;


// ======== TIMING ========

pub const timer = @import( "data/timer.zig" );

pub const TimeVal    = timer.TimeVal;
pub const Timer      = timer.Timer;
pub const TimerFlags = timer.TimerFlags;

pub const getNow     = timer.getNow;


// ======== TYPING ========

pub const typer = @import( "data/typer.zig" );

pub const GenPairedEnum = typer.GenPairedEnum;
pub const GenSplitEnum  = typer.GenSplitEnum;

pub const pairEnums     = typer.pairEnums;
pub const splitEnums    = typer.splitEnums;


// ======== VECTORS ========

pub const vec2 = @import( "data/vec2.zig" );
pub const vec3 = @import( "data/vec3.zig" );
pub const vecA = @import( "data/vecA.zig" );

pub const Vec2 = vec2.Vec2;
pub const Vec3 = vec3.Vec3;
pub const VecA = vecA.VecA;



// ================ I/O SHORTHANDS ================================

// ================ LOGGING ================

pub const logger = @import( "io/logger.zig" );

pub const log   = logger.log;  // for argument-formatting logging
pub const qlog  = logger.qlog; // for quick logging ( no args )

pub const resetTmpTimer = logger.resetTmpTimer;
pub const logTmpTimer   = logger.logTmpTimer;


// ================ CLI COLOURS ================

pub const termColour = @import( "io/termColourer.zig" );



// ================================ MATHS SHORTHANDS ================================

// ======== ARITHMETICS ========

pub const maths = @import( "maths/mather.zig" );

// Constants

pub const E    = maths.E;
pub const PI   = maths.PI;
pub const TAU  = maths.TAU;
pub const PHI  = maths.PHI;
pub const EPS  = maths.EPS;

pub const R2   = maths.R2;
pub const HR2  = maths.HR2;
pub const IR2  = maths.IR2;

pub const R3   = maths.R3;
pub const HR3  = maths.HR3;
pub const IR3  = maths.IR3;

// Builtins

pub const atan2   = maths.atan2;
pub const DtR     = maths.DtR;
pub const RtD     = maths.RtD;

pub const clmp    = maths.clmp;
pub const lerp    = maths.lerp;

pub const pow     = maths.pow;
pub const exp     = maths.exp;

pub const sqrt    = maths.sqrt;
pub const cbrt    = maths.cbrt;

pub const gcd     = maths.gcd;

// Custom

pub const isFltZr = maths.isFltZr;
pub const isFltEq = maths.isFltEq;

pub const sign    = maths.getSign;
pub const inv1    = maths.inv1;
pub const pow2    = maths.pow2;

pub const sigmoid = maths.sigmoid;
pub const softCap = maths.softCap;

pub const med3    = maths.med3;
pub const wrap    = maths.wrap;

pub const norm    = maths.norm;
pub const denorm  = maths.denorm;
pub const renorm  = maths.renorm;

pub const getPolyCircumRad = maths.getPolyCircumRad;
pub const getPolyArea      = maths.getPolyArea;


// ======== SHAPES ========

pub const shape2D = @import( "maths/shape2.zig" );
pub const shape3D = @import( "maths/shape3.zig" );

pub const Shape2D = shape2D.Shape2D;
pub const Shape3D = shape3D.Shape3D;



// ================================ RENDER SHORTHANDS ================================

// ======== SCREEN ========

pub const screen = @import( "render/screener.zig" );

pub const getScreenWidth      = screen.getScreenWidth;
pub const getScreenHeight     = screen.getScreenHeight;
pub const getScreenSize       = screen.getScreenSize;

pub const getHalfScreenWidth  = screen.getHalfScreenWidth;
pub const getHalfScreenHeight = screen.getHalfScreenHeight;
pub const getHalfScreenSize   = screen.getHalfScreenSize;

pub const getMouseScreenPos   = screen.getMouseScreenPos;


// ======== CAMERA ========

pub const cam2 = @import( "render/cam2.zig" );

pub const Cam2 = cam2.Cam2;


// ======== COLOURS ========

pub const colour = @import( "render/colour.zig" );

pub const Colour = colour.Colour;


// ======== DRAWERS ========

pub const drawerCore = @import( "render/drawerCore.zig" );
pub const sDraw = @import( "render/drawerScreen.zig" );


// ======== SPRITEMAPS ========

pub const spritemap = @import( "render/spritemap.zig" );

pub const Spritemap = spritemap.Spritemap;
pub const Sprite    = spritemap.Sprite;


// ================================ RNG SHORTHANDS ================================

// ======== NOISE ========

pub const noise2D = @import( "rng/noise2D.zig" );

pub const Noise2D = noise2D.Noise2D;


// ======== RANDOMNESS ========

pub const random = @import( "rng/randomiser.zig" );

pub const Randomiser = random.Randomiser;


// ======== SHAKE ========

pub const shake2D = @import( "rng/shake2D.zig" );

pub const Shake2D = shake2D.Shake2D;


// ================================ UI SHORTHANDS ================================

// ======== RETAINED UI ========

pub const uiContext = @import( "ui/uiContext.zig" );
pub const uiTypes   = @import( "ui/uiTypes.zig" );

pub const UiManager   = uiContext.UiManager;
pub const UiContext   = uiContext.UiContext;
pub const UiId        = uiContext.UiId;
pub const UiNodeKind  = uiContext.UiNodeKind;
pub const UiLayer     = uiContext.UiLayer;
pub const UiLayout    = uiContext.UiLayout;
pub const UiEvent     = uiContext.UiEvent;
pub const UiEventType = uiContext.UiEventType;
pub const UiStyle     = uiContext.UiStyle;
pub const UiNodeOpts  = uiContext.UiNodeOpts;
pub const UiInput     = uiContext.UiInput;

pub const uiBoxFromTopLeft = uiContext.boxFromTopLeft;


// ======== INTERFACER ========

pub const interface2D = @import( "ui/interface2D.zig" );

pub const InterfaceShape = interface2D.InterfaceShape;
pub const BevelArray     = interface2D.BevelArray;
pub const Interface2D    = interface2D.Interface2D;



// ================================ HELPER FUNCTIONS ================================

const std = @import( "std" );


pub const areContEqual = std.meta.eql;


// ================ (DE) INITIALISATION =================

pub inline fn initAllUtils() void
{
  logger.initFile();
}

pub inline fn deinitAllUtils() void
{
  const bytesInUse = getBytesInUse();

  switch( G_ALLOC.deinit() )
  {
    .ok   => qlog( .INFO, 0, @src(), "$ Default allocator deinitialized without leaks" ),
    .leak => log(  .WARN, 0, @src(), "@ Default allocator detected leaked memory : {d} bytes still in use", .{ bytesInUse } ),
  }

  logger.deinitFile();
}

pub var G_ALLOC : std.heap.DebugAllocator(.{ .enable_memory_limit = true }) = .init;

pub inline fn getDefaultAlloc() std.mem.Allocator { return G_ALLOC.allocator(); }
pub inline fn getBytesInUse() usize { return G_ALLOC.total_requested_bytes; }
