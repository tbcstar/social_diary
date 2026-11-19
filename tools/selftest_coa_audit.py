"""Prove tools/coa_audit.py is not vacuous: every rule must fail a broken addon.

Run it after changing either file:

    python -B tools/selftest_coa_audit.py

It builds throwaway addons under a temp dir, runs the audit on each and checks
the rule that has to fire. Exit code 0 = the gate still catches all of it.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
AUDIT = os.path.join(HERE, "coa_audit.py")

TOC_HEAD = """## Interface: 30300
## Title: Self Test
## Version: 1.0
## SavedVariables: SocialDiaryDB

"""


def build(root, files):
    for rel, text in files.items():
        full = os.path.join(root, rel.replace("/", os.sep))
        folder = os.path.dirname(full)
        if folder and not os.path.isdir(folder):
            os.makedirs(folder)
        with open(full, "wb") as handle:
            handle.write(text if isinstance(text, bytes) else text.encode("utf-8"))


def audit(root, *args):
    """Run the audit and parse its JSON.

    A case that wants the client-native split writes tools/client_native.txt
    into its addon first (client_cache below); without one every retail name
    is treated as shim-required, which is the right default for a gate.
    """
    out = subprocess.run([sys.executable, "-B", AUDIT, "--root", root, "--json"] + list(args),
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        return json.loads(out.stdout.decode("utf-8", "replace"))
    except ValueError:
        raise SystemExit("the audit did not print JSON (exit %d)\n%s\n%s"
                         % (out.returncode, out.stdout[:2000], out.stderr[:2000]))


def failing(report):
    return set(rule["id"] for rule in report["rules"] if rule["status"] == "fail")


def findings(report, rule):
    return [f for f in report["findings"] if f["rule"] == rule]


CASES = []


def case(name, files, expect, check=None):
    CASES.append((name, files, set(expect), check))


def client_cache(*lines):
    """The client-native cache an addon ships, as tools/client_native.txt."""
    head = ("# test cache\n# NAME<TAB>file:line\n")
    return {"tools/client_native.txt": head + "\n".join(lines) + "\n"}


# A clean port: the call stays in business code, the shim is in Core/Compat/.
CLEAN = {
    "addontest.toc": TOC_HEAD + "Core/Compat/Map.lua\nCore/Place.lua\nLocales/enUS.lua\nLocales/zhCN/a.lua\n",
    "Core/Compat/Map.lua": "C_Map = C_Map or {}\nfunction C_Map.GetMapInfo(id) return nil end\n",
    "Core/Place.lua": "local addonName, ns = ...\nlocal info = C_Map.GetMapInfo(1412)\n"
                      "local text = ns.L[\"A day in Mulgore\"]\n",
    "Locales/enUS.lua": "ns.Locale.Add(\"enUS\", { [\"A day in Mulgore\"] = \"A day in Mulgore\" })\n",
    "Locales/zhCN/a.lua": "ns.Locale.Add(\"zhCN\", { [\"A day in Mulgore\"] = \"\xe7\x8e\x9b\xe6\xa0\xbc\xe9\x9b\xb7\xe7\x9a\x84\xe4\xb8\x80\xe5\xa4\xa9\" })\n",
}
case("clean port passes", CLEAN, [])

# The shim is missing entirely: the call must be reported.
missing_shim = dict(CLEAN)
del missing_shim["Core/Compat/Map.lua"]
missing_shim["addontest.toc"] = TOC_HEAD + "Core/Place.lua\nLocales/enUS.lua\nLocales/zhCN/a.lua\n"
case("retail call with no shim", missing_shim, ["R1"])

# The shim exists but a second definition appears outside Core/Compat/.
shadowed = dict(CLEAN)
shadowed["Core/Place.lua"] = CLEAN["Core/Place.lua"] + "\nC_Map = { }\n"
case("shim redefined outside Compat", shadowed, ["R1"])

# A retail template nothing supplies.
template = dict(CLEAN)
template["Core/Place.lua"] = CLEAN["Core/Place.lua"] + "\nlocal f = CreateFrame(\"Frame\", nil, UIParent, \"BackdropTemplate\")\n"
case("BackdropTemplate with no mixin", template, ["R1"])

# TOC names a file that is not on disk, and one file is not UTF-8.
bad_toc = dict(CLEAN)
bad_toc["addontest.toc"] = CLEAN["addontest.toc"] + "Core/Missing.lua\n"
case("TOC names a missing file", bad_toc, ["R2"])

bad_utf8 = dict(CLEAN)
bad_utf8["Core/Place.lua"] = b"local addonName, ns = ...\n-- \xc3\x28 broken\n"
case("not UTF-8", bad_utf8, ["R2"])

# Retail-only TOC directives and a retail Interface.
bad_head = dict(CLEAN)
bad_head["addontest.toc"] = ("## Interface: 16001\n## Title: Self Test\n"
                             "## LoadSavedVariablesFirst: 1\n## AddonCompartmentFunc: Foo\n"
                             + "Core/Compat/Map.lua\nCore/Place.lua\nLocales/enUS.lua\nLocales/zhCN/a.lua\n")
case("retail TOC directives", bad_head, ["R3"])

# A key with no zhCN word.
untranslated = dict(CLEAN)
untranslated["Core/Place.lua"] = CLEAN["Core/Place.lua"] + "local more = ns.L[\"Never translated\"]\n"
untranslated["Locales/enUS.lua"] = CLEAN["Locales/enUS.lua"].replace(
    "} )", "} )").replace("\n", "\n") + ""
untranslated["Locales/enUS.lua"] = ("ns.Locale.Add(\"enUS\", { [\"A day in Mulgore\"] = \"A day in Mulgore\","
                                    " [\"Never translated\"] = \"Never translated\" })\n")
case("L key with no zhCN word", untranslated, ["R4"])

# A Windows path written with single backslashes, and a Unix shell from tests/.
escapes = dict(CLEAN)
escapes["Core/Place.lua"] = CLEAN["Core/Place.lua"] + "local icon = \"Interface\\Icons\\INV_Misc_Book_09\"\n"
case("Windows path in a Lua escape", escapes, ["R5"])

shell = dict(CLEAN)
shell["addontest.toc"] = CLEAN["addontest.toc"]
shell["tests/run.lua"] = "local p = io.popen(\"find . -name '*.lua' | sort\")\n"
case("Unix shell in the suite", shell, ["R5"])

# The mock must not hand the addon a retail global.
mock = dict(CLEAN)
mock["addontest.toc"] = CLEAN["addontest.toc"]
mock["tests/wowmock.lua"] = "_G.C_Map = { GetMapInfo = function() end }\n"
case("mock defines a retail global", mock, ["R6"])


# With the client's own cache: a name the client provides may be modelled by
# the mock (class N), one it does not may not (class S).
mock_native = dict(CLEAN)
mock_native.update(client_cache("Enum\tSharedXML/Enum.lua:34"))
mock_native["tests/wowmock.lua"] = "Enum = { TooltipDataType = { Unit = 2 } }\n"
case("mock models a client-native name", mock_native, [])

mock_shim = dict(CLEAN)
mock_shim.update(client_cache("Enum\tSharedXML/Enum.lua:34"))
mock_shim["tests/wowmock.lua"] = "C_Item = { GetItemInfo = function() end }\n"
case("mock defines a class-S name", mock_shim, ["R6"])

# A client-native table may be filled in member by member, never replaced.
augmented = dict(CLEAN)
augmented.update(client_cache("C_Map\tFrameXML/Util/C_WorldMap.lua:188",
                              "C_Map.GetBestMapForUnit\tFrameXML/Util/C_WorldMap.lua:190"))
augmented["Core/Compat/Map.lua"] = (
    "C_Map = C_Map or {}\n"
    "if not C_Map.GetMapInfo then\n"
    "    function C_Map.GetMapInfo(id) return nil end\n"
    "end\n")
case("client-native table augmented", augmented, [])

# The member-by-member fill form the lead asked to be recognised: the table
# is kept and each missing member is added only when the client lacks it.
filled = dict(CLEAN)
filled.update(client_cache("C_Map\tFrameXML/Util/C_WorldMap.lua:188",
                         "C_Map.GetBestMapForUnit\tFrameXML/Util/C_WorldMap.lua:190"))
filled["Core/Compat/Map.lua"] = (
    "C_Map = C_Map or {}\n"
    "C_Map.GetBestMapForUnit = C_Map.GetBestMapForUnit or function() return nil end\n"
    "C_Map.GetMapInfo = C_Map.GetMapInfo or function(id) return nil end\n")
case("client-native members filled", filled, [])

# But an unconditional write of a member the client already has replaces
# working client behaviour: class D.
overwritten = dict(CLEAN)
overwritten.update(client_cache("C_Map\tFrameXML/Util/C_WorldMap.lua:188",
                             "C_Map.GetBestMapForUnit\tFrameXML/Util/C_WorldMap.lua:190"))
overwritten["Core/Compat/Map.lua"] = (
    "C_Map = C_Map or {}\n"
    "C_Map.GetBestMapForUnit = function() return nil end\n")
case("client-native member overwritten", overwritten, ["R1"])

replaced = dict(CLEAN)
replaced.update(client_cache("C_Map\tFrameXML/Util/C_WorldMap.lua:188",
                             "C_Map.GetBestMapForUnit\tFrameXML/Util/C_WorldMap.lua:190"))
replaced["Core/Compat/Map.lua"] = (
    "C_Map = { GetBestMapForUnit = function() end, GetMapInfo = function() end }\n")
case("client-native table replaced whole", replaced, ["R1"])


def main():
    failures = 0
    temp = tempfile.mkdtemp(prefix="coa_audit_selftest_")
    try:
        for name, files, expect, check in CASES:
            root = os.path.join(temp, "addontest")
            if os.path.isdir(root):
                shutil.rmtree(root)
            os.makedirs(root)
            build(root, files)
            report = audit(root)
            got = failing(report)
            ok = got == expect
            if not ok:
                failures += 1
                print("FAIL %-32s expected %s, got %s"
                      % (name, sorted(expect) or "no rule", sorted(got) or "no rule"))
                for item in report["findings"]:
                    print("       %s %s:%s %s" % (item["rule"], item["path"], item["line"],
                                                  item["message"]))
            else:
                print("ok   %-32s %s" % (name, ", ".join(sorted(expect)) or "all rules pass"))
    finally:
        shutil.rmtree(temp, ignore_errors=True)
    if failures:
        print("\n%d of %d self-test cases failed" % (failures, len(CASES)))
        return 1
    print("\nALL %d SELF-TESTS PASSED" % len(CASES))
    return 0


if __name__ == "__main__":
    sys.exit(main())
