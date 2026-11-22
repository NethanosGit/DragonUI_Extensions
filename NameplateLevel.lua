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
-- With the frame on, the level moves this far towards the bar.
local FRAME_SHIFT = 2

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

-- The level uses DragonUI's nameplate font.
local function LevelFontPath()
    return NP.config.GetNameplateFont()
end

-- Outline / shadow style of the level text drawn outside the bar.
-- Font size of the outside level text: drawn at LEVEL_FONT_BASE + the setting (default 2 = 6).
local LEVEL_FONT_BASE = 4
local DEFAULT_FONT_SIZE = 2
local MIN_FONT_SIZE, MAX_FONT_SIZE = -3, 10

local function ClampFontSize(value)
    value = math.floor((tonumber(value) or DEFAULT_FONT_SIZE) + 0.5)
    if value < MIN_FONT_SIZE then return MIN_FONT_SIZE end
    if value > MAX_FONT_SIZE then return MAX_FONT_SIZE end
    return value
end

function EXT.GetLevelFontSize()
    local node = NameplateProfile()
    return ClampFontSize(node and node.extLevelFontSize)
end

local function LevelPixelSize()
    return LEVEL_FONT_BASE + EXT.GetLevelFontSize()
end

local STYLES = { none = true, outline = true, shadow = true, both = true }
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
            local path = LevelFontPath()
            if path then
                local outline = (value == "outline" or value == "both")
                local shadow = (value == "shadow" or value == "both")
                NP.layout.SafeSetFont(plateData._extLevelFS, path, LevelPixelSize(), outline and "OUTLINE" or "")
                plateData._extLevelFS:SetShadowOffset(1, -1)
                plateData._extLevelFS:SetShadowColor(0, 0, 0, shadow and 1 or 0)
            end
        end
    end
    if DUI.RefreshNameplates then
        DUI:RefreshNameplates()
    end
end

function EXT.SetLevelFontSize(value)
    local profile = DUI.db and DUI.db.profile
    if not profile then return end
    profile.modules = profile.modules or {}
    profile.modules.nameplates = profile.modules.nameplates or {}
    profile.modules.nameplates.extLevelFontSize = ClampFontSize(value)
    -- Same live update as the style setting: it re-applies the font on plates already shown.
    EXT.SetLevelStyle(EXT.GetLevelStyle())
end

-- Difficulty colour per kind of unit. On (default) keeps DragonUI's difficulty colour; off draws the
-- level in WoW's normal text colour (gold) instead.
local NORMAL_HEX = "ffd100"
local DIFFICULTY_KEYS = {
    friendlyPlayer = "extLevelDiffFriendlyPlayer",
    friendlyNPC    = "extLevelDiffFriendlyNPC",
    enemyPlayer    = "extLevelDiffEnemyPlayer",
    enemyNPC       = "extLevelDiffEnemyNPC",
}

function EXT.GetLevelDifficultyColor(kind)
    local node = NameplateProfile()
    local key = DIFFICULTY_KEYS[kind]
    if not key then return true end
    return not (node and node[key] == false)
end

function EXT.SetLevelDifficultyColor(kind, value)
    local profile = DUI.db and DUI.db.profile
    local key = DIFFICULTY_KEYS[kind]
    if not (profile and key) then return end
    profile.modules = profile.modules or {}
    profile.modules.nameplates = profile.modules.nameplates or {}
    profile.modules.nameplates[key] = value and true or false
    if DUI.RefreshNameplates then
        DUI:RefreshNameplates()
    end
end

local function PlateDifficultyKind(plateData)
    local reaction, unitType = NP.native_style.GetPlateReaction(plateData)
    local friendly = (reaction == "FRIENDLY")
    if unitType == "PLAYER" then
        return friendly and "friendlyPlayer" or "enemyPlayer"
    end
    return friendly and "friendlyNPC" or "enemyNPC"
end

-- ============================================================================
-- NAME TEXT: take the level prefix out of the name when it is drawn outside the bar
-- ============================================================================

