$(function() {
    let currentJob = null;
    
    window.addEventListener('message', function(event) {
        const data = event.data;
        
        if (data.action === "open") {
            $('body').fadeIn(300);
            currentJob = data.currentJob;
            updateJobInfo(data.currentJob);
            populateJobs(data.jobs);
            playOpenSound();
        } else if (data.action === "close") {
            $('body').fadeOut(300);
            playCloseSound();
        } else if (data.action === "update") {
            currentJob = data.currentJob;
            updateJobInfo(data.currentJob);
            populateJobs(data.jobs);
            playUpdateSound();
        }
    });
    
    // Close button
    $('.close-btn').click(function() {
        $.post('https://ec-multijob/close', JSON.stringify({}));
    });
    
    // Toggle duty button
    $('#toggle-duty-btn').click(function() {
        $(this).addClass('clicked');
        setTimeout(() => {
            $(this).removeClass('clicked');
        }, 300);
        
        $.post('https://ec-multijob/toggleDuty', JSON.stringify({}));
        playButtonSound();
    });
    
    // Handle escape key
    $(document).keyup(function(e) {
        if (e.key === "Escape") {
            $.post('https://ec-multijob/close', JSON.stringify({}));
        }
    });
    
    // Sound effects
    function playOpenSound() {
        try {
            const audio = new Audio('https://cdn.freesound.org/previews/521/521642_7247361-lq.mp3');
            audio.volume = 0.2;
            audio.play().catch(e => console.log("Audio play failed:", e));
        } catch (e) {
            console.log("Sound error:", e);
        }
    }
    
    function playCloseSound() {
        try {
            const audio = new Audio('https://cdn.freesound.org/previews/521/521643_7247361-lq.mp3');
            audio.volume = 0.2;
            audio.play().catch(e => console.log("Audio play failed:", e));
        } catch (e) {
            console.log("Sound error:", e);
        }
    }
    
    function playButtonSound() {
        try {
            const audio = new Audio('https://cdn.freesound.org/previews/522/522720_10058132-lq.mp3');
            audio.volume = 0.2;
            audio.play().catch(e => console.log("Audio play failed:", e));
        } catch (e) {
            console.log("Sound error:", e);
        }
    }
    
    function playUpdateSound() {
        try {
            const audio = new Audio('https://cdn.freesound.org/previews/270/270404_5123851-lq.mp3');
            audio.volume = 0.2;
            audio.play().catch(e => console.log("Audio play failed:", e));
        } catch (e) {
            console.log("Sound error:", e);
        }
    }
});

function updateJobInfo(job) {
    $('#job-name').text(job.label || job.name);
    $('#job-grade').text(job.grade.name);
    
    if (job.onduty) {
        $('#duty-status-icon').removeClass('off').addClass('on');
        $('#duty-status-text').text('On Duty');
        $('#toggle-duty-btn').html('<i class="fas fa-toggle-off"></i> Go Off Duty');
    } else {
        $('#duty-status-icon').removeClass('on').addClass('off');
        $('#duty-status-text').text('Off Duty');
        $('#toggle-duty-btn').html('<i class="fas fa-toggle-on"></i> Go On Duty');
    }
}

function populateJobs(jobs) {
    const container = $('#jobs-container');
    container.empty();
    
    $('#job-count').text(jobs.length);
    
    if (jobs.length === 0) {
        container.append('<p class="no-jobs">You have no jobs assigned. Contact an admin to get a job.</p>');
        return;
    }
    
    jobs.forEach((job, index) => {
        const currentJobName = $('#job-name').text().toLowerCase();
        const isCurrentJob = job.name.toLowerCase() === currentJobName || job.label.toLowerCase() === currentJobName;
        
        const jobElement = $(`
            <div class="job-item" style="animation-delay: ${index * 0.1}s">
                <div class="job-info">
                    <h3>${job.label || job.name}</h3>
                    <p>${job.gradeLabel || 'Grade ' + job.grade}</p>
                </div>
                <button class="switch-job-btn blue-btn" data-job="${job.name}" data-grade="${job.grade}">
                    <i class="fas fa-sign-in-alt"></i> Switch
                </button>
            </div>
        `);
        
        if (isCurrentJob) {
            jobElement.css('border-left-color', 'var(--primary)');
            jobElement.find('h3').append(' <i class="fas fa-check-circle" style="color: var(--success);"></i>');
        }
        
        container.append(jobElement);
    });
    
    // Add click event for switch job buttons
    $('.switch-job-btn').click(function() {
        const jobName = $(this).data('job');
        const jobGrade = $(this).data('grade');
        
        $(this).html('<i class="fas fa-spinner fa-spin"></i>');
        
        setTimeout(() => {
            $.post('https://ec-multijob/switchJob', JSON.stringify({
                jobName: jobName,
                jobGrade: jobGrade
            }));
            playButtonSound();
        }, 500);
    });
}

function playButtonSound() {
    try {
        const audio = new Audio('https://cdn.freesound.org/previews/522/522720_10058132-lq.mp3');
        audio.volume = 0.2;
        audio.play().catch(e => console.log("Audio play failed:", e));
    } catch (e) {
        console.log("Sound error:", e);
    }
}
