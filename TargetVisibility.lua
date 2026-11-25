-- DragonUI_Extensions: "Show on Target" visibility mode for DragonUI's unit frames and action bars.
--
-- When enabled for a frame or bar, it is shown while a target exists. It combines with DragonUI's
-- "Show on Hover Only" and "Show in Combat Only": any one of the conditions shows the entry.
-- It is exclusive with "Hide in Combat".
-- The option is set in the standalone window (/duiext, see ExtensionsWindow.lua).
--
-- Relies on DragonUI internals: _G.DragonUI, addon.VisibilityFade (Register / Update / Reset).
-- Nothing in DragonUI or DragonUI_Options is modified. While "Show on Target" is on, this file
-- shows the entry itself when there is a target (or no other mode is set) and otherwise leaves
-- hover/combat to the engine, with its AND/OR logic read as OR.

local DUI = _G.DragonUI
if not (DUI and DUI.VisibilityFade) then return end

local VF = DUI.VisibilityFade

local FLAG = "show_on_target"

-- Visibility key (as passed to VF.Register) -> DragonUI profile prefix of its settings.
-- Flags are read as prefix .. name, e.g. "unitframe.player." .. "show_on_hover".
local UNIT_PREFIX = {
    player = "unitframe.player.",
    target = "unitframe.target.",
    focus  = "unitframe.focus.",
    pet    = "unitframe.pet.",
    boss   = "unitframe.boss.", -- boss1..boss5 share it
}

local BAR_PREFIX = {
    main         = "actionbars.main_",
    bottom_left  = "actionbars.bottom_left_",
    bottom_right = "actionbars.bottom_right_",
    right        = "actionbars.right_",
    left         = "actionbars.left_",
    -- Additional bars keep their settings in their own table, not in actionbars.
    stancebar    = "additional.stance.",
    petbar       = "additional.pet.",
    totembar     = "additional.totem.",
    extrabar1    = "additional.extrabar1.",
    -- XP and Rep share one config table.
    xprepbar     = "xprepbar.",
    -- Registered by AuraVisibility.lua.
    playerauras  = "extensions.auras.",
}

local function PrefixOf(key)
    if UNIT_PREFIX[key] then return UNIT_PREFIX[key] end
    if string.match(key, "^boss%d+$") then return UNIT_PREFIX.boss end
    return BAR_PREFIX[key]
end

-- Reads and writes DragonUI's profile, the same table its own options use.
local function GetProfileValue(path)
    local node = DUI.db and DUI.db.profile
    if not node then return nil end
    for key in string.gmatch(path, "[^%.]+") do
        if type(node) ~= "table" then return nil end
        node = node[key]
    end
    return node
end

