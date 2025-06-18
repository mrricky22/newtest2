local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

-- Discord webhook URL
local webhookUrl = "https://discord.com/api/webhooks/1384910804377141338/PYYqx9758hsp5r3H88andR5dj4xAQ_LI517F5VbRpYAvEF7kqDF1rndYJURVR26tsXBr"

-- Script to run after teleport
local scriptToRun = [[
    -- Wait until the game is fully loaded
    wait(10)
    loadstring(game:HttpGet("https://raw.githubusercontent.com/mrricky22/newtest2/refs/heads/main/new.lua"))()
]]

-- Function to send Discord webhook
local function sendWebhook(message)
    local requestOptions = {
        Url = webhookUrl,
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
    
    if not success then
        warn("Failed to send webhook: " .. tostring(response))
    end
end

-- Function to get a list of servers, with pagination support
local function getServerList(cursor)
    local servers = {}
    local url = "https://games.roblox.com/v1/games/606849621/servers/Public?limit=100&sortOrder=Desc&excludeFullGames=true"
    if cursor then
        url = url .. "&cursor=" .. cursor
    end
    
    local requestOptions = {
        Url = url,
        Method = "GET"
    }
    
    local retries = 3
    for i = 1, retries do
        local success, response = pcall(function()
            return request(requestOptions)
        end)
        
        if success and response.Success then
            local data = HttpService:JSONDecode(response.Body)
            if data.data then
                for _, server in ipairs(data.data) do
                    -- Only include servers with enough open slots (e.g., at least 2 slots)
                    if server.playing < server.maxPlayers - 1 then
                        table.insert(servers, server)
                    end
                end
                -- If there's a next page and we need more servers, recurse
                if data.nextPageCursor and #servers < 10 then
                    local moreServers = getServerList(data.nextPageCursor)
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
                wait(2) -- Wait before retrying
            end
        end
    end
    return {}
end

-- Function to attempt teleporting to a server
local function attemptTeleport(serverId)
    local success, errorMsg = pcall(function()
        queue_on_teleport(scriptToRun)
        TeleportService:TeleportToPlaceInstance(606849621, serverId, Players.LocalPlayer)
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
        if server.id ~= excludeJobId then
            table.insert(validServers, server)
        end
    end
    if #validServers == 0 then
        warn("No valid servers after filtering excludeJobId: " .. tostring(excludeJobId))
        return nil
    end
    local randomIndex = math.random(1, #validServers)
    return validServers[randomIndex].id
end

-- Main logic
local function checkWorkspaceAndAct()
    local dropCount = 0
    
    -- Search workspace for "Drop" with "Walls" child and count instances
    for _, child in ipairs(workspace:GetChildren()) do
        if child.Name == "Drop" and child:FindFirstChild("Walls") then
            dropCount = dropCount + 1
        end
    end
    
    -- Send webhook only if drops are found
    if dropCount > 0 then
        local message = string.format(
            "Found %d airdrop(s) in server: https://fern.wtf/joiner?placeId=606849621&gameInstanceId=%s",
            dropCount,
            game.JobId
        )
        sendWebhook(message)
    end
    
    -- Fetch server list and hop to a random server
    local servers = getServerList()
    warn("Fetched " .. #servers .. " servers")
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
        
        -- Fetch a new server list
        local servers = getServerList()
        warn("Fetched " .. #servers .. " servers after teleport failure")
        local serverId = getRandomServer(servers, game.JobId)
        
        if serverId then
            warn("Attempting to join another server: " .. serverId)
            attemptTeleport(serverId)
        else
            warn("No alternative servers available after teleport failure. Server list size: " .. #servers)
            -- Fallback to default teleport
            pcall(function()
                queue_on_teleport(scriptToRun)
                TeleportService:Teleport(606849621, Players.LocalPlayer)
            end)
        end
    end
end)

-- Execute the main logic
checkWorkspaceAndAct()
