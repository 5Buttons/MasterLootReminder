local MasterLootReminder = LibStub("AceAddon-3.0"):NewAddon("MasterLootReminder", "AceEvent-3.0", "AceConsole-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("MasterLootReminder", true)

-- Get the boss library for more accurate boss detection
local LibBabbleBoss = LibStub("LibBabble-Boss-3.0")
local BossCheck = LibBabbleBoss:GetUnstrictLookupTable()

-- Local variables
MasterLootReminder.visible = false
MasterLootReminder.bossName = "_NONE_"
MasterLootReminder.Ignored = {}

-- Default settings
local defaults = {
    profile = {
        Enable = true,
        Type = 2, -- 1 = Party only, 2 = Raid only, 3 = Both
        Ignored = {}
    }
}

function MasterLootReminder:OnInitialize()
    -- Initialize DB
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
            ignoreTarget = {
                name = "Add target to 'permanent' ignore list",
                desc = "Add target to 'permanent' ignore list",
                type = "execute",
                func = "IgnoreTarget",
                order = 3
            },
            pIgnore = {
                type = 'group',
                name = "Permanent ignore list options",
                desc = "Permanent ignore list options",
                args = {                
                    reset = {
                        name = "Reset permanent ignore list",
                        desc = "Reset permanent ignore list",
                        type = "execute",
                        func = "ResetPermanentIgnoreList",
                    },
                    list = {
                        name = "View permanent ignore list",
                        desc = "View permanent ignore list",
                        type = "execute",
                        func = "ViewPermanentIgnoreList",
                    },  
                    del = {
                        name = "Delete Boss from permanent ignore list",
                        desc = "Delete Boss from permanent ignore list",
                        type = "input",
                        usage = "<Boss>",
                        set = "DelFromPermanentIgnore",
                    },
                },
            },
            sIgnore = {
                type = 'group',
                name = "Session ignore list options",
                desc = "Session ignore list options",
                args = {                
                    reset = {
                        name = "Reset session ignore list",
                        desc = "Reset session ignore list",
                        type = "execute",
                        func = "ResetSessionIgnoreList",
                    },
                    list = {
                        name = "View session ignore list",
                        desc = "View session ignore list",
                        type = "execute",
                        func = "ViewSessionIgnoreList",
                    },  
                    del = {
                        name = "Delete name from session ignore list",
                        desc = "Delete name from session ignore list",
                        type = "input",
                        usage = "<name>",
                        set = "DelFromSessionIgnore",
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
    self:Print("MasterLootReminder loaded. Type /mlr for options.")
end

function MasterLootReminder:OnDisable()
    self:UnregisterEvent("PLAYER_TARGET_CHANGED")
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

function MasterLootReminder:ResetSessionIgnoreList(info)
    wipe(self.Ignored)
    self:Print("Session ignore list reset!")
end

function MasterLootReminder:ViewSessionIgnoreList(info)
    if #self.Ignored == 0 then
        self:Print("Session ignore list is empty!")
        return
    end
    
    self:Print("Session ignore list:")
    for _, value in pairs(self.Ignored) do
        self:Print(value)
    end
end

function MasterLootReminder:DelFromSessionIgnore(info, name)
    self:DelFromIgnore(name, self.Ignored, "Session")
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
function MasterLootReminder:PLAYER_TARGET_CHANGED()
    local type = self.db.profile.Type
    local getType = self:GetGroupType()
    
    if self.db.profile.Enable and (getType ~= 0 and type == 3 or getType == type) then
        local lootmethod = GetLootMethod()
        local targetName
        
        if UnitIsPlayer("target") or UnitPlayerControlled("target") then
            targetName = UnitName("targettarget")
        else
            targetName = UnitName("target")
        end
        
        if targetName and self:IsBoss(targetName) and lootmethod ~= "master" and not self.visible and not self:IsIgnored(targetName) then
            self.bossName = targetName
            self:Print("Boss detected: " .. self.bossName)
            StaticPopup_Show("MASTERLOOTREMINDER_POPUP")
        end
    end
end

-- Setup the popup dialog
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