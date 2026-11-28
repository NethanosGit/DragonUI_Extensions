-- DragonUI_Extensions: sectioned inventory for Bagster.
--
-- Replaces Bagster's category tabs with one view where the items are split into labelled sections:
-- a top row (Hearthstone, Potion, Food, Consumable, Ammo, Devices, Quest), then Equipment (Armor,
-- Weapon, Trinket, BOE), Crafting, Miscellaneous, Keys, and Empty (one slot showing how many are free).
-- The rarity filter, search and bag column stay as they are. Applies to the inventory only, not the bank.
--
-- Nothing in DragonUI is edited. Relies on DragonUI.BagsterModule internals: the ItemFrame.Layout/UpdateSlot,
-- SideFilter/BottomFilter.UpdateFilters, Frame.SetCategory/SetSubCategory and ItemSlot.Update/Set/Free methods.
-- The setting is stored as modules.bagster.extSections in DragonUI's profile.

local DUI = _G.DragonUI
local mod = DUI and DUI.BagsterModule
if not (mod and mod.ItemFrame and mod.Frame and mod.SideFilter and mod.BottomFilter and mod.ItemSlot) then
    return
end

local EXT = _G.DragonUIExtensions or {}
_G.DragonUIExtensions = EXT

local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min

local ItemFrame, Frame, ItemSlot = mod.ItemFrame, mod.Frame, mod.ItemSlot

-- ============================================================================
-- SETTINGS
-- ============================================================================

local function Node()
    return DUI.db and DUI.db.profile and DUI.db.profile.modules and DUI.db.profile.modules.bagster
end

function EXT.IsBagsterSections()
    local node = Node()
    return node ~= nil and node.extSections == true
end

local function Active(frame)
    return frame ~= nil and not frame.isBank and EXT.IsBagsterSections()
end

local function Collapsed()
    local node = Node()
    if not node then return {} end
    node.extCollapsed = node.extCollapsed or {}
    return node.extCollapsed
end

function EXT.SetBagsterSections(value)
    local node = Node()
    if not node then return end
    node.extSections = value and true or false
    for _, f in pairs(mod.frames or {}) do
        if not f.isBank and f.sideFilter then
            f:UpdateSets()
            f:UpdateClampInsets()
            if f.itemFrame then
                f.itemFrame:Regenerate()
                f.itemFrame:RequestLayout()
            end
        end
    end
end

-- ============================================================================
-- TABS OFF, NO CATEGORY FILTER
-- ============================================================================

local origSideUpdate = mod.SideFilter.UpdateFilters
function mod.SideFilter:UpdateFilters()
    if Active(self:GetParent()) then
        self:Hide()
        return
    end
    return origSideUpdate(self)
end

local origBottomUpdate = mod.BottomFilter.UpdateFilters
function mod.BottomFilter:UpdateFilters()
    local parent = self:GetParent()
    if Active(parent) then
        self:Hide()
        parent:UpdateClampInsets()
        return
    end
    return origBottomUpdate(self)
end

local origSetCategory = Frame.SetCategory
function Frame:SetCategory(name)
    if Active(self) then
        self:SetFilter("rule", nil)
        self:SetFilter("subRule", nil)
        return
    end
    return origSetCategory(self, name)
end

local origSetSubCategory = Frame.SetSubCategory
function Frame:SetSubCategory(name)
    if Active(self) then
        self:SetFilter("subRule", nil)
        return
    end
    return origSetSubCategory(self, name)
end

-- Smaller icon and pinned draw order, on sectioned inventory slots only. Slots are pooled and shared
-- with the bank, so a slot that stops qualifying is put back the way Bagster skins it.
local function SetSectionChrome(self, enable)
    if not enable and not self._extChrome then return end
    self._extChrome = enable or nil

    local ring = self._dragonuiSlotBorder
    local name = self:GetName()
    local icon = name and _G[name .. "IconTexture"]
    local count = name and _G[name .. "Count"]
    -- The ring, icon and count share the BORDER layer; pin their order so the ring never ends up above the icon.
    if ring then ring:SetDrawLayer("BORDER", 0) end
    if icon then
        icon:SetDrawLayer("BORDER", enable and 1 or 0)
        -- Sectioned inventory: icon 2px smaller on every side.
        local inset = enable and 2 or 0
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", self, "TOPLEFT", inset, -inset)
        icon:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -inset, inset)
    end
    if count then count:SetDrawLayer("BORDER", enable and 2 or 0) end
