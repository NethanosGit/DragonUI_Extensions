-- DragonUI_Extensions: "Show on Target" visibility mode for DragonUI's unit frames and action bars.
--
-- When enabled for a frame or bar, it is shown while a target exists and hidden otherwise.
-- It is exclusive with DragonUI's "Show on Hover Only", "Show in Combat Only" and "Hide in Combat".
-- The option is set in the standalone window (/duiext, see ExtensionsWindow.lua).
--
-- Relies on DragonUI internals: _G.DragonUI, addon.VisibilityFade (Register / Update / Reset).
-- Nothing in DragonUI or DragonUI_Options is modified. The engine's rules are left untouched for
-- every other combination; this file only takes over an entry while "Show on Target" is the sole mode.

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

local function OtherModeOn(prefix)
    return FlagOn(prefix, "show_on_hover") or FlagOn(prefix, "show_in_combat") or FlagOn(prefix, "hide_in_combat")
end

-- ============================================================================
-- TRACK REGISTRATIONS
-- ============================================================================

local records = {} -- visibility key -> { frame, opts, prefix }

local origRegister = VF.Register
function VF.Register(key, frame, opts)
    origRegister(key, frame, opts)
    local prefix = PrefixOf(key)
    if prefix and frame and opts and opts.dbTable then
        records[key] = { frame = frame, opts = opts, prefix = prefix }
    end
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

local function UpdateTargetMode(key, rec, cfg)
    local shouldShow = (not cfg.always_hidden) and UnitExists("target") and true or false
    local shownAlpha = Clamp01(cfg.visibility_shown_alpha == nil and 1 or cfg.visibility_shown_alpha)
    local hiddenAlpha = Clamp01(cfg.visibility_hidden_alpha == nil and 0 or cfg.visibility_hidden_alpha)

    -- Reset stops any fade the engine still has running for this key, then snaps alpha.
    -- The engine is never asked to update this key while the mode is active, so it cannot fight us.
    VF.Reset(key, shouldShow and shownAlpha or hiddenAlpha)

    -- Click-through frames must not eat clicks while invisible.
    local opts = rec.opts
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
            if not OtherModeOn(rec.prefix) then
                return UpdateTargetMode(key, rec, cfg)
            end
            -- Another mode was switched on elsewhere. Drop the stale flag so this mode cannot
            -- come back on its own later.
            SetProfileValue(rec.prefix .. FLAG, false)
        end
    end
    return origUpdate(key)
end

-- Target gained or lost: re-evaluate only the entries in this mode (the engine handles the rest).
local targetEvents = CreateFrame("Frame")
targetEvents:RegisterEvent("PLAYER_TARGET_CHANGED")
targetEvents:SetScript("OnEvent", function()
    for key, rec in pairs(records) do
        if FlagOn(rec.prefix, FLAG) and not OtherModeOn(rec.prefix) then
            VF.Update(key)
        end
    end
end)

-- ============================================================================
-- PUBLIC API (used by ExtensionsWindow.lua)
-- ============================================================================

local EXT = _G.DragonUIExtensions or {}
_G.DragonUIExtensions = EXT

-- prefix: a settings prefix from the tables above, e.g. "unitframe.player." or "actionbars.main_".
function EXT.GetShowOnTarget(prefix)
    return FlagOn(prefix, FLAG)
end

-- Turning it on also turns off the other three visibility modes for that entry.
function EXT.SetShowOnTarget(prefix, value)
    if value then
        for _, name in ipairs({ "show_on_hover", "show_in_combat", "hide_in_combat" }) do
            SetProfileValue(prefix .. name, false)
        end
    end
    SetProfileValue(prefix .. FLAG, value and true or false)
    for key, rec in pairs(records) do
        if rec.prefix == prefix then VF.Update(key) end
    end
end
