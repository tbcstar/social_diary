-- Finding files without a dependency, on either OS.
--
-- Some tests read the tree itself: a feature is a folder (Features/<Name>/),
-- a group is a folder of folders (Features/Classes/Hunter/), UI/Style's
-- areas are files, and every .lua a player's words may live in has to be
-- opened. Lua has no directory API, nothing here ships LuaFileSystem, and
-- the shell is two shells: find/ls on Unix, dir on Windows -- a test written
-- against one of them fails on the other machine for a reason that has
-- nothing to do with the addon.
--
-- So: lfs when the host happens to have it, else the OS's own lister, else
-- the addon's own manifest (the TOC names every file the client loads).
-- Names come back sorted and "/"-separated, so a path built from them reads
-- the same everywhere. A folder that cannot be listed at all raises with
-- what was tried and where the suite thinks it is running from: a silent
-- empty list is how "the sources not found from ?" happened.

local FS = {}

FS.windows = package.config:sub(1, 1) == "\\"
local QUIET = FS.windows and " 2>NUL" or " 2>/dev/null"

local function Trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- A path as the shell wants it: quoted, so a folder with a space works.
local function Quoted(path)
    return '"' .. path .. '"'
end

-- A Lua pattern that matches text literally.
local function Literal(text)
    return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

