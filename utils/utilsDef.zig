const std = @import( "std"    );


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

pub const ngl_u = @import( "data/angler.zig" );

pub const Angle = ngl_u.Angle;


// ======== BOXES ========

pub const box2_u = @import( "data/boxer2.zig" );

pub const Box2 = box2_u.Box2;

pub const isLeftOf  = box2_u.isLeftOf;
pub const isRightOf = box2_u.isRightOf;
pub const isAbove   = box2_u.isAbove;   // NOTE : Y axis is inverted in raylib rendering
pub const isBelow   = box2_u.isBelow;   // NOTE : Y axis is inverted in raylib rendering

pub const getCenterXFromLeftX      = box2_u.getCenterXFromLeftX;
pub const getCenterXFromRightX     = box2_u.getCenterXFromRightX;
pub const getCenterYFromTopY       = box2_u.getCenterYFromTopY;
pub const getCenterYFromBottomY    = box2_u.getCenterYFromBottomY;

pub const getCenterFromTopLeft     = box2_u.getCenterFromTopLeft;
pub const getCenterFromTopRight    = box2_u.getCenterFromTopRight;
pub const getCenterFromBottomLeft  = box2_u.getCenterFromBottomLeft;
pub const getCenterFromBottomRight = box2_u.getCenterFromBottomRight;


// ======== COORDS ========

pub const cor2_u  = @import( "data/coorder2.zig" );
pub const cor3_u  = @import( "data/coorder3.zig" );

pub const e_dir_2 = cor2_u.e_dir_2;
pub const e_dir_3 = cor3_u.e_dir_3;

pub const Coords2 = cor2_u.Coords2;
pub const Coords3 = cor3_u.Coords3;


// ======== DATA MATRICES ========

pub const d1d_u  = @import( "data/data1D.zig" );
pub const d2d_u  = @import( "data/data2D.zig" );
pub const d3d_u  = @import( "data/data3D.zig" );
pub const d4d_u  = @import( "data/data4D.zig" );

pub const GenDataLine     = d1d_u.GenDataLine;
pub const GenDataGrid     = d2d_u.GenDataGrid;
pub const GenDataCube     = d3d_u.GenDataCube;
pub const GenDataMatrix4  = d3d_u.GenDataMatrix4;


// ======== BITFLAGS ========

pub const flg_u = @import( "data/flagger.zig" );

pub const BitField8  = flg_u.BitField8;
pub const BitField16 = flg_u.BitField16;
pub const BitField32 = flg_u.BitField32;
pub const BitField64 = flg_u.BitField64;


// ======== TIMING ========

pub const tmr_u = @import( "data/timer.zig" );

pub const TimeVal       = tmr_u.TimeVal;
pub const Timer         = tmr_u.Timer;
pub const e_timer_flags = tmr_u.e_timer_flags;

pub const getNow        = tmr_u.getNow;


// ======== TYPING ========

pub const tpr_u = @import( "data/typer.zig" );

pub const GenPairedEnum = tpr_u.GenPairedEnum;
pub const GenSplitEnum  = tpr_u.GenSplitEnum;

pub const pairEnums     = tpr_u.pairEnums;
pub const splitEnums    = tpr_u.splitEnums;


// ======== VECTORS ========

pub const vec2_u = @import( "data/vecter2.zig" );
pub const vec3_u = @import( "data/vecter3.zig" );
pub const vecA_u = @import( "data/vecterA.zig" );

pub const Vec2 = vec2_u.Vec2;
pub const Vec3 = vec3_u.Vec3;
pub const VecA = vecA_u.VecA;



// ================ I/O SHORTHANDS ================================

// ================ LOGGING ================

pub const log_u = @import( "io/logger.zig" );

pub const log   = log_u.log;  // for argument-formatting logging
pub const qlog  = log_u.qlog; // for quick logging ( no args )

pub const resetTmpTimer = log_u.resetTmpTimer;
pub const logTmpTimer   = log_u.logTmpTimer;


// ================ CLI COLOURS ================

pub const tcl_u  = @import( "io/termColourer.zig" );



// ================================ MATHS SHORTHANDS ================================

// ======== ARITHMETICS ========

pub const mth_u = @import( "maths/mather.zig" );

// Constants

pub const E    = mth_u.E;
pub const PI   = mth_u.PI;
pub const TAU  = mth_u.TAU;
pub const PHI  = mth_u.PHI;
pub const EPS  = mth_u.EPS;

pub const R2   = mth_u.R2;
pub const HR2  = mth_u.HR2;
pub const IR2  = mth_u.IR2;

pub const R3   = mth_u.R3;
pub const HR3  = mth_u.HR3;
pub const IR3  = mth_u.IR3;

// Builtins

pub const atan2   = mth_u.atan2;
pub const DtR     = mth_u.DtR;
pub const RtD     = mth_u.RtD;

pub const clmp    = mth_u.clmp;
pub const lerp    = mth_u.lerp;

pub const pow     = mth_u.pow;
pub const exp     = mth_u.exp;

