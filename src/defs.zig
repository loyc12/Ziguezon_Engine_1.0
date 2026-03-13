pub const std = @import( "std" );
pub const ray = @import( "raylib" );


pub var G_RNG : rng_u.Randomiser = .{};
pub var G_NG  : Engine = .{}; // Global game engine instance
pub var G_CAM : Cam2D  = .{}; // Global camera2D instance

// TODO : split engineDefs from utilDefs, have the former include the later


// ================================ GLOBAL INITIALIZATION / DEINITIALIZATION ================================

pub fn getAlloc() std.mem.Allocator { return std.heap.page_allocator; }

pub var GLOBAL_EPOCH : TimeVal = .{};


pub fn initAllUtils( allocator : std.mem.Allocator ) void
{
  //GLOBAL_EPOCH = getNow();

  std.debug.print( "allocator.ptr    = {}\n", .{ allocator.ptr } );
  std.debug.print( "allocater.vtable = {}\n", .{ allocator.vtable } );

  log_u.initFile();

  rng_u.initGlobalRNG();
  G_RNG = rng_u.G_RNG;
}

pub fn deinitAllUtils() void
{
  log_u.deinitFile();

  G_RNG = undefined;
}



// ================================ INTERFACER HANDLERS ================================

// ================ ENGINE SETTINGS ================
// NOTE : Do not forget to call def.Settings( SpecificGameInterface ) in your main function

const  ngs_h = @import( "core/interfacers/engineSettings.zig" );
pub var G_ST : ngs_h.EngineSettings = .{}; // NOTE : Global engineSettings struct instance

pub inline fn loadSettings( module : anytype ) void { G_ST.loadSettings( module ); }


// ================ GAME HOOKS ================
// NOTE : Do not forget to call def.loadHooks( SpecificGameInterface ) in your main function

const  ghk_h = @import( "core/interfacers/gameHooks.zig" );
pub var G_HK : ghk_h.GameHooks = .{}; // NOTE : Global gameHooks struct instance

pub const HookCntx = ghk_h.HookCntx;
pub const HookFunc = ghk_h.HookFunc;

pub inline fn loadHooks( module : anytype ) void                      { G_HK.loadHooks( module  ); }
pub inline fn tryHook( tag : ghk_h.e_hook_tag, cntx : HookCntx ) void { G_HK.tryHook( tag, cntx ); }



// ================================ ENGINE SYSTEMS ================================

pub const ng            = @import( "core/engine/engineCore.zig" );
pub const Engine        = ng.Engine;


// ================ MANAGERS ================

pub const res_m = @import( "core/resource/resourceManager.zig" );
pub const bdy_m = @import( "core/body/bodyManager.zig" );
pub const tlm_m = @import( "core/tilemap/tilemapManager.zig" );
pub const vnt_m = @import( "core/event/eventManager.zig" );


// ================ BODY ================

pub const bdy         = @import( "core/body/bodyCore.zig" );
pub const Body        = bdy.Body;

pub const e_bdy_flags = bdy.e_bdy_flags;


// ================ TILEMAP ================

pub const tlm          = @import( "core/tilemap/tilemapCore.zig" );

pub const Tile         = tlm.Tile;
pub const e_tile_type  = tlm.e_tile_type;

pub const Tilemap      = tlm.Tilemap;
pub const e_tlmp_shape = tlm.e_tlmp_shape;


// ================ SCRIPT ================

pub const spt        = @import( "core/script/scripter.zig" );

pub const Scripter   = spt.Scripter;
pub const ScriptData = spt.ScriptData;
pub const ScriptCntx = spt.ScriptCntx;
pub const ScriptFunc = spt.ScriptFunc;


// ================ ECS ================

pub const ntt              = @import( "core/ecs/entity.zig" );

pub const Entity           = ntt.Entity;
pub const EntityId         = ntt.EntityId;
pub const EntityIdRegistry = ntt.EntityIdRegistry;


pub const cmp                   = @import( "core/ecs/component.zig" );

pub const ComponentRegistry     = cmp.ComponentRegistry;
pub const componentStoreFactory = cmp.componentStoreFactory;


pub const cmp2 = @import( "core/ecs/baseComps.zig" );

pub const TransComp  = cmp2.TransComp;
pub const ShapeComp  = cmp2.ShapeComp;
pub const SpriteComp = cmp2.SpriteComp;


// ================ EVENT ================

pub const vnt        = @import( "core/event/event.zig" );

pub const Event      = vnt.Event;

pub const EventType  = vnt.EventType;
pub const EventPhase = vnt.EventPhase;
pub const EventData  = vnt.EventData;
pub const EventFunc  = vnt.EventFunc;

pub const EventListener      = vnt.EventListener;
pub const EventListenerArray = vnt.EventListenerArray;
pub const EventQueue         = vnt.EventQueue;



// ================================ RAYLIB SHORTHANDS ================================

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

pub const ngl_u = @import( "utils/data/angler.zig" );

pub const Angle = ngl_u.Angle;


// ======== BOXES ========

pub const box2_u = @import( "utils/data/boxer2.zig" );

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