local function Lines(cmd)
    local pipe = io.popen(cmd)
    if not pipe then return nil end
    local out = {}
    for line in pipe:lines() do
        local name = Trim(line)
        if name ~= "" then out[#out + 1] = name end
    end
    pipe:close()
    return out
end

----------------------------------------------------------------------------
-- lfs, when it is there (it is not, in the client or in a bare LuaJIT)
----------------------------------------------------------------------------

local lfs
do
    local ok, found = pcall(require, "lfs")
    if ok and type(found) == "table" then lfs = found end
end

----------------------------------------------------------------------------
-- Where we are, and what can list a folder
----------------------------------------------------------------------------

FS._cwd = nil

function FS.Cwd()
    if FS._cwd then return FS._cwd end
    local lines = Lines(FS.windows and "cd" or "pwd") or {}
    local path = (lines[1] or "?"):gsub("\\", "/")
    FS._cwd = path
    return path
end

-- What the walkers below can use here, for an error message.
function FS.Lister()
    if lfs then return "lfs" end
    if FS.windows then return "dir (Windows)" end
    return "find (Unix)"
end

local function ToSlash(path)
    path = (path or ""):gsub("\\", "/")
    local cwd = FS.Cwd()
    if cwd ~= "?" and cwd ~= "" then
        local prefix = "^" .. Literal(cwd) .. "/"
        if path:match(prefix) then path = path:gsub(prefix, "") end
    end
    return path
end

function FS.IsDir(path)
    if lfs then
        local attrs = lfs.attributes(path)
        return attrs ~= nil and attrs.mode == "directory"
    end
    local cmd
    if FS.windows then
        cmd = 'if exist ' .. Quoted(path:gsub("[/\\]+$", "") .. "\\*") .. ' (echo yes) else (echo no)'
    else
        cmd = 'test -d ' .. Quoted(path) .. ' && echo yes || echo no'
    end
    local lines = Lines(cmd)
    return lines ~= nil and (lines[1] or ""):match("^yes") ~= nil
end

local function CannotList(dir, what)
    return (("tests/fs.lua: cannot list %s%s (no such folder): the suite has to run from "
        .. "the addon's folder, and it is in %q, listing with %s")
        :format(dir, what and (" (" .. what .. ")") or "", FS.Cwd(), FS.Lister()))
end

----------------------------------------------------------------------------
-- One folder
----------------------------------------------------------------------------

-- "any" (the default), "file" or "dir": the names directly inside dir,
-- sorted. dir itself is not in the list.
function FS.List(dir, what)
    what = what or "any"
    local out = {}
    if lfs then
        for name in lfs.dir(dir) do
            if name ~= "." and name ~= ".." then
                local mode = (lfs.attributes(dir .. "/" .. name) or {}).mode
                if what == "any"
                    or (what == "file" and mode == "file")
                    or (what == "dir" and mode == "directory") then
                    out[#out + 1] = name
                end
            end
        end
    else
        local cmd
        if FS.windows then
            local flag = what == "file" and " /a-d" or what == "dir" and " /ad" or ""
            cmd = "dir /b" .. flag .. " " .. Quoted(dir) .. QUIET
        else
            local flag = what == "file" and " -type f" or what == "dir" and " -type d" or ""
            cmd = "find " .. Quoted(dir) .. " -mindepth 1 -maxdepth 1" .. flag .. QUIET
        end
        local lines = Lines(cmd)
        for _, line in ipairs(lines or {}) do
            -- find prints the path it was given; dir /b prints the name.
            local name = ToSlash(line)
            local base = dir:gsub("\\", "/"):gsub("/+$", "")
            if base ~= "" and base ~= "." and name:sub(1, #base + 1) == base .. "/" then
                name = name:sub(#base + 2)
            end
            if name ~= "" and name ~= "." and name ~= ".." then out[#out + 1] = name end
        end
    end
    table.sort(out)
    if #out == 0 and not FS.IsDir(dir) then error(CannotList(dir), 3) end
    return out
end

-- The files directly inside dir, sorted.
function FS.Files(dir) return FS.List(dir, "file") end

-- The folders directly inside dir, sorted.
function FS.Dirs(dir) return FS.List(dir, "dir") end

----------------------------------------------------------------------------
-- Everywhere below
----------------------------------------------------------------------------

-- Every file at any depth below dir, as paths that name it from here
-- ("Core/Bridges/Questie.lua"), sorted: what io.open wants.
function FS.Walk(dir)
    local out = {}
    if lfs then
        local function Down(path, prefix)
            local names = {}
            for name in lfs.dir(path) do
                if name ~= "." and name ~= ".." then names[#names + 1] = name end
            end
            table.sort(names)
            for _, name in ipairs(names) do
                local full = path .. "/" .. name
                local mode = (lfs.attributes(full) or {}).mode
                if mode == "directory" then
                    Down(full, prefix .. name .. "/")
                elseif mode == "file" then
                    out[#out + 1] = prefix .. name
                end
            end
        end
        Down(dir, dir == "." and "" or (dir .. "/"))
    else
        local cmd
        if FS.windows then
            cmd = "dir /s /b /a-d " .. Quoted(dir) .. QUIET
        else
            cmd = "find " .. Quoted(dir) .. " -type f" .. QUIET
        end
        local base = ToSlash(dir):gsub("/+$", "")
        for _, line in ipairs(Lines(cmd) or {}) do
            local path = ToSlash(line)
            if base == "." then
                path = path:gsub("^%./", "")
            elseif base ~= "" and path:sub(1, #base) ~= base then
                -- dir prints the path it was given; a host that answers in
                -- absolute paths has already had the cwd taken off.
                path = base .. "/" .. path
            end
            out[#out + 1] = path
        end
    end
    table.sort(out)
    if #out == 0 and not FS.IsDir(dir) then error(CannotList(dir), 3) end
    return out
end

-- Every folder at any depth below dir (dir itself not one), named from here.
function FS.WalkDirs(dir)
    local out, seen = {}, {}
    local base = dir:gsub("\\", "/"):gsub("/+$", "")
    for _, path in ipairs(FS.Walk(dir)) do
        if base ~= "." and base ~= "" then
            local prefix = "^" .. Literal(base) .. "/"
            path = path:gsub(prefix, "")
        end
        local folder = path:match("^(.*)/[^/]*$")
        while folder and folder ~= "" and not seen[folder] do
            seen[folder] = true
            out[#out + 1] = folder
            folder = folder:match("^(.*)/[^/]*$")
        end
    end
    table.sort(out)
    return out
end

-- Every file below dir whose name matches pattern (a Lua pattern on the
-- name, "%.lua$" by default), as paths from dir down.
function FS.Find(dir, pattern)
    pattern = pattern or "%.lua$"
    local out = {}
    for _, path in ipairs(FS.Walk(dir)) do
        local name = path:match("([^/]*)$")
        if name and name:match(pattern) then out[#out + 1] = path end
    end
    return out
end

-- FS.Find over several folders, merged and sorted.
function FS.FindIn(dirs, pattern)
    local out = {}
    for _, dir in ipairs(dirs) do
        for _, path in ipairs(FS.Find(dir, pattern)) do out[#out + 1] = path end
    end
    table.sort(out)
    return out
end

----------------------------------------------------------------------------
-- The addon's own manifest, for a host with no lister at all
----------------------------------------------------------------------------

-- The TOC at the top of the addon: its name is the folder's (the client
-- looks for <folder>/<folder>.toc), and it lists every file the client
-- loads, in order. Its .lua lines are the manifest the tests fall back to.
function FS.Toc(root)
    root = root or "."
    local found = {}
    for _, name in ipairs(FS.Files(root)) do
        if name:match("%.toc$") then found[#found + 1] = name end
    end
    if #found ~= 1 then
        error(("tests/fs.lua: expected one .toc in %s, found %d (%s)")
            :format(root, #found, table.concat(found, ", ")), 2)
    end
    return found[1]
end

-- The .lua paths a TOC names, in its order.
function FS.Manifest(root)
    root = root or "."
    local out = {}
    local f = assert(io.open(root .. "/" .. FS.Toc(root), "r"))
    for line in f:lines() do
        -- The 3.3.5 client resolves backslash entries only, so the TOC
        -- spells them that way; the suite works in "/".
        local path = line:match("^([%w_%-\\/]+%.lua)%s*$")
        if path then out[#out + 1] = (path:gsub("\\", "/")) end
    end
    f:close()
    return out
end

-- The file's text; the error names the path.
function FS.Read(path)
    local f, err = io.open(path, "r")
    if not f then error("tests/fs.lua: cannot read " .. path .. ": " .. tostring(err), 2) end
    local text = f:read("*a")
    f:close()
    return text
end

return FS
