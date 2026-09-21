local ADDON_NAME, NS = ...

local GROUP_ORDER = { 1, 3, 5, 7, 2, 4, 6, 8 }
local DEFAULT_VISIBLE_GROUPS = { true, true, true, true, true, true, false, false }
local raidFrames
local firstHeader, lastHeader
local pendingLayout = false
local eventFrame = CreateFrame("Frame")

local function GetSeparatedProfile()
    local profile = raidFrames and raidFrames.db and raidFrames.db.profile
    if profile and not profile.mergeGroups then return profile end
end

local function CaptureAnchor(frame)
    -- EUI uses one explicit anchor for each header and preview unit. Stand down
    -- if that contract changes instead of discarding additional constraints.
    if frame:GetNumPoints() ~= 1 then return end
    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    return {
        frame = frame,
        point = point,
        relativeTo = relativeTo,
        relativePoint = relativePoint,
        x = x,
        y = y,
    }
end

local function PlaceAnchor(anchor, relativeTo, x, y)
    if anchor.relativeTo == relativeTo and anchor.x == x and anchor.y == y then return end
    anchor.frame:ClearAllPoints()
    anchor.frame:SetPoint(anchor.point, relativeTo, anchor.relativePoint, x, y)
end

local function BuildGroupOrder(blocks, lastGroup)
    local order = {}
    local unpairedGroup = lastGroup % 2 == 1 and lastGroup
    for _, group in ipairs(GROUP_ORDER) do
        if blocks[group] and group ~= unpairedGroup then
            order[#order + 1] = group
        end
    end

    if unpairedGroup then
        order[#order + 1] = unpairedGroup
    end
    return order
end

local function ReorderBlocks(blocks)
    -- Capture every original slot before moving anything. These positions come
    -- from the EUI pass that just finished, including tier overrides and pixel
    -- snapping. Never feed already-reordered positions back through this pass.
    local slots = {}
    local lastGroup
    for group = 1, 8 do
        local block = blocks[group]
        if block then
            slots[#slots + 1] = block[1]
            lastGroup = group
        end
    end

    local origin = slots[1]
    if not origin then return false end

    for group = 1, 8 do
        for _, anchor in ipairs(blocks[group] or {}) do
            if anchor.point ~= origin.point or anchor.relativeTo ~= origin.relativeTo
                or anchor.relativePoint ~= origin.relativePoint then
                return false
            end
        end
    end

    local order = BuildGroupOrder(blocks, lastGroup)
    for slot, group in ipairs(order) do
        local block = blocks[group]
        local dx = slots[slot].x - block[1].x
        local dy = slots[slot].y - block[1].y
        for _, anchor in ipairs(block) do
            PlaceAnchor(anchor, anchor.relativeTo, anchor.x + dx, anchor.y + dy)
        end
    end
    return order
end

local function ReanchorAttachedFrames(owner)
    if InCombatLockdown() or not GetSeparatedProfile() or not firstHeader then return end
    if not owner or not owner.built or not owner.container then return end
    local settings = owner.Settings()
    local position = settings and settings.position
    if position ~= "left" and position ~= "right" then return end

    local anchor = CaptureAnchor(owner.container)
    if not anchor then return end
    for group = 1, 8 do
        if anchor.relativeTo == _G["ERFGroupHeader" .. group] then
            local target = position == "left" and firstHeader or lastHeader
            PlaceAnchor(anchor, target, anchor.x, anchor.y)
            return
        end
    end
    -- EUI can attach bosses to the party or chain them after Extra Frames.
    -- Those anchors already follow their owner and need no adjustment.
end

local function OnRaidLayout()
    if InCombatLockdown() then
        pendingLayout = true
        return
    end

    pendingLayout = false
    firstHeader, lastHeader = nil, nil
    local profile = GetSeparatedProfile()
    if not profile then return end
    local visible = profile.visibleGroups or DEFAULT_VISIBLE_GROUPS
    local occupied
    if profile.hideEmptyGroups ~= false and IsInRaid() then
        occupied = {}
        for index = 1, 40 do
            local _, _, group = GetRaidRosterInfo(index)
            if group then occupied[group] = true end
        end
    end

    local blocks = {}
    for group = 1, 8 do
        local header = _G["ERFGroupHeader" .. group]
        if header and header:IsShown() and visible[group] ~= false
            and (not occupied or occupied[group]) then
            local anchor = CaptureAnchor(header)
            if not anchor then return end
            blocks[group] = { anchor }
        end
    end

    local order = ReorderBlocks(blocks)
    if not order then return end
    firstHeader = blocks[order[1]][1].frame
    lastHeader = blocks[order[#order]][1].frame
    ReanchorAttachedFrames(raidFrames._XF)
    ReanchorAttachedFrames(raidFrames._FB)
end

local function ReorderPreviewFrames(frames)
    if InCombatLockdown() or not GetSeparatedProfile() or not frames then return end
    local blocks = {}
    for index = 1, 40 do
        local frame = frames[index]
        if frame and frame:IsShown() then
            local anchor = CaptureAnchor(frame)
            if not anchor then return end
            local group = math.floor((index - 1) / 5) + 1
            blocks[group] = blocks[group] or {}
            local block = blocks[group]
            block[#block + 1] = anchor
        end
    end
    ReorderBlocks(blocks)
end

local function OnPreviewLayout()
    if not raidFrames.previewActive or not raidFrames.previewActive() then return end
    if not raidFrames._testMode and not EllesmereUI:IsShown() then return end
    ReorderPreviewFrames(raidFrames.previewFrames)
end

local function OnSizePreviewLayout(tier)
    local profile = GetSeparatedProfile()
    local overrides = profile and profile.raidSizeOverrides
    if not overrides or not overrides[tier] then return end
    ReorderPreviewFrames(raidFrames._sizePreviewFrames)
end

local function InstallHooks()
    local registry = EllesmereUI and EllesmereUI._ModuleNS
    raidFrames = registry and registry.EllesmereUIRaidFrames
    if not raidFrames or type(raidFrames._LayoutGroupsImpl) ~= "function" then
        print("|cff0cd29f" .. ADDON_NAME .. "|r: EUI's raid layout interface is unavailable; companion inactive.")
        return
    end

    -- Post-hooks preserve EUI's implementation and its re-entrancy guard.
    -- Only group origins move: secure unit assignments, clicks, and sorting
    -- within each group remain owned by EUI and Blizzard's secure headers.
    hooksecurefunc(raidFrames, "_LayoutGroupsImpl", OnRaidLayout)
    if type(raidFrames.ShowPreview) == "function" then
        hooksecurefunc(raidFrames, "ShowPreview", OnPreviewLayout)
    end
    if type(raidFrames.ApplyPreviewMode) == "function" then
        hooksecurefunc(raidFrames, "ApplyPreviewMode", OnPreviewLayout)
    end
    if type(raidFrames._ShowSizePreview) == "function" then
        hooksecurefunc(raidFrames, "_ShowSizePreview", OnSizePreviewLayout)
    end
    if raidFrames._FB and type(raidFrames._FB.Anchor) == "function" then
        hooksecurefunc(raidFrames._FB, "Anchor", function(owner)
            ReanchorAttachedFrames(owner or raidFrames._FB)
        end)
    end
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
end

local handlers = {}

function handlers.ADDON_LOADED(self, loadedAddon)
    if loadedAddon ~= ADDON_NAME then return end
    self:UnregisterEvent("ADDON_LOADED")
    InstallHooks()
end

function handlers.PLAYER_REGEN_ENABLED()
    if not pendingLayout then return end
    -- Let EUI's own post-combat refresh run first. If it already laid out the
    -- raid, the hook cleared pendingLayout and this callback does no work.
    C_Timer.After(0, function()
        if not pendingLayout or InCombatLockdown() then return end
        if raidFrames.db and type(raidFrames.ReloadFrames) == "function" then
            raidFrames.ReloadFrames()
        end
    end)
end

eventFrame:SetScript("OnEvent", function(self, event, ...)
    local handler = handlers[event]
    if handler then handler(self, ...) end
end)
eventFrame:RegisterEvent("ADDON_LOADED")
