local Rotations = {}

local API           = require("api")
local Utils         = require("core.helper")
local Player        = require("core.player")
local PlayerManager = require("core.player_manager")

local targetCycleKey = 0x09

Rotations["BIS Equilibrium"] = {
    fightRotation = {
        { label = "Invoke Death", wait = 0 },
        { label = "Surge" },
        { label = "Command Vengeful Ghost", wait = 0 },
        {
            label = "Enhanced Excalibur",
            type = "Custom",
            action = function()
                PlayerManager.new():useExcalibur()
                return true
            end,
            wait = 0
        },
        { label = "Surge" },
        { label = "Command Skeleton Warrior", wait = 1 },
        {
            label = "Equip Salve amulet (e)",
            type = "Custom",
            action = function() return Inventory:Equip("Salve amulet (e)") end,
            wait = 2
        },
        {
            label = "Target cycle",
            type = "Target cycle",
            wait = 0,
            targetCycleKey = targetCycleKey
        },
        {
            label = "Vulnerability bomb",
            type = "Inventory",
            wait = 0
        },
        { label = "Death Skulls" },
        {
            label = "Backup Attack Rasial",
            type = "Custom",
            condition = function()
                return (API.GetABs_name("Death Skulls", true).cooldown_timer == 0)
            end,
            action = function()
                local rasial = Utils:find(30165, 1, 40)
                print("Target cycling failed: attempting to attack Rasial")
                if rasial then
                    --- @ diagnostic disable-next-line: missing-parameter
                    if API.DoAction_NPC(0x2a, API.OFF_ACT_AttackNPC_route, { 30165 }, 50) then
                        API.DoAction_Inventory1(48951, 0, 1, API.OFF_ACT_GeneralInterface_route)
                        return Utils:useAbility("Death Skulls")
                    end
                else
                    return false
                end
            end,
            wait = 3,
            useTicks = true,
            replacementAction = function() return true end,
            replacementWait = 0
        },
        { label = "Soul Sap" },
        {
            label = "War's Retreat Teleport",
            condition = function()
                return API.GetABs_name("Death Skulls", true).cooldown_timer <= 1
            end
        },
        { label = "Touch of Death" },
        { label = "Basic<nbsp>Attack" },
        { label = "Soul Sap", wait = 0 },
        {
            label = "Pause drinking for Adrenaline renewal",
            type = "Custom",
            action = function()
                PlayerManager.new():dontDrink(4)
                return true
            end
        },
        { label = "Living Death", wait = 0 },
        { label = "Adrenaline renewal", type = "Inventory" },
        { label = "Touch of Death" },
        { label = "Death Skulls", useTicks = true },
        {
            label = "War's Retreat Teleport",
            condition = function()
                return API.GetABs_name("Living Death", true).cooldown_timer <= 1
            end
        },
        { label = "Soul Sap", wait = 1, useTicks = true },
        { label = "Vengeance", wait = 2, useTicks = true },
        { label = "Split Soul" },
        { label = "Divert" },
        { label = "Bloat" },
        { label = "Soul Sap" },
        {
            label = "Command Skeleton Warrior",
            condition = function() return Player:getAdrenaline() > 60 end,
            replacementLabel = "Basic<nbsp>Attack"
        },
        { label = "Death Skulls", wait = 2 },
        { label = "Undead Slayer", wait = 1 },
        { label = "Finger of Death" },
        { label = "Touch of Death" },
        { label = "Soul Sap" },
        { label = "Volley of Souls" },
        { label = "Finger of Death" },
        { label = "Soul Sap" },
        { label = "Death Skulls" },
        { label = "Bloat" },
        { label = "Command Putrid Zombie" },
        { label = "Soul Sap" },
        { label = "Touch of Death" },
        { label = "Command Skeleton Warrior" },
        { label = "Soul Sap" },
        {
            label = "Improvise",
            type = "Improvise",
            style = "Necromancy",
            spend = false
        }
    },

    finalRotation = {
        { label = "Basic<nbsp>Attack" },
        {
            label = "Vulnerability bomb",
            type = "Inventory",
            wait = 0
        },
        {
            label = "Basic<nbsp>Attack",
            condition = function() return (API.GetAddreline_() < 60) end,
            wait = 3
        },
        {
            label = "Basic<nbsp>Attack",
            condition = function() return (API.GetAddreline_() < 60) end,
            wait = 3
        },
        { label = "Death Skulls" },
        { label = "Soul Sap" },
        {
            label = "Weapon Special Attack",
            condition = function()
                return (API.GetAdrenalineFromInterface() > 23) and not Player:getDebuff(55524).found
            end
        },
        {
            label = "Volley of Souls",
            condition = function() return Player:getBuff(30123).remaining > 1 end
        },
        { label = "Basic<nbsp>Attack", wait = 2 },
        {
            label = "Equip Essence of Finality",
            type = "Custom",
            condition = function()
                return (API.GetAdrenalineFromInterface() > 23) and not Player:getDebuff(55524).found
            end,
            action = function()
                Inventory:Equip("Essence of Finality")
                return true
            end,
            wait = 1,
            replacementAction = function() return true end
        },
        {
            label = "Essence of Finality",
            condition = function() return (API.GetAdrenalineFromInterface() > 23) end
        },
        {
            label = "Equip Salve amulet (e)",
            type = "Custom",
            action = function()
                if Inventory:GetItem("Salve amulet (e)") then
                    Inventory:Equip("Salve amulet (e)")
                end
                return true
            end,
            wait = 0
        },
        {
            label = "Improvise",
            type = "Improvise",
            style = "Necromancy",
            spend = true
        }
    }
}

