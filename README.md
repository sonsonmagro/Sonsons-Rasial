# Sonson's Rasial [v2.1.1]

A comprehensive, production-grade Rasial boss automation script showcasing advanced Lua scripting patterns, modular architecture, and the power of the MemoryError framework.

**Disclaimer:**

> This script is intentionally feature-rich to demonstrate best practices in bot scripting: a task-based scheduler (Timer), pluggable managers for rotations/buffs/prayers, abstracted GUI system with presets, persistent statistics, and defensive error handling. While it could be simpler, the architecture is designed to be maintainable, extensible, and reusable across other boss scripts.

---

## Overview

Sonson's Rasial automates the Rasial boss fight from start to finish, including:

- **Pre-fight preparation** via War's Retreat (banking, prayers, buffs, conjures)
- **Combat management** with adaptive rotations, prayer flicking, and buff tracking
- **Intelligent loot handling** with unique drop notifications and GP tracking
- **Death recovery** with automatic teleport and re-entry
- **Persistent statistics** across sessions (kills, GP, drop tracking)
- **Full preset system** for quick configuration swaps

All controlled via an intuitive, themeable GUI with live status updates.

---

## Requirements

### Essential

- **MemoryError Client** with Lua scripting support
- **War's Retreat unlocked** with crystal, bank, and altar accessible
- **Necromancy spellbook** (for Ruination and other buffs)

### Recommended Setup

| Category        | Items                                                                                                |
| --------------- | ---------------------------------------------------------------------------------------------------- |
| **Weapons**     | T100 Omni Guard + Soulbound Lantern (Essence of Finality slot)                                       |
| **Perks**       | Aftershock 4 + Equilibrium 2; Precise 6 + Ruthless 1                                                 |
| **Armor**       | Full First Necromancer Robes (T95)                                                                   |
| **Armor Perks** | Crackling 4 + Relentless 5; Invigorating 4 + Undead Slayer; Impatient 4 + Mobile                     |
| **Amulet**      | Salve Amulet (e)                                                                                     |
| **Offhand**     | Essence of Finality + T70 Death Guard                                                                |
| **Book**        | Scripture of Ful (charged)                                                                           |
| **Curses**      | T99 Necromancy                                                                                       |
| **Aura**        | Equilibrium                                                                                          |
| **Supplies**    | Elder Overloads, Adrenaline Renewals, Vulnerability Bombs, Lantadyme Incense, Ripper Demon Contracts |

> **Note:** The script can adapt to lower-tier gear and different setups. These recommendations are for the "BIS Equilibrium" rotation.

---

## Installation

### 1. File Structure

Place files in your `Lua_Scripts` directory:

```
Lua_Scripts/
├── core/                          # Reusable library modules
│   ├── timer.lua
│   ├── rotation_manager.lua
│   ├── player_manager.lua
│   ├── prayer_flicker.lua
│   ├── wars_retreat.lua
│   ├── gui_lib.lua
│   ├── player.lua
│   └── helper.lua
├── rasial/                        # Boss script for Rasial
│   ├── main.lua                   # Entry point
│   ├── gui.lua                    # GUI implementation
│   └── presets.lua                # Preset definitions
├── api.lua                        # Game API wrapper
└── usertypes.lua                  # Type definitions
```

### 2. Running the Script

1. Run `Sonson's Rasial` through MemoryError's Script Manager

### 3. First Time Setup

When the script starts:

1. **GUI opens with configuration tabs**
2. **Presets tab:** Select your Inventory, Equipment, and Rotation presets
3. **General tab:** Configure Bank PIN, health/prayer thresholds, notifications
4. **War's Retreat tab:** Set crystal/portal summon options, movement abilities
5. **Debug tab** (optional): Enable debug logging for troubleshooting
6. **Click "Save Configuration"** to save your setup as a preset
7. **Click "Start"** to begin the script

---

## Features

### 🎮 Flexible Preset System

**Three-tier configuration:**

- **Inventory Presets:** Item sets (food, bombs, incense, contracts)
- **Equipment Presets:** Gear configurations (pocket, weapon, armor)
- **Rotation Presets:** Ability sequences for fight and final phases

### 🔄 Task-Based Combat System

Instead of linear scripting, Rasial uses a **priority-based task scheduler** (`core/timer.lua`):

- **Parallel tasks** (buffs, prayers) execute independently
- **Priority tasks** (rotations, special attacks) execute in order
- **Conditions** determine when tasks run
- **Cooldowns** prevent spam (per-tick or per-millisecond)

This makes combat logic declarative and easy to reason about.

### 🛡️ Adaptive Player Management

The **PlayerManager** tracks and maintains:

- **Health** with configurable restoration thresholds
- **Prayer** with adaptive flicking and renewal logic
- **Buffs** with auto-refresh (Ruination, Ful, Elder Overload, Lantadyme, Ripper Demon)

Thresholds are configurable per situation (normal, critical, special).

### 📍 War's Retreat Automation