end

local function UpdateSectionChrome(self)
    SetSectionChrome(self, not self:IsBank() and EXT.IsBagsterSections())
end

-- Drops the free-slot total from a slot and shows its real stack count again.
local function ClearEmptyCount(self)
    if not self._extEmptyCount then return end
    self._extEmptyCount = nil
    local _, count = self:GetItemSlotInfo()
    SetItemButtonCount(self, count)
end

-- The Empty section shows one slot carrying the free-slot total; keep the count when the slot refreshes.
local origItemUpdate = ItemSlot.Update
function ItemSlot:Update()
    origItemUpdate(self)
    UpdateSectionChrome(self)
    if self._extEmptyCount then
        if self:GetItemSlotInfo() then
            -- An item went into the slot: its own stack count applies.
            ClearEmptyCount(self)
        else
            SetItemButtonCount(self, self._extEmptyCount)
        end
    end
end

-- A new slot is skinned after its first Update, which resets the icon, so apply ours again.
local origItemSet = ItemSlot.Set
function ItemSlot:Set(parent, bag, slot)
    origItemSet(self, parent, bag, slot)
    self._extChrome = nil
    UpdateSectionChrome(self)
end

-- Released slots go back to the pool clean.
local origItemFree = ItemSlot.Free
function ItemSlot:Free()
    self._extKind = nil
    if self._extEmptyCount then
        self._extEmptyCount = nil
        SetItemButtonCount(self, 0)
    end
    SetSectionChrome(self, false)
    return origItemFree(self)
end

-- ============================================================================
-- CLASSIFICATION
-- ============================================================================

local HEARTHSTONE_ID = 6948

local labels
local function Labels()
    if labels then return labels end
    local enUS = (GetLocale() == "enUS")
    local consumables = { GetAuctionItemSubClasses(4) }
    labels = {
        hearth     = GetItemInfo(HEARTHSTONE_ID) or "Hearthstone",
        potion     = enUS and "Potion" or consumables[2] or "Potion",
        food       = enUS and "Food" or consumables[1] or "Food",
        consumable = mod.L.Consumable or "Consumable",
        ammo       = AMMOSLOT or "Ammo",
        devices    = mod.L.Devices or "Devices",
        quest      = mod.L.Quest or "Quest",
        equipment  = mod.GetSetDisplayName("Equipment"),
        armor      = mod.L.Armor or "Armor",
        weapon     = mod.L.Weapon or "Weapon",
        trinket    = INVTYPE_TRINKET or "Trinket",
        boe        = "BOE",
        crafting   = "Crafting",
        tradegood  = mod.L.TradeGood or "Trade Goods",
        gem        = mod.L.Gem or "Gem",
        recipe     = mod.L.Recipe or "Recipe",
        misc      = mod.L.Misc or "Miscellaneous",
        keys      = "Keys",
        empty      = EMPTY or "Empty",
    }
    -- Names GetItemInfo reports for the consumable subtypes that get their own column.
    labels.potionSub = { Potion = true, [consumables[2] or "Potion"] = true }
    labels.foodSub = { ["Food & Drink"] = true, [consumables[1] or "Food & Drink"] = true }
    -- Arrows and bullets (item class "Projectile").
    labels.projectileType = select(7, GetAuctionItemClasses()) or "Projectile"
    return labels
end

local scanner