Rotations["BIS Supreme Invigoration"] = {
    fightRotation = {
        { label = "Invoke Death", wait = 0 },
        { label = "Surge" },
        { label = "Command Vengeful Ghost", wait = 0 },
        { label = "Surge" },
        { label = "Command Skeleton Warrior", wait = 1 },
        { label = "Augmented Roar of Awakening", type = "Equip", wait = 0 },
        { label = "Salve amulet (e)", type = "Equip", wait = 2 },
        {
            label = "Target cycle",
            type = "Target cycle",
            wait = 0,
            targetCycleKey = targetCycleKey
        },
        {
            label = "Vulnerability bomb",
            type = "Inventory",
            wait = 0
        },
        { label = "Smoke Cloud", wait = 0 },
        { label = "Augmented Omni guard", type = "Equip" , wait = 0},
        { label = "Death Skulls" },
        {
            label = "Backup Attack Rasial",
            type = "Custom",
            condition = function()
                return (API.GetABs_name("Death Skulls", true).cooldown_timer == 0)
            end,
            action = function()
                local rasial = Utils:find(30165, 1, 40)
                print("Target cycling failed: attempting to attack Rasial")
                if rasial then
                    --- @ diagnostic disable-next-line: missing-parameter
                    if API.DoAction_NPC(0x2a, API.OFF_ACT_AttackNPC_route, { 30165 }, 50) then
                        API.DoAction_Inventory1(48951, 0, 1, API.OFF_ACT_GeneralInterface_route)
                        return Utils:useAbility("Death Skulls")
                    end
                else
                    return false
                end
            end,
            wait = 3,
            useTicks = true,
            replacementAction = function() return true end,
            replacementWait = 0
        },
        { label = "Soul Sap"--[[, wait = 0]] },
        --[[ {
            label = "Pause drinking for Adrenaline renewal",
            type = "Custom",
            action = function()
                PlayerManager.new():dontDrink(4)
                return true
            end
        }, ]]
        {
            label = "War's Retreat Teleport",
            condition = function()
                return API.GetABs_name("Death Skulls", true).cooldown_timer <= 1
            end
        },
        { label = "Touch of Death", wait = 0 },
        { label = "Adrenaline renewal", type = "Inventory" },
        { label = "Living Death", wait = 0},
        { label = "Adrenaline renewal", type = "Inventory" },
        { label = "Soul Sap" },
        { label = "Death Skulls" },
        {
            label = "War's Retreat Teleport",
            condition = function()
                return API.GetABs_name("Living Death", true).cooldown_timer <= 1
            end
        },
        { label = "Touch of Death" },
        { label = "Split Soul" },
        { label = "Soul Sap" },
        { label = "Bloat" },
        { label = "Basic<nbsp>Attack" },
        { label = "Soul Sap" },
        { label = "Death Skulls", wait = 2 },
        { label = "Undead Slayer", wait = 1 },
        { label = "Finger of Death" },
        { label = "Touch of Death" },
        { label = "Soul Sap" },
        { label = "Volley of Souls" },
        { label = "Finger of Death" },
        { label = "Soul Sap" },
        { label = "Death Skulls" },
        { label = "Bloat" },
        { label = "Command Putrid Zombie" },
        { label = "Soul Sap" },
        { label = "Touch of Death" },
        { label = "Command Skeleton Warrior" },
        { label = "Soul Sap" },
        {
            label = "Improvise",
            type = "Improvise",
            style = "Necromancy",
            spend = false
        }
    },

    finalRotation = {
        { label = "Basic<nbsp>Attack" },
        {
            label = "Vulnerability bomb",
            type = "Inventory",
            wait = 0
        },
        {
            label = "Basic<nbsp>Attack",
            condition = function() return (API.GetAddreline_() < 60) end,
            wait = 3
        },
        {
            label = "Basic<nbsp>Attack",
            condition = function() return (API.GetAddreline_() < 60) end,
            wait = 3
        },
        { label = "Death Skulls" },
        {
            label = "Soul Sap",
            condition = function() return Player:getBuff(30123).remaining < 5 end
        },
        {
            label = "Weapon Special Attack",
            condition = function()
                return (API.GetAdrenalineFromInterface() > 23) and not Player:getDebuff(55524).found
            end
        },
        {
            label = "Volley of Souls",
            condition = function() return Player:getBuff(30123).remaining > 1 end
        },
        { label = "Basic<nbsp>Attack", wait = 2 },
        {
            label = "Equip Augmented Death guard",
            type = "Custom",
            condition = function()
                return (API.GetAdrenalineFromInterface() > 23) and not Player:getDebuff(55524).found
            end,
            action = function()
                Inventory:Equip("Augmented Death guard")
                return true
            end,
            wait = 1,
            replacementAction = function() return true end
        },
        {
            label = "Weapon Special Attack",
            condition = function() return (API.GetAdrenalineFromInterface() > 23) end
        },
        { label = "Augmented Omni guard", type = "Equip", wait = 0 },
        { label = "Touch of Death" },
        {
            label = "Improvise",
            type = "Improvise",
            style = "Necromancy",
            spend = true
        }
    }
}

