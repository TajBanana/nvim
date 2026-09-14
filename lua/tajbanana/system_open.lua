-- Open URLs and files with the desktop handler, including from Fedora Toolbx.
local M = {}

local function notify_failure(cmd, result)
    if result.code == 0 then return end
    local detail = vim.trim((result.stderr or "") ~= "" and result.stderr or (result.stdout or ""))
    vim.schedule(function()
        vim.notify(
            ("%s failed (exit %d)%s"):format(cmd[1], result.code, detail ~= "" and (": " .. detail) or ""),
            vim.log.levels.ERROR
        )
    end)
end

function M.open(target)
    local plat = require("tajbanana.platform")
    local is_uri = target:match("^%a[%w+.-]*:") ~= nil

    -- WSL is also Linux, so handle it before the Linux launchers. explorer.exe
    -- returns 1 even after a successful handoff, hence there is no exit check.
    if plat.wsl then
        if vim.fn.executable("explorer.exe") ~= 1 then
            vim.notify("explorer.exe is not on PATH (WSL interop disabled?)", vim.log.levels.ERROR)
            return
        end
        if not is_uri then
            local linux_path = target
            local converted = vim.system({ "wslpath", "-w", target }, { text = true }):wait()
            target = vim.trim(converted.stdout or "")
            if converted.code ~= 0 or target == "" then
                vim.notify("wslpath failed for: " .. linux_path, vim.log.levels.ERROR)
                return
            end
        end
        vim.system({ "explorer.exe", target }, { detach = true })
        return
    end

    local cmd
    -- Toolbx shares the home directory but not the host's /usr desktop files.
    -- Cross the host boundary so xdg-open can see rpm-ostree-installed apps.
    if plat.linux and vim.uv.fs_stat("/run/.toolboxenv") and vim.fn.executable("flatpak-spawn") == 1 then
        cmd = { "flatpak-spawn", "--host", "xdg-open" }
    else
        cmd = plat.pick({
            mac = { "open" },
            windows = { "cmd.exe", "/c", "start", "" },
            linux = { "xdg-open" },
        })
    end

    if not cmd then
        vim.notify("No opener known for platform: " .. plat.name, vim.log.levels.ERROR)
        return
    end
    if vim.fn.executable(cmd[1]) ~= 1 then
        vim.notify("No opener: `" .. cmd[1] .. "` is not executable", vim.log.levels.ERROR)
        return
    end

    local argv = vim.list_extend(vim.deepcopy(cmd), { target })
    vim.system(argv, { text = true }, function(result) notify_failure(cmd, result) end)
end

return M