local function SetProfileValue(path, value)
    local profile = DUI.db and DUI.db.profile
    if not profile then return end
    local keys = { strsplit(".", path) }
    local node = profile
    for i = 1, #keys - 1 do
        if type(node[keys[i]]) ~= "table" then node[keys[i]] = {} end
        node = node[keys[i]]
    end
    node[keys[#keys]] = value
end

local function FlagOn(prefix, name)
    return GetProfileValue(prefix .. name) == true
end

local function HoverOrCombatOn(prefix)
    return FlagOn(prefix, "show_on_hover") or FlagOn(prefix, "show_in_combat")
end

local function TargetModeOn(prefix)
    return FlagOn(prefix, FLAG) and not FlagOn(prefix, "hide_in_combat")
end

-- ============================================================================
-- TRACK REGISTRATIONS
-- ============================================================================

local records = {} -- visibility key -> { frame, opts, prefix }

local origRegister = VF.Register
function VF.Register(key, frame, opts)
    local prefix = PrefixOf(key)
    if not (prefix and frame and opts and opts.dbTable) then
        return origRegister(key, frame, opts)
    end

    -- The engine gets a copy of opts whose config reads the hover/combat logic as OR while target
    -- mode is on. The config is copied too, since it can be DragonUI's own profile table.
    local wrapped = {}
    for k, v in pairs(opts) do wrapped[k] = v end
    local dbTable = opts.dbTable
    wrapped.dbTable = function()
        local cfg = dbTable()
        if not (cfg and TargetModeOn(prefix)) then return cfg end
        local copy = {}
        for k, v in pairs(cfg) do copy[k] = v end
        copy.visibility_logic = "or"
        return copy
    end

    origRegister(key, frame, wrapped)
    records[key] = { frame = frame, opts = opts, prefix = prefix }
end

-- ============================================================================
-- VISIBILITY
-- ============================================================================

local function Clamp01(value)
    value = tonumber(value) or 0
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local FADE_PATH = "extensions.target_fade_duration"
local FADE_DEFAULT = 0.35
local FADE_LIMITS = { min = 0, max = 2, step = 0.05 }

-- Seconds, used for both fade-in and fade-out. 0 snaps with no animation.
local function GetFadeDuration()
    local v = tonumber(GetProfileValue(FADE_PATH))
    if not v then return FADE_DEFAULT end
    return math.min(FADE_LIMITS.max, math.max(FADE_LIMITS.min, v))
end

local fadeDrivers = {} -- visibility key -> frame running the OnUpdate fade

local function SetAlphaAll(rec, alpha)
    rec.frame:SetAlpha(alpha)
    if rec.opts.frames then
        for _, f in ipairs(rec.opts.frames) do
            if f then f:SetAlpha(alpha) end
        end
    end
end

local function FadeTo(key, rec, targetAlpha)
    local driver = fadeDrivers[key]
    if not driver then
        driver = CreateFrame("Frame")
        fadeDrivers[key] = driver
    end
    driver:SetScript("OnUpdate", nil)

    local duration = GetFadeDuration()
    local fromAlpha = rec.frame:GetAlpha() or 1
    if duration <= 0 or math.abs(fromAlpha - targetAlpha) <= 0.01 then
        SetAlphaAll(rec, targetAlpha)
        return
    end

    local elapsed = 0
    driver:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        local progress = elapsed / duration
        if progress >= 1 then
            self:SetScript("OnUpdate", nil)
            SetAlphaAll(rec, targetAlpha)
        else
            SetAlphaAll(rec, fromAlpha + (targetAlpha - fromAlpha) * progress)
        end
    end)
end

local function UpdateTargetMode(key, rec, cfg)
    local shouldShow = (not cfg.always_hidden) and UnitExists("target") and true or false
    local shownAlpha = Clamp01(cfg.visibility_shown_alpha == nil and 1 or cfg.visibility_shown_alpha)
    local hiddenAlpha = Clamp01(cfg.visibility_hidden_alpha == nil and 0 or cfg.visibility_hidden_alpha)

    -- Reset stops any fade the engine still has running for this key (holding the current alpha so
    -- nothing jumps); our own 0.5s fade then takes over. The engine is never asked to update this
    -- key while the mode is active, so it cannot fight us.
    VF.Reset(key, rec.frame:GetAlpha() or 1)
    local opts = rec.opts
    -- The main bar uses this to bring its buttons back, as the engine does on every reveal.
    if shouldShow and opts.onVisibilityChange then opts.onVisibilityChange(true) end
    FadeTo(key, rec, shouldShow and shownAlpha or hiddenAlpha)

    -- Click-through frames must not eat clicks while invisible.
    if opts.clickThrough then
        local inCombat = InCombatLockdown()
        for _, f in ipairs(opts.hoverFrames or { rec.frame }) do
            if f and f ~= opts.noMouseFrame and f.EnableMouse and not (inCombat and f:IsProtected()) then
                pcall(f.EnableMouse, f, shouldShow)
            end
        end
    end
end

local origUpdate = VF.Update
function VF.Update(key)
    local rec = records[key]
    if rec and FlagOn(rec.prefix, FLAG) then
        -- Some bars return no config while disabled; those are left to the engine.
        local cfg = rec.opts.dbTable and rec.opts.dbTable()
        if cfg then
            if FlagOn(rec.prefix, "hide_in_combat") then
                -- Switched on elsewhere. Drop the stale flag so this mode cannot come back on
                -- its own later.
                SetProfileValue(rec.prefix .. FLAG, false)
            elseif UnitExists("target") or not HoverOrCombatOn(rec.prefix) then
                return UpdateTargetMode(key, rec, cfg)
            end
        end
    end
    -- Hover/combat decide (no target, or target mode off): stop our fade so it cannot fight the
    -- engine's.
    if fadeDrivers[key] then fadeDrivers[key]:SetScript("OnUpdate", nil) end
    return origUpdate(key)
end

-- Target gained or lost: re-evaluate only the entries in this mode (the engine handles the rest).
local targetEvents = CreateFrame("Frame")
targetEvents:RegisterEvent("PLAYER_TARGET_CHANGED")
targetEvents:SetScript("OnEvent", function()
    for key, rec in pairs(records) do
        if TargetModeOn(rec.prefix) then
            VF.Update(key)
        end
    end
end)

-- ============================================================================
-- PUBLIC API (used by ExtensionsWindow.lua)
-- ============================================================================

local EXT = _G.DragonUIExtensions or {}
_G.DragonUIExtensions = EXT

EXT.GetProfileValue = GetProfileValue
EXT.SetProfileValue = SetProfileValue

-- prefix: a settings prefix from the tables above, e.g. "unitframe.player." or "actionbars.main_".
function EXT.GetShowOnTarget(prefix)
    return FlagOn(prefix, FLAG)
end

EXT.TARGET_FADE_LIMITS = FADE_LIMITS

function EXT.GetTargetFadeDuration()
    return GetFadeDuration()
end

function EXT.SetTargetFadeDuration(value)
    value = tonumber(value) or FADE_DEFAULT
    -- Snap to the step in whole hundredths so float error (0.35000000000000003) never gets stored.
    value = math.floor(value * 100 / (FADE_LIMITS.step * 100) + 0.5) * (FADE_LIMITS.step * 100) / 100
    SetProfileValue(FADE_PATH, math.min(FADE_LIMITS.max, math.max(FADE_LIMITS.min, value)))
end

-- Turning it on also turns off "Hide in Combat" for that entry; hover and combat are kept.
function EXT.SetShowOnTarget(prefix, value)
    if value then
        SetProfileValue(prefix .. "hide_in_combat", false)
    end
    SetProfileValue(prefix .. FLAG, value and true or false)
    for key, rec in pairs(records) do
        if rec.prefix == prefix then VF.Update(key) end
    end
end
