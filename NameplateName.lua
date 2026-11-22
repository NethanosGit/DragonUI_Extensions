-- DragonUI_Extensions: name font size for nameplates, down to 0.5.
--
-- DragonUI_Options' Font Size slider stops at 1. DragonUI's own code takes any number here: the
-- name is drawn at 9 + fontSize, and the power text at 7 + fontSize. This file only lets the
-- setting go lower, so no DragonUI file is edited.
--
-- The value is stored as modules.nameplates.fontSize, the key DragonUI_Options uses.

local DUI = _G.DragonUI
if not (DUI and DUI.Nameplates and DUI.Nameplates.config) then return end

local EXT = _G.DragonUIExtensions or {}
_G.DragonUIExtensions = EXT

local DEFAULT_SIZE = 2
local MIN_SIZE, MAX_SIZE, STEP = -3, 10, 0.5

local function ClampSize(value)
    value = tonumber(value) or DEFAULT_SIZE
    -- Round to the nearest half so the stored value is exactly 0, 0.5, 1, ... with no float drift.
    value = math.floor(value * 2 + 0.5) / 2
    if value < MIN_SIZE then return MIN_SIZE end
    if value > MAX_SIZE then return MAX_SIZE end
    return value
end

local function NameplateProfile()
    return DUI.db and DUI.db.profile and DUI.db.profile.modules and DUI.db.profile.modules.nameplates
end

function EXT.GetNameSize()
    local node = NameplateProfile()
    return ClampSize(node and node.fontSize)
end

function EXT.SetNameSize(value)
    local profile = DUI.db and DUI.db.profile
    if not profile then return end
    profile.modules = profile.modules or {}
    profile.modules.nameplates = profile.modules.nameplates or {}
    profile.modules.nameplates.fontSize = ClampSize(value)
    if DUI.RefreshNameplates then
        DUI:RefreshNameplates()
    end
end

-- ============================================================================
-- NO CROP: let the name ignore the plate width so it is never cut with "..."
-- ============================================================================

function EXT.IsNameCropDisabled()
    local node = NameplateProfile()
    return node ~= nil and node.extNameNoCrop == true
end

function EXT.SetNameCropDisabled(value)
    local profile = DUI.db and DUI.db.profile
    if not profile then return end
    profile.modules = profile.modules or {}
    profile.modules.nameplates = profile.modules.nameplates or {}
    profile.modules.nameplates.extNameNoCrop = value and true or false
    if DUI.RefreshNameplates then
        DUI:RefreshNameplates()
    end
end

-- ============================================================================
-- STYLE: outline and/or shadow for the name (retail draws it with a shadow, no outline)
-- ============================================================================

local STYLES = { none = true, outline = true, shadow = true, both = true }
local DEFAULT_STYLE = "shadow"
-- Retail's shadow falls to the right only (1.5px): no vertical offset.
local SHADOW_X, SHADOW_Y = 1.5, 0

function EXT.NormalizeTextStyle(value)
    if STYLES[value] then return value end
    return DEFAULT_STYLE
end

-- Puts the style on a font string, keeping its font and size.
function EXT.ApplyTextStyle(fs, style, safeSetFont)
    if not (fs and fs.GetFont) then return end
    local path, size = fs:GetFont()
    if not path then return end
    local outline = (style == "outline" or style == "both")
    local shadow = (style == "shadow" or style == "both")
    safeSetFont(fs, path, size, outline and "OUTLINE" or "")
    fs:SetShadowOffset(SHADOW_X, SHADOW_Y)
    fs:SetShadowColor(0, 0, 0, shadow and 1 or 0)
end

function EXT.GetNameStyle()
    local node = NameplateProfile()
    return EXT.NormalizeTextStyle(node and node.extNameStyle)
end

function EXT.SetNameStyle(value)
    local profile = DUI.db and DUI.db.profile
    if not profile then return end
    profile.modules = profile.modules or {}
    profile.modules.nameplates = profile.modules.nameplates or {}
    profile.modules.nameplates.extNameStyle = EXT.NormalizeTextStyle(value)
    if DUI.RefreshNameplates then
        DUI:RefreshNameplates()
    end
end

