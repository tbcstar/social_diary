#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Static gate for the Social Diary -> Conquest of Azeroth (3.3.5a) port.

The port keeps every retail global name and backs it with a shim in
Core/Compat/: business code goes on calling C_Map, Enum, Settings and the
rest. That only stays true if something checks it, because a leftover retail
call is invisible until the client raises on a nil -- in the middle of a
session, for one reader.

This script reads the addon as the client will and refuses four kinds of
mistake:

  R1  a retail-only name outside Core/Compat/   (PORT.md 2.2)
  R2  a TOC that names a file that is not there, or a .lua that is not UTF-8
  R3  a TOC directive the 3.3.5 client does not know, or a retail Interface
  R4  an L["..."] key with no zhCN word, and enUS -> zhCN coverage
  R5  a Lua escape 5.1 rejects, or a test shelling out to a Unix command
  R6  the test mock defining a retail global (it would hide R1's failures)

Exit status: 0 when every rule passes, 1 when any rule has an error, 2 for
bad usage or an unreadable tree. --json prints the whole report as one
object.

    python -B tools/coa_audit.py
    python -B tools/coa_audit.py --json
    python -B tools/coa_audit.py --strict        # warnings are errors too
    python -B tools/coa_audit.py --only R1 R4
"""

import argparse
import io
import json
import os
import sys

TOOL = "coa_audit"
VERSION = "1.0"

# ---------------------------------------------------------------------------
# What 3.3.5a does not have
# ---------------------------------------------------------------------------

# Globals retail added and WotLK never had. A C_* name is matched by prefix
# (retail has hundreds, the addon uses a dozen, and a new one is the same
# mistake). Everything else is exact. Names reached through a dot or a colon
# are fields and methods, not globals, and are left alone: Core/Compat/
# Textures.lua teaches the Texture widget SetColorTexture, so the 240 call
# sites keep writing tex:SetColorTexture(...).
RETAIL_GLOBALS = {
    # FrameXML/API helpers
    "issecretvalue", "strsplit", "strtrim", "strjoin", "wipe", "Mixin",
    "CreateFromMixins", "UnitTokenFromGUID", "GetNumGroupMembers",
    "GetItemInfoInstant", "GetSpecialization", "GetSpecializationInfo",
    "UnitPosition", "CreateVector2D", "CreateVector3D", "GetAtlasInfo",
    "TooltipDataProcessor", "MenuUtil", "InputUtil", "ItemLocation",
    "PlayerLocation", "GetSpellTexture", "GetSpellDescription",
    "C_GamePad", "C_CVar", "C_EditMode", "C_MountJournal", "C_PetJournal",
    "C_TooltipInfo", "C_Item", "C_Timer", "C_Map", "C_Container", "C_QuestLog",
    "C_Spell", "C_UnitAuras", "C_PlayerInfo", "C_PartyInfo", "C_Friend",
    "C_PvP", "C_Texture", "C_AddOns", "C_ChatInfo", "C_CurrencyInfo",
    "C_Commentator", "C_Reputation", "C_SocialQueue", "C_Mail", "C_AuctionHouse",
    # Frame/Texture methods retail added, as bare globals they are never valid
    "SetColorTexture", "SetAtlas", "CreateFramePool", "AddonCompartmentFunc",
}
RETAIL_PREFIXES = ("C_",)
# Table names retail introduced wholesale.
RETAIL_TABLES = {"Enum", "Settings"}
# A string the client reads as a frame template name.
RETAIL_TEMPLATES = {"BackdropTemplate"}
# The audit's cache of names the CLIENT itself provides, as tools/scan_client_api.py
# found them in the client's own Lua (tools/client_native.txt). R1 uses it to tell
# three cases apart: class N (the client has the name, so Core/Compat/ may only
# fill in missing members), class S (nobody has it, so Core/Compat/ must define
# it) and class D (Core/Compat/ defines a name the client already has, which
# overwrites client behaviour). R6 uses the same split for the test mock.
CLIENT_NATIVE_FILE = "tools/client_native.txt"

COMPAT_DIR = "Core/Compat/"

# ---------------------------------------------------------------------------
# What the 3.3.5a TOC reader knows
# ---------------------------------------------------------------------------

TOC_KNOWN = {
    "Interface", "Title", "Notes", "Author", "Version", "SavedVariables",
    "SavedVariablesPerCharacter", "DefaultState", "LoadOnDemand",
    "Dependencies", "OptionalDeps", "RequiredDeps", "IconTexture",
    "OnlyBetaAndPTR", "LoadSavedVariablesFirst", "Secure",
}
# Custom ## fields that are fine, with the reason (printed when --json is off
# only on failure, so a reader knows the field was considered).
TOC_JUSTIFIED = {
    "IconTexture": "3.3.5 reads it for the addon list's icon; harmless",
    "X-License": "packaging metadata (Curse/WoWInterface); the 3.3.5 client ignores unknown ## lines",
    "X-Website": "packaging metadata; ignored by the client",
    "X-Email": "packaging metadata; ignored by the client",
    "X-Category": "RETAIL addon-list category; 3.3.5 has no such thing",
}
# Named in PORT.md 2.2 / the port's brief as must-go.
TOC_FORBIDDEN = {"LoadSavedVariablesFirst", "AddonCompartmentFunc", "X-Category"}
TOC_INTERFACE = 30300

UNIX_SHELL = ("find ", "ls -", "grep ", "| sort", "sed ", "awk ")
SHELL_OK_FILES = {"tests/fs.lua"}

# ---------------------------------------------------------------------------
# A Lua 5.1 reader: tokens, and the escapes 5.1 refuses
# ---------------------------------------------------------------------------

ESC_51 = set("abfnrtv\\\"'\n")
ESC_52_PLUS = set("xz")
NAME_START = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_")
NAME_BODY = NAME_START | set("0123456789")


class Finding(object):
    def __init__(self, rule, severity, path, line, message):
        self.rule = rule
        self.severity = severity
        self.path = path
        self.line = line
        self.message = message

    def as_dict(self):
        return {"rule": self.rule, "severity": self.severity, "file": self.path,
                "line": self.line, "message": self.message}


class Scan(object):
    """One .lua file, read: its tokens and what 5.1 would refuse."""

    def __init__(self, path, text):
        self.path = path
        self.text = text
        self.tokens = []      # (kind, value, line)
        self.errors = []      # (line, message)
        self.strings = []     # (line, quote, raw, decoded)
        self._lex()

    # -- lexing ----------------------------------------------------------
    def _lex(self):
        text = self.text
        i, n, line = 0, len(text), 1
        while i < n:
            c = text[i]
            if c == "\n":
                line += 1
                i += 1
                continue
            if c in " \t\r":
                i += 1
                continue
            # comments
            if c == "-" and text.startswith("--", i):
                level = _long_bracket_level(text, i + 2)
                if level is not None:
                    close = "]" + ("=" * level) + "]"
                    end = text.find(close, i + 2 + level + 2)
                    if end < 0:
                        self.errors.append((line, "unterminated long comment"))
                        break
                    line += text.count("\n", i, end)
                    i = end + len(close)
                    continue
                end = text.find("\n", i)
                i = n if end < 0 else end
                continue
            # strings
            if c == '"' or c == "'":
                start_line, j = line, i + 1
                raw = []
                closed = False
                while j < n:
                    ch = text[j]
                    if ch == "\\" and j + 1 < n:
                        raw.append(ch)
                        raw.append(text[j + 1])
                        if text[j + 1] == "\n":
                            line += 1
                        j += 2
                        continue
                    if ch == c:
                        closed = True
                        break
                    if ch == "\n":
                        self.errors.append((start_line, "unterminated string (a newline before the closing quote)"))
                        break
                    raw.append(ch)
                    j += 1
                body = "".join(raw)
                self.strings.append((start_line, c, body, _unquote(body)))
                self._check_escapes(start_line, body)
                self.tokens.append(("string", _unquote(body), start_line))
                i = j + 1 if closed else j
                continue
            if c == "[":
                level = _long_bracket_level(text, i)
                if level is not None:
                    close = "]" + ("=" * level) + "]"
                    body_start = i + level + 2
                    end = text.find(close, body_start)
                    if end < 0:
                        self.errors.append((line, "unterminated long string"))
                        break
                    body = text[body_start:end]
                    self.strings.append((line, "[", body, body))
                    self.tokens.append(("string", body, line))
                    line += text.count("\n", i, end)
                    i = end + len(close)
                    continue
            # names
            if c in NAME_START:
                j = i + 1
                while j < n and text[j] in NAME_BODY:
                    j += 1
                self.tokens.append(("name", text[i:j], line))
                i = j
                continue
            # numbers
            if c.isdigit() or (c == "." and i + 1 < n and text[i + 1].isdigit()):
                j = i + 1
                while j < n and (text[j].isalnum() or text[j] in "._"):
                    j += 1
                self.tokens.append(("number", text[i:j], line))
                i = j
                continue
            self.tokens.append(("punct", c, line))
            i += 1

    def _check_escapes(self, line, body):
        i, n = 0, len(body)
        while i < n:
            if body[i] != "\\":
                i += 1
                continue
            if i + 1 >= n:
                self.errors.append((line, "a backslash at the end of a string"))
                return
            nxt = body[i + 1]
            if nxt in ESC_51:
                i += 2
                continue
            if nxt.isdigit():
                digits = 0
                while i + 1 + digits < n and body[i + 1 + digits].isdigit() and digits < 3:
                    digits += 1
                if int(body[i + 1:i + 1 + digits]) > 255:
                    self.errors.append((line, "decimal escape above 255: %s" % body[i:i + 1 + digits]))
                i += 1 + digits
                continue
            if nxt in ESC_52_PLUS:
                self.errors.append((line, "'\\%s' is Lua 5.2+; this client is 5.1" % nxt))
                i += 2
                continue
            self.errors.append((line, "invalid escape sequence '\\%s' (Lua 5.1 refuses the file)" % nxt))
            i += 2

    # -- helpers ---------------------------------------------------------
    def names(self):
        """Name tokens with the token before them, for global-vs-field tests."""
        prev = None
        for tok in self.tokens:
            yield prev, tok
            prev = tok


def _long_bracket_level(text, i):
    if i >= len(text) or text[i] != "[":
        return None
    j, level = i + 1, 0
    while j < len(text) and text[j] == "=":
        level += 1
        j += 1
    if j < len(text) and text[j] == "[":
        return level
    return None


def _unquote(body):
    out, i, n = bytearray(), 0, len(body)
    simple = {"a": "\a", "b": "\b", "f": "\f", "n": "\n", "r": "\r",
              "t": "\t", "v": "\v", "\\": "\\", '"': '"', "'": "'", "\n": "\n"}
    while i < n:
        ch = body[i]
        if ch != "\\" or i + 1 >= n:
            out += ch.encode("utf-8")
            i += 1
            continue
        nxt = body[i + 1]
        if nxt in simple:
            out += simple[nxt].encode("utf-8")
            i += 2
            continue
        if nxt.isdigit():
            j = i + 1
            while j < n and body[j].isdigit() and j - i <= 3:
                j += 1
            try:
                out.append(int(body[i + 1:j]) & 0xFF)
            except ValueError:
                pass
            i = j
            continue
        out += nxt.encode("utf-8")
        i += 2
    # Lua strings are bytes: a decimal escape such as \194\160 is two bytes of
    # one UTF-8 character, not two characters. Decode once, at the end.
    return bytes(out).decode("utf-8", "replace")


# ---------------------------------------------------------------------------
# The tree
# ---------------------------------------------------------------------------

class Tree(object):
    def __init__(self, root):
        self.root = os.path.abspath(root)
        self.lua = []      # relative paths, forward slashes
        self.other = []
        self._read_all()

    def _read_all(self):
        for base, dirs, files in os.walk(self.root):
            dirs[:] = sorted(d for d in dirs if d not in (".git", ".svn"))
            for name in sorted(files):
                full = os.path.join(base, name)
                rel = os.path.relpath(full, self.root).replace(os.sep, "/")
                if name.endswith(".lua"):
                    self.lua.append(rel)
                else:
                    self.other.append(rel)

    def full(self, rel):
        return os.path.join(self.root, rel.replace("/", os.sep))

    def read_bytes(self, rel):
        with io.open(self.full(rel), "rb") as f:
            return f.read()

    def read_text(self, rel):
        return self.read_bytes(rel).decode("utf-8", "replace")

    def find_toc(self):
        tocs = [p for p in self.other if p.endswith(".toc") and "/" not in p]
        return tocs


def parse_toc(text):
    """(headers, files) -- headers as [(key, value, line)], files as [(path, line)]."""
    headers, files = [], []
    for number, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if not line:
            continue
        if line.startswith("##"):
            if ":" in line:
                key, value = line[2:].split(":", 1)
                headers.append((key.strip(), value.strip(), number))
            continue
        if line.startswith("#"):
            continue
        if line.lower().endswith(".lua"):
            files.append((line.replace("\\", "/"), number))
    return headers, files


# ---------------------------------------------------------------------------
# Rules
# ---------------------------------------------------------------------------

class Report(object):
    def __init__(self):
        self.findings = []
        self.notes = []          # (rule, message) -- for the operator, not a failure
        self.counts = {}

    def add(self, rule, severity, path, line, message):
        self.findings.append(Finding(rule, severity, path, line, message))

    def error(self, rule, path, line, message):
        self.add(rule, "error", path, line, message)

    def warn(self, rule, path, line, message):
        self.add(rule, "warning", path, line, message)

    def note(self, rule, message):
        self.notes.append((rule, message))

    def by_rule(self, rule):
        return [f for f in self.findings if f.rule == rule]

    def has_error(self, rule, strict):
        return any(f.severity == "error" or (strict and f.severity == "warning")
                   for f in self.by_rule(rule))


def retail_kind(name):
    """'table' or 'global' when the name is retail-only, else None."""
    if name in RETAIL_TABLES:
        return "table"
    if name in RETAIL_GLOBALS or name.startswith(RETAIL_PREFIXES):
        return "global"
    return None


class NativeAPI(object):
    """What the client's own Lua provides.

    names:   {name: "file:line"}          the client defines the name itself.
    members: {base: {member: "file:line"}}  the table surface the client's own
             Lua writes out; empty when the client builds the members some
             other way (a metatable, C code), which means "not judgeable".
    present: whether a cache file was found at all. Without one every retail
             name is treated as shim-required, which the R1 note says out loud
             instead of silently demanding a reimplementation of wipe().
    """

    def __init__(self, names=None, members=None, present=False):
        self.names = names or {}
        self.members = members or {}
        self.present = present

    def __contains__(self, name):
        return name in self.names

    def __getitem__(self, name):
        return self.names[name]

    def __bool__(self):
        return bool(self.names)

    __nonzero__ = __bool__


def load_client_native(path):
    """Read tools/client_native.txt into a NativeAPI.

    Lines are "NAME<TAB>file:line", and "BASE.MEMBER<TAB>file:line" for the
    members of a table the client builds itself. Written by
    tools/scan_client_api.py from the client's Lua.
    """
    names, members = {}, {}
    present = bool(path) and os.path.isfile(path)
    if not present:
        return NativeAPI(present=False)
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            for line in handle:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                parts = line.split("\t")
                if len(parts) != 2 or not parts[0]:
                    continue
                key = parts[0]
                if "." in key:
                    base, member = key.split(".", 1)
                    members.setdefault(base, {})[member] = parts[1]
                else:
                    names[key] = parts[1]
    except (IOError, OSError):
        return NativeAPI(present=False)
    return NativeAPI(names, members, present)


def _sites(scan):
    """What one file does with retail-only names.

    defs:    [(name, line, kind)]   kind "full" (X = ...), "guard" (X = X or {})
                                    or "func" (function X(...)).
    members: [(base, member, line)] base.member = ... / function base:member(...)
    uses:    [(name, line, what)]   what "global", "method" or "template".
    """
    toks = scan.tokens
    defs, members, uses = [], [], []
    operators = ("=", "+", "-", "*", "/", "%", "^", "<", ">", "~", "(", "[")
    keywords_before_value = ("and", "or", "not", "return", "if", "elseif", "while", "until")
    # Scope tracking, so "local Enum = _G.Enum" makes the later "Enum = {}" a
    # local write rather than a second global, and "if not C_Map then C_Map =
    # {...} end" reads as a guard (it never overwrites the client's table).
    depth = 0
    local_depth = {}
    guards = []                     # [(name, depth)] from "if not NAME then"
    for i in range(len(toks)):
        kind, value, line = toks[i]
        prev = toks[i - 1] if i else None
        nxt = toks[i + 1] if i + 1 < len(toks) else None
        if kind == "name" and value in ("end", "until"):
            depth -= 1
            while guards and guards[-1][1] > depth:
                guards.pop()
        elif kind == "name" and value == "local" and nxt is not None and nxt[0] == "name":
            local_depth[nxt[1]] = depth
        elif (kind == "name" and value == "then" and prev is not None and prev[0] == "name"
              and i >= 3 and toks[i - 2][0] == "name" and toks[i - 2][1] == "not"
              and toks[i - 3][0] == "name" and toks[i - 3][1] in ("if", "elseif")):
            guards.append((prev[1], depth + 1))
        if kind == "name" and value in ("then", "do", "function", "repeat"):
            depth += 1
        if kind == "string":
            if value in RETAIL_TEMPLATES:
                uses.append((value, line, "template"))
            continue
        # A member written onto a table: "T.m = ..." or "function T:m(...)".
        # Recorded whatever `m` is called, because a table the client builds
        # (C_Map) is filled in member by member with names that are 3.3.5
        # natives, not retail names.
        if (kind == "name" and prev is not None and prev[0] == "punct"
                and prev[1] in (".", ":") and i >= 2 and toks[i - 2][0] == "name"):
            after_m = toks[i + 2] if i + 2 < len(toks) else None
            before_m = toks[i - 3] if i >= 3 else None
            member_assign = (nxt is not None and nxt[0] == "punct" and nxt[1] == "="
                             and not (after_m is not None and after_m[0] == "punct"
                                      and after_m[1] == "="))
            member_func = (before_m is not None and before_m[0] == "name"
                           and before_m[1] == "function")
            # `M.m = M.m or impl` fills a member only when the client lacks it.
            member_fill = (member_assign and i + 5 < len(toks)
                           and toks[i + 2][0] == "name"
                           and toks[i + 2][1] == toks[i - 2][1]
                           and toks[i + 3][1] == "."
                           and toks[i + 4][1] == value
                           and toks[i + 5][1] == "or")
            if member_assign or member_func:
                members.append((toks[i - 2][1], value, line,
                                "fill" if member_fill else "write"))
                continue
        if kind != "name" or retail_kind(value) is None:
            continue
        after = toks[i + 2] if i + 2 < len(toks) else None
        if prev is not None and prev[0] == "punct" and prev[1] in (".", ":"):
            # A field, a method, or the place Compat adds one: the name here
            # is a member, and the table in front of it is the base.
            base = toks[i - 2] if i >= 2 else None
            before = toks[i - 3] if i >= 3 else None
            declaring = (before is not None and before[0] == "name"
                         and before[1] == "function")
            assigning = (nxt is not None and nxt[0] == "punct" and nxt[1] == "="
                         and not (after is not None and after[0] == "punct"
                                  and after[1] == "="))
            if base is not None and base[0] == "name" and (declaring or assigning):
                members.append((base[1], value, line))
            else:
                uses.append((value, line, "method"))
            continue
        if prev is not None and prev[0] == "name" and prev[1] == "local":
            continue                    # a local shadow, not a global
        if i >= 2 and toks[i - 2][0] == "name" and toks[i - 2][1] == "local":
            continue                    # local function X(...)
        if value in local_depth and local_depth[value] <= depth:
            continue                    # a local declared in an enclosing scope
        # C_Map = ...   /   function C_Map(...)   make the global;
        # C_Map == nil  /  x = C_Map  /  { C_Map = 1 }  only read it.
        assigns = (nxt is not None and nxt[0] == "punct" and nxt[1] == "="
                   and not (after is not None and after[0] == "punct" and after[1] == "="))
        declaring = (prev is not None and prev[0] == "name" and prev[1] == "function"
                     and nxt is not None and nxt[0] == "punct" and nxt[1] == "(")
        operator = prev is not None and (
            (prev[0] == "punct" and prev[1] in operators)
            or (prev[0] == "name" and prev[1] in keywords_before_value))
        if prev is not None and prev[0] == "punct" and prev[1] in ("{", ","):
            continue                    # a table-constructor key, not a global
        if (assigns or declaring) and not operator:
            kind_of_def = "full"
            if declaring:
                kind_of_def = "func"
            elif (i + 3 < len(toks) and toks[i + 2][0] == "name"
                  and toks[i + 2][1] == value and toks[i + 3][0] == "name"
                  and toks[i + 3][1] == "or"):
                kind_of_def = "guard"
            elif any(gname == value and gdepth <= depth for gname, gdepth in guards):
                kind_of_def = "guard"   # "if not X then X = ... end" never overwrites
            defs.append((value, line, kind_of_def))
        else:
            uses.append((value, line, "global"))
    return defs, members, uses


def _by_count(sites, limit):
    items = sorted(sites.items(), key=lambda kv: (-len(kv[1]), kv[0]))
    head = ["%s (%d)" % (name, len(found)) for name, found in items[:limit]]
    if len(items) > limit:
        head.append("... %d more" % (len(items) - limit))
    return ", ".join(head)


# Widget methods retail added. A member of one of these names is retail-only
# whatever the table in front of it is called (Texture:SetColorTexture).
RETAIL_METHODS = frozenset([
    "SetColorTexture", "SetAtlas", "GetAtlasInfo", "SetBackdrop",
    "SetBackdropColor", "SetBackdropBorderColor",
])


def _retail_member(base, member, native):
    """Whether base.member is a retail-only name rather than the addon's own."""
    if member in RETAIL_METHODS:
        return True
    if retail_kind(base) is not None or base in native or base == "_G":
        return retail_kind(member) is not None
    return False


def _member_calls(scan, bases):
    """[(base, member, line)] for "base.member(...)" / "base:member(...)".

    A definition ("function base.member(") is skipped: that is the shim being
    written, and R1 already judges it as such.
    """
    toks = scan.tokens
    out = []
    for i in range(len(toks) - 3):
        if toks[i][0] != "name" or toks[i][1] not in bases:
            continue
        if toks[i + 1][1] not in (".", ":"):
            continue
        if toks[i + 2][0] != "name" or toks[i + 3][1] != "(":
            continue
        if i and toks[i - 1][0] == "name" and toks[i - 1][1] in ("function", "local"):
            continue
        out.append((toks[i][1], toks[i + 2][1], toks[i][2]))
    return out


def rule_r1(tree, report, manifest, scans, native):
    """Three sentences, and the whole rule is them (PORT.md §2.1 + §2.2):

    1. Only Core/Compat/ may DEFINE a retail-only global.
    2. Every retail-only name the addon calls must be provided -- by the client
       itself when the client has it (class N, and then Core/Compat/ only fills
       in members the client lacks), otherwise by Core/Compat/ (class S).
    3. Core/Compat/ defining, as a whole, a name the client already provides
       (class D) overwrites client behaviour, so it is an error.

    The client's half comes from tools/client_native.txt, which
    tools/scan_client_api.py writes from the client's own Lua: the split is
    derived from the client, not from a list kept in this file.
    """
    compat_defs, compat_bases, compat_members, compat_mentioned = {}, set(), set(), set()
    compat_member_writes = {}         # base -> [(member, file, line)] written unconditionally
    for rel in tree.lua:
        if not rel.startswith(COMPAT_DIR) or rel not in scans:
            continue
        defs, members, uses = _sites(scans[rel])
        for name, line, kind in defs:
            compat_defs.setdefault(name, (rel, line, kind))
        for base, member, line, _fill in members:
            compat_bases.add(base)
            compat_members.add(member)
            if _fill == "write":
                compat_member_writes.setdefault(base, []).append((member, rel, line))
        for name, line, what in uses:
            compat_mentioned.add(name)
    compat_dir = os.path.isdir(tree.full(COMPAT_DIR))

    needed = {}
    member_needed = {}
    for rel in manifest:
        scan = scans.get(rel)
        if scan is None or rel.startswith(COMPAT_DIR):
            continue
        defs, members, uses = _sites(scan)
        for name, line, kind in defs:
            report.error("R1", rel, line,
                         "%s is retail-only: only Core/Compat/ may define it (PORT.md §2.2); "
                         "a second definition out here shadows the shim" % name)
        for base, member, line, _fill in members:
            if not _retail_member(base, member, native):
                continue                # the addon's own table, e.g. UI.Settings
            report.error("R1", rel, line,
                         "%s.%s is retail-only: only Core/Compat/ may add it (PORT.md §2.2); "
                         "defined out here it shadows the shim" % (base, member))
        for name, line, what in uses:
            needed.setdefault(name, []).append((rel, line, what))
        for base, member, line in _member_calls(scan, set(native.names) | RETAIL_TABLES):
            member_needed.setdefault(base, []).append((member, rel, line))

    # One name at a time, and the client's own cache decides the class: a name
    # the client provides needs no shim, only the members it lacks; one it does
    # not provide needs the shim; and shimming a client-native name as a whole
    # is what overwrites client behaviour.
    native_seen, augmented, guarded, missing, guarded_native = [], [], [], [], []
    for name in sorted(needed):
        sites = needed[name]
        defn = compat_defs.get(name)
        if name in RETAIL_TEMPLATES:
            if name not in native and name not in compat_mentioned:
                missing.append((name, sites))
            continue
        if name in native:
            native_seen.append(name)
            if defn is not None and defn[2] != "guard":
                rel, line, _kind = defn
                report.error("R1", rel, line,
                             "%s is client-native (the client defines it at %s) and Core/Compat/ "
                             "defines it again as a whole: fill in the missing members instead, a "
                             "wholesale redefinition overwrites client behaviour (class D)"
                             % (name, native[name]))
                continue
            if defn is not None:
                guarded_native.append("%s (%s:%s)" % (name, defn[0], defn[1]))
            if name in compat_bases or name in compat_members:
                augmented.append(name)
            continue
        if defn is not None:
            if defn[2] == "guard":
                guarded.append(name)
            continue
        if name in compat_members:
            continue
        missing.append((name, sites))
    missing.sort(key=lambda kv: (-len(kv[1]), kv[0]))

    if not compat_dir:
        shim = [name for name in needed if name not in native]
        if shim:
            report.error("R1", COMPAT_DIR, 0,
                         "Core/Compat/ does not exist yet, so none of the %d retail names this "
                         "addon calls is implemented (PORT.md §3)" % len(shim))
            report.note("R1", "Core/Compat/ has to define, most-used first: %s"
                        % _by_count({n: needed[n] for n in shim}, 40))
        if native:
            report.note("R1", "the client itself provides %d of these names (class N), so only the "
                        "members it lacks need filling in, not the name: %s"
                        % (len([n for n in needed if n in native]),
                           ", ".join(sorted(n for n in needed if n in native)[:40])))
        return
    if not native:
        report.note("R1", "tools/client_native.txt is missing, so every retail name is treated as "
                    "shim-required; run tools/scan_client_api.py to refresh the client cache")
    # A table the client builds itself has a surface: the members its own Lua
    # writes. A member the addon calls, that is not in that surface and that no
    # Core/Compat/ file adds, is only there when the client builds it another
    # way -- and a whole-table guard then leaves it nil (class D gap).
    gaps = []
    for base in sorted(member_needed):
        surface = native.members.get(base) or {}
        if not surface:
            continue                    # metatable or C code: not judgeable here
        for member, rel, line in sorted(member_needed[base]):
            if member in surface or member in compat_members:
                continue
            gaps.append((base, member, rel, line, surface))
    for base, member, rel, line, surface in gaps:
        report.warn("R1", rel, line,
                    "%s.%s is called, but the client's own %s (%s) writes only %s and no "
                    "Core/Compat/ file adds the member: a whole-table guard leaves %s.%s nil on "
                    "this client (class D gap; fill in that one member)"
                    % (base, member, base, native.names.get(base, "?"),
                       ", ".join(sorted(surface)[:8]), base, member))
    # A member the client already writes, written again unconditionally by
    # Core/Compat/, replaces working client behaviour (class D). `M.m = M.m or
    # impl` is the fill form and is not one of these.
    overwritten = []
    for base in sorted(compat_member_writes):
        surface = native.members.get(base) or {}
        if not surface:
            continue
        for member, rel, line in compat_member_writes[base]:
            if member in surface:
                overwritten.append((base, member, rel, line, surface))
    for base, member, rel, line, surface in overwritten:
        report.error("R1", rel, line,
                     "Core/Compat/ writes %s.%s unconditionally, but the client already "
                     "provides it (%s): fill it in only when missing (class D)"
                     % (base, member, native.members.get(base, {}).get(member, "?")))
    for name, sites in missing:
        rel, line, what = sites[0]
        if what == "template":
            report.error("R1", rel, line,
                         "the frame template %r is retail-only (3.3.5 has no such template) and "
                         "no Core/Compat/ file mentions it, so nothing supplies the mixin" % name)
        elif what == "method":
            report.error("R1", rel, line,
                         "%s is a retail method the widget does not have, and no Core/Compat/ file "
                         "adds it: %d call site(s) would error as soon as they run (class S)"
                         % (name, len(sites)))
        else:
            report.error("R1", rel, line,
                         "%s is neither provided by the client (tools/client_native.txt) nor "
                         "defined by Core/Compat/, and %d call site(s) use it (PORT.md §2.1 keeps "
                         "the call, §3 puts the shim in Compat; class S)" % (name, len(sites)))
    report.note("R1", "%d retail names are client-native (class N: filled in, never redefined); "
                "%d are shim-required (class S); %d distinct retail names are called from the rest "
                "of the addon" % (len(native_seen), len(needed) - len(native_seen), len(needed)))
    if augmented:
        report.note("R1", "class N names Core/Compat/ adds members to: %s" % ", ".join(sorted(augmented)))
    if guarded:
        report.note("R1", "guarded, so the client's own copy stays: %s" % ", ".join(sorted(guarded)))
    if guarded_native:
        filled = [entry for entry in guarded_native
                  if entry.split(" ")[0] in compat_bases]
        empty = [entry for entry in guarded_native if entry not in filled]
        if filled:
            report.note("R1", "client-native names Core/Compat/ fills member by member (the "
                        "whole-table form `T = T or {}` only keeps the client's own copy): %s"
                        % ", ".join(sorted(filled)))
        if empty:
            report.note("R1", "client-native names Core/Compat/ only builds when the client "
                        "lacks them (a whole-table guard, so nothing is added on this client; "
                        "the client's own copy is used as is): %s" % ", ".join(sorted(empty)))
    if gaps:
        report.note("R1", "%d member(s) of client-native tables are called but missing from the "
                    "client's own surface: %s"
                    % (len(gaps), ", ".join("%s.%s" % (base, member) for base, member, _r, _l, _s in gaps)))
    if missing:
        report.note("R1", "still shim-required (class S), most-used first: %s"
                    % _by_count({n: needed[n] for n, _sites_ in missing}, 40))


def rule_r2(tree, report, toc_name, manifest):
    """Every file the TOC names exists; every .lua is UTF-8."""
    if not toc_name:
        return
    for rel, line in manifest:
        if not os.path.exists(tree.full(rel)):
            report.error("R2", toc_name, line,
                         "the TOC names %s, which is not on disk (the client stops loading here)" % rel)
    for rel in tree.lua:
        raw = tree.read_bytes(rel)
        try:
            raw.decode("utf-8")
        except UnicodeDecodeError as exc:
            bad = raw[:exc.start].count(b"\n") + 1
            report.error("R2", rel, bad,
                         "not UTF-8 (%s at byte %d): the client reads these files as UTF-8"
                         % (exc.reason, exc.start))
        if raw.startswith(b"\xef\xbb\xbf"):
            report.warn("R2", rel, 1, "starts with a UTF-8 BOM; Lua 5.1 chokes on it")
    listed = set(rel for rel, _ in manifest)
    # Everything a shipped addon never loads, so a missing TOC line is not a bug:
    # the suite, this tool, the dev tooling and the repo scaffolding.
    never_loaded = ("tests/", "tools/", "Dev/", ".claude/", ".github/", ".vscode/")
    for rel in tree.lua:
        if rel in listed or rel.startswith(never_loaded):
            continue
        report.warn("R2", rel, 0, "not named in the TOC, so the client never loads it")


def rule_r3(tree, report, toc_name, headers):
    """The TOC header: nothing 3.3.5 refuses, and a 3.3.5 Interface."""
    if not toc_name:
        return
    seen = {}
    for key, value, line in headers:
        seen[key] = value
        if key in TOC_FORBIDDEN:
            report.error("R3", toc_name, line,
                         "## %s: is retail-only; 3.3.5 has no such directive" % key)
            continue
        if key in TOC_KNOWN or key in TOC_JUSTIFIED:
            continue
        report.warn("R3", toc_name, line,
                    "## %s: is not a 3.3.5 directive and is not on the justified list (%s)"
                    % (key, ", ".join(sorted(TOC_JUSTIFIED))))
    interface = seen.get("Interface")
    if interface is None:
        report.error("R3", toc_name, 0, "no ## Interface: line; 3.3.5 will not load the addon")
    else:
        try:
            number = int(interface.split(".")[0])
        except ValueError:
            number = -1
        if number != TOC_INTERFACE:
            report.error("R3", toc_name, 0,
                         "## Interface: %s, but this client is 3.3.5a (%d); it shows the addon as "
                         "out of date and skips it unless Load out of date AddOns is ticked"
                         % (interface, TOC_INTERFACE))
    folder = os.path.basename(tree.root)
    if toc_name and os.path.splitext(toc_name)[0] != folder:
        report.error("R3", toc_name, 0,
                     "the TOC must be named after its folder (%s.toc): the client looks for "
                     "Interface/AddOns/%s/%s.toc, not %s"
                     % (folder, folder, folder, toc_name))


def _locale_keys(tree, pattern):
    """The keys one locale's files define: {key: file}."""
    keys = {}
    for rel in tree.lua:
        if not pattern(rel):
            continue
        scan = Scan(rel, tree.read_text(rel))
        toks = scan.tokens
        for i in range(len(toks) - 3):
            if toks[i][0] == "punct" and toks[i][1] == "[":
                if toks[i + 1][0] == "string" and toks[i + 2][0] == "punct" and toks[i + 2][1] == "]":
                    if toks[i + 3][0] == "punct" and toks[i + 3][1] == "=":
                        keys[toks[i + 1][1]] = rel
    return keys


def rule_r4(tree, report, manifest, scans, strict):
    """Every L["..."] has a zhCN word; enUS keys are covered by zhCN."""
    enus = _locale_keys(tree, lambda p: p == "Locales/enUS.lua")
    zhcn = _locale_keys(tree, lambda p: p.startswith("Locales/zhCN/"))
    if not enus:
        report.error("R4", "Locales/enUS.lua", 0, "no keys found: is the master list generated?")
    if not zhcn:
        report.error("R4", "Locales/zhCN/", 0, "no keys found")

    used = {}
    for rel in manifest:
        if rel.startswith("Locales/") or rel not in scans:
            continue
        scan = scans[rel]
        toks = scan.tokens
        # The three shapes Dev/Locale/extract.lua reads a key from:
        # L["..."], ns.L["..."] and ns.T("...").
        for i in range(len(toks) - 3):
            if toks[i][0] != "name":
                continue
            field = i and toks[i - 1][0] == "punct" and toks[i - 1][1] == "."
            if toks[i][1] == "L" and toks[i + 1][1] == "[":
                if (toks[i + 2][0] == "string"
                        and toks[i + 3][0] == "punct" and toks[i + 3][1] == "]"):
                    used.setdefault(toks[i + 2][1], (rel, toks[i][2]))
            elif toks[i][1] == "T" and field and toks[i + 1][1] == "(":
                if (toks[i + 2][0] == "string"
                        and toks[i + 3][0] == "punct" and toks[i + 3][1] == ")"):
                    used.setdefault(toks[i + 2][1], (rel, toks[i][2]))

    missing = sorted(k for k in used if k not in zhcn)
    for key in missing:
        rel, line = used[key]
        report.error("R4", rel, line, "L[%r] has no zhCN word (Locales/zhCN/)" % key)

    uncovered = sorted(k for k in enus if k not in zhcn)
    coverage = (len(enus) - len(uncovered)) * 100.0 / len(enus) if enus else 0.0
    report.note("R4", "zhCN covers %d of %d enUS keys (%.1f%%)"
                % (len(enus) - len(uncovered), len(enus), coverage))
    report.note("R4", "%d of %d keys are used by the code" % (len(used), len(enus)))
    for key in uncovered:
        report.warn("R4", enus[key], 0,
                    "enUS key %r has no zhCN word (%d missing)" % (key, len(uncovered)))
    for key, (rel, line) in sorted(used.items(), key=lambda kv: kv[0]):
        if key and key not in enus:
            report.warn("R4", rel, line,
                        "L[%r] is not in Locales/enUS.lua: regenerate it (Dev/Locale/extract.lua)" % key)


def rule_r5(tree, report, scans, manifest):
    """Escapes 5.1 refuses, and shelling out to a Unix command."""
    for rel in tree.lua:
        if rel not in scans:
            continue
        scan = scans[rel]
        for line, message in scan.errors:
            report.error("R5", rel, line, message)
        # a Windows path with a single backslash that happens to be a valid
        # escape is not a parse error, only a broken icon: warn.
        for line, quote, raw, decoded in scan.strings:
            if raw == decoded:
                continue
            lowered = decoded.lower()
            if ("\t" in decoded or "\r" in decoded or "\b" in decoded or "\f" in decoded) and (
                    ".ttf" in lowered or ".otf" in lowered or ".blp" in lowered
                    or ".tga" in lowered or "interface\\" in lowered
                    or "interface/" in lowered):
                report.warn("R5", rel, line,
                            "looks like a Windows path written with single backslashes "
                            "(a tab or a backspace where a separator was meant)")
        # io.popen
        toks = scan.tokens
        for i in range(len(toks) - 3):
            if (toks[i][0] == "name" and toks[i][1] == "io"
                    and toks[i + 1][1] == "." and toks[i + 2][0] == "name"
                    and toks[i + 2][1] == "popen"):
                rel_ok = rel in SHELL_OK_FILES
                if not rel_ok:
                    report.error("R5", rel, toks[i][2],
                                 "io.popen in the addon: a shipped addon cannot run a shell "
                                 "(and tests must use tests/fs.lua, which speaks both shells)")
                    continue
                cmd = None
                for j in range(i + 3, min(i + 8, len(toks))):
                    if toks[j][0] == "string":
                        cmd = toks[j][1]
                        break
                if cmd and any(word in cmd for word in UNIX_SHELL):
                    source = scan.text
                    if "FS.windows" not in source:
                        report.error("R5", rel, toks[i][2],
                                     "io.popen with a Unix-only command (%r) and no Windows branch"
                                     % cmd.strip())


def rule_r6(tree, report, scans, native):
    """The test mock stands in for the client, not for Core/Compat/.

    A name the client provides (class N) is the mock's to model: a mock that
    answered wipe() or Enum would be lying about the client it stands for. A
    name the client does NOT provide (class S) must not be there either: the
    addon would then pass R1 on the mock's own shim and the suite would prove
    nothing about Core/Compat/.
    """
    rel = "tests/wowmock.lua"
    if rel not in scans:
        return
    scan = scans[rel]
    defs, members, uses = _sites(scan)
    modelled = sorted(set(name for name, _line, _kind in defs if name in native))

    def judge(name, line):
        if name in RETAIL_TEMPLATES:
            return                  # a template is a string, not a global
        if native.present and name in native:
            return                  # the client's own: the mock may model it
        report.error("R6", rel, line,
                     "the mock defines %r, which the client does not provide (class S): "
                     "Core/Compat/ has to, or the suite passes R1 on the mock's own shim"
                     % name)

    for name, line, _kind in defs:
        judge(name, line)
    for base, member, line, _fill in members:
        # "_G.X = ..." is the mock writing a global; only a retail-only name
        # there is R6's business (CreateFont and UIParent are the client's
        # own globals that no cache lists).
        if base == "_G":
            if retail_kind(member) is not None:
                judge(member, line)
        elif retail_kind(member) is not None:
            judge(member, line)
    toks = scan.tokens
    for i in range(len(toks) - 4):
        if toks[i][0] == "name" and toks[i][1] == "_G":
            if toks[i + 1][1] == "[" and toks[i + 2][0] == "string":
                if toks[i + 4][1] == "=":
                    judge(toks[i + 2][1], toks[i][2])
    for name, line, what in uses:
        if what == "template" and name not in native:
            report.warn("R6", rel, line,
                        "the mock mentions the retail-only template %r; nothing the client has "
                        "supplies it (Core/Compat/ must, or the frames error)" % name)
    if modelled:
        report.note("R6", "%d client-native names are modelled by the mock (class N): %s"
                    % (len(modelled), ", ".join(modelled[:30])))


# ---------------------------------------------------------------------------
# What runs
# ---------------------------------------------------------------------------

RULES = [
    ("R1", "retail-only names: the client's own (class N) are filled in, never redefined (class D); the rest (class S) live in Core/Compat/"),
    ("R2", "the TOC's files exist, and every .lua is UTF-8"),
    ("R3", "the TOC says only what a 3.3.5 client reads"),
    ("R4", "every L[...] key has a zhCN word"),
    ("R5", "Lua 5.1 escapes, and no Unix shell from tests"),
    ("R6", "the test mock stands in for the client, not for Core/Compat/ (no class-S name)"),
]


def run(root, only, strict, client_native_path=None):
    tree = Tree(root)
    report = Report()
    scans = {}
    native = load_client_native(client_native_path)

    tocs = tree.find_toc()
    toc_name = tocs[0] if len(tocs) == 1 else None
    if len(tocs) == 0:
        report.error("R3", "", 0, "no .toc at the top of the addon: the client loads nothing")
        headers, manifest = [], []
    elif len(tocs) > 1:
        report.error("R3", "", 0, "more than one .toc at the top (%s): only one is the addon"
                     % ", ".join(tocs))
        headers, manifest = [], []
    else:
        headers, manifest = parse_toc(tree.read_text(toc_name))

    wanted = set(only) if only else set(rule for rule, _ in RULES)
    for rel in tree.lua:
        if rel.startswith("Vendor/"):
            continue          # upstream GPL data, copied as it ships
        try:
            text = tree.read_text(rel)
        except (IOError, OSError) as exc:
            report.error("R2", rel, 0, "unreadable: %s" % exc)
            continue
        scans[rel] = Scan(rel, text)

    if "R1" in wanted:
        rule_r1(tree, report, [rel for rel, _ in manifest], scans, native)
    if "R2" in wanted:
        rule_r2(tree, report, toc_name, manifest)
    if "R3" in wanted:
        rule_r3(tree, report, toc_name, headers)
    if "R4" in wanted:
        rule_r4(tree, report, [rel for rel, _ in manifest], scans, strict)
    if "R5" in wanted:
        rule_r5(tree, report, scans, [rel for rel, _ in manifest])
    if "R6" in wanted:
        rule_r6(tree, report, scans, native)

    status = {}
    for rule, title in RULES:
        if rule not in wanted:
            status[rule] = "skipped"
        elif report.has_error(rule, strict):
            status[rule] = "fail"
        else:
            status[rule] = "pass"
    return tree, report, status, toc_name, len(manifest)


def _safe_streams():
    """UTF-8 out, and never a UnicodeEncodeError on a cp936 console."""
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="backslashreplace")
        except (AttributeError, ValueError):
            pass


