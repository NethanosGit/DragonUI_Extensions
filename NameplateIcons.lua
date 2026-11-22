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

local MIN_SIZE, MAX_SIZE = 8, 64

function EXT.GetRaidMarkerSize()
    local node = NameplateProfile()
    local v = tonumber(node and node.extRaidMarkerSize)
    if not v then
        local C = NP.const or {}
        return C.RAID_MARKER_SIZE or 24
    end
    v = math.floor(v + 0.5)
    if v < MIN_SIZE then return MIN_SIZE end
    if v > MAX_SIZE then return MAX_SIZE end
    return v
end

function EXT.SetRaidMarkerSize(value)
    local node = WriteNode()
    if not node then return end
    value = math.floor((tonumber(value) or 24) + 0.5)
    if value < MIN_SIZE then value = MIN_SIZE elseif value > MAX_SIZE then value = MAX_SIZE end
    node.extRaidMarkerSize = value
    Refresh()
end

EXT.RAID_MARKER_SIZE_LIMITS = { min = MIN_SIZE, max = MAX_SIZE, step = 1 }
EXT.RAID_MARKER_X_LIMITS = { min = MIN_X, max = MAX_X, step = 1 }

local origReflow = NP.widgets.ReflowTopOverlays
function NP.widgets.ReflowTopOverlays(plateData)
    origReflow(plateData)
    local native = plateData and plateData.raidIcon
    local hp = plateData and plateData.minaHp
    if not (native and hp) then return end

    local offset = EXT.GetRaidMarkerOffsetX()
    local mirror = EXT.GetRaidMarkerSide() == "left"
    local C = NP.const or {}
    local defaultSize = C.RAID_MARKER_SIZE or 24
    local size = EXT.GetRaidMarkerSize()
    local resize = size ~= defaultSize
    if offset == 0 and not mirror and not resize then return end

    local point, relativeTo, relativePoint, x, y = native:GetPoint(1)
    -- Only the plain "TOP of the bar" anchor; headline mode anchors to the name and is left alone.
    if point ~= "TOP" or relativeTo ~= hp then return end

    -- The beside layout is the only one with a large positive x. Keep its gap to the bar edge when the
    -- size changes (the marker is centred, so half the growth goes outwards), then mirror for the left side.
    local beside = x and x > 0 and x ~= (C.RAID_MARKER_OFFSET_X or 0)
    if beside then
        x = x + (size - defaultSize) * 0.5
        if mirror then
            x = -x
        end
    end
    if resize then
        native:SetSize(size, size)
    end
    native:ClearAllPoints()
    if beside then
        -- Beside the bar: always centred on the bar's middle, whatever the size.
        native:SetPoint("CENTER", hp, "CENTER", x + offset, 0)
    else
        -- Above the bar: a TOP anchor would move the marker's centre when the size changes; keep it.
        native:SetPoint(point, relativeTo, relativePoint, (x or 0) + offset, (y or 0) + (size - defaultSize) * 0.5)
    end
end
