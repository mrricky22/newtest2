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

-- Function to get a list of servers
local function getServerList()
    local url = "https://games.roblox.com/v1/games/606849621/servers/Public?limit=100&sortOrder=Desc&excludeFullGames=true"
    local requestOptions = {
        Url = url,
        Method = "GET"
    }
    
    local success, response = pcall(function()
        return request(requestOptions)
    end)
    
    if success and response.Success then
        local data = HttpService:JSONDecode(response.Body)
        return data.data or {}
    else
        warn("Failed to fetch servers: " .. tostring(response))
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
        return nil
    end
    local validServers = {}
    for _, server in ipairs(servers) do
        if server.id ~= excludeJobId then
            table.insert(validServers, server)
        end
    end
    if #validServers == 0 then
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
    local serverId = getRandomServer(servers, game.JobId)
    if serverId then
        attemptTeleport(serverId)
    else
        warn("No available servers found.")
    end
end

-- Handle teleport failures
TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage)
    if player == Players.LocalPlayer then
        warn("Teleport failed: " .. teleportResult.Name .. " - " .. tostring(errorMessage))
        
        -- Fetch a new server list
        local servers = getServerList()
        local serverId = getRandomServer(servers, game.JobId)
        
        if serverId then
            warn("Attempting to join another server: " .. serverId)
            attemptTeleport(serverId)
        else
            warn("No alternative servers available after teleport failure.")
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
