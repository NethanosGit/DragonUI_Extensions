-- DragonUI_Extensions: health text font size for nameplates, with no style restrictions.
--
-- DragonUI_Options locks this slider in the Modern style and when the name sits after the health
-- text, and DragonUI sizes Modern health text like the name. This file gives the setting its own
-- effect in every style, by wrapping the nameplate font pass. Nothing in DragonUI is edited.
--
-- Relies on DragonUI internals: DragonUI.Nameplates.layout (ApplyNameplateFonts, SafeSetFont).
-- The size is stored in DragonUI's profile as modules.nameplates.healthNumberFontSize, the same key
-- DragonUI reads, so the value is shared with DragonUI_Options.

local DUI = _G.DragonUI
if not (DUI and DUI.Nameplates and DUI.Nameplates.layout) then return end

local LAYOUT = DUI.Nameplates.layout
if type(LAYOUT.ApplyNameplateFonts) ~= "function" or type(LAYOUT.SafeSetFont) ~= "function" then
    return
end

local EXT = _G.DragonUIExtensions or {}
_G.DragonUIExtensions = EXT

local DEFAULT_SIZE = 2
local MIN_SIZE, MAX_SIZE = -3, 10

local function ClampSize(value)
    value = math.floor((tonumber(value) or DEFAULT_SIZE) + 0.5)
    if value < MIN_SIZE then return MIN_SIZE end
    if value > MAX_SIZE then return MAX_SIZE end
    return value
end

local function NameplateProfile()
    return DUI.db and DUI.db.profile and DUI.db.profile.modules and DUI.db.profile.modules.nameplates
end

function EXT.GetHealthTextSize()
    local node = NameplateProfile()
    return ClampSize(node and node.healthNumberFontSize)
end

function EXT.SetHealthTextSize(value)
    local profile = DUI.db and DUI.db.profile
    if not profile then return end
    profile.modules = profile.modules or {}
    profile.modules.nameplates = profile.modules.nameplates or {}
    profile.modules.nameplates.healthNumberFontSize = ClampSize(value)
    if DUI.RefreshNameplates then
        DUI:RefreshNameplates()
    end
end

function EXT.GetHealthStyle()
    local node = NameplateProfile()
    return EXT.NormalizeTextStyle and EXT.NormalizeTextStyle(node and node.extHealthStyle) or "shadow"
end

function EXT.SetHealthStyle(value)
    local profile = DUI.db and DUI.db.profile
    if not profile then return end
    profile.modules = profile.modules or {}
    profile.modules.nameplates = profile.modules.nameplates or {}
    profile.modules.nameplates.extHealthStyle = EXT.NormalizeTextStyle(value)
    if DUI.RefreshNameplates then
        DUI:RefreshNameplates()
    end
end

-- The core sizes the health text as 7 + the setting in Heritage, and as the name in Modern.
-- Re-apply the health text size after the core's pass, keeping the font path and outline it chose.
local origApply = LAYOUT.ApplyNameplateFonts
function LAYOUT.ApplyNameplateFonts(plateData)
    origApply(plateData)
    local px = 7 + EXT.GetHealthTextSize()
    for _, key in ipairs({ "minaHpNum", "minaHpBarPct" }) do
        local fs = plateData and plateData[key]
        if fs and fs.GetFont then
            local path, _, flags = fs:GetFont()
            if path then
                LAYOUT.SafeSetFont(fs, path, px, flags)
            end
        end
    end
    -- Outline / shadow style, on every health text.
    local style = EXT.GetHealthStyle()
    for _, key in ipairs({ "minaHpNum", "minaHpBarPct", "minaHpPct" }) do
        EXT.ApplyTextStyle(plateData and plateData[key], style, LAYOUT.SafeSetFont)
    end
end