local origFormat = NP.discovery.FormatPlateName
function NP.discovery.FormatPlateName(plateData, unit, levelOverride)
    local text = origFormat(plateData, unit, levelOverride)
    if not plateData then
        return text
    end
    -- DragonUI's prefix is "|cffRRGGBB<level>|r <name>". The level has no "|r" in it, so the first
    -- "|r " is the end of the prefix.
    local hex, levelText, rest = string.match(text, "^|cff(%x%x%x%x%x%x)(.-)|r (.*)$")
    if not hex then
        return text
    end
    local useDifficulty = EXT.GetLevelDifficultyColor(PlateDifficultyKind(plateData))
    if EXT.GetLevelPlacement() == "beforeName" then
        if useDifficulty then return text end
        return "|cff" .. NORMAL_HEX .. levelText .. "|r " .. rest
    end
    plateData._extLevel = { hex = useDifficulty and hex or NORMAL_HEX, text = levelText }
    return rest
end

-- ============================================================================
-- LEVEL TEXT: a font string on the health bar, outside its left or right edge
-- ============================================================================

-- "Show Frame Under": a 10x10 box behind the level, drawn with the nameplate's own slices (dark
-- capsule, target border, non-target wash) and its mouseover wash. The background is static: no
-- tank tint and no fill. Target and hover follow the plate's own chrome.
local BOX_SIZE = 12
local CAVITY = 10
local MOUSEOVER_TEX = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill"
local MOUSEOVER_ALPHA = 0.25
-- Pads copied from DragonUI's retail chrome (scale 1 at a 10-unit cavity).
local BG_PAD = { 2, 3, 6, 6 }
local SEL_PAD, DESEL_PAD = 4, 1

function EXT.IsLevelFrameShown()
    local node = NameplateProfile()
    return node ~= nil and node.extLevelFrame == true
end

function EXT.SetLevelFrameShown(value)
    local profile = DUI.db and DUI.db.profile
    if not profile then return end
    profile.modules = profile.modules or {}
    profile.modules.nameplates = profile.modules.nameplates or {}
    profile.modules.nameplates.extLevelFrame = value and true or false
    if DUI.RefreshNameplates then
        DUI:RefreshNameplates()
    end
end

local A = NP.atlas

local function SyncBoxState(box, plateData)
    local sel, desel = plateData._retailSelected, plateData._retailDeselected
    local mo = plateData._retailMouseover
    if sel and sel.shown then
        -- Same colour as the target highlight on the plate (Target tab); NameplateTarget.lua defines it.
        if EXT.GetTargetHighlightColor then
            local r, g, b = EXT.GetTargetHighlightColor()
            A.SetSliceVertexColor(box.selected, r, g, b, 1)
        end
        A.ShowSlice(box.selected)
    else
        A.HideSlice(box.selected)
    end
    if desel and desel.shown then A.ShowSlice(box.deselected) else A.HideSlice(box.deselected) end
    if mo and mo:IsShown() then box.mo:Show() else box.mo:Hide() end
end

local function CreateLevelBox(plateData, hp)
    local box = CreateFrame("Frame", nil, hp)
    box:SetSize(BOX_SIZE, BOX_SIZE)
    box.plateData = plateData
    box.elapsed = 0
    box:SetScript("OnUpdate", function(self, dt)
        self.elapsed = self.elapsed + dt
        if self.elapsed < 0.05 then return end
        self.elapsed = 0
        if self.frameOn then SyncBoxState(self, self.plateData) end
    end)
    return box
end

-- The box is as tall as the health bar; pads scale like DragonUI's own chrome below a 10-unit bar.
local function LayoutBox(box, h)
    if box.layoutH == h then return end
    box.layoutH = h
    box:SetSize(BOX_SIZE, h)
    local m = h / CAVITY
    if m > 1 then m = 1 end
    A.LayoutSlice(box.bg, "barBg", box, BOX_SIZE, h, BG_PAD[1] * m, BG_PAD[2] * m, BG_PAD[3] * m, BG_PAD[4] * m)
    A.LayoutSlice(box.selected, "selected", box, BOX_SIZE, h, SEL_PAD * m, SEL_PAD * m, SEL_PAD * m, SEL_PAD * m)
    A.LayoutSlice(box.deselected, "deselected", box, BOX_SIZE, h, DESEL_PAD * m, DESEL_PAD * m, DESEL_PAD * m, DESEL_PAD * m)
end

