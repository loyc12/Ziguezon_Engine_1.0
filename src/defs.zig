pub const std = @import( "std" );
pub const ray = @import( "raylib" );

pub const tCol   = @import( "utils/colouriser.zig" );
pub const timer  = @import( "utils/timer.zig" );
pub const rng    = @import( "utils/rng.zig" );

pub var G_RNG : rng.randomiser = .{};

pub fn initAllUtils( allocator : std.mem.Allocator ) void
{
  _ = allocator;

  logger.initLogTimer();
  logger.initFile();

  rng.initGlobalRNG();
  G_RNG = rng.G_RNG;
}

pub fn deinitAllUtils() void
{
  logger.deinitFile();

  G_RNG = undefined;
}

// ================================ DEFINITIONS ================================

pub const DEF_SCREEN_DIMS  = Vec2{ .x = 2048, .y = 1024 };
pub const DEF_TARGET_FPS   = 120; // Default target FPS for the game


// ================================ HOOK MANAGER ================================

pub const ghm = @import( "core/system/gameHookManager.zig" );
pub var G_HK : ghm.gameHooks = .{}; // NOTE : Global gameHooks struct instance

// NOTE : Initialize this in the main
pub fn initHooks( module : anytype ) void                { G_HK.initHooks( module ); }
pub fn tryHook( tag : ghm.hookTag, args : anytype ) void { G_HK.tryHook( tag, args ); }


// ================================ ENGINE ================================

pub const ngn = @import( "core/engine/engineCore.zig" );
pub const Engine = ngn.Engine;
pub var   G_NG : Engine = .{}; // NOTE : Global game engine instance

// ================ MANAGERS ================

pub const rsm = @import( "core/system/resourceManager.zig" );
pub const ntm = @import( "core/system/entityManager.zig" );


// ================ ENTITY SYSTEM ================

pub const ntt    = @import( "core/entity/entityCore.zig" );
pub const Entity = ntt.Entity; // Shorthand for the Entity struct


// ================================ SHORTHANDS ================================

pub const alloc = std.heap.smp_allocator;


// ================ SCREEN MNGR SHORTHANDS ================

pub const vwm = @import( "core/system/viewManager.zig" );

pub const getScreenWidth      = vwm.getScreenWidth;
pub const getScreenHeight     = vwm.getScreenHeight;
pub const getScreenSize       = vwm.getScreenSize;

pub const getHalfScreenWidth  = vwm.getHalfScreenWidth;
pub const getHalfScreenHeight = vwm.getHalfScreenHeight;
pub const getHalfScreenSize   = vwm.getHalfScreenSize;

pub const getMouseScreenPos   = vwm.getMouseScreenPos;
pub const getMouseWorldPos    = vwm.getMouseWorldPos;


// ================ DRAWER SHORTHANDS ================

pub const drawer = @import( "utils/drawer.zig" );

pub const coverScreenWith          = drawer.coverScreenWith;

pub const drawPixel                = drawer.drawPixel;
pub const drawMacroPixel           = drawer.drawMacroPixel;
pub const drawLine                 = drawer.drawLine;
// pub const drawDotedLine            = drawer.drawDotedLine; // TODO : Implement this function
pub const drawCircle               = drawer.drawCircle;
pub const drawCircleLines          = drawer.drawCircleLines;
pub const drawSimpleEllipse        = drawer.drawEllipse;
pub const drawSimpleEllipseLines   = drawer.drawEllipseLines;
pub const drawSimpleRectangle      = drawer.drawRectangle;
pub const drawSimpleRectangleLines = drawer.drawRectangleLines;

pub const drawBasicTria            = drawer.drawTria;
pub const drawBasicTriaLines       = drawer.drawTriaLines;
pub const drawBasicQuad            = drawer.drawQuad;
pub const drawBasicQuadLines       = drawer.drawQuadLines;
pub const drawBasicPoly            = drawer.drawPoly;
pub const drawBasicPolyLines       = drawer.drawPolyLines;

pub const drawRect                 = drawer.drawRectanglePlus;
pub const drawElli                 = drawer.drawEllipsePlus;
pub const drawPoly                 = drawer.drawPolygonPlus;

pub const drawTria                 = drawer.drawTrianglePlus;
pub const drawDiam                 = drawer.drawDiamondPlus;
pub const drawStar                 = drawer.drawHexStarPlus;
pub const drawDstr                 = drawer.drawOctStarPlus;

pub const drawText                 = drawer.drawText;
pub const drawCenteredText         = drawer.drawCenteredText;

pub const drawTexture              = drawer.drawTexture;
pub const drawTextureCentered      = drawer.drawTextureCentered;


// ================ LOGGER SHORTHANDS ================

pub const logger      = @import( "utils/logger.zig" );

pub const log         = logger.log;  // for argument-formatting logging
pub const qlog        = logger.qlog; // for quick logging ( no args )

pub const setTmpTimer = logger.setTmpTimer;
pub const logTmpTimer = logger.logTmpTimer;


// ================ MATHER SHORTHANDS ================

pub const mather      = @import( "utils/mather.zig" );

pub const atan2       = mather.atan2;
pub const DtR         = mather.DtR;
pub const RtD         = mather.RtD;

pub const lerp        = mather.lerp;
pub const med3        = mather.med3;
pub const clmp        = mather.clmp;

pub const norm        = mather.norm;
pub const denorm      = mather.denorm;
pub const renorm      = mather.renorm;


// ================ VECTORS SHORTHANDS ================

// ======== RAYLIB COLOUR ========

pub const Colour = ray.Color;

pub fn newColour( r : u8, g : u8, b : u8, a : ?u8 ) Colour
{
  if( a )| alpha | { return Colour{ .r = r, .g = g, .b = b, .a = alpha }; }
  else             { return Colour{ .r = r, .g = g, .b = b, .a = 255   }; }
}