local LAYOUT = DUI.Nameplates.layout
if LAYOUT and type(LAYOUT.ApplyNameplateFonts) == "function" and type(LAYOUT.SafeSetFont) == "function" then
    local origFonts = LAYOUT.ApplyNameplateFonts
    function LAYOUT.ApplyNameplateFonts(plateData)
        origFonts(plateData)
        EXT.ApplyTextStyle(plateData and plateData.minaName, EXT.GetNameStyle(), LAYOUT.SafeSetFont)
        -- A recycled plate may come back at the base size while still scaled (NameplateTarget.lua).
        if EXT.UpdateNameScale then EXT.UpdateNameScale(plateData) end
    end
end

if LAYOUT and type(LAYOUT.AnchorPlateName) == "function" then
    local origAnchor = LAYOUT.AnchorPlateName
    -- DragonUI anchors the name between two points, which fixes its width and crops long names.
    -- With one anchor only, the name keeps its natural width and grows past the bar.
    function LAYOUT.AnchorPlateName(plateData, centered, leftInset)
        origAnchor(plateData, centered, leftInset)
        if not EXT.IsNameCropDisabled() then return end
        local name, row = plateData and plateData.minaName, plateData and plateData.minaNameRow
        if not name or not row then return end
        name:ClearAllPoints()
        if centered then
            name:SetJustifyH("CENTER")
            name:SetPoint("CENTER", row, "CENTER", 0, 0)
        else
            name:SetJustifyH("LEFT")
            name:SetPoint("LEFT", row, "LEFT", leftInset or 0, 0)
        end
    end
end

-- ============================================================================
-- VERTICAL OFFSET: moves the name row when the name sits above the bar (Modern frame)
-- ============================================================================

-- DragonUI only has a vertical offset for a name inside the bar. This one moves the row above the bar, which
-- carries the name, the level and the health text beside it. Stored as modules.nameplates.extNameOffsetY.
local MIN_OFFSET_Y, MAX_OFFSET_Y = -30, 30

function EXT.GetNameOffsetY()
    local node = NameplateProfile()
    local v = math.floor((tonumber(node and node.extNameOffsetY) or 0) + 0.5)
    if v < MIN_OFFSET_Y then return MIN_OFFSET_Y end
    if v > MAX_OFFSET_Y then return MAX_OFFSET_Y end
    return v
end

function EXT.SetNameOffsetY(value)
    local profile = DUI.db and DUI.db.profile
    if not profile then return end
    profile.modules = profile.modules or {}
    profile.modules.nameplates = profile.modules.nameplates or {}
    profile.modules.nameplates.extNameOffsetY = math.max(MIN_OFFSET_Y, math.min(MAX_OFFSET_Y, math.floor((tonumber(value) or 0) + 0.5)))
    -- DragonUI skips the layout pass while its own signature is unchanged: force it on the plates in view.
    local NP = DUI.Nameplates
    if NP.module and NP.module.plates then
        for _, pd in pairs(NP.module.plates) do
            pd._layoutSig = nil
        end
    end
    if DUI.RefreshNameplates then
        DUI:RefreshNameplates()
    end
end

EXT.NAME_OFFSET_Y_LIMITS = { min = MIN_OFFSET_Y, max = MAX_OFFSET_Y, step = 1 }

if LAYOUT and type(LAYOUT.LayoutMinaStack) == "function" then
    local origStack = LAYOUT.LayoutMinaStack
    function LAYOUT.LayoutMinaStack(plateData)
        origStack(plateData)
        local row = plateData and plateData.minaNameRow
        local offset = EXT.GetNameOffsetY()
        if not row or offset == 0 or DUI.Nameplates.config.IsNameOverlayBar() then return end
        local n = row:GetNumPoints()
        local pts = {}
        for i = 1, n do
            pts[i] = { row:GetPoint(i) }
        end
        row:ClearAllPoints()
        for i = 1, n do
            local p = pts[i]
            row:SetPoint(p[1], p[2], p[3], p[4] or 0, (p[5] or 0) + offset)
        end
    end
end

EXT.NAME_SIZE_LIMITS ={ min = MIN_SIZE, max = MAX_SIZE, step = STEP }
