local MasterLootReminder = LibStub("AceAddon-3.0"):NewAddon("MasterLootReminder", "AceEvent-3.0", "AceConsole-3.0", "AceTimer-3.0")

-- Debug function to check library availability
local function CheckLibrary(name)
   local status, lib = pcall(function() return LibStub(name) end)
    if status and lib then
        -- MasterLootReminder:Print("Found library: " .. name)
       return true
    else
        -- MasterLootReminder:Print("Missing library: " .. name)
        return false
    end
end

-- Check for critical libraries
MasterLootReminder.LibrariesLoaded = true

-- Safe locale loading
local L = {}
if not CheckLibrary("AceLocale-3.0") then
    MasterLootReminder.LibrariesLoaded = false
else
    L = LibStub("AceLocale-3.0"):GetLocale("MasterLootReminder", true)
end

-- Get the boss library for more accurate boss detection
local BossCheck = nil
if not CheckLibrary("LibBabble-Boss-3.0") then
    MasterLootReminder:Print("Warning: LibBabble-Boss-3.0 not found. Using built-in boss list.")
else
    local LibBabbleBoss = LibStub("LibBabble-Boss-3.0")
    BossCheck = LibBabbleBoss:GetUnstrictLookupTable()
end

-- Local variables
MasterLootReminder.visible = false
MasterLootReminder.bossName = "_NONE_"
MasterLootReminder.Ignored = {}
MasterLootReminder.isVashjPhase3 = false

-- Define fallback list of known bosses for detection if library is missing
local KnownBosses = {
    -- SSC
    ["Lady Vashj"] = true,
    ["Hydross the Unstable"] = true,
    ["The Lurker Below"] = true,
    ["Leotheras the Blind"] = true,
    ["Fathom-Lord Karathress"] = true,
    ["Morogrim Tidewalker"] = true,
    -- TK
    ["Kael'thas Sunstrider"] = true,
    ["Void Reaver"] = true,
    ["High Astromancer Solarian"] = true,
    ["Al'ar"] = true,
    -- Other common raid bosses
    ["Gruul the Dragonkiller"] = true,
    ["High King Maulgar"] = true,
    ["Magtheridon"] = true,
    ["Prince Malchezaar"] = true,
    ["Nightbane"] = true,
    ["Shade of Aran"] = true,
    ["Netherspite"] = true,
    ["Maiden of Virtue"] = true,
    ["Attumen the Huntsman"] = true,
    ["Moroes"] = true,
    ["The Curator"] = true,
    ["Terestian Illhoof"] = true,
    -- Sample Naxx bosses
    ["Kel'Thuzad"] = true,
    ["Sapphiron"] = true,
    ["Patchwerk"] = true,
    ["Thaddius"] = true,
    ["Anub'Rekhan"] = true,
    ["Heigan the Unclean"] = true,
    ["Loatheb"] = true,
    ["Instructor Razuvious"] = true,
    ["Gothik the Harvester"] = true,
    ["The Four Horsemen"] = true
}

-- Add a list of NPCs to be ignored by default
local IgnoredByDefault = {
    -- Lady Vashj adds
    ["Coilfang Elite"] = true,
    ["Coilfang Strider"] = true,
    ["Tainted Elemental"] = true,
    ["Toxic Spore Bat"] = true,
    ["Enchanted Elemental"] = true,
    ["Coilfang Fathom-Witch"] = true,
    
    -- Add other trash mobs or encounter adds here as needed
    ["Tempest-Smith"] = true,  -- Possible Al'ar add
    ["Phoenix"] = true,        -- Al'ar add
    ["Phoenix Egg"] = true,    -- Al'ar add
}

-- Default settings
local defaults = {
    profile = {
        Enable = true,
        Ignored = {},
        GroupLoot = false -- New option for group loot
    }
}

