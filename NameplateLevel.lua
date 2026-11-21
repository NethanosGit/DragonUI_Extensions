-- DragonUI_Extensions: level position for nameplates.
--
-- DragonUI draws the level as a prefix inside the name text, "[70] Name". This file adds a
-- placement setting: beforeName keeps DragonUI's layout, while outsideLeft and outsideRight take
-- the level out of the name and draw it beside the health bar. Nothing in DragonUI is edited.
--
-- Relies on DragonUI internals: DragonUI.Nameplates.discovery.FormatPlateName (which builds the
-- "|cffRRGGBB[70]|r Name" string), DragonUI.Nameplates.gather.SyncName, and layout.SafeSetFont.
-- The setting is stored as modules.nameplates.levelPlacement in DragonUI's profile.

local DUI = _G.DragonUI
if not (DUI and DUI.Nameplates and DUI.Nameplates.discovery
        and DUI.Nameplates.gather and DUI.Nameplates.layout) then
    return
end

local NP = DUI.Nameplates
local EXT = _G.DragonUIExtensions or {}
_G.DragonUIExtensions = EXT

local PLACEMENTS = { beforeName = true, outsideLeft = true, outsideRight = true }
local DEFAULT_PLACEMENT = "beforeName"
local GAP = 4

local function NameplateProfile()
    return DUI.db and DUI.db.profile and DUI.db.profile.modules and DUI.db.profile.modules.nameplates
end

function EXT.GetLevelPlacement()
    local node = NameplateProfile()
    local value = node and node.levelPlacement
    if PLACEMENTS[value] then return value end
    return DEFAULT_PLACEMENT
end

function EXT.SetLevelPlacement(value)
    local profile = DUI.db and DUI.db.profile
    if not profile then return end
    if not PLACEMENTS[value] then value = DEFAULT_PLACEMENT end
    profile.modules = profile.modules or {}
    profile.modules.nameplates = profile.modules.nameplates or {}
    profile.modules.nameplates.levelPlacement = value
    if DUI.RefreshNameplates then
        DUI:RefreshNameplates()
    end
end

-- Outline / shadow style of the level text drawn outside the bar.
local STYLES = { outline = true, shadow = true, both = true }
local DEFAULT_STYLE = "shadow"
local levelPlates = setmetatable({}, { __mode = "k" })

function EXT.GetLevelStyle()
    local node = NameplateProfile()
    local value = node and node.extLevelStyle
    if STYLES[value] then return value end
    return DEFAULT_STYLE
end

function EXT.SetLevelStyle(value)
    local profile = DUI.db and DUI.db.profile
    if not profile then return end
    if not STYLES[value] then value = DEFAULT_STYLE end
    profile.modules = profile.modules or {}
    profile.modules.nameplates = profile.modules.nameplates or {}
    profile.modules.nameplates.extLevelStyle = value
    -- Force the font pass to run again on plates already on screen.
    for plateData in pairs(levelPlates) do
        plateData._extLevelFontKey = nil
        if plateData._extLevelFS and plateData.minaName then
            local path, size = plateData.minaName:GetFont()
            if path then
                local outline = (value == "outline" or value == "both")
                local shadow = (value == "shadow" or value == "both")
                NP.layout.SafeSetFont(plateData._extLevelFS, path, size, outline and "OUTLINE" or "")
                plateData._extLevelFS:SetShadowOffset(1, -1)
                plateData._extLevelFS:SetShadowColor(0, 0, 0, shadow and 1 or 0)
            end
        end
    end
    if DUI.RefreshNameplates then
        DUI:RefreshNameplates()
    end
end

-- ============================================================================
-- NAME TEXT: take the level prefix out of the name when it is drawn outside the bar
-- ============================================================================

local origFormat = NP.discovery.FormatPlateName
function NP.discovery.FormatPlateName(plateData, unit, levelOverride)
    local text = origFormat(plateData, unit, levelOverride)
    if not plateData or EXT.GetLevelPlacement() == "beforeName" then
        return text
    end
    -- DragonUI's prefix is "|cffRRGGBB<level>|r <name>". The level has no "|r" in it, so the first
    -- "|r " is the end of the prefix.
    local hex, levelText, rest = string.match(text, "^|cff(%x%x%x%x%x%x)(.-)|r (.*)$")
    if not hex then
        return text
    end
    plateData._extLevel = { hex = hex, text = levelText }
    return rest
end

-- ============================================================================
-- LEVEL TEXT: a font string on the health bar, outside its left or right edge
-- ============================================================================

local function HideLevelText(plateData)
    if plateData._extLevelFS then
        plateData._extLevelFS:Hide()
    end
end

local function UpdateLevelText(plateData)
    local info = plateData._extLevel
    local placement = EXT.GetLevelPlacement()
    local hp, name = plateData.minaHp, plateData.minaName
    if not info or placement == "beforeName" or not hp or not name then
        HideLevelText(plateData)
        return
    end

    local fs = plateData._extLevelFS
    if not fs then
        fs = hp:CreateFontString(nil, "OVERLAY")
        plateData._extLevelFS = fs
    end

    -- Same font and size as the name; the outline and shadow follow the Style setting.
    local path, size = name:GetFont()
    if path then
        local style = EXT.GetLevelStyle()
        local key = path .. "|" .. tostring(size) .. "|" .. style
        if plateData._extLevelFontKey ~= key then
            plateData._extLevelFontKey = key
            local outline = (style == "outline" or style == "both")
            local shadow = (style == "shadow" or style == "both")
            NP.layout.SafeSetFont(fs, path, size, outline and "OUTLINE" or "")
            fs:SetShadowOffset(1, -1)
            fs:SetShadowColor(0, 0, 0, shadow and 1 or 0)
        end
    end
    levelPlates[plateData] = true

    if plateData._extLevelPlacement ~= placement then
        plateData._extLevelPlacement = placement
        fs:ClearAllPoints()
        if placement == "outsideLeft" then
            fs:SetJustifyH("RIGHT")
            fs:SetPoint("RIGHT", hp, "LEFT", -GAP, 0)
        else
            fs:SetJustifyH("LEFT")
            fs:SetPoint("LEFT", hp, "RIGHT", GAP, 0)
        end
    end

    if plateData._extLevelText ~= info.text then
        plateData._extLevelText = info.text
        fs:SetText(info.text)
    end
    if plateData._extLevelHex ~= info.hex then
        plateData._extLevelHex = info.hex
        local r = tonumber(info.hex:sub(1, 2), 16) / 255
        local g = tonumber(info.hex:sub(3, 4), 16) / 255
        local b = tonumber(info.hex:sub(5, 6), 16) / 255
        fs:SetTextColor(r, g, b)
    end
    fs:Show()
end

local origSync = NP.gather.SyncName
function NP.gather.SyncName(plateData, unit)
    if plateData then
        plateData._extLevel = nil
    end
    origSync(plateData, unit)
    if plateData then
        UpdateLevelText(plateData)
    end
end