Rotations["T95, No CoE, No FotS"] = {
    fightRotation = {
        {
            label = "Delay",
            type = "Custom", 
            action = function() return true end,
            wait = 1
        },
        {
            label = "Salve amulet (e)",
            type = "Custom",
            action = function() return Inventory:Equip("Salve amulet (e)") end,
            wait = 0
        },
        { label = "Invoke Death", wait = 0 },
        { label = "Surge" },
        { label = "Command Vengeful Ghost", wait = 0 },
        { label = "Surge" },
        {
            label = "Ring of vigour",
            type = "Custom",
            action = function() return Inventory:Equip("Ring of vigour") end,
            wait = 0
        },
        { label = "Command Skeleton Warrior" },
        {
            label = "Target cycle",
            type = "Target cycle",
            targetCycleKey = targetCycleKey,
            wait = 0
        },
        {
            label = "Vulnerability bomb",
            type = "Inventory"
        },
        { label = "Death Skulls" },
        {
            label = "Occultist's ring",
            type = "Custom",
            action = function() return Inventory:Equip("Occultist's ring") end,
            wait = 0
        },
        { label = "Soul Sap" },
        { label = "Touch of Death" },
        { label = "Basic<nbsp>Attack" },
        { label = "Soul Sap" },
        { label = "Basic<nbsp>Attack" },
        { label = "Basic<nbsp>Attack" },
        {
            label = "Ring of vigour",
            type = "Custom",
            action = function() return Inventory:Equip("Ring of vigour") end,
            wait = 0
        },
        { label = "Living Death", wait = 0 },
        { label = "Adrenaline renewal", type = "Inventory" },
        {
            label = "Occultist's ring",
            type = "Custom",
            action = function() return Inventory:Equip("Occultist's ring") end,
            wait = 0
        },
        { label = "Touch of Death" },
        { label = "Command Skeleton Warrior" },
        { label = "Divert" },
        {
            label = "Ring of vigour",
            type = "Custom",
            action = function() return Inventory:Equip("Ring of vigour") end,
            wait = 0
        },
        { label = "Death Skulls" },
        {
            label = "Occultist's ring",
            type = "Custom",
            action = function() return Inventory:Equip("Occultist's ring") end,
            wait = 0
        },
        { label = "Soul Sap" },
        { label = "Basic<nbsp>Attack" },
        { label = "Basic<nbsp>Attack" },
        { label = "Soul Sap" },
        { label = "Touch of Death" },
        { label = "Split Soul" },
        {
            label = "Ring of vigour",
            type = "Custom",
            action = function() return Inventory:Equip("Ring of vigour") end,
            wait = 0
        },
        { label = "Death Skulls" },
        {
            label = "Occultist's ring",
            type = "Custom",
            action = function() return Inventory:Equip("Occultist's ring") end,
            wait = 0
        },
        { label = "Command Skeleton Warrior" },
        { label = "Soul Sap" },
        { label = "Volley of Souls" },
        { label = "Finger of Death" },
        { label = "Bloat" },
        { label = "Touch of Death" },
        {
            label = "Ring of vigour",
            type = "Custom",
            action = function() return Inventory:Equip("Ring of vigour") end,
            wait = 0
        },
        {
            label = "Essence of Finality",
            type = "Custom",
            action = function() return Inventory:Equip("Essence of Finality") end,
            wait = 0
        },
        { label = "Essence of Finality" },
        {
            label = "Salve amulet (e)",
            type = "Custom",
            action = function() return Inventory:Equip("Salve amulet (e)") end,
            wait = 0
        },
        {
            label = "Occultist's ring",
            type = "Custom",
            action = function() return Inventory:Equip("Occultist's ring") end,
            wait = 0
        },
        { label = "Soul Sap" },
        { label = "Basic<nbsp>Attack" },
        { label = "Bloat" },
        { label = "Soul Sap" },
        {
            label = "Improvise",
            type = "Improvise",
            style = "Necromancy",
            spend = false
        }
    },

    finalRotation = {
        { label = "Basic<nbsp>Attack" },
        {
            label = "Basic<nbsp>Attack",
            condition = function() return (API.GetAddreline_() < 60) end,
            wait = 3
        },
        { label = "Vulnerability bomb", type = "Inventory", wait = 0 },
        { label = "Death Skulls" },
        { label = "Soul Sap" },
        {
            label = "Weapon Special Attack",
            condition = function()
                return (API.GetAdrenalineFromInterface() > 30) and not Player:getDebuff(55524).found
            end
        },
        {
            label = "Volley of Souls",
            condition = function()
                return Player:getBuff(30123).remaining > 1
            end
        },
        { label = "Basic<nbsp>Attack" },
        {
            label = "Ring of vigour",
            type = "Custom",
            action = function() return Inventory:Equip("Ring of vigour") end,
            wait = 0
        },
        {
            label = "Essence of Finality",
            type = "Custom",
            action = function() return Inventory:Equip("Essence of Finality") end,
            wait = 0
        },
        { label = "Essence of Finality" },
        {
            label = "Equip Salve amulet (e)",
            type = "Custom",
            action = function()
                if Inventory:GetItem("Salve amulet (e)") then
                    Inventory:Equip("Salve amulet (e)")
                end
                return true
            end,
            wait = 0
        },
        {
            label = "Improvise",
            type = "Improvise",
            style = "Necromancy",
            spend = true
        }
    }
}

