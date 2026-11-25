-- DragonUI_Extensions: cut the nameplate health fill instead of shrinking it.
--
-- In the Modern (and WoW Forever) style DragonUI draws the health fill as a nine-slice sized to the
-- remaining health, so the whole art is squeezed as health drops. With this option the fill is laid
-- out at full width and cut at the health value. Heritage already cuts its fill. The power bar and
-- DragonUI's files are not touched.
--
-- Relies on DragonUI internals: DragonUI.Nameplates (atlas.LayoutSlice, config.GetBarRefSize,
-- gather.SyncHealth, retail_chrome.LayoutFill, discovery.ClipBarFill, module.plates).
-- Stored in DragonUI's profile as modules.nameplates.extHealthCutFill.

local DUI = _G.DragonUI
local NP = DUI and DUI.Nameplates
if not (NP and NP.atlas and NP.config and NP.gather and NP.retail_chrome and NP.discovery) then return end
if type(NP.atlas.LayoutSlice) ~= "function" or type(NP.config.GetBarRefSize) ~= "function"
    or type(NP.gather.SyncHealth) ~= "function" or type(NP.retail_chrome.LayoutFill) ~= "function"
    or type(NP.discovery.ClipBarFill) ~= "function" then
    return
end

local A = NP.atlas

local EXT = _G.DragonUIExtensions or {}
_G.DragonUIExtensions = EXT

local function Profile()
    return DUI.db and DUI.db.profile and DUI.db.profile.modules and DUI.db.profile.modules.nameplates
end

function EXT.IsHealthFillCut()
    local node = Profile()
    return node ~= nil and node.extHealthCutFill == true
end

function EXT.SetHealthFillCut(value)
    local profile = DUI.db and DUI.db.profile
    if not profile then return end
    profile.modules = profile.modules or {}
    profile.modules.nameplates = profile.modules.nameplates or {}
    profile.modules.nameplates.extHealthCutFill = value and true or false
    -- DragonUI skips the fill while the health value is unchanged: redraw the plates in view.
    for _, plateData in pairs(NP.module and NP.module.plates or {}) do
        local bar = plateData.minaHp
        if bar and bar._retailFillOn then
            local lo, hi = bar:GetMinMaxValues()
            bar._fillClipRight = nil
            NP.discovery.ClipBarFill(bar, bar:GetValue() - lo, hi - lo)
        end
    end
end

-- Trims the laid-out pieces at x = cut. Every piece is marked stale afterwards, so the next
-- LayoutSlice sets its texture, coordinates and size again.
local function CutSlice(slice, cut)
    local geo, collapsed, keyed = slice.geo, slice.collapsed, slice.keyed
    for i = 1, 9 do
        if not collapsed[i] then
            local tex = slice[i]
            local x, width = geo.x[i], geo.w[i]
            local visible = cut - x
            if visible <= 0.01 then
                -- Marked collapsed so ShowSlice skips it and LayoutSlice shows it again.
                collapsed[i] = true
                tex:Hide()
            elseif visible < width then
                -- GetTexCoord: upper left x/y, lower left x/y, upper right x/y, lower right x/y.
                local left, top, _, bottom, right = tex:GetTexCoord()
                tex:SetWidth(visible)
                tex:SetTexCoord(left, left + (right - left) * visible / width, top, bottom)
            end
            keyed[i], geo.w[i] = nil, nil
        end
    end
end

local origFill = NP.retail_chrome.LayoutFill
function NP.retail_chrome.LayoutFill(bar, fraction)
    if not (bar._extHealthBar and EXT.IsHealthFillCut()) then
        return origFill(bar, fraction)
    end
    local fill = bar._retailFill
    if not fill then return end
    local w, h = NP.config.GetBarRefSize()
    if A.LayoutSlice(fill, "barFill", bar, w, h, 0, 0, 0, 0) then
        CutSlice(fill, w * fraction)
        A.ShowSlice(fill)
    end
end

-- The health and power bars share LayoutFill: mark the health bar before DragonUI fills it.
local origSyncHealth = NP.gather.SyncHealth
function NP.gather.SyncHealth(plateData, ...)
    local bar = plateData and plateData.minaHp
    if bar and not bar._extHealthBar then
        bar._extHealthBar = true
        bar._fillClipRight = nil
    end
    return origSyncHealth(plateData, ...)
end
