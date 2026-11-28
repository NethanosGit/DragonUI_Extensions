-- DragonUI_Extensions: quest level and difficulty colour on the quest tracker's titles.
--
-- Adds a collector to DragonUI's objective tracker. Collectors run after the quest blocks are
-- gathered and before they are drawn, so the title can be changed there. The colour is written as a
-- colour code inside the text, because DragonUI sets the title's own colour again on every paint.
-- Nothing in DragonUI is edited.
--
-- Relies on DragonUI internals: ObjectiveTracker.AddCollector / Refresh and the block fields
-- kind, title, level, questLogIndex, onEnter and onLeave.
-- Stored as questtracker.extShowLevel and questtracker.extDifficultyColor (nil = on).

local DUI = _G.DragonUI
if not (DUI and DUI.ObjectiveTracker and DUI.ObjectiveTracker.AddCollector) then return end

local OT = DUI.ObjectiveTracker

local EXT = _G.DragonUIExtensions or {}
_G.DragonUIExtensions = EXT

-- How far a hovered title is blended toward white, in place of the highlight the colour code hides.
local HOVER_BLEND = 0.5

local function TrackerProfile()
    return DUI.db and DUI.db.profile and DUI.db.profile.questtracker
end

local function GetSetting(key)
    local node = TrackerProfile()
    return not node or node[key] ~= false
end

local function SetSetting(key, value)
    local node = TrackerProfile()
    if not node then return end
    node[key] = value and true or false
    OT.Refresh()
end

function EXT.GetQuestTrackerLevel()
    return GetSetting("extShowLevel")
end

function EXT.SetQuestTrackerLevel(value)
    SetSetting("extShowLevel", value)
end

function EXT.GetQuestTrackerDifficultyColor()
    return GetSetting("extDifficultyColor")
end

function EXT.SetQuestTrackerDifficultyColor(value)
    SetSetting("extDifficultyColor", value)
end

-- ============================================================================
-- TITLES
-- ============================================================================

local function Colorize(text, r, g, b)
    return string.format("|cff%02x%02x%02x%s|r",
        math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), text)
end

local function Lighten(value)
    return value + (1 - value) * HOVER_BLEND
end

-- Timer blocks carry no level of their own, so it is read from the quest log.
local function QuestLevel(block)
    local level = block.level
    if not level and block.questLogIndex then
        local _, logLevel = GetQuestLogTitle(block.questLogIndex)
        level = logLevel
    end
    -- A level of -1 means the quest scales with the player.
    if level and level <= 0 then level = UnitLevel("player") end
    return level
end

local function Decorate(block, showLevel, useColor)
    local level = QuestLevel(block)
    if not (level and block.title) then return end

    local text = block.title
    if showLevel then text = "[" .. level .. "] " .. text end

    local color = useColor and GetQuestDifficultyColor(level)
    if not color then
        block.title = text
        return
    end

    local idle = Colorize(text, color.r, color.g, color.b)
    local hover = Colorize(text, Lighten(color.r), Lighten(color.g), Lighten(color.b))
    block.title = idle
    block.onEnter = function(row) row.title:SetText(hover) end
    block.onLeave = function(row) row.title:SetText(idle) end
end

OT.AddCollector(function(blocks)
    local showLevel = EXT.GetQuestTrackerLevel()
    local useColor = EXT.GetQuestTrackerDifficultyColor()
    if not (showLevel or useColor) then return end
    for _, block in ipairs(blocks) do
        if block.kind == "quest" or block.kind == "timer" then
            Decorate(block, showLevel, useColor)
        end
    end
end)

-- The difficulty colour depends on the player's level, which the tracker does not watch. UnitLevel
-- can still report the old level while PLAYER_LEVEL_UP fires, so the redraw waits one frame.
local levelWatch = CreateFrame("Frame")
levelWatch:Hide()
levelWatch:RegisterEvent("PLAYER_LEVEL_UP")
levelWatch:SetScript("OnEvent", function(self) self:Show() end)
levelWatch:SetScript("OnUpdate", function(self)
    self:Hide()
    OT.Refresh()
end)
