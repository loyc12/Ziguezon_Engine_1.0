pub const std = @import( "std" );
pub const ray = @import( "raylib" );

pub const col_u  = @import( "utils/colouriser.zig" );
pub const tmr_u  = @import( "utils/timer.zig" );
pub const rng_u  = @import( "utils/rng.zig" );

pub var G_RNG : rng_u.randomiser = .{};

pub fn initAllUtils( allocator : std.mem.Allocator ) void
{
  _ = allocator;

  log_u.initLogTimer();
  log_u.initFile();

  rng_u.initGlobalRNG();
  G_RNG = rng_u.G_RNG;
}

pub fn deinitAllUtils() void
{
  log_u.deinitFile();

  G_RNG = undefined;
}

// ================================ DEFINITIONS ================================

pub const DEF_SCREEN_DIMS  = Vec2{ .x = 2048, .y = 1024 };
pub const DEF_TARGET_FPS   = 120; // Default target FPS for the game


// ================================ HOOK MANAGER ================================

pub const ghk_m = @import( "core/system/gameHookManager.zig" );
pub var G_HK : ghk_m.gameHooks = .{}; // NOTE : Global gameHooks struct instance

// NOTE : Do not forget to call def.initHooks( SpecificGameModule ) in your main function
pub fn initHooks( module : anytype ) void                  { G_HK.initHooks( module ); }
pub fn tryHook( tag : ghk_m.hookTag, args : anytype ) void { G_HK.tryHook( tag, args ); }


// ================================ ENGINE ================================

pub const ng     = @import( "core/engine/engineCore.zig" );
pub const Engine = ng.Engine;
pub var   G_NG : Engine = .{}; // NOTE : Global game engine instance

// ================ MANAGERS ================

pub const res_m = @import( "core/system/resourceManager.zig" );
pub const ntt_m = @import( "core/system/entityManager.zig" );
pub const tlm_m = @import( "core/system/tilemapManager.zig" );
pub const scr_m = @import( "core/system/viewManager.zig" );


// ================ ENTITY SYSTEM ================

pub const ntt    = @import( "core/entity/entityCore.zig" );
pub const Entity = ntt.Entity;


// ================ TILEMAP SYSTEM ================

pub const tlm     = @import( "core/tilemap/tilemapCore.zig" );
pub const Tile    = tlm.Tile;
pub const Tilemap = tlm.Tilemap;


// ================================ MANAGER SHORTHANDS ================================

pub const alloc = std.heap.smp_allocator;


// ================ SCREEN MNGR SHORTHANDS ================

pub const getScreenWidth      = scr_m.getScreenWidth;
pub const getScreenHeight     = scr_m.getScreenHeight;
pub const getScreenSize       = scr_m.getScreenSize;

pub const getHalfScreenWidth  = scr_m.getHalfScreenWidth;
pub const getHalfScreenHeight = scr_m.getHalfScreenHeight;
pub const getHalfScreenSize   = scr_m.getHalfScreenSize;

pub const getMouseScreenPos   = scr_m.getMouseScreenPos;
pub const getMouseWorldPos    = scr_m.getMouseWorldPos;


// ================ DRAWER SHORTHANDS ================

pub const drw_u                    = @import( "utils/drawer.zig" );

pub const coverScreenWith          = drw_u.coverScreenWith;

pub const drawPixel                = drw_u.drawPixel;
pub const drawMacroPixel           = drw_u.drawMacroPixel;
pub const drawLine                 = drw_u.drawLine;
// pub const drawDotedLine            = drw_u.drawDotedLine; // TODO : Implement this function
pub const drawCircle               = drw_u.drawCircle;
pub const drawCircleLines          = drw_u.drawCircleLines;
pub const drawSimpleEllipse        = drw_u.drawEllipse;
pub const drawSimpleEllipseLines   = drw_u.drawEllipseLines;
pub const drawSimpleRectangle      = drw_u.drawRectangle;
pub const drawSimpleRectangleLines = drw_u.drawRectangleLines;