pub const cor2_u  = @import( "utils/data/coorder2.zig" );
pub const cor3_u  = @import( "utils/data/coorder3.zig" );

pub const e_dir_2 = cor2_u.e_dir_2;
pub const e_dir_3 = cor3_u.e_dir_3;

pub const Coords2 = cor2_u.Coords2;
pub const Coords3 = cor3_u.Coords3;


// ======== DATA MATRIX ========

pub const d1d_u  = @import( "utils/data/data1D.zig" );
pub const d2d_u  = @import( "utils/data/data2D.zig" );
pub const d3d_u  = @import( "utils/data/data3D.zig" );

pub const newDataArray  = d1d_u.newDataArray;
pub const newDataGrid   = d2d_u.newDataGrid;
pub const newDataMatrix = d3d_u.newDataMatrix;


// ======== BITFLAGS ========

pub const flg_u = @import( "utils/data/flagger.zig" );

pub const BitField8  = flg_u.BitField8;
pub const BitField16 = flg_u.BitField16;
pub const BitField32 = flg_u.BitField32;
pub const BitField64 = flg_u.BitField64;


// ======== TIMING ========

pub const tmr_u         = @import( "utils/data/timer.zig" );

pub const TimeVal       = tmr_u.TimeVal;
pub const Timer         = tmr_u.Timer;
pub const e_timer_flags = tmr_u.e_timer_flags;

pub const getNow        = tmr_u.getNow;


// ======== VECTORS ========

pub const vec2_u = @import( "utils/data/vecter2.zig" );
pub const vec3_u = @import( "utils/data/vecter3.zig" );
pub const vecA_u = @import( "utils/data/vecterA.zig" );

pub const Vec2   = vec2_u.Vec2;
pub const Vec3   = vec3_u.Vec3;
pub const VecA   = vecA_u.VecA;



// ================ I/O SHORTHANDS ================================

// ================ LOGGING ================

pub const log_u = @import( "utils/io/logger.zig" );

pub const log   = log_u.log;  // for argument-formatting logging
pub const qlog  = log_u.qlog; // for quick logging ( no args )

pub const resetTmpTimer = log_u.resetTmpTimer;
pub const logTmpTimer   = log_u.logTmpTimer;


// ================ CLI COLOURS ================

pub const tcl_u  = @import( "utils/io/termColourer.zig" );



// ================================ MATHS SHORTHANDS ================================

// ======== ARITHMETICS ========

pub const mth_u  = @import( "utils/maths/mather.zig" );

pub const atan2  = mth_u.atan2;
pub const DtR    = mth_u.DtR;
pub const RtD    = mth_u.RtD;

pub const E      = mth_u.E;
pub const PI     = mth_u.PI;
pub const TAU    = mth_u.TAU;
pub const PHI    = mth_u.PHI;
pub const EPS    = mth_u.EPS;

pub const R2     = mth_u.R2;
pub const HR2    = mth_u.HR2;
pub const IR2    = mth_u.IR2;

pub const R3     = mth_u.R3;
pub const HR3    = mth_u.HR3;
pub const IR3    = mth_u.IR3;


pub const inv1   = mth_u.inv1;
pub const sign   = mth_u.sign;
pub const pow2   = mth_u.pow2;

pub const lerp   = mth_u.lerp;
pub const pow    = mth_u.pow;

pub const sqrt   = mth_u.sqrt;
pub const cbrt   = mth_u.cbrt;

pub const gcd    = mth_u.gcd;

pub const med3   = mth_u.med3;
pub const clmp   = mth_u.clmp;
pub const wrap   = mth_u.wrap;

pub const norm   = mth_u.norm;
pub const denorm = mth_u.denorm;
pub const renorm = mth_u.renorm;

pub const getPolyCircumRad = mth_u.getPolyCircumRad;
pub const getPolyArea      = mth_u.getPolyArea;


// ======== SHAPES ========

pub const shp2_u = @import( "utils/maths/shape2.zig" );
pub const shp3_u = @import( "utils/maths/shape2.zig" );

pub const Shape2D = shp2_u.Shape2D;
pub const Shape3D = shp3_u.Shape3D;



// ================================ RENDER SHORTHANDS ================================

// ======== CAMERA ========

pub const cmr_u = @import( "utils/render/camer.zig" );

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

pub const col_u  = @import( "utils/render/colourer.zig" );

pub const Colour = col_u.Colour;


// ======== SCREEN DRAWER ========

pub const drwS_u = @import( "utils/render/drawerS.zig" );

pub const getDefaultFont     = drwS_u.getDefaultFont;
pub const setDefaultFont     = drwS_u.setDefaultFont;

pub const clearBackground    = drwS_u.clearBackground;
pub const coverScreenWithCol = drwS_u.coverScreenWithCol;

