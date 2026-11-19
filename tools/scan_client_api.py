"""Where the CoA client defines a name itself, cached for the audit gate.

    python -B tools/scan_client_api.py            # refresh tools/client_native.txt

It reads the client Lua that ui-port exported from the game (the interface
FrameXML/*.lua under the port's scratch folder by default), looks for
definitions, and writes one line per name:

    NAME<TAB>relative/path.lua:LINE         (the first place that defines it)

tools/coa_audit.py reads that file to split a retail-only name into three
classes, and the split is what the gate needs: a name the client already has
(class N) must NOT be redefined wholesale in Core/Compat/, a name nobody has
(class S) must be, and a name Compat defines although the client has it
(class D) is a regression. The class is derived from the scan, not typed by
hand, so the day the client grows a name the gate stops demanding a shim.

A name counts as defined when the client does any of:

    function NAME(...)              local function NAME(...)
    NAME = ...                      NAME = NAME or {}
    local NAME = ...                NAME.member = ...

Names looked for: every C_* namespace (by prefix, no list to maintain) plus
the retail-only and 3.3.5-native names this port argues about (coa_audit's
RETAIL_GLOBALS/RETAIL_TABLES plus WATCH_EXTRA below).
"""

import argparse
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_ROOT = os.path.dirname(HERE)
DEFAULT_SRC = os.path.join(os.path.dirname(DEFAULT_ROOT), "_ui-port-scratch",
                           "out", "Interface")
OUT_NAME = "client_native.txt"

# 3.3.5 natives and names the port argues about. Not exhaustive by design: a
# name that is not here and does not start with C_ is simply not classified.
WATCH_EXTRA = [
    "wipe", "strtrim", "strjoin", "strsplit", "strsub", "strupper", "strlower",
    "Mixin", "CreateFromMixins", "Enum", "Settings", "GetNumGroupMembers",
    "GetNumRaidMembers", "GetNumPartyMembers", "UnitAura", "UnitBuff",
    "UnitDebuff", "UnitAuraSlots", "GetTime", "GetItemInfo",
    "GetItemInfoInstant", "GetContainerNumSlots", "GetContainerItemInfo",
    "GetContainerItemLink", "ContainerIDToInventoryID", "GetInventoryItemLink",
    "GetQuestLogTitle", "GetNumQuestLogEntries", "GetNumQuestLeaderBoards",
    "GetQuestLogLeaderBoard", "GetQuestLogQuestText", "GetMapInfo",
    "GetMapContinents", "GetMapZones", "SetMapZoom", "SetMapByID",
    "SetMapToCurrentZone", "GetCurrentMapContinent", "GetCurrentMapZone",
    "GetCurrentMapAreaID", "GetPlayerMapPosition", "GetNumMapOverlays",
    "GetMapOverlayInfo", "UIDropDownMenu_Initialize", "UIDropDownMenu_AddButton",
    "UIDropDownMenu_CreateInfo", "InterfaceOptions_AddCategory",
    "GetAddOnMetadata", "GetAddOnInfo", "IsAddOnLoaded", "LoadAddOn",
    "GetNumAddOns", "CreateVector2D", "CreateVector3D", "UnitPosition",
    "GetBuildInfo", "GetLocale", "GetInstanceInfo", "RegisterUnitEvent",
    "GetSpellInfo", "GetSpellTexture", "GetCurrencyInfo", "GetSpellDescription",
    "UnitTokenFromGUID", "GetGUIDFromPlayerLocation", "GetPlayerInfoByGUID",
    "SetColorTexture", "SetAtlas", "GetAtlasInfo", "BackdropTemplate",
    "TooltipDataProcessor", "MenuUtil", "InputUtil", "C_GamePad", "C_CVar",
    "C_Item", "C_Container", "C_QuestLog", "C_Spell", "C_UnitAuras",
    "C_PlayerInfo", "C_PartyInfo", "C_FriendList", "C_Friend", "C_PvP",
    "C_Texture", "C_AddOns", "C_ChatInfo", "C_CurrencyInfo", "C_Bank",
    "C_NamePlate", "C_Secrets", "C_LootHistory", "C_InstanceEncounter",
    "C_DamageMeter", "C_DeathRecap", "C_InputInterfaceStyle", "C_CreatureInfo",
    "C_MapExplorationInfo", "C_Timer", "C_Map", "GetSpecialization",
    "GetSpecializationInfo", "SetPortraitTextureFromCreatureDisplayID",
]

