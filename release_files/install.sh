#!/usr/bin/env bash
# Banished Multiplayer installer for Linux (Banished runs there through Proton or Wine; the mod is the same).
#   bash install.sh                        install into every Banished it finds (Steam and GOG)
#   bash install.sh --uninstall            uninstall
#   bash install.sh [--uninstall] <dir>    only the Banished folder <dir>
# Copies:
#   dinput8.dll   -> the Banished folder (next to Application-steam-x64.exe, or Application-x64.exe for GOG)
#   bmpShare.pkm  -> Banished/WinData
# A dinput8.dll from another mod is kept as dinput8.dll.bmp-backup and put back by --uninstall.
# The game must also be told to load the DLL (Wine prefers its own dinput8): this script prints how.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
uninstall=0
only=""
for a in "$@"; do
    case "$a" in
        --uninstall|-u) uninstall=1 ;;
        -h|--help) sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*) echo "Unknown option: $a (see: bash install.sh --help)" >&2; exit 1 ;;
        *) only="$a" ;;
    esac
done

if [ -t 1 ]; then red=$'\e[31m'; green=$'\e[32m'; yellow=$'\e[33m'; bold=$'\e[1m'; off=$'\e[0m'
else red=""; green=""; yellow=""; bold=""; off=""; fi
die() { echo; echo "${red}$*${off}" >&2; exit 1; }

is_game() { [ -n "$1" ] && { [ -f "$1/Application-steam-x64.exe" ] || [ -f "$1/Application-x64.exe" ]; }; }

found=()
declare -A seen=()
add() {  # add a Banished folder once (by its real path)
    is_game "$1" || return 0
    local r; r="$(realpath -e "$1")"
    [ -z "${seen[$r]+x}" ] || return 0
    seen[$r]=1
    found+=("$r")
}

