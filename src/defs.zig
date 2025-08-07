pub const std = @import( "std" );
pub const ray = @import( "raylib" );

pub const col    = @import( "utils/colour.zig" );
pub const rng    = @import( "utils/rng.zig" );
pub const timer  = @import( "utils/timer.zig" );

// ================================ DEFINITIONS ================================

pub const DEF_SCREEN_DIMS  = Vec2{ .x = 2048, .y = 1024 };
pub const DEF_TARGET_FPS   = 120; // Default target FPS for the game


// ================================ HOOK MANAGER ================================

pub const ghm = @import( "core/system/gameHookManager.zig" );
pub var G_HK : ghm.gameHooks = .{}; // NOTE : Global gameHooks struct instance

pub fn initHooks( module : anytype ) void                { G_HK.initHooks( module ); }
pub fn tryHook( tag : ghm.hookTag, args : anytype ) void { G_HK.tryHook( tag, args ); }


// ================================ ENGINE ================================

pub const ngn = @import( "core/engine/engineCore.zig" );
pub var G_NG : ngn.engine = .{}; // NOTE : Global game engine instance

// ================ MANAGERS ================

pub const rsm = @import( "core/system/resourceManager.zig" );
pub const ntm = @import( "core/system/entityManager.zig" );


// ================ ENTITY SYSTEM ================

pub const ntt = @import( "core/entity/entityCore.zig" );


// ================================ SHORTHANDS ================================

pub const alloc = std.heap.smp_allocator;


// ================ SCREEN MNGR SHORTHANDS ================

pub const scm = @import( "core/system/screenManager.zig" );

pub const getScreenWidth      = scm.getScreenWidth;
pub const getScreenHeight     = scm.getScreenHeight;
pub const getScreenSize       = scm.getScreenSize;

pub const getHalfScreenWidth  = scm.getHalfScreenWidth;
pub const getHalfScreenHeight = scm.getHalfScreenHeight;
pub const getHalfScreenSize   = scm.getHalfScreenSize;

pub const getMouseScreenPos   = scm.getMouseScreenPos;
pub const getMouseWorldPos    = scm.getMouseWorldPos;


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

// ======== Vec2 ========

pub const Vec2math = @import( "utils/vec2math.zig" );

pub const Vec2               = Vec2math.Vec2;
pub const newVec2            = Vec2math.newVec2;

pub const addValToVec2       = Vec2math.addValToVec2;
pub const subValFromVec2     = Vec2math.subValFromVec2;
pub const mulVec2ByVal       = Vec2math.mulVec2ByVal;
pub const divVec2ByVal       = Vec2math.divVec2ByVal;

pub const normVec2Unit       = Vec2math.normVec2Unit;
pub const normVec2Len        = Vec2math.normVec2Len;

pub const addVec2            = Vec2math.addVec2;
pub const subVec2            = Vec2math.subVec2;
pub const mulVec2            = Vec2math.mulVec2;
pub const divVec2            = Vec2math.divVec2;

pub const getVec2Dist        = Vec2math.getDist;
pub const getVec2CartDist    = Vec2math.getCartDist;
pub const getVec2SqrDist     = Vec2math.getSqrDist;

pub const getVec2DistX       = Vec2math.getDistX;
pub const getVec2DistY       = Vec2math.getDistY;

pub const rotVec2Rad         = Vec2math.rotVec2Rad;
pub const rotVec2Deg         = Vec2math.rotVec2Rad;

pub const vec2ToRad          = Vec2math.vec2ToRad;
pub const vec2ToDeg          = Vec2math.vec2ToDeg;

pub const vec2AngularDistRad = Vec2math.vec2AngularDistRad;
pub const vec2AngularDistDeg = Vec2math.vec2AngularDistDeg;

pub const degToVec2          = Vec2math.degToVec2;
pub const radToVec2          = Vec2math.radToVec2;

