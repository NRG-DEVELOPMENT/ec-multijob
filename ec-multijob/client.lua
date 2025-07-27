-- Detect framework
local QBCore = nil
local ESX = nil
local framework = "unknown"

-- Try to load QBCore
local success = pcall(function()
    QBCore = exports['qb-core']:GetCoreObject()
    framework = "qbcore"
end)

-- If QBCore failed, try ESX
if not success then
    Citizen.CreateThread(function()
        while ESX == nil do
            TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
            Citizen.Wait(0)
        end
        framework = "esx"
    end)
end

-- Debug message to show which framework is being used
Citizen.CreateThread(function()
    Citizen.Wait(2000) -- Wait to ensure framework detection is complete
    print("^2[EC-MultiJob]^7 Client using framework: ^3" .. framework .. "^7")
end)

local PlayerData = {}
local isUIOpen = false

-- Initialize player data when player loads
if framework == "qbcore" then
    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
        PlayerData = QBCore.Functions.GetPlayerData()
    end)
    
    RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
        PlayerData.job = JobInfo
        -- Update UI if it's open
        if isUIOpen then
            TriggerServerEvent('ec-multijob:server:RequestPlayerJobs')
        end
    end)
else
    RegisterNetEvent('esx:playerLoaded', function(xPlayer)
        PlayerData = xPlayer
    end)
    
    RegisterNetEvent('esx:setJob', function(job)
        PlayerData.job = job
        -- Update UI if it's open
        if isUIOpen then
            TriggerServerEvent('ec-multijob:server:RequestPlayerJobs')
        end
    end)
end

-- Function to toggle the UI
function ToggleMultiJobUI()
    isUIOpen = not isUIOpen
    
    if isUIOpen then
        -- Request jobs data from server using event
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
            currentJob = PlayerData.job,
            framework = framework
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

-- Add new callback for removing job
RegisterNUICallback('removeJob', function(data, cb)
    TriggerServerEvent('ec-multijob:server:RemoveJob', data.jobId)
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

if framework == "qbcore" then
    RegisterNetEvent('QBCore:Client:OnJobUpdate', function(jobInfo)
        TriggerServerEvent('ec-multijob:server:JobUpdated', jobInfo)
    end)
else
    -- ESX version of job update tracking
    RegisterNetEvent('esx:setJob', function(job, lastJob)
        TriggerServerEvent('ec-multijob:server:JobUpdated', job, lastJob)
    end)
end

