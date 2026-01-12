-- CheckMate.toc
-- ## Interface: 110002
-- ## Title: CheckMate
-- ## Notes: Smart todo list with auto-tracking for daily, weekly and permanent tasks
-- ## Author: YourName
-- ## Version: 2.0.0
-- ## SavedVariables: CheckMateDB
-- CheckMate.lua

-- ============================================
-- CheckMate.lua - Main Addon File with Auto-Tracking
-- ============================================

local addonName, addon = ...
local frame = CreateFrame("Frame", "CheckMateFrame", UIParent, "BasicFrameTemplateWithInset")

-- Initialize saved variables
CheckMateDB = CheckMateDB or {}

-- Auto-tracking keywords and their detection methods
local AUTO_TRACK_KEYWORDS = {
    -- Dungeons
    {pattern = "dungeon", check = function() return true end, event = "CHALLENGE_MODE_COMPLETED"},
    {pattern = "mythic%+", check = function() return true end, event = "CHALLENGE_MODE_COMPLETED"},
    {pattern = "m%+", check = function() return true end, event = "CHALLENGE_MODE_COMPLETED"},
    {pattern = "heroic dungeon", check = function() return true end, event = "LFG_COMPLETION_REWARD"},
    
    -- Raids
    {pattern = "raid", check = function() return true end, event = "BOSS_KILL"},
    {pattern = "boss", check = function() return true end, event = "BOSS_KILL"},
    
    -- PvP
    {pattern = "arena", check = function() return true end, event = "ARENA_MATCH_COMPLETE"},
    {pattern = "battleground", check = function() return true end, event = "UPDATE_BATTLEFIELD_STATUS"},
    {pattern = "bg", check = function() return true end, event = "UPDATE_BATTLEFIELD_STATUS"},
    
    -- World content
    {pattern = "world quest", check = function() return true end, event = "QUEST_TURNED_IN"},
    {pattern = "world boss", check = function() return true end, event = "BOSS_KILL"},
    
    -- Vault
    {pattern = "vault", check = function()
        return C_WeeklyRewards and C_WeeklyRewards.HasAvailableRewards()
    end, event = "WEEKLY_REWARDS_UPDATE"},
    {pattern = "great vault", check = function()
        return C_WeeklyRewards and C_WeeklyRewards.HasAvailableRewards()
    end, event = "WEEKLY_REWARDS_UPDATE"},
}

local function InitializeDB()
    if not CheckMateDB[GetRealmName()] then
        CheckMateDB[GetRealmName()] = {}
    end
    
    local playerName = UnitName("player")
    if not CheckMateDB[GetRealmName()][playerName] then
        CheckMateDB[GetRealmName()][playerName] = {
            dailyTasks = {},
            weeklyTasks = {},
            permanentTasks = {},
            lastDailyReset = date("%Y-%m-%d"),
            lastWeeklyReset = date("%U-%Y"),
            trackedEvents = {}
        }
    end
    
    return CheckMateDB[GetRealmName()][playerName]
end

-- Check if daily reset is needed
local function CheckDailyReset(db)
    local currentDate = date("%Y-%m-%d")
    
    if db.lastDailyReset ~= currentDate then
        db.dailyTasks = {}
        db.lastDailyReset = currentDate
        print("|cff00ff00[CheckMate]|r Daily tasks have been reset!")
    end
end

-- Check if weekly reset is needed
local function CheckWeeklyReset(db)
    local currentWeek = date("%U-%Y")
    
    if db.lastWeeklyReset ~= currentWeek then
        local lastResetWeek = tonumber(string.match(db.lastWeeklyReset, "^(%d+)"))
        local currentWeekNum = tonumber(string.match(currentWeek, "^(%d+)"))
        
        if currentWeekNum > lastResetWeek or (currentWeekNum == 1 and lastResetWeek > 50) then
            db.weeklyTasks = {}
            db.lastWeeklyReset = currentWeek
            print("|cff00ff00[CheckMate]|r Weekly tasks have been reset!")
        end
    end
end

-- Auto-complete tasks based on keywords
local function AutoCompleteTask(taskText, db, taskList)
    if not taskText then return end
    
    local lowerText = string.lower(taskText)
    
    -- Check for keyword matches
    for _, tracker in ipairs(AUTO_TRACK_KEYWORDS) do
        if string.find(lowerText, tracker.pattern) then
            -- Find the task in the list
            for i, task in ipairs(taskList) do
                if string.lower(task.text) == lowerText and not task.completed then
                    if tracker.check() then
                        task.completed = true
                        print("|cff00ff00[CheckMate]|r Auto-completed: " .. task.text)
                        addon:RefreshTasks()
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- Check all tasks for auto-completion
local function CheckAllTasksForCompletion()
    local db = InitializeDB()
    
    -- Check daily tasks
    for _, task in ipairs(db.dailyTasks) do
        if not task.completed and task.autoTrack then
            AutoCompleteTask(task.text, db, db.dailyTasks)
        end
    end
    
    -- Check weekly tasks
    for _, task in ipairs(db.weeklyTasks) do
        if not task.completed and task.autoTrack then
            AutoCompleteTask(task.text, db, db.weeklyTasks)
        end
    end
    
    -- Check permanent tasks
    for _, task in ipairs(db.permanentTasks) do
        if not task.completed and task.autoTrack then
            AutoCompleteTask(task.text, db, db.permanentTasks)
        end
    end
