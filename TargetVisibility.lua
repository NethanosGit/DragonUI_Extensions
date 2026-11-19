-- DragonUI_Extensions: "Show on Target" visibility mode for DragonUI's unit frames.
--
-- Adds a third option next to "Show on Hover Only" and "Show in Combat Only" in each unit
-- frame's Visibility group (editor mode). When enabled, the frame is shown while a target
-- exists and hidden otherwise. It is exclusive with the other two, like they are with each other.
--
-- Relies on DragonUI internals:
--   _G.DragonUI, addon.VisibilityFade (Register / Update / Reset) and addon.EditorSettings
--   (Get / GetDB / SetDB / IsLocked). The engine's own rules are left untouched for every
--   other combination; this file only takes over a key while "Show on Target" is the sole mode.

local DUI = _G.DragonUI
if not (DUI and DUI.VisibilityFade and DUI.EditorSettings) then return end

local VF = DUI.VisibilityFade
local E = DUI.EditorSettings

local FLAG = "show_on_target"
local OTHER_FLAGS = { "show_on_hover", "show_in_combat", "hide_in_combat" }

-- Visibility key (as passed to VF.Register) -> DragonUI profile root and editor frame name.
-- boss1..boss5 all share one root and one editor entry.
local UNITS = {
    player = { root = "unitframe.player", editor = "player" },
    target = { root = "unitframe.target", editor = "target" },
    focus  = { root = "unitframe.focus",  editor = "focus" },
    pet    = { root = "unitframe.pet",    editor = "PetFrame" },
    boss   = { root = "unitframe.boss",   editor = "boss" },
}

local function UnitOf(key)
    if UNITS[key] then return UNITS[key] end
    if string.match(key, "^boss%d+$") then return UNITS.boss end
    return nil
end

-- ============================================================================
-- TRACK REGISTRATIONS
-- ============================================================================

local records = {} -- visibility key -> { frame, opts, unit }

local origRegister = VF.Register
function VF.Register(key, frame, opts)
    origRegister(key, frame, opts)
    local unit = UnitOf(key)
    if unit and frame and opts and opts.dbTable then
        records[key] = { frame = frame, opts = opts, unit = unit }
    end
end

-- ============================================================================
-- VISIBILITY
-- ============================================================================

local function OtherModeOn(cfg)
    return cfg.show_on_hover or cfg.show_in_combat or cfg.hide_in_combat
end

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
    local cfg = rec and rec.opts.dbTable and rec.opts.dbTable()
    if cfg and cfg.show_on_target then
        if not OtherModeOn(cfg) then
            return UpdateTargetMode(key, rec, cfg)
        end
        -- Another mode was switched on in DragonUI's own rows. Drop the stale flag so this
        -- mode cannot come back on its own later.
        E.SetDB(rec.unit.root .. "." .. FLAG, false)
    end
    return origUpdate(key)
end

-- Target gained or lost: re-evaluate only the keys in this mode (the engine handles the rest).
local targetEvents = CreateFrame("Frame")
targetEvents:RegisterEvent("PLAYER_TARGET_CHANGED")
targetEvents:SetScript("OnEvent", function()
    for key, rec in pairs(records) do
        local cfg = rec.opts.dbTable and rec.opts.dbTable()
        if cfg and cfg.show_on_target and not OtherModeOn(cfg) then
            VF.Update(key)
        end
    end
end)

-- ============================================================================
-- EDITOR ROWS
-- ============================================================================

local function RefreshUnit(unit)
    for key, rec in pairs(records) do
        if rec.unit == unit then VF.Update(key) end
    end
end

local function MakeRow(unit)
    local path = unit.root .. "." .. FLAG
    return {
        type = "checkbox",
        key = path,
        label = "Show on Target",
        path = path,
        get = function()
            -- Shown as off while another mode owns the frame, matching what the engine does.
            return (E.GetDB(path) and not OtherModeOn({
                show_on_hover = E.GetDB(unit.root .. ".show_on_hover"),
                show_in_combat = E.GetDB(unit.root .. ".show_in_combat"),
                hide_in_combat = E.GetDB(unit.root .. ".hide_in_combat"),
            })) and true or false
        end,
        set = function(value)
            if E.IsLocked() then return end
            if value then
                for _, name in ipairs(OTHER_FLAGS) do
                    E.SetDB(unit.root .. "." .. name, false)
                end
            end
            E.SetDB(path, value and true or false)
            RefreshUnit(unit)
        end,
        disabled = function() return E.IsLocked() and true or false end,
        needsOverlayResize = false,
    }
end

local installed = {}
local function InstallRows()
    for _, unit in pairs(UNITS) do
        local def = E.Get(unit.editor)
        if def and not installed[unit.editor] then
            table.insert(def.settings, MakeRow(unit))
            installed[unit.editor] = true
        end
    end
end

-- The editor's Visibility rows are built by DragonUI at load; rows added here land after them,
-- so "Show on Target" sits in the same folded group, after "Hover/Combat Logic".
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
    InstallRows()
    self:UnregisterEvent("PLAYER_LOGIN")
end)
