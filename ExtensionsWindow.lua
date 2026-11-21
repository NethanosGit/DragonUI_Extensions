-- DragonUI_Extensions: standalone settings window, opened with /duiext.
--
-- Same layout as DragonUI Options: a category list on the left (Frames, Bars) and the selected
-- page on the right. Built with DragonUI's ForeverUI helpers and DragonUI_Options' controls.
-- Nothing is copied from DragonUI: all textures and fonts are read from DragonUI at runtime.

local DUI = _G.DragonUI
local EXT = _G.DragonUIExtensions
if not (DUI and EXT and DUI.ForeverUI) then return end

local FUI = DUI.ForeverUI

-- Layout constants copied from DragonUI_Options (panel/panel.lua) so the window lines up with it.
local WINDOW_WIDTH, WINDOW_HEIGHT = 720, 560
local LIST_WIDTH = 197
local LIST_GAP = 16
local LIST_MARGIN_TOP = 12
local LIST_HEADER_H = 30
local ROW_X = 7
local ROW_WIDTH = 183
local ROW_HEIGHT = 20
local ROW_LABEL_INSET = 13
local GROUP_GAP = 12
local INSET_SIDE = 17
local CONTAINER_RIGHT = 5
local HEADER_HEIGHT = 50
local SCROLL_MARGIN = 6
local SCROLL_CONTENT_OFFSET = 32
local CLOSE_BUTTON_W = 96

local CONTENT_WIDTH = WINDOW_WIDTH - (INSET_SIDE + 1 + LIST_WIDTH + LIST_GAP + CONTAINER_RIGHT)

-- Each page's items use the DragonUI settings prefix that TargetVisibility.lua reads.
local PAGES = {
    units = {
        title = "Unit Frames",
        items = {
            { label = "Player Frame", prefix = "unitframe.player." },
            { label = "Target Frame", prefix = "unitframe.target." },
            { label = "Focus Frame",  prefix = "unitframe.focus." },
            { label = "Pet Frame",    prefix = "unitframe.pet." },
            { label = "Boss Frames",  prefix = "unitframe.boss." },
        },
    },
    bars = {
        title = "Action Bars",
        items = {
            { label = "Main Action Bar",  prefix = "actionbars.main_" },
            { label = "Right Bar",        prefix = "actionbars.right_" },
            { label = "Left Bar",         prefix = "actionbars.left_" },
            { label = "Bottom Left Bar",  prefix = "actionbars.bottom_left_" },
            { label = "Bottom Right Bar", prefix = "actionbars.bottom_right_" },
        },
    },
}

PAGES.additional = {
    title = "Additional Bars",
    items = {
        { label = "Stance Bar",   prefix = "additional.stance." },
        { label = "Pet Bar",      prefix = "additional.pet." },
        { label = "Totem Bar",    prefix = "additional.totem." },
        { label = "Extra Bar 1",  prefix = "additional.extrabar1." },
    },
}

PAGES.xprep = {
    title = "XP & Rep Bars",
    items = {
        { label = "XP & Rep Bars", prefix = "xprepbar." },
    },
}

-- Name: the name font size, down to 0.5 (DragonUI_Options stops at 1).
PAGES.name = {
    title = "Name",
    build = function(container)
        local C = DUI.PanelControls
        C:AddDescription(container, "Font size of the nameplate name. Goes down to -3, below the 1 that DragonUI_Options allows.")
        C:AddSpacer(container)

        local section = C:AddSection(container, "Name Text")
        local limits = EXT.NAME_SIZE_LIMITS
        C:AddSlider(section, {
            label = "Font Size",
            desc = "Font size of the name (-3 to 10 in steps of 0.5, default 2). The name is drawn at 9 + this value.",
            min = limits.min, max = limits.max, step = limits.step,
            width = 200,
            getFunc = function() return EXT.GetNameSize() end,
            setFunc = function(value) EXT.SetNameSize(value) end,
        })
        C:AddToggle(section, {
            label = "Ignore Nameplate Width",
            getFunc = function() return EXT.IsNameCropDisabled() end,
            setFunc = function(value) EXT.SetNameCropDisabled(value) end,
        })
    end,
}

