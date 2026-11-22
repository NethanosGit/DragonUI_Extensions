-- DragonUI_Extensions: how much bigger the current target's nameplate gets.
--
-- DragonUI only scales the target plate while its retail stacking behaviour is on, so this file
-- scales the plate itself. SetScale on the plate scales every child: name, level, health text,
-- health bar, cast bar, borders, auras and icons. Nothing in DragonUI is edited.
--
-- Relies on DragonUI internals: DragonUI.Nameplates.layout.SetRetailPlateScale (wrapped, so the
-- extra scale is multiplied in wherever DragonUI sets a plate's scale), NP.module.plates and
-- NP.identity.IsTargetPlateVisual. Stored as modules.nameplates.extTargetScale (1 = no change).

local DUI = _G.DragonUI
if not (DUI and DUI.Nameplates and DUI.Nameplates.layout and DUI.Nameplates.identity) then return end

local NP = DUI.Nameplates
local LAYOUT = NP.layout
if type(LAYOUT.SetRetailPlateScale) ~= "function" then return end

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
-- SCALE: multiplied into every scale DragonUI sets on the target's plate, eased over time
-- ============================================================================

-- Fraction of the remaining distance covered per second, so the scale eases out smoothly.
local EASE_SPEED = 14
local SNAP = 0.002

local origSetScale = LAYOUT.SetRetailPlateScale

-- The name only follows this share of the extra target scale: a plate scaled x1.5 draws its name at
-- x1.375. SetScale on the plate scales the name too, so its font size is shrunk to compensate.
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

-- DragonUI asks for a scale; the extra target scale is multiplied in and becomes the goal that the
-- animation below walks towards.
function LAYOUT.SetRetailPlateScale(plateData, scale)
    scale = scale or 1
    if not plateData then
        return origSetScale(plateData, scale)
    end
    -- A scale deferred during combat is replayed by DragonUI with the extra scale already in it.
    plateData._extBase = scale
    if plateData._extPendingScale == scale then
        plateData._extPendingScale = nil
        return origSetScale(plateData, scale)
    end
    local factor = EXT.GetTargetScale()
    if factor <= 1 and plateData._extDesired == nil then
        return origSetScale(plateData, scale)
    end
    if factor > 1 and NP.identity.IsTargetPlateVisual(plateData) then
        scale = scale * factor
    end
    plateData._extDesired = scale
end

local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, elapsed)
    if not (NP.module and NP.module.applied and NP.module.plates) then return end

    local retailMode = NP.module._retailBehavior
    local hasTarget = UnitExists("target") and true or false
    local factor = EXT.GetTargetScale()
    local step = elapsed * EASE_SPEED
    if step > 1 then step = 1 end

    for _, pd in pairs(NP.module.plates) do
        local plate = pd.plate
        if plate and plate.IsShown and plate:IsShown() then
            -- In retail mode DragonUI's own loop feeds the goal through the wrapper every tick.
            if not retailMode and (factor > 1 or pd._extDesired ~= nil) then
                pd._extDesired = (factor > 1 and NP.identity.IsTargetPlateVisual(pd, hasTarget)) and factor or 1
            end
            local goal = pd._extDesired
            if goal then
                local current = pd._pendingRetailScale or pd._retailScale or 1
                if current ~= goal then
                    local nextScale = current + (goal - current) * step
                    if math.abs(goal - nextScale) < SNAP then
                        nextScale = goal
                    end
                    origSetScale(pd, nextScale)
                    pd._extExtra = nextScale / (pd._extBase or 1)
                    EXT.UpdateNameScale(pd)
                    pd._extPendingScale = pd._pendingRetailScale and nextScale or nil
                    current = nextScale
                end
                if current == goal and factor <= 1 then
                    pd._extDesired = nil
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
