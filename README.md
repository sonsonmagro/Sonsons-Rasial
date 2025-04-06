# [v1.0.2] Sonson's Rasial

A comprehensive PvM script that demonstrates advanced use of my Lua libraries and script structuring for efficient combat automation.

**Disclaimer:**
> **Note:** I do understand that this script could have been much simpler, but the main purpose of this release is to showcase the libraries being used and their potential when making more complex PVM'ing scripts

---

## Requirements

> **Warning:** Ignoring this list may lead to suboptimal results.

- These requirements apply primarily to the default rotations and systems.
- The script is designed to allow significant flexibility and customization.

### Relics
- Conservation of Energy
- Fury of the Small

### Equipment
- T100 Omni Guard & Soulbound Lantern
- Weapon Perks:
  - Aftershock 4 + Equilibrium 2
  - Precise 6 + Ruthless 1
- Full set of First Necromancer Robes
- Armor Perks:
  - Crackling 4 + Relentless 5
  - Invigorating 4 + Undead Slayer
  - Impatient 4 + Mobile
- Essence of Finality with T70 Death Guard
- Equilibrium Aura
- Salve Amulet (e)
- Scripture of Ful (charged)

### Preset 
![image](https://github.com/user-attachments/assets/80df12de-e11b-4bfd-9463-ce8efcf92bdb)

### Unlocks and Misc.
- T99 Necromancy curses
- Elder Overloads
- Adrenaline Renewals
- Vulnerability Bombs
- Lantadyme Incense Sticks
- Ripper Demon Binding Contracts

---

## Features
- **Customization:** Easily customizable settings, rotations, and buffs.
- **Inventory Detection:** Automatic detection of food and prayer items.
- **Combat Handling:** Smooth management of combat mechanics.
- **Efficient Banking:** Optimized banking and reset systems to maximize kills per hour.
- **Adaptive Rotations:** Ability to improvise rotations based on boss health and available resources.
- **Discord Notifications:** Custom notifications when you get a drop!
  
![image](https://github.com/user-attachments/assets/5139bbef-46fc-4869-9447-6faf98bf2dcb)

---

## Upcoming Features
- Aura Management
- Custom GUI
- Preset Management

---

## Installation
1. Setup your `Lua_Scripts` folder to include both the `rasial` and `core` files.
   - It should look something like this:
      ```bash
      Lua_Scripts/
      ├── core/
      │   ├── player_manager.lua
      │   ├── prayer_flicker.lua
      │   ├── rotation_manager.lua
      │   └── timer.lua
      └── rasial/
          ├── main.lua
          ├── config.lua
          └── utils.lua
      ```
2. Configure settings in `rasial/config.lua` under `Config.UserInput`.
   - Adjust the values below to your needs.
    ```lua
    Config.UserInput = {
        -- essential
        useBankPin = true,
        bankPin = 1234,                 -- use ur own [0000 will spam your console]
        targetCycleKey = 0x09,          -- 0x09 is tab
        -- health and prayer thresholds (settings for player manager)
        healthThreshold = {
            normal =   {type = "percent", value = 50},
            critical = {type = "percent", value = 50},
            special =  {type = "percent", value = 75}  -- excal threshold
        },
        prayerThreshold = {
            normal =   {type = "current", value = 200},
            critical = {type = "percent", value = 10},
            special =  {type = "current", value = 600}  -- elven shard threshold
        },
        -- things to check in your inventory before fight
        presetChecks = {
            {id = 48951, amount = 10}, -- vuln bombs
            {id = 29448, amount = 4},  -- guthix rests
            {id = 42267, amount = 8},  -- blue blubbers
        },
        --discord (private method)
        discordNotifications = true,
        webhookUrl = "WEBHOOK_URL_HERE",
        mention = true,
        userId = "123456789101112"
    }
    ```
3. Adjust buffs as needed in `Config.Buffs`.
   - Adjust to your liking by adding, removing or modifying them.
    ```lua
    Config.Buffs = {
        {
            buffName = "Ruination",      -- used in activating the buff from inventory or ability bar
            buffId = 30769,              -- used to track the buff's activity
            canApply = function(self)    -- used to check if the buff CAN be applied
                return (self.state.prayer.current > 100)
            end,
            execute = function()         -- used apply the buff. MUST have a return
                return Utils.useAbility("Ruination")
            end,
            toggle = true                -- used to check if the buff needs to be toggled off when not being managed
            -- refreshAt = 10            -- when remaining time on the buff reaches this number, the buff is refreshed
        },
        -- add as many as you want
    }
    ```

5. Modify rotation steps in `Config.RotationManager`:
   - `fightRotation`: Used from the start until Phase 4.
   - `finalRotation`: Executed during Phase 4 or at 199k boss health.
   - To modify a rotation, you can add or remove a step.
   - Below are a few examples of steps that could be added
     #### Example 1: Simple ability
     ```lua
     { label = "Volley of Souls" },
     { label = "Soul Sap" }
     
     -- will cast "Volley of Souls" from the ability bar
     -- will wait for 3 game ticks
     -- will cast "Soul Sap"
     ```
     #### Example 2: Casting abilities (off-global-cooldown) between other abilities
     ```lua
     { label = "Invoke Death", wait = 2 },
     { label = "Surge:, wait = 1 },
     { label = "Command Skeleton Warrior" }
     
     -- wil cast "Invoke Death" from the ability bar
     -- will wait for 2 game ticks
     -- will cast "Surge" from the ability bar (off the global cooldown)
     -- will wait for 1 game tick
     -- will cast "Command Skeleton Warrior" from the ability bar
     ```
     #### Example 3: Using inventory items & using miliseconds instead of ticks to wait
     ```lua
     { label = "Essence of Finality", type = "Inventory", wait = 100, useTicks = false },
     { label = "Essence of Finality" },
     { label = "Salve amulet (e), type = "Inventory, wait = 100, useTicks = false },
     { label = "Weapon Special Attack" },
     ```



---

## Usage
1. Run `Lua_Scripts\rasial\main.lua` through the injector.

---

## Debugging
Debugging can be toggled by setting `local debug = true` in the following files:
- `core/player_manager.lua`: Debug player status and health checks.
  - When status is changed
  - When player eats
  - When player drinks
- `core/rotation_manager.lua`: Debug ability selection and rotation execution.
  - Clear logs of every rotation step and relevant attributes
- `rasial/utils.lua`: Enable detailed metrics such as:
  - All kill details (runtime & kill duration)
  - Player State details: (health, prayer, adrenaline, location, coords, status, etc...)
  - Managed buffs (name and remaining duration)
  - Food items, prayer items and more!

---

## Documentation and Help
For detailed documentation, questions, or feedback, please reference the thread on ME's Discord channel:
- [Sonson's Player Manager](https://discord.com/channels/809828167015596053/1354535418166509660)

---