MAX_PRINTED = 25


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="coa_audit.py",
        description="Static gate for the Social Diary -> 3.3.5a port.")
    parser.add_argument("--root", default=None,
                        help="the addon folder (default: the one above tools/)")
    parser.add_argument("--json", action="store_true", help="the whole report as one JSON object")
    parser.add_argument("--strict", action="store_true", help="warnings are errors too")
    parser.add_argument("--only", nargs="+", choices=[r for r, _ in RULES],
                        help="run only these rules")
    parser.add_argument("--quiet", action="store_true", help="print failures only")
    parser.add_argument("--client-native", default=None,
                        help="the client's own API cache (default: <root>/tools/client_native.txt), "
                             "written by tools/scan_client_api.py")
    args = parser.parse_args(argv)
    _safe_streams()

    root = args.root
    if root is None:
        here = os.path.dirname(os.path.abspath(__file__))
        root = os.path.dirname(here)
    if not os.path.isdir(root):
        sys.stderr.write("coa_audit: no such folder: %s\n" % root)
        return 2
    if not os.path.exists(os.path.join(root, "Locales")) and not os.path.exists(
            os.path.join(root, "Core")):
        sys.stderr.write("coa_audit: %s does not look like the addon (no Core/ or Locales/)\n" % root)
        return 2

    try:
        native_path = args.client_native or os.path.join(root, "tools", "client_native.txt")
        tree, report, status, toc_name, manifest_lines = run(root, args.only, args.strict, native_path)
    except (IOError, OSError) as exc:
        sys.stderr.write("coa_audit: cannot read the tree: %s\n" % exc)
        return 2

    errors = [f for f in report.findings if f.severity == "error"]
    warnings = [f for f in report.findings if f.severity == "warning"]
    failed = [rule for rule, state in status.items() if state == "fail"]

    if args.json:
        payload = {
            "tool": TOOL,
            "version": VERSION,
            "root": tree.root,
            "toc": toc_name,
            "toc_files": manifest_lines,
            "rules": [{"id": rule, "title": title, "status": status[rule],
                       "errors": len([f for f in report.by_rule(rule) if f.severity == "error"]),
                       "warnings": len([f for f in report.by_rule(rule) if f.severity == "warning"])}
                      for rule, title in RULES],
            "notes": [{"rule": rule, "message": message} for rule, message in report.notes],
            "findings": [f.as_dict() for f in
                         sorted(report.findings, key=lambda f: (f.rule, f.path, f.line, f.message))],
            "summary": {"ok": not failed, "failed_rules": failed,
                        "errors": len(errors), "warnings": len(warnings),
                        "lua_files": len(tree.lua), "strict": args.strict},
        }
        print(json.dumps(payload, indent=2, ensure_ascii=False))
        return 0 if not failed else 1

    out = []
    out.append("%s %s  %s" % (TOOL, VERSION, tree.root))
    out.append("  %s: %d .lua files, %d of them in the TOC"
               % (toc_name or "no TOC", len(tree.lua), manifest_lines))
    for rule, title in RULES:
        state = status[rule]
        mark = {"pass": "PASS", "fail": "FAIL", "skipped": "---- "}[state]
        if args.quiet and state == "pass":
            continue
        out.append("  [%s] %s  %s" % (mark, rule, title))
        shown = 0
        for finding in report.by_rule(rule):
            if finding.severity == "error" or not args.quiet:
                if shown >= MAX_PRINTED:
                    out.append("         ... %d more (--json lists them all)"
                               % (len(report.by_rule(rule)) - shown))
                    break
                shown += 1
                where = finding.path + ((":%d" % finding.line) if finding.line else "")
                out.append("         %s %s: %s"
                           % ("x" if finding.severity == "error" else "!", where, finding.message))
    for rule, message in report.notes:
        out.append("  note %s: %s" % (rule, message))
    out.append("")
    if failed:
        out.append("FAILED %d rule(s): %s -- %d error(s), %d warning(s)"
                   % (len(failed), ", ".join(failed), len(errors), len(warnings)))
    else:
        out.append("OK -- %d error(s), %d warning(s)%s"
                   % (len(errors), len(warnings), " (strict)" if args.strict else ""))
    print("\n".join(out))
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