end

-- ============================================
-- UI Setup
-- ============================================

frame:SetSize(450, 700)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:Hide()

frame.title = frame:CreateFontString(nil, "OVERLAY")
frame.title:SetFontObject("GameFontHighlight")
frame.title:SetPoint("TOP", frame.TitleBg, 0, -5)
frame.title:SetText("CheckMate - " .. UnitName("player"))

-- Daily Tasks Section
frame.dailyLabel = frame:CreateFontString(nil, "OVERLAY")
frame.dailyLabel:SetFontObject("GameFontNormalLarge")
frame.dailyLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -30)
frame.dailyLabel:SetText("|cffff6666Daily Tasks|r (Reset: Daily)")

-- Weekly Tasks Section
frame.weeklyLabel = frame:CreateFontString(nil, "OVERLAY")
frame.weeklyLabel:SetFontObject("GameFontNormalLarge")
frame.weeklyLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -230)
frame.weeklyLabel:SetText("|cff4488ffWeekly Tasks|r (Reset: Wednesday)")

-- Permanent Tasks Section
frame.permanentLabel = frame:CreateFontString(nil, "OVERLAY")
frame.permanentLabel:SetFontObject("GameFontNormalLarge")
frame.permanentLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -430)
frame.permanentLabel:SetText("|cffffaa00Permanent Tasks|r")

-- Scroll frames for tasks
local function CreateScrollFrame(parent, name, yOffset)
    local scrollFrame = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, yOffset)
    scrollFrame:SetPoint("BOTTOMRIGHT", parent, "TOPRIGHT", -35, yOffset - 150)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(380, 1)
    scrollFrame:SetScrollChild(scrollChild)
    scrollChild.items = {}
    
    return scrollFrame, scrollChild
end

frame.dailyScroll, frame.dailyContent = CreateScrollFrame(frame, "CheckMateDailyScroll", -55)
frame.weeklyScroll, frame.weeklyContent = CreateScrollFrame(frame, "CheckMateWeeklyScroll", -255)
frame.permanentScroll, frame.permanentContent = CreateScrollFrame(frame, "CheckMatePermanentScroll", -455)

-- Check if task text should be auto-tracked
local function ShouldAutoTrack(text)
    local lowerText = string.lower(text)
    for _, tracker in ipairs(AUTO_TRACK_KEYWORDS) do
        if string.find(lowerText, tracker.pattern) then
            return true
        end
    end
    return false
end

-- Add task input boxes
local function CreateAddTaskSection(parent, yOffset, buttonText, callback)
    local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    editBox:SetSize(280, 30)
    editBox:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, yOffset)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(100)
    
    local addButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    addButton:SetSize(80, 25)
    addButton:SetPoint("LEFT", editBox, "RIGHT", 10, 0)
    addButton:SetText(buttonText)
    addButton:SetScript("OnClick", function()
        local text = editBox:GetText()
        if text and text ~= "" then
            callback(text)
            editBox:SetText("")
            editBox:ClearFocus()
        end
    end)
    
    editBox:SetScript("OnEnterPressed", function()
        addButton:Click()
    end)
    
    return editBox
end

frame.dailyInput = CreateAddTaskSection(frame, -210, "Add", function(text)
    local db = InitializeDB()
    table.insert(db.dailyTasks, {
        text = text, 
        completed = false,
        autoTrack = ShouldAutoTrack(text)
    })
    addon:RefreshTasks()
end)

frame.weeklyInput = CreateAddTaskSection(frame, -410, "Add", function(text)
    local db = InitializeDB()
    table.insert(db.weeklyTasks, {
        text = text, 
        completed = false,
        autoTrack = ShouldAutoTrack(text)
    })
    addon:RefreshTasks()
end)

frame.permanentInput = CreateAddTaskSection(frame, -610, "Add", function(text)
    local db = InitializeDB()
    table.insert(db.permanentTasks, {
        text = text, 
        completed = false,
        autoTrack = ShouldAutoTrack(text)
    })
    addon:RefreshTasks()
end)

-- ============================================
-- Task Rendering
-- ============================================