-- True when the item in this slot is still unbound and binds when equipped. Only the slot tooltip tells:
-- a soulbound copy shows "Soulbound" on that line instead.
local function IsBindOnEquip(bag, slot)
    if not scanner then
        scanner = CreateFrame("GameTooltip", "DragonUIExtensionsScanTooltip", nil, "GameTooltipTemplate")
    end
    scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanner:ClearLines()
    scanner:SetBagItem(bag, slot)
    -- The binding line sits right under the name, after any extra lines such as "Heroic".
    for i = 2, min(scanner:NumLines(), 5) do
        local line = _G["DragonUIExtensionsScanTooltipTextLeft" .. i]
        if line and line:GetText() == ITEM_BIND_ON_EQUIP then return true end
    end
    return false
end

-- Returns the bucket key for an item link in the given bag slot; nil link means an empty slot.
-- cached: the slot is saved data (another character), so there is no live item to scan.
local function Classify(link, bag, slot, cached)
    if not link then return "empty" end
    -- Anything in the keyring is a key, whatever item type the game reports for it.
    if bag == KEYRING_CONTAINER then return "keys" end
    local id = tonumber(link:match("item:(%d+)"))
    if id == HEARTHSTONE_ID then return "hearth" end

    local _, _, _, _, _, itype, subType, _, equipLoc = GetItemInfo(link)
    if not itype then return "misc" end

    local L = Labels()
    if itype == mod.L.Quest then
        return "quest"
    elseif itype == mod.L.Consumable then
        if L.potionSub[subType] then return "potion" end
        if L.foodSub[subType] then return "food" end
        return "consumable"
    elseif itype == mod.L.TradeGood then
        if subType == mod.L.Devices or subType == mod.L.Explosives then return "devices" end
        return "tradegood"
    elseif itype == mod.L.Armor or itype == mod.L.Weapon then
        if not cached and IsBindOnEquip(bag, slot) then return "boe" end
        if itype == mod.L.Weapon then return "weapon" end
        return (equipLoc == "INVTYPE_TRINKET") and "trinket" or "armor"
    elseif itype == mod.L.Gem then
        return "gem"
    elseif itype == L.projectileType then
        return "ammo"
    elseif itype == mod.L.Recipe then
        return "recipe"
    end
    return "misc"
end

-- ============================================================================
-- HEADERS (pooled, parented to the item frame)
-- ============================================================================

local HEAD_H, LABEL_H = 22, 14
local LINE_GAP, SECTION_GAP, BLOCK_GAP = 4, 8, 0.4
local MIN_SCALE = 0.7

local function SetArrow(tex, collapsed)
    local name = collapsed and "common-button-dropdown-closed" or "common-button-dropdown-open"
    local fui = DUI.ForeverUI
    if fui and fui.SetAtlas then
        pcall(fui.SetAtlas, tex, name, false)
    end
    tex:SetSize(18, 18)
end

local function AcquireHeader(self, index)
    local pool = self._extHeaders
    if not pool then
        pool = {}
        self._extHeaders = pool
    end
    local h = pool[index]
    if not h then
        h = CreateFrame("Button", nil, self)
        h.indicator = h:CreateTexture(nil, "ARTWORK")
        h.indicator:SetPoint("LEFT", h, "LEFT", 0, 0)
        h.label = h:CreateFontString(nil, "ARTWORK")
        local hover = h:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints(h)
        hover:SetTexture(1, 1, 1, 0.07)
        h.hover = hover
        h:SetScript("OnClick", function(btn)
            if not btn.sectionKey then return end
            local state = Collapsed()
            state[btn.sectionKey] = not state[btn.sectionKey] or nil
            local itemFrame = btn:GetParent()
            itemFrame:RequestLayout()
        end)
        pool[index] = h
    end
    return h
end

local function HideHeaders(self)
    for _, h in ipairs(self._extHeaders or {}) do h:Hide() end
end

-- ============================================================================
-- LAYOUT
-- ============================================================================

local function ToIndex(bag, slot)
    return (bag < 0 and bag * 100 - slot) or (bag * 100 + slot)
end

