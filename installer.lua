local APP_NAME = "WOPR 0.1"

-- Files to install (relative to repo root)
local FILES = {
    --"wopr/startup.lua",
    "wopr/main.lua",
    "wopr/chess.lua",
    "wopr/tictactoe.lua"
}

-- Ask user for confirmation
term.clear()
term.setCursorPos(1,1)
print("WARNING: This will")
print("overwrite any existing files.")
write("Do you want to continue? (y/n): ")
local choice = read()
if choice:lower() ~= "y" then
    term.setCursorPos(3, 18)
    print("Installation cancelled.")
    os.sleep(2)
    os.reboot()
    return
end

-- Helper: download file with retries
local function http_get_file(url, save_path)
    local max_retries = 3
    for attempt = 1, max_retries do
        local resp = http.get(url)
        if resp then
            local content = resp.readAll()
            resp.close()

            local dir = fs.getDir(save_path)
            if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end

            local f = fs.open(save_path, "w")
            if f then
                f.write(content)
                f.close()
                return true
            end
        end
        sleep(0.5)
    end
    return false
end

-- Install workflow
term.setCursorPos(1,1)
print("=== Installing " .. APP_NAME .. " ===")

for _, file in ipairs(FILES) do
    local url = "https://raw.githubusercontent.com/Grain2077/WOPR/main/" .. file
    local cache_path = "/.install-cache/" .. APP_NAME .. "/" .. file

    -- Decide where the file should be installed
    local dest_path
    if file == "wopr/startup.lua" then
        dest_path = "/startup.lua"         -- root!
    else
        dest_path = "/" .. file            -- normal /pip-boy/...
    end

    -- Download into cache
    if http_get_file(url, cache_path) then
        local dir = fs.getDir(dest_path)
        if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end

        if fs.exists(dest_path) then fs.delete(dest_path) end
        fs.copy(cache_path, dest_path)
        print("Installed " .. dest_path)
    else
        print("Failed to download " .. file)
    end
end
shell.run("delete installer.lua")
print("=== Installation complete for " .. APP_NAME .. " ===")
