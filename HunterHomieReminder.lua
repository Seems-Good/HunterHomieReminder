-- HunterHomieReminder.lua
-- BM/Survival only. Shows when main pet is dead or missing.
-- Right-click: lock/unlock | Drag: move | Corner grip: resize

local addonName, addon = ...
local L = addon.L
local BASE_W, BASE_H = 260, 70

-- ============================================================
--  Frame
-- ============================================================
local frame = CreateFrame("Frame", "HunterHomieReminderFrame", UIParent, "BackdropTemplate")
frame:SetSize(BASE_W, BASE_H)
frame:SetFrameStrata("HIGH")
frame:SetMovable(true)
frame:SetResizable(false) -- we handle scale manually, not frame resizing
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:Hide()

frame:SetBackdrop({
    bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 14,
    insets   = { left = 4, right = 4, top = 4, bottom = 4 },
})
frame:SetBackdropColor(0.25, 0, 0, 0.92)
frame:SetBackdropBorderColor(0.9, 0.1, 0.1, 1)

-- Skull icon
local skull = frame:CreateTexture(nil, "ARTWORK")
skull:SetSize(38, 38)
skull:SetPoint("LEFT", frame, "LEFT", 12, 0)
skull:SetTexture("Interface/TargetingFrame/UI-TargetingFrame-Skull")

-- Main label
local mainLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
mainLabel:SetPoint("TOPLEFT", skull, "TOPRIGHT", 10, -4)
mainLabel:SetPoint("RIGHT",   frame, "RIGHT",    -10,  0)
mainLabel:SetJustifyH("LEFT")
mainLabel:SetTextColor(1, 0.25, 0.25)
mainLabel:SetText(L.NO_PET)

-- Flash animation
local flashGroup = mainLabel:CreateAnimationGroup()
flashGroup:SetLooping("REPEAT")
local fadeOut = flashGroup:CreateAnimation("Alpha")
fadeOut:SetFromAlpha(1)
fadeOut:SetToAlpha(0.15)
fadeOut:SetDuration(0.6)
fadeOut:SetOrder(1)
fadeOut:SetSmoothing("IN_OUT")
local fadeIn = flashGroup:CreateAnimation("Alpha")
fadeIn:SetFromAlpha(0.15)
fadeIn:SetToAlpha(1)
fadeIn:SetDuration(0.6)
fadeIn:SetOrder(2)
fadeIn:SetSmoothing("IN_OUT")

-- Sub label
local subLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
subLabel:SetPoint("BOTTOMLEFT", skull, "BOTTOMRIGHT", 10, 6)
subLabel:SetPoint("RIGHT",      frame, "RIGHT",       -20, 0)
subLabel:SetJustifyH("LEFT")
subLabel:SetTextColor(1, 0.75, 0.75)
subLabel:SetText(L.HELP_HOMIE)

-- ============================================================
--  Resize grip (bottom-right corner) — scale-based, real-time
-- ============================================================
local resizeGrip = CreateFrame("Frame", nil, frame)
resizeGrip:SetSize(16, 16)
resizeGrip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
resizeGrip:EnableMouse(true)
resizeGrip:RegisterForDrag("LeftButton")

local gripTex = resizeGrip:CreateTexture(nil, "OVERLAY")
gripTex:SetAllPoints()
gripTex:SetTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up")

local isDraggingScale = false
local dragStartX, dragStartScale

resizeGrip:SetScript("OnDragStart", function()
    if InCombatLockdown() or HunterHomieReminderDB.locked then return end
    isDraggingScale = true
    dragStartX = select(1, GetCursorPosition())
    dragStartScale = frame:GetScale()
end)

resizeGrip:SetScript("OnDragStop", function()
    isDraggingScale = false
    HunterHomieReminderDB.scale = frame:GetScale()
end)