# A definition, as the client writes one. Each entry is (regex, capture group
# holding the name). A dotted member assignment means the client has the table
# NAME, which is exactly what class N is about.
PATTERNS = [
    (re.compile(r"^\s*function\s+([A-Za-z_][A-Za-z0-9_]*)\s*[\(.:]"), 1),
    (re.compile(r"^\s*local\s+function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\("), 1),
    (re.compile(r"^\s*local\s+([A-Za-z_][A-Za-z0-9_]*)\s*=(?!=)"), 1),
    (re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=(?!=)"), 1),
    (re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*\.[A-Za-z_][A-Za-z0-9_]*\s*=(?!=)"), 1),
]


def watch_names():
    """The names worth reporting: coa_audit's retail list plus WATCH_EXTRA."""
    names = set(WATCH_EXTRA)
    try:
        sys.path.insert(0, HERE)
        import coa_audit
        names |= set(coa_audit.RETAIL_GLOBALS)
        names |= set(coa_audit.RETAIL_TABLES)
    except Exception:                    # the cache is still useful without it
        pass
    return names


def _files(src):
    """[(relative path, lines)] for every .lua under src."""
    out = []
    for folder, _, files in os.walk(src):
        for filename in sorted(files):
            if not filename.endswith(".lua"):
                continue
            full = os.path.join(folder, filename)
            rel = os.path.relpath(full, src).replace(os.sep, "/")
            try:
                with open(full, "r", encoding="utf-8", errors="replace") as handle:
                    out.append((rel, handle.readlines()))
            except (IOError, OSError):
                continue
    return out


def scan(src, names):
    """{name: "rel/path.lua:line"} for every name the client provides.

    Two kinds of evidence, because the client is two halves: a name the
    client's own Lua defines (FrameXML/*.lua), and a name its Lua only calls
    but never defines -- those live in the executable (GetMapInfo, wipe,
    GetItemInfo, GetTime …) and shipped FrameXML calling them is proof enough
    that the client provides them. A definition wins over a call site.
    """
    found = {}
    files = _files(src)
    for rel, lines in files:
        for number, line in enumerate(lines, 1):
            for pattern, group in PATTERNS:
                match = pattern.match(line)
                if not match:
                    continue
                name = match.group(group)
                if name in found:
                    break
                if name in names or name.startswith("C_"):
                    found[name] = "%s:%d" % (rel, number)
                break

    wanted = sorted(set(names) | set(found), key=len, reverse=True)
    if not wanted:
        return found
    call = re.compile(r"(?<![\w.:])(%s)\s*\("
                      % "|".join(re.escape(name) for name in wanted))
    called = {}
    for rel, lines in files:
        for number, line in enumerate(lines, 1):
            if line.lstrip().startswith("--"):
                continue
            for match in call.finditer(line):
                name = match.group(1)
                if name not in found and name not in called:
                    called[name] = "%s:%d" % (rel, number)
    for name, where in called.items():
        found.setdefault(name, where)
    return found


def scan_members(files, names_found):
    """{(base, member): "rel/path.lua:line"} for members the client defines.

    A member counts when the client's own Lua writes "function BASE.MEMBER("
    or "BASE.MEMBER = ...". Only bases the cache already knows are worth
    keeping: the question the audit asks is what surface a client-native
    table really has, so a whole-table guard in Core/Compat/ can be told
    apart from filling in the one member that is missing.
    """
    bases = set(names_found)
    patterns = (
        re.compile(r"^\s*function\s+([A-Za-z_][A-Za-z0-9_]*)\s*[.:]([A-Za-z_][A-Za-z0-9_]*)\s*\("),
        re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*[.:]([A-Za-z_][A-Za-z0-9_]*)\s*=(?!=)"),
    )
    out = {}
    for rel, lines in files:
        for number, line in enumerate(lines, 1):
            for pattern in patterns:
                match = pattern.match(line)
                if not match:
                    continue
                base, member = match.group(1), match.group(2)
                if base in bases or base.startswith("C_"):
                    key = (base, member)
                    if key not in out:
                        out[key] = "%s:%d" % (rel, number)
                break
    return out


def write_cache(path, found, src, members=None):
    folder = os.path.dirname(path)
    if folder and not os.path.isdir(folder):
        os.makedirs(folder)
    lines = ["# Client-native names: the client defines them, so define nothing",
             "# wholesale in Core/Compat/ (class N); fill missing members only.",
             "# Generated by tools/scan_client_api.py from %s" % src.replace(os.sep, "/"),
             "# Format: NAME<TAB>file:line (the first definition found)."]
    for name in sorted(found):
        lines.append("%s\t%s" % (name, found[name]))
    if members:
        lines.append("# Members of the tables above: BASE.MEMBER<TAB>file:line. A client")
        lines.append("# table whose surface is known can be checked member by member.")
        for base, member in sorted(members):
            lines.append("%s.%s\t%s" % (base, member, members[(base, member)]))
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines) + "\n")
    return len(found)


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="scan_client_api.py",
        description="Cache which names the CoA client defines (tools/client_native.txt).")
    parser.add_argument("--root", default=DEFAULT_ROOT,
                        help="the addon folder (default: the one above tools/)")
    parser.add_argument("--src", default=DEFAULT_SRC,
                        help="the exported client Interface folder (default: the ports scratch dump)")
    parser.add_argument("--out", default=None,
                        help="cache file (default: <root>/tools/client_native.txt)")
    args = parser.parse_args(argv)

    out = args.out or os.path.join(args.root, "tools", OUT_NAME)
    if not os.path.isdir(args.src):
        sys.stderr.write(
            "scan_client_api: no client dump at %s\n"
            "  pass --src <the exported Interface folder>; the existing %s was left alone\n"
            % (args.src, out))
        return 2
    names = watch_names()
    found = scan(args.src, names)
    members = scan_members(_files(args.src), found)
    count = write_cache(out, found, args.src, members)
    namespaces = len([name for name in found if name.startswith("C_")])
    print("%d names, %d of them C_* namespaces -> %s" % (count, namespaces, out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