Rotations["[0xB0BABAE] T90"] = {
    fightRotation = {
        {
            label = "Delay",
            type = "Custom",
            action = function() return true end,
            wait = 1
        },
        { label = "Command Vengeful Ghost", wait = 0 },
        { label = "Surge", wait = 3, useTicks = true },
        { label = "Command Skeleton Warrior" },
        {
            label = "Salve amulet (e)",
            type = "Custom",
            action = function() return Inventory:Equip("Salve amulet (e)") end,
            wait = 0
        },
        { label = "Reflect" },
        {
            label = "Target cycle",
            type = "Target cycle",
            targetCycleKey = targetCycleKey,
            wait = 0,
        },
        { label = "Vulnerability bomb", type = "Inventory", wait = 0 },
        { label = "Bloat" },
        { label = "Soul Sap" },
        { label = "Death Skulls" },
        { label = "Touch of Death" },
        { label = "Soul Sap" },
        { label = "Basic<nbsp>Attack" },
        { label = "Basic<nbsp>Attack" },
        { label = "Soul Sap" },
        { label = "Command Skeleton Warrior" },
        { label = "Living Death", wait = 0 },
        { label = "Adrenaline renewal", type = "Inventory" },
        { label = "Touch of Death" },
        { label = "Death Skulls" },
        { label = "Divert" },
        { label = "Split Soul" },
        { label = "Volley of Souls" },
        { label = "Soul Sap" },
        { label = "Finger of Death" },
        { label = "Command Skeleton Warrior" },
        { label = "Death Skulls", wait = 2, useTicks = true },
        { label = "Undead Slayer", wait = 1, useTicks = true },
        { label = "Soul Sap" },
        { label = "Touch of Death" },
        { label = "Finger of Death" },
        { label = "Soul Sap" },
        { label = "Volley of Souls" },
        {
            label = "Finger of Death",
            condition = function()
                local necrosisStacks = Player:getBuff(30101).found and Player:getBuff(30101).remaining or 0
                return necrosisStacks >= 6
            end,
            replacementLabel = "Basic<nbsp>Attack"
        },
        { label = "Death Skulls" },
        { label = "Soul Sap" },
        { label = "Bloat" },
        { label = "Command Skeleton Warrior" },
        { label = "Touch of Death" },
        { label = "Soul Sap" },
        { label = "Soul Strike" },
        {
            label = "Finger of Death",
            condition = function()
                local necrosisStacks = Player:getBuff(30101).found and Player:getBuff(30101).remaining or 0
                return necrosisStacks >= 4
            end,
            replacementLabel = "Basic<nbsp>Attack"
        },
        { label = "Soul Sap" },
        { label = "Soul Strike" },
        {
            label = "Finger of Death",
            condition = function()
                local necrosisStacks = Player:getBuff(30101).found and Player:getBuff(30101).remaining or 0
                return necrosisStacks >= 4
            end,
            replacementLabel = "Basic<nbsp>Attack"
        },
        {
            label = "Improvise",
            type = "Improvise",
            style = "Necromancy",
            spend = false
        }
    },

    finalRotation = {
        {
            label = "Life Transfer",
            condition = function(self)
                return Player:getBuff(34178).found and Player:getBuff(34178).remaining >= 2
            end,
            replacementLabel = "Conjure Undead Army"
        },
        { label = "Death Skulls", wait = 0 },
        { label = "Vulnerability bomb", type = "Inventory", wait = 3, useTicks = true },
        { label = "Powerburst of vitality", wait = 0 },
        {
            label = "Reflect",
            condition = function() return API.GetAddreline_() >= 50 end,
            replacementLabel = "Divert"
        },
        { label = "Command Skeleton Warrior" },
        { label = "Finger of Death" },
        {
            label = "Weapon Special Attack",
            condition = function()
                return (API.GetAdrenalineFromInterface() > 23) and not Player:getDebuff(55524).found
            end
        },
        { label = "Soul Sap" },
        { label = "Volley of Souls" },
        { label = "Touch of Death" },
        { label = "Command Putrid Zombie" },
        { label = "Finger of Death" },
        {
            label = "Improvise",
            type = "Improvise",
            style = "Necromancy",
            spend = true
        }
    }
}

