pub const std = @import( "std" );
pub const ray = @import( "raylib" );

pub const col    = @import( "utils/colour.zig" );
pub const rng    = @import( "utils/rng.zig" );
pub const timer  = @import( "utils/timer.zig" );


// ================================ CORE ENGINE MODULES ================================

// ================ GAME HOOK SYSTEM ================
pub const ghm = @import( "core/gameHookManager.zig" );
pub var G_HK : ghm.gameHooks = .{}; // NOTE : Global gameHooks struct instance

pub fn initHooks( module : anytype ) void                { G_HK.initHooks( module ); }
pub fn tryHook( tag : ghm.hookTag, args : anytype ) void { G_HK.tryHook( tag, args ); }


// ================ ENGINE & MANAGERS ================
pub const eng = @import( "core/engine.zig" );
pub const rsm = @import( "core/resourceManager.zig" );
pub const ntm = @import( "core/entityManager.zig" );

pub var G_NG : eng.engine = .{}; // NOTE : Global game engine instance


// ================ ENTITY SYSTEM ================
pub const ntt = @import( "core/entity/entityCore.zig" );


// ================================ SHORTHANDS ================================
pub const alloc = std.heap.smp_allocator;


// ================ DRAWER SHORTHANDS ================
pub const drawer              = @import( "utils/drawer.zig" );

pub const getScreenWidth      = drawer.getScreenWidth;
pub const getScreenHeight     = drawer.getScreenHeight;
pub const getScreenSize       = drawer.getScreenSize;

pub const drawText            = drawer.drawText;
pub const drawCenteredText    = drawer.drawCenteredText;

pub const drawTexture         = drawer.drawTexture;
pub const drawTextureCentered = drawer.drawTextureCentered;


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
pub const Vec2math           = @import( "utils/vec2math.zig" );

pub const Vec2               = Vec2math.Vec2;
pub const newVec2            = Vec2math.newVec2;

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

// NOTE : Radian version shortcuts only
pub const rotVec2            = Vec2math.rotVec2Rad;
pub const getVec2Angle       = Vec2math.getVec2AngleRad;
pub const getVec2AngleDist   = Vec2math.getVec2AngleDistRad;

pub const getScaledVec2Deg   = Vec2math.getScaledVec2Deg;
pub const getScaledVec2Rad   = Vec2math.getScaledVec2Rad;
pub const getScaledPolyVerts = Vec2math.getScaledPolyVerts;


// ======== VecR ========
pub const VecRmath         = @import( "utils/vecRmath.zig" );

pub const VecR             = VecRmath.VecR;
pub const newVecR          = VecRmath.newVecR;
pub const getRVal          = VecRmath.getRVal;

pub const normVecRUnit     = VecRmath.normVecRUnit;
pub const normVecRLen      = VecRmath.normVecRLen;

pub const addVecR          = VecRmath.addVecR;
pub const subVecR          = VecRmath.subVecR;
pub const mulVecR          = VecRmath.mulVecR;
pub const divVecR          = VecRmath.divVecR;

pub const getVecRDist      = VecRmath.getVecRDist;
pub const getVecRCartDist  = VecRmath.getVecRCartDist;
pub const getVecRSqrDist   = VecRmath.getVecRSqrDist;

pub const getVecRDistX     = VecRmath.getVecRDistX;
pub const getVecRDistY     = VecRmath.getVecRDistY;
pub const getVecRDistR     = VecRmath.getVecRDistR;

// NOTE : Radian version shortcuts only
pub const rotVecR          = VecRmath.rotVecR;
pub const getVecRAngle     = VecRmath.getVecRAngleRad;
pub const getVecRAngleDist = VecRmath.getVecRAngleDistRad;

pub const getScaledVecRDeg = VecRmath.getScaledVecRDeg;
pub const getScaledVecRRad = VecRmath.getScaledVecRRad;


// ======== Vec3 ========
pub const Vec3math      = @import( "utils/vec3math.zig" );

pub const Vec3          = Vec3math.Vec3;
pub const newVec3       = Vec3math.newVec3;

pub const normVec3Unit  = Vec3math.normVec3Unit;
pub const normVec3Len   = Vec3math.normVec3Len;

pub const addVec3       = Vec3math.addVec3;
pub const subVec3       = Vec3math.subVec3;
pub const mulVec3       = Vec3math.mulVec3;
pub const divVec3       = Vec3math.divVec3;

pub const getDist       = Vec3math.getDist;
pub const getCartDist   = Vec3math.getCartDist;
pub const getSqrDist    = Vec3math.getSqrDist;

pub const getDistX      = Vec3math.getDistX;
pub const getDistY      = Vec3math.getDistY;
pub const getDistZ      = Vec3math.getDistZ;

pub const getDistXY     = Vec3math.getDistXY;
pub const getDistXZ     = Vec3math.getDistXZ;
pub const getDistYZ     = Vec3math.getDistYZ;

pub const getSqrDistXY  = Vec3math.getSqrDistXY;
pub const getSqrDistXZ  = Vec3math.getSqrDistXZ;
pub const getSqrDistYZ  = Vec3math.getSqrDistYZ;

pub const getCylnDistXY = Vec3math.getCylnDistXY;
pub const getCylnDistXZ = Vec3math.getCylnDistXZ;
pub const getCylnDistYZ = Vec3math.getCylnDistYZ;