local function CreateTaskItem(parent, task, index, taskType)
    local item = CreateFrame("Frame", nil, parent)
    item:SetSize(370, 30)
    
    -- Auto-track indicator
    if task.autoTrack then
        local autoIcon = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        autoIcon:SetPoint("LEFT", item, "LEFT", 0, 0)
        autoIcon:SetText("|cff00ff00⚡|r")
        autoIcon:SetTextColor(0, 1, 0)
    end
    
    -- Checkbox
    local checkbox = CreateFrame("CheckButton", nil, item, "UICheckButtonTemplate")
    checkbox:SetPoint("LEFT", item, "LEFT", task.autoTrack and 15 or 0, 0)
    checkbox:SetSize(24, 24)
    checkbox:SetChecked(task.completed)
    
    -- Task text
    local text = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
    text:SetPoint("RIGHT", item, "RIGHT", -30, 0)
    text:SetJustifyH("LEFT")
    text:SetText(task.text)
    
    if task.completed then
        text:SetTextColor(0.5, 0.5, 0.5)
        text:SetText("|cff888888" .. task.text .. "|r")
    end
    
    -- Delete button
    local deleteBtn = CreateFrame("Button", nil, item, "UIPanelButtonTemplate")
    deleteBtn:SetSize(20, 20)
    deleteBtn:SetPoint("RIGHT", item, "RIGHT", 0, 0)
    deleteBtn:SetText("X")
    deleteBtn:SetScript("OnClick", function()
        local db = InitializeDB()
        local tasks
        if taskType == "daily" then
            tasks = db.dailyTasks
        elseif taskType == "weekly" then
            tasks = db.weeklyTasks
        else
            tasks = db.permanentTasks
        end
        table.remove(tasks, index)
        addon:RefreshTasks()
    end)
    
    checkbox:SetScript("OnClick", function()
        task.completed = checkbox:GetChecked()
        addon:RefreshTasks()
    end)
    
    return item
end

function addon:RefreshTasks()
    local db = InitializeDB()
    CheckDailyReset(db)
    CheckWeeklyReset(db)
    
    -- Clear existing items
    for _, item in ipairs(frame.dailyContent.items) do
        item:Hide()
    end
    for _, item in ipairs(frame.weeklyContent.items) do
        item:Hide()
    end
    for _, item in ipairs(frame.permanentContent.items) do
        item:Hide()
    end
    
    wipe(frame.dailyContent.items)
    wipe(frame.weeklyContent.items)
    wipe(frame.permanentContent.items)
    
    -- Render daily tasks
    local yOffset = 0
    for i, task in ipairs(db.dailyTasks) do
        local item = CreateTaskItem(frame.dailyContent, task, i, "daily")
        item:SetPoint("TOPLEFT", frame.dailyContent, "TOPLEFT", 0, yOffset)
        table.insert(frame.dailyContent.items, item)
        yOffset = yOffset - 35
    end
    frame.dailyContent:SetHeight(math.max(1, math.abs(yOffset)))
    
    -- Render weekly tasks
    yOffset = 0
    for i, task in ipairs(db.weeklyTasks) do
        local item = CreateTaskItem(frame.weeklyContent, task, i, "weekly")
        item:SetPoint("TOPLEFT", frame.weeklyContent, "TOPLEFT", 0, yOffset)
        table.insert(frame.weeklyContent.items, item)
        yOffset = yOffset - 35
    end
    frame.weeklyContent:SetHeight(math.max(1, math.abs(yOffset)))
    
    -- Render permanent tasks
    yOffset = 0
    for i, task in ipairs(db.permanentTasks) do
        local item = CreateTaskItem(frame.permanentContent, task, i, "permanent")
        item:SetPoint("TOPLEFT", frame.permanentContent, "TOPLEFT", 0, yOffset)
        table.insert(frame.permanentContent.items, item)
        yOffset = yOffset - 35
    end
    frame.permanentContent:SetHeight(math.max(1, math.abs(yOffset)))
end

-- ============================================
-- Slash Commands
-- ============================================

SLASH_CHECKMATE1 = "/checkmate"
SLASH_CHECKMATE2 = "/cm"
SLASH_CHECKMATE3 = "/check"

SlashCmdList["CHECKMATE"] = function(msg)
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        addon:RefreshTasks()
    end
end

-- ============================================
-- Event Handling
-- ============================================

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Register auto-tracking events
eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
eventFrame:RegisterEvent("BOSS_KILL")
eventFrame:RegisterEvent("QUEST_TURNED_IN")
eventFrame:RegisterEvent("ARENA_MATCH_COMPLETE")
eventFrame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
eventFrame:RegisterEvent("LFG_COMPLETION_REWARD")
eventFrame:RegisterEvent("WEEKLY_REWARDS_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        InitializeDB()
        CheckDailyReset(InitializeDB())
        CheckWeeklyReset(InitializeDB())
        print("|cff00ff00CheckMate|r loaded! Type |cffff8800/checkmate|r, |cffff8800/cm|r or |cffff8800/check|r to open.")
        print("|cff00ff00[CheckMate]|r Auto-tracking enabled! Use keywords like 'dungeon', 'raid', 'vault', 'arena', etc.")
    elseif event == "PLAYER_ENTERING_WORLD" then
        CheckDailyReset(InitializeDB())
        CheckWeeklyReset(InitializeDB())
    else
        -- Auto-tracking events
        CheckAllTasksForCompletion()
    end
end)
