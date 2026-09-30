-- Repo-wide diagnostics (<leader>xr).
--
-- LSP servers only diagnose files that are open, so <leader>xx / <leader>xb can
-- never show problems in files you have not visited. This runs a real
-- project-wide linter/compiler, loads the results into the quickfix list, and
-- browses them in Telescope (same left/right layout).
--
-- Which project: the NEAREST ancestor of the current file (bounded by the git
-- root) that carries a detector's marker, so in a monorepo the sub-project the
-- file belongs to is linted -- a root-only check found nothing there. One tool
-- runs per invocation: the detector with the deepest marker wins, detector
-- order breaks ties. Gradle/Kotlin is intentionally excluded -- a full compile
-- is far too slow to bind to a keypress. Add a detector below to support
-- another stack.

local M = {}

local function exists(path)
    return vim.uv.fs_stat(path) ~= nil
end

-- Absolute path on any OS: "/..." or a Windows drive ("C:\..." or "C:/...").
local function is_abs(p)
    return p:sub(1, 1) == "/" or p:match("^%a:[/\\]") ~= nil
end

-- `path` is `dir` itself or inside it. vim.fs.relpath normalises separators
-- on Windows, so this should also hold for fs_realpath's backslashes there,
-- where a plain `startswith(path, dir .. "/")` could not (reasoned from the
-- vim.fs docs; only the POSIX behaviour is exercised by the tests).
local function inside_dir(path, dir)
    return path == dir or vim.fs.relpath(dir, path) ~= nil
end

local function missing(tool, how)
    return nil, ("'%s' not found on PATH (%s)"):format(tool, how or "install it via :Mason")
end

-- JSON null must decode to nil: the default vim.NIL is truthy userdata, and
-- eslint emits `"ruleId": null` for parse errors (concatenating it crashed).
local function decode(text)
    local ok, results = pcall(vim.json.decode, text or "", { luanil = { object = true, array = true } })
    if ok and type(results) == "table" then
        return results
    end
end

-- ESLint: -f json exists in every ESLint version. The previous `-f unix` was
-- removed from core in ESLint 9 (moved to a separate npm package), so it failed
-- to load on any current project.
local function parse_eslint(out)
    local results = decode(out.stdout)
    if not results then
        return nil
    end
    local items = {}
    for _, file in ipairs(results) do
        for _, m in ipairs(file.messages or {}) do
            items[#items + 1] = {
                filename = file.filePath,
                lnum = m.line or 1,
                col = m.column or 1,
                type = m.severity == 2 and "E" or "W",
                text = m.message .. (m.ruleId and (" [" .. m.ruleId .. "]") or ""),
            }
        end
    end
    return items
end

-- node_modules/.bin/<name> from `root` up to `limit` (the git root). npm/yarn
-- workspaces -- and pnpm when the tool is only a root devDependency -- hoist the
-- binary to the repo root, not the sub-package the nearest package.json names.
-- The first `dir/rel` from `root` up to `limit` (the git root; nil = root
-- only) for which `accept(path)` holds (default: it exists). Returns the path
-- and the directory it was found in.
local function find_up(root, limit, rel, accept)
    accept = accept or exists
    local dir = root
    while dir do
        local path = dir .. "/" .. rel
        if accept(path) then
            return path, dir
        end
        local parent = vim.fs.dirname(dir)
        if not limit or dir == limit or parent == dir then
            return nil
        end
        dir = parent
    end
end

local function find_bin(root, limit, name)
    return (find_up(root, limit, "node_modules/.bin/" .. name))
end

