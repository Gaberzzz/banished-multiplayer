# Linux (Proton / Wine): details and testing

**Installing on Fedora and running a multiplayer game are in the main README:
[Linux (Fedora)](../README.md#linux-fedora).** This page has the rest: the GOG launchers, what the mod does
differently under Wine, a test checklist for two Linux PCs, and notes for later.

Banished has no Linux version, so on Linux the Windows game runs through Proton (Steam) or Wine (GOG). Linux players
use the same release zip as Windows players. The only Linux-specific parts are the installer (`install.sh`) and one
Wine setting.

## GOG version: the DLL override in each launcher

Wine normally uses its own built-in `dinput8.dll` and ignores the one in the game folder. On Steam the launch option
`WINEDLLOVERRIDES="dinput8=n,b" %command%` fixes that. For the GOG version, set the same thing in your launcher:

- **Heroic:** the game's *Settings* → *Advanced* → *Environment Variables*: `WINEDLLOVERRIDES` = `dinput8=n,b`.
- **Lutris:** *Configure* → *Runner options* → *DLL overrides*: `dinput8` = `n,b`.
- **Bottles:** the bottle's *Settings* → *DLL Overrides*: `dinput8` = native, builtin.
- **Plain Wine:** `winecfg` → *Libraries*: add `dinput8`, set it to *Native then Builtin*.

`install.sh` looks for GOG installs in Heroic's list of installed games and under `~/Games`, the Bottles and Lutris
folders and `~/.wine`.

## What the mod does differently under Wine

- **Log:** `bmp.log` (in the Banished folder) starts with `bmp loaded` and `running under Wine ...`, which names the
  Wine/Proton version and the Linux kernel. If that line is missing, the game isn't running under Wine.
- **Bug reports:** **Save** puts the zip in the Banished folder instead of on the Windows Desktop. Under Proton the
  Desktop is a folder inside the game's Wine prefix (`steamapps/compatdata/242920/pfx/...`), where nobody would find
  it. `bmp.log` records the full Linux path of the saved zip. Reports have a `wine:` line, and Linux user names in
  folder paths (`/home/<name>/...`) are replaced with `<user>`.

## Test checklist

For the first session on two Linux PCs (A hosts, B joins). Write down what fails, and press the **bug** button →
**Save** when something goes wrong.

1. **Loads:** on both PCs, `bmp.log` appears in the Banished folder and starts with `bmp loaded` and `running under
   Wine ...`. The main menu has the Multiplayer button and no "missing file" message.
2. **Draws:** with the DirectX 11 renderer, the Multiplayer window opens. In a game, the bar at the top shows both
   players, and each player sees the other's cursor. Alt + left click shows a ping on both PCs, and the ping chime
   plays.
3. **Typing and clipboard:** type a player name with your keyboard layout (including special letters, e.g. ä, é).
   With the relay, copy the room code on A with the copy button and paste it on B with the paste button (or Ctrl+V).
4. **Connect** each way you'll use: Steam (*Invite players*, and *Join Game* from the friends list), Direct (IP)
   over the LAN.
5. **Stays in sync** (the most important one): *Share one town* → *New town*, play 30 minutes or more at the highest
   speed, placing buildings and assigning workers on both PCs. Then search both logs:
   ```
   grep -E 'DESYNC|RESYNC|resync at' bmp.log
   grep 'fp: tick' bmp.log
   ```
   No `DESYNC` lines is the goal. A few resyncs that you started yourself are fine. On both PCs the `fp:` lines should
   show the same `mxcsr` / `x87 control` values. Repeat with *Separate towns* and a trade between the towns.
6. **Joining a running game:** B leaves and joins again while A keeps playing. B's game should reload A's town.
7. **Save and load:** A saves, both quit, A loads the save under *Multiplayer* → *Load town*, and B joins.
8. **Bug report:** *bug* → *Save*. The zip appears in the Banished folder. Its `report.txt` has a `wine:` line, and
   the logs inside show `/home/<user>/` instead of your Linux user name.

If step 5 shows `DESYNC` lines, keep both PCs' `bmp_desync_*.log` files and compare them with
`python3 tools/ringdiff.py` ([TESTING.md](TESTING.md)): it names the first thing the two games did differently.

## Linux with Windows players

Not tested yet. Everything except determinism should work the same as Linux-only. The open question is whether
Banished's simulation gives bit-identical results under Wine and on Windows. If the game takes maths functions (sine,
square root, ...) from Microsoft's C runtime, Wine's own version of that runtime can round differently. Hash
mismatches would show as `DESYNC` lines and frequent resyncs. If that happens, the first thing to try is Microsoft's
runtime in the game's Wine prefix: `protontricks 242920 vcrun2012`.

## Building on Linux

Not needed to play: the release DLL is the same for every platform. The DLL is built with Visual Studio
([BUILDING.md](BUILDING.md)). `src/commands.cpp` uses MSVC's `__try`/`__except`, so a Linux build would need clang-cl
with the Windows SDK and MSVC headers (e.g. through `xwin`), not MinGW.