pub const drawScreenPixel                = drwS_u.drawPixel;
pub const drawScreenMacroPixel           = drwS_u.drawMacroPixel;
pub const drawScreenLine                 = drwS_u.drawLine;
// pub const drawDotedLine                 = drwS_u.drawDotedLine; // TODO : Implement this function
pub const drawScreenCircle               = drwS_u.drawCircle;
pub const drawScreenCircleLines          = drwS_u.drawCircleLines;
pub const drawScreenSimpleEllipse        = drwS_u.drawEllipse;
pub const drawScreenSimpleEllipseLines   = drwS_u.drawEllipseLines;
pub const drawScreenSimpleRectangle      = drwS_u.drawRectangle;
pub const drawScreenSimpleRectangleLines = drwS_u.drawRectangleLines;

pub const drawScreenBasicTria            = drwS_u.drawTria;
pub const drawScreenBasicTriaLines       = drwS_u.drawTriaLines;
pub const drawScreenBasicQuad            = drwS_u.drawQuad;
pub const drawScreenBasicQuadLines       = drwS_u.drawQuadLines;
pub const drawScreenBasicPoly            = drwS_u.drawPoly;
pub const drawScreenBasicPolyLines       = drwS_u.drawPolyLines;


pub const drawScreenTria = drwS_u.drawTrianglePlus;
pub const drawScreenDiam = drwS_u.drawDiamondPlus;
pub const drawScreenPent = drwS_u.drawPentagonPlus;
pub const drawScreenHexa = drwS_u.drawHexagonPlus;

pub const drawScreenRect = drwS_u.drawRectanglePlus;
pub const drawScreenPoly = drwS_u.drawPolygonPlus;
pub const drawScreenStar = drwS_u.drawStarPlus;


pub const drawScreenTexture         = drwS_u.drawTexture;
pub const drawScreenTextureCentered = drwS_u.drawTextureCentered;


pub const drawText          = drwS_u.drawText;
pub const drawTextFmt       = drwS_u.drawTextFmt;

pub const drawTextOffset    = drwS_u.drawTextOffset;
pub const drawTextOffsetFmt = drwS_u.drawTextOffsetFmt;

pub const drawTextCenter    = drwS_u.drawTextCenter;
pub const drawTextCenterFmt = drwS_u.drawTextCenterFmt;

pub const drawTextRight     = drwS_u.drawTextRight;
pub const drawTextRightFmt  = drwS_u.drawTextRightFmt;

pub const drawTextBottom    = drwS_u.drawTextBottom;
pub const drawTextBottomFmt = drwS_u.drawTextBottomFmt;

pub const drawTextLeft      = drwS_u.drawTextLeft;
pub const drawTextLeftFmt   = drwS_u.drawTextLeftFmt;

pub const drawTextTop       = drwS_u.drawTextTop;
pub const drawTextTopFmt    = drwS_u.drawTextTopFmt;


// ======== WORLD DRAWER ========

pub const drwW_u = @import( "utils/render/drawerW.zig" );

pub const drawPixel                = drwW_u.drawPixel;
pub const drawMacroPixel           = drwW_u.drawMacroPixel;
pub const drawLine                 = drwW_u.drawLine;
// pub const drawDotedLine           = drwS_u.drawDotedLine; // TODO : Implement this function
pub const drawCircle               = drwW_u.drawCircle;
pub const drawCircleLines          = drwW_u.drawCircleLines;
pub const drawSimpleEllipse        = drwW_u.drawEllipse;
pub const drawSimpleEllipseLines   = drwW_u.drawEllipseLines;
pub const drawSimpleRectangle      = drwW_u.drawRectangle;
pub const drawSimpleRectangleLines = drwW_u.drawRectangleLines;

pub const drawBasicTria            = drwW_u.drawTria;
pub const drawBasicTriaLines       = drwW_u.drawTriaLines;
pub const drawBasicQuad            = drwW_u.drawQuad;
pub const drawBasicQuadLines       = drwW_u.drawQuadLines;
pub const drawBasicPoly            = drwW_u.drawPoly;
pub const drawBasicPolyLines       = drwW_u.drawPolyLines;


pub const drawTria = drwW_u.drawTrianglePlus;
pub const drawDiam = drwW_u.drawDiamondPlus;
pub const drawPent = drwW_u.drawPentagonPlus;
pub const drawHexa = drwW_u.drawHexagonPlus;

pub const drawRect = drwW_u.drawRectanglePlus;
pub const drawPoly = drwW_u.drawPolygonPlus;
pub const drawStar = drwW_u.drawStarPlus;


pub const drawTexture         = drwW_u.drawTexture;
pub const drawTextureCentered = drwW_u.drawTextureCentered;


// ======== SPRITEMAPS ========

pub const spm_u = @import( "utils/render/spritemap.zig" );

pub const Spritemap = spm_u.Spritemap;
pub const Sprite    = spm_u.Sprite;



// ================================ RNG SHORTHANDS ================================

// ======== NOISE ========

pub const nsr_u = @import( "utils/rng/noiser2.zig" );

pub const Noise2D = nsr_u.Noise2D;


// ======== RANDOMNESS ========

pub const rng_u  = @import( "utils/rng/randomer.zig" );

// ======== SHAKE ========

pub const shk_u = @import( "utils/rng/shaker2.zig" );

pub const Shaker2D = shk_u.Shake2D;









