# Tabletop Combat Simulator

Tabletop Combat Simulator is a gameplay mod for Total War: WARHAMMER III that aims to recreate the feel of tabletop skirmishes inside the real-time battles: tighter unit control, simplified morale interactions, scaled damage, and modular rules for custom scenarios.

It slows down the battles considerably, to the effect of allowing players to zoom in on their units and admire the combat from up close, without the pressure of micromanaging units into the ideal position or relying on reaction time to counter a flanking manouver. 

This mod intends to be served as a framework and does not aim to deliver a balanced play experience. To that end a balance mod, with perhaps a compatibility submod, is required to be installed alongside of it. 

Although the AI is implemented to make use of the adapted combat system, it by no means is aware of the limitations. As such, it's decisions may seem strange and lack any strategic depth. Much more fun is to be had by playing this mod in a multiplayer environment.

## Key features
- Simplified morale rules with clearer break/hold thresholds
- Adjustable command ranges and formation tightness to mimic tabletop movement
- Optional toggleable rules so you can mix classic and tabletop behavior
- Lightweight and compatible with both multi- and single-player battles

## Requirements
- Total War: WARHAMMER III (current or compatible version)
- Installation via mod manager recommended for automatic activation
- No paid DLC required

## Reccomended Additional Mods
- [Mod Configuration Tool](https://steamcommunity.com/sharedfiles/filedetails/?id=2927955021) by Groove Wizard
    - To get access to the modular features and to customize the experience.
- A balance mod such as [The Duke's Damned Nations](https://steamcommunity.com/sharedfiles/filedetails/?id=2878608715) by The Duke
    - This mod only offers the framework of Tabletop Battles, not the balance that is necessary for a good experience.

## Installation
1. Using a Mod Manager (recommended)
    - Import the mod package into your mod manager (e.g., the Steam Workshop or third-party manager) and enable it.
2. Manual install
    - Extract the packfile into your game's data directory (example path varies by platform/installer).
    - Potentially enable the mod from the game's mod list before launching.

## Configuration
- Open the in-game MCT settings menu (if enabled).
- Available options (examples):
  - `min_movement_range` (0–any number lower than the max_movement_range) — the distance a unit can move with 0 speed.
  - `fight_time` (0–any number) — the duration a Fight Activation lasts for the player.
  - `simultaneous_turns` (true/false) — Allows both players to activate units during each phase in a round.

Tweak these to suit your own playstyle, make sure both players have the same settings in Multiplayer.

## Gameplay tips
- Keep the Unit Info Panel open with 'I' on the left-hand side of your HUD. On top of it you will see a small info banner which tells you about the Activations of your units.
- All activations require you to either target the ground or an enemy to resolve.
- Spells with projectiles, such as Fireball, require a Shoot Activation in the Shooting Phase to be cast.
- Some Activations can be processed for all selected units (Charge/Fight), but others only affect the currently selected unit (Move/Wheel)
- Buffs and Debuffs that do not deal damage or heal are permanent and are automatically cleared at the start of the Hero Phase. Just don't touch the Spell Ability in the bottom right after casting it!
- You can terminate the TCS at any time during a battle through the Army Ability on the right-hand side of your HUD.
- Each unit has a zone of influence around it of 20 metres. Units cannot move into that zone by normal move, instead they need to charge to cross this boundary.

## Known issues
- There is a lot of selecting/unselecting of units going on by the LUA scripts. This is used to prevent orders after the code takes control of a unit.
- You'll hear the script 'Halt' units often, this is to prevent damage and movement spilling over in between activations.
- Units do not 'fight' in between activations. Splash damage is capped at a minimum of 1 per splash target, thus some units would continuously deal damage if they kept fighting.
- Units get 'locked' when they enter the engagement range of an enemy, which means they can't move away and can only charge from there on out. There's a warning option in MCT that tries to resolve it, but it isn't ideal.
- A unit receiving the Shoot Activation sometimes does not fire their weapon. Make sure there is line of sight by zooming in!
- No testing is done for Multiplayer battles of more than 2 players.
- Some units are so fast that they are not stopped in time before moving into Engagement Range of another unit, thus getting into combat without actually charging.

## Troubleshooting
- If the mod fails to load: ensure it is enabled in the mod list and placed in the correct mods folder.
- Conflicts: disable other gameplay mods that use scripts during the battle.
- Save corruption: back up saves before enabling new mod versions.

## Contributing
- Issues are most welcome. Provide:
  - Clear description of the issue or change
  - Steps to reproduce
  - Game and mod version
  - Script logs from the game's directory

## Changelog (v1.0)
- Initial release: core tabletop mechanics, settings menu.

## License & Credits
- Author: Me
- License: MIT
- Thanks to community over at the Da Modding Den and CA for their documentation and the game itself!
