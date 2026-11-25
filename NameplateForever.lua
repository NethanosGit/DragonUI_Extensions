-- DragonUI_Extensions: the WoW Forever (thin) nameplate style.
--
-- A port of DragonUI pull request #586 (https://github.com/NeticSoul/DragonUI/pull/586) that edits
-- no DragonUI file: every change the pull request makes is applied here by wrapping DragonUI's
-- nameplate functions. The style runs on top of DragonUI's Modern style (plateStyle stays "modern"),
-- so with this addon disabled the plates are ordinary Modern plates. Picking Heritage in
-- DragonUI_Options turns the Forever style off.
--
-- Only the art changes: sizes, fonts, text placement, icons and the level position are whatever the
-- settings say.
--
-- Must load after NameplateName, NameplateLevel, NameplateTarget and NameplateIcons: these wrappers
-- have the last word over theirs.
--
-- Stored in DragonUI's profile: modules.nameplates.extForeverStyle and extForeverPrevStyle (the
-- plate style to return to).

local DUI = _G.DragonUI
local EXT = _G.DragonUIExtensions
local NP = DUI and DUI.Nameplates
if not (NP and EXT and EXT.FOREVER_KEYS) then return end

local A, C = NP.atlas, NP.const
local max, min, floor = math.max, math.min, math.floor

-- Every DragonUI internal this file wraps. If a DragonUI update removes one, the style stays off.
local REQUIRED = {
    atlas = { "Apply", "LayoutSlice", "CreateSlice", "ShowSlice", "HideSlice", "SetSliceVertexColor" },
    config = { "GetCfg", "IsRetailSkin", "GetCastFillTexture", "GetCastBarMetrics", "GetBarRefSize",
        "GetNameplateFont", "IsNameOverlayBar" },
    castbar = { "SizeCastSpark", "LayoutCastIconShield", "GetCastSpellIconSize", "LayoutCastSpellIcon",
        "CreateCastMinaBar", "CreatePartyCastBar", "LayoutPartyCastBar", "ShowInterruptedState" },
    layout = { "LayoutMinaStack", "LayoutCastBarStack", "HideMinaStack", "AnchorPlateName", "SafeSetFont" },
    gather = { "SyncName", "SyncHealth", "SyncTargetHighlight", "RefreshPlateTargetState",
        "IsHeadlineActive", "IsTotemIconOnlyActive" },
    widgets = { "Get" },
    discovery = { "FormatPlateName" },
    identity = { "ProcessContextTransitions", "IsTargetPlateVisual", "IsFocusPlate" },
    lifecycle = { "InvalidatePlateVisuals" },
}

for tableName, names in pairs(REQUIRED) do
    for _, name in ipairs(names) do
        if not (NP[tableName] and type(NP[tableName][name]) == "function") then return end
    end
end
local chrome = NP.widgets.Get("RetailChrome")
if not (chrome and chrome.Layout and chrome.Sync and type(DUI.RefreshNameplates) == "function") then
    return
end

-- ============================================================================
-- SETTINGS: one switch; every other setting stays as the user has it
-- ============================================================================

local function Profile()
    return DUI.db and DUI.db.profile and DUI.db.profile.modules and DUI.db.profile.modules.nameplates
end

local function IsForever()
    local cfg = NP.config.GetCfg()
    return cfg.extForeverStyle == true and NP.config.IsRetailSkin()
end

-- DragonUI skips layout passes while its signatures are unchanged: force them on the plates in view.
local function InvalidatePlates()
    for _, pd in pairs(NP.module and NP.module.plates or {}) do
        pd._layoutSig = nil
        pd._retailChromeSig = nil
    end
end

-- The first version of this style overwrote settings and kept the old ones in extForeverBackup.
-- These are the values it forced: any still in place goes back to the old one.
local OLD_FORCED = {
    barWidth = 166, barHeight = 13, castBarHeight = 6, castBarGap = 2,
    fontSize = 5, castBarSpellNameFontSize = 10, debuffCooldownFontSize = 10, nameFont = "primary",
    centerNameOnly = true, nameOverlayHealthBar = false, retailTextOutlineAbove = true,
    healthTextPosition = "barRight",
    showLevelAlways = true, showLevelInName = true, showLevelOnHover = true,
    levelPosition = "name", levelTextFormat = "plain",
    showCastBar = true, showCastBarSpellName = true,
    castBarModernIconLeft = false, castBarModernIconBorder = false,
    retailSelectionBorder = true, retailDeselectedOverlay = true,
    retailMouseoverHighlight = true, showTargetHighlight = true,
    showEliteIcon = false, threatGlow = false, showTargetArrows = false, showPowerBar = false,
    extNameStyle = "outline", extHealthStyle = "outline",
    extNameNoCrop = false, extNameOffsetY = 0, healthNumberFontSize = 7,
    levelPlacement = "beforeName", extRaidMarkerSide = "left", extRaidMarkerOffsetX = 0,
}