Full bank-prepare-fight loop handled via **WarsRetreat singleton:**

- Navigate to bank, load last
- Restore prayers at altar
- Summon conjures (optional)
- Use adrenaline crystal (optional)
- Go through to boss portal

Customizable with:

- Bank PIN (auto-entered)
- Surge/Dive chance for faster navigation
- Minimum stats to proceed (health, prayer, summoning)
- Inventory full handling (bank or drop items)

### 💀 Rasial-Specific Logic

**Dynamic phase detection:**

- Changes rotations at Phase 4 or 199k boss HP
- Final rotation optimized for quick kills

**Loot handling:**

- Auto-pickup common drops and uniques
- Unique item detection with Discord notifications
- GP tracking (all-time and per-session)
- Unique drops logged with timestamps

### 🔔 Discord Notifications

When you receive a unique drop:

1. Webhook POST with custom embed
2. Item image, quantity, and kill details
3. Optional @mention for instant alerts
4. Fully customizable webhook URL

### 📊 Statistics & Tracking

**Session stats:**

- Kills this session, GP this session, runtime

**All-time stats:**

- Total kills, total GP, unique items looted
- Unique drop history with timestamps
- Persistent across script restarts

Stats saved to `stats.json`.

### 🐛 Comprehensive Debugging

Enable debug output for each system:

- `debugMain` — Script flow and state changes
- `debugTimer` — Task execution and cooldowns
- `debugRotation` — Ability casting and rotation progress
- `debugPlayer` — Health/prayer/buff updates
- `debugPrayer` — Prayer flicking events
- `debugWars` — War's Retreat navigation steps

Logs visible in MemoryError console.

### 🎨 Modern GUI

- **Tabbed interface:** Presets, General, War's Retreat, Player Manager, Debug
- **Live status display** (current phase, health, prayer, buffs)
- **Real-time statistics** (session and all-time)
- **Configuration management** (load/save/delete presets)
- **Warning system** for missing items or invalid setup

---

## Configuration Guide

### Presets Tab

#### Inventory Preset

Select a pre-configured set of consumables:

- Vulnerability bombs
- Food (Guthix rests, Blubber)
- Incense sticks
- Overload potions
- Adrenaline renewals
- Binding contracts

Current presets: `Sonson's Loadout`, plus custom additions.

#### Equipment Preset

Select a gear configuration:

- Offhand weapon (Scripture of Ful, etc.)
- Quick-swap items

Current presets: `Ful`.

#### Rotation Preset

Select a combat rotation:

- Defines ability sequence for Phases 1-3
- Defines final phase sequence (Phase 4 or 199k HP)
- Can include abilities, inventory items, and waits

Current presets: `BIS Equilibrium`.

### General Tab

| Setting                      | Description                                   |
| ---------------------------- | --------------------------------------------- |
| **Bank PIN**                 | Your bank PIN (auto-entered when needed)      |
| **Wait for Full HP**         | Delay starting fight until you're at full HP  |
| **Discord Notifications**    | Enable webhook notifications for unique drops |
| **Health/Prayer Thresholds** | When to restore health/prayer (% or absolute) |

### War's Retreat Tab

| Setting                    | Description                                             |
| -------------------------- | ------------------------------------------------------- |
| **Summon Conjures**        | Auto-summon thralls before portal                       |
| **Use Adrenaline Crystal** | Drink from adrenaline pool                              |
| **Surge/Dive Chance**      | Probability of using Surge (0-100%) for faster movement |
| **Minimum Stats**          | Don't enter fight below this health/prayer/summoning    |

### Debug Tab

Enable individual module debugging:

- Main script flow
- Timer/scheduler
- Rotation manager
- Player manager
- Prayer flicker
- War's Retreat navigation

---

## Adding Custom Rotations

Rotations are defined in `rasial/presets.lua`. Each rotation has two sequences:

```lua
Presets.Rotations["My Rotation"] = {
    fightRotation = {
        { label = "Invoking Death" },
        { label = "Surge", wait = 1 },
        { label = "Command Skeleton Warrior" },
        -- ...
    },
    finalRotation = {
        -- Phase 4 abilities (199k HP onwards)
    }
}
```

**Rotation Step Fields:**

- `label` — Ability or item name
- `type` — `"Ability"` (default) or `"Inventory"`
- `wait` — Ticks to wait after this step (default: 3)
- `useTicks` — If true, `wait` is in game ticks; if false, milliseconds

**Example: Using inventory items**

```lua
{ label = "Vulnerability bomb", type = "Inventory", wait = 100, useTicks = false }
```

After editing `presets.lua`, restart the script and your rotation appears in the dropdown.

---

## Troubleshooting

### "Missing inventory item" Warning

**Problem:** You don't have an item from your preset.

**Solution:**

1. Check you have the item in inventory
2. Verify quantity meets preset requirements
3. Check item ID if custom items used
4. Clear warnings and start anyway (if possible)

### "Missing equipment item" Warning

**Problem:** You're missing equipment from the preset.

