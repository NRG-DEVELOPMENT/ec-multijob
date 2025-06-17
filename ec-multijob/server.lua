local QBCore = exports['qb-core']:GetCoreObject()

-- Event to get player's jobs (replacing callback)
RegisterNetEvent('ec-multijob:server:RequestPlayerJobs', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player then
        local citizenid = Player.PlayerData.citizenid
        
        -- Get jobs from database
        MySQL.Async.fetchAll('SELECT * FROM player_jobs WHERE citizenid = ?', {citizenid}, function(result)
            local jobs = {}
            
            if result and #result > 0 then
                for _, job in ipairs(result) do
                    local jobData = {
                        id = job.id,
                        name = job.name,
                        grade = tonumber(job.grade),
                        label = job.name, -- Default label
                        gradeLabel = "Grade " .. job.grade -- Default grade label
                    }
                    
                    -- Add job details from QBCore shared jobs
                    if QBCore.Shared.Jobs[job.name] then
                        jobData.label = QBCore.Shared.Jobs[job.name].label
                        if QBCore.Shared.Jobs[job.name].grades[tonumber(job.grade)] then
                            jobData.gradeLabel = QBCore.Shared.Jobs[job.name].grades[tonumber(job.grade)].name
                        end
                    end
                    
                    table.insert(jobs, jobData)
                end
            end
            
            -- Add current job if it's not already in the list
            local currentJobFound = false
            for _, job in ipairs(jobs) do
                if job.name == Player.PlayerData.job.name then
                    currentJobFound = true
                    break
                end
            end
            
            if not currentJobFound and Player.PlayerData.job.name ~= "unemployed" then
                -- Add current job to database and job list
                MySQL.Async.insert('INSERT INTO player_jobs (citizenid, name, grade) VALUES (?, ?, ?)', 
                    {citizenid, Player.PlayerData.job.name, Player.PlayerData.job.grade.level},
                    function(jobId)
                        -- No need to do anything here, job will appear next time UI opens
                    end
                )
                
                local currentJobData = {
                    name = Player.PlayerData.job.name,
                    grade = Player.PlayerData.job.grade.level,
                    label = Player.PlayerData.job.label or Player.PlayerData.job.name,
                    gradeLabel = Player.PlayerData.job.grade.name
                }
                
                table.insert(jobs, currentJobData)
            end
            
            TriggerClientEvent('ec-multijob:client:ReceivePlayerJobs', src, jobs)
        end)
    else
        TriggerClientEvent('ec-multijob:client:ReceivePlayerJobs', src, {})
    end
end)

-- Event to switch job
RegisterNetEvent('ec-multijob:server:SwitchJob', function(jobName, jobGrade)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player then
        -- Check if the job exists in the player's jobs
        MySQL.Async.fetchAll('SELECT * FROM player_jobs WHERE citizenid = ? AND name = ?', 
            {Player.PlayerData.citizenid, jobName}, 
            function(result)
                if result and #result > 0 then
                    local jobInfo = result[1]
                    local grade = tonumber(jobInfo.grade)
                    
                    -- Set the job
                    Player.Functions.SetJob(jobInfo.name, grade)
                    
                    -- Get job label for notification
                    local jobLabel = jobName
                    if QBCore.Shared.Jobs[jobName] then
                        jobLabel = QBCore.Shared.Jobs[jobName].label
                    end
                    
                    TriggerClientEvent('QBCore:Notify', src, 'Switched to ' .. jobLabel, 'success')
                    TriggerClientEvent('ec-multijob:client:UpdateUI', src)
                    TriggerClientEvent('ec-multijob:client:PlaySwitchAnimation', src)
                else
                    TriggerClientEvent('QBCore:Notify', src, 'Job not found!', 'error')
                end
            end
        )
    end
end)

-- Event to toggle duty
RegisterNetEvent('ec-multijob:server:ToggleDuty', function()
    local src = source
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
end)

-- Add a job to a player (admin command)
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

-- Remove a job from a player (admin command)
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

-- Add default jobs to new players
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