local function SetBoxFrame(box, on, h)
    if not A or not A.CreateSlice then return end
    if on and not box.bg then
        box.bg = A.CreateSlice(box, "BACKGROUND")
        box.selected = A.CreateSlice(box, "OVERLAY")
        box.deselected = A.CreateSlice(box, "OVERLAY")
        box.mo = box:CreateTexture(nil, "OVERLAY")
        box.mo:SetTexture(MOUSEOVER_TEX)
        box.mo:SetAlpha(MOUSEOVER_ALPHA)
        box.mo:SetBlendMode("ADD")
        box.mo:SetAllPoints(box)
        box.mo:Hide()
    end
    box.frameOn = on
    if not box.bg then return end
    if on then
        LayoutBox(box, h)
        A.ShowSlice(box.bg)
        SyncBoxState(box, box.plateData)
    else
        A.HideSlice(box.bg)
        A.HideSlice(box.selected)
        A.HideSlice(box.deselected)
        box.mo:Hide()
    end
end

local function HideLevelText(plateData)
    if plateData._extLevelFS then
        plateData._extLevelFS:Hide()
    end
    if plateData._extLevelBox then
        plateData._extLevelBox:Hide()
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

    local box = plateData._extLevelBox
    if not box then
        box = CreateLevelBox(plateData, hp)
        plateData._extLevelBox = box
    end
    local fs = plateData._extLevelFS
    if not fs then
        fs = box:CreateFontString(nil, "OVERLAY")
        plateData._extLevelFS = fs
    end
    box:Show()

    -- DragonUI's nameplate font, at the Font Size setting; the outline and shadow follow the Style setting.
    local path = LevelFontPath()
    if path then
        local style = EXT.GetLevelStyle()
        local key = path .. "|" .. LevelPixelSize() .. "|" .. style
        if plateData._extLevelFontKey ~= key then
            plateData._extLevelFontKey = key
            local outline = (style == "outline" or style == "both")
            local shadow = (style == "shadow" or style == "both")
            NP.layout.SafeSetFont(fs, path, LevelPixelSize(), outline and "OUTLINE" or "")
            fs:SetShadowOffset(1, -1)
            fs:SetShadowColor(0, 0, 0, shadow and 1 or 0)
        end
    end
    levelPlates[plateData] = true

    local framed = EXT.IsLevelFrameShown()
    local placeKey = placement .. (framed and "F" or "")
    if plateData._extLevelPlacement ~= placeKey then
        plateData._extLevelPlacement = placeKey
        box:ClearAllPoints()
        fs:ClearAllPoints()
        if framed then
            -- The level sits in the middle of the frame; the frame takes the spot the text had.
            if placement == "outsideLeft" then
                box:SetPoint("RIGHT", hp, "LEFT", -GAP + FRAME_SHIFT, 0)
            else
                box:SetPoint("LEFT", hp, "RIGHT", GAP - FRAME_SHIFT, 0)
            end
            fs:SetJustifyH("CENTER")
            fs:SetPoint("CENTER", box, "CENTER", 0, 0)
        elseif placement == "outsideLeft" then
            box:SetPoint("RIGHT", hp, "LEFT", -GAP, 0)
            fs:SetJustifyH("RIGHT")
            fs:SetPoint("RIGHT", hp, "LEFT", -GAP, 0)
        else
            box:SetPoint("LEFT", hp, "RIGHT", GAP, 0)
            fs:SetJustifyH("LEFT")
            fs:SetPoint("LEFT", hp, "RIGHT", GAP, 0)
        end
    end
    local _, barH = NP.config.GetBarRefSize()
    box:SetHeight(framed and barH or BOX_SIZE)
    SetBoxFrame(box, framed, barH)

    if plateData._extLevelText ~= info.text then
        plateData._extLevelText = info.text
        fs:SetText(info.text)
    end
    local r = tonumber(info.hex:sub(1, 2), 16) / 255
    local g = tonumber(info.hex:sub(3, 4), 16) / 255
    local b = tonumber(info.hex:sub(5, 6), 16) / 255
    local colorKey = r .. ":" .. g .. ":" .. b
    if plateData._extLevelHex ~= colorKey then
        plateData._extLevelHex = colorKey
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