**Solution:**

1. Equip the item or add it to inventory
2. Verify preset configuration
3. Start a new preset without that item

### Script stops during War's Retreat

**Problem:** Gets stuck at bank/altar/portal.

**Troubleshooting:**

1. Enable `debugWars = true` in Debug tab
2. Check console output for step name
3. Verify bank PIN is correct
4. Check if altar is accessible
5. Manually complete the step and restart script

### Rotation not progressing

**Problem:** Abilities aren't casting, rotation stuck.

**Solution:**

1. Enable `debugRotation = true`
2. Check if you're in combat (check interface)
3. Verify ability names match exactly
4. Check adrenaline levels meet ability requirements
5. Ensure you're in the correct location

### Prayer flicker issues

**Problem:** Prayers turning on/off unexpectedly.

**Solution:**

1. Enable `debugPrayer = true`
2. Check prayer threshold settings
3. Verify you have sufficient prayer points
4. Check if altar access was successful in War's Retreat

### GUI not saving configuration

**Problem:** Settings lost when script restarts.

**Solution:**

1. Click "Save Configuration" explicitly (not just Start)
2. Check `presets/` folder has write permissions
3. Check `configs/rasial.config.json` exists
4. Restart MemoryError completely

### Performance / lag

**Problem:** Script running slow or causing frame drops.

**Solution:**

1. Disable visual debug options (debugMain, debugTimer)
2. Reduce number of parallel tasks if possible
3. Check MemoryError CPU usage in task manager
4. Clear old session logs

---

## API & System Overview

### Core Modules (in `core/`)

| Module                 | Purpose                                                |
| ---------------------- | ------------------------------------------------------ |
| `timer.lua`            | Priority-based task scheduler — core of the script     |
| `rotation_manager.lua` | Handles ability casting and rotation progression       |
| `player_manager.lua`   | Tracks and manages health, prayer, buffs               |
| `prayer_flicker.lua`   | Automated prayer flicking logic                        |
| `wars_retreat.lua`     | Full bank-prepare-fight automation                     |
| `player.lua`           | Player state queries (health, prayer, buffs, location) |
| `helper.lua` (Utils)   | Logging, ability use, inventory queries, formatting    |
| `gui_lib.lua`          | Abstraction over ImGui for theming and layouts         |

### Rasial Modules (in `rasial/`)

| Module        | Purpose                                            |
| ------------- | -------------------------------------------------- |
| `main.lua`    | Script entry point, task registration, fight logic |
| `gui.lua`     | Pre-start GUI with preset/config management        |
| `presets.lua` | Inventory, equipment, rotation, buff definitions   |

### Important Patterns

**Task Registration:**

```lua
timer:addTask({
    name = "Cast ability",
    priority = 10,
    condition = function() return playerManager:canCast() end,
    action = function() return Utils:useAbility("Ruination") end
})
```

**Player State:**

```lua
local health = Player:getHealth()
local hasRunination = Player:getBuff(30769).found
local isAtBoss = Player:isAtCoordWithRadius(x, y, z, range)
```

**Logging:**

```lua
Utils:log("Message", "debug")  -- default
Utils:log("Important", "info")
Utils:log("Careful", "warn")
Utils:log("Failed!", "error")
```

---

## Contributing & Customization

### Adding a New Inventory Preset

1. Open `rasial/presets.lua`
2. Add to `Presets.Inventory`:
   ```lua
   Presets.Inventory["My Inventory"] = {
    {id = 48951, amount = 10, name = "Vulnerability bomb"},
    {id = 29448, amount = 2, name = "Guthix rest flask (6)"},
        ids = {49042, 49044, 49046, 49048, 49050, 49052},
        amount = 1,
        name = "Elder overload salve"
    }, -- Accepts any dose (1-6)
   ```
3. Preset appears in Equipment dropdown

### Adding a New Equipment Preset

1. Open `rasial/presets.lua`
2. Add to `Presets.Equipment`:
   ```lua
   Presets.Equipment["My Equipment"] = {
       {id = 52494, slot = 12, name = "Scripture of Ful"}
   }
   ```
3. Preset appears in Equipment dropdown

### Adding a New Buff

1. Open `rasial/presets.lua`
2. Add to `Presets.Buffs["Standard"]`:
   ```lua
   {
       buffName = "Your Buff",
       buffId = 12345,
       canApply = function() return true end,
       execute = function() return Utils:useAbility("Buff Name") end,
       toggle = true,
       refreshAt = 60  -- (optional) refresh at 60 seconds remaining
   }
   ```
3. Restart script

---

## Support

### Debugging Workflow

1. Enable relevant debug flags in GUI
2. Run the script and reproduce issue
3. Check MemoryError console for logs
4. Inspect `configs/rasial.*.json` files if configuration issue
5. Review markdown guides for the relevant module

### Getting Help

- Enable debug flags and review console output
- Inspect preset/config JSON files for typos
- Verify game state matches expectations (at location, in combat, items present)