pub const drawBasicTria            = drw_u.drawTria;
pub const drawBasicTriaLines       = drw_u.drawTriaLines;
pub const drawBasicQuad            = drw_u.drawQuad;
pub const drawBasicQuadLines       = drw_u.drawQuadLines;
pub const drawBasicPoly            = drw_u.drawPoly;
pub const drawBasicPolyLines       = drw_u.drawPolyLines;

pub const drawRect                 = drw_u.drawRectanglePlus;
pub const drawElli                 = drw_u.drawEllipsePlus;
pub const drawPoly                 = drw_u.drawPolygonPlus;

pub const drawTria                 = drw_u.drawTrianglePlus;
pub const drawDiam                 = drw_u.drawDiamondPlus;
pub const drawStar                 = drw_u.drawHexStarPlus;
pub const drawDstr                 = drw_u.drawOctStarPlus;

pub const drawText                 = drw_u.drawText;
pub const drawCenteredText         = drw_u.drawCenteredText;

pub const drawTexture              = drw_u.drawTexture;
pub const drawTextureCentered      = drw_u.drawTextureCentered;


// ================================ UTILS SHORTHANDS ================================

// ================ ANGLER SHORTHANDS ================================

pub const ngl_u = @import( "utils/angler.zig" );

pub const Angle = ngl_u.Angle;


// ================ BOXER SHORTHANDS ================

pub const box_u = @import( "utils/boxer.zig" );

pub const getLeftX       = box_u.getLeftX;
pub const getRightX      = box_u.getRightX;
pub const getTopY        = box_u.getTopY;
pub const getBottomY     = box_u.getBottomY;

pub const getTopLeft     = box_u.getTopLeft;
pub const getTopRight    = box_u.getTopRight;
pub const getBottomLeft  = box_u.getBottomLeft;
pub const getBottomRight = box_u.getBottomRight;


pub const getCenterXFromLeftX      = box_u.getCenterXFromLeftX;
pub const getCenterXFromRightX     = box_u.getCenterXFromRightX;
pub const getCenterYFromTopY       = box_u.getCenterYFromTopY;
pub const getCenterYFromBottomY    = box_u.getCenterYFromBottomY;

pub const getCenterFromTopLeft     = box_u.getCenterFromTopLeft;
pub const getCenterFromTopRight    = box_u.getCenterFromTopRight;
pub const getCenterFromBottomLeft  = box_u.getCenterFromBottomLeft;
pub const getCenterFromBottomRight = box_u.getCenterFromBottomRight;


pub const isLeftOfX   = box_u.isLeftOfX;
pub const isRightOfX  = box_u.isRightOfX;
pub const isBelowY    = box_u.isBelowY;
pub const isAboveY    = box_u.isAboveY;

pub const isOnXVal    = box_u.isOnXVal;
pub const isOnYVal    = box_u.isOnYVal;
pub const isOnPoint   = box_u.isOnPoint;

pub const isOnXRange  = box_u.isOnXRange;
pub const isOnYRange  = box_u.isOnYRange;
pub const isOnArea    = box_u.isOnArea;

pub const isInXRange  = box_u.isInXRange;
pub const isInYRange  = box_u.isInYRange;
pub const isInArea    = box_u.isInArea;


pub const clampLeftOfX   = box_u.clampLeftOfX;
pub const clampRightOfX  = box_u.clampRightOfX;
pub const clampBelowY    = box_u.clampBelowY;
pub const clampAboveY    = box_u.clampAboveY;

pub const clampOnXVal    = box_u.clampOnXVal;
pub const clampOnYVal    = box_u.clampOnYVal;
pub const clampOnPoint   = box_u.clampOnPoint;

pub const clampOnXRange  = box_u.clampOnXRange;
pub const clampOnYRange  = box_u.clampOnYRange;
pub const clampOnArea    = box_u.clampOnArea;

pub const clampInXRange  = box_u.clampInXRange;
pub const clampInYRange  = box_u.clampInYRange;
pub const clampInArea    = box_u.clampInArea;


// ================ LOGGER SHORTHANDS ================

pub const log_u       = @import( "utils/logger.zig" );

pub const log         = log_u.log;  // for argument-formatting logging
pub const qlog        = log_u.qlog; // for quick logging ( no args )

pub const setTmpTimer = log_u.setTmpTimer;
pub const logTmpTimer = log_u.logTmpTimer;


