pub const std = @import( "std" );
pub const ray = @import( "raylib" );

pub const col    = @import( "utils/colour.zig" );
pub const rng    = @import( "utils/rng.zig" );
pub const timer  = @import( "utils/timer.zig" );


// ================================ CORE ENGINE MODULES ================================

// ================ GAME HOOK SYSTEM ================
pub const ghm = @import( "core/gameHookManager.zig" );
pub var G_HK : ghm.gameHooks = .{}; // NOTE : Global gameHooks struct instance

pub fn initHooks( module : anytype ) void { G_HK.initHooks( module ); }
pub fn tryHook( tag : ghm.hookTag, args : anytype ) void { G_HK.tryHook( tag, args ); }


// ================ ENGINE & MANAGERS ================
pub const eng = @import( "core/engine.zig" );
pub var G_NG : eng.engine = .{}; // NOTE : Global game engine instance

pub const rsm = @import( "core/resourceManager.zig" );
pub const ntm = @import( "core/entityManager.zig" );


// ================ ENTITY SYSTEM ================
pub const ntt = @import( "core/entity/entityCore.zig" );


// ================================ SHORTHANDS ================================
// These are shorthand imports for commonly used modules in the project.

pub const alloc = std.heap.smp_allocator;


// ================ DRAWER SHORTHANDS ================
pub const drawer = @import( "utils/drawer.zig" );

pub const getScreenWidth  = drawer.getScreenWidth;
pub const getScreenHeight = drawer.getScreenHeight;
pub const getScreenSize   = drawer.getScreenSize;

pub const drawText         = drawer.drawText;
pub const drawCenteredText = drawer.drawCenteredText;

pub const drawTexture         = drawer.drawTexture;
pub const drawTextureCentered = drawer.drawTextureCentered;


// ================ LOGGER SHORTHANDS ================
pub const logger = @import( "utils/logger.zig" );

pub const log  = logger.log;  // for argument-formatting logging
pub const qlog = logger.qlog; // for quick logging ( no args )

pub const setTmpTimer = logger.setTmpTimer;
pub const logTmpTimer = logger.logTmpTimer;


// ================ MATHER SHORTHANDS ================
pub const mather = @import( "utils/mather.zig" );

pub const atan2 = mather.atan2;
pub const DtR   = mather.DtR;
pub const RtD   = mather.RtD;

pub const lerp  = mather.lerp;
pub const med3  = mather.med3;
pub const clmp  = mather.clmp;

pub const norm   = mather.norm;
pub const denorm = mather.denorm;
pub const renorm = mather.renorm;


// =============== VECTOR SHORTHANDS ===============
pub const vector = @import( "utils/vector.zig" );
pub const vec2   = vector.vec2;

pub const addValToVec2 = vector.addValToVec2;
pub const subValToVec2 = vector.subValToVec2;
pub const mulVec2ByVal = vector.mulVec2ByVal;
pub const divVec2ByVal = vector.divVec2ByVal;
pub const normVec2Unit = vector.normVec2;
pub const normVec2Len  = vector.normVec2Len;

pub const addVec2 = vector.addVec2;
pub const subVec2 = vector.subVec2;
pub const mulVec2 = vector.mulVec2;
pub const divVec2 = vector.divVec2;

pub const rotVec2Deg        = vector.rotVec2Deg;
pub const rotVec2Rad        = vector.rotVec2Rad;
pub const getAngleToVec2Deg = vector.getAngleToVec2Deg;
pub const getAngleToVec2Rad = vector.getAngleToVec2Rad;
pub const getAngDistDeg     = vector.getAngDistDeg;
pub const getAngDistRad     = vector.getAngDistRad;

pub const getDistX    = vector.getDistX;
pub const getDistY    = vector.getDistY;
pub const getCartDist = vector.getCartDist;
pub const getDistance = vector.getDistance;
pub const getSqrDist  = vector.getSqrDist;

pub const getScaledVec2FromDeg = vector.getScaledVec2FromDeg;
pub const getScaledVec2FromRad = vector.getScaledVec2FromRad;
pub const getScaledPolyVerts   = vector.getScaledPolyVerts;