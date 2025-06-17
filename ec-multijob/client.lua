local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local isUIOpen = false

-- Initialize player data when player loads
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
end)

-- Update player data when it changes
RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
end)

-- Function to toggle the UI
function ToggleMultiJobUI()
    isUIOpen = not isUIOpen
    
    if isUIOpen then
        -- Request jobs data from server using event instead of callback
        TriggerServerEvent('ec-multijob:server:RequestPlayerJobs')
    else
        SetNuiFocus(false, false)
        SendNUIMessage({
            action = "close"
        })
    end
end

-- Receive jobs data from server
RegisterNetEvent('ec-multijob:client:ReceivePlayerJobs', function(jobs)
    if isUIOpen then
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = "open",
            jobs = jobs,
            currentJob = PlayerData.job
        })
    end
end)

-- Command to open the UI
RegisterCommand('multijob', function()
    ToggleMultiJobUI()
end)

-- Key mapping for F9
RegisterKeyMapping('multijob', 'Open Multi Job UI', 'keyboard', 'F9')

-- NUI Callbacks
RegisterNUICallback('close', function(data, cb)
    ToggleMultiJobUI()
    cb('ok')
end)

RegisterNUICallback('switchJob', function(data, cb)
    TriggerServerEvent('ec-multijob:server:SwitchJob', data.jobName, data.jobGrade)
    cb('ok')
end)

RegisterNUICallback('toggleDuty', function(data, cb)
    TriggerServerEvent('ec-multijob:server:ToggleDuty')
    cb('ok')
end)

-- Event to update UI after job change
RegisterNetEvent('ec-multijob:client:UpdateUI', function()
    if isUIOpen then
        TriggerServerEvent('ec-multijob:server:RequestPlayerJobs')
    end
end)

-- Animation for job switching
RegisterNetEvent('ec-multijob:client:PlaySwitchAnimation', function()
    local playerPed = PlayerPedId()
    
    RequestAnimDict("mp_clothing@female@shirt")
    while not HasAnimDictLoaded("mp_clothing@female@shirt") do
        Wait(0)
    end
    
    TaskPlayAnim(playerPed, "mp_clothing@female@shirt", "try_shirt_positive_a", 8.0, -8.0, 800, 0, 0, false, false, false)
    Wait(800)
    ClearPedTasks(playerPed)
end)
