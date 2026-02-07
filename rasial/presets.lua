--- @module 'rasial.presets'
--- @version 3.0.0
--- Complete preset definitions for Rasial: Inventory, Equipment, and Rotations
local API = require("api")
local Utils = require("core.helper")
local Player = require("core.player")
local PlayerManager = require("core.player_manager")

local Presets = {}

-- ============================================================================
-- INVENTORY PRESETS
-- ============================================================================

Presets.Inventory = {}

Presets.Inventory["Sonson's Loadout"] = {
    {id = 48951, amount = 10, name = "Vulnerability bomb"},
    {id = 29448, amount = 2, name = "Guthix rest flask (6)"},
    {id = 42267, amount = 4, name = "Blue blubber jellyfish"}, {
        ids = {49042, 49044, 49046, 49048, 49050, 49052},
        amount = 1,
        name = "Elder overload salve"
    }, -- Accepts any dose (1-6)
    {id = 47713, amount = 11, name = "Lantadyme incense sticks"},
    {id = 49417, amount = 1, name = "Binding contract (ripper demon)"},
    {
        ids = {49079, 49081, 49083, 49085},
        amount = 1,
        name = "Adrenaline renewal"
    }
}

-- ============================================================================
-- EQUIPMENT PRESETS
-- ============================================================================

Presets.Equipment = {}

Presets.Equipment["Ful"] = {{id = 52494, slot = 12, name = "Scripture of Ful"}}

-- ============================================================================
-- BUFFS PRESETS
-- ============================================================================

Presets.Buffs = {}

Presets.Buffs["Standard"] = {
    {
        buffName = "Ruination",
        buffId = 30769,
        canApply = function() return true end,
        execute = function() return Utils:useAbility("Ruination") end,
        toggle = true
    }, {
        buffName = "Scripture of Ful",
        buffId = 52494,
        canApply = function()
            local bookEquipped = API.Container_Get_all(94)[18].item_id == 52494
            local bookChargesInSeconds = API.GetVarbitValue(30604) * 0.6
            return bookEquipped and (bookChargesInSeconds > 1000)
        end,
        execute = function()
            if API.Container_Get_all(94)[18].item_id == 52494 then
                return Utils:useAbility("Scripture of Ful")
            end
        end,
        toggle = true
    }, {
        buffName = "Lantadyme incense sticks",
        buffId = 47713,
        execute = function()
            local name = "Lantadyme incense sticks"
            if Player:getBuff(47713).found and Inventory:Contains(name) and
                Inventory:InvItemcountStack_Strings({name}) >= 6 then
                return API.DoAction_Inventory3(name, 0, 2,
                                               API.OFF_ACT_GeneralInterface_route)
            else
                return API.DoAction_Inventory3(name, 0, 1,
                                               API.OFF_ACT_GeneralInterface_route)
            end
        end,
        refreshAt = 660
    }, {
        buffName = "Elder overload",
        buffId = 49039,
        canApply = function()
            local ELDER_OLV_SALVE_IDS = {
                49042, 49044, 49046, 49048, 49050, 49052
            }
            return Inventory:Contains(ELDER_OLV_SALVE_IDS)
        end,
        execute = function()
            return Inventory:DoAction("Elder overload salve", 1,
                                      API.OFF_ACT_GeneralInterface_route)
        end,
        refreshAt = math.random(10, 20)
    }, {
        buffName = "Binding contract (ripper demon)",
        buffId = 26095,
        canApply = function()
            return Inventory:Contains("Binding contract (ripper demon)")
        end,
        execute = function()
            return Inventory:DoAction("Binding contract (ripper demon)", 1,
                                      API.OFF_ACT_GeneralInterface_route)
        end,
        refreshAt = 10
    }
}

Presets.Buffs["With Grimoire"] = {
    {
        buffName = "Ruination",
        buffId = 30769,
        canApply = function() return true end,
        execute = function() return Utils:useAbility("Ruination") end,
        toggle = true
    }, {
        buffName = "Scripture of Ful",
        buffId = 52494,
        canApply = function()
            return API.Container_Get_all(94)[18].item_id == 52494
        end,
        execute = function()
            if API.Container_Get_all(94)[18].item_id == 52494 then
                return Utils:useAbility("Scripture of Ful")
            end
        end,
        toggle = true
    }, {
        buffName = "Erethdor's grimoire",
        buffId = 42787,
        canApply = function()
            return API.Container_Get_all(94)[18].item_id == 42787
        end,
        execute = function()
            if API.Container_Get_all(94)[18].item_id == 42787 then
                return Utils:useAbility("Erethdor's grimoire")
            end
        end
    }, {
        buffName = "Lantadyme incense sticks",
        buffId = 47713,
        execute = function()
            local name = "Lantadyme incense sticks"
            if Player:getBuff(47713).found and Inventory:Contains(name) and
                Inventory:InvItemcountStack_Strings({name}) >= 6 then
                return API.DoAction_Inventory3(name, 0, 2,
                                               API.OFF_ACT_GeneralInterface_route)
            else
                return API.DoAction_Inventory3(name, 0, 1,
                                               API.OFF_ACT_GeneralInterface_route)
            end
        end,
        refreshAt = 660
    }, {
        buffName = "Elder overload",
        buffId = 49039,
        canApply = function()
            local ELDER_OLV_SALVE_IDS = {
                49042, 49044, 49046, 49048, 49050, 49052
            }
            return Inventory:Contains(ELDER_OLV_SALVE_IDS)
        end,
        execute = function()
            return Inventory:DoAction("Elder overload salve", 1,
                                      API.OFF_ACT_GeneralInterface_route)
        end,
        refreshAt = math.random(10, 20)
    }, {
        buffName = "Binding contract (ripper demon)",
        buffId = 26095,
        canApply = function()
            return Inventory:Contains("Binding contract (ripper demon)")
        end,
        execute = function()
            return Inventory:DoAction("Binding contract (ripper demon)", 1,
                                      API.OFF_ACT_GeneralInterface_route)
        end,
        refreshAt = 10
    }
}

-- ============================================================================
-- ROTATION PRESETS
-- ============================================================================

Presets.Rotations = {}

local targetCycleKey = 0x09

