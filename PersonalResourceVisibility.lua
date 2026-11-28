-- DragonUI_Extensions: visibility conditions for DragonUI's Personal Resource Display: hover,
-- combat, target, eating/drinking, casting, heal over time, debuff and missing health.
-- Any checked condition shows it. "Target" means an enemy target here.
--
-- DragonUI's own "Visibility" setting only knows Always, In Combat and Hidden, and the module does
-- not use addon.VisibilityFade. So the conditions need DragonUI's setting on Always (the frame stays
-- shown) and this file fades it through its alpha. In Combat and Hidden, picked in DragonUI, win.
--
-- Relies on DragonUI internals: the global DragonUI_PersonalResourceFrame, which the module sets
-- the alpha of (opacity and its own fade), and the profile table "personalresource".
-- Load after TargetVisibility.lua (shared fade duration).

local DUI = _G.DragonUI
local EXT = _G.DragonUIExtensions
if not (DUI and EXT and EXT.GetTargetFadeDuration) then return end

local FRAME_NAME = "DragonUI_PersonalResourceFrame"
local PREFIX = "extensions.personalresource."
local MODES = {
    "show_on_hover", "show_in_combat", "show_on_target",
    "show_while_eating", "show_while_casting", "show_with_hot", "show_with_debuff",
    "show_when_injured",
}

-- Auras are matched by name, which covers every rank and any client language. The names come from
-- one spell ID each.
local FOOD_SPELLS = {
    433,    -- Food
    430,    -- Drink
    44166,  -- Refreshment (conjured and feast food)
}
local HOT_SPELLS = {
    774,    -- Rejuvenation
    8936,   -- Regrowth
    33763,  -- Lifebloom
    48438,  -- Wild Growth
    22842,  -- Frenzied Regeneration
    139,    -- Renew
    64843,  -- Divine Hymn
    7001,   -- Lightwell Renew
    56161,  -- Glyph of Prayer of Healing
    61295,  -- Riptide
    51945,  -- Earthliving
    66922,  -- Flash of Light (Sacred Shield)
    54203,  -- Sheath of Light
    55694,  -- Enraged Regeneration
    29841,  -- Second Wind
    28880,  -- Gift of the Naaru
    45544,  -- First Aid (bandage)
}

local function SpellNames(ids)
    local names = {}
    for _, id in ipairs(ids) do
        local name = GetSpellInfo(id)
        if name then names[name] = true end
    end
    return names
end

local foodNames, hotNames = SpellNames(FOOD_SPELLS), SpellNames(HOT_SPELLS)

local function Visibility()
    local profile = DUI.db and DUI.db.profile
    local cfg = profile and profile.personalresource
    return cfg and cfg.visibility or "always"
end

local function Flags()
    local profile = DUI.db and DUI.db.profile
    local extensions = profile and profile.extensions
    return extensions and extensions.personalresource
end

-- ============================================================================
-- PLAYER AURAS
-- ============================================================================

-- Rescanned only after the player's auras change.
local aurasDirty = true
local eating, healing, debuffed = false, false, false

local function ScanAuras()
    aurasDirty = false
    eating, healing = false, false
    local index = 1
    local name = UnitBuff("player", index)
    while name do
        if foodNames[name] then eating = true end
        if hotNames[name] then healing = true end
        index = index + 1
        name = UnitBuff("player", index)
    end
    debuffed = UnitDebuff("player", 1) ~= nil
end

local auraWatcher = CreateFrame("Frame")
auraWatcher:RegisterEvent("UNIT_AURA")
auraWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
auraWatcher:SetScript("OnEvent", function(_, event, unit)
    if event ~= "UNIT_AURA" or unit == "player" then aurasDirty = true end
end)

local function ShouldShow(frame)
    if DUI.EditorMode and DUI.EditorMode:IsActive() then return true end
    -- In Combat and Hidden are handled by DragonUI itself.
    if Visibility() ~= "always" then return true end

    local flags = Flags()
    if not flags then return true end
    local any = false
    for _, mode in ipairs(MODES) do
        if flags[mode] then any = true break end
    end
    if not any then return true end

    if aurasDirty then ScanAuras() end
    local hover, combat, target = flags.show_on_hover, flags.show_in_combat, flags.show_on_target

    return (combat and UnitAffectingCombat("player"))
        -- Enemies only: anything you can attack, neutral units and duel opponents included.
        or (target and UnitCanAttack("player", "target"))
        or (hover and frame:IsMouseOver())
        or (flags.show_while_eating and eating)
        or (flags.show_while_casting and (UnitCastingInfo("player") or UnitChannelInfo("player")) and true)
        or (flags.show_with_hot and healing)
        or (flags.show_with_debuff and debuffed)
        or (flags.show_when_injured and UnitHealth("player") < UnitHealthMax("player"))
        or false
end

-- ============================================================================
-- ALPHA
-- ============================================================================

local content          -- DragonUI's frame, once it exists
local setAlpha         -- its original SetAlpha
local baseAlpha = 1    -- what DragonUI last asked for
local factor           -- 0-1, ours

-- DragonUI keeps setting the alpha (opacity, combat fade), so its value is stored and multiplied by
-- ours instead of being overwritten.
local function Attach(frame)
    content = frame
    setAlpha = frame.SetAlpha
    baseAlpha = frame:GetAlpha()
    frame.SetAlpha = function(self, alpha)
        baseAlpha = alpha
        setAlpha(self, alpha * (factor or 1))
    end
end

local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, elapsed)
    if not content then
        -- Created when the module is first enabled, which can be at any time.
        local frame = _G[FRAME_NAME]
        if not frame then return end
        Attach(frame)
    end

    local goal = ShouldShow(content) and 1 or 0
    if factor == goal then return end

    local duration = EXT.GetTargetFadeDuration()
    if not factor or duration <= 0 then
        factor = goal
    elseif goal > factor then
        factor = math.min(goal, factor + elapsed / duration)
    else
        factor = math.max(goal, factor - elapsed / duration)
    end
    setAlpha(content, baseAlpha * factor)
end)

-- ============================================================================
-- PUBLIC API (used by ExtensionsWindow.lua)
-- ============================================================================

-- name: one of MODES. DragonUI's "In Combat" counts as Show in Combat being on.
function EXT.GetPersonalResourceMode(name)
    local visibility = Visibility()
    if visibility == "combat" then return name == "show_in_combat" end
    if visibility ~= "always" then return false end
    return EXT.GetProfileValue(PREFIX .. name) == true
end

-- Changing a condition moves DragonUI's Visibility to Always, keeping what was in effect.
function EXT.SetPersonalResourceMode(name, value)
    local state = {}
    for _, mode in ipairs(MODES) do state[mode] = EXT.GetPersonalResourceMode(mode) end
    state[name] = value and true or false

    for _, mode in ipairs(MODES) do EXT.SetProfileValue(PREFIX .. mode, state[mode]) end
    EXT.SetProfileValue("personalresource.visibility", "always")
    if DUI.RefreshPersonalResource then DUI.RefreshPersonalResource() end
end
