pub const std = @import( "std" );
pub const ray = @import( "raylib" );

pub const tcl_u  = @import( "utils/termColourer.zig" );
pub const rng_u  = @import( "utils/rng.zig" );

pub var G_RNG : rng_u.randomiser = .{};

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
pub var   G_NG : Engine = .{}; // NOTE : Global game engine instance


// ================ MANAGERS ================

pub const res_m = @import( "core/system/resourceManager.zig" );
pub const ntt_m = @import( "core/system/entityManager.zig" );
pub const tlm_m = @import( "core/system/tilemapManager.zig" );


// ================ ENTITY ================

pub const ntt         = @import( "core/entity/entityCore.zig" );
pub const Entity      = ntt.Entity;

pub const e_ntt_flags = ntt.e_ntt_flags;
pub const e_ntt_shape = ntt.e_ntt_shape;


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


// ================================ UTILS SHORTHANDS ================================

// ================ ANGLER SHORTHANDS ================================

pub const ngl_u = @import( "utils/angler.zig" );

pub const Angle = ngl_u.Angle;


// ================ BOXER SHORTHANDS ================

pub const RayRect = ray.Rectangle;

pub const box2_u = @import( "utils/boxer2.zig" );

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


// ================ CAMER SHORTHANDS ================

pub const cmr_u  = @import( "utils/camer.zig" );

pub const RayCam = cmr_u.RayCam;
pub const Cam2D  = cmr_u.Cam2D;

pub const getScreenWidth      = cmr_u.getScreenWidth;
pub const getScreenHeight     = cmr_u.getScreenHeight;
pub const getScreenSize       = cmr_u.getScreenSize;

pub const getHalfScreenWidth  = cmr_u.getHalfScreenWidth;
pub const getHalfScreenHeight = cmr_u.getHalfScreenHeight;
pub const getHalfScreenSize   = cmr_u.getHalfScreenSize;

pub const getMouseScreenPos   = cmr_u.getMouseScreenPos;
pub const getMouseWorldPos    = cmr_u.getMouseWorldPos;


// ================ COLOUR SHORTHANDS ================

pub const RayCol  = ray.Color;

pub fn newRayCol( r : u8, g : u8, b : u8, a : ?u8 ) RayCol
{
  if( a )| alpha | { return RayCol{ .r = r, .g = g, .b = b, .a = alpha }; }
  else             { return RayCol{ .r = r, .g = g, .b = b, .a = 255   }; }
}

pub const col_u   = @import( "utils/colourer.zig" );

pub const Colour  = col_u.Colour;

// ================ COORDS SHORTHANDS ================

pub const cor2_u  = @import( "utils/coorder2.zig" );

pub const e_dir_2 = cor2_u.e_dir_2;
pub const Coords2 = cor2_u.Coords2;


pub const cor3_u  = @import( "utils/coorder3.zig" );

pub const e_dir_3 = cor3_u.e_dir_3;
pub const Coords3 = cor3_u.Coords3;


// ================ DRAWER SHORTHANDS ================

pub const drw_u                    = @import( "utils/drawer.zig" );

pub const getDefaultFont           = drw_u.getDefaultFont;
pub const setDefaultFont           = drw_u.setDefaultFont;

pub const coverScreenWithCol       = drw_u.coverScreenWithCol;

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

pub const drawTria                 = drw_u.drawTrianglePlus;
pub const drawDiam                 = drw_u.drawDiamondPlus;
pub const drawPent                 = drw_u.drawPentagonPlus;
pub const drawHexa                 = drw_u.drawHexagonPlus;

pub const drawRect                 = drw_u.drawRectanglePlus;
pub const drawElli                 = drw_u.drawEllipsePlus;
pub const drawPoly                 = drw_u.drawPolygonPlus;

pub const drawHstr                 = drw_u.drawHexStarPlus;
pub const drawDstr                 = drw_u.drawOctStarPlus;

pub const drawText                 = drw_u.drawText;
pub const drawTextFmt              = drw_u.drawTextFmt;
pub const drawCenteredText         = drw_u.drawCenteredText;
pub const drawCenteredTextFmt      = drw_u.drawCenteredTextFmt;

pub const drawTexture              = drw_u.drawTexture;
pub const drawTextureCentered      = drw_u.drawTextureCentered;


// ================ FLAGGER SHORTHANDS ================

pub const flg_u = @import( "utils/flagger.zig" );

pub const BitField8  = flg_u.BitField8;
pub const BitField16 = flg_u.BitField16;
pub const BitField32 = flg_u.BitField32;
pub const BitField64 = flg_u.BitField64;


// ================ LOGGER SHORTHANDS ================

pub const log_u = @import( "utils/logger.zig" );

pub const log   = log_u.log;  // for argument-formatting logging
pub const qlog  = log_u.qlog; // for quick logging ( no args )

pub const resetTmpTimer = log_u.resetTmpTimer;
pub const logTmpTimer   = log_u.logTmpTimer;


// ================ MATHER SHORTHANDS ================

pub const mth_u  = @import( "utils/mather.zig" );

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

pub const sign   = mth_u.sign;

pub const lerp   = mth_u.lerp;
pub const med3   = mth_u.med3;
pub const clmp   = mth_u.clmp;
pub const wrap   = mth_u.wrap;

pub const norm   = mth_u.norm;
pub const denorm = mth_u.denorm;
pub const renorm = mth_u.renorm;

pub const getPolyCircum = mth_u.getPolyCircum;
pub const getPolyArea   = mth_u.getPolyArea;


// ================ SHAKER SHORTHANDS ================

pub const shk_u    = @import( "utils/shaker2.zig" );

pub const Shaker2D = shk_u.Shake2D;


// ================ SHAKER SHORTHANDS ================

pub const spm_u    = @import( "utils/spritemap.zig" );

pub const Spritemap = spm_u.Spritemap;

// ================ TIMER SHORTHANDS ================

pub const tmr_u         = @import( "utils/timer.zig" );

pub const TimeVal       = tmr_u.TimeVal;
pub const Timer         = tmr_u.Timer;
pub const e_timer_flags = tmr_u.e_timer_flags;

pub const getNow        = tmr_u.getNow;


// ================ VECTER SHORTHANDS ================

pub const RayVec2 = ray.Vector2;
pub const RayVec3 = ray.Vector3;
pub const RayVec4 = ray.Vector4;

pub const zeroRayVec2 = RayVec2{ .x = 0, .y = 0 };
pub const zeroRayVec3 = RayVec3{ .x = 0, .y = 0, .z = 0 };
pub const zeroRayVec4 = RayVec4{ .x = 0, .y = 0, .z = 0, .w = 0 };


pub const vec2_u = @import( "utils/vecter2.zig" );
pub const Vec2   = vec2_u.Vec2;

pub const vecA_u = @import( "utils/vecterA.zig" );
pub const VecA   = vecA_u.VecA;

pub const vec3_u = @import( "utils/vecter3.zig" );
pub const Vec3   = vec3_u.Vec3;


// ================= OTHER RAYLIB SHORTHANDS ================

pub const Texture = ray.Texture2D;