-- sections: { { key, title, collapsible, blocks = { { label, items } } } }. Places everything (or only
-- measures when apply is false) at scale s and returns the height used.
local function Flow(self, sections, s, size, width, apply, placed)
    local cell = size * s
    local cols = max(1, floor(width / cell))
    local collapsed = Collapsed()
    local y, headerIndex = 0, 0

    local function Header(x, top, w, text, big, key, isCollapsed, collapsible, truncate)
        headerIndex = headerIndex + 1
        local h = AcquireHeader(self, headerIndex)
        h.sectionKey = (big and collapsible) and key or nil
        h:ClearAllPoints()
        -- Small category labels sit 2px higher than their row.
        h:SetPoint("TOPLEFT", self, "TOPLEFT", x, -top + (big and 0 or 2))
        h:SetSize(w, big and HEAD_H or LABEL_H)
        h.label:ClearAllPoints()
        if big and collapsible then
            h.label:SetFontObject(GameFontNormal)
            h.label:SetPoint("LEFT", h, "LEFT", 22, 0)
            SetArrow(h.indicator, isCollapsed)
            h.indicator:Show()
            h.hover:Show()
            h:EnableMouse(true)
        elseif big then
            -- Plain title: no arrow, no click.
            h.label:SetFontObject(GameFontNormal)
            h.label:SetPoint("LEFT", h, "LEFT", 4, 0)
            h.indicator:Hide()
            h.hover:Hide()
            h:EnableMouse(false)
        else
            h.label:SetFontObject(GameFontNormalSmall)
            h.label:SetPoint("LEFT", h, "LEFT", 1, 0)
            h.indicator:Hide()
            h.hover:Hide()
            h:EnableMouse(false)
        end
        h.label:SetText(text)
        if truncate then
            -- Cut the label to the button width and end it with "...".
            local len = #text
            while len > 1 and h.label:GetStringWidth() > w do
                len = len - 1
                h.label:SetText(text:sub(1, len) .. "...")
            end
        end
        h:Show()
    end

    for _, sec in ipairs(sections) do
        local isCollapsed = sec.collapsible and collapsed[sec.key]
        if sec.title then
            if apply then Header(0, y, width, sec.title, true, sec.key, isCollapsed, sec.collapsible) end
            y = y + HEAD_H
        end
        if not isCollapsed then
            local used, lineH = 0, 0
            for _, block in ipairs(sec.blocks) do
                local n = #block.items
                -- Items wrap only at the bag's width. A block that does not fit beside the previous
                -- ones starts a new line instead of being squeezed into the space left.
                local w = min(n, cols)
                if used > 0 and used + w > cols then
                    y = y + lineH + LINE_GAP
                    used, lineH = 0, 0
                end
                local labelH = block.label and LABEL_H or 0
                local rows = ceil(n / w)
                if apply then
                    if block.label then
                        -- Only the Hearthstone label is cut to its one-slot block; the others show in full.
                        local cut = (block.key == "hearth")
                        Header(used * cell, y, cut and (w * cell - 2) or max(w * cell, 40), block.label, false, nil, nil, nil, cut)
                    end
                    for i, item in ipairs(block.items) do
                        local col, row = (i - 1) % w, floor((i - 1) / w)
                        item:ClearAllPoints()
                        item:SetScale(s)
                        item:SetPoint("TOPLEFT", self, "TOPLEFT",
                            (used + col) * cell / s, -(y + labelH + row * cell) / s)
                        item:Show()
                        placed[item] = true
                    end
                end
                used = used + w + BLOCK_GAP
                lineH = max(lineH, labelH + rows * cell)
            end
            y = y + lineH
        end
        y = y + SECTION_GAP
    end
    return y - SECTION_GAP
end