local function RestoreOldSettings()
    local node = Profile()
    if not node then return false end
    local backup = node.extForeverBackup
    node.extForeverBackup, node.extForeverSaved = nil, nil
    if not backup then return false end
    for key, forced in pairs(OLD_FORCED) do
        if node[key] == forced and backup[key] ~= nil then node[key] = backup[key] end
    end
    -- The highlight colour was cleared rather than set.
    if node.extTargetHighlightColor == nil then node.extTargetHighlightColor = backup.extTargetHighlightColor end
    return true
end

function EXT.IsForeverStyle()
    local node = Profile()
    return node ~= nil and node.extForeverStyle == true and NP.config.IsRetailSkin()
end

function EXT.SetForeverStyle(value)
    local node = Profile()
    value = value and true or false
    if not node or value == EXT.IsForeverStyle() then return end
    RestoreOldSettings()
    if value then
        -- The art is drawn on top of DragonUI's Modern style.
        node.extForeverPrevStyle = nil
        if not NP.config.IsRetailSkin() then
            node.extForeverPrevStyle = node.plateStyle
            node.plateStyle = "modern"
        end
    else
        node.plateStyle = node.extForeverPrevStyle or node.plateStyle
        node.extForeverPrevStyle = nil
    end
    node.extForeverStyle = value
    InvalidatePlates()
    DUI:RefreshNameplates()
end

-- Heritage picked in DragonUI_Options ends the style.
local origRefresh = DUI.RefreshNameplates
function DUI.RefreshNameplates(...)
    RestoreOldSettings()
    local node = Profile()
    if node and node.extForeverStyle == true then
        if not NP.config.IsRetailSkin() then
            node.extForeverStyle, node.extForeverPrevStyle = false, nil
        end
        InvalidatePlates()
    end
    return origRefresh(...)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    if RestoreOldSettings() then
        InvalidatePlates()
        DUI:RefreshNameplates()
    end
end)

-- ============================================================================
-- ART: atlas keys and cast fills
-- ============================================================================

local origApply = A.Apply
function A.Apply(tex, key, ...)
    if IsForever() then key = EXT.FOREVER_KEYS[key] or key end
    return origApply(tex, key, ...)
end

local origSlice = A.LayoutSlice
function A.LayoutSlice(slice, key, ...)
    if IsForever() then key = EXT.FOREVER_KEYS[key] or key end
    return origSlice(slice, key, ...)
end

local origFill = NP.config.GetCastFillTexture
function NP.config.GetCastFillTexture(isChannel, notInterruptible, interrupted)
    if not IsForever() then return origFill(isChannel, notInterruptible, interrupted) end
    local fills = EXT.FOREVER_CAST_FILL
    if interrupted then
        return fills.interrupted
    elseif notInterruptible then
        return fills.uninterruptible
    end
    return isChannel and fills.channel or fills.standard
end

-- ============================================================================
-- LEVEL BADGE: the Level tab's outside positions, drawn with the original badge art
-- ============================================================================

local function HideBadge(plateData)
    if plateData and plateData._extFvBadge then plateData._extFvBadge:Hide() end
end

-- "Before the Name" keeps the level in the name; the outside positions use the badge.
local function BadgeSide()
    local placement = EXT.GetLevelPlacement and EXT.GetLevelPlacement()
    if placement == "outsideLeft" then return "left" end
    if placement == "outsideRight" then return "right" end
end

-- The Level tab's difficulty colour toggles apply to the badge too.
local function UsesDifficultyColor(plateData)
    if not (EXT.GetLevelDifficultyColor and NP.native_style) then return true end
    local reaction, unitType = NP.native_style.GetPlateReaction(plateData)
    local side = (reaction == "FRIENDLY") and "friendly" or "enemy"
    return EXT.GetLevelDifficultyColor(side .. (unitType == "PLAYER" and "Player" or "NPC"))