Presets.Rotations["BIS Equilibrium"] = {
    fightRotation = {
        {label = "Invoke Death", wait = 0}, {label = "Surge"},
        {label = "Command Vengeful Ghost", wait = 0}, {
            label = "Enhanced Excalibur",
            type = "Custom",
            action = function()
                PlayerManager.new():useExcalibur()
                return true
            end,
            wait = 0
        }, {label = "Surge"}, {label = "Command Skeleton Warrior", wait = 1}, {
            label = "Equip Salve amulet (e)",
            type = "Custom",
            action = function()
                return Inventory:Equip("Salve amulet (e)")
            end,
            wait = 2
        }, {
            label = "Target cycle",
            type = "Target cycle",
            wait = 0,
            targetCycleKey = targetCycleKey
        }, {label = "Vulnerability bomb", type = "Inventory", wait = 0},
        {label = "Death Skulls"}, {
            label = "Backup Attack Rasial",
            type = "Custom",
            condition = function()
                return (API.GetABs_name("Death Skulls", true).cooldown_timer ==
                           0)
            end,
            action = function()
                local rasial = Utils:find(30165, 1, 40)
                print("Target cycling failed: attempting to attack Rasial")
                if rasial then
                    --- @ diagnostic disable-next-line: missing-parameter
                    if API.DoAction_NPC(0x2a, API.OFF_ACT_AttackNPC_route,
                                        {30165}, 50) then
                        API.DoAction_Inventory1(48951, 0, 1,
                                                API.OFF_ACT_GeneralInterface_route)
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
        }, {label = "Soul Sap"}, {
            label = "War's Retreat Teleport",
            condition = function()
                return API.GetABs_name("Death Skulls", true).cooldown_timer <= 1
            end
        }, {label = "Touch of Death"}, {label = "Basic<nbsp>Attack"},
        {label = "Soul Sap", wait = 0}, {
            label = "Pause drinking for Adrenaline renewal",
            type = "Custom",
            action = function()
                PlayerManager.new():dontDrink(4)
                return true
            end
        }, {label = "Living Death", wait = 0},
        {label = "Adrenaline renewal", type = "Inventory"},
        {label = "Touch of Death"}, {label = "Death Skulls", useTicks = true},
        {
            label = "War's Retreat Teleport",
            condition = function()
                return API.GetABs_name("Living Death", true).cooldown_timer <= 1
            end
        }, {label = "Soul Sap", wait = 1, useTicks = true},
        {label = "Vengeance", wait = 2, useTicks = true},
        {label = "Split Soul"}, {label = "Divert"}, {label = "Bloat"},
        {label = "Soul Sap"}, {
            label = "Command Skeleton Warrior",
            condition = function() return Player:getAdrenaline() > 60 end,
            replacementLabel = "Basic<nbsp>Attack"
        }, {label = "Death Skulls", wait = 2},
        {label = "Undead Slayer", wait = 1}, {label = "Finger of Death"},
        {label = "Touch of Death"}, {label = "Soul Sap"},
        {label = "Volley of Souls"}, {label = "Finger of Death"},
        {label = "Soul Sap"}, {label = "Death Skulls"}, {label = "Bloat"},
        {label = "Command Putrid Zombie"}, {label = "Soul Sap"},
        {label = "Touch of Death"}, {label = "Command Skeleton Warrior"},
        {label = "Soul Sap"},
        {
            label = "Improvise",
            type = "Improvise",
            style = "Necromancy",
            spend = false
        }
    },

    finalRotation = {
        {label = "Basic<nbsp>Attack"},
        {label = "Vulnerability bomb", type = "Inventory", wait = 0}, {
            label = "Basic<nbsp>Attack",
            condition = function() return (API.GetAddreline_() < 60) end,
            wait = 3
        }, {
            label = "Basic<nbsp>Attack",
            condition = function() return (API.GetAddreline_() < 60) end,
            wait = 3
        }, {label = "Death Skulls"}, {label = "Soul Sap"}, {
            label = "Weapon Special Attack",
            condition = function()
                return (API.GetAdrenalineFromInterface() > 23) and
                           not Player:getDebuff(55524).found
            end
        }, {
            label = "Volley of Souls",
            condition = function()
                return Player:getBuff(30123).remaining > 1
            end
        }, {label = "Basic<nbsp>Attack", wait = 2}, {
            label = "Equip Essence of Finality",
            type = "Custom",
            condition = function()
                return (API.GetAdrenalineFromInterface() > 23) and
                           not Player:getDebuff(55524).found
            end,
            action = function()
                Inventory:Equip("Essence of Finality")
                return true
            end,
            wait = 1,
            replacementAction = function() return true end
        }, {
            label = "Essence of Finality",
            condition = function()
                return (API.GetAdrenalineFromInterface() > 23)
            end
        }, {
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

-- ============================================================================
-- BIS Equilibrium V2 (Modernized)
-- ============================================================================
-- Updated rotation using new rotation manager features:
-- - Cleaner step organization with section comments
-- - Consistent formatting and parameter usage
-- - Leverages new rotation manager capabilities
-- - Better error handling through validated steps
-- ============================================================================
Presets.Rotations["BIS Equilibrium V2"] = {
    fightRotation = {
        -- ====================================================================
        -- PRE-FIGHT: Buff Setup
        -- ====================================================================
        {label = "Invoke Death", wait = 0, useTicks = true},
        {label = "Surge", wait = 3, useTicks = true},
        {label = "Command Vengeful Ghost", wait = 0, useTicks = true}, {
            label = "Enhanced Excalibur",
            type = "Custom",
            action = function()
                PlayerManager.new():useExcalibur()
                return true
            end,
            wait = 0,
            useTicks = true
        }, {label = "Surge", wait = 3, useTicks = true},
        {label = "Command Skeleton Warrior", wait = 1, useTicks = true},

        -- ====================================================================
        -- ENGAGEMENT: Target and Apply Debuffs
        -- ====================================================================
        {
            label = "Equip Salve amulet (e)",
            type = "Custom",
            action = function()
                return Inventory:Equip("Salve amulet (e)")
            end,
            wait = 2,
            useTicks = true
        }, {
            label = "Target cycle",
            type = "Target cycle",
            targetCycleKey = targetCycleKey,
            wait = 0,
            useTicks = true
        },
        {
            label = "Vulnerability bomb",
            type = "Inventory",
            wait = 0,
            useTicks = true
        }, {label = "Death Skulls", wait = 3, useTicks = true}, {
            label = "Backup Attack Rasial",
            type = "Custom",
            condition = function()
                return API.GetABs_name("Death Skulls", true).cooldown_timer == 0
            end,
            action = function()
                local rasial = Utils:find(30165, 1, 40)
                if not rasial then return false end

                if API.DoAction_NPC(0x2a, API.OFF_ACT_AttackNPC_route, {30165},
                                    50) then
                    API.DoAction_Inventory1(48951, 0, 1,
                                            API.OFF_ACT_GeneralInterface_route)
                    return Utils:useAbility("Death Skulls")
                end

                return false
            end,
            wait = 3,
            useTicks = true,
            replacementAction = function()
                -- Target cycle succeeded, skip backup
                return true
            end,
            replacementWait = 0
        },

        -- ====================================================================
        -- PHASE 1: Build to Living Death
        -- ====================================================================
        {label = "Soul Sap", wait = 3, useTicks = true}, {
            label = "War's Retreat Teleport",
            condition = function()
                return API.GetABs_name("Death Skulls", true).cooldown_timer <= 1
            end,
            wait = 3,
            useTicks = true
        }, {label = "Touch of Death", wait = 3, useTicks = true},
        {label = "Basic<nbsp>Attack", wait = 3, useTicks = true},
        {label = "Soul Sap", wait = 0, useTicks = true}, {
            label = "Pause drinking for Adrenaline renewal",
            type = "Custom",
            action = function()
                PlayerManager.new():dontDrink(4)
                return true
            end,
            wait = 3,
            useTicks = true
        },

        -- ====================================================================
        -- LIVING DEATH: Ultimate Rotation
        -- ====================================================================
        {label = "Living Death", wait = 0, useTicks = true},
        {
            label = "Adrenaline renewal",
            type = "Inventory",
            wait = 3,
            useTicks = true
        }, {label = "Touch of Death", wait = 3, useTicks = true},
        {label = "Death Skulls", wait = 3, useTicks = true}, {
            label = "War's Retreat Teleport",
            condition = function()
                return API.GetABs_name("Living Death", true).cooldown_timer <= 1
            end,
            wait = 3,
            useTicks = true
        }, {label = "Soul Sap", wait = 1, useTicks = true},
        {label = "Vengeance", wait = 2, useTicks = true},
        {label = "Split Soul", wait = 3, useTicks = true},
        {label = "Divert", wait = 3, useTicks = true},
        {label = "Bloat", wait = 3, useTicks = true},
        {label = "Soul Sap", wait = 3, useTicks = true}, {
            label = "Command Skeleton Warrior",
            condition = function() return Player:getAdrenaline() > 60 end,
            replacementLabel = "Basic<nbsp>Attack",
            wait = 3,
            useTicks = true
        },

        -- ====================================================================
        -- POST-LIVING DEATH: High Damage Phase
        -- ====================================================================
        {label = "Death Skulls", wait = 2, useTicks = true},
        {label = "Undead Slayer", wait = 1, useTicks = true},
        {label = "Finger of Death", wait = 3, useTicks = true},
        {label = "Touch of Death", wait = 3, useTicks = true},
        {label = "Soul Sap", wait = 3, useTicks = true},
        {label = "Volley of Souls", wait = 3, useTicks = true},
        {label = "Finger of Death", wait = 3, useTicks = true},
        {label = "Soul Sap", wait = 3, useTicks = true},
        {label = "Death Skulls", wait = 3, useTicks = true},
        {label = "Bloat", wait = 3, useTicks = true},
        {label = "Command Putrid Zombie", wait = 3, useTicks = true},
        {label = "Soul Sap", wait = 3, useTicks = true},
        {label = "Touch of Death", wait = 3, useTicks = true},
        {label = "Command Skeleton Warrior", wait = 3, useTicks = true},
        {label = "Soul Sap", wait = 3, useTicks = true},

        -- ====================================================================
        -- IMPROVISE: Adaptive Filler
        -- ====================================================================
        {
            label = "Improvise",
            type = "Improvise",
            style = "Necromancy",
            spend = false
            -- Note: continueAfterImprovise defaults to false, creating infinite loop
        }
    },

    finalRotation = {
        -- ====================================================================
        -- FINAL PHASE: Execute Range
        -- ====================================================================
        {label = "Basic<nbsp>Attack", wait = 3, useTicks = true},
        {
            label = "Vulnerability bomb",
            type = "Inventory",
            wait = 0,
            useTicks = true
        }, {
            label = "Build adrenaline",
            type = "Custom",
            condition = function() return API.GetAddreline_() < 60 end,
            action = function()
                return Utils:useAbility("Basic<nbsp>Attack")
            end,
            wait = 3,
            useTicks = true,
            replacementAction = function()
                -- Adrenaline already sufficient
                return true
            end,
            replacementWait = 0
        }, {
            label = "Build adrenaline backup",
            type = "Custom",
            condition = function() return API.GetAddreline_() < 60 end,
            action = function()
                return Utils:useAbility("Basic<nbsp>Attack")
            end,
            wait = 3,
            useTicks = true,
            replacementAction = function()
                -- Adrenaline already sufficient
                return true
            end,
            replacementWait = 0
        }, {label = "Death Skulls", wait = 3, useTicks = true},
        {label = "Soul Sap", wait = 3, useTicks = true},

        -- ====================================================================
        -- WEAPON SPECIAL: Conditional Execution
        -- ====================================================================
        {
            label = "Weapon Special Attack",
            condition = function()
                return API.GetAdrenalineFromInterface() > 23 and
                           not Player:getDebuff(55524).found
            end,
            wait = 3,
            useTicks = true
        }, {
            label = "Volley of Souls",
            condition = function()
                local souls = Player:getBuff(30123)
                return souls.found and souls.remaining > 1
            end,
            wait = 3,
            useTicks = true
        }, {label = "Basic<nbsp>Attack", wait = 2, useTicks = true},

        -- ====================================================================
        -- ESSENCE OF FINALITY: Equipment Swap Sequence
        -- ====================================================================
        {
            label = "Equip Essence of Finality",
            type = "Custom",
            condition = function()
                return API.GetAdrenalineFromInterface() > 23 and
                           not Player:getDebuff(55524).found
            end,
            action = function()
                return Inventory:Equip("Essence of Finality")
            end,
            wait = 1,
            useTicks = true,
            replacementAction = function()
                -- Condition not met, skip equip
                return true
            end,
            replacementWait = 0
        }, {
            label = "Essence of Finality",
            condition = function()
                return API.GetAdrenalineFromInterface() > 23
            end,
            wait = 3,
            useTicks = true
        }, {
            label = "Equip Salve amulet (e)",
            type = "Custom",
            action = function()
                if #Inventory:GetItem("Salve amulet (e)") > 0 then
                    return Inventory:Equip("Salve amulet (e)")
                end
                return true
            end,
            wait = 0,
            useTicks = true
        },

        -- ====================================================================
        -- IMPROVISE: Aggressive Spending
        -- ====================================================================
        {
            label = "Improvise",
            type = "Improvise",
            style = "Necromancy",
            spend = true
            -- Loops indefinitely with aggressive resource spending
        }
    }
}

Presets.Rotations["BIS Supreme Invigoration"] = {
    fightRotation = {
        {label = "Invoke Death", wait = 0}, {label = "Surge"},
        {label = "Command Vengeful Ghost", wait = 0}, {label = "Surge"},
        {label = "Command Skeleton Warrior", wait = 1},
        {label = "Augmented Roar of Awakening", type = "Equip", wait = 0},
        {label = "Salve amulet (e)", type = "Equip", wait = 2}, {
            label = "Target cycle",
            type = "Target cycle",
            wait = 0,
            targetCycleKey = targetCycleKey
        }, {label = "Vulnerability bomb", type = "Inventory", wait = 0},
        {label = "Smoke Cloud", wait = 0},
        {label = "Augmented Omni guard", type = "Equip", wait = 0},
        {label = "Death Skulls"}, {
            label = "Backup Attack Rasial",
            type = "Custom",
            condition = function()
                return (API.GetABs_name("Death Skulls", true).cooldown_timer ==
                           0)
            end,
            action = function()
                local rasial = Utils:find(30165, 1, 40)
                print("Target cycling failed: attempting to attack Rasial")
                if rasial then
                    --- @ diagnostic disable-next-line: missing-parameter
                    if API.DoAction_NPC(0x2a, API.OFF_ACT_AttackNPC_route,
                                        {30165}, 50) then
                        API.DoAction_Inventory1(48951, 0, 1,
                                                API.OFF_ACT_GeneralInterface_route)
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
        }, {label = "Soul Sap" --[[, wait = 0]] }, --[[ {
            label = "Pause drinking for Adrenaline renewal",
            type = "Custom",
            action = function()
                PlayerManager.new():dontDrink(4)
                return true
            end
        }, ]] {
            label = "War's Retreat Teleport",
            condition = function()
                return API.GetABs_name("Death Skulls", true).cooldown_timer <= 1
            end
        }, {label = "Touch of Death", wait = 0},
        {label = "Adrenaline renewal", type = "Inventory"},
        {label = "Living Death", wait = 0},
        {label = "Adrenaline renewal", type = "Inventory"},
        {label = "Soul Sap"}, {label = "Death Skulls"}, {
            label = "War's Retreat Teleport",
            condition = function()
                return API.GetABs_name("Living Death", true).cooldown_timer <= 1
            end
        }, {label = "Touch of Death"}, {label = "Split Soul"},
        {label = "Soul Sap"}, {label = "Bloat"}, {label = "Basic<nbsp>Attack"},
        {label = "Soul Sap"}, {label = "Death Skulls", wait = 2},
        {label = "Undead Slayer", wait = 1}, {label = "Finger of Death"},
        {label = "Touch of Death"}, {label = "Soul Sap"},
        {label = "Volley of Souls"}, {label = "Finger of Death"},
        {label = "Soul Sap"}, {label = "Death Skulls"}, {label = "Bloat"},
        {label = "Command Putrid Zombie"}, {label = "Soul Sap"},
        {label = "Touch of Death"}, {label = "Command Skeleton Warrior"},
        {label = "Soul Sap"},
        {
            label = "Improvise",
            type = "Improvise",
            style = "Necromancy",
            spend = false
        }
    },

    finalRotation = {
        {label = "Basic<nbsp>Attack"},
        {label = "Vulnerability bomb", type = "Inventory", wait = 0}, {
            label = "Basic<nbsp>Attack",
            condition = function() return (API.GetAddreline_() < 60) end,
            wait = 3
        }, {
            label = "Basic<nbsp>Attack",
            condition = function() return (API.GetAddreline_() < 60) end,
            wait = 3
        }, {label = "Death Skulls"}, {
            label = "Soul Sap",
            condition = function()
                return Player:getBuff(30123).remaining < 5
            end
        }, {
            label = "Weapon Special Attack",
            condition = function()
                return (API.GetAdrenalineFromInterface() > 23) and
                           not Player:getDebuff(55524).found
            end
        }, {
            label = "Volley of Souls",
            condition = function()
                return Player:getBuff(30123).remaining > 1
            end
        }, {label = "Basic<nbsp>Attack", wait = 2}, {
            label = "Equip Augmented Death guard",
            type = "Custom",
            condition = function()
                return (API.GetAdrenalineFromInterface() > 23) and
                           not Player:getDebuff(55524).found
            end,
            action = function()
                Inventory:Equip("Augmented Death guard")
                return true
            end,
            wait = 1,
            replacementAction = function() return true end
        }, {
            label = "Weapon Special Attack",
            condition = function()
                return (API.GetAdrenalineFromInterface() > 23)
            end
        }, {label = "Augmented Omni guard", type = "Equip", wait = 0},
        {label = "Touch of Death"},
        {
            label = "Improvise",
            type = "Improvise",
            style = "Necromancy",
            spend = true
        }
    }
}

Presets.Rotations["T95, No CoE, No FotS"] = {
    fightRotation = {
        {
            label = "Delay",
            type = "Custom",
            action = function() return true end,
            wait = 1
        }, {
            label = "Salve amulet (e)",
            type = "Custom",
            action = function()
                return Inventory:Equip("Salve amulet (e)")
            end,
            wait = 0
        }, {label = "Invoke Death", wait = 0}, {label = "Surge"},
        {label = "Command Vengeful Ghost", wait = 0}, {label = "Surge"}, {
            label = "Ring of vigour",
            type = "Custom",
            action = function()
                return Inventory:Equip("Ring of vigour")
            end,
            wait = 0
        }, {label = "Command Skeleton Warrior"}, {
            label = "Target cycle",
            type = "Target cycle",
            targetCycleKey = targetCycleKey,
            wait = 0
        }, {label = "Vulnerability bomb", type = "Inventory"},
        {label = "Death Skulls"}, {
            label = "Occultist's ring",
            type = "Custom",
            action = function()
                return Inventory:Equip("Occultist's ring")
            end,
            wait = 0
        }, {label = "Soul Sap"}, {label = "Touch of Death"},
        {label = "Basic<nbsp>Attack"}, {label = "Soul Sap"},
        {label = "Basic<nbsp>Attack"}, {label = "Basic<nbsp>Attack"}, {
            label = "Ring of vigour",
            type = "Custom",
            action = function()
                return Inventory:Equip("Ring of vigour")
            end,
            wait = 0
        }, {label = "Living Death", wait = 0},
        {label = "Adrenaline renewal", type = "Inventory"}, {
            label = "Occultist's ring",
            type = "Custom",
            action = function()
                return Inventory:Equip("Occultist's ring")
            end,
            wait = 0
        }, {label = "Touch of Death"}, {label = "Command Skeleton Warrior"},
        {label = "Divert"}, {
            label = "Ring of vigour",
            type = "Custom",
            action = function()
                return Inventory:Equip("Ring of vigour")
            end,
            wait = 0
        }, {label = "Death Skulls"}, {
            label = "Occultist's ring",
            type = "Custom",
            action = function()
                return Inventory:Equip("Occultist's ring")
            end,
            wait = 0
        }, {label = "Soul Sap"}, {label = "Basic<nbsp>Attack"},
        {label = "Basic<nbsp>Attack"}, {label = "Soul Sap"},
        {label = "Touch of Death"}, {label = "Split Soul"}, {
            label = "Ring of vigour",
            type = "Custom",
            action = function()
                return Inventory:Equip("Ring of vigour")
            end,
            wait = 0
        }, {label = "Death Skulls"}, {
            label = "Occultist's ring",
            type = "Custom",
            action = function()
                return Inventory:Equip("Occultist's ring")
            end,
            wait = 0
        }, {label = "Command Skeleton Warrior"}, {label = "Soul Sap"},
        {label = "Volley of Souls"}, {label = "Finger of Death"},
        {label = "Bloat"}, {label = "Touch of Death"}, {
            label = "Ring of vigour",
            type = "Custom",
            action = function()
                return Inventory:Equip("Ring of vigour")
            end,
            wait = 0
        }, {
            label = "Essence of Finality",
            type = "Custom",
            action = function()
                return Inventory:Equip("Essence of Finality")
            end,
            wait = 0
        }, {label = "Essence of Finality"}, {
            label = "Salve amulet (e)",
            type = "Custom",
            action = function()
                return Inventory:Equip("Salve amulet (e)")
            end,
            wait = 0
        }, {
            label = "Occultist's ring",
            type = "Custom",
            action = function()
                return Inventory:Equip("Occultist's ring")
            end,
            wait = 0
        }, {label = "Soul Sap"}, {label = "Basic<nbsp>Attack"},
        {label = "Bloat"}, {label = "Soul Sap"},
        {
            label = "Improvise",
            type = "Improvise",
            style = "Necromancy",
            spend = false
        }
    },

    finalRotation = {
        {label = "Basic<nbsp>Attack"}, {
            label = "Basic<nbsp>Attack",
            condition = function() return (API.GetAddreline_() < 60) end,
            wait = 3
        }, {label = "Vulnerability bomb", type = "Inventory", wait = 0},
        {label = "Death Skulls"}, {label = "Soul Sap"}, {
            label = "Weapon Special Attack",
            condition = function()
                return (API.GetAdrenalineFromInterface() > 30) and
                           not Player:getDebuff(55524).found
            end
        }, {
            label = "Volley of Souls",
            condition = function()
                return Player:getBuff(30123).remaining > 1
            end
        }, {label = "Basic<nbsp>Attack"}, {
            label = "Ring of vigour",
            type = "Custom",
            action = function()
                return Inventory:Equip("Ring of vigour")
            end,
            wait = 0
        }, {
            label = "Essence of Finality",
            type = "Custom",
            action = function()
                return Inventory:Equip("Essence of Finality")
            end,
            wait = 0
        }, {label = "Essence of Finality"}, {
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

Presets.Rotations["[0xB0BABAE] T90"] = {
    fightRotation = {
        {
            label = "Delay",
            type = "Custom",
            action = function() return true end,
            wait = 1
        }, {label = "Command Vengeful Ghost", wait = 0},
        {label = "Surge", wait = 3, useTicks = true},
        {label = "Command Skeleton Warrior"}, {
            label = "Salve amulet (e)",
            type = "Custom",
            action = function()
                return Inventory:Equip("Salve amulet (e)")
            end,
            wait = 0
        }, {label = "Reflect"}, {
            label = "Target cycle",
            type = "Target cycle",
            targetCycleKey = targetCycleKey,
            wait = 0
        }, {label = "Vulnerability bomb", type = "Inventory", wait = 0},
        {label = "Bloat"}, {label = "Soul Sap"}, {label = "Death Skulls"},
        {label = "Touch of Death"}, {label = "Soul Sap"},
        {label = "Basic<nbsp>Attack"}, {label = "Basic<nbsp>Attack"},
        {label = "Soul Sap"}, {label = "Command Skeleton Warrior"},
        {label = "Living Death", wait = 0},
        {label = "Adrenaline renewal", type = "Inventory"},
        {label = "Touch of Death"}, {label = "Death Skulls"},
        {label = "Divert"}, {label = "Split Soul"}, {label = "Volley of Souls"},
        {label = "Soul Sap"}, {label = "Finger of Death"},
        {label = "Command Skeleton Warrior"},
        {label = "Death Skulls", wait = 2, useTicks = true},
        {label = "Undead Slayer", wait = 1, useTicks = true},
        {label = "Soul Sap"}, {label = "Touch of Death"},
        {label = "Finger of Death"}, {label = "Soul Sap"},
        {label = "Volley of Souls"}, {
            label = "Finger of Death",
            condition = function()
                local necrosisStacks = Player:getBuff(30101).found and
                                           Player:getBuff(30101).remaining or 0
                return necrosisStacks >= 6
            end,
            replacementLabel = "Basic<nbsp>Attack"
        }, {label = "Death Skulls"}, {label = "Soul Sap"}, {label = "Bloat"},
        {label = "Command Skeleton Warrior"}, {label = "Touch of Death"},
        {label = "Soul Sap"}, {label = "Soul Strike"}, {
            label = "Finger of Death",
            condition = function()
                local necrosisStacks = Player:getBuff(30101).found and
                                           Player:getBuff(30101).remaining or 0
                return necrosisStacks >= 4
            end,
            replacementLabel = "Basic<nbsp>Attack"
        }, {label = "Soul Sap"}, {label = "Soul Strike"}, {
            label = "Finger of Death",
            condition = function()
                local necrosisStacks = Player:getBuff(30101).found and
                                           Player:getBuff(30101).remaining or 0
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
                return Player:getBuff(34178).found and
                           Player:getBuff(34178).remaining >= 2
            end,
            replacementLabel = "Conjure Undead Army"
        }, {label = "Death Skulls", wait = 0},
        {
            label = "Vulnerability bomb",
            type = "Inventory",
            wait = 3,
            useTicks = true
        }, {label = "Powerburst of vitality", wait = 0}, {
            label = "Reflect",
            condition = function() return API.GetAddreline_() >= 50 end,
            replacementLabel = "Divert"
        }, {label = "Command Skeleton Warrior"}, {label = "Finger of Death"}, {
            label = "Weapon Special Attack",
            condition = function()
                return (API.GetAdrenalineFromInterface() > 23) and
                           not Player:getDebuff(55524).found
            end
        }, {label = "Soul Sap"}, {label = "Volley of Souls"},
        {label = "Touch of Death"}, {label = "Command Putrid Zombie"},
        {label = "Finger of Death"},
        {
            label = "Improvise",
            type = "Improvise",
            style = "Necromancy",
            spend = true
        }
    }
}

Presets.Rotations["[Arshalo] T95"] = {
    fightRotation = {
        {
            label = "Delay",
            type = "Custom",
            action = function() return true end,
            wait = 1
        }, {label = "Command Vengeful Ghost"},
        {label = "Invoke Death", wait = 1}, {
            label = "Salve amulet (e)",
            type = "Custom",
            action = function()
                return Inventory:Equip("Salve amulet (e)")
            end,
            wait = 0
        }, {label = "Surge", wait = 2}, {label = "Command Skeleton Warrior"}, {
            label = "Target cycle",
            type = "Target cycle",
            wait = 0,
            targetCycleKey = targetCycleKey
        }, {label = "Vulnerability"},
        {label = "Death Skulls", wait = 1, useTicks = true}, {
            label = "Backup Attack Rasial",
            type = "Custom",
            condition = function()
                return (API.ReadTargetInfo99(true).Hitpoints <= 0) and
                           (API.GetABs_name1("Death Skulls").cooldown_timer <= 0)
            end,
            action = function()
                local rasial = Utils:find(30165, 1, 40)
                if rasial then
                    ---@diagnostic disable-next-line
                    if API.DoAction_NPC(0x2a, API.OFF_ACT_AttackNPC_route,
                                        {30165}, 50) then
                        return Utils:_useAbility("Death Skulls")
                    end
                else
                    return false
                end
            end,
            wait = 3,
            useTicks = true,
            replacementAction = function() return true end,
            replacementWait = 2
        }, {label = "Soul Sap"}, {label = "Touch of Death"},
        {label = "Basic<nbsp>Attack"}, {label = "Soul Sap"},
        {label = "Bloat", wait = 1, useTicks = true}, {
            label = "Augmented Death guard",
            type = "Custom",
            action = function()
                return Inventory:Equip("Augmented Death guard")
            end,
            wait = 2,
            useTicks = true
        }, {label = "Weapon Special Attack", wait = 1, useTicks = true}, {
            label = "Augmented Omni guard",
            type = "Custom",
            action = function()
                return Inventory:Equip("Augmented Omni guard")
            end,
            wait = 2,
            useTicks = true
        }, {label = "Soul Sap"}, {label = "Volley of Souls"},
        {label = "Command Skeleton Warrior", useTicks = true},
        {label = "Soul Sap"}, {label = "Touch of Death"},
        {label = "Basic<nbsp>Attack"}, {label = "Soul Sap"},
        {label = "Weapon Special Attack"}, {label = "Basic<nbsp>Attack"},
        {label = "Soul Sap"}, {label = "Basic<nbsp>Attack"},
        {label = "Living Death", wait = 0},
        {label = "Replenishment potion", type = "Inventory"},
        {label = "Touch of Death"}, {label = "Basic<nbsp>Attack"},
        {label = "Death Skulls", useTicks = true}, {label = "Split Soul"},
        {label = "Basic<nbsp>Attack"}, {label = "Volley of Souls"},
        {label = "Finger of Death"}, {label = "Basic<nbsp>Attack"},
        {label = "Finger of Death"}, {label = "Basic<nbsp>Attack"},
        {label = "Touch of Death"}, {label = "Basic<nbsp>Attack"},
        {label = "Death Skulls", useTicks = true},
        {label = "Basic<nbsp>Attack"}, {label = "Finger of Death"},
        {label = "Finger of Death"}, {label = "Soul Sap"},
        {label = "Vulnerability"}, {label = "Touch of Death"},
        {label = "Soul Sap"}, {label = "Command Skeleton Warrior"},
        {label = "Basic<nbsp>Attack"}, {label = "Soul Sap"},
        {label = "Basic<nbsp>Attack"}, {label = "Basic<nbsp>Attack"}, {
            label = "Improvise",
            type = "Improvise",
            style = "Necromancy",
            spendAdren = false
        }
    },

    finalRotation = {
        {label = "Soul Sap"},
        {label = "Death Skulls", wait = 1, useTicks = true}, {
            label = "Augmented Death guard",
            type = "Custom",
            action = function()
                return Inventory:Equip("Augmented Death guard")
            end,
            wait = 2,
            useTicks = true
        }, {label = "Weapon Special Attack", wait = 1, useTicks = true}, {
            label = "Augmented Omni guard",
            type = "Custom",
            action = function()
                return Inventory:Equip("Augmented Omni guard")
            end,
            wait = 2,
            useTicks = true
        }, {label = "Soul Sap"}, {label = "Volley of Souls"},
        {label = "Basic<nbsp>Attack"}, {label = "Soul Sap"},
        {label = "Basic<nbsp>Attack"}, {label = "Weapon Special Attack"},
        {label = "Basic<nbsp>Attack"}, {label = "Touch of Death"},
        {label = "Basic<nbsp>Attack"}, {label = "Finger of Death"},
        {label = "Basic<nbsp>Attack"}, {
            label = "Improvise",
            type = "Improvise",
            style = "Necromancy",
            spendAdren = true
        }
    }
}

Presets.Rotations["[Matteus] T95"] = {
    fightRotation = {
        {
            label = "Delay",
            type = "Custom",
            action = function() return true end,
            wait = 1
        }, {label = "Command Vengeful Ghost"},
        {label = "Invoke Death", wait = 1}, {
            label = "Salve amulet (e)",
            type = "Custom",
            action = function()
                return Inventory:Equip("Salve amulet (e)")
            end,
            wait = 0
        }, {label = "Surge", wait = 2}, {label = "Command Skeleton Warrior"}, {
            label = "Target cycle",
            type = "Target cycle",
            wait = 0,
            targetCycleKey = targetCycleKey
        }, {label = "Vulnerability"},
        {label = "Death Skulls", wait = 1, useTicks = true}, {
            label = "Backup Attack Rasial",
            type = "Custom",
            condition = function()
                return (API.ReadTargetInfo99(true).Hitpoints <= 0) and
                           (API.GetABs_name1("Death Skulls").cooldown_timer <= 0)
            end,
            action = function()
                local rasial = Utils:find(30165, 1, 40)
                if rasial then
                    ---@diagnostic disable-next-line
                    if API.DoAction_NPC(0x2a, API.OFF_ACT_AttackNPC_route,
                                        {30165}, 50) then
                        return Utils:_useAbility("Death Skulls")
                    end
                else
                    return false
                end
            end,
            wait = 3,
            useTicks = true,
            replacementAction = function() return true end,
            replacementWait = 2
        }, {label = "Soul Sap"}, {label = "Bloat"}, {label = "Touch of Death"},
        {label = "Basic<nbsp>Attack"}, {label = "Soul Sap"},
        {label = "Basic<nbsp>Attack"}, {label = "Command Skeleton Warrior"},
        {label = "Living Death", wait = 0},
        {label = "Replenishment potion", type = "Inventory"},
        {label = "Touch of Death"}, {label = "Death Skulls"},
        {label = "Split Soul"}, {label = "Finger of Death"},
        {label = "Basic<nbsp>Attack"}, {label = "Basic<nbsp>Attack"},
        {label = "Basic<nbsp>Attack"}, {label = "Basic<nbsp>Attack"},
        {label = "Death Skulls"}, {label = "Finger of Death"},
        {label = "Touch of Death"}, {label = "Basic<nbsp>Attack"},
        {label = "Basic<nbsp>Attack"}, {label = "Finger of Death"},
        {label = "Finger of Death"}, {label = "Death Skulls"},
        {label = "Life Transfer"}, {label = "Soul Sap"},
        {label = "Volley of Souls"}, {label = "Command Skeleton Warrior"},
        {label = "Basic<nbsp>Attack"}, {label = "Soul Sap"},
        {label = "Vulnerability"}, {label = "Command Putrid Zombie"},
        {label = "Touch of Death"}, {label = "Bloat"},
        {
            label = "Improvise",
            type = "Improvise",
            style = "Necromancy",
            spend = false
        }
    },

    finalRotation = {
        {label = "Basic<nbsp>Attack"}, {
            label = "Basic<nbsp>Attack",
            condition = function() return (API.GetAddreline_() < 60) end,
            wait = 3,
            useTicks = true
        }, {label = "Death Skulls"}, {label = "Soul Sap"}, {
            label = "Weapon Special Attack",
            condition = function()
                return (API.GetAdrenalineFromInterface() > 23) and
                           not Player:getDebuff(55524).found
            end
        }, -- here
        {
            label = "Volley of Souls",
            condition = function()
                return Player:getBuff(30123).remaining > 1
            end
        }, -- here
        {label = "Basic<nbsp>Attack", wait = 2}, {
            label = "Equip Essence of Finality",
            type = "Custom",
            condition = function()
                return (API.GetAdrenalineFromInterface() > 23) and
                           not Player:getDebuff(55524).found
            end,
            action = function()
                Inventory:Equip("Essence of Finality")
                return true
            end,
            useTicks = true,
            wait = 1,
            replacementAction = function() return true end
        }, {
            label = "Essence of Finality",
            condition = function()
                return (API.GetAdrenalineFromInterface() > 23)
            end
        }, -- here
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
        }, -- here
        {label = "Touch of Death"}, {label = "Finger of Death"},
        {
            label = "Improvise",
            type = "Improvise",
            style = "Necromancy",
            spend = true
        }
    }
}

Presets.Rotations["[Oogle] T100, No Relics"] = {
    -- this rotation references and tries to match the equilibrium rotation listed on the PVME
    -- assumes t100 weapons and t99 prayers, amongst other best-in-slot items
    fightRotation = {
        -- prefight steps
        {label = "Command Vengeful Ghost"},
        -- {label = "Salve amulet (e)", type = "Custom", action = function() return Inventory:Equip("Salve amulet (e)") end, wait = 0},
        {label = "Invoke Lord of Bones", wait = 0},
        {label = "Surge", wait = 2, useTicks = true},
        {label = "Command Skeleton Warrior", wait = 4, useTicks = true}, --- <-- ADD THIS WAIT
        {
            label = "Target cycle",
            type = "Target cycle",
            wait = 0,
            targetCycleKey = targetCycleKey
        }, -- back up attack rasial if tc misses
        {
            label = "Backup Attack Rasial",
            type = "Custom",
            condition = function()
                return (API.GetABs_name("Death Skulls", true).cooldown_timer ==
                           0)
            end,
            action = function()
                local rasial = Utils:find(30165, 1, 40)
                print("Target cycling failed: attempting to attack Rasial")
                if rasial then
                    --- @ diagnostic disable-next-line: missing-parameter
                    if API.DoAction_NPC(0x2a, API.OFF_ACT_AttackNPC_route,
                                        {30165}, 50) then
                        API.DoAction_Inventory1(48951, 0, 1,
                                                API.OFF_ACT_GeneralInterface_route)
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
        }, {label = "Invoke Death", wait = 3}, {
            label = "Vulnerability bomb",
            type = "Custom",
            action = function()
                return API.DoAction_Inventory1(48951, 0, 1,
                                               API.OFF_ACT_GeneralInterface_route)
            end,
            wait = 0
        }, -- {label = "Death Skulls"},
        {label = "Soul Sap"}, {label = "Bloat"}, {label = "Touch of Death"},
        {label = "Basic<nbsp>Attack"}, {label = "Soul Sap"},
        {label = "Basic<nbsp>Attack"}, {label = "Command Skeleton Warrior"},
        {label = "Resonance"}, -- living death steps
        {label = "Undead Slayer", wait = 2, useTicks = false},
        {label = "Living Death", wait = 0},
        {label = "Enhanced replenishment potion", type = "Inventory"},
        {label = "Touch of Death"}, {label = "Death Skulls", useTicks = true},
        {label = "Split Soul"}, {label = "Finger of Death"},
        {label = "Basic<nbsp>Attack"}, {label = "Basic<nbsp>Attack"},
        {label = "Basic<nbsp>Attack"}, {label = "Basic<nbsp>Attack"},
        {label = "Death Skulls", useTicks = true}, {label = "Finger of Death"},
        {label = "Touch of Death"}, {label = "Basic<nbsp>Attack"},
        {label = "Basic<nbsp>Attack"}, {label = "Finger of Death"},
        {label = "Finger of Death"}, {label = "Death Skulls", useTicks = true},
        -- post living death steps
        {label = "Life Transfer"}, {label = "Soul Sap"},
        {label = "Volley of Souls"}, {label = "Command Skeleton Warrior"},
        {label = "Basic<nbsp>Attack"}, {label = "Soul Sap"},
        {label = "Vulnerability"}, {label = "Command Putrid Zombie"},
        {label = "Touch of Death"}, {label = "Bloat"},
        {
            label = "Improvise",
            type = "Improvise",
            style = "Necromancy",
            spend = false
        }, {label = "Touch of Death"},
        {label = "Conjure Undead Army", wait = 4, useTicks = true},
        {label = "Soul Sap"}, {label = "Command Skeleton Warrior"},
        {label = "Basic<nbsp>Attack"}, {label = "Soul Sap"},
        {label = "Basic<nbsp>Attack"}, {label = "Basic<nbsp>Attack"}, {
            label = "Improvise",
            type = "Improvise",
            style = "Necromancy",
            spendAdren = true
        }

    },
    finalRotation = {
        -- final phase steps
        {label = "Basic<nbsp>Attack"}, -- backup basic attack
        {
            label = "Basic<nbsp>Attack",
            condition = function() return (API.GetAddreline_() < 60) end,
            wait = 3,
            useTicks = true
        }, {label = "Conjure Undead Army", wait = 4, useTicks = true}, {
            label = "Vulnerability bomb",
            type = "Custom",
            action = function()
                return API.DoAction_Inventory1(48951, 0, 1,
                                               API.OFF_ACT_GeneralInterface_route)
            end,
            wait = 0
        }, {label = "Death Skulls"}, {label = "Soul Sap"}, {
            label = "Weapon Special Attack",
            condition = function()
                return (API.GetAdrenalineFromInterface() > 25) and
                           not Player:getDebuff(55524).found
            end
        }, -- here
        {
            label = "Volley of Souls",
            condition = function()
                return Player:getBuff(30123).remaining > 1
            end
        }, -- here
        {label = "Basic<nbsp>Attack", wait = 2},
        {label = "Undead Slayer", wait = 2, useTicks = false}, {
            label = "Equip Essence of Finality",
            type = "Custom",
            condition = function()
                return (API.GetAdrenalineFromInterface() > 25) and
                           not Player:getDebuff(55524).found
            end,
            action = function()
                Inventory:Equip("Essence of Finality")
                return true
            end,
            useTicks = true,
            wait = 1,
            replacementAction = function() return true end
        }, {
            label = "Essence of Finality",
            condition = function()
                return (API.GetAdrenalineFromInterface() > 25)
            end
        }, -- here
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
        }, -- here
        {label = "Touch of Death"}, {label = "Finger of Death"}, -- improvise
        {
            label = "Improvise",
            type = "Improvise",
            style = "Necromancy",
            spend = true
        }
    }
}

-- Additional rotation presets can be added here.

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--- Get a list of all inventory preset names
--- @return string[]
function Presets.getInventoryPresetNames()
    local names = {}
    for name, _ in pairs(Presets.Inventory) do table.insert(names, name) end
    table.sort(names)
    return names
end

--- Get a list of all equipment preset names
--- @return string[]
function Presets.getEquipmentPresetNames()
    local names = {}
    for name, _ in pairs(Presets.Equipment) do table.insert(names, name) end
    table.sort(names)
    return names
end

--- Get a list of all rotation preset names
--- @return string[]
function Presets.getRotationPresetNames()
    local names = {}
    for name, _ in pairs(Presets.Rotations) do table.insert(names, name) end
    table.sort(names)
    return names
end

--- Get a list of all buffs preset names
--- @return string[]
function Presets.getBuffsPresetNames()
    local names = {}
    for name, _ in pairs(Presets.Buffs) do table.insert(names, name) end
    table.sort(names)
    return names
end

return Presets