pub const degToVec2Scaled    = Vec2math.degToVec2Scaled;
pub const radToVec2Scaled    = Vec2math.radToVec2Scaled;


// ======== VecR ========

pub const VecRmath = @import( "utils/vecRmath.zig" );

pub const VecR               = VecRmath.VecR;
pub const newVecR            = VecRmath.newVecR;
pub const getRVal            = VecRmath.getRVal;

pub const addValToVecR       = VecRmath.addValToVecR;
pub const subValFromVecR     = VecRmath.subValFromVecR;
pub const mulVecRByVal       = VecRmath.mulVecRByVal;
pub const divVecRByVal       = VecRmath.divVecRByVal;

pub const normVecRUnit       = VecRmath.normVecRUnit;
pub const normVecRLen        = VecRmath.normVecRLen;

pub const addVecR            = VecRmath.addVecR;
pub const subVecR            = VecRmath.subVecR;
pub const mulVecR            = VecRmath.mulVecR;
pub const divVecR            = VecRmath.divVecR;

pub const getVecRDist        = VecRmath.getVecRDist;
pub const getVecRCartDist    = VecRmath.getVecRCartDist;
pub const getVecRSqrDist     = VecRmath.getVecRSqrDist;

pub const getVecRDistX       = VecRmath.getVecRDistX;
pub const getVecRDistY       = VecRmath.getVecRDistY;
pub const getVecRDistR       = VecRmath.getVecRDistR;

pub const rotVecRDeg         = VecRmath.rotVecRDeg;
pub const rotVecRRad         = VecRmath.rotVecRRad;

pub const vecRToRad          = VecRmath.vecRToRad;
pub const vecRToDeg          = VecRmath.vecRToDeg;

pub const vecRAngularDistRad = VecRmath.vecRAngularDistRad;
pub const vecRAngularDistDeg = VecRmath.vecRAngularDistDeg;

pub const degToVecR          = VecRmath.degToVecR;
pub const radToVecR          = VecRmath.radToVecR;

pub const degToVecRScaled    = VecRmath.degToVecRScaled;
pub const radToVecRScaled    = VecRmath.radToVecRScaled;


// ======== Vec3 ========

pub const Vec3math = @import( "utils/vec3math.zig" );

pub const Vec3           = Vec3math.Vec3;
pub const newVec3        = Vec3math.newVec3;

pub const addValToVec3   = Vec3math.addValToVec3;
pub const subValFromVec3 = Vec3math.subValFromVec3;
pub const mulVec3ByVal   = Vec3math.mulVec3ByVal;
pub const divVec3ByVal   = Vec3math.divVec3ByVal;

pub const normVec3Unit   = Vec3math.normVec3Unit;
pub const normVec3Len    = Vec3math.normVec3Len;

pub const addVec3        = Vec3math.addVec3;
pub const subVec3        = Vec3math.subVec3;
pub const mulVec3        = Vec3math.mulVec3;
pub const divVec3        = Vec3math.divVec3;

pub const getDist        = Vec3math.getDist;
pub const getCartDist    = Vec3math.getCartDist;
pub const getSqrDist     = Vec3math.getSqrDist;

pub const getDistX       = Vec3math.getDistX;
pub const getDistY       = Vec3math.getDistY;
pub const getDistZ       = Vec3math.getDistZ;

pub const getDistXY      = Vec3math.getDistXY;
pub const getDistXZ      = Vec3math.getDistXZ;
pub const getDistYZ      = Vec3math.getDistYZ;

pub const getSqrDistXY   = Vec3math.getSqrDistXY;
pub const getSqrDistXZ   = Vec3math.getSqrDistXZ;
pub const getSqrDistYZ   = Vec3math.getSqrDistYZ;

pub const getCylnDistXY  = Vec3math.getCylnDistXY;
pub const getCylnDistXZ  = Vec3math.getCylnDistXZ;
pub const getCylnDistYZ  = Vec3math.getCylnDistYZ;