pub const sqrt    = mth_u.sqrt;
pub const cbrt    = mth_u.cbrt;

pub const gcd     = mth_u.gcd;

// Custom

pub const isFltZr = mth_u.isFltZr;
pub const isFltEq = mth_u.isFltEq;

pub const sign    = mth_u.getSign;
pub const inv1    = mth_u.inv1;
pub const pow2    = mth_u.pow2;

pub const sigmoid = mth_u.sigmoid;
pub const softCap = mth_u.softCap;

pub const med3    = mth_u.med3;
pub const wrap    = mth_u.wrap;

pub const norm    = mth_u.norm;
pub const denorm  = mth_u.denorm;
pub const renorm  = mth_u.renorm;

pub const getPolyCircumRad = mth_u.getPolyCircumRad;
pub const getPolyArea      = mth_u.getPolyArea;


// ======== SHAPES ========

pub const shp2_u = @import( "maths/shape2.zig" );
pub const shp3_u = @import( "maths/shape3.zig" );

pub const Shape2D = shp2_u.Shape2D;
pub const Shape3D = shp3_u.Shape3D;



// ================================ RENDER SHORTHANDS ================================

// ======== CAMERA ========

pub const cmr_u = @import( "render/camer.zig" );

pub const Cam2D = cmr_u.Cam2D;

pub const getScreenWidth      = cmr_u.getScreenWidth;
pub const getScreenHeight     = cmr_u.getScreenHeight;
pub const getScreenSize       = cmr_u.getScreenSize;

pub const getHalfScreenWidth  = cmr_u.getHalfScreenWidth;
pub const getHalfScreenHeight = cmr_u.getHalfScreenHeight;
pub const getHalfScreenSize   = cmr_u.getHalfScreenSize;

pub const getMouseScreenPos   = cmr_u.getMouseScreenPos;
pub const getMouseWorldPos    = cmr_u.getMouseWorldPos;


// ======== COLOURS ========

pub const col_u  = @import( "render/colourer.zig" );

pub const Colour = col_u.Colour;


// ======== DRAWERS ========

pub const wDraw = @import( "render/drawerWorld.zig" );
pub const sDraw = @import( "render/drawerScreen.zig" );


// ======== SPRITEMAPS ========

pub const spm_u = @import( "render/spritemap.zig" );

pub const Spritemap = spm_u.Spritemap;
pub const Sprite    = spm_u.Sprite;


// ================================ RNG SHORTHANDS ================================

// ======== NOISE ========

pub const nsr_u = @import( "rng/noiser2.zig" );

pub const Noise2D = nsr_u.Noise2D;


// ======== RANDOMNESS ========

pub const rng_u = @import( "rng/randomer.zig" );

pub const Randomiser = rng_u.Randomiser;


// ======== SHAKE ========

pub const shk_u = @import( "rng/shaker2.zig" );

pub const Shaker2D = shk_u.Shake2D;


// ================================ UI SHORTHANDS ================================

// ======== RETAINED UI ========

pub const ui_m = @import( "ui/uiContext.zig" );
pub const ui_t = @import( "ui/uiTypes.zig" );

pub const UiManager   = ui_m.UiManager;
pub const UiContext   = ui_m.UiContext;
pub const UiId        = ui_m.UiId;
pub const UiNodeKind  = ui_m.UiNodeKind;
pub const UiLayer     = ui_m.UiLayer;
pub const UiLayout    = ui_m.UiLayout;
pub const UiEvent     = ui_m.UiEvent;
pub const UiEventType = ui_m.UiEventType;
pub const UiStyle     = ui_m.UiStyle;
pub const UiNodeOpts  = ui_m.UiNodeOpts;
pub const UiInput     = ui_m.UiInput;

pub const uiBoxFromTopLeft = ui_m.boxFromTopLeft;


// ======== INTERFACER ========

pub const ntf_u = @import( "ui/interfacer.zig" );

pub const InterfaceShape = ntf_u.InterfaceShape;
pub const BevelType      = ntf_u.BevelType;
pub const BevelArray     = ntf_u.BevelArray;
pub const Interface2D    = ntf_u.Interface2D;



// ================================ HELPER FUNCTIONS ================================

pub const areContEqual = std.meta.eql;


// ================ (DE) INITIALISATION =================

pub inline fn initAllUtils() void
{
  log_u.initFile();
}

pub inline fn deinitAllUtils() void
{
  const bytesInUse = getBytesInUse();

  switch( G_ALLOC.deinit() )
  {
    .ok   => qlog( .INFO, 0, @src(), "$ Default allocator deinitialized without leaks" ),
    .leak => log(  .WARN, 0, @src(), "@ Default allocator detected leaked memory : {d} bytes still in use", .{ bytesInUse } ),
  }

  log_u.deinitFile();
}

pub var G_ALLOC : std.heap.DebugAllocator(.{ .enable_memory_limit = true }) = .init;

pub inline fn getDefaultAlloc() std.mem.Allocator { return G_ALLOC.allocator(); }
pub inline fn getBytesInUse() usize { return G_ALLOC.total_requested_bytes; }