-- Health: its own settings, not the Show on Target toggles. Built by its own function.
PAGES.health = {
    title = "Health",
    build = function(container)
        local C = DUI.PanelControls
        C:AddDescription(container, "Health text font size for nameplates. It applies in every style, including Modern.")
        C:AddSpacer(container)

        local section = C:AddSection(container, "Health Text")
        C:AddSlider(section, {
            label = "Font Size",
            desc = "Font size of the health text (-3 to 10, default 2). The text is drawn at 7 + this value.",
            min = -3, max = 10, step = 1,
            width = 200,
            getFunc = function() return EXT.GetHealthTextSize() end,
            setFunc = function(value) EXT.SetHealthTextSize(value) end,
        })
    end,
}

-- Level: where the level number is drawn. Same control style as Health Text > Position.
PAGES.level = {
    title = "Level",
    build = function(container)
        local C = DUI.PanelControls
        C:AddDescription(container, "Where the level number is drawn. Before the Name is the layout DragonUI uses by default.")
        C:AddSpacer(container)

        local section = C:AddSection(container, "Level")
        C:AddDropdown(section, {
            label = "Position",
            desc = "Before the Name keeps the level inside the name. The outside options draw it beside the health bar.",
            values = {
                beforeName   = "Before the Name",
                outsideLeft  = "Outside the Bar, Left",
                outsideRight = "Outside the Bar, Right",
            },
            width = 260,
            getFunc = function() return EXT.GetLevelPlacement() end,
            setFunc = function(value) EXT.SetLevelPlacement(value) end,
        })
        C:AddDropdown(section, {
            label = "Style",
            desc = "Outline and shadow of the level text. Applies when the level is drawn outside the bar; inside the name it shares the name's style.",
            values = {
                outline = "Outline",
                shadow  = "Shadow",
                both    = "Outline & Shadow",
            },
            width = 260,
            getFunc = function() return EXT.GetLevelStyle() end,
            setFunc = function(value) EXT.SetLevelStyle(value) end,
        })
    end,
}

local window, scroll, currentPage
local RenderPage

-- Nameplates: one sidebar entry under Frames, with Name / Health / Level as sub-tabs, like
-- DragonUI_Options. Each sub-tab is built by the matching PAGES entry above.
local NAMEPLATE_SUBTABS = {
    { key = "name",   label = "Name" },
    { key = "health", label = "Health" },
    { key = "level",  label = "Level" },
}
local activeNameplateSubTab = "name"

PAGES.nameplates = {
    title = "Nameplates",
    build = function(container)
        local C = DUI.PanelControls
        C:AddSubTabs(container, NAMEPLATE_SUBTABS, activeNameplateSubTab, function(key)
            activeNameplateSubTab = key
            RenderPage("nameplates")
        end)
        local sub = PAGES[activeNameplateSubTab]
        if sub and sub.build then sub.build(container) end
    end,
}

-- Sidebar categories, in order. Each tab key is a PAGES key.
local CATEGORIES = {
    { label = "Frames", tabs = { "units", "nameplates" } },
    { label = "Bars",   tabs = { "bars", "additional", "xprep" } },
}

local tabButtons = {}

-- ============================================================================
-- CONTENT
-- ============================================================================

local function BuildPage(container, page)
    if page.build then
        return page.build(container)
    end
    local C = DUI.PanelControls
    C:AddDescription(container, "Show a frame only while you have a target selected. Turning it on turns off hover and combat visibility for that frame.")
    C:AddSpacer(container)

    local section = C:AddSection(container, "Show on Target")
    for _, item in ipairs(page.items) do
        local prefix = item.prefix
        C:AddToggle(section, {
            label = item.label,
            desc = "Show this only while a target is selected.",
            getFunc = function() return EXT.GetShowOnTarget(prefix) end,
            setFunc = function(value) EXT.SetShowOnTarget(prefix, value) end,
        })
    end
end

local function ReleaseScroll()
    if scroll then
        scroll:ReleaseChildren()
        LibStub("AceGUI-3.0"):Release(scroll)
        scroll = nil
    end
end

function RenderPage(key)
    local page = PAGES[key]
    if not page then return end
    currentPage = key

    ReleaseScroll()
    local AceGUI = LibStub("AceGUI-3.0")
    scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")

    local sf = scroll.frame
    sf:SetParent(window.content)
    sf:ClearAllPoints()
    sf:SetPoint("TOPLEFT", window.content, "TOPLEFT", SCROLL_MARGIN, -(HEADER_HEIGHT + SCROLL_MARGIN))
    sf:SetPoint("BOTTOMRIGHT", window.content, "BOTTOMRIGHT", -SCROLL_MARGIN, 4)
    sf:SetFrameStrata("DIALOG")
    sf:Show()
    FUI.SkinScrollBar(scroll)

    scroll.content:SetWidth(CONTENT_WIDTH - SCROLL_CONTENT_OFFSET)
    window.headerTitle:SetText(page.title)
    BuildPage(scroll, page)
    scroll:DoLayout()
    DUI.PanelControls:ReskinAll(scroll)

    for tabKey, btn in pairs(tabButtons) do
        btn:SetSelected(tabKey == key)
    end