// ================ MATHER SHORTHANDS ================

pub const mth_u  = @import( "utils/mather.zig" );

pub const atan2  = mth_u.atan2;
pub const DtR    = mth_u.DtR;
pub const RtD    = mth_u.RtD;

pub const lerp   = mth_u.lerp;
pub const med3   = mth_u.med3;
pub const clmp   = mth_u.clmp;
pub const wrap   = mth_u.wrap;

pub const norm   = mth_u.norm;
pub const denorm = mth_u.denorm;
pub const renorm = mth_u.renorm;


// ================ COORDS SHORTHANDS ================

pub const cor_u   = @import( "utils/coorder.zig" );
pub const Coords2 = cor_u.Coords2;
pub const Coords3 = cor_u.Coords3;


// ================ VECTORS SHORTHANDS ================

pub const RayVec2 = ray.Vector2;
pub const RayVec3 = ray.Vector3;
pub const RayVec4 = ray.Vector4;

pub const nullRayVec2 = RayVec2{ .x = 0, .y = 0 };
pub const nullRayVec3 = RayVec3{ .x = 0, .y = 0, .z = 0 };
pub const nullRayVec4 = RayVec4{ .x = 0, .y = 0, .z = 0, .w = 0 };


pub const vec2_u = @import( "utils/vecter2.zig" );
pub const Vec2   = vec2_u.Vec2;

pub const vecR_u = @import( "utils/vecterR.zig" );
pub const VecR   = vecR_u.VecR;

pub const vec3_u = @import( "utils/vecter3.zig" );
pub const Vec3   = vec3_u.Vec3;

pub const nullVec2 = Vec2{ .x = 0, .y = 0 };
pub const nullVecR = VecR{ .x = 0, .y = 0, .r = 0 };
pub const nullVec3 = Vec3{ .x = 0, .y = 0, .z = 0 };


// ================= RAYLIB SHORTHANDS ================

pub const Camera = ray.Camera2D;

pub const Colour = ray.Color;

pub fn newColour( r : u8, g : u8, b : u8, a : ?u8 ) Colour
{
  if( a )| alpha | { return Colour{ .r = r, .g = g, .b = b, .a = alpha }; }
  else             { return Colour{ .r = r, .g = g, .b = b, .a = 255   }; }
}