// ======== Vec2 ========

pub const vec2math = @import( "utils/vec2math.zig" );

pub const Vec2               = vec2math.Vec2;
pub const newVec2            = vec2math.newVec2;
pub const zeroVec2           = vec2math.zeroVec2;

pub const addValToVec2       = vec2math.addValToVec2;
pub const subValFromVec2     = vec2math.subValFromVec2;
pub const mulVec2ByVal       = vec2math.mulVec2ByVal;
pub const divVec2ByVal       = vec2math.divVec2ByVal;

pub const normVec2Unit       = vec2math.normVec2Unit;
pub const normVec2Len        = vec2math.normVec2Len;

pub const addVec2            = vec2math.addVec2;
pub const subVec2            = vec2math.subVec2;
pub const mulVec2            = vec2math.mulVec2;
pub const divVec2            = vec2math.divVec2;

pub const getVec2Dist        = vec2math.getDist;
pub const getVec2CartDist    = vec2math.getCartDist;
pub const getVec2SqrDist     = vec2math.getSqrDist;

pub const getVec2DistX       = vec2math.getDistX;
pub const getVec2DistY       = vec2math.getDistY;

pub const rotVec2Rad         = vec2math.rotVec2Rad;
pub const rotVec2Deg         = vec2math.rotVec2Rad;

pub const vec2ToRad          = vec2math.vec2ToRad;
pub const vec2ToDeg          = vec2math.vec2ToDeg;

pub const vec2AngularDistRad = vec2math.vec2AngularDistRad;
pub const vec2AngularDistDeg = vec2math.vec2AngularDistDeg;

pub const degToVec2          = vec2math.degToVec2;
pub const radToVec2          = vec2math.radToVec2;

pub const degToVec2Scaled    = vec2math.degToVec2Scaled;
pub const radToVec2Scaled    = vec2math.radToVec2Scaled;


// ======== VecR ========

pub const vecRmath = @import( "utils/vecRmath.zig" );

pub const VecR               = vecRmath.VecR;
pub const newVecR            = vecRmath.newVecR;
pub const zeroVecR           = vecRmath.zeroVecR;

pub const addValToVecR       = vecRmath.addValToVecR;
pub const subValFromVecR     = vecRmath.subValFromVecR;
pub const mulVecRByVal       = vecRmath.mulVecRByVal;
pub const divVecRByVal       = vecRmath.divVecRByVal;

pub const normVecRUnit       = vecRmath.normVecRUnit;
pub const normVecRLen        = vecRmath.normVecRLen;

pub const addVecR            = vecRmath.addVecR;
pub const subVecR            = vecRmath.subVecR;
pub const mulVecR            = vecRmath.mulVecR;
pub const divVecR            = vecRmath.divVecR;

pub const getVecRDist        = vecRmath.getVecRDist;
pub const getVecRCartDist    = vecRmath.getVecRCartDist;
pub const getVecRSqrDist     = vecRmath.getVecRSqrDist;

pub const getVecRDistX       = vecRmath.getVecRDistX;
pub const getVecRDistY       = vecRmath.getVecRDistY;
pub const getVecRDistR       = vecRmath.getVecRDistR;

pub const rotVecRDeg         = vecRmath.rotVecRDeg;
pub const rotVecRRad         = vecRmath.rotVecRRad;

pub const vecRToRad          = vecRmath.vecRToRad;
pub const vecRToDeg          = vecRmath.vecRToDeg;

pub const vecRAngularDistRad = vecRmath.vecRAngularDistRad;
pub const vecRAngularDistDeg = vecRmath.vecRAngularDistDeg;

pub const degToVecR          = vecRmath.degToVecR;
pub const radToVecR          = vecRmath.radToVecR;

pub const degToVecRScaled    = vecRmath.degToVecRScaled;
pub const radToVecRScaled    = vecRmath.radToVecRScaled;


// ======== Vec3 ========

pub const vec3math = @import( "utils/vec3math.zig" );

pub const Vec3           = vec3math.Vec3;
pub const newVec3        = vec3math.newVec3;
pub const zeroVec3       = vec3math.zeroVec3;

pub const addValToVec3   = vec3math.addValToVec3;
pub const subValFromVec3 = vec3math.subValFromVec3;
pub const mulVec3ByVal   = vec3math.mulVec3ByVal;
pub const divVec3ByVal   = vec3math.divVec3ByVal;

pub const normVec3Unit   = vec3math.normVec3Unit;
pub const normVec3Len    = vec3math.normVec3Len;

pub const addVec3        = vec3math.addVec3;
pub const subVec3        = vec3math.subVec3;
pub const mulVec3        = vec3math.mulVec3;
pub const divVec3        = vec3math.divVec3;

pub const getDist        = vec3math.getDist;
pub const getCartDist    = vec3math.getCartDist;
pub const getSqrDist     = vec3math.getSqrDist;

pub const getDistX       = vec3math.getDistX;
pub const getDistY       = vec3math.getDistY;
pub const getDistZ       = vec3math.getDistZ;

pub const getDistXY      = vec3math.getDistXY;
pub const getDistXZ      = vec3math.getDistXZ;
pub const getDistYZ      = vec3math.getDistYZ;

pub const getSqrDistXY   = vec3math.getSqrDistXY;
pub const getSqrDistXZ   = vec3math.getSqrDistXZ;
pub const getSqrDistYZ   = vec3math.getSqrDistYZ;

pub const getCylnDistXY  = vec3math.getCylnDistXY;
pub const getCylnDistXZ  = vec3math.getCylnDistXZ;
pub const getCylnDistYZ  = vec3math.getCylnDistYZ;