Rotations["[Arshalo] T95"] = {
    fightRotation = {
        {
            label = "Delay",
            type = "Custom",
            action = function() return true end,
            wait = 1
        },
        { label = "Command Vengeful Ghost" },
        { label = "Invoke Death", wait = 1 },
        {
            label = "Salve amulet (e)",
            type = "Custom",
            action = function() return Inventory:Equip("Salve amulet (e)") end,
            wait = 0
        },
        { label = "Surge", wait = 2 },
        { label = "Command Skeleton Warrior" },
        {
            label = "Target cycle",
            type = "Target cycle",
            wait = 0,
            targetCycleKey = targetCycleKey
        },
        { label = "Vulnerability" },
        { label = "Death Skulls", wait = 1, useTicks = true },
        {
            label = "Backup Attack Rasial",
            type = "Custom", 
            condition = function() return (API.ReadTargetInfo(true).Hitpoints <= 0) and (API.GetABs_name1("Death Skulls").cooldown_timer <= 0) end,
            action = function()
                local rasial = Utils:find(30165, 1, 40)
                if rasial then
                    ---@diagnostic disable-next-line
                    if API.DoAction_NPC(0x2a, API.OFF_ACT_AttackNPC_route, {30165}, 50) then
                        return Utils:_useAbility("Death Skulls")
                    end
                else return false end
            end,
            wait = 3,
            useTicks = true,
            replacementAction = function() return true end,
            replacementWait = 2
        },
        { label = "Soul Sap" },
        { label = "Touch of Death" },
        { label = "Basic<nbsp>Attack" },
        { label = "Soul Sap" },
        { label = "Bloat", wait = 1, useTicks = true },
        {
            label = "Augmented Death guard",
            type = "Custom",
            action = function() return Inventory:Equip("Augmented Death guard") end,
            wait = 2,
            useTicks = true
        },
        { label = "Weapon Special Attack", wait = 1, useTicks = true },
        {
            label = "Augmented Omni guard",
            type = "Custom",
            action = function() return Inventory:Equip("Augmented Omni guard") end,
            wait = 2,
            useTicks = true
        },
        { label = "Soul Sap" },
        { label = "Volley of Souls" },
        { label = "Command Skeleton Warrior", useTicks = true },
        { label = "Soul Sap" },
        { label = "Touch of Death" },
        { label = "Basic<nbsp>Attack" },
        { label = "Soul Sap" },
        { label = "Weapon Special Attack" },
        { label = "Basic<nbsp>Attack" },
        { label = "Soul Sap" },
        { label = "Basic<nbsp>Attack" },
        { label = "Living Death", wait = 0 },
        { label = "Replenishment potion", type = "Inventory" },
        { label = "Touch of Death" },
        { label = "Basic<nbsp>Attack" },
        { label = "Death Skulls", useTicks = true },
        { label = "Split Soul" },
        { label = "Basic<nbsp>Attack" },
        { label = "Volley of Souls" },
        { label = "Finger of Death" },
        { label = "Basic<nbsp>Attack" },
        { label = "Finger of Death" },
        { label = "Basic<nbsp>Attack" },
        { label = "Touch of Death" },
        { label = "Basic<nbsp>Attack" },
        { label = "Death Skulls", useTicks = true },
        { label = "Basic<nbsp>Attack" },
        { label = "Finger of Death" },
        { label = "Finger of Death" },
        { label = "Soul Sap" },
        { label = "Vulnerability" },
        { label = "Touch of Death" },
        { label = "Soul Sap" },
        { label = "Command Skeleton Warrior" },
        { label = "Basic<nbsp>Attack" },
        { label = "Soul Sap" },
        { label = "Basic<nbsp>Attack" },
        { label = "Basic<nbsp>Attack" },
        {
            label = "Improvise",
            type = "Improvise",
            style = "Necromancy",
            spendAdren = false
        }
    },

    finalRotation = {
        { label = "Soul Sap" },
        { label = "Death Skulls", wait = 1, useTicks = true },
        {
            label = "Augmented Death guard",
            type = "Custom",
            action = function() return Inventory:Equip("Augmented Death guard") end,
            wait = 2,
            useTicks = true
        },
        { label = "Weapon Special Attack", wait = 1, useTicks = true },
        {
            label = "Augmented Omni guard",
            type = "Custom",
            action = function() return Inventory:Equip("Augmented Omni guard") end,
            wait = 2,
            useTicks = true
        },
        { label = "Soul Sap" },
        { label = "Volley of Souls" },
        { label = "Basic<nbsp>Attack" },
        { label = "Soul Sap" },
        { label = "Basic<nbsp>Attack" },
        { label = "Weapon Special Attack" },
        { label = "Basic<nbsp>Attack" },
        { label = "Touch of Death" },
        { label = "Basic<nbsp>Attack" },
        { label = "Finger of Death" },
        { label = "Basic<nbsp>Attack" },
        {
            label = "Improvise",
            type = "Improvise",
            style = "Necromancy",
            spendAdren = true
        }
    }
}