//// ======== Vec2 ========
//
//pub const vec2math = @import( "utils/vec2math.zig" );
//
//pub const Vec2               = vec2math.Vec2;
//pub const newVec2            = vec2math.newVec2;
//pub const zeroVec2           = vec2math.zeroVec2;
//
//pub const addValToVec2       = vec2math.addValToVec2;
//pub const subValFromVec2     = vec2math.subValFromVec2;
//pub const mulVec2ByVal       = vec2math.mulVec2ByVal;
//pub const divVec2ByVal       = vec2math.divVec2ByVal;
//
//pub const normVec2Unit       = vec2math.normVec2Unit;
//pub const normVec2Len        = vec2math.normVec2Len;
//
//pub const addVec2            = vec2math.addVec2;
//pub const subVec2            = vec2math.subVec2;
//pub const mulVec2            = vec2math.mulVec2;
//pub const divVec2            = vec2math.divVec2;
//
//pub const getVec2Dist        = vec2math.getDist;
//pub const getVec2CartDist    = vec2math.getCartDist;
//pub const getVec2SqrDist     = vec2math.getSqrDist;
//
//pub const getVec2DistX       = vec2math.getDistX;
//pub const getVec2DistY       = vec2math.getDistY;
//
//pub const rotVec2Rad         = vec2math.rotVec2Rad;
//pub const rotVec2Deg         = vec2math.rotVec2Rad;
//
//pub const vec2ToRad          = vec2math.vec2ToRad;
//pub const vec2ToDeg          = vec2math.vec2ToDeg;
//
//pub const vec2AngularDistRad = vec2math.vec2AngularDistRad;
//pub const vec2AngularDistDeg = vec2math.vec2AngularDistDeg;
//
//pub const degToVec2          = vec2math.degToVec2;
//pub const radToVec2          = vec2math.radToVec2;
//
//pub const degToVec2Scaled    = vec2math.degToVec2Scaled;
//pub const radToVec2Scaled    = vec2math.radToVec2Scaled;
//
//
//// ======== VecR ========
//
//pub const vecRmath = @import( "utils/vecRmath.zig" );
//
//pub const VecR               = vecRmath.VecR;
//pub const newVecR            = vecRmath.newVecR;
//pub const zeroVecR           = vecRmath.zeroVecR;
//
//pub const addValToVecR       = vecRmath.addValToVecR;
//pub const subValFromVecR     = vecRmath.subValFromVecR;
//pub const mulVecRByVal       = vecRmath.mulVecRByVal;
//pub const divVecRByVal       = vecRmath.divVecRByVal;
//
//pub const normVecRUnit       = vecRmath.normVecRUnit;
//pub const normVecRLen        = vecRmath.normVecRLen;
//
//pub const addVecR            = vecRmath.addVecR;
//pub const subVecR            = vecRmath.subVecR;
//pub const mulVecR            = vecRmath.mulVecR;
//pub const divVecR            = vecRmath.divVecR;
//
//pub const getVecRDist        = vecRmath.getVecRDist;
//pub const getVecRCartDist    = vecRmath.getVecRCartDist;
//pub const getVecRSqrDist     = vecRmath.getVecRSqrDist;
//
//pub const getVecRDistX       = vecRmath.getVecRDistX;
//pub const getVecRDistY       = vecRmath.getVecRDistY;
//pub const getVecRDistR       = vecRmath.getVecRDistR;
//
//pub const rotVecRDeg         = vecRmath.rotVecRDeg;
//pub const rotVecRRad         = vecRmath.rotVecRRad;
//
//pub const vecRToRad          = vecRmath.vecRToRad;
//pub const vecRToDeg          = vecRmath.vecRToDeg;
//
//pub const vecRAngularDistRad = vecRmath.vecRAngularDistRad;
//pub const vecRAngularDistDeg = vecRmath.vecRAngularDistDeg;
//
//pub const degToVecR          = vecRmath.degToVecR;
//pub const radToVecR          = vecRmath.radToVecR;
//
//pub const degToVecRScaled    = vecRmath.degToVecRScaled;
//pub const radToVecRScaled    = vecRmath.radToVecRScaled;
//
//
//// ======== Vec3 ========
//
//pub const vec3math = @import( "utils/vec3math.zig" );
//
//pub const Vec3           = vec3math.Vec3;
//pub const newVec3        = vec3math.newVec3;
//pub const zeroVec3       = vec3math.zeroVec3;
//
//pub const addValToVec3   = vec3math.addValToVec3;
//pub const subValFromVec3 = vec3math.subValFromVec3;
//pub const mulVec3ByVal   = vec3math.mulVec3ByVal;
//pub const divVec3ByVal   = vec3math.divVec3ByVal;
//
//pub const normVec3Unit   = vec3math.normVec3Unit;
//pub const normVec3Len    = vec3math.normVec3Len;
//
//pub const addVec3        = vec3math.addVec3;
//pub const subVec3        = vec3math.subVec3;
//pub const mulVec3        = vec3math.mulVec3;
//pub const divVec3        = vec3math.divVec3;
//
//pub const getDist        = vec3math.getDist;
//pub const getCartDist    = vec3math.getCartDist;
//pub const getSqrDist     = vec3math.getSqrDist;
//
//pub const getDistX       = vec3math.getDistX;
//pub const getDistY       = vec3math.getDistY;
//pub const getDistZ       = vec3math.getDistZ;
//
//pub const getDistXY      = vec3math.getDistXY;
//pub const getDistXZ      = vec3math.getDistXZ;
//pub const getDistYZ      = vec3math.getDistYZ;
//
//pub const getSqrDistXY   = vec3math.getSqrDistXY;
//pub const getSqrDistXZ   = vec3math.getSqrDistXZ;
//pub const getSqrDistYZ   = vec3math.getSqrDistYZ;
//
//pub const getCylnDistXY  = vec3math.getCylnDistXY;
//pub const getCylnDistXZ  = vec3math.getCylnDistXZ;
//pub const getCylnDistYZ  = vec3math.getCylnDistYZ;