end

-- White (or the Target tab's colour) for the target, orange for the focus.
local function SelectionColor(isTarget)
    if not isTarget then return 1, 0.49, 0.039 end
    if EXT.GetTargetHighlightColor then return EXT.GetTargetHighlightColor() end
    return 1, 1, 1
end

local function PaintSelection(slice, isTarget, isFocus)
    local cfg = NP.config.GetCfg()
    if (isTarget or isFocus) and cfg.retailSelectionBorder ~= false and cfg.showTargetHighlight ~= false then
        local r, g, b = SelectionColor(isTarget)
        A.SetSliceVertexColor(slice, r, g, b, 1)
        A.ShowSlice(slice)
    else
        A.HideSlice(slice)
    end
end

-- Only known native levels or verified unit tokens are used. Off-target NPCs must not inherit the
-- target's level, nor the previous occupant's cached text.
local function SyncBadge(plateData, unit, fallback, boss)
    local hp = plateData.minaHp
    if not hp or NP.gather.IsHeadlineActive(plateData) then
        return HideBadge(plateData)
    end
    local level = tonumber(unit and UnitExists(unit) and UnitLevel(unit) or fallback)
    if not boss and not level then
        return HideBadge(plateData)
    end
    local frame = plateData._extFvBadge
    if not frame then
        frame = CreateFrame("Frame", nil, hp)
        frame:SetFrameLevel(hp:GetFrameLevel() + 1)
        frame:EnableMouse(false)
        frame.bg = A.CreateSlice(frame, "BACKGROUND")
        frame.selected = A.CreateSlice(frame, "OVERLAY")
        frame.text = frame:CreateFontString(nil, "OVERLAY")
        frame.text:SetPoint("CENTER", frame, "CENTER", 0, 0)
        frame.skull = frame:CreateTexture(nil, "OVERLAY")
        frame.skull:SetPoint("CENTER", frame, "CENTER", 0, 0)
        plateData._extFvBadge = frame
    end
    local _, h = NP.config.GetBarRefSize()
    local scale = h / 13
    local w, fh = 28 * scale, h + 5 * scale
    local side = BadgeSide()
    local framed = EXT.IsLevelFrameShown()
    local size = 4 + EXT.GetLevelFontSize()
    local style = EXT.GetLevelStyle()
    local offsetX = EXT.GetLevelOffsetX()
    local signature = table.concat({ h, tostring(side), tostring(framed), size, style, offsetX,
        tostring(NP.module._cfgRev) }, ":")
    if frame.signature ~= signature then
        frame.signature = signature
        frame:SetSize(w, fh)
        frame:ClearAllPoints()
        if side == "left" then
            frame:SetPoint("RIGHT", hp, "LEFT", -5 * scale + offsetX, 0.5 * scale)
        else
            frame:SetPoint("LEFT", hp, "RIGHT", 5 * scale + offsetX, 0.5 * scale)
        end
        A.LayoutSlice(frame.bg, "levelBg", frame, w, fh, 0, 0, 0, 0)
        A.LayoutSlice(frame.selected, "levelSelected", frame, w, fh, 3 * scale, 3 * scale, 3 * scale, 4 * scale)
        if framed then A.ShowSlice(frame.bg) else A.HideSlice(frame.bg) end
        A.Apply(frame.skull, "levelSkull")
        -- The cell is 26 logical pixels with the glyph inset; 21 matches the original badge.
        frame.skull:SetSize(21 * scale, 21 * scale)
        local outline = (style == "outline" or style == "both")
        NP.layout.SafeSetFont(frame.text, NP.config.GetNameplateFont(), size, outline and "OUTLINE" or "")
        frame.text:SetShadowOffset(1, -1)
        frame.text:SetShadowColor(0, 0, 0, (style == "shadow" or style == "both") and 1 or 0)
    end
    if framed then
        PaintSelection(frame.selected, NP.identity.IsTargetPlateVisual(plateData), NP.identity.IsFocusPlate(plateData))
    else
        A.HideSlice(frame.selected)
    end
    if boss or level <= 0 then
        frame.text:Hide()
        frame.skull:Show()
    else
        frame.text:SetText(tostring(level))
        -- The player's level can change without this unit's level changing.
        if UsesDifficultyColor(plateData) then
            local color = GetQuestDifficultyColor(level)
            frame.text:SetTextColor(color.r, color.g, color.b)
        else
            frame.text:SetTextColor(1, 0.82, 0)
        end
        frame.text:Show()
        frame.skull:Hide()
    end
    frame:Show()
end

-- DragonUI calls this exactly when a plate should show a level, so it feeds the badge.
local origFormat = NP.discovery.FormatPlateName
function NP.discovery.FormatPlateName(plateData, unit, levelOverride)
    if not (plateData and IsForever() and BadgeSide()) then
        return origFormat(plateData, unit, levelOverride)
    end
    plateData._extFvWanted, plateData._extFvUnit, plateData._extFvLevel = true, unit, levelOverride
    return plateData.plateName or "?"
end

local origSyncName = NP.gather.SyncName
function NP.gather.SyncName(plateData, unit)
    if plateData then plateData._extFvWanted = nil end
    origSyncName(plateData, unit)
    if not plateData then return end
    if not IsForever() or not plateData.minaName or NP.gather.IsTotemIconOnlyActive(plateData) then
        return HideBadge(plateData)
    end
    -- The badge carries the boss skull, so the one beside the name goes.
    local skull = plateData.minaBossSkull
    local boss = (plateData._extFvWanted and skull and skull:IsShown()) and true or false
    if boss then
        skull:Hide()
        if plateData.minaNameRow then
            NP.layout.AnchorPlateName(plateData, NP.config.GetCfg().centerNameOnly == true, 0)
        end
    end
    if plateData._extFvWanted then
        SyncBadge(plateData, plateData._extFvUnit, plateData._extFvLevel, boss)
    else
        HideBadge(plateData)
    end
end

local origSyncHealth = NP.gather.SyncHealth
function NP.gather.SyncHealth(plateData, ...)
    if plateData and NP.gather.IsTotemIconOnlyActive(plateData) then HideBadge(plateData) end
    return origSyncHealth(plateData, ...)
end

local origHideStack = NP.layout.HideMinaStack
function NP.layout.HideMinaStack(plateData, ...)
    HideBadge(plateData)
    return origHideStack(plateData, ...)
end

local origInvalidate = NP.lifecycle.InvalidatePlateVisuals
function NP.lifecycle.InvalidatePlateVisuals(plateData, ...)
    HideBadge(plateData)
    return origInvalidate(plateData, ...)
end

-- ============================================================================
-- HEALTH BAR CHROME: selection border (target and focus) and dim overlay
-- ============================================================================

-- Colours the selection border for target or focus and keeps the dim overlay off both.
local function SyncSelection(plateData, isTarget)
    local sel, desel = plateData._retailSelected, plateData._retailDeselected
    if not (sel and desel) or NP.gather.IsHeadlineActive(plateData) then return end
    if isTarget == nil then isTarget = NP.identity.IsTargetPlateVisual(plateData) end
    local focus = NP.identity.IsFocusPlate(plateData)
    PaintSelection(sel, isTarget, focus)
    if not isTarget and not focus and NP.config.GetCfg().retailDeselectedOverlay ~= false then
        A.ShowSlice(desel)
    else
        A.HideSlice(desel)
    end
end

local origChromeLayout = chrome.Layout
function chrome.Layout(plateData, ...)
    local forever = IsForever()
    -- DragonUI's signature knows only the sizes, so a style change has to clear it.
    if (plateData._extFvStyle or false) ~= forever then
        plateData._extFvStyle = forever
        plateData._retailChromeSig = nil
    end
    local before = plateData._retailChromeSig
    local ok = origChromeLayout(plateData, ...)
    local hp = plateData.minaHp
    if forever and hp and (before == nil or before ~= plateData._retailChromeSig) then
        local w, h = NP.config.GetBarRefSize()
        local m = min(1, h / 10)
        -- The original selection anchors are relative to the background, not the fill.
        A.LayoutSlice(plateData._retailSelected, "selected", hp, w, h, 5 * m, 5 * m, 6 * m, 4 * m)
        A.LayoutSlice(plateData._retailDeselected, "deselected", hp, w, h, 0, m, 0, m)
    end
    return ok
end

local origChromeSync = chrome.Sync
function chrome.Sync(plateData, context, state, ...)
    origChromeSync(plateData, context, state, ...)
    if IsForever() then
        SyncSelection(plateData, state and state.showTargetHighlight)
    end
end

-- NameplateTarget.lua tints the border with the target colour; the focus keeps its orange.
local origHighlight = NP.gather.SyncTargetHighlight
function NP.gather.SyncTargetHighlight(plateData, isTargeted)
    origHighlight(plateData, isTargeted)
    if not (plateData and plateData._retailSelected and IsForever()) then return end
    if isTargeted == nil then isTargeted = NP.identity.IsTargetPlateVisual(plateData) end
    if not isTargeted and NP.identity.IsFocusPlate(plateData) then
        A.SetSliceVertexColor(plateData._retailSelected, SelectionColor(false))
    end
end

local origTransitions = NP.identity.ProcessContextTransitions
function NP.identity.ProcessContextTransitions(...)
    local oldFocus = NP.module.focusPlate
    origTransitions(...)
    local newFocus = NP.module.focusPlate
    if oldFocus ~= newFocus and IsForever() then
        if oldFocus then NP.gather.RefreshPlateTargetState(oldFocus, "forever_focus_changed") end
        if newFocus then NP.gather.RefreshPlateTargetState(newFocus, "forever_focus_changed") end
    end
end

-- DragonUI centres the health text on the bar, which looks low on the thin art: raise it.
local function RaiseHealthText(fs)
    if not fs then return end
    local points = {}
    for i = 1, fs:GetNumPoints() do points[i] = { fs:GetPoint(i) } end
    fs:ClearAllPoints()
    for _, p in ipairs(points) do
        fs:SetPoint(p[1], p[2], p[3], p[4] or 0, 0.5)
    end
end

-- The name sits 2 units above the bar instead of DragonUI's 3.
local origStack = NP.layout.LayoutMinaStack
function NP.layout.LayoutMinaStack(plateData, ...)
    origStack(plateData, ...)
    if plateData and IsForever() then
        RaiseHealthText(plateData.minaHpNum)
        RaiseHealthText(plateData.minaHpBarPct)
    end
    local row = plateData and plateData.minaNameRow
    if not row or not IsForever() or NP.config.IsNameOverlayBar() then return end
    local points = {}
    for i = 1, row:GetNumPoints() do points[i] = { row:GetPoint(i) } end
    row:ClearAllPoints()
    for _, p in ipairs(points) do
        row:SetPoint(p[1], p[2], p[3], p[4] or 0, (p[5] or 0) - 1)
    end
end

-- ============================================================================
-- CAST BARS
-- ============================================================================

-- The Forever fills carry their own colour; tinting them again turns the gold art orange.
local function KeepFillUntinted(bar)
    if not bar or bar._extFvColorHook then return end
    bar._extFvColorHook = true
    local busy
    hooksecurefunc(bar, "SetStatusBarColor", function(self, r, g, b)
        if busy or not IsForever() or (r == 1 and g == 1 and b == 1) then return end
        busy = true
        self:SetStatusBarColor(1, 1, 1, 1)
        busy = nil
    end)
end

local origCreateCast = NP.castbar.CreateCastMinaBar
function NP.castbar.CreateCastMinaBar(...)
    local bar = origCreateCast(...)
    KeepFillUntinted(bar)
    return bar
end

local origCreateParty = NP.castbar.CreatePartyCastBar
function NP.castbar.CreatePartyCastBar(...)
    local bar = origCreateParty(...)
    if bar then
        -- The background is the first region DragonUI creates on a party bar.
        bar._extFvBg = bar:GetRegions()
        KeepFillUntinted(bar)
    end
    return bar
end

-- A cast already in progress skips the cast setup on an options refresh: swap its fill here.
local function SyncFillStyle(bar)
    local forever = IsForever()
    if not bar or (bar._extFvFill or false) == forever then return end
    bar._extFvFill = forever
    bar:SetStatusBarTexture(NP.config.GetCastFillTexture(bar.channelingEx, bar._notInterruptible, bar._interrupted))
    local color = bar.channelingEx and C.CAST_COLOR_CHANNEL or C.CAST_COLOR_STANDARD
    if forever or bar._interrupted or not color then
        bar:SetStatusBarColor(1, 1, 1, 1)
    else
        bar:SetStatusBarColor(color[1], color[2], color[3], 1)
    end
    if bar.InvalidateTextureCache then bar:InvalidateTextureCache() end
    if bar.UpdateTextureClipping then
        local lo, hi = bar:GetMinMaxValues()
        local value = bar:GetValue()
        bar:UpdateTextureClipping(hi > lo and (value - lo) / (hi - lo) or 0, bar.channelingEx)
    end
end

-- Party/raid cast bars have no retail chrome in DragonUI; they get the original frame here.
local function StylePartyCast(bar)
    if not IsForever() then
        if bar._extFvFrame then
            A.HideSlice(bar._extFvFrame)
            if bar.minaBr then bar.minaBr:Show() end
            if bar._extFvBg then
                bar._extFvBg:SetTexture(C.MINA_TEX .. "bar-bg")
                bar._extFvBg:SetTexCoord(0, 1, 0, 1)
            end
        end
        return
    end
    local width, height = bar:GetWidth(), bar:GetHeight()
    bar._extFvFrame = bar._extFvFrame or A.CreateSlice(bar, "ARTWORK")
    local margin = 2 * min(1, height / 6)
    A.LayoutSlice(bar._extFvFrame, "castFrame", bar, width, height, margin, margin, margin, margin)
    A.ShowSlice(bar._extFvFrame)
    if bar.minaBr then bar.minaBr:Hide() end
    if bar._extFvBg then A.Apply(bar._extFvBg, "castBg") end
end

local origLayoutParty = NP.castbar.LayoutPartyCastBar
function NP.castbar.LayoutPartyCastBar(plateData, ...)
    origLayoutParty(plateData, ...)
    local bar = plateData and plateData.minaPartyCast
    if not bar then return end
    SyncFillStyle(bar)
    StylePartyCast(bar)
end

local origCastStack = NP.layout.LayoutCastBarStack
function NP.layout.LayoutCastBarStack(plateData, ...)
    if plateData then SyncFillStyle(plateData.minaCast) end
    return origCastStack(plateData, ...)
end

local origInterrupted = NP.castbar.ShowInterruptedState
function NP.castbar.ShowInterruptedState(bar, ...)
    origInterrupted(bar, ...)
    if IsForever() and bar and bar._interrupted and bar._intBg then
        bar._intBg:SetTexture(EXT.FOREVER_CAST_FILL.interrupted)
        bar._intBg:SetTexCoord(0, 1, 0, 1)
    end
end

local origSpark = NP.castbar.SizeCastSpark
function NP.castbar.SizeCastSpark(spark, castH)
    if not spark then return end
    local forever = IsForever()
    if (spark._extFvSpark or false) ~= forever then
        spark._extFvSpark = forever
        local tex = spark:GetRegions()
        if tex then
            if forever then
                A.Apply(tex, "castSpark")
            else
                tex:SetTexture(C.CAST_TEX_SPARK)
                tex:SetTexCoord(0, 1, 0, 1)
            end
        end
    end
    if forever then
        spark:SetSize(4, castH + 8)
        return
    end
    return origSpark(spark, castH)
end

local origShield = NP.castbar.LayoutCastIconShield
function NP.castbar.LayoutCastIconShield(shield, iconRef, iconSize, parentBar)
    origShield(shield, iconRef, iconSize, parentBar)
    if not (shield and iconRef) or not NP.config.IsRetailSkin() then return end
    local forever = IsForever()
    -- The shield outlives a style switch. It is a texture, or a frame holding one.
    if shield._extFvShield ~= forever then
        shield._extFvShield = forever
        local tex = shield
        if shield:GetObjectType() ~= "Texture" then tex = shield:GetRegions() end
        if tex then A.Apply(tex, "castShield") end
    end
    if forever then
        local size = iconSize or 14
        shield:SetSize(size, size * 16 / 14)
    end
end

local origIconSize = NP.castbar.GetCastSpellIconSize
function NP.castbar.GetCastSpellIconSize(...)
    if not IsForever() then return origIconSize(...) end
    local castH = NP.config.GetCastBarMetrics()
    return max(6, floor(castH * 10 / 6 + 0.5))
end

local origLayoutIcon = NP.castbar.LayoutCastSpellIcon
function NP.castbar.LayoutCastSpellIcon(icon, bar, ...)
    local size = origLayoutIcon(icon, bar, ...)
    if icon and bar and IsForever() and not NP.config.GetCfg().castBarModernIconLeft then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, 0)
    end
    return size
end