end

-- ============================================================================
-- SIDEBAR
-- ============================================================================

local function BuildSidebar(inset)
    local list = CreateFrame("Frame", nil, inset)
    list:SetPoint("TOPLEFT", inset, "TOPLEFT", 1, -LIST_MARGIN_TOP)
    list:SetPoint("BOTTOMLEFT", inset, "BOTTOMLEFT", 1, LIST_MARGIN_TOP)
    list:SetWidth(LIST_WIDTH)

    local y = 0
    for index, category in ipairs(CATEGORIES) do
        local header = FUI.CreateCategoryHeader(list)
        header:SetPoint("TOPLEFT", list, "TOPLEFT", 0, y)
        header:SetIndex(index)
        header:SetLabel(category.label)
        header:Show()
        y = y - (LIST_HEADER_H + 4)

        for _, key in ipairs(category.tabs) do
            local btn = FUI.CreateCategoryButton(list)
            btn:SetSize(ROW_WIDTH, ROW_HEIGHT)
            btn:SetPoint("TOPLEFT", list, "TOPLEFT", ROW_X, y)
            btn:SetLabelLeft(ROW_LABEL_INSET)
            btn:SetText(PAGES[key].title)
            btn:SetScript("OnClick", function() RenderPage(key) end)
            tabButtons[key] = btn
            y = y - ROW_HEIGHT
        end
        y = y - GROUP_GAP
    end
end

-- ============================================================================
-- WINDOW
-- ============================================================================

local function CreateWindow()
    local f = FUI.CreateWindow("DragonUIExtensionsWindow", UIParent, {
        width = WINDOW_WIDTH,
        height = WINDOW_HEIGHT,
        title = "DragonUI |cffffffffExtensions|r",
        inset = true,
        strata = "DIALOG",
        movable = true,
        escClose = true,
        onClose = function() window:Hide() end,
    })
    f:SetPoint("CENTER")

    local inset = f.Inset
    BuildSidebar(inset)

    local content = CreateFrame("Frame", nil, inset)
    content:SetPoint("TOPLEFT", inset, "TOPLEFT", LIST_WIDTH + LIST_GAP + 1, -LIST_MARGIN_TOP)
    content:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -CONTAINER_RIGHT, LIST_MARGIN_TOP)
    f.content = content

    local headerTitle = content:CreateFontString(nil, "ARTWORK")
    headerTitle:SetFontObject(FUI.Fonts.HighlightHuge)
    headerTitle:SetJustifyH("LEFT")
    headerTitle:SetPoint("TOPLEFT", content, "TOPLEFT", 7, -22)
    headerTitle:SetPoint("TOPRIGHT", content, "TOPRIGHT", -7, -22)
    f.headerTitle = headerTitle

    local divider = FUI.CreateDivider(content)
    divider:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -HEADER_HEIGHT)
    divider:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -HEADER_HEIGHT)
    divider:SetHeight(1)

    local close = FUI.CreateButton(f, "Close", CLOSE_BUTTON_W, 22)
    close:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 16)
    close:SetScript("OnClick", function() f:Hide() end)

    window = f
    return f
end

-- DragonUI_Options is a dependency, but it is load-on-demand, so make sure its controls exist.
local function OptionsReady()
    if DUI.PanelControls then return true end
    if not IsAddOnLoaded("DragonUI_Options") then
        LoadAddOn("DragonUI_Options")
    end
    return DUI.PanelControls ~= nil
end

local function Open()
    if InCombatLockdown() then
        print("|cff1784d1DragonUI Extensions|r: cannot open settings during combat.")
        return
    end
    if not OptionsReady() then
        print("|cff1784d1DragonUI Extensions|r: DragonUI_Options is not available.")
        return
    end
    if not window then CreateWindow() end
    RenderPage(currentPage or "units")
    window:Show()
end

local function Toggle()
    if window and window:IsShown() then
        window:Hide()
        ReleaseScroll()
    else
        Open()
    end
end

SLASH_DUIEXT1 = "/duiext"
SlashCmdList["DUIEXT"] = Toggle
