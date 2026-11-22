-- DragonUI_Extensions: raid marker position for nameplates.
--
-- DragonUI puts the raid marker above the bar, or beside its right edge with "Beside Bar Layout".
-- This file adds a horizontal offset (any layout) and a side (left or right) for the beside layout.
-- Nothing in DragonUI is edited: ReflowTopOverlays is wrapped and the marker is re-anchored after it.
--
-- Relies on DragonUI internals: DragonUI.Nameplates.widgets.ReflowTopOverlays, which anchors the
-- marker as ("TOP", hp, "TOP", x, y); beside the bar x is positive (right edge).
-- Stored as modules.nameplates.extRaidMarkerOffsetX / extRaidMarkerSide.

local DUI = _G.DragonUI
if not (DUI and DUI.Nameplates and DUI.Nameplates.widgets
        and type(DUI.Nameplates.widgets.ReflowTopOverlays) == "function") then
    return
end

local NP = DUI.Nameplates
local EXT = _G.DragonUIExtensions or {}
_G.DragonUIExtensions = EXT

local MIN_X, MAX_X = -100, 100

local function NameplateProfile()
    return DUI.db and DUI.db.profile and DUI.db.profile.modules and DUI.db.profile.modules.nameplates
end

local function WriteNode()
    local profile = DUI.db and DUI.db.profile
    if not profile then return nil end
    profile.modules = profile.modules or {}
    profile.modules.nameplates = profile.modules.nameplates or {}
    return profile.modules.nameplates
end

function EXT.GetRaidMarkerOffsetX()
    local node = NameplateProfile()
    local v = tonumber(node and node.extRaidMarkerOffsetX) or 0
    if v < MIN_X then return MIN_X end
    if v > MAX_X then return MAX_X end
    return v
end

function EXT.GetRaidMarkerSide()
    local node = NameplateProfile()
    return (node and node.extRaidMarkerSide == "left") and "left" or "right"
end

local function Refresh()
    if DUI.RefreshNameplates then
        DUI:RefreshNameplates()
    end
end

function EXT.SetRaidMarkerOffsetX(value)
    local node = WriteNode()
    if not node then return end
    value = math.floor((tonumber(value) or 0) + 0.5)
    if value < MIN_X then value = MIN_X elseif value > MAX_X then value = MAX_X end
    node.extRaidMarkerOffsetX = value
    Refresh()
end

function EXT.SetRaidMarkerSide(value)
    local node = WriteNode()
    if not node then return end
    node.extRaidMarkerSide = (value == "left") and "left" or "right"
    Refresh()
end

EXT.RAID_MARKER_X_LIMITS = { min = MIN_X, max = MAX_X, step = 1 }

local origReflow = NP.widgets.ReflowTopOverlays
function NP.widgets.ReflowTopOverlays(plateData)
    origReflow(plateData)
    local native = plateData and plateData.raidIcon
    local hp = plateData and plateData.minaHp
    if not (native and hp) then return end

    local offset = EXT.GetRaidMarkerOffsetX()
    local mirror = EXT.GetRaidMarkerSide() == "left"
    if offset == 0 and not mirror then return end

    local point, relativeTo, relativePoint, x, y = native:GetPoint(1)
    -- Only the plain "TOP of the bar" anchor; headline mode anchors to the name and is left alone.
    if point ~= "TOP" or relativeTo ~= hp then return end

    -- The beside layout is the only one with a large positive x; mirror it for the left side.
    if mirror and x and x > 0 then
        local C = NP.const or {}
        local base = C.RAID_MARKER_OFFSET_X or 0
        if x ~= base then
            x = -x
        end
    end
    native:ClearAllPoints()
    native:SetPoint(point, relativeTo, relativePoint, (x or 0) + offset, y or 0)
end