-- tsc --pretty false: `path(line,col): error TS2322: msg`, paths relative to
-- tsc's cwd, a chained reason on indented continuation lines ("  Types of
-- property 'a' are incompatible."), config errors with no position ("error
-- TS5083: Cannot read file …" -- a broken `extends`), and with --listFiles the
-- absolute path of every file the project compiled. `opts`:
--   tsconfig   the config tsc ran (-p); position-less errors land on it;
--   inherited  true when that config sits ABOVE the package: tsc then checks
--              the parent project, so its entries are kept only inside the
--              package (config files excepted);
--   file       the buffer's file.
-- Returns items, problem, explained:
--   problem    the checked project does not cover the buffer's file (or, for
--              a non-source buffer, any file of the package) -- reported
--              instead of "no issues" (it used to be a false all-clear for a
--              package tsc never looked at, and for a solution-style config
--              whose `references` only `tsc -b` checks);
--   explained  tsc reported diagnostics, so a non-zero exit with no entries
--              left (all in other packages) is not a tool failure.
-- Nothing listed and nothing reported with a non-zero exit means tsc did not
-- really run (node missing, a crash): nil, so the caller reports the failure.
local function parse_tsc(out, root, opts)
    opts = opts or {}
    local items, current, listed, any_listed, reported = {}, nil, {}, false, false
    -- --listFiles paths come on stdout only: a failing wrapper's stderr
    -- ("…/.bin/tsc: line 2: /x/node: No such file") also starts with "/".
    local stdout_lines = {}
    for line in (out.stdout or ""):gmatch("[^\n]+") do
        stdout_lines[line] = true
    end
    local text = (out.stdout or "") .. "\n" .. (out.stderr or "")
    for line in text:gmatch("[^\n]+") do
        local file, lnum, col, sev, code, msg = line:match("^(.-)%((%d+),(%d+)%): (%a+) (TS%d+): (.*)$")
        local gsev, gcode, gmsg = line:match("^(%a+) (TS%d+): (.*)$")
        if file then
            reported = true
            file = vim.fs.normalize(is_abs(file) and file or (root .. "/" .. file))
            current = nil
            local config = vim.fs.basename(file):match("^tsconfig.*%.json$") ~= nil
            if not opts.inherited or config or inside_dir(file, root) then
                current = {
                    filename = file, lnum = tonumber(lnum), col = tonumber(col),
                    type = sev == "warning" and "W" or "E", text = code .. ": " .. msg,
                }
                items[#items + 1] = current
            end
        elseif gsev and opts.tsconfig then
            reported = true
            current = {
                filename = opts.tsconfig, lnum = 1, col = 1,
                type = gsev == "warning" and "W" or "E", text = gcode .. ": " .. gmsg,
            }
            items[#items + 1] = current
        elseif current and line:match("^%s") then
            current.text = current.text .. " " .. vim.trim(line)
        else
            current = nil
            if is_abs(line) and stdout_lines[line] then
                any_listed = true
                listed[vim.fs.normalize(line)] = true
            end
        end
    end
    if not any_listed and not reported then
        if (out.code or 0) ~= 0 then
            return nil
        end
    end
    local name = opts.tsconfig and vim.fn.fnamemodify(opts.tsconfig, ":~") or "the tsconfig.json"
    local target = opts.file and opts.file:match("%.[cm]?[jt]sx?$") and inside_dir(opts.file, root) and opts.file
    local covered
    if target then
        covered = listed[vim.fs.normalize(target)] == true
    else
        covered = false
        for path in pairs(listed) do
            if inside_dir(path, root) and not path:find("/node_modules/", 1, true) then
                covered = true
                break
            end
        end
    end
    local problem
    if not covered and not (reported and #items > 0 and not any_listed) then
        local what = target and vim.fn.fnamemodify(target, ":~:.") or ("any file of " .. vim.fn.fnamemodify(root, ":~"))
        problem = ("%s does not include %s, so it was not type-checked"):format(name, what)
        if not any_listed then
            problem = ("%s compiles no files%s"):format(name,
                opts.solution and " (a solution-style config: its `references` are only checked by `tsc -b`)" or "")
        end
    end
    return items, problem, reported
end

-- JS/TS: prefer ESLint (lint issues -- what "lint" usually means) via the
-- project's local binary; fall back to tsc (type errors). Local node_modules
-- binaries exec node, which nvim has on PATH via the env.lua nvm fix -- unlike
-- the interactive-shell `npx`, which is an nvm lazy-load stub that fails here.
-- ESLint runs with cwd = the sub-package, so only that package is linted (its
-- config is found by ESLint's own upward lookup); for tsc see parse_tsc.
local function js_detector(root, limit, file)
    local eslint = find_bin(root, limit, "eslint")
    if eslint then
        return { name = "eslint", cmd = { eslint, ".", "-f", "json" }, parse = parse_eslint }
    end
    local tsc = find_bin(root, limit, "tsc")
    if not tsc then
        return nil, "node_modules/.bin eslint or tsc not found (run npm/pnpm install)"
    end
    -- With no tsconfig.json at all tsc prints its help and "fails" with
    -- nothing to parse (reachable since tsc is found hoisted at the workspace
    -- root). So require one at or above the package, up to the git root.
    local tsconfig, dir = find_up(root, limit, "tsconfig.json")
    if not tsconfig then
        return nil, "no ESLint here, and no tsconfig.json at or above " .. vim.fn.fnamemodify(root, ":~") .. " for tsc"
    end
    local fd = io.open(tsconfig, "r")
    local config_text = fd and fd:read("*a") or ""
    if fd then
        fd:close()
    end
    local opts = {
        tsconfig = tsconfig,
        inherited = dir ~= root,
        file = file,
        solution = config_text:find('"references"', 1, true) ~= nil,
    }
    return {
        name = "tsc",
        cmd = { tsc, "--noEmit", "--pretty", "false", "--listFiles", "-p", tsconfig },
        parse = function(out, r)
            return parse_tsc(out, r, opts)
        end,
    }
end

-- helm lint prints `[SEVERITY] <path>: <message>`, sometimes followed by
-- indented continuation lines that carry the actual reason. The <path> is often
-- NOT the file at fault:
--   * template errors name the directory (`templates/: ...`) and put the real
--     location in the message, prefixed with the chart's NAME (from Chart.yaml,
--     not its directory), which is stripped. Shapes seen from real helm runs:
--       v3/v4 parse:  `parse error at (mychart/templates/x.yaml:3): ...`
--       v4 execution: `mychart/templates/x.yaml:1:13` + `  executing ...` lines
--       v3 execution: `template: mychart/templates/x.yaml:3:5: executing ...`
--   * chart-metadata errors give the chart dir as an absolute path, and a broken
--     Chart.yaml puts its `yaml: line N` on a continuation line;
--   * `unable to parse YAML ... yaml: line N` on a template counts lines of the
--     RENDERED output, not of the source -- the entry says so.
-- Directories are not openable, so they map to that chart's Chart.yaml. INFO
-- lines (e.g. "icon is recommended") and their continuations are dropped.
-- The chart name declared in dir/Chart.yaml.
local function chart_name(dir)
    local fd = io.open(dir .. "/Chart.yaml", "r")
    if not fd then
        return nil
    end
    for line in fd:lines() do
        local name = line:match("^name:%s*[\"']?([^\"'%s#]+)")
        if name then
            fd:close()
            return name
        end
    end
    fd:close()
end

-- `rel` inside chart dir `dir`. Helm names a sub-chart in paths by its
-- Chart.yaml NAME (charts/<name>/...), which need not be its directory name, so
-- each charts/<name>/ step is looked up. Returns nil, <name> for a sub-chart
-- that is not a directory (packaged as charts/<name>-x.y.z.tgz).
local function chart_path(dir, rel)
    local name, tail = rel:match("^charts/([^/]+)/(.+)$")
    if not name then
        return dir .. "/" .. rel
    end
    local sub = dir .. "/charts/" .. name
    if chart_name(sub) ~= name then
        sub = nil
        for entry, kind in vim.fs.dir(dir .. "/charts") do
            if kind == "directory" and chart_name(dir .. "/charts/" .. entry) == name then
                sub = dir .. "/charts/" .. entry
                break
            end
        end
    end
    if not sub then
        return nil, name
    end
    return chart_path(sub, tail)
end

-- Location forms inside a helm message, most specific first; each captures
-- path, line and an optional column. Paths may contain spaces.
local HELM_LOCATIONS = {
    "%(([^()]-%.%w+):(%d+):?(%d*)%)", -- parse error at (c/templates/x.yaml:3) / execution error at (…:3:5)
    "^([^:%s][^:]-%.%w+):(%d+):?(%d*)", -- v4 execution: c/templates/x.yaml:1:13
    "template: ([^:]-%.%w+):(%d+):?(%d*)", -- v3 execution: template: c/templates/x.yaml:3:5: …
}

-- file, lnum, col[, note] for a message that names its own location.
local function helm_location(msg, root)
    local ref, lnum, col
    for _, pat in ipairs(HELM_LOCATIONS) do
        ref, lnum, col = msg:match(pat)
        if ref then
            break
        end
    end
    if not ref then
        return nil
    end
    lnum, col = tonumber(lnum), tonumber(col) or 1
    if is_abs(ref) then
        return ref, lnum, col
    end
    -- The first segment is the chart's name, not a directory.
    local file, packaged = chart_path(root, ref:match("^[^/]+/(.+)$") or ref)
    if packaged then
        return root .. "/Chart.yaml", 1, 1, " (in packaged sub-chart " .. packaged .. ")"
    end
    if file and exists(file) then
        return file, lnum, col
    end
    if exists(root .. "/" .. ref) then
        return root .. "/" .. ref, lnum, col
    end
end

local function parse_helm(out, root)
    local items, seen = {}, {}
    local current -- the item continuation lines belong to (nil after INFO)
    local function finish(item)
        local file, lnum, col, note = helm_location(item.text, root)
        local secondary = false
        if not file then
            local path = (vim.trim(item.path):gsub("/+$", ""))
            -- "templates/: cannot load values.yaml: …" (and the bare ": unable
            -- to load chart" that follows) re-report a broken chart file.
            local loads = item.text:match("cannot load (%S+%.ya?ml)")
            -- "templates/: values don't meet the specifications of the
            -- schema(s)…" re-reports the values.yaml entry (helm 4.3).
            if not loads and item.text:find("don't meet the specifications of the schema", 1, true) then
                loads = "values.yaml"
                -- The detail names the failing chart ("other: - at '/port': …").
                -- For a SUB-chart the entry used to land on the parent's
                -- values.yaml; it goes to the sub-chart's own values.yaml unless
                -- the parent's values.yaml sets that sub-chart's key (an
                -- override -- then the parent file is the likely culprit).
                local failing = item.text:match("following chart%(s%):%s*([^:%s]+):")
                if failing and failing ~= chart_name(root) then
                    local sub = chart_path(root, "charts/" .. failing .. "/values.yaml")
                    local fd = io.open(root .. "/values.yaml", "r")
                    local parent = fd and fd:read("*a") or ""
                    if fd then
                        fd:close()
                    end
                    local key = "\n" .. parent
                    if sub and exists(sub) and not key:find("\n" .. vim.pesc(failing) .. ":", 1) then
                        loads = sub
                    end
                end
            end
            if loads and (path == "" or path == "templates") then
                -- In a sub-chart, helm prefixes "error unpacking subchart <dir>
                -- in <parent>: " (nested once per level; <dir> is the directory
                -- under charts/, not the chart name). Without following it the
                -- entry landed on the PARENT chart's values.yaml / Chart.yaml.
                local sub = ""
                for dir in item.text:gmatch("error unpacking subchart (%S+) in ") do
                    sub = sub .. "charts/" .. dir .. "/"
                end
                path, secondary = is_abs(loads) and loads or (sub .. loads), true
            end
            file = path == "" and root or (is_abs(path) and path or (root .. "/" .. path))
            lnum, col = tonumber(item.text:match("line (%d+)")) or 1, 1
            if item.text:find("unable to parse YAML", 1, true) and path:match("^templates/") then
                note = " (line of the rendered template, not the source)"
            end
        end
        local st = vim.uv.fs_stat(file)
        if not st or st.type == "directory" then
            local dir = (st and file) or root
            file = exists(dir .. "/Chart.yaml") and (dir .. "/Chart.yaml") or (root .. "/Chart.yaml")
            -- A line number in the message only means something for Chart.yaml
            -- itself (a metadata YAML error); otherwise it points elsewhere.
            if not item.text:find("Chart.yaml", 1, true) then
                lnum = 1
            end
        end
        local key = file .. ":" .. lnum
        if secondary and seen[key] then
            return -- the same file and line was already reported directly
        end
        seen[key] = true
        items[#items + 1] = {
            filename = file, lnum = lnum or 1, col = col or 1, type = item.type, text = item.text .. (note or ""),
        }
    end
    local pending = {}
    local text = (out.stdout or "") .. "\n" .. (out.stderr or "")
    for line in vim.gsplit(text, "\n", { plain = true }) do
        -- "[SEV] <path>: <msg>" -- split at the first ": " so a ':' inside an
        -- absolute chart path does not cut the path short.
        local sev, path, msg = line:match("^%[(%u+)%]%s+(.-):%s+(.*)$")
        if not sev then
            sev, path, msg = line:match("^%[(%u+)%]%s+(.-):$")
            msg = msg or ""
        end
        if sev then
            current = nil
            if sev ~= "INFO" then
                current = { path = path, text = msg, head = msg, lines = {}, type = sev == "ERROR" and "E" or "W" }
                pending[#pending + 1] = current
            end
        elseif current and line:match("^%s") and vim.trim(line) ~= "" then
            current.text = current.text .. " " .. vim.trim(line)
        elseif current and line ~= "" and not line:match("^==> ") and not line:match("^Error: ") then
            -- helm 4.3 prints a schema failure's detail on UNINDENTED lines up
            -- to the next blank line ("c:" / "- at '/replicaCount': got …").
            current.text = current.text .. " " .. line
            current.lines[#current.lines + 1] = line
        else
            current = nil
        end
    end
    -- A schema failure names each failing chart on its own line ("my.chart:",
    -- "other:"), each followed by its details: one entry per chart. As a
    -- single entry only the first chart was mapped, and a sub-chart's failure
    -- disappeared when the parent chart failed too.
    local function per_chart(item)
        if not item.head:find("don't meet the specifications of the schema", 1, true) then
            return { item }
        end
        local parts, part = {}, nil
        for _, line in ipairs(item.lines) do
            local chart = line:match("^([^%s:]+):$")
            if chart then
                part = { path = item.path, type = item.type, text = item.head .. " " .. chart .. ":" }
                parts[#parts + 1] = part
            elseif part then
                part.text = part.text .. " " .. line
            end
        end
        return #parts > 0 and parts or { item }
    end
    for _, item in ipairs(pending) do
        for _, part in ipairs(per_chart(item)) do
            finish(part)
        end
    end
    return items
end

-- hadolint JSON: [{ file, line, column, level, code, message }].
local function parse_hadolint(out, root)
    local results = decode(out.stdout)
    if not results then
        return nil
    end
    local items = {}
    for _, r in ipairs(results) do
        items[#items + 1] = {
            filename = is_abs(r.file) and r.file or (root .. "/" .. r.file),
            lnum = r.line or 1,
            col = r.column or 1,
            type = r.level == "error" and "E" or "W",
            -- Parse-error messages carry newlines ("unexpected 'F'\nexpecting …").
            text = r.code .. ": " .. vim.trim((r.message or ""):gsub("%s*\n%s*", " ")),
        }
    end
    return items
end

-- Dockerfile, Dockerfile.<variant>, <name>.Dockerfile -- but not the
-- per-Dockerfile ignore file (Dockerfile.dockerignore), which is not a Dockerfile.
-- Suffixes that make a Dockerfile.<x> something else (docs, templates, backups).
local NOT_DOCKERFILE = {
    dockerignore = true, md = true, txt = true, j2 = true, jinja = true, jinja2 = true, template = true,
    tmpl = true, tpl = true, bak = true, orig = true, rej = true, swp = true, sample = true, example = true,
}
local function is_dockerfile(name)
    local ext = name:match("%.([%w]+)$")
    if ext and NOT_DOCKERFILE[ext:lower()] then
        return false
    end
    return name == "Dockerfile" or name:match("^Dockerfile%.") ~= nil or name:match("%.[Dd]ockerfile$") ~= nil
end

-- Dockerfiles under root: tracked files when root is in git (skips
-- node_modules and friends for free), else a filesystem walk bounded by DEPTH
-- (not just by result count -- an unbounded walk of a big directory froze the
-- editor). Tracked files deleted from the working tree are skipped -- one
-- missing path aborts the whole hadolint run. `current` (the buffer's file) is
-- always included when it is a Dockerfile under root, even if gitignored.
local function dockerfiles(root, current)
    local files = {}
    -- -z: without it git C-quotes non-ASCII paths ("caf\303\251/Dockerfile"),
    -- which then matched nothing. A conflicted file is listed once per stage,
    -- hence the dedupe.
    local ok, res = pcall(function()
        return vim.system({ "git", "-C", root, "ls-files", "-z", "--cached", "--others", "--exclude-standard" }):wait()
    end)
    if ok and res.code == 0 then
        local seen = {}
        for f in (res.stdout or ""):gmatch("[^%z]+") do
            if not seen[f] and is_dockerfile(vim.fs.basename(f)) and exists(root .. "/" .. f) then
                seen[f] = true
                files[#files + 1] = f
            end
        end
    else
        -- vim.fs.dir passes the RELATIVE path (sub/node_modules), so test its
        -- last component -- testing the whole path only skipped top-level ones.
        local skip = function(dir)
            local base = vim.fs.basename(dir)
            return base ~= "node_modules" and not base:match("^%.")
        end
        for f, kind in vim.fs.dir(root, { depth = 4, skip = skip }) do
            if kind == "file" and is_dockerfile(vim.fs.basename(f)) then
                files[#files + 1] = f
                if #files >= 200 then
                    break
                end
            end
        end
    end
    -- Only when it exists on disk: an unsaved new Dockerfile, or a deleted one
    -- still open, used to be passed anyway and aborted the whole hadolint run.
    local rel = current and is_dockerfile(vim.fs.basename(current)) and exists(current)
        and vim.fs.relpath(root, current)
    if rel and not vim.tbl_contains(files, rel) then
        files[#files + 1] = rel
    end
    return files
end

-- golangci-lint's major version, read once per session ("... has version 2.14.0").
local golangci_version
local function golangci_major()
    if golangci_version == nil then
        local ok, out = pcall(vim.fn.system, { "golangci-lint", "--version" })
        golangci_version = ok and tonumber(tostring(out):match("version v?(%d+)")) or 0
    end
    return golangci_version
end

-- Ordered detectors (order breaks depth ties). `markers` is passed to
-- vim.fs.root; `make(root, limit)` (limit = the git root, or nil) returns a
-- spec { name, cmd, efm | parse } or (nil, reason). A cmd[1] containing "/" is
-- a local binary path; otherwise it is a PATH tool (Mason's bin dir is on
-- nvim's PATH).
local detectors = {
    {
        markers = { "go.mod" },
        make = function()
            -- golangci-lint (a superset of vet) when installed, else go vet.
            if vim.fn.executable("golangci-lint") == 1 then
                local cmd = { "golangci-lint", "run" }
                -- v2 prints paths relative to the CONFIG file's directory, so
                -- with .golangci.yml at the repo root and go.mod in a
                -- subdirectory they resolved against the wrong base. Ask for
                -- absolute paths (v2-only flag; v1 is relative to the cwd).
                if golangci_major() >= 2 then
                    cmd[#cmd + 1] = "--path-mode=abs"
                end
                cmd[#cmd + 1] = "./..."
                -- %-G drops its logfmt diagnostics ("level=error msg=..."),
                -- which otherwise became a junk entry that also hid the failure
                -- (no entries + non-zero exit reports the real stderr instead).
                return { name = "golangci-lint", cmd = cmd, efm = "%-Glevel=%.%#,%f:%l:%c: %m" }
            end
            -- Type errors come out as `vet: path:line:col: msg`; without the
            -- prefixed pattern the filename became "vet: path".
            return { name = "go vet", cmd = { "go", "vet", "./..." }, efm = "vet: %f:%l:%c: %m,%f:%l:%c: %m" }
        end,
    },
    {
        markers = { "Cargo.toml" },
        make = function(root, limit)
            -- cargo prints paths relative to the WORKSPACE root, which for a
            -- member crate is an ancestor of the (nearest-marker) project root:
            -- resolve entries against it (`base`), while still checking only
            -- the member (cwd = root). Without this they pointed at files that
            -- do not exist.
            local _, ws = find_up(root, limit, "Cargo.toml", function(path)
                local fd = io.open(path, "r")
                if not fd then
                    return false
                end
                local text = fd:read("*a") or ""
                fd:close()
                return text:find("%[workspace%]") ~= nil
            end)
            return {
                name = "cargo check",
                cmd = { "cargo", "check", "--message-format=short", "-q" },
                efm = "%f:%l:%c: %m",
                base = ws or root,
            }
        end,
    },
    {
        markers = { "pyproject.toml", "requirements.txt" },
        make = function()
            -- --color never: an inherited FORCE_COLOR made the output unparseable.
            return {
                name = "ruff",
                cmd = { "ruff", "check", "--output-format=concise", "--color", "never", "." },
                efm = "%f:%l:%c: %m",
            }
        end,
    },
    { markers = { "package.json", "tsconfig.json" }, make = js_detector },
    {
        markers = { "Chart.yaml" },
        make = function()
            if vim.fn.executable("helm") ~= 1 then
                return missing("helm", "helm is not in Mason: install it with your package manager (e.g. Homebrew)")
            end
            return { name = "helm lint", cmd = { "helm", "lint", "." }, parse = parse_helm }
        end,
    },
    {
        -- Only with an explicit yamllint config: yamllint's defaults (80-col
        -- lines, document-start markers, ...) would flood an unconfigured repo.
        markers = { ".yamllint", ".yamllint.yaml", ".yamllint.yml" },
        make = function()
            if vim.fn.executable("yamllint") ~= 1 then
                return missing("yamllint")
            end
            return {
                name = "yamllint",
                cmd = { "yamllint", "-f", "parsable", "." },
                efm = "%f:%l:%c: [%t%*[a-z]] %m,%f:%l:%c: %m",
            }
        end,
    },
    {
        markers = function(name)
            return is_dockerfile(name)
        end,
        make = function(root, _, file)
            if vim.fn.executable("hadolint") ~= 1 then
                return missing("hadolint")
            end
            local files = dockerfiles(root, file)
            if #files == 0 then
                return nil, "no Dockerfile found"
            end
            -- "--" so a file named like an option (-foo.Dockerfile) stays a file.
            return {
                name = "hadolint",
                cmd = vim.list_extend({ "hadolint", "-f", "json", "--no-fail", "--" }, files),
                parse = parse_hadolint,
            }
        end,
    },
}

local function realpath(p)
    return vim.uv.fs_realpath(p) or p
end

-- Nearest marked project for the current file, never above the git root (a
-- stray ~/package.json must not hijack every repo). Outside git only the
-- file's own directory counts: an unbounded search let a stray marker anywhere
-- above win (ruff over a whole temp tree) and walked to "/".
local function detect()
    local file = vim.api.nvim_buf_get_name(0)
    local start = (file ~= "" and vim.fs.dirname(file)) or vim.fn.getcwd()
    -- A new file in a directory that does not exist yet: use its nearest
    -- existing ancestor, not nvim's cwd (which linted an unrelated project).
    while not exists(start) do
        local parent = vim.fs.dirname(start)
        if parent == start then
            break
        end
        start = parent
    end
    local top = require("tajbanana.gitutil").toplevel(start)
    local limit = realpath(top or start)
    local best, best_root
    for _, det in ipairs(detectors) do
        -- A nested list makes the markers EQUAL priority, so the nearest of any
        -- of them wins. A flat list is a priority order to vim.fs.root: a
        -- repo-root package.json beat a nearer tsconfig.json, and a
        -- pyproject.toml above the git root hid svc/requirements.txt entirely.
        local markers = type(det.markers) == "table" and { det.markers } or det.markers
        local root = vim.fs.root(start, markers)
        if root then
            root = realpath(root)
            local inside = not limit or inside_dir(root, limit)
            if inside and (not best_root or #root > #best_root) then
                best, best_root = det, root
            end
        end
    end
    if not best then
        return nil, nil, "no known linter here (go/cargo/ruff/eslint/tsc/helm/yamllint/hadolint)"
    end
    local spec, reason = best.make(best_root, limit, file ~= "" and realpath(file) or nil)
    return spec, best_root, reason
end

-- Exposed for testing.
M._detect = detect
M._parse = { eslint = parse_eslint, helm = parse_helm, hadolint = parse_hadolint, tsc = parse_tsc }

-- errorformat path: a leading %D "Entering dir" line makes the tool's relative
-- paths resolve against <root> regardless of nvim's cwd (the make/quickfix
-- directory-tracking trick). Returns only real file entries.
local function efm_items(out, root, efm)
    local lines = { "Entering dir '" .. root .. "'" }
    -- Explicit "\n" between the streams: an unterminated final stdout line
    -- would otherwise be glued to the first stderr line, so that diagnostic
    -- fails the errorformat match and is silently dropped. trimempty discards
    -- the extra blank when stdout already ends in a newline.
    vim.list_extend(lines, vim.split((out.stdout or "") .. "\n" .. (out.stderr or ""), "\n", { trimempty = true }))
    local parsed = vim.fn.getqflist({ lines = lines, efm = "%DEntering dir '%f'," .. efm }).items
    -- The %D marker and summary lines parse into entries with no buffer
    -- (bufnr 0); left in the list they make Telescope's open action fail with
    -- E939 (buffer 0).
    local items = vim.tbl_filter(function(e)
        return e.valid == 1 and e.bufnr > 0
    end, parsed)
    -- A severity for every entry: a %t capture (yamllint's [error]/[warning]),
    -- else an "error…"/"warning…" message prefix (cargo), else E -- the
    -- remaining tools (golangci-lint, go vet, ruff) print none, and each of
    -- their findings fails the tool's exit code. Entries used to have none.
    for _, e in ipairs(items) do
        local t = (e.type or ""):upper()
        if t == "" then
            t = e.text:match("^%s*warning") and "W" or "E"
        end
        e.type = t
    end
    return items
end

M._efm_items = efm_items -- exposed for testing

-- The run in flight ({ name, root }), if any: a second <leader>xr while one
-- runs used to start another job, and whichever finished last replaced the
-- quickfix list -- a slower, older run could overwrite a newer one.
local running

function M.run()
    if running then
        vim.notify(("repo lint: %s is still running in %s"):format(running.name, vim.fn.fnamemodify(running.root, ":~")),
            vim.log.levels.WARN)
        return
    end
    local d, root, reason = detect()
    if not d then
        vim.notify("repo lint: " .. (reason or "no known linter here"), vim.log.levels.WARN)
        return
    end
    local prog = d.cmd[1]
    if vim.fn.executable(prog) ~= 1 then
        -- A path cmd (local node_modules/.bin tool) can exist without the
        -- execute bit; spawning it threw a raw EACCES.
        vim.notify(("repo lint: '%s' %s"):format(prog, prog:find("/") and "is not executable" or "not found on PATH"),
            vim.log.levels.ERROR)
        return
    end
    vim.notify(("repo lint: running %s in %s…"):format(d.name, vim.fn.fnamemodify(root, ":~")), vim.log.levels.INFO)
    running = { name = d.name, root = root }
    -- The timeout (10 min) only guarantees a hung tool cannot block
    -- <leader>xr for the rest of the session.
    local ok, err = pcall(vim.system, d.cmd, { cwd = root, text = true, timeout = 600000 }, vim.schedule_wrap(function(out)
        running = nil
        local items, problem, explained
        if d.parse then
            -- A parser may also name a problem (tsc: the project it ran does
            -- not cover this package) -- reported instead of an all-clear.
            items, problem, explained = d.parse(out, root)
        else
            -- Paths resolve against `base` when the tool reports them relative
            -- to somewhere else than its cwd (cargo: the workspace root).
            items = efm_items(out, d.base or root, d.efm)
        end
        if items == nil then
            -- A parser could not read the tool's output (e.g. eslint exited 2
            -- on a config error and printed no JSON).
            items = {}
        end
        vim.fn.setqflist({}, " ", { title = "repo lint: " .. d.name, items = items })
        -- Killed by a signal (a crash, the OOM killer, the timeout below):
        -- vim.system reports that as code 0 + a signal, so the exit-code check
        -- read it as a clean run and said "found no issues". The result is
        -- incomplete whatever was parsed.
        if (out.signal or 0) ~= 0 then
            local why = out.code == 124 and "timed out after 10 minutes" or ("was killed (signal %d)"):format(out.signal)
            vim.notify(("repo lint: %s %s — the result is incomplete, not a clean repo%s"):format(
                d.name, why, #items > 0 and "; showing what it reported before that" or ""), vim.log.levels.ERROR)
            if #items > 0 then
                require("telescope.builtin").quickfix()
            end
            return
        end
        if problem then
            vim.notify("repo lint: " .. d.name .. ": " .. problem, vim.log.levels.WARN)
        end
        -- A problem (the project did not cover this file) replaces the
        -- all-clear -- but never hides a tool failure: a parser returns nil,
        -- not a problem, when the tool did not really run.
        if #items == 0 and problem then
            return
        elseif #items == 0 then
            -- Zero parsed items with a non-zero exit is NOT a clean repo: the
            -- tool crashed, hit a bad config, or produced output we could not
            -- parse (eslint exits 2 on error, 1 on lint hits; go vet / cargo /
            -- ruff exit non-zero when they have findings that should have
            -- parsed). Report the failure instead of a false all-clear.
            if out.code ~= 0 and not explained then
                local detail = vim.trim((out.stderr ~= "" and out.stderr or out.stdout) or "")
                if #detail > 300 then
                    detail = detail:sub(1, 300) .. "…"
                end
                vim.notify(
                    ("repo lint: %s exited %d with no parseable output — likely a tool/config error, not a clean repo%s")
                        :format(d.name, out.code, detail ~= "" and ("\n" .. detail) or ""),
                    vim.log.levels.ERROR
                )
            else
                vim.notify("repo lint: " .. d.name .. " found no issues ✓", vim.log.levels.INFO)
            end
            return
        end
        require("telescope.builtin").quickfix()
    end))
    if not ok then
        running = nil
        vim.notify(("repo lint: could not start %s: %s"):format(d.name, err), vim.log.levels.ERROR)
    end
end

return M
