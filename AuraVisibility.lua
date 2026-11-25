-- DragonUI_Extensions: hover / combat / target visibility for the player's auras (buffs, debuffs
-- and weapon enchants). Any checked condition shows them; with none checked they are always shown.
--
-- Registers the Blizzard aura frames with DragonUI's addon.VisibilityFade, so hover and combat are
-- the engine's, and "Show on Target" is handled by TargetVisibility.lua (load it first).

local DUI = _G.DragonUI
local EXT = _G.DragonUIExtensions
if not (DUI and DUI.VisibilityFade and EXT) then return end

local VF = DUI.VisibilityFade

local KEY = "playerauras"
local PREFIX = "extensions.auras." -- also listed for KEY in TargetVisibility.lua

local function GetConfig()
    if not (DUI.db and DUI.db.profile) then return nil end
    return {
        show_on_hover = EXT.GetProfileValue(PREFIX .. "show_on_hover") == true,
        show_in_combat = EXT.GetProfileValue(PREFIX .. "show_in_combat") == true,
        visibility_logic = "or",
    }
end

-- DragonUI's collapse/expand arrow. It has no global name and is created on entering the world.
local function GetToggleButton()
    local info = DUI.EditableFrames and DUI.EditableFrames.buffs
    return info and info.frame and info.frame.toggleButton
end

local hoverFrames = {} -- shared with the registration, so later additions are seen by both
local known = {}       -- frame -> true once collected

local function AddHover(frame)
    if not frame or known[frame] then return false end
    known[frame] = true
    table.insert(hoverFrames, frame)
    return true
end

-- Frames whose alpha is set. A frame parented under another one in the list inherits its alpha, and
-- setting both would multiply them.
local function CollectAlphaFrames()
    local candidates, listed = {}, {}
    for _, frame in pairs({ BuffFrame, TemporaryEnchantFrame, ConsolidatedBuffs, GetToggleButton() }) do
        candidates[#candidates + 1] = frame
        listed[frame] = true
    end

    local roots = {}
    for _, frame in ipairs(candidates) do
        local parent = frame:GetParent()
        while parent and not listed[parent] do
            parent = parent:GetParent()
        end
        if not parent and frame ~= BuffFrame then roots[#roots + 1] = frame end
    end
    return roots
end

local registeredToggle

-- Registers on the first call and again whenever an aura button or the arrow has appeared since.
local function Sync()
    if not BuffFrame then return end
    local changed = false

    -- Aura buttons are created by Blizzard the first time each slot is used.
    for _, group in ipairs({ { "BuffButton", 40 }, { "DebuffButton", 40 }, { "TempEnchant", 3 } }) do
        for i = 1, group[2] do
            if AddHover(_G[group[1] .. i]) then changed = true end
        end
    end
    if AddHover(ConsolidatedBuffs) then changed = true end
    if AddHover(_G.ConsolidatedBuffsTooltip) then changed = true end

    local toggle = GetToggleButton()
    if AddHover(toggle) then changed = true end
    if toggle ~= registeredToggle then changed = true end

    if not changed then return end
    registeredToggle = toggle

    VF.Register(KEY, BuffFrame, {
        frames = CollectAlphaFrames(),
        hoverFrames = hoverFrames,
        enableMouse = false,
        -- Invisible auras must not show tooltips or be cancelled by a right click.
        clickThrough = true,
        mouseSafeInCombat = true,
        dbTable = GetConfig,
    })
    VF.Update(KEY)
end

hooksecurefunc("AuraButton_Update", function(buttonName, index)
    local button = _G[buttonName .. index]
    if button and not known[button] then Sync() end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        if DUI.db and DUI.db.RegisterCallback then
            local owner = {}
            local function Refresh() VF.Update(KEY) end
            DUI.db.RegisterCallback(owner, "OnProfileChanged", Refresh)
            DUI.db.RegisterCallback(owner, "OnProfileCopied", Refresh)
            DUI.db.RegisterCallback(owner, "OnProfileReset", Refresh)
        end
        return
    end
    Sync()
    VF.Update(KEY)
end)

-- ============================================================================
-- PUBLIC API (used by ExtensionsWindow.lua)
-- ============================================================================

EXT.AURA_PREFIX = PREFIX

-- name: "show_on_hover" or "show_in_combat". Show on Target uses EXT.SetShowOnTarget(AURA_PREFIX).
function EXT.GetAuraMode(name)
    return EXT.GetProfileValue(PREFIX .. name) == true
end

function EXT.SetAuraMode(name, value)
    EXT.SetProfileValue(PREFIX .. name, value and true or false)
    Sync()
    VF.Update(KEY)
end
