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
    TriggerEvent('esx:getSharedObject', function(obj) 
        ESX = obj 
        framework = "esx"
    end)
end

-- Debug message to show which framework is being used
print("^2[EC-MultiJob]^7 Framework detected: ^3" .. framework .. "^7")

-- Create database table if it doesn't exist with proper AUTO_INCREMENT
MySQL.ready(function()
    -- First, check if the table exists
    MySQL.Async.fetchAll("SHOW TABLES LIKE 'player_jobs'", {}, function(result)
        if result and #result > 0 then
            -- Table exists, check if we need to modify it
            print("^2[EC-MultiJob]^7 Table player_jobs exists, checking structure...")
            
            -- Check if id column has AUTO_INCREMENT
            MySQL.Async.fetchAll("SHOW COLUMNS FROM player_jobs LIKE 'id'", {}, function(columns)
                if columns and #columns > 0 then
                    local column = columns[1]
                    if column.Extra and string.find(column.Extra, "auto_increment") then
                        print("^2[EC-MultiJob]^7 Table structure is correct")
                    else
                        -- Fix the id column to have AUTO_INCREMENT
                        print("^3[EC-MultiJob]^7 Fixing id column to have AUTO_INCREMENT...")
                        MySQL.Async.execute("ALTER TABLE player_jobs MODIFY id INT NOT NULL AUTO_INCREMENT", {}, function()
                            print("^2[EC-MultiJob]^7 Table structure fixed successfully")
                        end)
                    end
                end
            end)
        else
            -- Table doesn't exist, create it with proper structure
            print("^3[EC-MultiJob]^7 Creating player_jobs table...")
            MySQL.Async.execute([[
                CREATE TABLE `player_jobs` (
                    `id` INT NOT NULL AUTO_INCREMENT,
                    `citizenid` VARCHAR(50) NOT NULL,
                    `name` VARCHAR(50) NOT NULL,
                    `grade` INT NOT NULL DEFAULT 0,
                    PRIMARY KEY (`id`),
                    INDEX `citizenid` (`citizenid`),
                    INDEX `name` (`name`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            ]], {}, function()
                print("^2[EC-MultiJob]^7 Table player_jobs created successfully")
            end)
        end
    end)
end)


RegisterNetEvent('ec-multijob:server:RequestPlayerJobs', function()
    local src = source
    local citizenid
    
    if framework == "qbcore" then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            citizenid = Player.PlayerData.citizenid
        end
    elseif framework == "esx" then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            citizenid = xPlayer.identifier
        end
    end
    
    if not citizenid then
        TriggerClientEvent('ec-multijob:client:ReceivePlayerJobs', src, {})
        return
    end
    
    MySQL.Async.fetchAll('SELECT * FROM player_jobs WHERE citizenid = ?', {citizenid}, function(result)
        local jobs = {}
        
        if result and #result > 0 then
            for _, job in ipairs(result) do
                local jobData = {
                    id = job.id,
                    name = job.name,
                    grade = tonumber(job.grade),
                    label = job.name,
                    gradeLabel = "Grade " .. job.grade
                }
                
                if framework == "qbcore" and QBCore.Shared.Jobs[job.name] then
                    jobData.label = QBCore.Shared.Jobs[job.name].label
                    if QBCore.Shared.Jobs[job.name].grades[tonumber(job.grade)] then
                        jobData.gradeLabel = QBCore.Shared.Jobs[job.name].grades[tonumber(job.grade)].name
                    end
                elseif framework == "esx" then
                    local ESXJobs = ESX.GetJobs and ESX.GetJobs() or {}
                    if ESXJobs[job.name] then
                        jobData.label = ESXJobs[job.name].label
                        if ESXJobs[job.name].grades[tonumber(job.grade)] then
                            jobData.gradeLabel = ESXJobs[job.name].grades[tonumber(job.grade)].name
                        end
                    end
                end
                
                table.insert(jobs, jobData)
            end
        end
        
        local currentJobName, currentJobGrade, currentJobLabel, currentGradeLabel
        
        if framework == "qbcore" then
            local Player = QBCore.Functions.GetPlayer(src)
            currentJobName = Player.PlayerData.job.name
            currentJobGrade = Player.PlayerData.job.grade.level
            currentJobLabel = Player.PlayerData.job.label
            currentGradeLabel = Player.PlayerData.job.grade.name
        elseif framework == "esx" then
            local xPlayer = ESX.GetPlayerFromId(src)
            currentJobName = xPlayer.job.name
            currentJobGrade = xPlayer.job.grade
            currentJobLabel = xPlayer.job.label
            
            local ESXJobs = ESX.GetJobs and ESX.GetJobs() or {}
            if ESXJobs[currentJobName] and ESXJobs[currentJobName].grades[currentJobGrade] then
                currentGradeLabel = ESXJobs[currentJobName].grades[currentJobGrade].name
            else
                currentGradeLabel = "Grade " .. currentJobGrade
            end
        end
        
        local currentJobFound = false
        for _, job in ipairs(jobs) do
            if job.name == currentJobName then
                currentJobFound = true
                break
            end
        end
        
        if not currentJobFound and currentJobName ~= "unemployed" then
            MySQL.Async.insert('INSERT INTO player_jobs (citizenid, name, grade) VALUES (?, ?, ?)', 
                {citizenid, currentJobName, currentJobGrade}
            )
            
            local currentJobData = {
                name = currentJobName,
                grade = currentJobGrade,
                label = currentJobLabel or currentJobName,
                gradeLabel = currentGradeLabel
            }
            
            table.insert(jobs, currentJobData)
        end
        
        TriggerClientEvent('ec-multijob:client:ReceivePlayerJobs', src, jobs)
    end)
end)

-- Event to switch job
RegisterNetEvent('ec-multijob:server:SwitchJob', function(jobName, jobGrade)
    local src = source
    local citizenid
    
    if framework == "qbcore" then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            citizenid = Player.PlayerData.citizenid
        end
    elseif framework == "esx" then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            citizenid = xPlayer.identifier
        end
    end
    
    if not citizenid then return end
    
    -- Check if the job exists in the player's jobs
    MySQL.Async.fetchAll('SELECT * FROM player_jobs WHERE citizenid = ? AND name = ?', 
        {citizenid, jobName}, 
        function(result)
            if result and #result > 0 then
                local jobInfo = result[1]
                local grade = tonumber(jobInfo.grade)
                
                -- Set the job based on framework
                if framework == "qbcore" then
                    local Player = QBCore.Functions.GetPlayer(src)
                    Player.Functions.SetJob(jobInfo.name, grade)
                    
                    -- Get job label for notification
                    local jobLabel = jobName
                    if QBCore.Shared.Jobs[jobName] then
                        jobLabel = QBCore.Shared.Jobs[jobName].label
                    end
                    
                    TriggerClientEvent('QBCore:Notify', src, 'Switched to ' .. jobLabel, 'success')
                elseif framework == "esx" then
                    local xPlayer = ESX.GetPlayerFromId(src)
                    xPlayer.setJob(jobInfo.name, grade)
                    
                    -- Get job label for notification
                    local jobLabel = jobName
                    local ESXJobs = ESX.GetJobs()
                    if ESXJobs[jobName] then
                        jobLabel = ESXJobs[jobName].label
                    end
                    
                    TriggerClientEvent('esx:showNotification', src, 'Switched to ' .. jobLabel)
                end
                
                TriggerClientEvent('ec-multijob:client:UpdateUI', src)
                TriggerClientEvent('ec-multijob:client:PlaySwitchAnimation', src)
            else
                if framework == "qbcore" then
                    TriggerClientEvent('QBCore:Notify', src, 'Job not found!', 'error')
                else
                    TriggerClientEvent('esx:showNotification', src, 'Job not found!')
                end
            end
        end
    )
end)

-- Event to toggle duty
RegisterNetEvent('ec-multijob:server:ToggleDuty', function()
    local src = source
    
    if framework == "qbcore" then
        local Player = QBCore.Functions.GetPlayer(src)
        
        if Player then
            if Player.PlayerData.job.onduty then
                Player.Functions.SetJobDuty(false)
                TriggerClientEvent('QBCore:Notify', src, 'You are now off duty', 'success')
            else
                Player.Functions.SetJobDuty(true)
                TriggerClientEvent('QBCore:Notify', src, 'You are now on duty', 'success')
            end
            TriggerClientEvent('ec-multijob:client:UpdateUI', src)
        end
    elseif framework == "esx" then
        local xPlayer = ESX.GetPlayerFromId(src)
        
        if xPlayer then
            local onDuty = xPlayer.get('onDuty') or false
            xPlayer.set('onDuty', not onDuty)
            
            if onDuty then
                TriggerClientEvent('esx:showNotification', src, 'You are now off duty')
            else
                TriggerClientEvent('esx:showNotification', src, 'You are now on duty')
            end
            TriggerClientEvent('ec-multijob:client:UpdateUI', src)
        end
    end
end)

-- Event for player removing their own job
RegisterNetEvent('ec-multijob:server:RemoveJob', function(jobId)
    local src = source
    local citizenid
    
    if framework == "qbcore" then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            citizenid = Player.PlayerData.citizenid
        end
    elseif framework == "esx" then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            citizenid = xPlayer.identifier
        end
    end
    
    if not citizenid then return end
    
    -- Get job info before removing
    MySQL.Async.fetchAll('SELECT * FROM player_jobs WHERE id = ? AND citizenid = ?', 
        {jobId, citizenid}, 
        function(result)
            if result and #result > 0 then
                local jobInfo = result[1]
                
                -- Don't allow removing current job
                local currentJob
                if framework == "qbcore" then
                    local Player = QBCore.Functions.GetPlayer(src)
                    currentJob = Player.PlayerData.job.name
                elseif framework == "esx" then
                    local xPlayer = ESX.GetPlayerFromId(src)
                    currentJob = xPlayer.job.name
                end
                
                if jobInfo.name == currentJob then
                    if framework == "qbcore" then
                        TriggerClientEvent('QBCore:Notify', src, 'Cannot remove your current job!', 'error')
                    else
                        TriggerClientEvent('esx:showNotification', src, 'Cannot remove your current job!')
                    end
                    return
                end
                
                -- Remove the job
                MySQL.Async.execute('DELETE FROM player_jobs WHERE id = ? AND citizenid = ?', 
                    {jobId, citizenid}, 
                    function(rowsChanged)
                        if rowsChanged > 0 then
                            if framework == "qbcore" then
                                TriggerClientEvent('QBCore:Notify', src, 'Job removed successfully', 'success')
                            else
                                TriggerClientEvent('esx:showNotification', src, 'Job removed successfully')
                            end
                            TriggerClientEvent('ec-multijob:client:UpdateUI', src)
                        end
                    end
                )
            end
        end
    )
end)

-- Add a job to a player (admin command)
if framework == "qbcore" then
    QBCore.Commands.Add('addjob', 'Add a job to a player (Admin Only)', {{name='id', help='Player ID'}, {name='job', help='Job Name'}, {name='grade', help='Job Grade'}}, true, function(source, args)
        local src = source
        local adminPlayer = QBCore.Functions.GetPlayer(src)
        
        if adminPlayer.PlayerData.admin or IsPlayerAceAllowed(src, 'command.addjob') then
            local targetId = tonumber(args[1])
            local targetPlayer = QBCore.Functions.GetPlayer(targetId)
            
            if targetPlayer then
                local jobName = args[2]
                local jobGrade = tonumber(args[3]) or 0
                
                -- Check if job exists in QBCore shared jobs
                if not QBCore.Shared.Jobs[jobName] then
                    TriggerClientEvent('QBCore:Notify', src, 'Job does not exist!', 'error')
                    return
                end
                
                -- Check if player already has this job
                MySQL.Async.fetchAll('SELECT * FROM player_jobs WHERE citizenid = ? AND name = ?', 
                    {targetPlayer.PlayerData.citizenid, jobName}, 
                    function(result)
                        if result and #result > 0 then
                            -- Update existing job grade
                            MySQL.Async.execute('UPDATE player_jobs SET grade = ? WHERE citizenid = ? AND name = ?', 
                                {jobGrade, targetPlayer.PlayerData.citizenid, jobName}
                            )
                            TriggerClientEvent('QBCore:Notify', src, 'Job grade updated for player', 'success')
                        else
                            -- Add new job
                            MySQL.Async.insert('INSERT INTO player_jobs (citizenid, name, grade) VALUES (?, ?, ?)', 
                                {targetPlayer.PlayerData.citizenid, jobName, jobGrade}
                            )
                            TriggerClientEvent('QBCore:Notify', src, 'Job added to player', 'success')
                        end
                        
                        -- Update player's current job if they're using this job
                        if targetPlayer.PlayerData.job.name == jobName then
                            targetPlayer.Functions.SetJob(jobName, jobGrade)
                        end
                    end
                )
            else
                TriggerClientEvent('QBCore:Notify', src, 'Player not found', 'error')
            end
        else
            TriggerClientEvent('QBCore:Notify', src, 'No permission', 'error')
        end
    end, 'admin')
else
    -- ESX version of addjob command
    RegisterCommand('addjob', function(source, args)
        local src = source
        local xPlayer = ESX.GetPlayerFromId(src)
        
        if xPlayer.getGroup() == 'admin' or xPlayer.getGroup() == 'superadmin' then
            local targetId = tonumber(args[1])
            local targetPlayer = ESX.GetPlayerFromId(targetId)
            
            if targetPlayer then
                local jobName = args[2]
                local jobGrade = tonumber(args[3]) or 0
                
                -- Check if job exists in ESX jobs
                local ESXJobs = ESX.GetJobs()
                if not ESXJobs[jobName] then
                    TriggerClientEvent('esx:showNotification', src, 'Job does not exist!')
                    return
                end
                
                -- Check if player already has this job
                MySQL.Async.fetchAll('SELECT * FROM player_jobs WHERE citizenid = ? AND name = ?', 
                    {targetPlayer.identifier, jobName}, 
                    function(result)
                        if result and #result > 0 then
                            -- Update existing job grade
                            MySQL.Async.execute('UPDATE player_jobs SET grade = ? WHERE citizenid = ? AND name = ?', 
                                {jobGrade, targetPlayer.identifier, jobName}
                            )
                            TriggerClientEvent('esx:showNotification', src, 'Job grade updated for player')
                        else
                            -- Add new job
                            MySQL.Async.insert('INSERT INTO player_jobs (citizenid, name, grade) VALUES (?, ?, ?)', 
                                {targetPlayer.identifier, jobName, jobGrade}
                            )
                            TriggerClientEvent('esx:showNotification', src, 'Job added to player')
                        end
                        
                        -- Update player's current job if they're using this job
                        if targetPlayer.job.name == jobName then
                            targetPlayer.setJob(jobName, jobGrade)
                        end
                    end
                )
            else
                TriggerClientEvent('esx:showNotification', src, 'Player not found')
            end
        else
            TriggerClientEvent('esx:showNotification', src, 'No permission')
        end
    end)
end

-- Remove a job from a player (admin command)
if framework == "qbcore" then
    QBCore.Commands.Add('removejob', 'Remove a job from a player (Admin Only)', {{name='id', help='Player ID'}, {name='job', help='Job Name'}}, true, function(source, args)
        local src = source
        local adminPlayer = QBCore.Functions.GetPlayer(src)
        
        if adminPlayer.PlayerData.admin or IsPlayerAceAllowed(src, 'command.removejob') then
            local targetId = tonumber(args[1])
            local targetPlayer = QBCore.Functions.GetPlayer(targetId)
            
            if targetPlayer then
                local jobName = args[2]
                
                MySQL.Async.execute('DELETE FROM player_jobs WHERE citizenid = ? AND name = ?', 
                    {targetPlayer.PlayerData.citizenid, jobName}, 
                    function(rowsChanged)
                        if rowsChanged > 0 then
                            TriggerClientEvent('QBCore:Notify', src, 'Job removed from player', 'success')
                            
                            -- If player is currently using this job, set them to unemployed
                            if targetPlayer.PlayerData.job.name == jobName then
                                targetPlayer.Functions.SetJob('unemployed', 0)
                            end
                        else
                            TriggerClientEvent('QBCore:Notify', src, 'Player does not have this job', 'error')
                        end
                    end
                )
            else
                TriggerClientEvent('QBCore:Notify', src, 'Player not found', 'error')
            end
        else
            TriggerClientEvent('QBCore:Notify', src, 'No permission', 'error')
        end
    end, 'admin')
else
    -- ESX version of removejob command
    RegisterCommand('removejob', function(source, args)
        local src = source
        local xPlayer = ESX.GetPlayerFromId(src)
        
        if xPlayer.getGroup() == 'admin' or xPlayer.getGroup() == 'superadmin' then
            local targetId = tonumber(args[1])
            local targetPlayer = ESX.GetPlayerFromId(targetId)
            
            if targetPlayer then
                local jobName = args[2]
                
                MySQL.Async.execute('DELETE FROM player_jobs WHERE citizenid = ? AND name = ?', 
                    {targetPlayer.identifier, jobName}, 
                    function(rowsChanged)
                        if rowsChanged > 0 then
                            TriggerClientEvent('esx:showNotification', src, 'Job removed from player')
                            
                            -- If player is currently using this job, set them to unemployed
                            if targetPlayer.job.name == jobName then
                                targetPlayer.setJob('unemployed', 0)
                            end
                        else
                            TriggerClientEvent('esx:showNotification', src, 'Player does not have this job')
                        end
                    end
                )
            else
                TriggerClientEvent('esx:showNotification', src, 'Player not found')
            end
        else
            TriggerClientEvent('esx:showNotification', src, 'No permission')
        end
    end)
end

-- Add default jobs to new players
if framework == "qbcore" then
    RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        
        if Player then
            local citizenid = Player.PlayerData.citizenid
            
            -- Check if player has any jobs
            MySQL.Async.fetchAll('SELECT COUNT(*) as count FROM player_jobs WHERE citizenid = ?', {citizenid}, function(result)
                if result[1].count == 0 then
                    -- Add current job to database
                    if Player.PlayerData.job.name ~= "unemployed" then
                        MySQL.Async.insert('INSERT INTO player_jobs (citizenid, name, grade) VALUES (?, ?, ?)', 
                            {citizenid, Player.PlayerData.job.name, Player.PlayerData.job.grade.level}
                        )
                    end
                end
            end)
        end
    end)
    
    -- Track job changes in QBCore
    RegisterNetEvent('QBCore:Server:OnJobUpdate', function(source, newJob)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        
        if Player then
            local citizenid = Player.PlayerData.citizenid
            local jobName = newJob.name
            local jobGrade = newJob.grade.level
            
            -- If job is unemployed, it means the player was fired
            if jobName == "unemployed" then
                -- Find the previous job and remove it
                MySQL.Async.fetchAll('SELECT * FROM player_jobs WHERE citizenid = ? AND name != ?', 
                    {citizenid, "unemployed"}, 
                    function(result)
                        if result and #result > 0 then
                            for _, job in ipairs(result) do
                                -- Delete all jobs except unemployed
                                MySQL.Async.execute('DELETE FROM player_jobs WHERE id = ?', {job.id})
                            end
                        end
                    end
                )
            else
                -- Check if job exists in database and update or add it
                MySQL.Async.fetchAll('SELECT * FROM player_jobs WHERE citizenid = ? AND name = ?', 
                    {citizenid, jobName}, 
                    function(result)
                        if result and #result > 0 then
                            -- Update existing job grade
                            MySQL.Async.execute('UPDATE player_jobs SET grade = ? WHERE citizenid = ? AND name = ?', 
                                {jobGrade, citizenid, jobName}
                            )
                        else
                            -- Add new job
                            MySQL.Async.insert('INSERT INTO player_jobs (citizenid, name, grade) VALUES (?, ?, ?)', 
                                {citizenid, jobName, jobGrade}
                            )
                        end
                    end
                )
            end
        end
    end)
else
    -- ESX version of player loaded event
    RegisterNetEvent('esx:playerLoaded', function(playerId, xPlayer)
        local src = playerId
        local citizenid = xPlayer.identifier
        
        -- Check if player has any jobs
        MySQL.Async.fetchAll('SELECT COUNT(*) as count FROM player_jobs WHERE citizenid = ?', {citizenid}, function(result)
            if result[1].count == 0 then
                -- Add current job to database
                if xPlayer.job.name ~= "unemployed" then
                    MySQL.Async.insert('INSERT INTO player_jobs (citizenid, name, grade) VALUES (?, ?, ?)', 
                        {citizenid, xPlayer.job.name, xPlayer.job.grade}
                    )
                end
            end
        end)
    end)
    
    -- Track job changes in ESX
    RegisterNetEvent('esx:setJob', function(source, job, lastJob)
        local src = source
        local xPlayer = ESX.GetPlayerFromId(src)
        
        if xPlayer then
            local citizenid = xPlayer.identifier
            local jobName = job.name
            local jobGrade = job.grade
            
            -- If job is unemployed, it means the player was fired
            if jobName == "unemployed" then
                -- Find the previous job and remove it
                MySQL.Async.fetchAll('SELECT * FROM player_jobs WHERE citizenid = ? AND name = ?', 
                    {citizenid, lastJob.name}, 
                    function(result)
                        if result and #result > 0 then
                            -- Delete the previous job
                            MySQL.Async.execute('DELETE FROM player_jobs WHERE citizenid = ? AND name = ?', 
                                {citizenid, lastJob.name}
                            )
                        end
                    end
                )
            else
                -- Check if job exists in database and update or add it
                MySQL.Async.fetchAll('SELECT * FROM player_jobs WHERE citizenid = ? AND name = ?', 
                    {citizenid, jobName}, 
                    function(result)
                        if result and #result > 0 then
                            -- Update existing job grade
                            MySQL.Async.execute('UPDATE player_jobs SET grade = ? WHERE citizenid = ? AND name = ?', 
                                {jobGrade, citizenid, jobName}
                            )
                        else
                            -- Add new job
                            MySQL.Async.insert('INSERT INTO player_jobs (citizenid, name, grade) VALUES (?, ?, ?)', 
                                {citizenid, jobName, jobGrade}
                            )
                        end
                    end
                )
            end
        end
    end)
end
-- Event to handle job updates from the core framework
RegisterNetEvent('ec-multijob:server:JobUpdated', function(newJob, lastJob)
    local src = source
    local citizenid
    
    if framework == "qbcore" then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            citizenid = Player.PlayerData.citizenid
            
            -- If job is unemployed, it means the player was fired
            if newJob.name == "unemployed" then
                -- Remove the previous job from the database
                MySQL.Async.execute('DELETE FROM player_jobs WHERE citizenid = ? AND name != ?', 
                    {citizenid, "unemployed"}
                )
            else
                -- Update or add the job in the database
                MySQL.Async.fetchAll('SELECT * FROM player_jobs WHERE citizenid = ? AND name = ?', 
                    {citizenid, newJob.name}, 
                    function(result)
                        if result and #result > 0 then
                            MySQL.Async.execute('UPDATE player_jobs SET grade = ? WHERE citizenid = ? AND name = ?', 
                                {newJob.grade.level, citizenid, newJob.name}
                            )
                        else
                            MySQL.Async.insert('INSERT INTO player_jobs (citizenid, name, grade) VALUES (?, ?, ?)', 
                                {citizenid, newJob.name, newJob.grade.level}
                            )
                        end
                    end
                )
            end
        end
    elseif framework == "esx" then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            citizenid = xPlayer.identifier
            
            if newJob.name == "unemployed" and lastJob then
                MySQL.Async.execute('DELETE FROM player_jobs WHERE citizenid = ? AND name = ?', 
                    {citizenid, lastJob.name}
                )
            else
                -- Update or add the job in the database
                MySQL.Async.fetchAll('SELECT * FROM player_jobs WHERE citizenid = ? AND name = ?', 
                    {citizenid, newJob.name}, 
                    function(result)
                        if result and #result > 0 then
                            MySQL.Async.execute('UPDATE player_jobs SET grade = ? WHERE citizenid = ? AND name = ?', 
                                {newJob.grade, citizenid, newJob.name}
                            )
                        else
                            MySQL.Async.insert('INSERT INTO player_jobs (citizenid, name, grade) VALUES (?, ?, ?)', 
                                {citizenid, newJob.name, newJob.grade}
                            )
                        end
                    end
                )
            end
        end
    end
end)
