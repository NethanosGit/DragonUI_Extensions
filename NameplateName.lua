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

local LAYOUT = DUI.Nameplates.layout
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

EXT.NAME_SIZE_LIMITS ={ min = MIN_SIZE, max = MAX_SIZE, step = STEP }