function MasterLootReminder:OnInitialize()
    -- Initialize DB
    self.db = LibStub("AceDB-3.0"):New("MasterLootReminderDB", defaults)
    
    -- Register slash commands
    self:RegisterChatCommand("mlr", "ChatCommand")
    self:RegisterChatCommand("masterlootreminder", "ChatCommand")
    
    -- Copy default ignored NPCs to the session ignore list
    for npc in pairs(IgnoredByDefault) do
        table.insert(self.Ignored, npc)
    end
    
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
            groupLoot = {
                name = "Enable Group Loot",
                desc = "Ask to switch to group loot after killing a boss",
                type = "toggle",
                get = "GetGroupLoot",
                set = "SetGroupLoot",
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
    
    -- Initialize options with or without timer
    local function InitializeOptions()
        -- Try to register options with thorough error handling
        local success, result = pcall(function()
            -- Check for AceConfigRegistry-3.0 first, as it's required by AceConfig-3.0
            if not CheckLibrary("AceConfigRegistry-3.0") then
                return false, "AceConfigRegistry-3.0 is missing"
            end
            
            -- Now check for AceConfig-3.0
            if not CheckLibrary("AceConfig-3.0") then
                return false, "AceConfig-3.0 is missing"
            end
            
            -- Then register the options
            LibStub("AceConfig-3.0"):RegisterOptionsTable("MasterLootReminder", options)
            
            -- Check if AceConfigDialog-3.0 is available
            if not CheckLibrary("AceConfigDialog-3.0") then
                return false, "AceConfigDialog-3.0 is missing"
            end
            
            -- Create the options panel
            self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("MasterLootReminder", "MasterLootReminder")
            return true
        end)
        
        if not success then
            self:Print("Could not initialize MLR: " .. tostring(result))
            self:Print("Basic slash commands will still work")
        elseif not result then
            self:Print("Could not initialize MLR: " .. tostring(result))
            self:Print("Basic slash commands will still work")
        else
            self:Print("MLR initialized successfully")
        end
    end
    
    -- Try to use timer if available, otherwise init directly
    if self.ScheduleTimer then
        self:ScheduleTimer(InitializeOptions, 2)
    else
        -- Fallback if AceTimer is not available
        InitializeOptions()
    end
end

function MasterLootReminder:OnEnable()
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("CHAT_MSG_MONSTER_YELL")
    self:Print("MasterLootReminder loaded. Type /mlr for options.")
end

function MasterLootReminder:OnDisable()
    self:UnregisterEvent("PLAYER_TARGET_CHANGED")
    self:UnregisterEvent("CHAT_MSG_MONSTER_YELL")
end

-- Chat Command Handler
function MasterLootReminder:ChatCommand(input)
    if not input or input:trim() == "" then
        -- Try to open config panel with error handling
        local success, msg = pcall(function()
            LibStub("AceConfigDialog-3.0"):Open("MasterLootReminder")
        end)
        
        if not success then
            -- Simple command help as fallback
            self:Print("Config panel not available: " .. tostring(msg))
            self:Print("Available commands:")
            self:Print("/mlr enable - Enable the addon")
            self:Print("/mlr disable - Disable the addon") 
            self:Print("/mlr grouploot - Toggle group loot option")
            self:Print("/mlr ignoreTarget - Add target to permanent ignore list")
        end
    else
        -- Parse the input
        local cmd = input:trim():lower()
        if cmd == "enable" then
            self:SetEnable(nil, true)
            self:Print("MasterLootReminder enabled")
        elseif cmd == "disable" then
            self:SetEnable(nil, false)
            self:Print("MasterLootReminder disabled")
        elseif cmd == "grouploot" then
            self:SetGroupLoot(nil, not self:GetGroupLoot())
            self:Print("Group loot option set to: " .. tostring(self:GetGroupLoot()))
        elseif cmd == "ignoretarget" then
            self:IgnoreTarget()
        else
            -- Try to use AceConfigCmd handler if available
            local success = pcall(function()
                LibStub("AceConfigCmd-3.0").HandleCommand(MasterLootReminder, "mlr", "MasterLootReminder", input)
            end)
            
            if not success then
                self:Print("Unknown command: " .. cmd)
                self:Print("Use /mlr for a list of commands")
            end
        end
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

function MasterLootReminder:GetGroupLoot(info)
    return self.db.profile.GroupLoot
end

function MasterLootReminder:SetGroupLoot(info, value)
    self.db.profile.GroupLoot = value
end

-- Boss detection
function MasterLootReminder:IsBoss(unitName)
    if not unitName then return false end
    
    -- Use LibBabble-Boss if available
    if BossCheck then
        return BossCheck[unitName] ~= nil
    end
    
    -- Fallback to our own list if library is missing
    return KnownBosses[unitName] == true
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
    -- Check if player is a raid leader
    if not self:IsGroupLeader() then
        return false
    elseif UnitInRaid("player") then
        return true
    end
    return false
end

function MasterLootReminder:IsIgnored(unitName)
    if self:InTable(self.db.profile.Ignored, unitName) or self:InTable(self.Ignored, unitName) or IgnoredByDefault[unitName] then
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
    local inRaid = self:GetGroupType()
    
    if self.db.profile.Enable and inRaid then
        local lootmethod, masterlooter = GetLootMethod()
        local targetName
        
        if UnitIsPlayer("target") or UnitPlayerControlled("target") then
            targetName = UnitName("targettarget")
        else
            targetName = UnitName("target")
        end
        
        if targetName and self:IsBoss(targetName) then
            -- Add debug message to show we detected a boss
            self:Print("Detected boss: " .. targetName)
            
            if self.visible then
                self:Print("Popup already visible, not showing another")
            elseif self:IsIgnored(targetName) then
                self:Print("Boss " .. targetName .. " is on ignore list, not showing popup")
            else
                self.bossName = targetName
                self:Print("Boss detected and not ignored: " .. self.bossName)
                
                -- Special handling for Lady Vashj
                if targetName == "Lady Vashj" and not self.isVashjPhase3 then
                    if lootmethod ~= "freeforall" then
                        StaticPopup_Show("MASTERLOOTREMINDER_VASHJ_POPUP")
                    end
                    return
                end
                
                -- Regular handling for other bosses
                -- Check if we should show master loot or group loot popup
                if self.db.profile.GroupLoot and lootmethod == "master" then
                    StaticPopup_Show("MASTERLOOTREMINDER_GROUP_POPUP")
                elseif lootmethod ~= "master" then
                    StaticPopup_Show("MASTERLOOTREMINDER_POPUP")
                end
            end
        end
    end
end

function MasterLootReminder:CHAT_MSG_MONSTER_YELL(event, message, sender)
    -- Use a partial match that we know works
    if string.find(message, "take cover") then
        self:Print("Vashj Phase 3 detected!")
        self.isVashjPhase3 = true
        local inRaid = self:GetGroupType()
        
        if self.db.profile.Enable and inRaid then
            local lootmethod = GetLootMethod()
            
            if lootmethod ~= "master" then
                self:Print("Showing master loot popup for Vashj Phase 3")
                StaticPopup_Show("MASTERLOOTREMINDER_VASHJ_PHASE3_POPUP")
            else
                self:Print("Already using master loot - no popup needed")
            end
        end
    end
end

-- Setup the popup dialogs
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

StaticPopupDialogs["MASTERLOOTREMINDER_GROUP_POPUP"] = {
    text = "Switch to Group Loot?",
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
        MasterLootReminder:Ignore(MasterLootReminder.Ignored)
        MasterLootReminder.visible = false
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["MASTERLOOTREMINDER_VASHJ_POPUP"] = {
    text = "Switch to Free-for-All for Lady Vashj?",
    button1 = YES,
    button2 = NO,
    OnShow = function()
        MasterLootReminder.visible = true
    end,
    OnAccept = function()
        SetLootMethod("freeforall")
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

StaticPopupDialogs["MASTERLOOTREMINDER_VASHJ_PHASE3_POPUP"] = {
    text = "Lady Vashj Phase 3! Switch to Master Loot?",
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
        MasterLootReminder.visible = false
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}