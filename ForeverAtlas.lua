-- DragonUI_Extensions: atlas for the WoW Forever nameplate style.
--
-- Rects and slice margins come from DragonUI pull request #586 (https://github.com/NeticSoul/DragonUI/pull/586),
-- generated there from the WoW Forever client wowf 1.60.1.70532. The artwork in Textures\Forever is
-- copyright Blizzard Entertainment; see Textures\Forever\provenance.json.

local DUI = _G.DragonUI
local A = DUI and DUI.Nameplates and DUI.Nameplates.atlas
if not (A and A.KEYS) then return end

local EXT = _G.DragonUIExtensions or {}
_G.DragonUIExtensions = EXT

local F = "Interface\\AddOns\\DragonUI_Extensions\\Textures\\Forever\\"

-- file, left, right, top, bottom, native w, native h, then nine-slice margins l/t/r/b.
local keys = {
    barBg = { F .. "barBg", 0, 0.515625, 0, 0.59375, 132, 19, 12, 7, 10, 11 },
    barFill = { F .. "barFill", 0, 0.96875, 0, 0.625, 124, 10, 4, 5, 4, 4 },
    selected = { F .. "selected", 0, 0.515625, 0, 1, 132, 16, 8, 7, 8, 7 },
    deselected = { F .. "deselected", 0, 0.8203125, 0, 0.75, 210, 12, 5, 5, 5, 5 },
    levelBg = { F .. "levelBg", 0, 0.9375, 0, 0.9375, 15, 15, 6, 6, 5, 5 },
    levelSelected = { F .. "levelSelected", 0, 0.875, 0, 0.6875, 28, 22, 7, 7, 7, 7 },
    levelSkull = { F .. "levelSkull", 0, 0.8125, 0, 0.8125, 26, 26, 0, 0, 0, 0 },
    castBg = { F .. "castBg", 0, 0.82421875, 0, 0.8125, 211, 13, 0, 0, 0, 0 },
    castFrame = { F .. "castFrame", 0, 0.83203125, 0, 0.9375, 213, 15, 12, 6, 12, 6 },
    castGlow = { F .. "castGlow", 0, 0.83203125, 0, 0.9375, 213, 15, 0, 0, 0, 0 },
    castGlowChannel = { F .. "castGlowChannel", 0, 0.83203125, 0, 0.9375, 213, 15, 0, 0, 0, 0 },
    castShield = { F .. "castShield", 0, 0.875, 0, 1, 14, 16, 0, 0, 0, 0 },
    castSpark = { F .. "castSpark", 0, 0.625, 0, 1, 10, 4, 0, 0, 0, 0 },
}

-- DragonUI key name -> Forever key name, used while the style is on.
EXT.FOREVER_KEYS = {}
for key, value in pairs(keys) do
    A.KEYS["forever_" .. key] = value
    EXT.FOREVER_KEYS[key] = "forever_" .. key
end

EXT.FOREVER_CAST_FILL = {
    standard = F .. "cast-fill-standard",
    channel = F .. "cast-fill-channel",
    interrupted = F .. "cast-fill-interrupted",
    uninterruptible = F .. "cast-fill-uninterruptible",
}