local function SectionLayout(self, parent)
    local width, height = self:GetWidth(), self:GetHeight()
    if width <= 0 or height <= 0 then return end

    local cfg = mod.GetModuleConfig()
    local spacing = (cfg and cfg.item_spacing) or 2
    local size = 37 + spacing
    local cap = (cfg and cfg.item_scale) or 1

    -- Items in bag order, bucketed by kind.
    local L = Labels()
    local buckets = {}
    for key in pairs(L) do buckets[key] = {} end
    local emptyItems = {}
    local items = self.items
    for _, bag in ipairs(self.bags) do
        local numSlots = self:GetBagSize(bag)
        if numSlots > 0 and parent:IsShowingBag(bag) then
            for slot = 1, numSlots do
                local item = items[ToIndex(bag, slot)]
                if item then
                    local key = Classify(self:GetItemLink(bag, slot), bag, slot, self:IsBagCached(bag))
                    item._extKind = key
                    if key == "empty" then
                        -- Empty keyring slots are not bag space; they stay hidden.
                        if bag ~= KEYRING_CONTAINER then
                            emptyItems[#emptyItems + 1] = item
                        end
                    else
                        local list = buckets[key]
                        list[#list + 1] = item
                    end
                end
            end
        end
    end

    local sections = {}
    local function Add(key, title, collapsible, blockDefs)
        local blocks = {}
        for _, def in ipairs(blockDefs) do
            local list = buckets[def[1]]
            if list and #list > 0 then
                blocks[#blocks + 1] = { key = def[1], label = def[2], items = list }
            end
        end
        if #blocks > 0 then
            sections[#sections + 1] = { key = key, title = title, collapsible = collapsible, blocks = blocks }
        end
    end

    Add("top", nil, false, {
        { "hearth", L.hearth }, { "potion", L.potion }, { "food", L.food },
        { "consumable", L.consumable }, { "ammo", L.ammo }, { "devices", L.devices },
        { "quest", L.quest },
    })
    Add("equipment", L.equipment, true, {
        { "armor", L.armor }, { "weapon", L.weapon }, { "trinket", L.trinket }, { "boe", L.boe },
    })
    Add("crafting", L.crafting, true, {
        { "tradegood", L.tradegood }, { "gem", L.gem }, { "recipe", L.recipe },
    })
    Add("misc", L.misc, true, { { "misc" } })
    Add("keys", L.keys, true, { { "keys" } })

    -- Empty: one slot standing for all of them, labelled with the total.
    local emptyCount = #emptyItems
    local emptyRep = emptyItems[1]
    if emptyRep then
        buckets.emptyRep = { emptyRep }
        Add("empty", nil, false, { { "emptyRep", L.empty } })
    end

    -- Icons always keep the configured size; when the rows do not fit, the frame grows instead.
    local s = max(cap, MIN_SCALE)
    local total = Flow(self, sections, s, size, width, false)

    local placed = {}
    for _, h in ipairs(self._extHeaders or {}) do h:Hide() end
    Flow(self, sections, s, size, width, true, placed)

    for _, item in pairs(items) do
        if not placed[item] then item:Hide() end
        if item ~= emptyRep then ClearEmptyCount(item) end
    end
    if emptyRep then
        emptyRep._extEmptyCount = emptyCount
        SetItemButtonCount(emptyRep, emptyCount)
    end

    if total > height + 1 then
        local target = min(parent:GetHeight() + (total - height), UIParent:GetHeight() * 0.9)
        if target > parent:GetHeight() + 1 then
            parent:SetHeight(target)
        end
    end
end

local origLayout = ItemFrame.Layout
function ItemFrame:Layout()
    local parent = self:GetParent()
    if parent and Active(parent) then
        SectionLayout(self, parent)
        return
    end
    -- Classic grid: drop the section extras before it takes over.
    HideHeaders(self)
    for _, item in pairs(self.items) do
        ClearEmptyCount(item)
    end
    return origLayout(self)
end

-- Bagster only re-arranges when slots appear or disappear. Sections also depend on what a slot holds,
-- so re-arrange when that changes.
local origUpdateSlot = ItemFrame.UpdateSlot
function ItemFrame:UpdateSlot(bag, slot, link)
    local changed = origUpdateSlot(self, bag, slot, link)
    local parent = self:GetParent()
    if parent and Active(parent) then
        local item = self.items[ToIndex(bag, slot)]
        if item and item._extKind
            and item._extKind ~= Classify(self:GetItemLink(bag, slot), bag, slot, self:IsBagCached(bag)) then
            self:RequestLayout()
        end
    end
    return changed
end
