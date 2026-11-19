#!/usr/bin/env python3
"""What the CoA client's own FrameXML provides.

Evidence for tools/coa_audit.py's CLIENT_PROVIDED set: an addon may use a retail
name the client itself defines, but must not lean on one it does not have.

    python -B tools/survey_client_api.py D:\...\_ui-port-scratch\out

Prints, per name, the files that define it (function NAME, NAME = table, ...).
"""
import io
import os
import re
import sys

NAMES = [
    "issecretvalue", "scrubsecretvalues", "wipe", "strsplit", "strtrim",
    "strjoin", "Mixin", "CreateFromMixins", "Enum", "Settings", "Menu",
    "MenuUtil", "InputUtil", "C_GamePad", "TooltipDataProcessor",
    "GetMapInfo", "SetMapByID", "GetCurrentMapAreaID", "GetPlayerMapPosition",
    "GetMapZones", "GetMapContinents", "SetMapZoom", "GetCurrentMapContinent",
    "GetCurrentMapZone", "SetMapToCurrentZone", "GetNumGroupMembers",
    "GetNumRaidMembers", "GetNumPartyMembers", "GetContainerNumSlots",
    "GetContainerItemInfo", "GetContainerItemLink", "GetItemInfo",
    "GetItemInfoInstant", "GetQuestLogTitle", "GetNumQuestLogEntries",
    "GetNumQuestLeaderBoards", "GetQuestLogLeaderBoard", "GetTime",
    "C_Timer", "C_Item", "C_Container", "C_QuestLog", "C_Map", "C_WorldMap",
    "C_AddOns", "C_UnitAuras", "C_PlayerInfo", "C_PvP", "C_Texture",
    "C_MapExplorationInfo", "C_VoiceChat", "UnitPosition", "CreateVector2D",
    "CreateVector3D", "UnitAura", "UnitBuff", "UnitDebuff", "BackdropTemplate",
    "SetColorTexture", "SetAtlas", "UIDropDownMenu_Initialize",
    "UIDropDownMenu_AddButton", "InterfaceOptions_AddCategory",
    "ContainerIDToInventoryID", "GetInventoryItemLink",
]

DEF = r"^(?:local\s+)?(?:function\s+{n}\s*\(|{n}\s*=(?!=)|{n}\s*=\s*function)"

def main(argv):
    root = argv[1] if len(argv) > 1 else "."
    found = {n: [] for n in NAMES}
    scanned = 0
    for base, dirs, files in os.walk(root):
        for name in sorted(files):
            if not name.lower().endswith(".lua"):
                continue
            full = os.path.join(base, name)
            rel = os.path.relpath(full, root).replace(os.sep, "/")
            scanned += 1
            try:
                with io.open(full, "r", encoding="utf-8", errors="replace") as f:
                    lines = f.read().splitlines()
            except OSError:
                continue
            for number, line in enumerate(lines, 1):
                code = line.split("--", 1)[0]
                for n in NAMES:
                    if n not in code:
                        continue
                    if re.match(DEF.format(n=re.escape(n)), code.strip()):
                        found[n].append("%s:%d" % (rel, number))
    print("scanned %d lua files under %s" % (scanned, root))
    for n in NAMES:
        hits = found[n]
        if hits:
            print("%-28s %s" % (n, ", ".join(hits[:3]) + (" ..." if len(hits) > 3 else "")))
    missing = [n for n in NAMES if not found[n]]
    print("\nnot defined by the client (%d):" % len(missing))
    for n in missing:
        print("  " + n)
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
