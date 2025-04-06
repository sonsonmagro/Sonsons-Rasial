# Sonson's Rasial

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
   - asdasd
3. Adjust buffs as needed in `Config.Buffs`.
4. Modify rotation steps in `Config.RotationManager`:
   - `fightRotation`: Used from the start until Phase 4.
   - `finalRotation`: Executed during Phase 4 or at 199k boss health.

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
  - Player State details
    - Health
    - Prayer
    - Adrenaline
    - Location
    - Status
    - Coordinates
    - etc..
  - Managed buffs (name and remaining duration)
  - Food Items
  - Prayer Items
  - and more!

---

## Documentation and Help
For detailed documentation, questions, or feedback, please reference the thread on ME's Discord channel:
- [Sonson's Player Manager](https://discord.com/channels/809828167015596053/1354535418166509660)

---

