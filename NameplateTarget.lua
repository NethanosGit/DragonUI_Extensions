-- DragonUI_Extensions: how much bigger the current target's nameplate gets.
--
-- The nameplate frame itself cannot be rescaled in combat (DragonUI postpones that until combat
-- ends), so this scales what is drawn on it: DragonUI's visualRoot (name, level, health text, health
-- and cast bars, borders, auras, icons) plus the combo points and totem icon, which sit directly on
-- the plate. These are ordinary frames, so it works in combat. The clickable area keeps its size.
-- Nothing in DragonUI is edited.
--
-- Relies on DragonUI internals: NP.module.plates, plateData.visualRoot / _comboHost / _totemIcon
-- and NP.identity.IsTargetPlateVisual. Stored as modules.nameplates.extTargetScale (1 = no change).

local DUI = _G.DragonUI
if not (DUI and DUI.Nameplates and DUI.Nameplates.layout and DUI.Nameplates.identity) then return end

local NP = DUI.Nameplates
local LAYOUT = NP.layout

local EXT = _G.DragonUIExtensions or {}
_G.DragonUIExtensions = EXT

local MIN_SCALE, MAX_SCALE, STEP = 1, 1.5, 0.01

local function ClampScale(value)
    value = tonumber(value) or MIN_SCALE
    -- Two decimals, so the stored value is exactly 1.00 ... 1.50 with no float drift.
    value = math.floor(value * 100 + 0.5) / 100
    if value < MIN_SCALE then return MIN_SCALE end
    if value > MAX_SCALE then return MAX_SCALE end
    return value
end

local function NameplateProfile()
    return DUI.db and DUI.db.profile and DUI.db.profile.modules and DUI.db.profile.modules.nameplates
end

function EXT.GetTargetScale()
    local node = NameplateProfile()
    return ClampScale(node and node.extTargetScale)
end

function EXT.SetTargetScale(value)
    local profile = DUI.db and DUI.db.profile
    if not profile then return end
    profile.modules = profile.modules or {}
    profile.modules.nameplates = profile.modules.nameplates or {}
    profile.modules.nameplates.extTargetScale = ClampScale(value)
    -- The driver below applies it on its next tick.
end

EXT.TARGET_SCALE_LIMITS = { min = MIN_SCALE, max = MAX_SCALE, step = STEP }

-- ============================================================================
-- SCALE: applied to the plate's visuals, eased over time
-- ============================================================================

-- Fraction of the remaining distance covered per second, so the scale eases out smoothly.
local EASE_SPEED = 14
local SNAP = 0.002

-- The name only follows this share of the extra target scale: a plate scaled x1.5 draws its name at
-- x1.375. Scaling the visuals scales the name too, so its font size is shrunk to compensate.
local NAME_SCALE_SHARE = 0.75

function EXT.UpdateNameScale(pd)
    local fs = pd and pd.minaName
    if not (fs and fs.GetFont and LAYOUT.SafeSetFont) then return end
    local path, size, flags = fs:GetFont()
    if not path or not size then return end
    -- A size we did not set is DragonUI's (or the Name setting's) new base size.
    if not pd._extNameSet or math.abs(size - pd._extNameSet) > 0.01 then
        pd._extNameBase = size
    end
    local extra = pd._extExtra or 1
    local m = 1
    if extra > 1 then
        m = (1 + NAME_SCALE_SHARE * (extra - 1)) / extra
    end
    local want = pd._extNameBase * m
    if math.abs(size - want) > 0.01 then
        LAYOUT.SafeSetFont(fs, path, want, flags)
    end
    pd._extNameSet = want
end

local function SetFrameScale(frame, scale)
    if frame and math.abs(frame:GetScale() - scale) > 0.001 then
        frame:SetScale(scale)
    end
end

-- Called every tick while a plate is scaled: DragonUI re-anchors visualRoot when it lays the plate
-- out again, and creates the combo points and totem icon only when they are first needed.
local function ApplyScale(pd, scale)
    local root = pd.visualRoot
    SetFrameScale(root, scale)
    SetFrameScale(pd._comboHost, scale)
    SetFrameScale(pd._totemIcon, scale)
    -- visualRoot hangs from the plate's top edge; this offset makes it grow around its center, so
    -- the health bar does not slide down. The offset is in visualRoot's own (scaled) units.
    local offset = root:GetHeight() * (scale - 1) / (2 * scale)
    local _, _, _, _, y = root:GetPoint(1)
    if math.abs((y or 0) - offset) > 0.01 then
        root:SetPoint("TOP", pd.plate, "TOP", 0, offset)
    end
end

local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, elapsed)
    if not (NP.module and NP.module.applied and NP.module.plates) then return end

    local hasTarget = UnitExists("target") and true or false
    local factor = EXT.GetTargetScale()
    local step = elapsed * EASE_SPEED
    if step > 1 then step = 1 end

    for _, pd in pairs(NP.module.plates) do
        local plate = pd.plate
        if plate and pd.visualRoot then
            local shown = plate:IsShown()
            local goal = 1
            if shown and factor > 1 and NP.identity.IsTargetPlateVisual(pd, hasTarget) then
                goal = factor
            end
            local current = pd._extExtra or 1
            local nextScale = goal
            -- A hidden plate resets at once: the game reuses it for another unit.
            if shown and current ~= goal then
                nextScale = current + (goal - current) * step
                if math.abs(goal - nextScale) < SNAP then
                    nextScale = goal
                end
            end
            if pd._extExtra or nextScale ~= 1 then
                ApplyScale(pd, nextScale)
                pd._extExtra = nextScale ~= 1 and nextScale or nil
                if nextScale ~= current then
                    EXT.UpdateNameScale(pd)
                end
            end
        end
    end
end)

-- ============================================================================
-- TARGET HIGHLIGHT COLOUR: tints the white glow DragonUI draws on the current target
-- ============================================================================

-- Stored as modules.nameplates.extTargetHighlightColor = { r, g, b }; nil keeps DragonUI's white.
function EXT.GetTargetHighlightColor()
    local node = NameplateProfile()
    local c = node and node.extTargetHighlightColor
    if type(c) == "table" then
        return c.r or c[1] or 1, c.g or c[2] or 1, c.b or c[3] or 1
    end
    return 1, 1, 1
end

function EXT.SetTargetHighlightColor(r, g, b)
    local profile = DUI.db and DUI.db.profile
    if not profile then return end
    profile.modules = profile.modules or {}
    profile.modules.nameplates = profile.modules.nameplates or {}
    profile.modules.nameplates.extTargetHighlightColor = { r = r or 1, g = g or 1, b = b or 1 }
    if DUI.RefreshNameplates then
        DUI:RefreshNameplates()
    end
end

if type(NP.gather) == "table" and type(NP.gather.SyncTargetHighlight) == "function" then
    local origHighlight = NP.gather.SyncTargetHighlight
    function NP.gather.SyncTargetHighlight(plateData, isTargeted)
        origHighlight(plateData, isTargeted)
        if not plateData then return end
        local r, g, b = EXT.GetTargetHighlightColor()
        -- Non-retail glow texture, and the retail skin's selection border (nine slices).
        local target = plateData.minaTarget
        if target and target.tex then
            target.tex:SetVertexColor(r, g, b)
        end
        local slice = plateData._retailSelected
        if slice and NP.atlas and NP.atlas.SetSliceVertexColor then
            NP.atlas.SetSliceVertexColor(slice, r, g, b, 1)
        end
    end
end
