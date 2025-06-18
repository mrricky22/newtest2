local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

-- Constants
local PLACE_ID = 606849621
local WEBHOOK_URL = "https://discord.com/api/webhooks/1384910804377141338/PYYqx9758hsp5r3H88andR5dj4xAQ_LI517F5VbRpYAvEF7kqDF1rndYJURVR26tsXBr"
local SERVER_CACHE_FILE = "server_list.json"
local SCRIPT_TO_RUN = [[
    -- Wait until the game is fully loaded
    wait(10)
    loadstring(game:HttpGet("https://raw.githubusercontent.com/mrricky22/newtest2/refs/heads/main/new.lua"))()
]]

-- Function to send Discord webhook
local function sendWebhook(message)
    local requestOptions = {
        Url = WEBHOOK_URL,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = HttpService:JSONEncode({
            content = message
        })
    }
    
    local success, response = pcall(function()
        return request(requestOptions)
    end)
    
    if success and response.StatusCode == 204 then
        warn("Webhook sent successfully")
    else
        warn("Failed to send webhook: " .. tostring(response))
    end
end

-- Function to get a list of servers, with pagination support
local function getServerList(cursor, recursionDepth)
    recursionDepth = recursionDepth or 0
    if recursionDepth > 5 then -- Prevent infinite recursion
        warn("Max recursion depth reached in getServerList")
        return {}
    end

    local servers = {}
    local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?limit=100&sortOrder=Desc&excludeFullGames=true", PLACE_ID)
    if cursor then
        url = url .. "&cursor=" .. HttpService:UrlEncode(cursor)
    end
    
    local retries = 3
    for i = 1, retries do
        local success, response = pcall(function()
            return request({ Url = url, Method = "GET" })
        end)
        
        if success and response.Success and response.Body then
            local data = HttpService:JSONDecode(response.Body)
            if data and data.data then
                for _, server in ipairs(data.data) do
                    if server.playing and server.maxPlayers and server.playing < server.maxPlayers - 1 then
                        table.insert(servers, server)
                    end
                end
                if data.nextPageCursor and #servers < 10 then
                    local moreServers = getServerList(data.nextPageCursor, recursionDepth + 1)
                    for _, server in ipairs(moreServers) do
                        table.insert(servers, server)
                    end
                end
                return servers
            else
                warn("Invalid server list response: " .. tostring(response.Body))
            end
        else
            warn("Failed to fetch servers (attempt " .. i .. "/" .. retries .. "): " .. tostring(response))
            if i < retries then
                wait(2)
            end
        end
    end
    return {}
end

-- Function to load servers from cache or fetch new ones
local function loadServers()
    local servers = {}
    
    -- Check if cache file exists
    local success, fileContent = pcall(function()
        return readfile(SERVER_CACHE_FILE)
    end)
    
    if success and fileContent then
        local decodeSuccess, cachedServers = pcall(function()
            return HttpService:JSONDecode(fileContent)
        end)
        
        if decodeSuccess and cachedServers then
            warn("Loaded " .. #cachedServers .. " servers from cache")
            return cachedServers
        else
            warn("Failed to decode cached server list, fetching new servers")
        end
    end
    
    -- Fetch new servers if cache doesn't exist or is invalid
    servers = getServerList()
    warn("Fetched " .. #servers .. " new servers")
    
    -- Save servers to cache
    local encodeSuccess, encodedServers = pcall(function()
        return HttpService:JSONEncode(servers)
    end)
    
    if encodeSuccess then
        pcall(function()
            writefile(SERVER_CACHE_FILE, encodedServers)
            warn("Saved server list to cache")
        end)
    else
        warn("Failed to encode server list for caching")
    end
    
    return servers
end

-- Function to attempt teleporting to a server
local function attemptTeleport(serverId)
    local success, errorMsg = pcall(function()
        queue_on_teleport(SCRIPT_TO_RUN)
        TeleportService:TeleportToPlaceInstance(PLACE_ID, serverId, Players.LocalPlayer)
    end)
    
    if not success then
        warn("Teleport attempt failed: " .. tostring(errorMsg))
        return false
    end
    return true
end

-- Function to get a random server from the list
local function getRandomServer(servers, excludeJobId)
    if #servers == 0 then
        warn("No servers provided to getRandomServer")
        return nil
    end
    local validServers = {}
    for _, server in ipairs(servers) do
        if server.id and server.id ~= excludeJobId then
            table.insert(validServers, server)
        end
    end
    if #validServers == 0 then
        warn("No valid servers after filtering excludeJobId: " .. tostring(excludeJobId))
        return nil
    end
    math.randomseed(tick()) -- Seed for better randomness
    local randomIndex = math.random(1, #validServers)
    return validServers[randomIndex].id
end

-- Main logic
local function checkWorkspaceAndAct()
    local dropCount = 0
    
    for _, child in ipairs(workspace:GetChildren()) do
        if child.Name == "Drop" and child:FindFirstChild("Walls") then
            dropCount = dropCount + 1
        end
    end
    
    if dropCount > 0 then
        local message = string.format(
            "Found %d airdrop(s) in server: https://fern.wtf/joiner?placeId=%d&gameInstanceId=%s",
            dropCount,
            PLACE_ID,
            game.JobId
        )
        sendWebhook(message)
    end
    
    -- Load servers from cache or fetch new ones
    local servers = loadServers()
    warn("Loaded " .. #servers .. " servers")
    local serverId = getRandomServer(servers, game.JobId)
    if serverId then
        warn("Attempting to teleport to server: " .. serverId)
        attemptTeleport(serverId)
    else
        warn("No available servers found. Server list size: " .. #servers)
    end
end

-- Handle teleport failures
TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage)
    if player == Players.LocalPlayer then
        warn("Teleport failed: " .. teleportResult.Name .. " - " .. tostring(errorMessage))
        
        -- Load servers from cache or fetch new ones
        local servers = loadServers()
        warn("Loaded " .. #servers .. " servers after teleport failure")
        local serverId = getRandomServer(servers, game.JobId)
        
        if serverId then
            warn("Attempting to join another server: " .. serverId)
            attemptTeleport(serverId)
        else
            warn("No alternative servers available after teleport failure. Server list size: " .. #servers)
            pcall(function()
                queue_on_teleport(SCRIPT_TO_RUN)
                TeleportService:Teleport(PLACE_ID, Players.LocalPlayer)
            end)
        end
    end
end)

-- Execute the main logic
checkWorkspaceAndAct()