Rotations["[Matteus] T95"] = {
    fightRotation = {
        {
            label = "Delay",
            type = "Custom",
            action = function() return true end,
            wait = 1
        },
        { label = "Command Vengeful Ghost" },
        { label = "Invoke Death", wait = 1 },
        {
            label = "Salve amulet (e)",
            type = "Custom",
            action = function() return Inventory:Equip("Salve amulet (e)") end,
            wait = 0
        },
        { label = "Surge", wait = 2 },
        { label = "Command Skeleton Warrior" },
        {
            label = "Target cycle",
            type = "Target cycle",
            wait = 0,
            targetCycleKey = targetCycleKey
        },
        { label = "Vulnerability" },
        { label = "Death Skulls", wait = 1, useTicks = true },
        {
            label = "Backup Attack Rasial",
            type = "Custom", 
            condition = function() return (API.ReadTargetInfo(true).Hitpoints <= 0) and (API.GetABs_name1("Death Skulls").cooldown_timer <= 0) end,
            action = function()
                local rasial = Utils:find(30165, 1, 40)
                if rasial then
                    ---@diagnostic disable-next-line
                    if API.DoAction_NPC(0x2a, API.OFF_ACT_AttackNPC_route, {30165}, 50) then
                        return Utils:_useAbility("Death Skulls")
                    end
                else return false end
            end,
            wait = 3,
            useTicks = true,
            replacementAction = function() return true end,
            replacementWait = 2
        },
        {label = "Soul Sap"},
        {label = "Bloat"},
        {label = "Touch of Death"},
        {label = "Basic<nbsp>Attack"},
        {label = "Soul Sap"},
        {label = "Basic<nbsp>Attack"},
        {label = "Command Skeleton Warrior"},
        {label = "Living Death", wait = 0},
        {label = "Replenishment potion", type = "Inventory"}, 
        {label = "Touch of Death"},
        {label = "Death Skulls"},
        {label = "Split Soul"},
        {label = "Finger of Death"},
        {label = "Basic<nbsp>Attack"},
        {label = "Basic<nbsp>Attack"},
        {label = "Basic<nbsp>Attack"},
        {label = "Basic<nbsp>Attack"},
        {label = "Death Skulls"},
        {label = "Finger of Death"},
        {label = "Touch of Death"},
        {label = "Basic<nbsp>Attack"},
        {label = "Basic<nbsp>Attack"},
        {label = "Finger of Death"},
        {label = "Finger of Death"},
        {label = "Death Skulls"},
        {label = "Life Transfer"},
        {label = "Soul Sap"},
        {label = "Volley of Souls"},
        {label = "Command Skeleton Warrior"},
        {label = "Basic<nbsp>Attack"},  
        {label = "Soul Sap"},
        {label = "Vulnerability"},
        {label = "Command Putrid Zombie"},
        {label = "Touch of Death"},
        {label = "Bloat"},
        {label = "Improvise", type = "Improvise", style = "Necromancy", spend = false}
    },

    finalRotation = {
        {label = "Basic<nbsp>Attack"},
        {label = "Basic<nbsp>Attack", condition = function() return (API.GetAddreline_() < 60) end, wait = 3, useTicks = true},
        {label = "Death Skulls"},
        {label = "Soul Sap"},
        {label = "Weapon Special Attack", condition = function() return (API.GetAdrenalineFromInterface() > 23) and not Player:getDebuff(55524).found end}, -- here
        {label = "Volley of Souls", condition = function() return Player:getBuff(30123).remaining > 1 end}, -- here
        {label = "Basic<nbsp>Attack", wait = 2},
        {
            label = "Equip Essence of Finality",
            type = "Custom",
            condition = function() return (API.GetAdrenalineFromInterface() > 23) and not Player:getDebuff(55524).found end,
            action = function() Inventory:Equip("Essence of Finality") return true end,
            useTicks = true,
            wait = 1,
            replacementAction = function() return true end,
        },
        {label = "Essence of Finality", condition = function() return (API.GetAdrenalineFromInterface() > 23) end}, -- here 
        {label = "Equip Salve amulet (e)", type = "Custom", action = function() if Inventory:GetItem("Salve amulet (e)") then Inventory:Equip("Salve amulet (e)") end return true end, wait = 0}, -- here
        {label = "Touch of Death"},
        {label = "Finger of Death"},
        {label = "Improvise", type = "Improvise", style = "Necromancy", spend = true}
    }
}

return Rotations
