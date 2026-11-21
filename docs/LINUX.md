# Linux (Fedora, Proton / Wine)

Banished has no Linux version, so on Linux the Windows game runs through **Proton** (Steam) or **Wine** (GOG, through
Heroic, Lutris or Bottles). The mod runs inside the game, so Linux players use the **same release zip** as Windows
players. The only Linux-specific parts are the installer (`install.sh`) and one Wine setting.

Status: written and checked for **groups where every player is on Linux**. Games that mix Linux and Windows players
haven't been tested yet (see [Linux with Windows players](#linux-with-windows-players)).

## Install

1. Install Banished. On Fedora, Steam comes from RPM Fusion (`sudo dnf install steam` once the *nonfree* repository
   is enabled) or Flathub (`flatpak install flathub com.valvesoftware.Steam`). The installer handles both. Start
   Banished once through Steam, so that Proton sets the game up, then close it.
2. Download `BanishedMultiplayer-<version>.zip` from the Releases page, unpack it and run:

   ```
   bash install.sh
   ```

   It finds Banished (Steam libraries, Flatpak Steam, Heroic / Lutris / Bottles for GOG) and copies `dinput8.dll` into
   the Banished folder and `bmpShare.pkm` into `Banished/WinData`. If it doesn't find the game, give it the folder:
   `bash install.sh ~/path/to/Banished`. To see the folder in Steam, right-click Banished → *Manage* → *Browse
   local files*.
3. **Tell Wine to load the mod's DLL** (once). Wine normally uses its own built-in `dinput8.dll` and ignores the one
   in the game folder, so the mod doesn't start and there is no Multiplayer button.
   - **Steam:** right-click Banished → *Properties* → *General* → *Launch Options*:
     ```
     WINEDLLOVERRIDES="dinput8=n,b" %command%
     ```
   - **Heroic:** the game's *Settings* → *Advanced* → *Environment Variables*: `WINEDLLOVERRIDES` = `dinput8=n,b`.
   - **Lutris:** *Configure* → *Runner options* → *DLL overrides*: `dinput8` = `n,b`.
   - **Bottles:** the bottle's *Settings* → *DLL Overrides*: `dinput8` = native, builtin.
   - **Plain Wine:** `winecfg` → *Libraries*: add `dinput8`, set it to *Native then Builtin*.
4. Start Banished. In its launcher choose the **DirectX 11** renderer (*Video Options*): the multiplayer bar, cursors
   and pings are drawn only with DirectX 11 (Proton runs it through DXVK). The main menu now has a **Multiplayer**
   button.

To uninstall: `bash install.sh --uninstall`, and remove the launch option.

### It doesn't work

- **No `bmp.log` in the Banished folder after starting the game:** the DLL wasn't loaded. Check the launch option /
  DLL override from step 3 (in Steam, the quotes must be straight `"`, not curly). Check that `dinput8.dll` is next to
  `Application-steam-x64.exe`.
- **`bmp.log` is there, but no Multiplayer button:** the message on the main menu says which file is missing or of the
  wrong version. Run `install.sh` again.
- **The mod's first log lines** show what it found: `running under Wine ...` names the Wine/Proton version. If that
  line is missing, the game isn't running under Wine.
- **Bug reports:** the **Save** button puts the report zip in the Banished folder. Under Proton the Windows Desktop
  is a folder inside the game's Wine prefix (`steamapps/compatdata/242920/pfx/...`), where nobody would find it.
  Reports say which Wine version you run, and Linux user names in folder paths are removed from them.

## Playing with two Linux PCs

- **Use the same Proton version on both PCs.** In Steam, set Banished → *Properties* → *Compatibility* → *Force the
  use of a specific Steam Play compatibility tool* to the same Proton version on every PC, and update them together.
  Every PC must calculate exactly the same results, and the maths functions come partly from Wine. The same Proton
  everywhere removes that variable.
- **Connecting:**
  - **Steam:** works as on Windows, through Proton's Steam bridge. *Invite players* needs the Steam overlay. If the
    overlay doesn't open, the others can right-click the host in their Steam friends list → *Join Game*.
  - **Direct (IP)** on the same home network: the others type the host's LAN address (`ip -4 addr`, e.g.
    `192.168.1.20`) and port 7777. Fedora Workstation's firewall already allows ports above 1024. On other setups
    open it on the host: `sudo firewall-cmd --add-port=7777/tcp` (add `--permanent` and run
    `sudo firewall-cmd --reload` to keep it).
  - **Relay:** the Python relay (`tools/bmp_relay.py`, [RELAY.md](RELAY.md)) runs natively on Linux.

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