-- OnUpdate drives the real-time scale while dragging
resizeGrip:SetScript("OnUpdate", function()
    if not isDraggingScale then return end
    local curX = select(1, GetCursorPosition())
    local delta = (curX - dragStartX) / 200  -- sensitivity
    local newScale = math.max(0.5, math.min(2.5, dragStartScale + delta))
    frame:SetScale(newScale)
end)

-- ============================================================
--  Persist helpers
-- ============================================================
local function SavePos()
    local x, y = frame:GetCenter()
    local cx, cy = UIParent:GetCenter()
    HunterHomieReminderDB.posX = x - cx
    HunterHomieReminderDB.posY = y - cy
end

-- ============================================================
--  Lock state
-- ============================================================
local function ApplyLockState()
    local locked = HunterHomieReminderDB.locked
    frame:SetMovable(not locked)
    frame:SetResizable(not locked)
    resizeGrip:SetShown(not locked)
end

-- ============================================================
--  Drag
-- ============================================================
frame:SetScript("OnDragStart", function(self)
    if not InCombatLockdown() and not HunterHomieReminderDB.locked then
        self:StartMoving()
    end
end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePos()
end)

-- ============================================================
--  Right-click to toggle lock
-- ============================================================
frame:SetScript("OnMouseUp", function(self, btn)
    if btn == "RightButton" and not InCombatLockdown() then
        HunterHomieReminderDB.locked = not HunterHomieReminderDB.locked
        ApplyLockState()
    end
end)

-- ============================================================
--  Tooltip — only show instructions when unlocked
-- ============================================================
frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("|cffff4444" .. L.ADDON_TITLE .. "|r")
    if HunterHomieReminderDB.locked then
        GameTooltip:AddLine(L.TT_UNLOCK, 0.8, 0.8, 0.8)
    else
        GameTooltip:AddLine(L.TT_DRAG, 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L.TT_RESIZE, 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L.TT_LOCK, 0.8, 0.8, 0.8)
    end
    GameTooltip:Show()
end)
frame:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- ============================================================
--  Show/hide flash
-- ============================================================
frame:SetScript("OnShow", function()
    flashGroup:Play()
    ApplyLockState() -- re-enforce grip visibility every time frame appears
end)
frame:SetScript("OnHide", function()
    flashGroup:Stop()
end)

-- ============================================================
--  State driver
-- ============================================================
local UNBREAKABLE_BOND_TALENT = 1223323

local function CanHavePet()
    local _, class = UnitClass("player")
    if class ~= "HUNTER" then return false end
    local spec = GetSpecialization()
    if spec == 2 then
        -- Marksmanship: only if Unbreakable Bond talent is selected
        return IsPlayerSpell(UNBREAKABLE_BOND_TALENT)
    end
    -- Beast Mastery (1) and Survival (3) always have a pet
    return true
end

local function ApplyStateDriver()
    if CanHavePet() then
        RegisterStateDriver(frame, "visibility", "[nopet][@pet,dead] show; hide")
    else
        UnregisterStateDriver(frame, "visibility")
        frame:Hide()
    end
end

-- ============================================================
--  Events
-- ============================================================
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
events:RegisterEvent("TRAIT_CONFIG_UPDATED")
events:RegisterEvent("PET_BATTLE_OPENING_START")
events:RegisterEvent("PET_BATTLE_CLOSE")

events:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if not HunterHomieReminderDB then
            HunterHomieReminderDB = { posX = 0, posY = 100, scale = 1.0, locked = false }
        end
        local db = HunterHomieReminderDB
        if db.locked == nil then db.locked = false  end
        if db.posX   == nil then db.posX   = 0      end
        if db.posY   == nil then db.posY   = 100    end
        if db.scale  == nil then db.scale  = 1.0    end

        frame:SetScale(db.scale)
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", db.posX, db.posY)
        ApplyLockState()
        return
    end

    if event == "PET_BATTLE_OPENING_START" then
        UnregisterStateDriver(frame, "visibility")
        frame:Hide()
        return
    end

    ApplyStateDriver()
end)