find_banished() {
    if [ -n "$only" ]; then
        only="${only/#\~/$HOME}"
        is_game "$only" || die "No Banished in '$only' (the folder with Application-steam-x64.exe or Application-x64.exe)."
        add "$only"; return
    fi
    if is_game "$here"; then add "$here"; return; fi                       # unpacked straight into the game folder
    if is_game "$(dirname "$here")"; then add "$(dirname "$here")"; return; fi

    # Steam: native (Fedora RPM, ~/.steam/steam links there too), Flatpak, Snap; every library in libraryfolders.vdf
    local root vdf lib
    for root in "$HOME/.local/share/Steam" "$HOME/.steam/steam" \
                "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam" \
                "$HOME/.var/app/com.valvesoftware.Steam/data/Steam" "$HOME/snap/steam/common/.local/share/Steam"; do
        [ -d "$root" ] || continue
        add "$root/steamapps/common/Banished"
        for vdf in "$root/steamapps/libraryfolders.vdf" "$root/config/libraryfolders.vdf"; do
            [ -f "$vdf" ] || continue
            while IFS= read -r lib; do add "$lib/steamapps/common/Banished"; done \
                < <(sed -n 's/^[[:space:]]*"path"[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$vdf")
        done
    done

    # GOG: Heroic's list of installed games, then the usual Heroic / Lutris / Bottles / Wine folders. GOG Galaxy in a
    # Wine prefix puts the game 7 levels down (<bottle>/drive_c/Program Files (x86)/GOG Galaxy/Games/Banished/...exe);
    # each prefix's Windows folder (thousands of files) and dosdevices (links to / and other drives) are skipped.
    local json p
    for json in "$HOME/.config/heroic/gog_store/installed.json" \
                "$HOME/.var/app/com.heroicgameslauncher.hgl/config/heroic/gog_store/installed.json"; do
        [ -f "$json" ] || continue
        while IFS= read -r p; do add "$p"; done \
            < <(grep -o '"install_path"[[:space:]]*:[[:space:]]*"[^"]*"' "$json" | sed 's/.*:[[:space:]]*"\(.*\)"$/\1/')
    done
    local d exe
    for d in "$HOME/Games" "$HOME/.local/share/bottles/bottles" "$HOME/.var/app/com.usebottles.bottles/data/bottles/bottles" \
             "$HOME/.local/share/lutris/prefixes" "$HOME/.wine/drive_c"; do
        [ -d "$d" ] || continue
        while IFS= read -r exe; do add "$(dirname "$exe")"; done \
            < <(find "$d" -maxdepth 8 \( -path '*/drive_c/windows' -o -name dosdevices \) -prune -o \
                     -type f \( -name 'Application-x64.exe' -o -name 'Application-steam-x64.exe' \) -print 2>/dev/null)
    done

    if [ "${#found[@]}" -eq 0 ] && [ -t 0 ]; then
        echo "Couldn't find Banished by myself."
        read -r -p "Where is it installed? (the folder with Application-steam-x64.exe or Application-x64.exe): " p || p=""
        p="${p/#\~/$HOME}"
        add "$p"
    fi
}

# Our DLL carries the text "BanishedMP" (UTF-16). grep -c, not -q: -q stops at the first match, tr then dies writing
# to the closed pipe, and pipefail turns that into "not ours" for any DLL with more than ~64 KB after the text.
is_ours() { tr -d '\0' < "$1" | LC_ALL=C grep -ca 'BanishedMP' >/dev/null; }

put() {  # copy, unless it is already that very file (the zip unpacked straight into the game folder or WinData)
    [ "$1" -ef "$2" ] || cp -f "$1" "$2"
}

windata() {  # the game's WinData folder, whatever its case on disk
    local w; w="$(find "$1" -maxdepth 1 -type d -iname windata -print -quit 2>/dev/null || true)"
    echo "${w:-$1/WinData}"
}

find_banished
[ "${#found[@]}" -gt 0 ] || die "Couldn't find Banished. Run this again with the Banished folder: bash install.sh /path/to/Banished
(Steam: right-click Banished in your library -> Manage -> Browse local files shows the folder.)"
# (Wine names the game's process after its exe, cut to 15 characters: Application-ste / Application-x64)
if pgrep '^Application-(ste|x64)' >/dev/null 2>&1; then die "Banished is running - close it first, then run this again."; fi
if [ "$uninstall" -eq 0 ]; then
    for f in dinput8.dll bmpShare.pkm; do
        [ -f "$here/$f" ] || die "$f is missing from this folder - unpack the whole zip first."
    done
fi

steam_games=0; other_games=0
for game in "${found[@]}"; do
    echo "Banished folder: $game"
    dll="$game/dinput8.dll"
    backup="$game/dinput8.dll.bmp-backup"
    pkm="$(windata "$game")/bmpShare.pkm"
    if [ "$uninstall" -eq 1 ]; then
        if [ -f "$dll" ] && is_ours "$dll"; then rm -f "$dll"; echo "  removed dinput8.dll"; fi
        if [ -f "$backup" ]; then
            if [ -e "$dll" ]; then  # yet another mod's dinput8.dll came after ours: leave it, and the backup, alone
                echo "${yellow}  dinput8.dll belongs to another mod: left it, and the older one stays in dinput8.dll.bmp-backup${off}"
            else
                mv "$backup" "$dll"; echo "  put the other mod's dinput8.dll back"
            fi
        fi
        if [ -f "$pkm" ]; then rm -f "$pkm"; echo "  removed WinData/bmpShare.pkm"; fi
        continue
    fi
    if [ -f "$dll" ] && ! is_ours "$dll" && [ ! -f "$backup" ]; then
        mv "$dll" "$backup"
        echo "${yellow}  another mod's dinput8.dll was there: kept as dinput8.dll.bmp-backup (--uninstall puts it back)${off}"
    fi
    put "$here/dinput8.dll" "$dll"
    # subscribed on the Steam Workshop: Steam keeps the mod file up to date - no second copy in WinData
    workshop="$(dirname "$(dirname "$game")")/workshop/content/242920"
    sub=""
    [ -d "$workshop" ] && sub="$(find "$workshop" -name bmpShare.pkm -type f -print -quit 2>/dev/null || true)"
    if [ -n "$sub" ]; then
        [ "$here/bmpShare.pkm" -ef "$pkm" ] || rm -f "$pkm"
        echo "  mod file: using your Steam Workshop subscription"
    else
        mkdir -p "$(dirname "$pkm")"
        put "$here/bmpShare.pkm" "$pkm"
    fi
    if [ -f "$game/Application-steam-x64.exe" ]; then steam_games=1; else other_games=1; fi
done

echo
if [ "$uninstall" -eq 1 ]; then
    echo "${green}Banished Multiplayer is uninstalled.${off} (Your settings and logs, bmp_*.txt / bmp*.log in the Banished folder, are left; delete them if you like.)"
    echo "You can also remove the WINEDLLOVERRIDES launch option / DLL override again."
    exit 0
fi
echo "${green}Banished Multiplayer is installed.${off}"
echo
echo "${bold}One more step (once):${off} tell Wine to load the mod's dinput8.dll instead of its own."
if [ "$steam_games" -eq 1 ]; then
    echo "  Steam: right-click Banished -> Properties -> General -> Launch Options, and enter:"
    echo
    echo "      ${bold}WINEDLLOVERRIDES=\"dinput8=n,b\" %command%${off}"
    echo
    echo "  (Already have launch options? Put it in front of them. Already set WINEDLLOVERRIDES? Add ;dinput8=n,b to it.)"
    echo
fi
if [ "$other_games" -eq 1 ]; then
    echo "  GOG version - in your launcher:"
    echo "    Heroic:  the game's Settings -> Advanced -> Environment Variables: WINEDLLOVERRIDES = dinput8=n,b"
    echo "    Lutris:  Configure -> Runner options -> DLL overrides: dinput8 = n,b"
    echo "    Bottles: the bottle's Settings -> DLL Overrides: dinput8 = native, builtin"
    echo "    Wine:    winecfg -> Libraries: add dinput8 (native, builtin)"
    echo
fi
echo "Then start Banished: the main menu has a Multiplayer button, and bmp.log appears in the Banished folder."
echo "Choose the DirectX 11 renderer in Banished's launcher (Video Options) to see the multiplayer bar and cursors."
