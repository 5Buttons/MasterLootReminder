local MasterLootReminder = LibStub("AceAddon-3.0"):NewAddon("MasterLootReminder", "AceEvent-3.0", "AceConsole-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("MasterLootReminder", true)

local LibBabbleBoss = LibStub("LibBabble-Boss-3.0")
local BossCheck = LibBabbleBoss:GetUnstrictLookupTable()

MasterLootReminder.visible = false
MasterLootReminder.bossName = "_NONE_"
--MasterLootReminder.Ignored = {}
MasterLootReminder.inCombat = false
MasterLootReminder.lastBossEncountered = nil

--Vashj state tracking
MasterLootReminder.vashjEncounter = false
MasterLootReminder.vashjPhase3 = false
MasterLootReminder.vashjPhase1Handled = false


-- Default settings
local defaults = {
    profile = {
        Enable = true,
        Type = 2, -- 1 = Party only, 2 = Raid only, 3 = Both
        Ignored = {},
        GroupLootReminder = true
    }
}

function MasterLootReminder:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("MasterLootReminderDB", defaults)
    
    -- Register slash commands
    self:RegisterChatCommand("mlr", "ChatCommand")
    self:RegisterChatCommand("masterlootreminder", "ChatCommand")
    
    -- Create options table
    local options = {
        name = "MasterLootReminder",
        handler = MasterLootReminder,
        type = "group",
        args = {
            enable = {
                name = "Enable",
                desc = "Enable/Disable 'Master Loot Reminder'",
                type = "toggle",
                get = "GetEnable",
                set = "SetEnable",
                order = 1,
            },
            type = {
                name = "ML Party/Raid/Both",
                desc = "1 = Party only, 2 = Raid only, 3 = Both",
                type = "range",
                get = "GetType",
                set = "SetType",
                min = 1,
                max = 3,
                step = 1,
                order = 2
            },
            grouploot = {
                name = "Post-Boss Group Loot Reminder",
                desc = "Enable group loot reminder after boss fights",
                type = "toggle",
                get = function() return self.db.profile.GroupLootReminder end,
                set = function(info, value) self.db.profile.GroupLootReminder = value end,
                order = 3
            },
            ignoreTarget = {
                name = "Add target to ignore list",
                desc = "Add target to permanent ignore list",
                type = "execute",
                func = "IgnoreTarget",
                order = 4
            },
            pIgnore = {
                type = 'group',
                name = "Permanent ignore list options",
                desc = "Permanent ignore list options",
                args = {                
                    reset = {
                        name = "Reset ignore list",
                        desc = "Reset permanent ignore list",
                        type = "execute",
                        func = "ResetPermanentIgnoreList",
                    },
                    list = {
                        name = "View ignore list",
                        desc = "View permanent ignore list",
                        type = "execute",
                        func = "ViewPermanentIgnoreList",
                    },  
                    del = {
                        name = "Delete Boss from ignore list",
                        desc = "Delete Boss from permanent ignore list",
                        type = "input",
                        usage = "<Boss>",
                        set = "DelFromPermanentIgnore",
                    },
                },
            },
        },
    }
    
    -- Register options table
    LibStub("AceConfig-3.0"):RegisterOptionsTable("MasterLootReminder", options)
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("MasterLootReminder", "MasterLootReminder")
end

function MasterLootReminder:OnEnable()
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("CHAT_MSG_MONSTER_YELL")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:Print("MasterLootReminder loaded. Type /mlr for options.")
end

function MasterLootReminder:OnDisable()
    self:UnregisterAllEvents()
end

-- Chat Command Handler
function MasterLootReminder:ChatCommand(input)
    if not input or input:trim() == "" then
        LibStub("AceConfigDialog-3.0"):Open("MasterLootReminder")
    else
        LibStub("AceConfigCmd-3.0").HandleCommand(MasterLootReminder, "mlr", "MasterLootReminder", input)
    end
end

-- Option Getters/Setters
function MasterLootReminder:GetEnable(info)
    return self.db.profile.Enable
end

function MasterLootReminder:SetEnable(info, value)
    self.db.profile.Enable = value
    if value then
        self:OnEnable()
    else
        self:OnDisable()
    end
end

function MasterLootReminder:GetType(info)
    return self.db.profile.Type
end

function MasterLootReminder:SetType(info, value)
    self.db.profile.Type = value
end


-- Boss detection
function MasterLootReminder:IsBoss(unitName)
    if not unitName then return false end
    
    -- Check using LibBabble-Boss
    return BossCheck[unitName] ~= nil
end

-- Ignore List Functions
function MasterLootReminder:IgnoreTarget(info)
    local targetName = UnitName("target")
    if not targetName then
        self:Print("No target found.")
        return
    end
    
    if not self:IsBoss(targetName) then
        self:Print(targetName .. " is not a known boss.")
        return        
    end
    
    if self:InTable(self.db.profile.Ignored, targetName) then
        self:Print(targetName .. " is already being ignored.")
        return
    end
    
    table.insert(self.db.profile.Ignored, targetName)
    self:Print(targetName .. " now permanently ignored!")
end

function MasterLootReminder:ResetPermanentIgnoreList(info)
    wipe(self.db.profile.Ignored)
    self:Print("Permanent ignore list reset!")
end

function MasterLootReminder:ViewPermanentIgnoreList(info)
    if #self.db.profile.Ignored == 0 then
        self:Print("Permanent ignore list is empty!")
        return
    end
    
    self:Print("Permanent ignore list:")
    for _, value in pairs(self.db.profile.Ignored) do
        self:Print(value)
    end
end

function MasterLootReminder:DelFromPermanentIgnore(info, name)
    self:DelFromIgnore(name, self.db.profile.Ignored, "Permanent")
end

function MasterLootReminder:DelFromIgnore(name, tableName, typeoflist)
    if #tableName == 0 then
        self:Print(typeoflist .. " ignore list is empty!")
        return
    end
    
    local i = self:InTable(tableName, name)
    if i then
        table.remove(tableName, i)
        self:Print(name .. " removed from " .. typeoflist .. " ignore list!")
    else
        self:Print(name .. " not found in " .. typeoflist .. " ignore list!")
    end
end

-- Utility functions
function MasterLootReminder:InTable(tableName, searchString)
    if not searchString then return false end
    for index, value in pairs(tableName) do
        if string.lower(value) == string.lower(searchString) then
            return index
        end
    end
    return nil
end

function MasterLootReminder:IsGroupLeader()
    -- Check if player is raid or party leader
    if UnitInRaid("player") then
        for i = 1, GetNumRaidMembers() do
            local name, rank = GetRaidRosterInfo(i)
            if name == UnitName("player") and rank == 2 then
                return true
            end
        end
        return false
    else
        return IsPartyLeader()
    end
end

function MasterLootReminder:GetGroupType()
    -- 1 = Party only, 2 = Raid only, 3 = Both (not used internally)
    if not self:IsGroupLeader() then
        return 0
    elseif UnitInParty("player") and not UnitInRaid("player") then
        return 1
    elseif UnitInRaid("player") then
        return 2
    end
    return 0
end

function MasterLootReminder:IsIgnored(unitName)
    if self:InTable(self.db.profile.Ignored, unitName) or self:InTable(self.Ignored, unitName) then
        return true
    else
        return false
    end
end

function MasterLootReminder:Ignore(tableName)
    if not self.bossName then return end
    if self:InTable(tableName, self.bossName) then
        return
    end
    self:Print("Now ignoring: " .. self.bossName)
    table.insert(tableName, self.bossName)
end

-- Event Handlers

--special lady vash case
function MasterLootReminder:CHAT_MSG_MONSTER_YELL(event, message, sender)
    if sender == "Lady Vashj" and message == L["You may want to take cover."] then
        self.vashjPhase3 = true
        if self:IsGroupLeader() and GetLootMethod() ~= "master" then
            StaticPopup_Show("MASTERLOOTREMINDER_VASHJ_ML")
        end
    end
end

function MasterLootReminder:PLAYER_REGEN_ENABLED()
    -- Reset encounter when leaving combat
    self.inCombat = false
    self.vashjEncounter = false
    self.vashjPhase3 = false
    self.vashjPhase1Handled = false
    if self.db.profile.GroupLootReminder and self.lastBossEncountered then
        if self:IsGroupLeader() and GetLootMethod() ~= "group" then
            StaticPopup_Show("MASTERLOOTREMINDER_GROUP_LOOT")
        end
        self.lastBossEncountered = nil
    end
end

function MasterLootReminder:PLAYER_REGEN_DISABLED()
    -- Reset flags when entering combat
    self.vashjEncounter = false
    self.vashjPhase3 = false
    self.vashjPhase1Handled = false
    self.inCombat = true
    self.lastBossEncountered = nil
end

function MasterLootReminder:PLAYER_TARGET_CHANGED()
    local type = self.db.profile.Type
    local getType = self:GetGroupType()
    
    if self.db.profile.Enable and (getType ~= 0 and type == 3 or getType == type) then
        local lootmethod = GetLootMethod()
        local targetName = UnitName("target")

           -- Track boss encounters during combat
           if UnitAffectingCombat("player") and targetName then
            if self:IsBoss(targetName) then
                self.lastBossEncountered = targetName
            end
        end
        -- Lady Vashj special handling
        if targetName == "Lady Vashj" and self:IsBoss(targetName) then
            if not self.vashjEncounter then
                self.vashjEncounter = true
                self.vashjPhase1Handled = false
            end
            
            if not self.vashjPhase3 and not self.vashjPhase1Handled then
                if self:IsGroupLeader() and lootmethod ~= "freeforall" then
                    StaticPopup_Show("MASTERLOOTREMINDER_VASHJ_FFA")
                    self.vashjPhase1Handled = true
                end
            end
            return  -- Skip normal processing for Vashj
        else
            self.vashjEncounter = false
        end
        -- Normal boss processing
        if targetName and self:IsBoss(targetName) and lootmethod ~= "master" 
           and not self.visible and not self:IsIgnored(targetName) then
            self.bossName = targetName
            self:Print("Boss detected: " .. self.bossName)
            StaticPopup_Show("MASTERLOOTREMINDER_POPUP")
        end
    end
end

-- Setup the popup dialog
-- New popup dialogs for Vashj
StaticPopupDialogs["MASTERLOOTREMINDER_VASHJ_FFA"] = {
    text = "Lady Vashj detected. Set loot to Free for All?",
    button1 = YES,
    button2 = NO,
    OnShow = function() MasterLootReminder.visible = true end,
    OnAccept = function() 
        SetLootMethod("freeforall")
        MasterLootReminder.visible = false
    end,
    OnCancel = function() MasterLootReminder.visible = false end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["MASTERLOOTREMINDER_VASHJ_ML"] = {
    text = "Lady Vashj Phase 3 detected! Set loot to Master Loot?",
    button1 = YES,
    button2 = NO,
    OnShow = function() MasterLootReminder.visible = true end,
    OnAccept = function() 
        SetLootMethod("master", UnitName("player"))
        MasterLootReminder.visible = false
    end,
    OnCancel = function() MasterLootReminder.visible = false end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}
StaticPopupDialogs["MASTERLOOTREMINDER_POPUP"] = {
    text = "Set yourself as Master Looter?",
    button1 = YES,
    button2 = NO,
    OnShow = function()
        MasterLootReminder.visible = true
    end,
    OnAccept = function()
        SetLootMethod("master", UnitName("player"))
        MasterLootReminder.visible = false
    end,
    OnCancel = function()
        MasterLootReminder:Ignore(MasterLootReminder.Ignored)
        MasterLootReminder.visible = false
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}
StaticPopupDialogs["MASTERLOOTREMINDER_GROUP_LOOT"] = {
    text = "Boss defeated! Switch to Group Loot?",
    button1 = YES,
    button2 = NO,
    OnShow = function()
        MasterLootReminder.visible = true
    end,
    OnAccept = function()
        SetLootMethod("group")
        MasterLootReminder.visible = false
    end,
    OnCancel = function()
        MasterLootReminder.visible = false
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}